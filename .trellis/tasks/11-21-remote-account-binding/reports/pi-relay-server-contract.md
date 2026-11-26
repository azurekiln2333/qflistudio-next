# Relay 服务契约（pi-relay-server）

状态：实现契约，供手机端 worker、桌面端 worker 与协调者冻结字段名。
本文件不含任何密钥、令牌或凭据值。

工作树：`D:/MyNewProjects/_wt/remote-account-binding/relay-server`
基线提交：`841cc86`，分支 `remote/remote-account-binding-relay`

## 1. 数据来源与信任边界

| 事实 | 取值 |
| --- | --- |
| `account_id` | QFLI `/api/relay/introspect` 返回的 `sub`（网关 `gateway_user_id`） |
| relay access / refresh | relay 自己签发的 opaque 令牌，DB 只存 `sha256` |
| QFLI grant | 60 秒、单次、audience `cloudterminal-relay`、scope `relay.connect` |
| QFLI JWT | 永不进入 relay；relay 不持有 `QFLI_JWT_SECRET` |
| 客户端自报账号 | 一律忽略；只认 introspection 的 `sub` |

## 2. 换票：`POST /api/v1/auth/exchange`

请求（`content-type: application/json`）：

```json
{"grant":"qrg_..."}
```

成功 `200`：

```json
{
  "account_id": "<gateway sub>",
  "display_name": "Ada" ,
  "access_token": "ct_...",
  "refresh_token": "ct_...",
  "token_type": "Bearer",
  "access_expires_at": "2026-11-21T12:15:00.000Z",
  "refresh_expires_at": "2026-12-21T12:00:00.000Z"
}
```

- `access_expires_at` / `refresh_expires_at` 为 ISO 8601 UTC 字符串，与既有
  `credentialsBody()` 形状一致（`oauth/complete`、`device/poll`、`token/refresh` 同形）。
- `display_name` 可空。`token_type` 固定 `Bearer`。
- access TTL 默认 15 分钟（`RELAY_ACCESS_TTL_MS`，默认改为 900000）。
- refresh TTL 默认 30 天（`RELAY_REFRESH_TTL_MS`，默认 2592000000）。
- 令牌是**账号级**（`device_id` 为 `null`）。设备作用域令牌只由设备流签发。

失败：

| 状态 | `error.code` | 含义 |
| --- | --- | --- |
| 400 | `invalid_request` | 缺少 `grant` 或格式不合法 |
| 401 | `invalid_grant` | introspection `active:false`（含已消费、过期、登出） |
| 429 | `rate_limited` | 同一 IP 失败次数超限 |
| 502 | `grant_unavailable` | QFLI introspection 网络/HTTP 故障（可重试） |
| 503 | `relay_grant_unavailable` | relay 未配置 QFLI grant（未启用账号层） |
| 503 | `db_unavailable` | 数据库不可用 |

规则：

- 每次 exchange 都会真实调用 QFLI introspection，**不缓存 `active:true`**。
- 同一个 grant 第二次 exchange 必须失败（QFLI 侧已单次消费）。
- `active:false` 是终态：relay 不重试同一 grant。

## 3. 刷新：`POST /api/v1/auth/token/refresh`

兼容旧形状，新增可选 `grant`：

```json
{"refresh_token":"ct_...","grant":"qrg_..."}
```

成功 `200`：与 exchange 同形（`account_id`、`access_token`、`refresh_token`、
`access_expires_at`、`refresh_expires_at`、`token_type`，可选 `display_name`）。

规则：

- **无 `grant` 的 refresh 是旧行为**：仅本地 rotate，供旧设备流/旧 OAuth 流签发的令牌继续工作。
- **有 `grant` 的 refresh 是账号来源（QFLI origin）**：必须调用 introspection，
  且 `sub` 必须与 refresh 令牌的 `account_id` 完全相等，否则 `401 invalid_grant`。
- 账号来源的 refresh 令牌同时带 `origin='qfli'` 与 `family_id`；刷新后新令牌继承二者。
- 账号来源的 refresh 令牌**不允许**走无 `grant` 的刷新路径（`401 grant_required`）。
- rotate 是原子条件更新（`revoked_at is null` + 未过期 + `kind='refresh'`），
  并发刷新只有一个成功。

## 4. 设备接口

全部要求 `Authorization: Bearer <access_token>`，且令牌 `kind` 必须是 `access`。

| 方法 | 路径 | 说明 |
| --- | --- | --- |
| GET | `/api/v1/devices` | 当前账号的绑定设备列表 |
| GET | `/api/v1/devices/:deviceId/accounts` | 该设备已绑定账号（须先绑定） |
| POST | `/api/v1/devices/:deviceId/bindings` | `{"pair_code":"..."}` 首次/再次绑定 |
| DELETE | `/api/v1/devices/:deviceId/bindings/:accountId` | 撤销一条绑定 |
| DELETE | `/api/v1/devices/:deviceId/bindings` | 设备 owner 撤销该设备全部绑定 |

`GET /api/v1/devices` 响应（保持既有 envelope 与 snake_case）：

```json
{
  "account_id": "...",
  "display_name": "Ada",
  "devices": [
    {
      "device_id": "...",
      "label": "desk",
      "platform": "linux",
      "role": "owner",
      "device_revoked": false,
      "online": true,
      "last_seen_at": "2026-11-21T11:59:00.000Z"
    }
  ]
}
```

`last_seen_at` 为新增字段（ISO 8601 或 `null`），旧客户端忽略即可。

绑定语义：

- 先原子消费 `pair_code`，再登记设备记录（`ct_devices` 行缺失时自动补齐，
  且**不覆盖**已有 `secret_hash`、不复活已撤销设备）。
- 设备上第一个有效绑定获得 `role: "owner"`，后续为 `"member"`。
- 重复绑定同一账号是幂等的（不重复创建、不改角色）。
- 撤销绑定后，该 `(account, device)` 的全部 access / refresh 令牌立即失效，
  已建立的 WebSocket 被关闭。

## 5. WebSocket 客户端 hello

```json
{"t":"hello","role":"client","agentId":"<deviceId>","relayToken":"ct_...","v":1}
```

- 只接受 `kind==='access'` 的令牌；refresh / device 令牌一律 `unauthorized`。
- 令牌若带设备作用域，只能连该设备。
- 连接建立后仍需存在 `active` 绑定。
- 已绑定账号的设备**不再接受**旧 `secret` hello（见 §6）。
- 错误码：`unauthorized`、`account_unavailable`、`agent_offline`、`device_revoked`。

## 6. 旧手动配对兼容边界

| 设备状态 | 旧 `secret` hello | 原因 |
| --- | --- | --- |
| 从未账号绑定 | 允许（完全不变） | 未启用账号层的部署必须继续工作 |
| 曾经账号绑定（含全部撤销后） | 拒绝 | 撤销必须终结旧凭据，不能靠 secret 复辟 |
| `ct_devices.revoked_at` 非空 | 拒绝 | 设备级撤销 |
| relay 未配置 DB | 允许 | 与今日行为一致 |

"曾经账号绑定"由 `ct_devices.account_managed` 持久标记，**单调**：一旦写入就不再清除。
`account_managed` 与 `revoked_at` 都在 `ct_devices` 行上，因此 pair-code 绑定、
设备流绑定、撤销绑定都不会改写它们。

桌面 agent 自己的注册（`role:'agent'` 的 hello + `secretHash`）**不受影响**，
它照常上线、照常接受已授权客户端。被阻断的只有未经账号授权的客户端连接。

## 7. 账号层未配置时的行为

- 没有 `DB_*`：`/api/v1/*` 与账号 hello 回 `503` / `account_unavailable`；
  旧配对码、旧 secret hello、agent 注册完全不变。
- 有 `DB_*` 但没有 QFLI grant 配置：`/auth/exchange` 回
  `503 relay_grant_unavailable`；其余旧路由（OAuth A/B 流）不变。
- `GET /readyz` 增加 `relayGrant: { configured: boolean }`，不泄漏密钥。

## 8. relay 需要的环境变量

| 名称 | 必填 | 默认 | 说明 |
| --- | --- | --- | --- |
| `RELAY_ACCESS_TTL_MS` | 否 | `900000` | access 有效期（15 分钟） |
| `RELAY_REFRESH_TTL_MS` | 否 | `2592000000` | refresh 有效期（30 天） |
| `QFLI_RELAY_BASE_URL` | exchange 必填 | 空 | QFLI 服务源站，如 `https://qfli.example` |
| `QFLI_RELAY_CLIENT_ID` | exchange 必填 | 空 | introspection Basic 用户名 |
| `QFLI_RELAY_CLIENT_SECRET` | exchange 必填 | 空 | introspection Basic 密码，不记录 |
| `QFLI_RELAY_AUDIENCE` | 否 | `cloudterminal-relay` | 期望 `aud` 成员 |
| `QFLI_RELAY_SCOPE` | 否 | `relay.connect` | 期望 `scope` |
| `QFLI_RELAY_ISSUER` | 否 | 空 | 期望 `iss`；空表示不校验 iss |
| `QFLI_RELAY_TIMEOUT_MS` | 否 | `8000` | introspection 超时 |

三项必填任一缺失即视为未配置，exchange 回 `503 relay_grant_unavailable`。

## 9. 需要 companion 同步的增补

`src/relay/relay.ts` 与 `src/shared/*` 属于与 companion 同步的 relay-core 五个文件。
本次对 relay-core 的改动（协调者负责同步）：

1. `AccountAuthorizer.authorizeClient(token, deviceId)` 语义收紧：只接受 `access`，
   并额外返回 `reason: 'device_revoked'`。
2. `AgentEntry` 记录 `secretHash` 之外新增 `accountManaged` 标记来源（由
   `AccountAuthorizer` 提供 `isAccountManaged(deviceId)`）；relay 在 secret hello
   路径上查询该标记。旧实现无该回调时行为不变。
3. `Relay.invalidateAccount(accountId)` 新增：撤销后关闭该账号的全部客户端连接。

未改动：帧类型、`msg`/`pair_*` 路由、20 秒超时语义、错误码取值集合。

## 10. 实现与验收对应

| 验收 | 落点 |
| --- | --- |
| AC5 绑定 | `POST /devices/:id/bindings` + owner 初始化 |
| AC6 撤销后旧令牌无法连接或刷新 | `revokeBindingAndTokens` + `invalidateAccount` |
| AC7 其他账号看不到未授权设备 | `listDevicesForAccount` 强制 `account_id` |
| AC8 手动配对继续可用 | `account_managed` 为空时走旧路径 |
| AC9 不泄露令牌 | 日志只记 `accountId`/`deviceId`/计数 |
| AC10 检查覆盖 | `test/relay-grant.test.ts`、`test/relay-revocation.test.ts`、`test/relay-token-kind.test.ts` |

## 11. 尚未在本机运行

按任务约束，本机未运行测试、构建或服务。新增用例的命令与未执行状态记录在
`reports/pi-relay-server.md`。
