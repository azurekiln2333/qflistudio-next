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
7. **数据库迁移需在线上运行**：MySQL 首次启动会自动补 `posts.status`、`comments.status` 与 4 张新表，
   由部署阶段跑一次冒烟确认。

### 边界遵守

未改动 W2a 边界内的 `src/audit.js`、`src/web-search.js`、AI 与注销文件、华为登录与实名中间件。
`src/db.js` 只在末尾追加独立迁移调用。新增 `src/client-ip.js` 是只读工具（仅消费 `X-Real-IP`/`X-Real-Port`），
不含可信代理配置本身（那是 W2a 的中间件）。

## Follow-up：接入 W1 SDK（2026-11-02）

### 提交

| 短哈希 | 标题 |
| --- | --- |
| c07c974 | feat(server): call the moderation SDK from the vendored tarball |

### 做了什么

- 把 `azurekiln-moderation-client-0.1.0.tgz` 复制到 `azurekiln-qfli-server/vendor/`，文件名不变。
  校验 SHA256：`e63df6cf97b73fb67dcf33d41b0a5b1c42ea20f1c1908374ef3a337c9fcaaab5`，大小 4329 字节，与下发值一致。
- `package.json` 依赖 `@azurekiln/moderation-client` 指向 `file:vendor/azurekiln-moderation-client-0.1.0.tgz`。
  lockfile 用 `npm install --package-lock-only` 更新，带 integrity 校验值，`npm ci` 可离线复现。
- `Dockerfile` 在 `npm ci` 之前 `COPY vendor ./vendor`。`.dockerignore` 原本未排除 `vendor`，
  无需改动，已逐行看过该文件。
- 适配层 `src/moderation-client.js` 改为真正调用 SDK：
  `checkText`、`checkIp`、`checkImage`、`submitReport` 走 `ModerationClient` 实例。
  SDK 的 `failClosed:true` 负责把网络失败、超时、非法响应统一成 `moderation.unavailable`。
  本层再做一次 decision 收敛，保证上层只看到 `pass|block|review`。
- 测试替身（`__setTransport`）保留，只给 `test/moderation.test.js` 的路由级用例用。
  新增 `test/moderation-sdk.test.js`：不注入替身，用本机 HTTP 假审核服务验证真实 SDK 路径。

### 测试

`
cd azurekiln-qfli-server
node --test test/moderation.test.js test/moderation-sdk.test.js
→ tests 25, pass 25, fail 0
`

其余服务端测试逐个单跑全通过（ai-relay 16、deactivate 6、huawei-binding 9、points-rewards 1、
points-upgrade 1、sqlbox 4、terminal-pool 29、web-tools 9、audit-log 前 4 条）。

### SDK 能力缺口

SDK 0.1.0 的导出只有 `ModerationClient`、`ModerationUnavailableError`、`ModerationHttpError`。
方法只有 `checkText`、`checkImage`、`checkIp`、`submitReport`、`getReview`，没有管理接口。
因此词库、IP 规则、场景开关仍由 `adminCall` 用 `MODERATION_ADMIN_KEY` 直连
`/v1/admin/*`，与 SDK 同一套 `X-App-Id` 加 Bearer 契约。接口签名对外不变，
SDK 补齐管理方法后只需替换 `adminCall` 一处。

### 阻塞上报：W2a 的 audit-log 测试挂起

`node --test test/audit-log.test.js` 第 5 条
"a Huawei account without a phone cannot skip binding to create an account" 以 `unhandledRejection` 失败，
错误文本是"请使用已绑定手机号的华为账号"，来自 `src/routes/auth.js:99` 的 `huaweiBinding`。
失败发生在路由模块加载时补的 Promise 包装层之前，所以该用例直接判失败。
进程随后不退出（残留句柄），单独跑该文件会一直挂住。
该文件属 W2a（`src/routes/auth.js` 与 `src/audit.js`）的边界，本任务未改也未提交。
按监控通知，该项由 w37:p2 修复。W2b 不再排查也不再运行该文件。
W2b 的 25 条与其余文件均不受影响。

## Acceptance fixes（2026-11 服务端验收失败项）

基线 ``af5829dd``。验收 84 条断言 79 通过、5 失败，全部修复并补回归测试。

### 提交

| 短哈希 | 标题 |
| --- | --- |
| ``10dee9b`` | fix(server): let admins see and open pending posts |
| ``741e33f`` | fix(server): attribute the register audit row to the new user |
| ``68a992e`` | fix(server): deidentify admin actions and audit failed deactivation |
| ``50aebcc`` | test(server): cover the five acceptance failures through real routes |

### 五处失败与修复

1. **注册审计 user_id 为 null**。``POST /api/auth/register`` 只写了 username。
   注册接口已经把账号建在网关上，因此用同一套客户端 Basic 凭据按用户名查
   ``/oauth2/public-profile/<username>`` 取 sub，再映射到本地 users 行。
   查不到时保留 null，不拿用户名冒充用户ID。
   不用 ``gateway.publicProfile()``，因为它要求参数本身就是用户ID，传用户名会被判 502。
2. **管理员看待审帖详情 404**。详情只放行作者，没放行管理员。改为已发布、作者、管理员三种情况放行。
3. **管理员列表漏掉待审帖**。列表 SQL 只给作者本人开 pending。管理员视角改为放开 pending。
4. **注销后审计 target 残留原用户ID**。去标识化原先只按 ``user_id`` 命中，
   ``admin.account_mute`` 这类行的 user_id 是管理员、target 才是被注销用户。
   改为 ``user_id = ? OR target LIKE ?`` 命中，target 与 detail 一并清洗。
   只有主体是本人时才改 user_id，管理员身份保留。
5. **注销失败没有审计**。网关 403 ``insufficient_scope`` 时本地数据按设计保留，
   但审计数 44→44。现在写 ``user.deactivate_failed``，detail 带状态码与错误码。
   网关错误码同步透传到 ``details.errorKey``（如 ``gateway.insufficient_scope``），
   便于客户端提示与复测断言。

### 测试

```
cd azurekiln-qfli-server
node --test --test-timeout=60000 "test/*.test.js"
→ tests 141, pass 140, fail 0, skipped 1（原有 MySQL 专用用例）
```

新增 ``test/acceptance-fixes.test.js`` 5 条，全部经过真实 Express 路由挂载
（真实 SQLite、真实 audit 写入，只把网关 HTTP 换成替身）：

- 注册审计带本地用户ID，且确实向网关查了 sub
- 网关解析不到账号时 user_id 保持 null
- 注销后以该用户为目标的审计目标被去标识化，两行结果一致，管理员身份不变
- 网关注销 403 时写失败审计，用户与会话保留，重试成功后失败审计同样被去标识化
- 缺二次确认时不写审计

``test/moderation.test.js`` 增加 1 条：管理员在列表与详情都能看到待审帖，
非作者非管理员仍 404，处置为 published 后对所有人可见。

### 剩余事项

验收第 1 条另有一项不计失败：超过 365 天的注册审计会被清理，长期注册信息由网关侧证据确认。

## Acceptance fixes round 2（复测 ac4d0b8 后的三项失败）

上一轮 3 项仍未通过，原因是修复和测试都建立在错误假设上。

| 短哈希 | 标题 |
| --- | --- |
| ``60732a9`` | fix(server): resolve admin visibility from the session, not req.user |
| ``936f9d6`` | fix(server): create the local user mapping on first registration |
| ``7285f82`` | fix(server): deidentify audit details and report rows on deactivation |
| ``b6a25d7`` | test(server): stop faking req.user and cover first registration |

### 根因

1. **管理员看不到待审帖（两项断言）**。真实 ``authOptional`` 只赋值 ``req.userId``，
   从不赋值 ``req.user``。上一版用 ``req.user?.is_admin`` 判定，恒为 false。
   更严重的是上一轮的测试替身自己填了 ``req.user``，比真实中间件宽松，把缺陷掩盖成通过。
2. **注册审计 user_id 仍为 null**。首次注册时本地没有 users 行，上一版只做 ``SELECT``。
   测试里预先插入了本地用户，所以测不出首次注册的真实路径。

### 修复

- 新增 ``src/admin-access.js``：按需判定管理员。有 ``req.user`` 直接用，否则解一次会话并缓存 30 秒
  （列表逐行判定会重复访问网关）。网关不可达或会话失效按非管理员处理，宁可少放行。
  不改 ``src/util.js``，那是 W2a 的边界。
- 注册后按网关 sub 补建本地 users 行，并发时回退到已有行。拿不到 sub 仍保留 null。

### 第 7 条静态边界（detail-only 分支）

``admin.post_delete`` / ``admin.comment_delete`` 把作者ID写在 ``detail`` 的 ``author=`` 里，
``target`` 是帖子或评论编号。只按 ``user_id`` 或 ``target`` 命中的去标识化会漏掉这类跨操作者记录。
本轮一并修复，并补了 detail-only 断言（``7285f82``）。同时把已注销举报人的 ``reporter_id``
换成去标识化值（该列 NOT NULL，举报要留存 365 天，不能删行也不能置空）。

### 测试

```
cd azurekiln-qfli-server
node --test --test-timeout=60000 "test/*.test.js"
→ tests 145, pass 144, fail 0, skipped 1
```

``test/pending-visibility.test.js`` 不替换 ``src/util``：真实 ``authOptional``、
真实 ``auth_sessions`` 与真实 token，只替身网关远端调用与审核服务。
覆盖管理员可见、非管理员与匿名不可见、会话失效回落非管理员。

``test/acceptance-fixes.test.js`` 的注册用例改为"从未有本地 users 行的首次注册"，
并新增"已有映射时复用不重复建用户"。

## 审核侧标识去标识化（验收第 7 条补漏）

验收观察到审核服务（举报中心与审核审计）里保存的 reporterId、userId 是本站原始用户ID。
该侧留存 365 天，用户注销后仍可关联到个人，因此必须换成不可逆假名。

| 短哈希 | 标题 |
| --- | --- |
| ``3463632`` | feat(server): send pseudonymous user ids to the moderation service |
| ``715ed33`` | test(server): assert no raw user ids reach the moderation service |
| ``59ab6af`` | docs(server): document the moderation subject salt |

### 做法

- 新增 ``src/moderation-subject.js``：HMAC-SHA256 假名，输出 ``psn_`` 加 64 位十六进制。
  密钥取 ``QFLI_MODERATION_SUBJECT_SALT``，独立于 JWT 与其他密钥。
- 适配层三个出口全部换成假名：文本审核与 IP 审核的 ``userId``、举报的 ``reporterId``、
  以及 ``targetType=user`` 时的 ``targetId``。帖子与评论编号不是个人标识，按原样送。
- 假名稳定：同一用户在审核侧仍可归并。换盐后旧假名无法与新数据关联。
- 生产环境缺盐或短于 16 位时拒绝发布类请求，返回 503 ``moderation.unavailable``
  并写一条 ``moderation.subject_salt_missing`` 告警，绝不回退成原始ID。
  开发环境有默认盐，与服务端其他密钥的开发口径一致。
- 本地 ``reports`` 行仍存真实上报人，管理员的举报处置以本地记录为准。

### 测试

```
cd azurekiln-qfli-server
node --test --test-timeout=60000 "test/*.test.js"
→ tests 154, pass 153, fail 0, skipped 1
```

``test/moderation-subject.test.js`` 经过真实路由挂载（发帖、评论、昵称、举报），
记录每一次到审核服务的调用载荷并整体扫描：任何原始用户ID出现即失败。
另覆盖 ``targetType=user`` 的 targetId、缺盐 failClosed、换盐后不可关联。

### 遗留

本地举报处理结果同步到审核中心：SDK 0.1.0 的方法只有
``checkText``、``checkImage``、``checkIp``、``submitReport``、``getReview``，
没有举报处理接口（``POST /v1/admin/reports/:id/handle`` 只能直连 admin 接口）。
本轮未接，等 W1 扩展 SDK 后再补。当前管理员在 QFLI 处理举报只更新本地记录。
