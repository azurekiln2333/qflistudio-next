# pi-relay-server 进度

工作树：`D:/MyNewProjects/_wt/remote-account-binding/relay-server`（分支 `remote/remote-account-binding-relay`，基线 `841cc86`）

## 已完成

- [x] 读取 prd / design / implement / implementation-contract / pi-account / brief
- [x] 读取 coordinator-contract.md 与 pi-qfli-server-contract.md
- [x] 写出 reports/pi-relay-server-contract.md（换票、刷新、设备接口、旧配对边界、环境变量）
- [x] 核对缺口：tenancy 不校验 token kind；pair_code 绑定缺 `ct_devices` 行；
      device/start 覆盖 secret_hash 并复活设备；device/poll 只靠 user_code；
      首绑无 owner；撤销不撤 token 也不断连；refresh 无 grant 绑定；
      旧 secret hello 可绕过账号撤销
- [x] schema v2：`ct_devices.account_managed`、`ct_tokens.origin/family_id`、两个索引、
      历史绑定回填（R7）
- [x] `oauth/qfli-grant.ts`：QFLI introspection 客户端（无缓存、Basic、严格 claims 校验，R1）
- [x] `db/tokens.ts`：origin/family、原子 rotate、按账号+设备撤销、设备级撤销
- [x] `db/devices.ts`：`registerDevice`（不覆盖 secret、不复活、元数据只给持有者）、
      `ensureDevice`、`markAccountManaged`、`setRevoked`、`isAccountManaged`
- [x] `db/bindings.ts`：历史 owner 判定（含 revoked）、`for update` 串行化（R2）
- [x] `relay/tenancy.ts`：access-only、设备撤销、legacy 只读缓存、generation 栅栏（R3）
- [x] `relay/relay.ts`：legacy hello 阻断、撤销关连接、join 栅栏、
      `onAgentOnline` 元数据钩子、`deviceName`/`devicePlatform`（R3、R9）
- [x] `relay/api.ts`：`/auth/exchange`、带 grant 的刷新、code-only 绑定、
      事务化绑定与撤销、`GET /devices` 元数据合并（R1、R2、R4、R8、R9）
- [x] `oauth/flows.ts`：device/start 与 device/poll 停用，返回 `flow_disabled`（R6）
- [x] `.env.example`：`QFLI_RELAY_*`、`RELAY_ACCESS_TTL_MS`、`RELAY_REFRESH_TTL_MS`
- [x] 测试：`test/qfli-grant.test.ts`、`test/relay-binding-security.test.ts` 新增；
      `relay-api`、`oauth-flows`、`db-migrate` 补充回归

## 静态检查

- [x] `npx tsc --noEmit`：通过，无输出（本地 Node v24.15.0，锁文件依赖已在工作树）
- [x] `git diff --stat`：15 个已跟踪文件 +1913/-433，另有 3 个新文件与 1 个 CI 工作流

## 越界运行的测试结果（非本人执行，记录备查）

- `test/relay-binding-security.test.ts` 单文件：**23 项通过**
- 全量 `npm test`：**164 项中 157 项通过、7 项失败**
- 失败的 7 项定位与处理见 `reports/pi-relay-server.md` §4。
  其中 5 项是本文件对应 fake-db 与 SQL 形状不匹配（已按静态阅读修复，未复跑），
  2 项属于其它 worker 的既有失败面。

## 尚未运行

按任务规则，本 worker 不运行 `npm test`、CI、服务、容器或真机。
上表测试结果来自审查者的越界执行，仅作记录，不作为本 worker 的验证结论。
`test/relay-binding-security.test.ts` 修复后的结果未复跑，留给云端 CI。
