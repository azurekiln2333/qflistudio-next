# W2a 设计：日志、可信代理、实名门槛、华为登录、注销、AI、联网搜索下线

仓库：`qflistudio/azurekiln-qfli-server`（CommonJS，Express 4，node:test）。
边界见 prd.md。W2b 负责社区/admin 路由内部、举报、限流、封停、审核接入。

## 1. 新增文件与职责

| 文件 | 职责 |
| --- | --- |
| `src/client-context.js` | 身份侧公共件：解析 `X-Client-Platform`（白名单）、解析可信代理地址（IP + 源端口）、`realnameRequired` 中间件、`accountErase` 网关客户端 |
| `src/deactivate.js` | 永久注销流程：删本站数据 + 删 `data/cloud/u<id>`、`data/terminals/u<id>` + 调网关 erase + 审计去标识化 |
| `test/client-context.test.js` | 平台解析、代理解析、实名中间件 |
| `test/audit-log.test.js` | 审计字段、365 天清理、登录/注册/登出落库 |
| `test/deactivate.test.js` | 注销全流程（替身网关） |

`src/audit.js`、`src/db.js`、`src/routes/auth.js`、`src/routes/users.js`、`src/server.js`、
`src/ai-client.js`、`src/routes/ai.js`、`src/web-search.js`、`.env.example`、
`docs/deployment/nginx.conf.example`、`README.md` 由本任务修改。

## 2. 日志（验收 1）

- `RETENTION_DAYS = 365`，`src/audit.js` 导出该常量；`src/db.js` 的 SQLite 与 MySQL 两处启动清理改成读同一常量
  （`db.js` 目前硬编码 `-90 days` / `INTERVAL 90 DAY`，必须与 audit.js 同步，否则代码与清理口径不一致）。
- `audit_logs` 新增三列，保持既有行可读：
  - `port INTEGER`（源端口）
  - `platform VARCHAR(64)`（`harmonyos-app` 等，不含版本号）
  - `login_type VARCHAR(32)`（`password|huawei|huawei_skip|huawei_bind|huawei_mfa|oauth2|logout|register`）
  - SQLite 用 `PRAGMA table_info` + `ALTER TABLE ADD COLUMN` 幂等补列；MySQL 用 `SHOW COLUMNS` + `ALTER TABLE`。
- `audit(req, {...})` 增加可选 `loginType`；`port`/`platform` 由 `audit.js` 自行从请求推导，调用方不用传。
- 登录（密码/华为/华为跳过/华为绑定/华为 MFA/OAuth2）、注册、登出都写审计。
  当前登出**完全没有**审计，注册审计缺 userId/username（用请求体的用户名）。

## 3. 可信代理（验收 1）

- 现状：`audit.js` 直接取 `X-Forwarded-For` 第一段，客户端可伪造。
- 改为：只认 `X-Real-IP` / `X-Real-Port`（由 nginx `proxy_set_header` 覆盖写入），
  其余来源按 `req.socket.remoteAddress` / `remotePort`。
- 不启用 Express `trust proxy`：它会让 `req.protocol`/`req.ip` 随 `X-Forwarded-*` 变化，
  且 `PUBLIC_BASE_URL` 已固定回调地址，收益为零、风险更高。
- 地址必须过 `net.isIP` 校验，非法值丢弃，不写进审计。
- nginx 示例两处 `location` 都补 `X-Real-Port $remote_port;`，并删掉已不被信任的
  `X-Forwarded-For` 透传（保留会误导后续维护者）。

## 4. 实名门槛（验收 2）

- 华为一键登录拿到的手机号在网关 claims 里。判定为“已验证手机号”：
  `phone_number` 非空且 `phone_number_verified !== false`（网关不返回该标志时按已验证处理），
  或 `phone_verified === true`。
- `src/client-context.js` 导出 `hasVerifiedPhone(claims)`。
- 中间件 `realnameRequired` 挂在**路由挂载层**（`src/server.js`），不改社区路由内部：
  - 受保护前缀：`/api/posts`、`/api/comments`、`/api/reports`、`/api/zones`、`/api/tags`、
    `/api/cloud`、`/api/cloud-projects`、`/api/terminal`、`/api/sql`、`/api/ai`。
  - 放行：`/api/users`（账号设置、注销必须在未实名时也能用）、`/api/auth`、`/api/health`、`/api/audit`。
  - `OPTIONS` 放行（CORS 预检）。
  - 已登录但无验证手机号 → 403 `{error, errorKey:'realname.required', message}`。
  - 未带 Bearer 令牌 → `next()`，交给下游 `authRequired` 返回 401（不改变未登录语义）。
  - 需要在挂载前确认 `req.gatewayClaims`：因此改用**独立中间件**先做令牌解析
    （复用 `util.authOptional` 的思路），不依赖下游路由的 `authRequired`。
  - 令牌解析每请求要访问网关取 claims。为避免请求数翻倍，中间件解析后把 claims 挂在
    `req.gatewayClaims` / `req.authSession`，并让 `util.authRequired` 复用已有值。
- 本地内置教程在客户端，不请求这些前缀，天然不受影响。

## 5. 华为登录（验收 3，服务端部分）

`/huawei/skip` 与 `/huawei/bind` 在 `entry.phoneAvailable === false` 时直接 403
`{error, errorKey:'realname.phone_required'}`，message 为“请使用已绑定手机号的华为账号”，
并删掉该 bindingId，不再调网关。`/huawei` 初始响应已带 `phoneAvailable`，客户端据此隐藏按钮（W3 负责）。

## 6. 永久注销（验收 7）

`POST /api/users/me/deactivate`，body `{confirm:"DEACTIVATE"}`，缺省或不等 → 400。

流程（严格顺序，失败即中断并保留会话，避免半途数据丢失）：

1. 审计 `auth.deactivate` 前先取 userId / gateway_user_id。
2. 调网关 `POST {AZK_OAUTH2_BASE_URL}/oauth2/account/erase`
   （Basic client credentials，body `{user_id, reason:"user_request", request_id}`），
   200 / 404 `user_not_found` 视为可继续；其他错误 → 502 且不清本地数据（可重试）。
3. 删除 `data/cloud/u<id>`、`data/terminals/u<id>`（不存在时静默跳过，先 `lstat` 拒绝符号链接）。
4. 数据库事务删本站数据：`auth_sessions`（吊销全部会话）、业务表
   （`comments`、`likes`、`post_tags`/`posts`、`cloud_projects`、`checkins`、`task_events`、
   `task_claims`、`point_ledger`、`redemptions`、`user_state`、`users`）。
5. 审计去标识化：把该用户的历史审计行的 `user_id` 换成 `deleted_<sha256 前 32 位>`，
   `username` 置空（保留 action/target/ip/port/platform/时间，满足 365 天留存）。
6. 返回 `{status:'deactivated'}`。

`AZK_OAUTH2_ERASE_SCOPE` 默认 `qfli_account_erase`。

## 7. AI 标识与联网搜索下线（验收 9，服务端部分）

- `ai-client.resultData()` 增加 `aiGenerated: true`；`routes/ai.js` 的 `/chat` 直接透传。
- `web_search`：路由保留但**固定返回 410/下线错误**？不 —— 任务书要求“工具也不再对外暴露”，
  因此删除 `POST /api/ai/web_search` 路由（404），删除 `src/web-search.js`，删除 `test/web-tools.test.js`
  里搜索解析的用例。`web_fetch` 与 SSRF 守卫保留。
  客户端 W3 同步下线 `web_search` 工具；服务端 404 是最后一道防线。
- `README.md` 写明线上 `QFLI_AI_BASE_URL` 只允许 DeepSeek 官方接口，不能指向第三方聚合。

## 8. 风险

- `src/db.js` 与 W2b 同改：只在既有函数内部改列/清理语句，不重排结构；W2b 追加自己的迁移块。
  每次提交保持文件可解析，减少冲突面。
- 实名中间件在挂载层，W2b 在路由内部加的东西不受影响。
- 注销删除 `users` 行会级联到 W2b 新增的 `user_moderation` / `publish_rate` / `reports`，
  若它们带 `ON DELETE CASCADE` 则自动清理；`reports`（留痕 365 天）不能级联 —— 由 W2b 的表定义决定，
  本任务注销流程删 `users` 后如果外键阻止删除，会显式先删这些表。为稳妥，注销前显式删除
  `reports`（reporter_id）、`user_moderation`、`publish_rate` 中该用户的行（表存在时）。
