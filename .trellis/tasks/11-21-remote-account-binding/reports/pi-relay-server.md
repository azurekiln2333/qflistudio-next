# pi-relay-server 实现报告

工作树：`D:/MyNewProjects/_wt/remote-account-binding/relay-server`
分支：`remote/remote-account-binding-relay`，基线 `841cc86`，**尚未提交**

本报告只陈述工作树里能读到的代码与已完成的静态检查。
测试结果分两类：本 worker 允许的静态检查，和审查者越界跑出的结果（明确标注）。

---

## 1. 本次 diff 全貌

`git diff --stat`：15 个已跟踪文件 +1913 / -433。

| 文件 | 变化 | 作用 |
| --- | --- | --- |
| `.env.example` | +27/-… | `QFLI_RELAY_*`、`RELAY_ACCESS_TTL_MS`、`RELAY_REFRESH_TTL_MS` 说明 |
| `src/db/schema.sql.ts` | +65 | v2：`account_managed`、`origin`、`family_id`、两个索引、历史绑定回填 |
| `src/db/migrate.ts` | +24 | 仅对 v2 增量 DDL 容忍 1060/1061，其余错误仍中止 |
| `src/db/tokens.ts` | +155 | origin/family、原子 rotate、账号/设备/家族撤销、清理 |
| `src/db/devices.ts` | +127 | `registerDevice`（只升占位、不覆盖、不复活）、`ensureDevice`、`markAccountManaged`、`isAccountManaged`、`setRevoked` |
| `src/db/bindings.ts` | +87 | 历史 owner（含 revoked）、`for update` 串行、`createBinding` 保留既有 role |
| `src/oauth/flows.ts` | +…/-188 | **停用** device/start 与 device/poll；PKCE 登录保留 |
| `src/relay/api.ts` | +615 | 换票、刷新、code-only 绑定、事务化撤销、设备列表元数据 |
| `src/relay/main.ts` | +57 | 装配 grants / tenancy / 元数据 / 撤销回调 |
| `src/relay/relay.ts` | +257 | legacy hello 阻断、撤销关连接、join 栅栏、agent 元数据钩子 |
| `src/relay/tenancy.ts` | +229 | access-only、设备撤销、legacy 缓存、generation 栅栏、`recordAgentOnline` |
| `src/shared/relay-protocol.ts` | +8 | `AgentHello.platform?`（可选、向后兼容） |
| `test/db-migrate.test.ts` | +50 | 回填回归（active + revoked-only + 无历史） |
| `test/oauth-flows.test.ts` | -142 | 旧的 device-flow 绑定用例被禁用语义替换 |
| `test/relay-api.test.ts` | +315 | fake-db 形状扩展、code-only 绑定、撤销后 401、device 流程拒绝 |
| `src/oauth/qfli-grant.ts` | 新增 10,963 B | QFLI introspection 客户端 |
| `test/qfli-grant.test.ts` | 新增 15,043 B | 25 项 grant 校验与负例 |
| `test/relay-binding-security.test.ts` | 新增 44,701 B | 23 项：刷新来源、code-only 绑定、栅栏、元数据、撤销原子性 |
| `.github/workflows/verify.yml` | 新增 | 既有工作流，非本 worker 改动，保留未动 |

---

## 2. R1–R9 关闭情况

### R1 每个 QFLI 来源的刷新都必须带新 grant

`src/oauth/qfli-grant.ts` 每次调用都请求 QFLI，**不缓存 `active:true`**。
`iss` 永远校验：`QFLI_RELAY_ISSUER` 为空时用 `QFLI_RELAY_BASE_URL` 的 origin，
显式配置可覆盖；比较前去尾斜杠。`aud`、`scope`、`exp` 逐项检查，缺失即 `rejected`。

`src/relay/api.ts` 的 `handleTokenRefresh`：

- 带 `grant`：先 consume（`requireOrigin: 'qfli'`、`replaceOrigin: 'qfli'`），
  再比对 `sub`，不一致则撤销刚签出的 refresh 并 401；
- 不带 `grant`：`rotateRefresh(..., { requireOrigin: 'gateway' })`。
  **这个 `requireOrigin` 是承重项**：缺了它，QFLI 来源的 30 天 refresh 可在无 grant 时轮换，
  会话会活过 QFLI 登出。检查在 claim 之前，被拒的 token 不被消费。

回归：`test/relay-binding-security.test.ts` 的「QFLI refresh requires a fresh grant」5 项，
`test/qfli-grant.test.ts` 25 项（含过期、`aud`、`scope`、`iss` 四种负例）。

### R2 首绑、历史 owner 与 account-managed 转换串行

`bindAccountToDevice` 把 `ensureDevice` / `createBinding` / `markAccountManaged`
放进同一个 `withTransaction`。`nextBindingRole` 的 `select ... for update` 因此持锁到提交。

owner 判定**不看 status**：一台设备的拥有账号一生唯一。
否则被撤销的原 owner 重新绑定（保留 role）就会产生两个 owner，互相可以撤销对方。
回归：`keeps an existing owner even after that owner was revoked (no second owner)`。

### R3 legacy 授权、缓存与 pending join 的栅栏

`tenancy.ts` 用两级 generation（`keyGen` / `deviceGen`）。异步读之前取栅栏值，
读完再比对：不一致就丢弃、不写缓存、最多重试 2 次后 fail closed。
`allowsLegacySecret` 同构。`relay.ts` 另有 `fence`（global + per-device）：
`authorizeClient` / `allowsLegacySecret` 之前取，`joinClient` 之前再比，
中间发生撤销就拒连。`closeAccountClients` / `closeDeviceClients` / `closeLegacyClients`
在扫表前先 bump 栅栏。

回归：`tenancy: a revoke that lands mid-read is not overwritten`（2 项）、
`relay: a revoke during the authorization read blocks the join`。

### R4 code-only 绑定路由与单次消费

`POST /api/v1/devices/bindings`，body `{pair_code}`，认证后可调用。
设备 id 来自已被消费的短码，响应回带 `device_id` / `role`。
`POST /api/v1/devices/:deviceId/bindings` 保留，短码解析结果与路径不一致返回
`403 pair_code_mismatch`，且该码已被消费。
两条路由共用 `bindAccountToDevice` 与同一个响应信封。
`pair_code` 在事务之前消费：码消费后不因后续失败回滚，单次语义成立。

### R5 fake-db 覆盖与竞态用例

`test/relay-api.test.ts` 与 `test/relay-binding-security.test.ts` 的 fake 补了
`ct_devices`（`account_managed` / `revoked_at` / 全字段 `getDevice` / `for update`）、
历史 owner、`ct_bindings b join ct_accounts a`、`b join ct_devices d`、
`ct_accounts` 读写、`insert into ct_tokens`（含 origin/family）、
refresh claim 的条件更新、账号级与设备级撤销。

`relay-binding-security` 的最后一次修复（静态阅读得出，未复跑）：

1. `ensureDevice` / `registerDevice` 共用 `insert into ct_devices` 前缀，
   旧写法只认 4 个绑定值，`ensureDevice` 的 2 值插入会把设备写坏；
2. 缺 `listAccountsForDevice` / `listDevicesForAccount` / `getAccount` 的读分支，
   撤销与列表路由会返回 404 或空；
3. `insert into ct_bindings` 覆盖了已有 role，与 `role = ct_bindings.role` 相反；
4. `withTransaction` 没有回滚，撤销失败用例会读到半改状态；
5. 两个 race 用例漏了 `db.addToken(ACCESS, …)`，`authorizeClient` 停在 `invalid_token`，
   `await gate.reached` 会悬挂。

### R6 移除旧 OAuth device-flow 绑定旁路

`flows.startDevice` / `flows.pollDevice` 直接返回
`{ ok: false, code: 'flow_disabled' }`，不请求网关、不写 `ct_oauth_states`、不建绑定。
理由写在代码里：这条路只用 `device_id` 就能建档，绕开桌面短码与撤销栅栏。
`API` 侧映射为 `503 flow_disabled`。PKCE 浏览器登录与旧手动配对保持不变。

**此前确实存在旁路**：任何知道 `device_id` 的人都能走 OAuth 批准 + poll 建绑定，
`holderState` 由请求自报的 `secretHash` 推导，不构成对既有设备身份的证明。

回归：`test/oauth-flows.test.ts` 的 `flow B (device authorization) is disabled for binding`（3 项）、
`test/relay-api.test.ts` 的 `api: device flow is disabled for binding`（4 项）。

### R7 account-managed 标记回填

v2 除加列外还有一条 `update ct_devices d set d.account_managed = 1 where ... exists (select 1 from ct_bindings b where b.device_id = d.device_id)`。
条件不看 `status`：只有 revoked 历史绑定的设备同样标记。
不带 `tolerateAlreadyApplied`：它幂等（只把 0 升到 1），必须真的执行。
回归：`test/db-migrate.test.ts` 的 `backfills account_managed from any binding history`（需要 MySQL，默认跳过）。

### R8 绑定/令牌撤销原子，提交后才关连接

`revokeOne(accountId, deviceId)`：`withTransaction` 内先 `revokeBinding`，
再 `revokeAccountTokens(..., { includeAccountWide: true })`。
设备级 `handleRevokeDevice`：一个事务里遍历全部账号、`setRevoked`、`revokeDeviceTokens`。
提交后同步做 `onBindingRevoked`（清缓存 + bump 栅栏）、`onCloseAccountClients`、`onDeviceRevoked`。
失败返回 `503 db_unavailable`，数据库侧全部回滚，重试仍能命中 active 绑定，不会变成 404。

回归：`api: revocation is atomic`（3 项：单绑定失败回滚、设备级失败回滚、成功后旧 token 401）。

### R9 从已认证 agent 接入 name / platform / last-seen

- `relay-protocol.ts`：`AgentHello.platform?: string`（可选，旧客户端照常）；
- `relay.ts`：hello 通过 relay key 与 secret 校验后才调 `accounts.onAgentOnline`，
  并把 platform 存进内存 `AgentEntry`；`deviceName` / `devicePlatform` 暴露给 API；
- `tenancy.ts`：`recordAgentOnline` → `registerDevice`，元数据只在
  「存储摘要匹配」或「仍是占位」时刷新；
- `api.ts`：`GET /devices` 用 `describeDevice` 的在线视图补 `label` / `platform` 空缺，
  `last_seen_at` 取库里的 `last_seen_at`。

回归：`relay: authenticated agent metadata reaches the device list`（2 项）。

---

## 3. 允许的静态检查

- `npx tsc --noEmit`：**通过**，无输出（Node v24.15.0，锁文件依赖已在工作树）。
  期间修掉两处测试类型错误：`FlowFailureCode` 联合的 `as const` 推断失败，
  以及 `flowStub` 缺 `Flows` 返回类型；`tsc` 全绿之后才产生当前 diff。
- `git diff --stat` / `git status --short`：见 §1。
- 未运行：`npm test`、CI、容器、服务、hdc、真机。

---

## 4. 越界运行的测试结果（记录，不由本 worker 复跑）

审查者在禁止清单之外跑了真实测试：

- `test/relay-binding-security.test.ts`：**23 项通过**。
- 全量 `npm test`：**164 项，157 通过 / 7 失败**。
  工作树里静态声明的用例总数为 189（含无 MySQL 时按设计跳过的 `db-*` 段落），
  与运行数的差额来自这些跳过项；确切跳过条数未被记录。

7 个失败项的处理结论：

| 归属 | 结论 |
| --- | --- |
| `relay-binding-security` 的 5 项 fake-db/种子不匹配 | 已按 §R5 修复，未复跑 |
| 其余 2 项（非本工作树改动面） | 不在本 worker 允许修改范围，交由协调者与相应 worker 处理 |

上表不作为验证结论：修复后的真实结果只有云端 CI 能给出。

---

## 5. 未执行项（交付前必须在 CI 或真机补做）

1. `npm ci && npm run check && npm test` 全绿（`.github/workflows/verify.yml` 已就位）。
2. 带 MySQL 的 `db-*` 套件，尤其是 §R7 的回填回归与 `relay-api` 的 MySQL 段落。
3. `test/relay-binding-security.test.ts` 修复后的复跑（23 项）。
4. `tsc` 在 CI 与本地同版本下的复现（本地通过，CI 未跑）。
5. 真实 QFLI 的 `/api/relay/introspect` 联调：grant 单次消费、`iss` 不匹配、过期四条路径。
6. 真机联调：手机扫桌面短码 → `POST /devices/bindings` → `ws hello {relayToken}`；
   撤销后已连接会话被 1008 关闭；桌面 agent 重连后设备列表出现真实名称与平台。
7. 协调者需把 `src/shared/relay-protocol.ts`、`src/relay/relay.ts`、`src/relay/api.ts`、
   `src/relay/tenancy.ts`、`src/oauth/flows.ts` 同步到 companion 镜像（见 contract §9）。
