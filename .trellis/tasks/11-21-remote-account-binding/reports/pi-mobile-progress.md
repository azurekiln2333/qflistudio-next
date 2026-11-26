# Pi mobile progress

工作树：`D:/MyNewProjects/_wt/remote-account-binding/core`
分支：`remote/remote-account-binding-core`（基于 `72c0b09`）
状态：实现完成，静态检查通过，**未运行测试 / 未提交 / 未推送**

## 完成项

| 项 | 状态 | 落点 |
| --- | --- | --- |
| M1 仅配对码绑定，不消耗旧配对 | 已完成 | `account_api.dart` `bind`、`remote_account_controller.dart` `bindDevice`、`account_devices_page.dart` `_bindAndConnect` |
| M2 刷新返回完整凭据（令牌 + 过期时间同源） | 已完成 | `credentialsFor` / `_refreshTokens` |
| M3 身份代次栅栏（restore/save/reset/refresh/bind/revoke） | 已完成 | `_AccountFence`、`_devicesEpoch` |
| M4 安全存储串行化，拒绝陈旧写/清 | 已完成 | `relay_credentials.dart` 版本化写穿 + `clearIf`（返回是否真清） |
| M5 身份变化立即断开 | 已完成 | `_onAuthChanged` 同步触发 `onIdentityLost`，页面退出时对账号配对 `unpair()` |
| M6 慢存储 / A→B→A / 换服务器 / 共享刷新回归 | 已完成（未运行） | `test/remote_control/account_test.dart`（35 例） |
| M7 手动配对与会话/审批路径可达 | 已完成 | `_AccountEntry` 叠加式入口、设备页「改用配对码或密钥连接」、手动配对用例 |

## 本轮新增的接线

- `lib/app.dart`：`home` 外包 `RemoteAccountScope(auth: widget.auth)`，全应用只有
  一个 `AuthStore`，没有第二份 `auth.json` 读取。
- `lib/remote_control/remote_computer_page.dart`：装配 `RemoteAccountController`、
  安装 `AccountOwnerScope` / `AccountSignInHook`，退出时 `relayTokens = null` +
  `account.dispose()`。
- `pair_screen.dart`：`_AccountEntry` 现在同时拿 `account` 与 `controller`，首绑
  用户绑定成功后可以直接连上（此前只传 `account`，会停在只能看列表的页面）。
- `remote_account_controller.dart`：`refreshDevices()` 改为返回本次刷新的列表。
  `bindDevice` 在刷新后用该列表中的同 `device_id` 行作为结果（绑定响应只有
  `ok/account_id/device_id/role`，没有在线状态），再保留栅栏检查。此前直接返回
  绑定行 → 在线电脑首绑后判成离线，不会自动连接。
- `home_screen.dart`：「我的电脑」菜单项。失效横幅区分「重新授权」（账号连接）
  与「重新配对」（手动配对）。
- `remote_computer_page.dart`：`onIdentityLost` 只在 `controller.isAccountBound`
  时 `unpair()`，不再误断手动配对。

## 静态分析结果（本轮实际运行）

| 命令 | 结果 |
| --- | --- |
| `dart format --output=none --set-exit-if-changed lib\app.dart lib\remote_control\account lib\remote_control\state lib\remote_control\pages lib\remote_control\remote_computer_page.dart test\remote_control\account_test.dart` | `Formatted 25 files (0 changed)`，exit 0 |
| `dart analyze lib\app.dart lib\remote_control\account lib\remote_control\state lib\remote_control\pages lib\remote_control\models lib\remote_control\transport lib\remote_control\widgets lib\remote_control\theme lib\remote_control\remote_computer_page.dart test\remote_control\account_test.dart` | `No issues found!` |
| `git diff --check` | exit 0 |

未通过项（不属于本人写权限）：`dart analyze lib` 全量会在
`lib/remote_control/desktop/*` 报 `AppExitResponse` 未定义、并在
`services/process_supervisor.dart` 报文件缺失。该目录是桌面 worker 的未跟踪 WIP。

## 明确未运行

`flutter test`、`dart test`、`flutter build`、`flutter analyze`（整套工程）、
任何服务 / 模拟器 / 设备工具。`test/remote_control/account_test.dart` 仅通过静态分析。

## 待 root 复核

1. relay 最终响应信封（`device_id`、`state`/`online`、时间格式）与
   `account_models.dart` 的解码是否一致。尤其是绑定响应确实不带在线状态这一点。
2. `qr_flutter 4.1.0` 依赖到位后，桌面端复用同一 QR 实现（非本 worker 范围）。
3. 云端 CI 运行 `test/remote_control/account_test.dart`（35 例）后回填结果。
4. 内存令牌限制：重启后需在「我的电脑」重新授权一次（不需要重新配对），
   若产品不接受，需要另开任务接平台安全存储。
5. `lib/remote_control/desktop/**` 的 sidecar 退出时删除端口文件。这属桌面 worker
   写权限，本 worker 未改动。

## 约束遵守

- 只改 Core 手机端账号 / 远程控制文件，未碰 Studio、`desktop/**`、
  `desktop_remote_page.dart`。
- 未改 `pubspec.yaml` / `pubspec.lock`。
- 未改 relay-core 五个同步文件、CloudTerminal 源仓库、主仓库。
- 未读取任何凭据文件（`auth.json`、`agent.json`、`.env`、令牌）。
- 未提交、未推送、未合并。