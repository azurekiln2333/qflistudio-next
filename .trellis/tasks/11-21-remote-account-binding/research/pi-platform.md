# 平台与 CI 只读调研：桌面 runner、配对助手、GitHub workflows

任务：`11-21-remote-account-binding`（远程电脑账号绑定与桌面配对）
调研对象：发布工作树 `D:/MyNewProjects/_wt/cloudterminal-import/work/qflistudio`
方式：只读静态核对（读文件、`git ls-tree` / `git show` / `git log --all`）。
未执行：build、test、service、device、中继、任何安装脚本；未读取任何凭据文件内容。

## 1. 证据基线

| 项 | 值 |
| --- | --- |
| 工作树分支 | `remote/cloudterminal-app`，HEAD `ea1da19` |
| 提交数 | 本分支 191；`main` 190；`release/v5.0.5-preview.1` 239（本分支是其祖先） |
| 工作树未提交改动 | 6 个生成文件（`*/flutter/generated_plugin*`）+ 未跟踪的 `scripts/check-remote-companion.mjs` |
| 仓库内 GitHub workflow 总数 | 1 个：`.github/workflows/app-installers.yml`（含 `.github/actions/app-setup`、`.github/actions/setup-ohos`） |
| 本工作树是否含 `.github` | **否**（`git ls-tree HEAD` 无 `.github`，磁盘上也没有） |
| 本工作树 CI 配置 | 只有根 `.cnb.yml`（CNB），构建 server / terminal / sandbox 三个镜像 |

关键事实：**全部 GitHub workflow 只存在于 `main` 的后续分支（`release/**`、`ci/**`、`merge/app`），当前发布工作树里一个都没有。**
`git log --all -- .github/workflows/remote-companion.yml` 为空——该文件名从未在任何 ref 中出现过，尽管 `scripts/check-remote-companion.mjs` 要求它存在。

## 2. 结论摘要

1. **桌面构建矩阵是完整的**：Windows x64/arm64、Linux x64/arm64、macOS x64/arm64 共 6 个安装包目标，都在 GitHub 托管 runner 上产出，且每个都有产物结构与架构校验。
2. **配对助手只覆盖 Windows**：`companion/windows_assistant` 是只有 `windows/` 平台目录的独立 Flutter 工程；macOS 与 Linux 目前只有 `companion/remote_agent/start.sh` 命令行入口，没有桌面配对界面。
3. **CI 只覆盖 Windows 助手**：`verify-companion` 跑 ubuntu-24.04 + windows-2022，`verify-assistant` 只在 windows-2022 跑并打包 `qfli-remote-assistant-*-windows-x64`。**没有任何 job 在 macOS 上跑 companion。**
4. **发布证据一致**：`v5.0.5-remote.2` 共 13 个资产、12 个 zip，其中 companion 资产只有 1 个（Windows x64，约 183 MB），无 macOS/Linux 助手包。
5. **账号层有能力、无接线**：中继协议副本里已有 `AccountClientHello` / `devices` / `accounts` / `bind_revoked` / `account_unavailable`，`relay.ts` 预留 `AccountAuthorizer` 钩子；但 agent 调 `createRelay({ logger, relayKey })` 未传 authorizer，客户端侧（Studio 共享内核）**完全没有账号/绑定代码**。
6. **签名全部是"可安装但未受信"**：Windows 未签名、Linux 未签名、macOS 仅 ad-hoc 未公证、iOS/OHOS 未签名、Android 用调试证书。CI 里没有任何签名密钥。

## 3. 桌面 runner：现有构建与校验

`app-installers.yml`（release 分支版，2118 行）的桌面 job：

| 平台 | Runner | 架构 | 主要校验 | 签名状态（workflow 自述） |
| --- | --- | --- | --- | --- |
| Windows | `windows-2022` | x64 | `flutter build windows --release`；产物 exe 存在；`dumpbin` 读 PE machine（`8664`）；捆绑 MSVC 运行库 | `unsigned (Windows SmartScreen will warn)` |
| Windows | `windows-11-arm` | arm64 | 同上，走 `flutter.bat` 以取 arm64 Dart SDK；PE machine `AA64` | 同上 |
| Linux | `ubuntu-22.04` | x64 | bundle 条目齐全、可执行位、`file` 判 ELF `x86-64`（逐个 `.so`）、RPATH；`package_linux.sh` 出 `.deb` + `.tar.gz` | `unsigned`（glibc 2.35+） |
| Linux | `ubuntu-22.04-arm` | arm64 | 同上，ELF `aarch64`，deb arch `arm64` | 同上 |
| macOS | `macos-15`（Apple Silicon） | x86_64 | `FLUTTER_XCODE_ARCHS` 交叉编译；`thin_macos_app.sh` 去通用二进制；bundle id `com.azurekiln.qfli.qflistudio`；`codesign --verify --deep --strict` 且**要求 `Signature=adhoc`**；`lipo -archs` 单架构；DMG 创建/校验/挂载复核 | `ad-hoc signature, not notarized (Gatekeeper will block the first launch)` |
| macOS | `macos-15` | arm64 | 同上 | 同上 |

补充事实：

- macOS Release 配置本身即 `CODE_SIGN_IDENTITY = "-"`（ad-hoc），`CODE_SIGN_ENTITLEMENTS = Runner/Release.entitlements`，entitlements 为 `app-sandbox` + `network.client` + `network.server`。
- Linux 的 `.desktop` 只有 `Exec`/`Name`/`Categories`，**没有** `MimeType=x-scheme-handler/cloudterminal`。
- macOS `Info.plist` **没有** `CFBundleURLTypes`；Windows runner 也没有协议注册。`cloudterminal://pair?...` 目前只是二维码/文本载荷，不是可点击的系统深链。
- 非桌面目标（仅作背景）：iOS 在 `macos-15` 出未签名 IPA（`CODE_SIGNING_ALLOWED=NO`），Android 在 `ubuntu-24.04` 用调试证书，OHOS 在 `ubuntu-22.04` 出未签名 HAP。

## 4. 配对助手（companion）的实平台覆盖

| 组件 | 实际平台 | 入口 | 界面 | 现有自动化 |
| --- | --- | --- | --- | --- |
| `companion/remote_agent`（Node agent + 进程内中继） | Windows / macOS / Linux（代码层面跨平台，`engines: node >= 23.6`） | `start.cmd`（Windows）、`start.sh`（`/bin/sh`，缺 `node_modules/node-pty` 时自动 `npm ci`） | 无界面，控制台配对横幅 | 18 个 `node --test` 用例；CI 覆盖 ubuntu-24.04 + windows-2022 |
| `companion/windows_assistant`（Flutter 助手） | **仅 Windows**（工程只有 `windows/` 平台目录） | `run.cmd` / 发行 `Start-QFLI-Remote.cmd` | 总览、工具、会话、配对（二维码 + 短码）、设置 | 本分支 2 个测试；release 分支 3 个；CI 仅 windows-2022 |

跨平台差异点（说明"代码支持"不等于"已验证"）：

- `pty.ts` 按 `process.platform === 'win32'` 选 `ComSpec` / `SHELL`，Windows 有 `node-pty` worker 泄漏的版本绑定绕过逻辑；POSIX 侧没有等价走查。
- `codex-rpc.ts` / `herdr.ts` 有 `codex.exe`、`herdr.exe` 分支；`herdr-socket.ts` 有命名管道 vs unix socket 映射。
- `tool-probe.ts` 的 `locate()` 已含 `/usr/local/bin`、`/opt/homebrew/bin`、`~/.local/bin`，即 macOS 是"写进去了但没跑过"。
- `start.sh` 自身只做 `set -eu` + `cd` + Node 版本断言 + 条件 `npm ci` + `exec node src/agent/main.ts`，CI 从未执行过它。
- 连接信息展示（PRD R6）现状：agent 控制台横幅打印局域网地址 / 外网地址 / 一次性配对码 / 设备 ID / 密钥文件路径；助手以二维码 + 短码 + 中继状态呈现。macOS/Linux 只有前者。

## 5. 账号/绑定相关的现有代码面（与 R2–R5 直接相关）

- `companion/remote_agent/src/shared/protocol-account.ts`：`AccountClientHello`（客户端用 `relayToken` 替代 device secret 的 `hello`）、`AccountRelayErrorCode`（含 `account_unavailable`）、`AccountRelayFrame`（`devices` / `accounts` / `bind_revoked`）。文件头明确写着"由 Dart 客户端镜像；采用账号登录时必须在 `lib/models/protocol.dart` 同步"。
- `companion/remote_agent/src/relay/relay.ts`：`AccountAuthorizer`（`available`、`authorizeClient(token, deviceId)`、`invalidate`）、`account` 分支的 client hello 处理、`invalidateBinding` 供 HTTP 撤销接口回调；未配置时一律回 `account_unavailable`。
- agent 侧未接线：`main.ts` 的 `createRelay({ logger: log, relayKey: localRelayKey })` 没有 `accounts`，所以进程内局域网中继的账号登录路径恒为不可用。真实账号权威在外部仓库 `cloudterminal-relay-server`（`relay-core.json` 记录 commit `841cc86e…`）。
- 客户端侧为零：共享内核 `lib/remote_control/remote_computer_page.dart` 中 `isSupported => !kIsWeb`，配对仅 `pages/pair_screen.dart` 的一次性码流程；`lib/remote_control` 全目录 grep 不到任何 account/device 绑定实现。
- `remote_agent/relay-core.json` 限定 5 个文件必须与中继仓库逐字节一致，`test/relay-core-sync.test.ts` 会在漂移时失败——**账号协议字段不能在本仓库原地改**。

## 6. 现有 CI 缺口

### 6.1 分支/工作树层面

| 缺口 | 事实 |
| --- | --- |
| 发布工作树没有任何 GitHub workflow | 本 HEAD 无 `.github`；`app-installers.yml` 只在 `release/**`、`ci/**`、`main` 之后存在 |
| trigger 覆盖不到该分支 | `on.push.branches` 为 `main`、`ci/**`、`release/**`；PR 只对 `main`。分支 `remote/cloudterminal-app` 的推送不会触发任何 job |
| 静态检查自相矛盾 | `scripts/check-remote-companion.mjs`（未跟踪）含 `workflow` 检查，要求 `.github/workflows/remote-companion.yml` 存在且 PIN 了 `azurekiln2333/qflistudio-core`、`remote/cloudterminal-core`、`remote/cloudterminal-app`、`3.27.5-ohos-1.0.1`、`12587c79…`；该文件从未提交过 ⇒ 现在跑必红 |
| 工作树与 release 分支内容漂移 | 相对 `release/v5.0.5-preview.1`，本工作树缺 `.github/**`、`tool/ci/**`（12 个脚本）、`companion/remote_agent/scripts/sidecar-smoke.ts`、`companion/windows_assistant/test/settings_page_test.dart`，且 `e2e.ts` 没有 `--demo` / `--timeout`。直接搬 release 的工作流过来，`verify-companion` 与 `verify-assistant` 会因缺命令与缺脚本失败 |
| CNB 侧不覆盖 companion | 根 `.cnb.yml` 只做三个镜像的构建与推送；release 分支版另加 `verify-flutter-workbench`（`allowFailure: true`）与 `release-apk`（secret 签名，`allowFailure: true`），仍无 companion |

### 6.2 平台层面

| 平台 | 现状 | 具体缺口 |
| --- | --- | --- |
| Windows | 最完整：`verify-companion`（windows-2022）+ `verify-assistant`（windows-2022，analyze/test/build/打包/打包后 e2e 与 first-run 配对） | 助手只出 **x64**（Studio 本体有 arm64 目标）；`start.cmd` 从未被执行；`start.cmd` 的 `pause` 分支在无人值守环境不可用 |
| Linux | `verify-companion` 的 ubuntu-24.04 覆盖 Node 层 | 无 Linux GUI 助手可测；`start.sh` 从未执行；`.deb` 安装到 `/opt` 后的启动路径未验证；`.desktop` 无 scheme handler |
| macOS | 只有 Studio 本体的 DMG 构建 | **companion 零覆盖**：`npm ci`（`node-pty` 本地编译）、`npm test`、`start.sh`、打包分发一条都没有在 macOS 上跑过；也无 macOS 助手 |
| 通用 | — | `sidecar_ipc_test.dart` 在 `../remote_agent/node_modules` 缺失时**静默跳过**（本分支未强制预装）；publisher 里 `device_validation=none` 明确声明无设备验收 |

## 7. 适合增加的 CI 检查

按"能证明什么 / 成本 / 前提"排序。全部为云端可执行，不依赖实体设备。

### P0：静态与结构（分钟级，无副作用）

1. **把 `scripts/check-remote-companion.mjs` 纳入必跑**（先提交它，或改成只检查已存在的文件）。它已覆盖：工具页入口接线、agent 布局与脚本、助手布局与 sidecar 查找顺序、禁止指向源仓库的路径、`pubspec.yaml` 相对路径、禁止入库的身份/密钥/`node_modules`、`relay-core.json` 哈希一致。
2. **工作流自检**：保留它里面"actions 必须全 SHA 固定、`PAIRED_*_COMMIT` 必须 40 位、禁止 `ref: main` 回退"的断言，并把目标文件名改成实际存在的 `app-installers.yml`（或新建 `remote-companion.yml` 后同步）。
3. **布局断言断言到"绑定入口"**：账号绑定一旦落地，用同一模式检查 `lib/remote_control` 里存在绑定页/设备列表、助手侧存在对应页面、`protocol-account.ts` 的帧名与 Dart 侧镜像一致（纯文本断言，零运行）。
4. **启动器语法检查**：`sh -n start.sh`、`node --check` 逐个 TS 入口（若走 `tsc --noEmit` 已覆盖）。注意 `start.sh` 会按需 `npm ci`，所以只能在依赖已装后跑，或只做语法检查。

### P1：companion 运行时矩阵（推荐补齐 macOS 这一格）

5. **`verify-companion` 增加 `macos-15`**：执行 `npm ci` → `npm run check` → `npm test` → `npm run e2e -- --demo --timeout 60`。
   - 能证明：`node-pty` 在 Apple Silicon/Xcode CLT 下可编译、POSIX 分支（`SHELL`、unix socket、`0600` 权限断言）成立、协议与中继逻辑在 macOS 上不崩。
   - 成本：macOS runner 计费倍率最高；建议只在 `companion/**` 路径变更与 `workflow_dispatch` 上触发，或挂在夜间。
   - 前提：需要 `e2e.ts --demo`（本工作树还没有，见 6.1）。
6. **把 `sidecar_ipc_test.dart` 的跳过改成显式失败**：`verify-assistant` 已经先 `npm ci`，可在测试前加一条 `test -d ../remote_agent/node_modules` 守卫（release 分支已有此写法），避免"跳过当通过"。
7. **启动器冒烟（可选）**：在已装依赖的前提下执行 `start.sh --help` 与 `cmd /c start.cmd --help`，断言退出码 0 且横幅包含设备 ID/中继字段。这只启动进程打印帮助后退出，不连接中继、不建会话。

### P2：分发形态（把"macOS/Linux 只有命令行"变成可验证交付）

8. **新增 Linux/macOS 的"CLI 配对包"**：仿 `package_windows_assistant.ps1` 的做法，把 `remote_agent` + 官方 Node 运行时（校验 SHA256）+ 锁定依赖打成 `qfli-remote-agent-<ver>-<os>-<arch>.tar.gz`，打完后在包内跑一次 `e2e --demo` 与 `sidecar-smoke`。
   - 能证明：用户侧无需自备 Node/编译工具链即可配对；这是 R6「电脑端在 macOS、Linux 显示连接信息」当前唯一现实路径。
   - 成本：中；可在现有 linux/macos job 内追加，不必新开 runner。
9. **打包产物元数据门禁**：把 publisher 现有的 `BUILD_INFO.txt` 字段校验（`component`、`node_version`、`signing`、`packaged_protocol_e2e`、`device_validation`、`run` 链接）扩展到新包，保持"未验证的东西必须写 none"。

### P3：账号绑定契约（不依赖公网中继）

10. **relay 层账号用例**：在 `remote_agent/test` 里用假 `AccountAuthorizer` 断言
    - 无 authorizer 时 `relayToken` 客户端得到 `account_unavailable`（不回退成 device secret 通过）；
    - 有 authorizer 时 token 与 `deviceId` 不匹配得到 `unauthorized`；
    - `invalidateBinding` 后同一 token 被拒（对应 AC4 的"撤销后旧凭据不能重连"）；
    - 两个 account 操作同一 `agentId` 时互不可见（对应 AC2 的隔离，单进程内即可构造）。
    这些全部在进程内跑，不连公网、不读真实身份。
11. **协议镜像一致性**：`pairing.ts` 与 `windows_assistant/lib/models/pairing_uri.dart` 已有双侧测试（`widget_test.dart` 断言 `cloudterminal://pair?`）。新增账号帧时按同样方式做双侧断言，Don't 让 Dart 与 TS 漂移。
12. **严禁在本仓库改中继副本**：`relay-core-sync.test.ts` 已是这样的门禁，绑定相关改动必须先去 `cloudterminal-relay-server` 再 `npm run sync-relay`。

## 8. 签名与权限限制

| 平台 | 当前签名 | 想升级需要什么 | 现实限制 |
| --- | --- | --- | --- |
| Windows | 未签名（Authenticode 缺失） | 代码签名证书（OV/EV）+ 密钥托管 + timestamp 服务 | 未签名必然触发 SmartScreen；证书是付费资产，不应进仓库，只能进 secrets/CNB 密钥仓 |
| Linux | 未签名（`.deb`/`.tar.gz` 裸分发） | 仓库级 GPG 签名 + 发布源 | 没有 apt 源就没有信任链，单文件 detached 签名收益有限 |
| macOS | 仅 ad-hoc（`CODE_SIGN_IDENTITY = "-"`），未公证 | Developer ID Application 证书 + App Store Connect API key；还需开启 Hardened Runtime 并复核 entitlements | 当前 entitlements 为 `app-sandbox` + 网络 client/server；**沙盒应用无法自行拉起 Node agent**，macOS GUI 助手若要做，必须先决定是关沙盒还是让用户手工在沙盒外启动 agent（对应 PRD 待确认项） |
| iOS | 未签名 IPA（`CODE_SIGNING_ALLOWED=NO`） | Apple 证书 + provisioning profile | 用户需自行重签 |
| OHOS | 未签名 HAP | 华为签名材料 | 同上 |
| Android | GitHub 侧调试证书；CNB 侧 `release-apk` 用 `ANDROID_KEYSTORE_BASE64` 并 `apksigner verify` 拒绝调试证书 | 已有 secret 通道 | `allowFailure: true`，且签名只在 CNB，不在 GitHub |

权限模型约束（影响 CI 可做的事）：

- GitHub workflow 顶层 `permissions: contents: read`，只有 `publish-preview` 提权到 `contents: write`；所有 checkout 都 `persist-credentials: false`。任何需要仓库写权限、installer 权限或系统服务的检查都不该进来。
- 因此"开机自启 / 后台服务安装"这类能力（`companion/README.md` 已标为暂缓）在 CI 里无法验证，只能靠设备验收。
- macOS job 发布说明明确写了用户侧绕过方式（`System Settings > Privacy & Security` 或 `xattr -dr com.apple.quarantine`），这既是文档也是限制声明。

## 9. 设备验收边界

CI 能证明（可写进自动化结论）：

- 六个桌面目标都在干净的云 runner 上构建成功，产物架构、bundle id、签名形态、归档结构正确；
- companion 协议、sidecar IPC、打包后的首次配置与局域网配对链接在**回环网络**上可用（Windows 已有，macOS/Linux 待补）；
- 产物来源可追溯（commit / SDK / Node 版本 / 运行链接 / SHA256SUMS）。

CI 不能证明（必须留在设备/人工验收清单）：

- 真实手机与真实电脑的配对、扫码（**手机端尚无相机扫码**，`install-preview.md` 明确要求手输短码）；
- 多网卡、防火墙、局域网发现与 `--public-url` 隧道场景；
- 安装器层面的体验：`msi/dmg/deb` 安装、Gatekeeper 首次拦截、SmartScreen 警告；
- 账号绑定的真实服务行为：登录、设备列表在线/离线、撤销后重连失败、跨账号隔离——这些依赖外部 `cloudterminal-relay-server` 与真实账号库；
- 系统的代理/证书拦截、企业网络下的 `wss` 行为。

建议的验收切分（供 planning 用）：

- AC5（保留手动配对）→ 可用现有回环 e2e + 打包后 first-run 覆盖，属 CI 可证。
- AC7（绑定/撤销/隔离/重连的自动化检查）→ 拆成"仓库内协议与 relay 层用例"（可 CI 化，见 P3）与"真实账号服务契约"（外部仓库，需单独证据）。
- AC1–AC4、AC6 → 需要至少一台 Windows 与一台 macOS/Linux 的实机，加上一台真实手机；`device_validation=none` 的声明在补上之前不应改成通过。

## 10. 本次未核对（按约束跳过）

- 未运行任何 build / test / service / device，因此本文所有"可用/不可用"均为静态推断，不是运行结论。
- 未读取 `~/.cloudterminal/agent.json`、`bootstrap.json`、`android/key.properties`、任何 keystore 或 secrets，仅确认这些路径已被 `.gitignore` 与 `check-remote-companion.mjs` 的 `no-secrets` 检查覆盖。
- 未访问外部仓库 `cloudterminal-relay-server`，账号层服务端实现只按 `relay-core.json` 的 commit 号与副本内容理解。
