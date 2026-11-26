# Pi mobile: 账号绑定设备（Core 手机端）

范围：`D:/MyNewProjects/_wt/remote-account-binding/core`，分支 `remote/remote-account-binding-core`。
未提交、未推送、未合并。

## 改动文件

新增：

| 文件 | 作用 |
| --- | --- |
| `lib/remote_control/account/relay_endpoint.dart` | 由 socket 地址**推导** HTTP origin，拒绝 userinfo / query / fragment |
| `lib/remote_control/account/account_models.dart` | `RelayDevice`、`RelayGrant`、`AccountDeviceCache`、`parseAccountTime` |
| `lib/remote_control/account/account_api.dart` | `QfliGrantApi`（只发 QFLI）、`RelayAccountApi`（只发 relay） |
| `lib/remote_control/account/relay_credentials.dart` | 凭据存储：接口 + 内存默认 + 版本化写穿 |
| `lib/remote_control/account/remote_account_controller.dart` | 账号状态机、设备列表、栅栏 |
| `lib/remote_control/account/account_scope.dart` | `RemoteAccountScope`（复用真实 `AuthStore`） |
| `lib/remote_control/account/account_devices_page.dart` | 「我的电脑」页 + `AccountOwnerScope` + `AccountSignInHook` |
| `test/remote_control/account_test.dart` | 账号层云回归（未在本机运行） |

修改：

| 文件 | 改动 |
| --- | --- |
| `lib/app.dart` | 在 `home` 外包一层 `RemoteAccountScope(auth: widget.auth)` |
| `lib/remote_control/remote_computer_page.dart` | 装配账号层、两个 scope、退出时释放 |
| `lib/remote_control/state/remote_controller.dart` | `PairingAuth`、`relayToken` hello、`connectAccountDevice`、generation 栅栏 |
| `lib/remote_control/state/remote_store.dart` | `Pairing` 增加 `auth` / `accountId`。新增 `getJson` / `setJson` |
| `lib/remote_control/pages/pair_screen.dart` | 未配对页顶部「我的电脑」入口，透传 controller |
| `lib/remote_control/pages/home_screen.dart` | 「我的电脑」菜单项、账号感知的失效横幅 |

未改 `pubspec.yaml` / `pubspec.lock`（root 负责 `qr_flutter 4.1.0`）。

## 契约落实

**QFLI 只到 QFLI。** `QfliGrantApi` 构造时固定 `ApiConfig.baseUrl`，发出前再比一次
`origin`。`RelayAccountApi` 拿不到会话令牌。测试断言 `Bearer <session>` 只出现在
`/api/relay/grants`，`/api/v1/*` 上从不出现。

**relay 令牌不落盘到应用文档。** 只存在 `RelayCredentialStore`（默认内存）。
`auth.json`、`qfli_remote_control.json` 里没有令牌字段。`Pairing.toJson()` 只有
`relayUrl/agentId/secret/name/auth/accountId`，账号配对 `secret` 为空。

**一次配对码只用一次。** 账号绑定走 `POST /api/v1/devices/bindings {pair_code}`，
设备 ID 由响应回填。账号流程**不**先 `pairWithCode`，否则第二次调用必然 400/410。
已知 ID 时可选 `POST /api/v1/devices/:deviceId/bindings`，两条路由同一 body。
`RelayAccountApi.bind` 签名为
`{required relay, required credentials, required pairCode, String? deviceId, abortTrigger}`
与 `RemoteAccountController.bindDevice({required pairCode, String? deviceId})` 对齐。

**首绑即连。** 绑定成功后 `bindDevice` 依次：再校验栅栏 → `refreshDevices()` →
**再次**校验栅栏与凭据归属 → 在**该次刷新返回的列表**里找同 `device_id` 的行。
绑定响应只有 `ok/account_id/device_id/role`，没有在线状态。若拿它当结果，会把
在线的电脑判成离线，首绑后不连接。因此返回的必须是列表行（缺失字段由绑定行补）。
列表里查不到时退回绑定行，那行没有在线证据，按离线处理。
设备页据此决定：在线 → 直接 `connectAccountDevice`。离线 → 提示「等电脑上线后即可连接」，
不打开只能报「电脑不在线」的 socket。
未配对用户从 `PairScreen` 进入时 `_AccountEntry` 现在同时传 `account` 与
`controller`，因此绑定成功后能真的连上并回到主页。

## 复核点

### 1. 慢速存储不得复活旧令牌

`RelayCredentialStore` 每次写/清递增 `_version`。`load()` 记录起始版本，回来时
版本变了就丢弃结果。写穿（`_writeThrough`）在 back-end 慢写返回后发现版本已变，
按当前值再写一次。`save` 先同步更新内存，再等 back-end。

`_restore()` 额外校验 `loaded.isOwnedBy(identity) && loaded.belongsTo(endpoint.key)`：
`RelayCredentials.ownerId` 记录签发时的 QFLI 用户，relay `account_id` 无法证明这点。

### 2. 身份切换立即断开

`_onAuthChanged` 全部同步完成：先把旧令牌取出、`_invalidateInFlight()`、清列表、
**同步** 调 `onIdentityLost`，再 `unawaited(clearIf(旧值))`。旧 socket 在同一轮
事件循环里就关闭，不等存储。

`RemoteComputerPage` 传入的 `onIdentityLost` 只在 `controller.isAccountBound` 时
`unpair()`：手动配对（配对码 / 链接 / 密钥）与账号无关，登出不应打断它。

### 3. 栅栏覆盖 identity + epoch + relay

`_AccountFence` 同时记录 `identity`、`epoch`、`endpoint.key`、`relayInput`。

- `_onAuthChanged` 与 `setRelayAddress` 都调 `_invalidateInFlight()`。
- 只比 identity 挡不住 A → B → A，也挡不住同账号换服务器。
- 每个 await 之后、写凭据前后、副作用前后都做校验：

| 位置 | 校验点 |
| --- | --- |
| `_restore` | `load()` 之后 |
| `authorize` | grant 之后、exchange 之后、`save` 之后（失配则 `clearIf(saved)`，不是 `clear()`） |
| `refreshDevices` | `_usableCredentials` 之后、`devices` 之后、`_saveCache` 前、`finally` 关 busy 前。另有 `_devicesEpoch` 保证后发先至 |
| `bindDevice` | 取凭据后、bind 后、`refreshDevices` 后（避免账号切换后 UI 继续 connect 旧设备） |
| `revokeDevice` | 取凭据后、revoke 后。失配返回 `false`，不写 `_devices` |
| `_refreshTokens` | grant 之后（**在调用 relay 之前**）、refresh 之后、`save` 之后 |
| `_handleFailure` | `clearIf` 之后 |

### 4. 共享刷新不并发

`credentialsFor` 遇到 `_refreshing` 非空时 `await` 它，再在**同一栅栏**下重读。
重读的是完整 `RelayCredentials`，令牌与其 `accessExpiresAt` 同源：此前把新令牌
拼回旧 `expiresAt`，导致紧随其后的 `devices/bind/revoke` 自己判过期。
刷新失败时只交回**尚未真正过期**的旧凭据，否则 `null`。

`credentialsFor` 还要 `current.accountId == accountId`、`current.isOwnedBy(identity)`、
`current.belongsTo(relayUrl)`：当前账号的令牌不会发给旧 pairing 的服务器。

### 5. 账号连接不回落密钥

`RemoteController._tokenFor` 对 `PairingAuth.relayAccount` 要求 provider 返回非空
令牌。`null`、空串、provider 抛错一律视为无授权，进入 `authFailed` 并**停止重试循环**
（`_generation++`），横幅提示「重新授权」。手动配对路径完全没变，仍发 `secret`。

`connectAccountDevice` / `_savePairing` 在 `await` 存储后比对 `_generation`：
并发切换不会二次启动连接循环。

`dispose()` 只 `_credentials.close()`（内存），不再异步 `clear()`：关闭页面不等于
登出账号，也不该删掉下次启动要用的持久副本。

### 6. 退出页面不留下账号 socket

`RemoteComputerPage.dispose()` 先解绑 `relayTokens`，再对**账号配对**调 `unpair()`，
最后才看 ownership 决定是否 `dispose()` controller。即使 controller 由页面外部注入
（host 保留它跨模块访问），页面附加的账号连接也不会留存：令牌已经随页面释放，
继续重连只会在后台反复 401。手动配对不受影响，它本来就是 host 自己的状态。

### 7. 旧请求的 401 不清新授权

`_handleFailure` 接收 `failedWith`（该请求实际携带的凭据），`clearIf` 以
`ownerId + accountId + relayUrl + accessToken` 逐项比对后才清。`clearIf` 返回是否
真清了，只有真清过才把状态降到 `needsAuthorization`。否则一个晚到的 401 会把并发
刷新或重新授权刚存的令牌抹掉，或把可用状态误报成「请重新授权」。

## 静态分析（本轮实际运行）

```
D:\ProgramFiles\flutter_ohos\bin\cache\dart-sdk\bin\dart.exe format --output=none --set-exit-if-changed lib\app.dart lib\remote_control\account lib\remote_control\state lib\remote_control\pages lib\remote_control\remote_computer_page.dart test\remote_control\account_test.dart
→ Formatted 25 files (0 changed) in 0.14 seconds
→ exit 0
```

```
dart analyze lib\app.dart lib\remote_control\account lib\remote_control\state lib\remote_control\pages lib\remote_control\models lib\remote_control\transport lib\remote_control\widgets lib\remote_control\theme lib\remote_control\remote_computer_page.dart test\remote_control\account_test.dart
→ Analyzing app.dart, account, state, pages, models, transport, widgets, theme, remote_computer_page.dart, account_test.dart...
→ No issues found!
```

```
git diff --check
→ exit 0（无空白错误）
```

```
python scripts\ste-lint-zh.py reports\pi-mobile.md
→ 硬违规 0 处，未超过 baseline 0

python scripts\ste-lint-zh.py reports\pi-mobile-progress.md
→ 硬违规 0 处，未超过 baseline 0
```

补充：整目录 `dart analyze lib\remote_control` 也 `No issues found!`。
`dart analyze lib` 全量会报 `lib/remote_control/desktop/*` 两处 `AppExitResponse`
未定义、`services/process_supervisor.dart` 缺失。该目录是桌面 worker 的未跟踪
WIP（`?? lib/remote_control/desktop/`），不在本人写权限内，未改动。

**未运行**：`flutter test`、`dart test`、`flutter build`、任何服务、模拟器或设备工具。
`test/remote_control/account_test.dart` 只做了静态分析，尚未运行。

## 云回归覆盖（`test/remote_control/account_test.dart`，35 例）

分组：`RelayEndpoint` 4、`RelayDevice` 4、device cache round trip 2、
`RelayCredentialStore` 4、`RelayAccountApi.bind` 4、`RemoteAccountController` 13、
`RemoteController account link` 4。

| 场景 | 用例 |
| --- | --- |
| 慢 `load` 不复活令牌 | `RelayCredentialStore`: *a slow load does not resurrect tokens after a clear* |
| 旧请求 401 不清新授权 | *a 401 for an old token does not clear a newer authorization* |
| 慢 `save` 不覆盖新值 | *a slow save cannot overwrite a newer save* |
| 迟到 `clearIf` 不误删 | *clearIf leaves a newer owner alone* |
| 关闭页面不删持久副本 | *close keeps the persisted copy* |
| 设备缓存往返 | *online and revoked survive a write/read cycle*、*the memo contains no credential field* |
| 仅配对码绑定只发一次 | `RelayAccountApi.bind`: *the code-only route sends one POST…* |
| 绑定响应无在线状态 | 同上断言返回行 `state == offline`（绑定行不代表在线） |
| 缺 `device_id` 报协议错 | *a code-only response without a device id is a protocol error* |
| 已知 ID 路由 | *a known-id route uses the documented path* |
| 错误不回声服务端 body | *errors never echo a server body* |
| **首绑在线 → 自动连接** | *binding reports the freshly read presence, not the bind response*（列表说在线即在线） |
| **首绑但列表未出现** | *a binding the list does not show yet stays offline*（不连 socket） |
| 慢 `_restore` + 换账号 | *a slow restore cannot reinstate tokens for a new identity* |
| A → B → A | *A → B → A does not revive the first A generation* |
| 返回后仍连旧设备 | *a late bind answer cannot hand a device to the next account* |
| 迟到撤销 | *a late revoke reports false instead of editing the new list* |
| 共享刷新 | *a shared refresh is joined, not repeated*（同时校验令牌与过期时间同源） |
| 切服务器作废在飞请求 | *switching relay invalidates an in-flight device list* |
| 令牌不外借 | *credentialsFor refuses a token issued for another relay* |
| 登出清理 | *signing out clears the tokens and reports the identity loss once* |
| 401 转重新授权 | *a rejected access token asks for re-authorization, never a secret* |
| 账号连接发 `relayToken` | *sends relayToken instead of a secret for an account pairing* |
| 无令牌不回落 | *a missing token fails authentication instead of falling back* |
| 手动配对不变 | *manual pairing still sends the device secret* |
| pairing 序列化无令牌 | *a pairing keeps no credential in its serialized form* |

## 已知限制

1. **令牌只活一次运行（重启需重新授权）。** 没有可用的平台安全存储后端
   （Core 里没有 `flutter_secure_storage`，也不愿把 bearer 写进现有明文 JSON），
   因此 `RelayCredentialStore` 默认内存模式：进程结束即丢。用户看到的是
   「授权只在本次运行中有效，重启应用后需要重新授权」（`AccountPhase.needsAuthorization`
   下的说明文字）。重启后已存储的账号配对会进入「重新授权」，点一下即可恢复，
   不需要重新配对。接 Keychain / Keystore / HUKS 时实现 `RelayCredentialBackend`
   即可，接口、`ownerId` 归属校验和版本栅栏都已就位。
2. **设备缓存写进 `qfli_remote_control.json`。** 只有 `deviceId/label/platform/
   role/state/时间戳`，带 `accountId` + `relayUrl` 双键，不匹配就不用。这是选择元数据，
   不是凭据。
3. **未验证真实 relay 响应字段。** 解码同时接受 `device_id|deviceId|id`、
   `state|online|device_revoked`、ISO8601 与 UNIX 秒。这是按
   `reports/coordinator-contract.md` 写的，需要 relay worker 的最终信封确认。
4. **未运行任何测试。** 上述 35 个用例的编译性已由 `dart analyze` 确认，运行结果待云端 CI。
