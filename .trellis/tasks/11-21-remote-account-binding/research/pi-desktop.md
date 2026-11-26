# 桌面配对入口只读调研

- 调研对象：`D:/MyNewProjects/_wt/cloudterminal-import/work/qflistudio`（分支 `remote/cloudterminal-app`，HEAD `ea1da19`）及其并列内核 `../qfli_studio_core`。
- 方式：只读源码、脚本与文档；未运行、未修改任何代码，未读取身份文件、凭据与环境变量值。
- 结论先行：三个桌面系统目前是三条互不相同的实现，没有任何一条能把「一次性配对码」完整交给 Studio 手机端；桌面 QFLIStudio 自身没有本机配对入口。

## 1. 证据（文件 : 函数）

### 1.1 配对码是怎么产生的（三端共用）

| 环节 | 位置 |
| --- | --- |
| 生成本地码 | `companion/remote_agent/src/agent/link.ts` → `generatePairCode()`、`formatPairCode()`、`RelayLink.requestPairCode(ttlMs = 10 * 60_000)`（发 `{t:'pair_code', code, ttlMs}`，10 秒等确认） |
| 中继登记 | `companion/remote_agent/src/relay/relay.ts` → `onPairCode()`：8 位、按 `PAIR_CODE_ALPHABET` 校验、同一 agent 只保留最新一码、TTL 夹在 10 秒–15 分钟 |
| 换取凭据 | 同上 → `onPair()`（一次性 `pairCodes.delete`）、`onPairResponse()`（校验 secret 与注册哈希一致后回 `{t:'paired', agentId, secret, name}`） |
| 二维码载荷 | `companion/remote_agent/src/shared/pairing.ts` → `encodePairUri()` / `decodePairUri()`；Dart 镜像 `companion/windows_assistant/lib/models/pairing_uri.dart` 与 `qfli_studio_core/lib/remote_control/models/pairing_uri.dart` |

载荷格式固定为 `cloudterminal://pair?relay=<ws|wss>&code=<8 位>&v=1`，只含一次性码，不含长期密钥。

### 1.2 三条显示路径

**Windows（有图形界面）**

- `companion/windows_assistant/lib/main.dart` → `_CloudTerminalWindowsAppState` 创建 `SidecarClient(arguments: ['src/agent/main.ts','--sidecar'], workingDirectory: _agentDirectory())`，`initState` 里 `_controller.start()`。
- `companion/windows_assistant/lib/state/assistant_controller.dart` → `AssistantController.start()`：连上 sidecar 后立即 `probeTools()` + `requestPairCode()`；`_onMessage` 收 `pair_code` 存入 `_pairCode`。
- `companion/windows_assistant/lib/engine/sidecar_client.dart` → `SidecarClient.start()`（首行 `{"type":"listening","port":N}`，回环 socket）、`requestPairCode()`。
- `companion/remote_agent/src/agent/sidecar.ts` → `buildPairUri(display, expiresAt)`、`refreshPairCode()`（`link.isOnline` 为假则直接返回，不产码）、`snapshot()`。
- `companion/windows_assistant/lib/screens/pairing_page.dart` → `PairingPage.build`：`QrImageView(data: pair.uri, size: 220)` + `PairUri.displayCode(pair.display)`（`XXXX-XXXX`，30 号等宽字体）+ `_Countdown(expiresAt)`（秒级倒计时）+ 右上角刷新 → `controller.requestPairCode`。
- 启动方式：`companion/windows_assistant/run.cmd`（自检 Flutter/Node/VS 工作负载后 `flutter run -d windows`，缺工具链则退到 chrome 预览）；纯 agent 用 `companion/remote_agent/start.cmd`。

**macOS / Linux（只有控制台）**

- `companion/remote_agent/start.sh`：`cd "$(dirname "$0")"`，校验 Node 版本，缺依赖时 `npm ci`，然后 `exec node src/agent/main.ts "$@"`。没有 `--sidecar`，没有图形界面；`companion/windows_assistant` 只有 `windows/` 平台目录，macOS/Linux 无法构建。
- `companion/remote_agent/src/agent/main.ts` → `printPairing()`：框中打印 `│ 局域网： ws://<内网IP>:8787/ws`、可选 `│ 外网： <relay>`、`│ 配对码： XXXX-XXXX （N 分钟内有效，仅可使用一次）`、`│ 也可手动填写：设备 ID <agentId>`、`│ 密钥见 <configPath()>`。
- 触发时机：`anyOnline()`（首个链路首次上线时自动打印一次）、`readPairingInput()`（运行中按回车重印，`attach` 进本地终端）。
- 地址来源：`lanAddress()` 取第一块非内部 IPv4；`publicUrl` 由 `--public-url` / 局域网地址 / 中继地址决定。
- 首次运行还会进 `src/agent/setup.ts` → `setupConfig()`（端口、可选中继、工作目录、共享终端），同样只有终端交互。

**桌面 QFLIStudio（主 App）**

- `lib/main.dart` → `qfliStudioProfile` 的 `toolsTabBuilder: buildStudioToolsTab`。
- `lib/studio_tools_tab.dart` → `buildStudioToolsTab(store, onOpenTerminal)`：仅以 `RemoteComputerPage.isSupported` 为条件追加「远程电脑」卡片，`builder: (_) => const RemoteComputerPage()`。
- `qfli_studio_core/lib/remote_control/remote_computer_page.dart` → `RemoteComputerPage.isSupported => !kIsWeb`；无配对时进 `PairScreen`，有配对时进 `HomeScreen`。
- `qfli_studio_core/lib/remote_control/pages/pair_screen.dart` → `PairScreen` / `_PairScreenState`：`_startQr()`（粘贴链接，`_pasteLink()` 读剪贴板）、`_startCode()`（短码，`_canSubmit` 要求 8 位）、`_submit()` → `controller.pairWithCode/pairManually`、`_submitQr()` → `controller.pairWithQr`。
- 主 App 内所有 `companion` / `windows_assistant` / 「连接助手」引用为 0 处（对整个 `lib/` 检索无命中）。

## 2. 现状对照

| 维度 | Windows | macOS | Linux |
| --- | --- | --- | --- |
| 配对码展示 | 图形界面：二维码 + `XXXX-XXXX` + 倒计时 | 终端框：地址 + `XXXX-XXXX` + 设备 ID | 同 macOS |
| 图形助手 | 有（`windows_assistant`） | 无 | 无 |
| 二维码 | 有（`QrImageView`） | 无 | 无 |
| 可复制的配对链接 | 无（只渲染二维码，页面上没有 `cloudterminal://pair?...` 文本） | 无（`printPairing()` 不打印 URI） | 无 |
| 手机端可用的配对方式 | 短码 + 服务器地址（二维码需第三方扫码 App 转文本） | 短码 + 服务器地址（手抄） | 短码 + 服务器地址（手抄） |
| 中继离线时 | 配对页顶部提示「中继未连接」，不产码 | `printPairing()` 静默失败，只写日志 | 同 macOS |
| 已配对数量 | 恒显示「尚未配对」 | 无此信息 | 无此信息 |
| 账号/设备绑定 | 无 | 无 | 无 |

## 3. 缺口

1. **没有可复制链接**：手机端 `PairScreen` 明确没有摄像头（`_pasteLink()` 上方注释与页面文案），推荐路径是「在电脑上复制配对链接粘贴过来」；但三条桌面路径都不提供可复制的 `cloudterminal://pair?...`。Windows 的二维码只能靠第三方扫码器转文本，macOS/Linux 完全无解。
2. **macOS/Linux 没有界面**：`windows_assistant` 只有 `windows/` 目标；PRD 待确认项「Linux 和 macOS 使用桌面助手界面，还是保留命令行配对入口」在当前代码里实际是「只能命令行」。
3. **桌面 QFLIStudio 角色错位**：「远程电脑」卡片只按 `!kIsWeb` 门控，所以在 Windows/macOS/Linux 桌面上同样出现，点进去却是手机侧界面（粘贴链接/输短码/配对某台电脑），没有「本机作为被控端」的入口，也没有打开连接助手的入口。
4. **配对状态不可见**：`companion/remote_agent/src/agent/sidecar.ts` → `snapshot()` 里 `pairedClients: 0` 是硬编码，助手总览与设置里的「已配对手机」永远是 0；R3「手机端可查看已绑定电脑及在线状态」在桌面侧没有数据源。
5. **入口死链**：`companion/windows_assistant/lib/screens/overview_page.dart` 的「配对手机」卡片 `onTap: () => DefaultTabController.maybeOf(context)`，点击无任何反应（不会跳到配对页）。
6. **文案与实际不符**：`qfli_studio_core/lib/remote_control/pages/pair_screen.dart` 的 `_HowTo` 仍写 `cd server` / `npm run agent -- --relay wss://...`，与本仓的 `companion/remote_agent/start.cmd|start.sh` 不一致；同段「加 `--local-relay`」也只在 `start.cmd` 参数里成立。
7. **解析宽严不一致**：`companion/remote_agent/src/shared/pairing.ts` → `decodePairUri()` 强制 8 位；两份 Dart `PairUri.tryParse()` 不校验长度，仅由界面 `_canSubmit` 兜底，容易被其他调用方绕过。
8. **账号层只有协议、没有接线**：`companion/remote_agent/src/shared/protocol-account.ts` 定义了 `AccountClientHello.relayToken`、`AccountRelayFrame`（`devices` / `accounts` / `bind_revoked`）、`account_unavailable`；`src/relay/relay.ts` 有 `AccountAuthorizer`、`unavailableAccounts`（`available: false`）与 `onAccountClient()`（默认回 `account login is not configured on this relay`）。Dart 侧零引用；`qfli_studio_core/lib/remote_control/state/remote_store.dart` 的 `Pairing` 只有 `relayUrl/agentId/secret/name`，没有账号或设备标识字段——PRD R5「账号凭据与配对密钥分开保存」目前没有落点。
9. **验证缺口**：`node scripts/check-remote-companion.mjs` 在发布工作树实测退出码 1，唯一失败项是 `.github/workflows/remote-companion.yml: missing`（该 worktree 无 `.github/` 目录），且该脚本本身在 git 中未跟踪。也就是说 11-20 声称的结构门禁在当前工作树并不绿。

## 4. 建议：桌面端最小统一入口

只做「一处入口 + 一份数据」，不新增第二套协议。

**入口位置**：`lib/studio_tools_tab.dart` 的 `buildStudioToolsTab` 增加一个仅桌面可用的分组（`Platform.isWindows || Platform.isMacOS || Platform.isLinux`），卡片名为「本机配对」，builder 指向新的共享内核页面（建议 `qfli_studio_core/lib/remote_control/` 下新增 `local_pair_page.dart`，与 `PairScreen` 并列，不改 `RemoteComputerPage` 的既有语义）。

**页面内容（三个系统同一份）**：

1. 连接方式：局域网地址（`ws://<内网IP>:8787/ws`）与可选中继地址，只读展示，由 agent 侧提供。
2. 配对码：`XXXX-XXXX`；有效期倒计时；「生成新码」按钮。
3. 可复制文本：`cloudterminal://pair?relay=…&code=…&v=1`，一个「复制」按钮 —— 这是当前手机端唯一顺畅的入口。
4. 二维码：Windows 保留现有 `QrImageView` 等价渲染；macOS/Linux 同页显示（同一份 URI，不另写编码器）。
5. 状态行：中继在线/重试次数/已配对数量；数据不足时显示「未知」，不要沿用 `pairedClients: 0` 的假值。

**数据来源（按成本从低到高，先做第 1 步即可）**：

- 第 1 步：复用现有 sidecar。桌面 App 通过 `node <repo>/companion/remote_agent/src/agent/main.ts --sidecar` 起子进程，读同一套 `snapshot` / `pair_code` 帧；`buildPairUri()` 已在中继地址缺失时回退到 `relayUrl`。
- 第 2 步（可选）：sidecar 的 `snapshot()` 增加真实 `pairedClients`（来自 `relay.ts` 的 `agent.clients.size`），只加字段、不改既有字段含义。
- 第 3 步（本任务范围外）：账号绑定帧 `devices` / `bind_revoked` 的客户端接线。

**边界**：

- 不改 `relay.ts` / `relay-protocol.ts` / `protocol-account.ts` 的既有帧与字段，不改 20 秒请求超时、`seq` 去重与重连语义。
- 不重写 `PairScreen`（手机侧粘贴/短码/手动三条通道保持原样），只在同目录新增本机页面。
- 不把桌面 App 变成第二个连接助手：工具探测、会话绑定仍留在 `companion/windows_assistant`。
- 不复制、不迁移、不覆盖 `~/.cloudterminal/agent.json`；页面只显示路径，不显示密钥内容。
- 不改公网中继部署；`cloudterminal://pair` 的编码实现保持单一来源（TS 为准，Dart 镜像）。
- macOS/Linux 的 `start.sh` 控制台横幅保留作为兜底（无桌面环境时仍能配对），但应追加打印同一 `cloudterminal://pair?...` 文本。

## 5. 检查项

**自动化**

- `cd companion/remote_agent && npm test`：`test/pairing.test.ts`（URI 往返、`normalizePairCode`、拒绝异 scheme、仅 ws/wss、拒绝非 8 位）、`test/sidecar.test.ts`（JSON 行分帧与解码）。
- `cd companion/windows_assistant && flutter test`：`test/sidecar_ipc_test.dart` 用 `--local-relay --no-herdr` 起真实 sidecar，断言 `pair_code.uri` 以 `cloudterminal://pair?` 开头。
- `node scripts/check-remote-companion.mjs`：当前必须先补 `.github/workflows/remote-companion.yml`（或收敛该断言）才能作为门禁；新增入口后需同步 `host-entry` 断言。
- `flutter analyze` / `flutter test`（主 App 与 `qfli_studio_core`）。

**手工矩阵（每格都要能配对成功）**

| 场景 | 通过标准 |
| --- | --- |
| Windows 桌面 App「本机配对」 | 显示地址、`XXXX-XXXX`、可复制链接；手机短码模式与粘贴模式都能连上 |
| Windows 连接助手（`run.cmd`） | 二维码、短码、倒计时与刷新不回归 |
| Windows 纯 CLI（`start.cmd`） | 回车重印新码；旧码立即失效 |
| macOS `./start.sh` | 控制台出现地址、短码与可复制链接 |
| Linux `./start.sh` | 同上 |
| 中继离线 | 三端都提示「中继未连接」，不显示过期码，不静默假装成功 |
| 生成新码 | 旧码无法再配对（relay `onPairCode` 删除同 agent 旧码） |
| 已配对后 | 桌面状态行不再显示恒定的 0；手机端会话协议不变 |
| 日志与界面 | 任何位置不出现 `secret` / 密钥内容 |

## 6. 仍待产品决策（PRD 已列，本次调研未改）

- 账号身份用 Studio 现有登录，还是 CloudTerminal 中继的独立 OAuth：决定 `devices` 帧的 `deviceId` 与 `Pairing` 扩展字段。
- macOS/Linux 是否要真正的图形助手：若否则按上面方案 1 只补「可复制链接」，若否则需另立 Flutter 桌面目标（当前 `windows_assistant` 仅 `windows/`）。
