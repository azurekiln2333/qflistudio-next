# W2b 实施计划

仓库：`qflistudio/azurekiln-qfli-server`。边界见 design.md §1。

## A. 数据与配置
- [x] A1 `src/db.js`：追加独立迁移块 `moderationMigration*`，建四张新表并补两列：
      `posts.status`、`comments.status`、
      `moderation_settings`、`user_moderation`、`publish_rate`、`reports`。sqlite 与 mysql 各一份。
- [x] A2 `.env.example` 追加审核服务与限流配置。
- [x] A3 提交 `feat(server): add moderation tables and publish status columns`

## B. 适配层
- [x] B1 `src/moderation-client.js`：传输层（SDK 优先 / HTTP 兜底 / 测试注入），超时、错误分类。
- [x] B2 `src/moderation-service.js`：`checkText`、`checkIp`、`prePublish` 开关、
      `publishGate`（ban/mute → 限流 → IP → 文本 → pending 判定）、错误映射。
- [x] B3 `src/publish-rate.js`：按用户的分钟/天窗口计数（数据库记账）。
- [x] B4 提交 `feat(server): add moderation adapter with fail-closed publish gate`

## C. 业务接入
- [x] C1 `src/routes/posts.js`：发帖走 publishGate，列表/详情按 status 过滤，返回 `status`。
- [x] C2 `src/routes/comments.js`：评论走 publishGate，pending 可见性。
- [x] C3 `src/routes/users.js`：昵称、简介先审。`isAdmin` 由 `authRequired` 提供，供路由判断。
- [x] C4 提交 `feat(server): moderate posts, comments, nicknames and bios`

## D. 管理员与举报
- [x] D1 `src/routes/reports.js`：`POST /api/reports` 本地落库 + 转发 W1。
- [x] D2 `src/routes/moderation-admin.js`：删除内容、举报处理、先审后发开关、封停/禁言、词库与 IP 规则代理。
- [x] D3 `src/server.js` 挂载新路由（只新增行）。
- [x] D4 提交 `feat(server): add admin takedown, report center and account bans`

## E. 测试
- [x] E1 `test/moderation.test.js`：见 design.md §8。
- [x] E2 `node --test test/moderation.test.js` + 全量 `node --test "test/*.test.js"`。
- [x] E3 提交 `test(server): cover moderation gate, rate limit, bans and reports`

## Result

### 提交（qflistudio，main）

| 短哈希 | 标题 |
| --- | --- |
| `f1c366a` | feat(server): add moderation tables and publish status columns |
| `74a3527` | feat(server): add moderation adapter with fail-closed publish gate |
| `3ae1aee` | feat(server): moderate posts, comments, nicknames and bios |
| `957f818` | feat(server): add admin takedown, report center and account bans |
| `fb6bc94` | test(server): cover the moderation gate, rate limit, bans and reports |
| `07a0642` | docs(server): document the moderation integration and new admin endpoints |

所有提交无署名，无 `git add -A`/点号，无 reset/amend/push。

### 测试

```
cd azurekiln-qfli-server
node --test "test/*.test.js"
→ tests 96, pass 95, fail 0, skipped 1（跳过的是原有 MySQL 专用用例）
```

`test/moderation.test.js` 16 条全通过：正常发布与可见性、变体命中 422 且不回显命中词、
昵称简介拦截、review 强制 pending、先审后发开关、503 failClosed（查询类不受影响）、
IP 规则 403、429 分钟窗口带 retryAfter、封停/禁言与解除、管理员删帖/删评论必填原因并写审计。
举报落库与转发、审核服务不可用时仍返回 201(queued)、举报参数校验、举报列表与处理（重复处理 409）。
还有词库代理与 503、待审评论只对作者可见。

### 契约对齐

按 W1 `azurekiln-moderation/README.md`（`e95e7ff`）实现，而非早先的 contracts.md 草案：

- 鉴权用 `X-App-Id` + `Authorization: Bearer <apiKey>`，管理接口用 `adminKey`。
- 命中是 `200 {decision:"block"}`，不是 HTTP 错误。`review` 同样扣留发布。
- 查询结果校验 `decision ∈ pass|block|review`，非法结果按不可用处理（failClosed）。
- 词库接口是 `/v1/admin/keywords`（不是 lexicon），场景开关是 `/v1/admin/scenes/:scene`。
- 举报 `POST /v1/reports {targetType,targetId,reporterId,reason}`。

SDK 未就绪（w37:p7 在做）前用同契约的直连实现。安装 `@azurekiln/moderation-client` 后自动切到 SDK，
无需改业务代码。**分发尚未落地**：README 要求 `npm pack` 产物放接入方 `vendor/` 并在 lockfile 里引用，
本任务未提交 tgz（SDK 还没实现），待 w37:p7 交付后由部署阶段补。

### 未完成 / 需要用户或上游处理

1. **SDK vendoring**：等 w37:p7 交付 `@azurekiln/moderation-client` 的 tgz，再放进 `azurekiln-qfli-server/vendor/`
   并改 `package.json`/lockfile。Docker 构建上下文也要包含 `vendor/`。当前直连实现已可用，不影响功能验收。
2. **线上环境变量**：需在部署机 `.env` 填 `MODERATION_BASE_URL`、`MODERATION_APP_ID`、`MODERATION_API_KEY`、
   `MODERATION_ADMIN_KEY`。审核服务的 app 凭据要向用户/部署负责人索取（W1 用 `MODERATION_APPS_JSON` 发放）。
3. **词库初始化**：初始敏感词库由 W1 负责导入并调优，QFLI 侧只转发管理接口，不内置词表。
4. **客户端契约**（W3 承接）：`status` 字段、`POST /api/posts` 返回 `{id,status}`、
   `errorKey` 集合（`moderation.blocked|moderation.ip_blocked|moderation.unavailable|rate.limited|account.banned|account.muted`）、
   举报 `201 {id,status}`。
5. **`src/util.js` 有 W2a 的未提交改动**（实名中间件复用会话），本任务未触碰也未提交。
6. **昵称/简介审核只在 `PATCH /api/users/me`**：网关侧（W4）也会改昵称简介，那条路径由网关工作区接入审核，
   本仓库不能替代。
7. **数据库迁移需在线上执行**：MySQL 首次启动会自动补 `posts.status`、`comments.status` 与 4 张新表，
   由部署阶段跑一次冒烟确认。

### 边界遵守

未改动 W2a 边界内的 `src/audit.js`、`src/web-search.js`、AI 与注销文件、华为登录与实名中间件。
`src/db.js` 只在末尾追加独立迁移调用。新增 `src/client-ip.js` 是只读工具（仅消费 `X-Real-IP`/`X-Real-Port`），
不含可信代理配置本身（那是 W2a 的中间件）。
