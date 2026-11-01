# W2b 设计：审核接入、限流、封停、管理员处置、举报

仓库：`qflistudio/azurekiln-qfli-server`（CommonJS，Express 4，node:test）。
本任务只改自己边界内的文件。W2a 的文件（`src/audit.js`、可信代理、实名中间件、华为登录、`src/web-search.js`、AI、注销）不动。

## 1. 边界与分层

```
routes/posts.js ─┐
routes/comments.js├─> moderation-service.js ─> moderation-client.js ─> W1 SDK
routes/users.js  ┤      业务适配层：           薄传输层：             或同契约直连
routes/reports.js┘      场景、failClosed、      契约映射、超时、
                        503/422 映射            举报转发
moderation-admin.js ─> W1 管理接口（词库、IP 规则、场景开关）
```

业务代码只调用 `moderation-service`。`src/` 里不出现词库、正则或供应商细节。
`moderation-client` 是可替换的传输层，默认 `fetch` 到 `MODERATION_BASE_URL`。
安装 `@azurekiln/moderation-client`（W1 的 `packages/client`）时由它接管。
两种模式对外签名一致，测试用 `__setTransport` 注入替身。
审核逻辑（规范化、词库、黑名单）全部在 W1，`src/` 内不复制。

## 2. 数据模型

迁移写在 `src/moderation-migration.js`，由 `src/db.js` 末尾追加调用。sqlite 与 mysql 各一份，语句幂等。

- `posts.status` 与 `comments.status`：取值 `published|pending|rejected`，默认 `published`，兼容历史行。
- `moderation_settings`：键值表。键 `pre_publish` 是本地的先审后发开关。
- `user_moderation`：`user_id` 主键，含 `banned`、`muted`、`reason`、`actor_id`、`updated_at`。
- `publish_rate`：`user_id` 加 `kind` 做主键，记录 `day`、`minute_start`、`minute_count`、`day_count`。
  用数据库记账的原因：限流是承诺项，服务重启不得清零。
- `reports`：`id`、`target_type`、`target_id`、`reporter_id`、`reason`、`status`、`resolution`、
  `handler_id`、`moderation_report_id`、`forwarded`、`created_at`、`handled_at`。
  内容删除不级联这张表，留痕 365 天。

## 3. 契约映射（contracts.md C 节）

| 场景 | 状态 | errorKey |
| --- | --- | --- |
| 文本命中 | 422 | `moderation.blocked`，带 `categories`，不回显命中词 |
| IP 规则命中 | 403 | `moderation.ip_blocked` |
| 审核服务不可达或超时 | 503 | `moderation.unavailable`，message 固定为“审核服务暂不可用” |
| 超限 | 429 | `rate.limited`，带 `retryAfter` |
| 被封停账号发布 | 403 | `account.banned` |
| 被禁言账号发布 | 403 | `account.muted` |

以上只用于新增路径。既有错误的形状不动，避免回归 W3 已对齐的字段。

## 4. 发布流水线（`moderation-service.publishGate`）

1. 查封停与禁言，命中直接拒绝。
2. 按用户限流（分钟窗口加自然日窗口），命中返回 429。
3. 调 `POST /v1/ip/check`，block 则 403。
4. 逐字段调 `POST /v1/text/check`。block 则 422，review 则强制 pending。
5. 先审后发开关打开时一律 pending。
6. 全部通过才写库。限流计数在 3 与 4 之前递增，失败请求也计入，防止刷配额。

failClosed 只作用于发布类。查询类（列表、详情）在审核服务不可用时照常工作。

## 5. 可见性

- 列表：`published` 全公开。`pending` 只对作者本人可见。
- 详情：pending 对非作者返回 404。
- 评论：未登录只看 `published`。新增 `/api/posts/:id/comments/mine` 给作者本人视角。
- 返回体新增 `status` 字段，客户端据此显示“审核中”。

## 6. 管理员接口（`src/routes/moderation-admin.js`，挂在 `/api/admin`）

- 删除帖子与评论：body 必填 `reason`（2–500 字），写审计 `admin.post_delete` 与 `admin.comment_delete`。
- 举报：`GET /reports` 列表，`PATCH /reports/:id` 置 `handled|rejected`。重复处理返回 409。
- 先审后发：`GET|PATCH /settings/pre-publish`，写审计 `admin.pre_publish_toggle`。
- 封停与禁言：`POST|DELETE /users/:id/ban` 与 `/mute`，都必填原因并写审计。
- 人工复核：`PATCH /posts/:id/status` 把内容改成 `published|pending|rejected`。
- 词库与 IP 规则：`/moderation/keywords*`、`/moderation/ip-rules*`、`/moderation/scenes*` 转发到 W1 管理接口。
  使用服务端的 `MODERATION_ADMIN_KEY`，不透传客户端凭据。W1 不可用时返回 503。

## 7. 举报

`POST /api/reports` 要求登录。校验 `targetType ∈ {post,comment,user}`、目标存在、`reason` 1–500 字。
先写本地 `reports` 行保证留痕，再转发 W1 举报中心。
W1 失败时本地行保留，`forwarded=0`，返回 201 与 `status:"queued"`。审计 `report.create`。

## 8. 测试

`test/moderation.test.js` 使用真实 Express 与真实 sqlite，替换 `moderation-client` 的传输层。
覆盖：命中拦截与变体、review 强制 pending、503 failClosed、429 双窗口、封停与禁言、
pending 可见性、管理员删除与审计、举报本地落库与转发失败、先审后发开关。

## 9. 配置

`.env.example` 追加 `MODERATION_BASE_URL`、`MODERATION_APP_ID`、`MODERATION_API_KEY`、
`MODERATION_ADMIN_KEY`、`MODERATION_TIMEOUT_MS`、`PUBLISH_RATE_*`、`COMMENT_RATE_*`。
未配置审核服务且未装 SDK 时，发布类返回 503，查询类正常。

## 10. 风险

- 与 W2a 同改 `src/db.js`：只在自己的迁移块追加，不触碰 init 主体结构。
- 与 W3 客户端契约：`status` 字段与 errorKey 已写进 contracts.md，向后兼容。
- W1 契约以 README 为准，不以草案为准：命中是 HTTP 200 的 `decision:"block"`，词库路径是 `/v1/admin/keywords`。
