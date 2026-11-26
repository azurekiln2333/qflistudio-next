# Pi desktop 报告：本机配对页与 companion 打包

工作树
- Studio：`D:/MyNewProjects/_wt/remote-account-binding/studio`，分支 `remote/remote-account-binding-studio`（基线 `6d1b96d`）
- Core：`D:/MyNewProjects/_wt/remote-account-binding/core`，分支 `remote/remote-account-binding-core`（基线 `72c0b09`）

状态：实现完成，允许的静态检查通过。**未运行测试、未构建、未启动服务、未用设备工具、未提交、未推送。**

## 1. 目标与达成

Studio 桌面版（Windows/macOS/Linux）新增「本机配对」：显示地址、一次性配对码、倒计时、
可复制的 `cloudterminal://pair?...` 链接、二维码、刷新、离线态，并列出本机真实已有会话。
手机端「远程电脑」入口保持原样，两页职责分开：一页发布本机，一页连接别的电脑。

## 2. Core：新增 `lib/remote_control/desktop/`

| 文件 | 作用 |
| --- | --- |
| `desktop_companion_channel.dart` | 传输边界 `DesktopCompanionChannel`、行分帧 `CompanionFrameDecoder`、测试用 `FakeDesktopCompanionChannel` |
| `desktop_companion_locator.dart` | 按平台发现安装包内 companion，校验 `companion.json`/`package.json`/`src/agent/main.ts`，解析 `{port, token}` |
| `desktop_companion_platform.dart` / `_io.dart` / `_stub.dart` | 真实文件系统探测（条件导出，web 用 stub） |
| `desktop_companion_link.dart` / `_io.dart` / `_stub.dart` | `spawnAndOwn`（Windows/Linux）与 `attach`（macOS） |
| `desktop_companion_session.dart` | **进程所有权**：会话作用域持有子进程，页面只 detach |
| `desktop_companion_controller.dart` | 状态机：配对码、倒计时、离线、断线、会话发现、错误横幅 |
| `desktop_companion_entry.dart` | 工具页入口、进程注册表、退出清理 |
| `desktop_remote_page.dart` | 页面 UI |

### 2.1 macOS 安装目录推导（错误的根因已修）
`Platform.resolvedExecutable` 是 `<install>/QFLIStudio.app/Contents/MacOS/qflistudio`。
早期实现按固定次数 `_parentOf` 上溯，`~/Applications` 这类深目录会丢掉一层，拼出
`/Applications/Contents/Resources` 这样的路径。现在改为寻找**最近的 `.app` 祖先**
（`_macOsBundleRoot`，最多 8 层，遇到根停止），再由它取父目录拼同级
`QFLI Remote Companion.app/Contents/Resources/companion`。测试覆盖
`/Applications`、`~/Applications`、`/Volumes/Build/Apps`、包内自带 companion 四种布局。

### 2.2 attach 文件路径与启动器一致
| 平台 | 位置 |
| --- | --- |
| Windows | `%APPDATA%\QFLIStudio\companion\sidecar.json` |
| macOS | `~/Library/Application Support/QFLIStudio/companion/sidecar.json` |
| Linux | `${XDG_CONFIG_HOME:-~/.config}/QFLIStudio/companion/sidecar.json` |

`start.sh` 原先写 `.config`（Linux 习惯），与 mac 的读取位置不符；打包脚本现按
`uname -s` 分两支写同一份清单，`start.cmd` 用 `%APPDATA%`。三处与 `_attachFile` 严格一致。

### 2.3 macOS 沙箱：用户显式选文件
沙箱读不到真实 HOME 的 Application Support。页面在 attach 模式下提供
「选择 companion 凭据文件…」，经 `file_selector.openFile` 由用户选择 `sidecar.json`，
只读取所选文件内容，校验含 `port` 与 `token` 后才连 `127.0.0.1`。
`RemoteAccountScope` 需要的 `com.apple.security.files.user-selected.read-only`
由 Root 加入两个 entitlements 文件（本次未编辑）。

## 3. Companion（Node sidecar）

- `--port-file` 写 `{port, token}`（目录 0700、文件 0600，重写后再 chmod）。
- `--console-pairing` 才在终端打印配对码与 `cloudterminal://pair?...` 链接；
  Studio 的启动不传该参数，stdout 因此只有 JSON 帧。
- **attach token 永不写 stdout**：早期版本把 `token` 放进第一行 `listening` 帧，
  等于把能驱动本机的凭据写进终端回滚、`tee` 与 CI 日志。现在 token 只存在于 0600 文件。
- 首帧必须 `{"type":"auth","token":...}`，常量时间比较，5 秒未认证即断开。
- `broadcast()` 只发给已认证的 socket；未认证连接收不到 `snapshot`（含中继地址与设备 ID）、
  `pair_code`（配对凭据本身）与 `stream_event`（会话输出）。
- 配对 URI 统一走共享 `encodePairUri`：CLI 横幅与 sidecar 同一实现，
  relay 取**真正签发该码的那条 link 的 URL**（`RelayLink.url`），不再靠优先级猜测。

### 3.1 会话发现与打开（真实 provider）
`desktop-discovery.ts` 按既有 AgentCore 协议列举，`bindings` 不再被当作全部会话：

| 来源 | 列出 | 打开 | 输入 |
| --- | --- | --- | --- |
| Herdr | `herdr_workspaces` + `herdr_panes` | 屏幕轮询 | 否（只读） |
| Claude Code | SDK `listSessions`（`list_history` 同一加载器） | 历史转录 | 否（只读） |
| Codex | `project/list` + `thread/list`，跟随 `nextCursor`，上限 20 页 | `read()` 或 `resume()` | 仅 `canAcceptDirectInput` |

三个已修缺陷：
1. `open_session` 原先统一映射到 `daemon-history`，而该分支只认 Claude，
   Codex 打开后空白。现在 `bindView` 先按 `kind === 'codex'` 走 Codex provider。
2. `bindView` 原先先 `connected.set()` 再 `await`，失败不回滚，重试被
   `connected.has(id)` 吞掉。现在成功后才登记。
3. Codex 只读历史原先要求 `canResume`，被别的客户端占用的线程直接不可打开。
   现在 `canOpen: true`，只由 `canAcceptInput` 决定能否输入。
4. `turn.items[]` 才是文本来源，`turn.text` 不存在；按 `items` 渲染。
5. 分页：项目与线程都跟随 `nextCursor`，并按 `kind:id` 去重。

### 3.2 会话所有权（关闭页面不杀机）
早期 `controller.dispose()` → `channel.close()` → `process.cancel()`：关闭本机页会杀掉
sidecar 与全部托管会话，手机当场断开。现在：

- `DesktopCompanionSession` 是唯一所有者，注册表在进程范围内复用它。
- 页面拿 `_DetachableCompanionChannel`，`close()` 只取消自己的订阅。
- `stop()` 先递增 generation、失效在途连接，再等它收尾，最后清句柄；
  取消失败时**保留** `_spawned`，使重试仍有所有权而不是遗失句柄。
- 启动前再次检查 generation，`stop()` 期间不会落下新子进程。
- 退出：`didRequestAppExit()` 等待停止完成，`detached` 作为兜底；
  `stopAll()` 逐个停止，一个失败不阻断其余，最后再抛出首个错误。
- spawn 时 socket 连接失败会取消子进程并删除临时目录。

## 4. 打包

`companion/tools/package_companion.ps1`（六目标：windows/macos/linux × x64/arm64）
- 显式 `-Os -Arch`，不从宿主推断。
- 下载 Node 并强制校验 `SHASUMS256.txt`；`-SkipDownload` 复用也校验。
- `npm ci` 用**目标架构的 Node 运行随包 npm**，并把目标 Node 的 bin 目录前置到 `PATH`，
  结束后恢复；Apple Silicon 上产 x64 包经 Rosetta 运行，避免混入 arm64 `pty.node`。
- 生成 `companion.json`（`sandboxed`、`attach{mode,port_file,file_mode,token_bytes,handshake}`）。
- `start.cmd` / `start.sh` 传 `--sidecar --console-pairing --port-file <path>`。
- 交付前调用 verifier。

`companion/tools/verify_companion_bundle.mjs`
- 读真实二进制头（ELF / Mach-O thin+fat / PE），处理两种字节序与 fat 头端序。
- 校验 Node 与 `pty.node` 架构、必需文件、launcher、attach 契约，拒绝凭据、
  `agent.json`、`.env`、运行期 `sidecar.json`。
- CLI 入口有直接执行守卫（`fileURLToPath`，修掉 Windows 上 `new URL().pathname`
  变成 `/D:/…` 导致 CLI 不执行的问题），因此可被测试静态 import。

## 5. 已执行的检查（全部只读）

| 命令 | 结果 |
| --- | --- |
| `dart analyze lib/remote_control test/remote_control/desktop`（core） | No issues found |
| `dart format --output=none --set-exit-if-changed lib/remote_control/desktop test/remote_control/desktop` | 0 changed |
| `node node_modules/typescript/bin/tsc --noEmit -p tsconfig.json`（remote_agent） | exit 0 |
| `node --check verify_companion_bundle.mjs` / `.test.mjs` | exit 0 |
| PowerShell `Parser::ParseFile` 全部 `.ps1`（含 `package_companion.ps1`、`stage_desktop_companion.ps1`） | 全部 OK |

## 6. 未验证项（必须由云端 CI 或真机完成）

- Flutter 测试：`flutter test test/remote_control/desktop`（本会话按约束未运行）。
- Node 测试：`node --test companion/tools/verify_companion_bundle.test.mjs`、
  `desktop-discovery.test.ts`、`sidecar-port-file.test.ts`、`npm test`、
  `npm run e2e -- --demo`。
- 六目标真实打包与 `verify_companion_bundle` 在 macOS 上的 Rosetta 路径。
- macOS 真机：`file_selector` 面板、entitlements、attach 成功率。
- Windows/Linux 真机：spawn、配对码、二维码扫描、会话打开。
- 手机端扫桌面二维码的端到端配对。

## 7. 需要 Root 确认的集成点

1. `RemoteAccountScope` 挂载与 `RemoteComputerPage` 的登录 hook（Root 已接管
   `studio/lib/main.dart`、`studio/lib/studio_tools_tab.dart`）。
2. macOS 两个 entitlements 已由 Root 加 `files.user-selected.read-only`。
3. CI：`app-installers.yml` 已有 `verify-companion`（ubuntu/windows/macos-15）与
   bundle verifier 步骤；`stage_desktop_companion.ps1` 与 `package_linux.sh` 已接入。
4. Core `pubspec.yaml` / `pubspec.lock` 增加 `qr_flutter: ^4.1.0`（Root 已加并离线解析通过）。

## 8. 与 PRD 的边界

- 桌面只读：没有新增桌面输入/审批面（`input` 请求存在但页面只对 `canAcceptInput` 的
  会话开放，读来源一律隐藏）。
- 已配对数显示「未知」而非 0：中继持有权威列表，sidecar 只报 `pairingsSinceStart`。
- 不读取、不复制、不覆盖 `~/.cloudterminal/agent.json`；不显示 secret 与 attach token。
