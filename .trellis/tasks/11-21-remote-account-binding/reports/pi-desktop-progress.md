# Pi desktop progress

工作树
- Studio：`D:/MyNewProjects/_wt/remote-account-binding/studio`（`remote/remote-account-binding-studio`，基线 `6d1b96d`）
- Core：`D:/MyNewProjects/_wt/remote-account-binding/core`（`remote/remote-account-binding-core`，基线 `72c0b09`）

状态：实现完成，允许的静态检查通过。**未运行测试 / 未构建 / 未起服务 / 未提交 / 未推送。**

## 完成项

| 项 | 状态 | 落点 |
| --- | --- | --- |
| 本机配对页（地址、码、倒计时、复制链接、二维码、刷新、离线） | 已完成 | `core/lib/remote_control/desktop/desktop_remote_page.dart` |
| 二维码复用 `qr_flutter`，不再自维护编码器 | 已完成 | `QrImageView`；自写 `qr_encoder.dart` 已删除 |
| macOS 同级 companion 目录推导（含深目录） | 已完成 | `_macOsBundleRoot` + locator 测试 |
| attach 文件路径三端与启动器一致 | 已完成 | `_attachFile` / `start.cmd` / `start.sh` |
| macOS 沙箱：用户选 `sidecar.json` | 已完成 | `_attachFilePicker` + `openFile` |
| 进程所有权在会话作用域，页面只 detach | 已完成 | `desktop_companion_session.dart`、`desktop_companion_entry.dart` |
| stop/退出的 generation 栅栏与延迟清理 | 已完成 | `stop()`、`stopAll()`、`didRequestAppExit` |
| 会话发现走真实 provider，支持只读 | 已完成 | `desktop-discovery.ts`、`tool-streams.ts` `bindView` |
| Codex 分页（`nextCursor`）与去重 | 已完成 | `desktop-discovery.ts`，上限 20 页 |
| sidecar 广播只给已认证连接 | 已完成 | `broadcast()` |
| attach token 不进 stdout | 已完成 | `listening` 帧仅 `{type,port}`；token 走 0600 文件 |
| 退出时删除自己写的 attach 文件（ownership 校验） | 已完成 | `sidecar-port-file.ts` + `shutdown()` / `process.on('exit')` |
| CLI 横幅输出配对码与 `cloudterminal://pair?...` | 已完成 | `--console-pairing`，`encodePairUri`，relay 取签发码的那条 link |
| 六目标打包脚本 | 已完成 | `companion/tools/package_companion.ps1` |
| bundle 校验器 + 单测 | 已完成 | `verify_companion_bundle.mjs` / `.test.mjs` |

## 已执行的检查

| 命令 | 结果 |
| --- | --- |
| `dart analyze lib/remote_control test/remote_control/desktop` | No issues found |
| `dart format --output=none --set-exit-if-changed …` | 0 changed |
| `tsc --noEmit -p tsconfig.json`（`companion/remote_agent`） | exit 0 |
| `node --check`（两个 `.mjs`） | exit 0 |
| PowerShell `ParseFile`（全部 `.ps1`） | 全部 OK |

## 未验证项

- `flutter test test/remote_control/desktop`：未运行（约束）。
- `node --test companion/tools/verify_companion_bundle.test.mjs`、
  `desktop-discovery.test.ts`、`sidecar-port-file.test.ts`、`npm test`、`npm run e2e -- --demo`：未运行（约束）。
- 六目标真实打包、macOS Rosetta 下的 x64 打包、真机三系统配对与扫二维码。
- macOS `file_selector` 面板与 entitlements 的真实生效情况。

## 需要 Root 确认

1. `RemoteAccountScope` 挂载与登录 hook（`studio/lib/main.dart`、`studio/lib/studio_tools_tab.dart` 由 Root 接管）。
2. macOS entitlements 的 `files.user-selected.read-only`（Root 已加）。
3. CI 三系统 companion 校验与 bundle verifier 步骤（Root 已接入 `app-installers.yml`）。
4. Core 依赖 `qr_flutter: ^4.1.0` 与锁文件（Root 已加，离线解析通过）。
