# Pi Mobile 报告：账号绑定设备列表、在线状态、撤销与手动配对回退

任务：`.trellis/tasks/11-21-remote-account-binding`（PRD R1–R8，AC1–AC7）
调研对象：发布工作树 `D:/MyNewProjects/_wt/cloudterminal-import/work/qfli_studio_core/lib/remote_control`
（模块在 **core**，不在主仓 `D:/MyNewProjects/qflistudio/lib`；主仓只提供 `lib/main.dart`、`lib/studio_tools_tab.dart` 两个文件的挂载面）
性质：**只读调研**。本次没有修改任何代码，只新增本文件。
凭据：**未读取任何凭据文件**（未打开 `auth.json`、`agent.json`、`.env`、token 或密钥值）。下文所有涉及 `secret`/`token` 的结论都来自代码路径，不来自真实值。

## 0. 结论摘要

1. 手机端现在是**单机配对模型**：`RemoteStore` 只持久化一个 `pairing`（`relayUrl` + `agentId` + `secret` + `name`）。没有设备列表、没有账号维度、没有任何多设备结构（`state/remote_store.dart:23,100,110`）。
2. 连接鉴权只有一条路：客户端 hello 带设备 `secret`（`state/remote_controller.dart:355-362`）。账号身份完全没进这个模块 —— 模块不 import `AuthStore`、不 import `ApiClient`，全文没有 `token` 这个词。
3. **中继侧已经有可选的账号层，且是增量、向后兼容的**：`AccountClientHello{relayToken}`、`AccountAuthorizer`、`resolvePairCode()`、`isDeviceOnline()`、`invalidateBinding()`，以及 `devices` / `accounts` / `bind_revoked` 三种附加帧（`server/src/shared/protocol-account.ts:16,41-44`、`server/src/relay/relay.ts:35,350,498,507,511`）。本任务不需要新造协议，只需要把手机端和 QFLI 账号服务接上这套既有契约。
4. **最小可行切口**：账号层只做「发现 + 授权 + 撤销」，**不动**连接路径。配对成功后仍然把 `Pairing` 存本地、仍用现有 `pairWithCode` 连中继（满足 R1/R7/AC5）。这样手动配对永远可用，账号服务挂了也不影响既有流程。
5. **一处必须注意的集成约束**：`LoginGateScope` 目前只装在 `editor_page.dart` 内（`:1442`、`:1518`），`FunctionsTab → buildStudioToolsTab → ToolsGrid` 这条链上**没有** `LoginGateScope`。因此在远程电脑模块里直接调 `ensureLoggedIn(context)` 会静默返回 `false`（`shell/login_gate.dart:34-41`），必须显式注入 `AuthStore`（见 §3.1）。

## 1. 事实核对（发布工作树）

### 1.1 Pairing URI

| 事实 | 证据 |
| --- | --- |
| 格式 `cloudterminal://pair?relay=<urlencoded ws(s)>&code=XXXXXXXX&v=1` | `models/pairing_uri.dart:14-22` |
| 版本常量 `currentVersion = 1`，scheme `cloudterminal`，host `pair` | `:25,28,31` |
| `tryParse` 宽松：找 marker、裁掉尾随空白/散文、`queryParameters` 自动解码 | `:48-85` |
| relay 必须经 `normalizeRelayUrl` 归一为 `ws`/`wss` 且带路径 | `:74-76`、`transport/relay_socket.dart:24-58` |
| 配对码 8 位、去装饰横线、大写、非字母数字剥离 | `:101-106` |
| `encode()` 生成规范串（桌面端镜像与测试用） | `:87-97` |
| 裸主机默认 `wss://`；LAN/loopback 默认 `ws://`；路径缺省 `/ws` | `transport/relay_socket.dart:31-54` |

**对本任务的约束**：账号绑定不能改这个 URI。若将来要带账号信息，只能加参数并保持 `v=1` 的解析兼容（当前 `tryParse` 会忽略未知参数，安全）。**最小方案不需要改 URI**。

### 1.2 RemoteStore

| 事实 | 证据 |
| --- | --- |
| 只存一个 `Pairing`：`_data['pairing']` | `state/remote_store.dart:100-110` |
| 文档名 `qfli_remote_control.json`，宿主私有 support 目录 | `:92`、`state/remote_store_backend.dart:14` |
| 另外只存一个字符串 `lastRelayUrl`（解绑后仍保留，省得重输地址） | `:114-117` |
| 原子写（tmp + rename），写入串行化，失败不毒化后续写 | `state/remote_store_backend_io.dart:40-49`、`remote_store.dart:127-140` |
| 损坏 JSON → 空文档，不拒绝启动 | `remote_store_backend_io.dart:27-36` |
| 存储插件缺失/文件系统错误 → 退化为内存存储 | `remote_store.dart:75-88` |
| `Pairing.toString()` 永不渲染 secret | `:47-49` |
| 明文存储、不加密，属**有意**记录的限制 | `:6-12`、`README.md`「Persistence」 |

**缺口**：`_put` 是私有的，`setString` 只收 `String`。要缓存设备列表只能新增一个类型化访问器（例如 `setJson(key, value)` / `List<RemoteDevice>? get devices`），不能复用 `setString`。

**R5 硬约束**：账号 token **不得**写进这个文档。`qfli_remote_control.json` 是「电脑配对密钥」的命名空间；账号凭据属于 `auth.json`（`store/auth_store.dart:53-91`）。同一文档混存会直接违反 R5，也会让 `document`（`@visibleForTesting`，可能进入诊断日志）变成 token 泄漏面。

### 1.3 RemoteController

| 能力 | 证据 |
| --- | --- |
| `ConnectionPhase`：`unpaired / connecting / online / agentOffline / authFailed / disconnected` | `state/remote_controller.dart:37-56` |
| `pairWithCode(relayInput, code)`：`hello{role:'pair',code}`，20s 超时，等 `paired{agentId,secret,name}` | `:202-240` |
| `pairWithQr(payload,{confirmed})`：relay 变了先返回 `needsRelayConfirm` | `:244-271`、`:65-104` |
| `pairManually(relay, agentId, secret)`：直填设备 ID + 密钥 | `:273-289` |
| `unpair()`：清 pairing/agent/sessions/views/owners，`_store.setPairing(null)`，phase→unpaired | `:291-303` |
| `connect()` / `reconnectNow()`（跳过退避；`authFailed` 走重连） | `:327-349` |
| 退避：`min(30, 2^attempt)` 秒 + 0.75–1.25 抖动，attempt 上限 6 | `:406-411` |
| 帧处理：`hello_ok` 同步 name；`presence`；`error{unauthorized}`→`authFailed`；`agent_offline`；`rate_limited`→60s | `:414-460` |
| 请求：`r<n>` id + 20s Timer，非 online 直接 `'电脑未连接'` | `:601-620` |
| 会话/终端/Herdr/Codex 全部走 `_request` | `:640-1010` |
| `dispose()` 只关本地 socket，不发 `session_close` | `:1046-1056`、`README.md`「Ownership」 |

**关键点**：`authFailed` 已经是「凭据失效」的既有语义，正好可以承载「授权被撤销」（AC4）。撤销后下一次 hello 会被中继以 `unauthorized` 拒掉 → 手机自动进入 `authFailed` → 顶部横幅「配对失效 / 重新配对」（`pages/home_screen.dart:502-548`）。这条链路不需要新 UI 概念。

### 1.4 页面与入口

| 页面 | 事实 |
| --- | --- |
| `RemoteComputerPage` | `isSupported => !kIsWeb`（`:89`）、`open(context)`（`:92`）、`_RemoteRoot` 按 `pairing == null` 在 `PairScreen`/`HomeScreen` 间切换（`:236-268`）、存活期 resumed → `reconnectNow()`（`:178-188`） |
| `PairScreen` | 三种入口 `enum _PairMethod { qr, code, manual }`（`pages/pair_screen.dart:36`）；两个大按钮 `_EntryButton`（`:267,276`）；剪贴板粘贴 + 校验回执（`:82-113`）；relay 变更确认框（`:163-190`）；`XXXX-XXXX` 格式化 `_PairCodeFormatter`（`:703-716`） |
| `HomeScreen` | 断开配对确认（`pages/home_screen.dart:270-291`，标题 `:275`）、`_Title` 状态点（`:455-500`）、`_ConnectionBanner`（`:502-548`，`重新配对` 动作 `:520-523`）、更多菜单「重新连接 / 断开配对」（`:371-395`） |
| 挂载面（app） | `work/qflistudio/lib/studio_tools_tab.dart:35-47` 唯一入口，`if (RemoteComputerPage.isSupported)` 才渲染卡片；`work/qflistudio/lib/main.dart:37` 通过 `StudioProfile.toolsTabBuilder` 接入 |
| 构建器签名 | `Widget Function(ProjectStore store, VoidCallback onOpenTerminal)` —— **没有 BuildContext，也没有 AuthStore**（`services/studio_profile.dart:184-185`、`pages/quick_tools_page.dart:28,34`） |

### 1.5 QFLI 登录态 / auth adapter

| 事实 | 证据 |
| --- | --- |
| `AuthStore`：`isLoggedIn`（token 且 user 都非空）、`token`、`user` | `store/auth_store.dart:24-27` |
| `auth.json` 只信任同源登录态：`ApiConfig.ownsSession(serviceOrigin)` 否则按未登录处理并重写 | `:38-49`、`config/api_config.dart:21-28` |
| `signIn` / `signOut`（本地先清，再异步 `/api/auth/logout`）/ `clearLocalData`（不碰服务端） | `:93,151-177` |
| `ApiConfig.baseUrl = https://qfli.suanxiwanjie.cn`，`endpoint()` 强制 `/api/` 前缀，25s 超时 | `config/api_config.dart:4-16` |
| `ApiClient` 单例，请求头 `content-type` + `x-client-platform` + `authorization: Bearer <token>` | `services/api_client.dart:215,219-223` |
| `_send()` 统一错误：`{error, requestId}` → `ApiException(message, statusCode, details)`；5xx 附带请求编号；离线模式抛 `OFFLINE_ONLY` | `:234-320`、`:226-232` |
| 登录门控：`LoginGateScope`（InheritedWidget）；`ensureLoggedIn` 未登录时 push `LoginPage` 并返回是否成功；`LoginGateCard` 是引导卡 | `shell/login_gate.dart:10-45,47-104` |
| 门控实际只装在编辑器 Agent Dock | `editor/editor_page.dart:1442,1518`（全仓仅这两处 `LoginGateScope(`） |
| 服务端：`authRequired` 验 HS256 JWT（14 天）、拉 `identity.session` 与 gateway claims，写 `req.userId`/`req.user` | `azurekiln-qfli-server/src/util.js:9,35,81-108` |
| 服务端挂载：`/api/auth`、`/api/users` 不过实名门；`/api/terminal`、`/api/sql`、`/api/ai`、posts/comments/cloud/reports 走 `realnameRequired` | `src/server.js:63-75` |
| 路由范式：`express.Router()` + `authRequired` + 按 `req.userId` 限流 + `audit(req,{action,target,detail})` | `src/routes/terminal.js:1-31` |

**结论**：账号身份用 **Studio 现有登录**（`AuthStore.token`）最省事，也与 PRD 待确认项的第一条一致；不需要在手机端再引入一套 CloudTerminal OAuth。

### 1.6 远端已有的账号层契约（可复用，不必新发明）

| 契约 | 位置 | 用途 |
| --- | --- | --- |
| `AccountClientHello{t:'hello', role:'client', agentId, relayToken}` | `protocol-account.ts:16-22` | 用账号 token 替代设备 secret 连中继 |
| `AccountRelayErrorCode` 含 `account_unavailable` | `:31-39` | **可重试**，客户端不得因此丢弃本地凭据 |
| `devices[] / accounts[] / bind_revoked` 附加帧 | `:41-44` | 设备列表、设备上的账号、撤销推送 |
| `AccountAuthorizer{available, authorizeClient(token,deviceId), invalidate}` | `relay.ts:35-39` | 中继只依赖接口，实现由 `tenancy.ts` 提供（**该文件不在本快照内**，只有注释引用） |
| `AccountClientResult` 失败原因 `no_database / invalid_token / not_bound / unavailable` | `relay.ts:27-30` | 映射到客户端错误语义 |
| `onAccountClient()`：未绑定 → `unauthorized`；库不可用 → `account_unavailable` | `relay.ts:350-384` | 撤销后自然落到 `unauthorized` |
| `resolvePairCode(code)`：**消费**一次性配对码，返回 `agentId` | `relay.ts:498-505` | HTTP 绑定 API 用它证明「设备同意」（PRD R12） |
| `isDeviceOnline(deviceId)` | `relay.ts:507-509` | 在线状态的唯一权威来源 |
| `invalidateBinding(accountId, deviceId)` | `relay.ts:511-513` | 撤销后必须调用，否则中继缓存的正向判定还有效（会破坏 AC4） |
| 配对码字母表/长度/单次使用/TTL 10s–15min | `relay-protocol.ts:50-51`、`relay.ts:236-292` | 与手机端 `normalizePairCode` 一致 |

**注意**：`server/relay-core.json` 表明 `relay.ts`、`relay-protocol.ts`、`protocol-account.ts` 是从 `cloudterminal-relay-server@841cc86` 逐文件校验同步来的（`test/relay-core-sync.test.ts` 保证字节一致）。改这三个文件要走上游同步流程，所以**最小方案不改中继核心**，只新增一个极薄的内部查询端点或复用 `Relay` 实例即可。

### 1.7 现状差距（相对 AC1–AC7）

| AC | 现状 | 缺口 |
| --- | --- | --- |
| AC1 登录用户能把电脑加入设备列表 | 无 | 缺服务端绑定表/路由、缺手机端绑定入口 |
| AC2 另一用户看不到未授权电脑 | 无 | 缺按 `user_id` 作用域的列表查询与测试 |
| AC3 识别在线/离线/已撤销 | 只有**当前链路**的 `ConnectionPhase`（`remote_controller.dart:37-56`），非列表级 | 缺设备级三态模型与展示 |
| AC4 撤销后旧凭据不能重连 | 无撤销概念 | 缺 `DELETE` + `relay.invalidateBinding` + 中继 `unauthorized` 回归 |
| AC5 手动配对仍可独立使用 | 已具备（三种方式） | 需明确「账号层关闭/失败时完全回退」并加回归 |
| AC6 绑定入口覆盖目标桌面系统 | 无 | 需确认 Windows/macOS/Linux 都能出示配对码（现有 `_HowTo` 只写 `cd server && npm run agent -- --relay …`，`pair_screen.dart:754-800`） |
| AC7 自动化覆盖 | 无 | 缺 §4 的测试点 |

## 2. 最小 API 草案

设计原则：**账号层只做发现/授权/撤销**；连接、终端、Herdr、Codex 一字不改（R7）。账号层不可用时，模块退化到今天的单机配对（R1/AC5）。

### 2.1 数据表（`azurekiln-qfli-server`）

新增一张表，SQLite 与 MySQL 都要（`db.js` 双分支：`:152-278` / `:329-530`）：

```sql
-- SQLite
CREATE TABLE IF NOT EXISTS remote_devices (
  id           TEXT PRIMARY KEY NOT NULL,      -- device_<32 hex>（entity-id.js 需新增前缀）
  user_id      TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  device_id    TEXT NOT NULL,                  -- 中继里的 agentId，非密钥
  relay_url    TEXT NOT NULL,
  label        TEXT NOT NULL DEFAULT '',
  platform     TEXT NOT NULL DEFAULT '',       -- win32 / darwin / linux
  bound_at     TEXT NOT NULL DEFAULT (datetime('now')),
  last_seen_at TEXT,
  revoked_at   TEXT,                            -- 软撤销：保留行才能显示「已撤销」
  UNIQUE (user_id, device_id)
);
CREATE INDEX IF NOT EXISTS idx_remote_devices_user ON remote_devices(user_id, revoked_at);
```

理由：
- 软撤销（`revoked_at` 非空）而不是删行，才能满足 AC3 的「已撤销」状态展示；同时 `UNIQUE(user_id, device_id)` 让重新绑定可走「复活同一行」。
- `(user_id, device_id)` 唯一、而非 `device_id` 唯一 —— 中继明确支持「一台设备同时挂多个账号」（`relay.ts:345-348` 注释），一对多必须保留。
- `entity-id.js` 的 `prefixes` 目前没有 `device` 键（`entity-id.js:3`），需新增 `device: 'device'` 才能 `createId('remote_devices')`——或直接复用 `createId` 前先加映射（与现有 `reports: 'report'` 同法）。
- 遵循现有约定：TEXT 主键、`created_at TEXT DEFAULT (datetime('now'))`、跨库时间用 `db.NOW_SQL`（毫秒，`db.js:144-147`）。

**明确不存**：设备 `secret`、账号 token。服务端只需知道「哪个人可以连哪台设备」，secret 永远只在设备与手机之间（R5）。

### 2.2 路由（新增 `src/routes/remote.js`，挂 `/api/remote`）

全部 `authRequired`（`util.js:81`）。是否加 `realnameRequired` 需产品确认：绑定本身不产出内容，但与 `/api/terminal` 同属联网服务，默认建议**加**，与 `server.js:69-75` 保持一致。

| 方法 | 路径 | 请求 | 响应 | 说明 |
| --- | --- | --- | --- | --- |
| `GET` | `/api/remote/devices` | — | `{devices:[Device]}` | 只返回 `req.userId` 名下设备（AC2） |
| `POST` | `/api/remote/devices/bind` | `{relayUrl, code}` | `201 {device: Device}` | 用一次性配对码证明设备同意；**不接受 secret** |
| `DELETE` | `/api/remote/devices/:deviceId` | — | `{device: Device}`（`status:'revoked'`） | 幂等；重复撤销返回同一结果 |
| `GET` | `/api/remote/devices/:deviceId/status` | — | `{deviceId, online, lastSeenAt}` | 单设备轻量刷新（可选，列表已含） |

`Device` 形状（与中继 `devices` 帧对齐，`protocol-account.ts:42`）：

```json
{
  "deviceId": "a_7f3c…",
  "label": "书房的台式机",
  "platform": "win32",
  "relayUrl": "wss://relay.example.com/ws",
  "status": "online | offline | revoked",
  "online": true,
  "boundAt": "2026-11-21T10:00:00Z",
  "lastSeenAt": "2026-11-21T10:04:00Z",
  "revokedAt": null
}
```

`bind` 的服务端流程（顺序重要）：

1. 校验 `relayUrl` 用的是**已配置的**中继白名单（不允许任意 URL，否则等于开放中继发现面）。
2. `normalizePairCode(code)`（`relay-protocol.ts:53-55` 语义，8 位）→ 不合法直接 400。
3. 调 `relay.resolvePairCode(code)` → 拿到 `agentId`；`null` → `410 配对码无效或已过期`（该函数本身已消费码，天然防重放）。
4. `INSERT … ON CONFLICT(user_id, device_id) DO UPDATE SET revoked_at=NULL, bound_at=now()`。
5. `audit(req, {action:'remote.bind', target:'device:'+agentId})`（对齐 `routes/terminal.js:20`）。

`DELETE` 的服务端流程：`UPDATE … SET revoked_at=now()` → `relay.invalidateBinding(req.userId, deviceId)` → `audit(req,{action:'remote.revoke'})` → 返回 `status:'revoked'`。**漏掉第 2 步会让 AC4 失败**（中继缓存的正向判定仍在）。

`online` 的算法：`status==='revoked' ? 'revoked' : (relay.isDeviceOnline(deviceId) ? 'online' : 'offline')`。`last_seen_at` 只在拿到 online 时刷新（避免把「手机刷新列表」误记为设备在线）。

### 2.3 与中继的桥接

最小形态是**服务端 → 中继的只读查询**，不新增中继帧：

- `relay.isDeviceOnline(deviceId)` 与 `relay.invalidateBinding()` 都是 `Relay` 的公开方法（`relay.ts:88-97,498-513`），QFLI 服务只要持有同一个 `Relay` 实例（同进程挂载）或走一个 `X-Relay-Key` 保护的内部端点即可。
- 若 QFLI 服务与中继不同进程（更可能的部署）：在中继侧加 **一个** 端点 `GET /internal/devices?ids=…` + `POST /internal/bindings/revoke`，用 `RELAY_INTERNAL_KEY` 做常量时间比较（`shared/crypto.ts` 已有 `hexDigestEquals`）。这属于**新增文件**，不触碰 `relay-core.json` 校验的三个文件。
- 实时性取舍：最小版**不做**列表级推送，改为「进入设备列表 / 下拉刷新 / 应用恢复前台」时刷新（`RemoteComputerPage.didChangeAppLifecycleState` 已有 resumed 钩子，`:178-188`）。当前连接的那台设备仍用 `ConnectionPhase` 实时表达，不受影响。若后续要 `devices`/`bind_revoked` 推送，中继帧已经定义好（`protocol-account.ts:41-44`），属于增量，不在本轮。

### 2.4 凭据分离（R5）落地检查表

| 项 | 结论 |
| --- | --- |
| 账号 token 存放 | 只在 `auth.json`，由 `AuthStore` 管（`auth_store.dart:53-91`）；模块只读不写 |
| 设备 secret 存放 | 只在 `qfli_remote_control.json` 的 `pairing.secret`（`remote_store.dart:23-45`） |
| HTTP 请求 | `/api/remote/*` **永不**携带 `secret`；只带 `Authorization: Bearer <token>` + `x-client-platform`（`api_client.dart:219-223`） |
| 服务端存储 | 只存 `(user_id, device_id)` 关系，无 secret、无 token |
| 日志 | `Pairing.toString()` 已脱敏（`remote_store.dart:47-49`）；新 `Device` 模型同样不得把 `secret` 放进 `toJson`/`toString` |

### 2.5 错误语义映射（手机端要做的判断）

| 服务端/中继 | 手机端表现 | 是否清本地凭据 |
| --- | --- | --- |
| `401` | 引导登录（`LoginGuideCard` 风格），并保留手动配对入口 | 否（`AuthStore` 自己会在 `refreshMe` 401 时 `signOut`，`auth_store.dart:104-107`） |
| `403 realname.required` | 提示先完成手机号实名绑定 | 否 |
| `410` 配对码无效/过期 | 文案：「配对码无效或已过期，请在电脑上按回车生成新的」——**复用现成文案**（`remote_controller.dart:1074-1085` 的 `_relayErrorText(pairing: true)`） | 否 |
| `409` 已绑定 | 视为成功（幂等）并刷新列表 | 否 |
| `5xx` / 网络失败 / `account_unavailable` | 「账号服务暂时不可用，稍后重试」+ 保留离线缓存 + 手动配对仍可用 | **否**（`protocol-account.ts:31-39` 明确要求可重试） |
| 中继 `unauthorized`（撤销后） | `ConnectionPhase.authFailed` → 横幅「配对失效 / 重新配对」（`home_screen.dart:502-520`） | 否，等用户显式 `unpair()` |

## 3. 最小 UI 草案

### 3.1 集成点：auth 必须显式注入（不能靠 `LoginGateScope`）

事实（§1.5）：`LoginGateScope` 只在编辑器里装了两次，功能页链路没有。而 `toolsTabBuilder` 签名不带 `BuildContext`、不带 `AuthStore`（`studio_profile.dart:184-185`），所以远程电脑页拿不到登录态。

**推荐最小改法（2 处，均为接线，不改模块行为）：**

1. `pages/quick_tools_page.dart`：`FunctionsTab` 增加可选 `AuthStore? auth`，在 `inlineTools(...)` 外包一层 `LoginGateScope(auth: auth!, child: …)`。与 `editor_page.dart:1442` 完全同构。
2. `pages/home_page.dart:231-246`：`FunctionsTab(store: widget.store, auth: widget.auth, …)`（`_buildPage` 已能拿到 `widget.auth`）。

之后 `RemoteComputerPage` 用 `LoginGateScope.maybeAuthOf(context)` 取 `AuthStore`；**取不到就完全按今天的行为工作**（不显示账号 UI），保证旧宿主/离线语言产品/Web 不受影响。

### 3.2 设备列表页（新增 `pages/devices_screen.dart`）

一个页面，四段结构：

```
AppBar  「我的电脑」        [刷新]
─────────────────────────────
登录引导卡（未登录时）  ← 复用 LoginGuideCard 的视觉，不自建
─────────────────────────────
[ 在线 ] 书房的台式机                ›    ← 点按 = 切换到这台
         Windows · 刚刚在线
[ 离线 ] 办公室 Mac mini             ›
         macOS · 3 小时前在线
[ 已撤销] 旧的笔记本                 ⃠     ← 不可点，右侧「重新配对」
─────────────────────────────
「没有你的电脑？」→ 手动配对（配对码 / 配对链接 / 设备 ID + 密钥）
```

- 行内状态：`online` 绿点、`offline` 灰点、`revoked` 红点 + 灰化整行。
- 「切换到这台」= 用**现有** `pairWithCode(relayUrl, code)` 或本地已存 `Pairing` 走 `connect()`；若该设备没有本地 secret，则提示「需要先在电脑上生成配对码」并跳到 `PairScreen`（预填 `relay`，`PairScreen.initialRelay` 已有此能力，`pair_screen.dart:21-27`）。
- 撤销：`AlertDialog`（照 `_confirmUnpair` 的文案风格，`home_screen.dart:270-291`）→ `DELETE` → 行变「已撤销」；若撤销的是当前连接设备，紧接 `controller.unpair()`。
- 空态/失败态都要保留「手动配对」按钮，这是 AC5 的 UI 保证。

### 3.3 状态矩阵（AC3）

| 服务端 `status` | 列表点色 | 行文案 | 点击行为 |
| --- | --- | --- | --- |
| `online` | primary（绿） | 在线 · 刚刚 | 切换并连接 |
| `offline` | outline（灰） | 离线 · N 小时前在线（`util/format.dart` 的相对时间） | 切换，进入 `agentOffline` 横幅 |
| `revoked` | error（红） | 授权已撤销 | 不可点；提供「重新配对」 |
| 列表请求失败 + 有缓存 | 缓存值 + 「⚠ 未能刷新」 | 同缓存 | 保留点击 |
| 列表请求失败 + 无缓存 | — | 「账号服务暂时不可用」 | 仅手动配对 |
| 未登录 | — | `LoginGuideCard` | 登录后自动刷新 |

**不要**把列表状态和 `ConnectionPhase` 混在一个枚举里：前者是「账号维度」，后者是「当前链路维度」。二者可以同时显示（列表说这台机器在线，链路可能仍是 `connecting`）。

### 3.4 手动配对回退（R1 / AC5）

保留**全部**三条现有路径，并且在以下四个位置都能一步到达：

| 位置 | 现状 | 需要补 |
| --- | --- | --- |
| `PairScreen` 首屏 | 已有三种入口（`pair_screen.dart:36,267,276`） | 顶部加一行「从账号选择电脑」→ 设备列表（登录后才显示） |
| `PairScreen` 手工输入区 | 已有（`_SectionHeader` 可折叠，`:389`，展开体 `:401-470`） | 不改 |
| 设备列表空态/失败态 | 无 | 加「手动配对」按钮 → 打开 `PairScreen` |
| `HomeScreen` 更多菜单 | 已有「重新连接 / 断开配对」（`:371-395`） | 加「切换电脑」→ 设备列表 |

**账号层不可用时**（`account_unavailable`、离线产品、未登录、Web）：模块行为与 `v5.0.5-remote.2` **完全一致**，一行 UI 都不多。

### 3.5 明确不做

- 不做列表级实时推送（改为进入/下拉/恢复前台刷新）。
- 不做「一台手机管理多台已配对设备并同时保活」——仍是单 `pairing`，切换即换配对（最小改动，避免动 `RemoteStore` 的单一写入语义）。
- 不做桌面端账号登录 UI（见 §5 决策 A）。
- 不做 token 加密存储改造（现有 `auth.json` 语义不变）。

## 4. 测试点

### 4.1 core 单测（`test/remote_control/`，沿用 `FakeSocket`/`healthyAgent` 夹具）

文件：`test/support/fake_relay.dart`（`FakeSocket`、`healthyAgent`）、`test/support/remote_control_app.dart`（`TestRemoteHost`、`TestControllerOwner`）。

1. `RemoteDevice.fromJson`：完整字段 / 缺 `label` / 缺 `lastSeenAt` / 未知 `status` 回落 `offline` / 多一个未知字段不崩。
2. `RemoteDevice.toJson`/`toString` **不含** `secret`、不含 `token`（断言字符串里没有这两个键）。
3. `RemoteAccountClient.list()`：200 → 列表；401 → `ApiException(statusCode:401)` 且不抛到 UI 崩溃；5xx → 保留上次缓存（内存注入）。
4. `RemoteAccountClient.bind()`：`XXXX-XXXX` 先归一为 `XXXXXXXX`；本地就拒非法码（不浪费一次服务端配额）；`410` 映射到复用文案（`remote_controller.dart:1074-1085` 的 `_relayErrorText`）；`409` 当作成功。
5. `RemoteAccountClient.revoke()`：成功 → 该行 `status=='revoked'`；失败 → 行状态不变且抛可读错误。
6. `StudioProfile.offlineOnly == true` 时所有账号调用抛 `OFFLINE_ONLY`（`api_client.dart:226-232` 的既有语义）。
7. `RemoteStore` 新增设备缓存：round-trip；`document` 的键集合**只**允许 `pairing` / `lastRelayUrl` / `devices`（不含 `token`）；损坏 JSON 仍回落到空文档（`remote_store_backend_io.dart:27-36`）。
8. **不回归**：`pairing` 仍为单值，`setPairing(null)` 后 `lastRelayUrl` 保留（`remote_store.dart:114-117`）。

### 4.2 服务端（`azurekiln-qfli-server`，Node 测试，对齐 `test/terminal-routes.test.js` 风格）

新增 `test/remote-routes.test.js`：

1. 无 token → 4 条路由全 `401`。
2. `GET /devices` 只返回本用户（造两个用户各绑一台，互相看不到）——**AC2**。
3. `bind`：正常 → `201` + 行落库 + `audit_logs` 有 `remote.bind`。
4. `bind` 重放同一配对码 → `410`（`resolvePairCode` 单次消费，`relay.ts:498-505`）。
5. `bind` 非法码格式 → `400`，且**不**调用 `resolvePairCode`。
6. `bind` 同一 `(user, device)` 二次 → 幂等 `201`/`200`，不产生第二行。
7. `revoke`：非本人设备 → `404`（不用 403，避免枚举）；本人 → `200` + `revoked_at` 非空 + 调 `relay.invalidateBinding` **恰好一次**（mock 断言）+ `audit_logs` 有 `remote.revoke`。
8. `revoke` 幂等：重复调用仍 `200`，`invalidateBinding` 不重复计数（或允许重复但状态不变）。
9. 在线状态：`isDeviceOnline=true` → `status:'online'`；`false` → `'offline'`；`revoked_at` 非空时**即使**设备在线也返回 `'revoked'`——**AC3**。
10. `last_seen_at` 只在 online 时推进。
11. 用户注销（`ON DELETE CASCADE`）后无残留行。

### 4.3 中继契约（上游 `relay.test.ts` 风格，可只读断言）

1. `relayToken` hello 命中已绑定账号 → `hello_ok`；未绑定 → `error{unauthorized}`。
2. `invalidateBinding` 之后同一 token 再连 → `unauthorized`——**AC4**。
3. 账号库不可用 → `account_unavailable`（客户端必须重试而非清凭据）。
4. 老客户端（只带 `secret`）在开启账号层时行为**字节不变**——**AC5** 的服务端侧。

### 4.4 Widget（`testWidgets`，用 `TestRemoteHost` 以「第二条路由」挂载，与真实宿主一致）

1. 未登录 → 设备列表显示登录引导，且「手动配对」仍可点。
2. 列表三态渲染：online/offline/revoked 的点色、文案、`revoked` 行不可点。
3. 撤销确认框：取消 → 不发请求；确认 → 行变已撤销。
4. 撤销当前连接设备 → 触发 `unpair()` 并回到 `PairScreen`。
5. 列表请求失败 + 无缓存 → 只剩手动配对；`PairScreen` 三条路径都可达。
6. 账号接口 401 → 引导登录，不把用户踢出已配对会话。
7. **不回归**：`kIsWeb` 仍显示「当前平台不支持远程电脑」（`remote_computer_page.dart:89`、`:382`）；无账号注入时页面与今天完全一致。

### 4.5 跨平台回归（AC6 / R8）

1. Windows：`start.cmd` 起 agent → 终端打印配对码与配对链接 → 手机 `bind` 成功。
2. macOS：`start.sh` 同上。
3. Linux：`start.sh` 同上。
4. 手机端：Android + OpenHarmony 各跑一次「绑定 → 列表显示在线 → 撤销 → 再连接被拒（`authFailed`）」。
5. 无账号后端（旧部署）配置下，整包行为等同 `v5.0.5-remote.2`。

### 4.6 AC 覆盖矩阵

| AC | 主要测试点 |
| --- | --- |
| AC1 | 4.2-3、4.4-2 |
| AC2 | 4.2-2、4.2-7 |
| AC3 | 4.2-9、4.1-1、4.4-2 |
| AC4 | 4.3-2、4.4-4 |
| AC5 | 4.3-4、4.4-5、4.5-5、4.1-8 |
| AC6 | 4.5-1/2/3 |
| AC7 | 全部（4.1–4.5） |

## 5. 待决策（对应 PRD「待确认的产品决策」）

**A. 账号身份用 Studio 登录还是中继独立 OAuth？**
建议 **Studio 登录**。理由：`AuthStore` 已有稳定 token（14 天，`util.js:9`）、已有同源校验（`api_config.dart:21-28`）、已有服务端 `authRequired`；中继的 `AccountAuthorizer` 是接口（`relay.ts:35-39`），让 QFLI 服务做实现方即可，不必再引入第二套 OAuth。代价：中继必须信任 QFLI 服务签发的身份（要么同进程，要么内部密钥）。

**B. Linux/macOS 用桌面助手界面还是命令行？**
建议 **保留命令行**，最小改动。现状 `_HowTo` 已给出 `cd server && npm run agent -- --relay …`（`pair_screen.dart:754-800`），三个系统的启动脚本都在（`start.cmd` / `start.sh`）。R6 只要求「显示连接信息」，那么只需把「配对码 + 配对链接 + 设备 ID」打印得更醒目、并加一句「在手机『我的电脑』里绑定」。做助手界面属于新工程，会顶掉本轮的最小范围。

**C. `/api/remote` 是否加 `realnameRequired`？**
需要拍板。建议加（与 `/api/terminal` 一致，`server.js:69`），但这会让未实名用户完全无法用账号绑定——只影响账号层，手动配对不受影响，风险可控。

**D. 撤销的粒度**
建议按「账号 × 设备」撤销（`(user_id, device_id)` 一行）。若产品要「撤销这台设备上的所有人」，则是另一个端点（`DELETE /api/remote/devices/:deviceId/all`，需要设备归属主概念），不在最小范围。

## 6. 证据索引

| 主题 | 文件:行 |
| --- | --- |
| 配对 URI 契约 | `lib/remote_control/models/pairing_uri.dart:14-22,25,28,31,48,87,101` |
| relay 归一 | `lib/remote_control/transport/relay_socket.dart:24-58` |
| 单配对存储 | `lib/remote_control/state/remote_store.dart:23,92,100,110,114,117,127` |
| 原子写 / 损坏回退 | `lib/remote_control/state/remote_store_backend_io.dart:27-49` |
| 连接阶段枚举 | `lib/remote_control/state/remote_controller.dart:37-56` |
| 三种配对入口 | `lib/remote_control/state/remote_controller.dart:202,244,273` |
| 解绑 | `lib/remote_control/state/remote_controller.dart:291` |
| 退避 | `lib/remote_control/state/remote_controller.dart:406` |
| 中继错误处理 | `lib/remote_control/state/remote_controller.dart:414-460,1074-1085` |
| 模块入口 / Web 门 | `lib/remote_control/remote_computer_page.dart:89,92,178,236,382` |
| 配对页 | `lib/remote_control/pages/pair_screen.dart:36,82,140,163,267,389,703,754` |
| 主页 / 解绑 / 横幅 | `lib/remote_control/pages/home_screen.dart:270,371,455,502` |
| 登录态 | `lib/store/auth_store.dart:24,38,93,151,165` |
| 服务地址 / 同源 | `lib/config/api_config.dart:4,18,21` |
| API 客户端 | `lib/services/api_client.dart:215,219,226,234` |
| 登录门控 | `lib/shell/login_gate.dart:10,34,47`；`lib/editor/editor_page.dart:1442,1518`（唯一两处安装点） |
| 功能页与构建器签名 | `lib/pages/quick_tools_page.dart:17,28,34`；`lib/services/studio_profile.dart:184-185`；`lib/pages/home_page.dart:231-246` |
| app 挂载 | `work/qflistudio/lib/studio_tools_tab.dart:35-47`；`work/qflistudio/lib/main.dart:37` |
| 中继账号层类型 | `source/cloudterminal/server/src/shared/protocol-account.ts:16,31,41-44` |
| 中继账号鉴权 | `source/cloudterminal/server/src/relay/relay.ts:27,35,350,498,507,511` |
| 配对码规则 | `source/cloudterminal/server/src/shared/relay-protocol.ts:50-51`；`relay.ts:236-292` |
| 中继同步约束 | `source/cloudterminal/server/relay-core.json`；`server/test/relay-core-sync.test.ts` |
| 服务端 JWT / 中间件 | `azurekiln-qfli-server/src/util.js:9,35,81` |
| 服务端挂载 / 实名门 | `azurekiln-qfli-server/src/server.js:63-75` |
| 路由范式 | `azurekiln-qfli-server/src/routes/terminal.js:1-31` |
| 表与 ID 约定 | `azurekiln-qfli-server/src/db.js:144,152,238,329`；`src/entity-id.js:3,5,11` |
| 测试夹具 | `test/support/fake_relay.dart`；`test/support/remote_control_app.dart` |

## 7. 本次未核实 / 需后续确认

1. `tenancy.ts`（`AccountAuthorizer` 的正式实现、以及中继侧「HTTP 绑定 API」）**不在** `_wt/cloudterminal-import/source` 快照里，只有 `relay.ts:35,88-97` 的注释引用。实现前需确认上游是否已有该文件，避免重复实现。
2. 中继与 QFLI 服务是否同进程部署未知，直接影响 §2.3 选「同实例调用」还是「内部端点 + `RELAY_INTERNAL_KEY`」。
3. `realnameRequired` 对 `/api/remote` 的取舍（§5 决策 C）。
4. 移动端没有二维码扫描能力：代码注释明确写「This app has no camera scanner」（`pair_screen.dart:81-86`），界面文案写「没有扫描功能」（`:379`）。绑定流程只能靠粘贴/短码，AC6 的桌面侧文案需相应调整。
