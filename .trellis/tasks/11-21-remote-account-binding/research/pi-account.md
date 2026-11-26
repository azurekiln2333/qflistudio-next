# 远程电脑账号绑定调研（pi-account）

> 范围：QFLI Studio 共享内核、QFLI 后端、CloudTerminal Relay、桌面 Agent。只读源码与文档，未读取 `.env`、数据库凭据、令牌或密钥。
>
> 结论：**采用 Studio 当前 QFLI 登录作为唯一产品身份，账号主键用网关 `sub`（QFLI `users.gateway_user_id`）；QFLI 后端签发 60 秒单次、audience 受限的 relay grant，relay 通过 introspection 换取自己的 access/refresh；设备绑定必须同时有账号授权和设备同意；撤销绑定必须撤销对应 token 并断开已建立连接。**

---

## 1. 账号模型

### 1.1 QFLI 侧

`azurekiln-qfli-server` 的身份模型（`README.md`、`src/db.js`）：

```sql
users (
  id              -- user_ + 32 位随机十六进制，QFLI 本地业务 ID
  gateway_user_id -- 网关 userinfo 的 sub，唯一、区分大小写
)
auth_sessions (
  id, user_id, credentials, access_expires_at, expires_at
)
```

- 用户名、密码、邮箱、手机号、昵称、头像、角色、华为 OpenID/UnionID 均由 azurekiln OAuth2 网关保存；QFLI 不保存密码。
- `gateway_user_id` 是网关 `sub`，不是 QFLI 的 `users.id`。QFLI 的 `identity.ensureUser()` 以 `gateway_user_id` 为键建立本地用户行。
- QFLI 登录成功后，`src/routes/auth.js` 的 `loginResponse()` 只下发：
  ```json
  {"token":"<HS256 JWT>", "user":{...}}
  ```
  token payload 只有 `uid`（QFLI `users.id`）、`sid`（`auth_sessions.id`）、`exp`。
- `src/util.js`：`signToken()` 使用 **HS256**，TTL **14 天**；`verifyToken()` 校验签名、`alg=HS256`、`typ=JWT`、`exp`、`uid` 为 `user_...`、`sid` 为字符串。**没有 `iss`、`aud`、`iat`、`sub`、`scope`。**
- `authRequired` 除签名外，还会查 `auth_sessions` 行并调用网关 userinfo，确认会话未过期、用户未封禁。
- `src/identity.js`：session TTL 14 天；网关 access/refresh token 用 AES-256-GCM 加密后存在 `auth_sessions.credentials`，密钥由 `QFLI_JWT_SECRET` 派生；网关 access 快过期时后台刷新。
- 登出 `POST /api/auth/logout` 删除当前 `auth_sessions` 行；注销账号删除该用户全部 session、业务数据，并调用网关注销。

**结论：QFLI token 是第一方会话令牌，不是给第三方服务用的 OAuth access token。它没有 audience/scope，不能安全地直接交给 relay。**

### 1.2 Relay 侧

`cloudterminal-relay-server` 的账号模型（`src/db/schema.sql.ts`）：

| 表 | 关键字段 | 语义 |
| --- | --- | --- |
| `ct_accounts` | `account_id` PK, `issuer`, `display_name` | 网关身份缓存，只存 `sub`/issuer/显示名，不存密码、邮箱 |
| `ct_devices` | `device_id` PK, `label`, `platform`, `secret_hash`, `last_seen_at`, `revoked_at` | 一台电脑一行；设备 secret 只存 sha256 |
| `ct_bindings` | `account_id`, `device_id`, `role owner/member`, `status active/revoked`, `created_by` | 账号↔设备多对多；`unique(account_id,device_id)` |
| `ct_tokens` | `token_hash` PK, `account_id`, `device_id` nullable, `kind access/refresh/device`, `expires_at`, `revoked_at` | relay 自己签发的 opaque token，DB 只存哈希 |
| `ct_oauth_states` | `state` PK, `kind pkce/device`, `code_verifier`, `device_id`, `user_code`, `expires_at` | OAuth/设备流的一次性中间状态 |

`src/oauth/flows.ts` 的账号创建逻辑：OAuth 验证成功后 `upsertAccount({accountId: identity.sub, issuer: identity.issuer, displayName: identity.name})`，再签发 relay access/refresh。即 relay 的 `account_id` 本来就是 OAuth `sub`。

### 1.3 推荐账号身份

**推荐：`account_id = 网关 sub`，即 QFLI `users.gateway_user_id`。**

| 候选 | 结论 |
| --- | --- |
| 网关 `sub` / `gateway_user_id` | **采用**：稳定、opaque、唯一；QFLI 已有；relay OAuth 本来就用 `sub`；不暴露用户名/邮箱/手机号 |
| QFLI 本地 `users.id`（`user_...`） | 备选：只存在于 QFLI DB，网关/relay 不知道；QFLI DB 重建会变；需要额外映射 |
| 用户名 | 不采用：可改、可能重名/回收、PII |
| 邮箱/手机号 | 不采用：PII、可改、验证状态复杂 |
| relay 独立账号 | 最后备选：第二套账号，华为一键登录/实名/注销/封禁无法复用 |

约束：

- QFLI grant/introspection 必须返回 `sub = users.gateway_user_id`；`gateway_user_id` 为空时拒绝绑定，不要回退用户名。
- 客户端提交的 `account_id`、`gatewayUserId`、`username` 一律不可信；只从已验证 token 取。
- `ct_accounts.account_id` 目前是单列主键。MVP 只配置一个 issuer；未来多 issuer 必须把内部键改为 `issuer + '\0' + sub` 的哈希/拼接，或加 `unique(issuer, account_id)`，否则同 `sub` 会串号。
- `display_name` 只用于展示，不参与授权。

### 1.4 凭据分离

- QFLI token：只给 QFLI 后端；存 `auth.json`（当前明文，应用私有目录）。
- 设备配对 secret：只给桌面 `agent.json` 和手机 `RemoteStore`（`qfli_remote_control.json`），当前明文但独立命名空间。
- relay access/refresh：只给 relay；应新建独立 `RelayAccountStore`，不得写入 `auth.json` 或 `qfli_remote_control.json`。
- QFLI grant：只用于 relay exchange，60 秒、单次、audience 受限，不能反过来访问 QFLI 业务 API。

---

## 2. 接口边界

### 2.1 Studio 与 QFLI 后端

Studio 现有接口（`lib/services/api_client.dart`）：

- 登录：`POST /api/auth/login/requirements`、`POST /api/auth/login`
- 华为：`POST /api/auth/huawei`、`/huawei/complete`、`/huawei/bind`、`/huawei/skip`
- 注册：`POST /api/auth/register`、`POST /api/auth/email-code`、`GET /api/auth/captcha`
- 浏览器 OAuth：`GET /api/auth/oauth2/url`、`POST /api/auth/oauth2/complete`
- 登出：`POST /api/auth/logout`
- 用户：`GET/PATCH /api/users/me`；注销：`POST /api/users/me/deactivate`

边界：QFLI token 只走这些 QFLI 接口；不要发到 relay。

### 2.2 Relay 现有账号/绑定 API（`src/relay/api.ts`）

| 方法 | 路径 | 鉴权 | 作用 |
| --- | --- | --- | --- |
| POST | `/api/v1/auth/oauth/start` | 无 | Flow A：PKCE `code_challenge` → `state`、`authorize_url` |
| POST | `/api/v1/auth/oauth/complete` | 无 | Flow A：`code/state/code_verifier` → relay 凭据 |
| POST | `/api/v1/auth/device/start` | 无 | Flow B：`device_id`、可选 `label/platform/secret_hash` → `user_code` |
| POST | `/api/v1/auth/device/poll` | 无 | Flow B：`device_id/user_code` → 202 pending 或 200 凭据 |
| POST | `/api/v1/auth/token/refresh` | refresh token | 旋转 refresh，签发新 access |
| POST | `/api/v1/auth/logout` | bearer/refresh | 撤销本次提交的 token，幂等 |
| GET | `/api/v1/devices` | relay access | 当前账号的绑定设备、角色、`online`、`device_revoked` |
| POST | `/api/v1/devices/:deviceId/bindings` | relay access | `pair_code` 证明设备同意后创建/恢复绑定 |
| GET | `/api/v1/devices/:deviceId/accounts` | relay access | 只有已绑定账号能看该设备的其他账号 |
| DELETE | `/api/v1/devices/:deviceId/bindings/:accountId` | relay access | 自己撤销自己，或 owner 撤销同设备其他账号 |
| GET | `/readyz` | 无 | DB/OAuth 状态 |

WebSocket（`src/relay/relay.ts`）：

- 旧客户端：`{t:'hello',role:'client',agentId,secret}`。
- 账号客户端：`{t:'hello',role:'client',agentId,relayToken}`。
- `tenancy.authorizeClient()`：验证 token → 设备范围 → `isBound(accountId, deviceId)` → 加入 agent 的 client 集合。

### 2.3 Relay DB API

- `accounts.ts`：`upsertAccount()`、`getAccount()`。
- `bindings.ts`：`createBinding()`、`listDevicesForAccount()`、`listAccountsForDevice()`、`revokeBinding()`、`isBound()`。
- `devices.ts`：`upsertDevice()`、`touchDevice()`、`getDevice()`、`setRevoked()`。
- `tokens.ts`：`issueToken()`、`verifyToken()`、`revokeToken()`、`revokeTokenHash()`、`rotateRefresh()`、`purgeExpired()`、`countByHash()`。

### 2.4 建议新增的边界

**QFLI 后端（只给 relay 用，不对外）：**

```http
POST /api/relay/grants
Authorization: Bearer <QFLI token>
{"audience":"cloudterminal-relay","scope":"relay.connect"}

→ {"grant":"<opaque 32-byte>","expires_at":"...","audience":"cloudterminal-relay"}
```

```http
POST /api/relay/introspect
Authorization: Basic <relay-client-id:secret>
token=<grant>

→ {"active":true,"sub":"<gateway_user_id>","iss":"<QFLI issuer>","aud":["cloudterminal-relay"],"exp":...,"name":"...","scope":"relay.connect"}
```

规则：grant 只存 `sha256`；60 秒；`used_at` 单次消费；`revoked_at` 支持注销；audience/scope 精确匹配；introspection 只返回最小 claims，不记录 grant 明文。

**Relay 新增：**

```http
POST /api/v1/auth/exchange
{"grant":"..."}
→ {account_id, access_token, refresh_token, access_expires_at, refresh_expires_at}
```

```http
POST /api/v1/auth/token/refresh
{"refresh_token":"...","grant":"..."}
→ 新 access + 新 refresh
```

`exchange` 只接受 relay grant，不接受 QFLI token、不接受客户端自报 `account_id`。refresh 时 introspection 的 `sub` 必须与 refresh token 的 `account_id` 一致。

**设备绑定边界：**

- 账号侧：relay access token。
- 设备侧：现有 `pair_code`（一次性、10–15 分钟 TTL，`resolvePairCode()` 消费）或桌面设备持有证明。
- 不把设备 secret 交给手机；手机账号模式只保存 relay token。

---

## 3. 未实现项

### 3.1 Relay 未实现/不完整

**P0（阻塞验收或有安全影响）**

1. **`tenancy.authorizeClient()` 不校验 token kind。**
   `src/relay/tenancy.ts` 只检查 `deviceId` 范围和 `isBound()`，没有要求 `verified.kind === 'access'`。因此 refresh token（甚至未来的 device token）可以直接作为 WebSocket `relayToken` 使用。

2. **pair_code 绑定缺少 `ct_devices` 行。**
   `handleCreateBinding()` 直接 `createBinding()`，而 `ct_bindings.device_id` 有 FK 到 `ct_devices`。桌面 `RelayLink` 连接时只做 WS hello，不写 `ct_devices`；`upsertDevice()` 只在 `flows.startDevice()` 调用。只走过手动配对码的桌面，第一次账号绑定会因外键失败被映射成 503 `db_unavailable`。

3. **`device/start` 可被任意调用方覆盖 `secret_hash`。**
   `flows.startDevice()` 在收到 `secretHash` 时 `upsertDevice()`；`upsertDevice()` 对已存在 device 无条件 `secret_hash = values(secret_hash)`、`revoked_at = null`，而该 HTTP 路由未认证。知道 `device_id` 的调用方可覆盖真实设备记录、复活已撤销设备。

4. **`device/poll` 只用 `device_id + user_code`。**
   `pollDevice()` 按 `(device_id, user_code)` 查 `ct_oauth_states`，不要求 `state` 或网关 `device_code`。`user_code` 是显示在桌面屏幕上的短码，`device_id` 可能出现在二维码/配对链接里；同时看到两者的人可在用户批准后轮询拿到凭据。

5. **首个绑定没有 owner。**
   `handleCreateBinding()` 和 `flows.pollDevice()` 调 `createBinding()` 都不传 `role`，默认 `member`。设备上没有任何 `owner`；普通成员无法撤销其他成员绑定（`handleRevokeBinding` 要求 `own.role === 'owner'`）。

6. **撤销绑定不撤销 token、不断开连接。**
   `handleRevokeBinding()` 只 `revokeBinding()` + `onBindingRevoked()`；`main.ts` 的 `onBindingRevoked` 只调 `relay.invalidateBinding()` 清 30 秒缓存。已签发 access 仍可用 1 小时，refresh 仍可换新 access，已建立 WebSocket 不会被关闭。重新绑定后旧 token 又会恢复可用。

7. **没有设备撤销 API。**
   `devices.ts` 有 `setRevoked()`，但没有任何 HTTP 路由调用；`ct_devices.revoked_at` 只能手工改库。PRD R4 目前只能撤销账号绑定，不能撤销整台电脑。

**P1**

8. `rotateRefresh()` 没有 token family/reuse detection；旧 refresh 被攻击者先使用时可拿到新 refresh。
9. `purgeExpiredStates()` / `purgeExpired()` 没有定时调度，`ct_oauth_states`/`ct_tokens` 会累积。
10. `src/shared/protocol-account.ts` 的 `devices`、`accounts`、`bind_revoked` frame 没有发送方/使用方，是未使用协议。
11. `completeFlowA()` 换 token 固定用 `config.redirectUri`，而 `startFlowA()` 允许请求自定义 `redirect_uri`，state 行也没存该值，自定义 redirect 会失败。
12. `parseDiscoveryDocument()` 在 `OAUTH_VERIFY=introspect` 时仍强制要求 `jwks_uri`。
13. `ct_oauth_states.code_verifier` 是 `varchar(128)`，却被复用来存网关 `device_code`（代码按 4096 读取）；设备码过长会截断/报错。
14. `ct_tokens.account_id` 没有 FK；账号删除后 token 行可能残留。

### 3.2 QFLI 后端未实现

- 没有 relay grant 表/端点。
- 没有 relay introspection 端点。
- 没有“QFLI 登出/注销时撤销 relay grant 并通知 relay”的逻辑。
- QFLI 不是 OIDC provider：没有 `/.well-known/openid-configuration`、JWKS、`/oauth2/authorize`、`/oauth2/token`、`/oauth2/introspect`、设备授权端点。QFLI 只是 azurekiln 网关的 OAuth 客户端。
- 未决定远程电脑绑定是否复用实名门槛（`src/client-context.js` 的已验证手机号判断）。

### 3.3 Studio 客户端未实现

- 没有 relay grant/exchange 客户端。
- `RemoteController` 只有 `secret` hello，没有 `relayToken` hello。
- `Pairing` 只有 `relayUrl/agentId/secret/name`，没有账号模式。
- 没有设备列表/在线状态/撤销 UI。
- 没有独立 `RelayAccountStore`；不能把 relay token 写进现有 `auth.json` 或 `qfli_remote_control.json`。

### 3.4 桌面 Agent 未实现

- 不向 relay DB 注册 `ct_devices`（见 3.1-2）。
- 没有账号绑定状态展示（R6 目前只显示设备 ID/配对码）。
- `reset_pairing` 直接换 `agentId` + secret，不撤销旧 device 的绑定，会留下孤儿 `ct_bindings`。
- 没有“撤销所有账号绑定”入口；桌面转手/丢失时只能手机逐个撤销。
- 没有桌面设备流（`device/start` + 浏览器批准）的 UI；当前只有手机配对码。

---

## 4. 建议

### 4.1 推荐方案：Studio 登录 + QFLI relay grant + relay token

```text
Studio ──QFLI token──► QFLI /api/relay/grants
                         │ 验证 session + gateway sub
                         └─ 60s 单次 grant
Studio ──grant───────► Relay /api/v1/auth/exchange
                         │ 调 QFLI /api/relay/introspect
                         ├─ upsertAccount(sub)
                         └─ relay access(15m) + refresh(30d)
Studio ──relay access──► Relay /api/v1/devices、/ws (relayToken)
```

建议 TTL：

- QFLI grant：60 秒，单次。
- relay access：15 分钟（比现有 1 小时短，降低泄漏窗口）。
- relay refresh：30 天；每次 refresh 必须带新的 QFLI grant，grant 的 `sub` 必须与 refresh 的 `account_id` 一致。
- QFLI 登出后：现有 access 最迟 15 分钟失效；refresh 立即不能再用。若产品要求“立即”，QFLI 调 relay internal revoke。

### 4.2 绑定路径

**路径 A（MVP，推荐）：手机登录 + 桌面配对码。**

1. 桌面显示配对码（现有 `pair_code`）。
2. 手机已登录 QFLI，完成 grant/exchange 拿到 relay access。
3. 手机调 `POST /api/v1/devices/{deviceId}/bindings`，带 relay access + `pair_code`。
4. relay `resolvePairCode()` 消费配对码并校验 `deviceId`，创建绑定；首次 `owner`，后续 `member`。
5. 手机用 `relayToken` 连接，不保存设备 secret。

注意：现有 `pairWithCode()` 会消费配对码；账号绑定必须走独立的“绑定”按钮/接口，不能先手动配对再拿同一个码去绑定。

**路径 B（后续）：桌面设备流。**

桌面 `device/start` 显示 `user_code`，用户在浏览器批准，桌面轮询 `device/poll` 自动绑定。必须先修 3.1-3/4：设备持有证明、poll 要求 `state`/`device_code`、限流。

### 4.3 撤销与隔离

- 撤销某账号对某设备的绑定：`ct_bindings.status='revoked'` + 撤销该 `(account,device)` 的全部 token + 关闭该绑定的 WS client。
- 撤销整台设备：`ct_devices.revoked_at` + 撤销该 device 全部绑定/token + 关闭 client；Agent 重连不得自动复活，必须换新 `agentId`。
- 桌面重置身份：先生成新 `agentId`/secret，再撤销旧 device；不要复用旧 `device_id`。
- QFLI 注销账号：撤销该用户全部 grant，调 relay internal revoke，撤销全部绑定/token。
- 角色：首绑 `owner`；owner 可列设备账号、撤销成员、撤销设备；member 只能撤销自己。
- 所有查询必须带 `account_id` 条件；`GET /devices/:id/accounts` 未绑定返回 403；device-scoped token 只能操作该设备。

### 4.4 服务端改动优先级

**Relay P0：**

1. `tenancy.authorizeClient()` 要求 `kind==='access'`，并检查 `ct_devices.revoked_at is null`。
2. Agent 上线写 `ct_devices`（`onAgentRegistered` hook，传 `agentId/secretHash/name`），修复 pair_code 绑定外键。
3. `device/start` 设备持有证明；拆分 `registerDevice()`/`updateDeviceMetadata()`，禁止裸 hash 覆盖。
4. `device/poll` 要求 `state`/`device_code` + 限流。
5. 首绑 owner + 角色校验。
6. 撤销绑定联动撤销 token + 关闭 WS；新增设备撤销 API。
7. 新增 `/auth/exchange`、refresh 带 grant、`/internal/revoke-account`。
8. `ct_tokens` 加 `binding_id/binding_epoch`、`family_id`；定时清理。

**QFLI P0：**

1. `relay_grants` 表 + `POST /api/relay/grants` + `POST /api/relay/introspect`。
2. 登出/注销撤销 grant；注销调 relay internal revoke。
3. 配置 `RELAY_AUDIENCE`、relay client id/secret；secret 只存在服务端。
4. 决定是否复用实名门槛。

**Studio P0：**

1. 独立 `RelayAccountStore`；不混入 `auth.json`/`qfli_remote_control.json`。
2. 账号绑定入口 + grant/exchange；手动配对保持独立。
3. `RemoteController` 支持 `relayToken` hello；`Pairing` 区分手动/账号凭据。
4. 设备列表/在线状态/撤销 UI；日志脱敏。

**桌面 P0：**

1. 配合 relay 注册 `ct_devices`；显示设备 ID/配对码/绑定状态。
2. 重置身份前撤销旧绑定。
3. 提供“撤销所有账号绑定”入口。

### 4.5 方案备选

- **方案 B：relay 直接对接上游 azurekiln OAuth2 网关。** 适用于 QFLI 后端不能改、且网关支持 OIDC discovery/JWKS 或 introspection、以及 RFC 8628 device flow 的情况。优点：relay 不信任 QFLI 后端；缺点：用户可能要在浏览器再登录一次，华为一键登录不能直接复用，且仓库内没有网关支持 discovery/device flow 的证据。
- **方案 C：relay 独立账号。** 仅最后备选；第二套账号会割裂 QFLI 登录、实名、注销、封禁，不推荐。
- **拒绝：relay 直接接受 QFLI HS256 JWT 或共享 `QFLI_JWT_SECRET`。** 没有 audience/scope、14 天有效、无法单独撤销、密钥泄露可伪造全部会话，违反最小权限和 R5。

---

## 5. 关键风险

1. **直接复用 QFLI token 是最大风险。** QFLI token 无 `iss/aud/scope`，HS256 共享密钥；relay 若接受它，必须复制 `QFLI_JWT_SECRET`，任何一侧泄露即可伪造全部 QFLI 会话。必须走 grant 交换。
2. **现有 relay 有多个 P0 安全缺口。** 尤其 `tenancy` 不校验 token kind（refresh 可当 access）、`device/start` 可覆盖 secret hash、`device/poll` 只用 user_code、撤销绑定不撤销 token/不断开 WS。未修前不应上线账号绑定。
3. **pair_code 绑定当前真实链路会失败。** 没有 `ct_devices` 行时 `createBinding()` 外键失败；必须先让 Agent 上线写 device 或绑定接口补齐。
4. **配对码单次使用与两条流程冲突。** 手动配对和账号绑定不能复用同一个码；UI 必须让用户二选一，失败后重新生成。
5. **QFLI 登出/注销与 relay 的最终一致性。** 若不做 internal revoke，QFLI 注销后 relay access 仍可能存活至 15 分钟；产品需明确是否接受。
6. **多 issuer / 多 relay 的串号风险。** `ct_accounts.account_id` 目前单列主键；多 issuer 同 `sub` 会串号。多 relay 时固定 audience 的 grant 可能被跨 relay 尝试；建议单次消费 + 每 relay audience。
7. **本地 relay 没有账号层。** 桌面同时有本地 LAN relay 和可选远程 relay；本地 relay 默认无 DB/OAuth，账号绑定只适用于远程 relay。产品需明确范围。
8. **明文存储。** QFLI token 在 `auth.json`、配对 secret 在 `qfli_remote_control.json`，均为应用私有明文；新增 relay token 不应扩大明文面，建议后续接平台安全存储。
9. **无端到端加密。** relay 仍能读取转发内容；账号绑定只解决“谁能连”，不解决“relay 能看到什么”。
10. **账号注销残留。** QFLI 删除 `users` 后，relay 的 `ct_bindings`/`ct_tokens` 不会自动清理；需要 internal revoke 或定期对账。
11. **实名门槛未定。** 远程电脑控制比在线终端更敏感；建议复用 `hasVerifiedPhone()`，至少产品明确未实名用户是否允许绑定。
12. **网关能力未知。** 若选方案 B，必须先确认 azurekiln 网关是否提供 discovery/JWKS/introspection/device flow；当前 QFLI 代码只使用 `/oauth2/authorize`、`/oauth2/token`、`/oauth2/userinfo`。

---

## 附：关键源码索引

- QFLI Studio：`lib/store/auth_store.dart`、`lib/config/api_config.dart`、`lib/services/api_client.dart`、`lib/remote_control/state/remote_store.dart`、`lib/remote_control/state/remote_controller.dart`、`lib/remote_control/models/pairing_uri.dart`。
- QFLI 后端：`src/routes/auth.js`、`src/util.js`、`src/identity.js`、`src/db.js`、`src/client-context.js`、`README.md`。
- Relay：`src/oauth/config.ts`、`src/oauth/flows.ts`、`src/relay/api.ts`、`src/relay/tenancy.ts`、`src/relay/relay.ts`、`src/db/schema.sql.ts`、`src/db/{accounts,bindings,devices,tokens}.ts`、`src/shared/protocol-account.ts`。
- 桌面 Agent：`server/src/agent/config.ts`、`server/src/agent/link.ts`、`server/src/agent/sidecar.ts`、`server/src/agent/main.ts`。
