# W2a 实施计划

仓库：`qflistudio/azurekiln-qfli-server`。边界与设计见 design.md。
每步可独立提交，避免与 W2b 并行时的大块冲突。

## A. 日志与可信代理（验收 1）
- [x] A1 `src/client-context.js` 新建：`clientPlatform(req)`、`clientIp`/`clientPort`（只信 `X-Real-*`）、`hasVerifiedPhone`
- [x] A2 `src/audit.js`：`RETENTION_DAYS=365`、`audit_logs` 写 `port`/`platform`/`login_type`
- [x] A3 `src/db.js`：`audit_logs` 补三列（sqlite PRAGMA + ALTER / mysql SHOW + ALTER），
      两处清理语句改 365 天并与 `audit.js` 同源
- [x] A4 `src/routes/auth.js`：登录各分支、注册、登出写审计（含 loginType）
- [x] A5 nginx 示例补 `X-Real-Port`，去掉 `X-Forwarded-For` 透传
- [x] 提交 `feat(server): record login platform and source port with 365-day retention`

## B. 实名门槛与华为登录（验收 2、3）
- [x] B1 `src/client-context.js`：`realnameRequired` 中间件（先解析令牌，未登录放行给 401）
- [x] B2 `src/util.js`：`authRequired` 复用 `client-context` 已解析的会话，避免重复网关调用
- [x] B3 `src/server.js`：把 `realnameRequired` 挂到社区/云项目/终端/AI/SQL 前缀
- [x] B4 `src/routes/auth.js`：`/huawei/skip`、`/huawei/bind` 在 `phoneAvailable===false` 时 403
- [x] 提交 `feat(server): gate networked features behind a verified phone number`

## C. 永久注销（验收 7）
- [x] C1 `src/client-context.js` 或 `src/deactivate.js`：网关 `account/erase` 客户端（唯一错误映射）
- [x] C2 `src/deactivate.js`：数据删除、目录删除、审计去标识化
- [x] C3 `src/routes/users.js`：`POST /api/users/me/deactivate`
- [x] C4 `.env.example` 写明注销 scope
- [x] 提交 `feat(server): permanently deactivate accounts across gateway and local data`

## D. AI 标识与联网搜索下线（验收 9，服务端）
- [x] D1 `src/ai-client.js`：响应带 `aiGenerated: true`
- [x] D2 删除 `src/web-search.js` 与 `/api/ai/web_search` 路由。`web_fetch` 保留
- [x] D3 清理 `test/web-tools.test.js` 中的搜索用例
- [x] D4 `.env.example` / `README.md`：`QFLI_AI_BASE_URL` 只允许 DeepSeek 官方，删除搜索 provider 说明
- [x] 提交 `feat(server): label AI output and remove web search relay`

## E. 测试
- [x] E1 `test/client-context.test.js`、`test/audit-log.test.js`、`test/deactivate.test.js`
- [x] E2 `node --test test/*.test.js` 全量通过
- [x] E3 提交 `test(server): cover client context, audit fields and account deactivation`

## Result

### 提交列表

| 短哈希 | 标题 |
| --- | --- |
| `a54cb3d` | feat(server): record login platform and source port with 365-day retention |
| `c348224` | feat(server): reuse the verified session when the realname gate has already run |
| `c4e588a` | feat(server): permanently deactivate accounts across gateway and local data |
| `87d21e7` | feat(server): label AI output and remove the web search relay |
| `574a3f9` | fix(server): gate the realname check on the unmounted request path |
| `75c260a` | feat(server): unify the Huawei phone-required refusal under huawei.phone_required |

`src/db.js` 的审计三列与 365 天清理随 `f1c366a`（W2b 的提交）一起入库。
该提交中的内容已逐行进过审查。`src/server.js` 的挂载同样随 W2b 的提交入库。

### 测试

```
node --test --test-timeout=60000 test/*.test.js   # 135 tests, 134 pass, 0 fail, 1 skipped
```

跳过的 1 项是 `test/terminal-pool.mysql.test.js` 的 MySQL 池用例（无 MySQL 实例，原有行为）。
新增/扩充的用例：

- `test/client-context.test.js`（18 项）：平台解析、`X-Real-IP`/`X-Real-Port` 校验、
  `X-Forwarded-For` 完全忽略、实名判定、受保护前缀、真实挂载形状回归（含 query 与大小写变体）。
- `test/audit-log.test.js`（9 项）：365 天口径、登录/注册/登出字段、未知平台存 NULL、
  华为无手机号不得建号、有手机号可跳过绑定、网关三条路径的错误统一转换。
- `test/deactivate.test.js`（6 项）：网关 Basic 鉴权、404 视为已删、403 与不可达不清本地数据、
  全量删除与审计去标识化、符号链接拒绝。

### 关键事故与根因（供后续参考）

1. **真实 E2E 复现了实名门槛的完全绕过**。`realnameRequired` 用 `req.path` 判断。
   Express 在 `app.use('/api', mw)` 之后剥掉挂载前缀，中间件只能看到 `/posts`。
   该值与 `GATED_PREFIXES` 的 `/api/posts` 永不相等，五类服务全部放行。
   改用 `req.originalUrl`，并做 query 剥离与大小写归一（Express 路由默认忽略大小写）。
   已加与 `src/server.js` 同形状的挂载回归测试。
2. **`test/audit-log.test.js` 卡住 8 小时不退出**。Express 4 不自动转发路由异步拒绝。
   测试里直接 require 路由后调用 `app.use`，漏掉 `src/server.js` 的包装。
   抛出的 rejected promise 变成 unhandledRejection，Node 测试进程随之停滞。
   测试内补齐同样的包装，并在 `beforeExit` 显式 `db.close()`。

### 未完成项

- **部署未执行**：prd 要求“先不要部署（root 另行指示）”。`.env.example` 的
  `QFLI_AI_BASE_URL` 已改为 `https://api.deepseek.com`，线上 env 需由部署方同步。
- **注销的网关 scope 待授予**：`AZK_OAUTH2_ERASE_SCOPE=qfli_account_erase` 需要在网关后台
  给 qfli 客户端授予。未授予时注销返回 403，本地数据按设计保留。

### 需要用户本人处理

1. 网关管理后台给 qfli 客户端授予 `qfli_account_erase` scope。
2. 线上 `.env` 的 `QFLI_AI_BASE_URL` 与 `.env.example` 对齐（只允许 DeepSeek 官方接口）。
3. 线上 `QFLI_AUDIT_SALT` 建议单独配置（留空时用内置固定盐）。
4. 部署时执行 nginx 配置更新，确认两处 `location` 都带 `X-Real-Port` 且不再透传
   `X-Forwarded-For`（示例见 `docs/deployment/nginx.conf.example`）。

### 验收对应（§4）

| 条目 | 状态 |
| --- | --- |
| 1 登录日志含ID/平台/类型/IP/端口/时间，保留 365 天 | 已完成（`test/audit-log.test.js`） |
| 2 未实名账号得不得社区/云项目/终端/AI/SQL | 已完成（`574a3f9`，含 query/大小写变体） |
| 3 无手机号华为账号无法跳过绑定建号（服务端） | 已完成（`75c260a`） |
| 7 永久注销，日志去标识化 | 已完成（`c4e588a`） |
| 9 服务端无 bing.com 调用，AI 带标识 | 已完成（`87d21e7`） |

