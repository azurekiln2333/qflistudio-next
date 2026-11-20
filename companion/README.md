# companion — 电脑侧组件

本目录放两件电脑侧的东西。它们都属于 Studio 的远程电脑功能，但不属于 Studio 主 App。

| 目录 | 是什么 | 谁用它 |
| --- | --- | --- |
| `remote_agent/` | Node agent 与进程内局域网中继 | 手机端远程电脑入口，以及下面的连接助手 |
| `windows_assistant/` | Flutter Windows 连接助手 | 电脑前的操作者：配对、看中继状态、探测工具 |

```
windows_assistant ──本机回环 socket──▶ remote_agent ──wss──▶ 中继 ◀──wss── 手机 (Studio)
```

连接助手不直连中继。它用 `--sidecar` 启动 agent，再在本机回环 socket 上读状态。手机端走同一条中继协议，由 Studio 共享内核的 `lib/remote_control` 实现。

## 分别独立运行

两件东西各自独立，可以只跑其中一件。

电脑侧准备（连接助手需要）：

```powershell
cd companion/remote_agent
npm ci
cd ../windows_assistant
flutter run -d windows
```

只跑 agent（无界面，供手机直接配对）：

```powershell
companion\remote_agent\start.cmd
```

只跑连接助手（agent 已由其他方式启动时，助手会自行再拉起一个）：

```powershell
companion\windows_assistant\run.cmd
```

`windows_assistant` 是独立的 Flutter 工程，不依赖 `qfli_studio_core`。`remote_agent` 是独立的 Node 工程，依赖见 `remote_agent/package.json`。

## 打包路径

| 用途 | 路径 |
| --- | --- |
| agent 入口 | `companion/remote_agent/src/agent/main.ts` |
| agent 依赖 | `companion/remote_agent/node_modules`（`npm ci` 生成，不进版本库） |
| sidecar 启动方式 | `node src/agent/main.ts --sidecar`，工作目录为 `companion/remote_agent` |
| 连接助手工程 | `companion/windows_assistant` |
| 连接助手发行产物 | `companion/windows_assistant/build/windows/x64/runner/Release` |
| 助手启动脚本 | `companion/windows_assistant/run.cmd` |

助手查找 agent 目录的顺序：

1. 环境变量 `CLOUDTERMINAL_AGENT_DIR`。
2. 当前工作目录的 `../remote_agent`。
3. 从当前运行文件所在目录向上逐级查找 `remote_agent`。发行产物在深层 `build` 目录里也能命中 `companion/remote_agent`。

Node 运行文件默认 `node.exe`（非 Windows 上为 `node`），可用 `CLOUDTERMINAL_NODE` 指定。三处路径都不存在时，助手把当前目录交给 sidecar，由 sidecar 报启动失败。助手不编造路径，也不回退到原 CloudTerminal 仓库结构。

## 在 Studio 里的入口

手机端入口只有一处，属于主 App：

| 位置 | 内容 |
| --- | --- |
| `lib/studio_tools_tab.dart` | 功能页内容：共享默认网格加一个「远程电脑」卡片 |
| `lib/main.dart` | 把 `buildStudioToolsTab` 交给 `StudioProfile.toolsTabBuilder` |
| 卡片目标 | 共享内核 `lib/remote_control/remote_computer_page.dart`（`RemoteComputerPage`） |

离线语言产品不设置 `toolsTabBuilder`，因此看不到这个在线入口。web 目标上 `RemoteComputerPage.isSupported` 为 false，卡片不渲染。

## 许可与声明

- 仓库根目录的 `LICENSE` 是 GNU GPL v3.0，覆盖本仓库整体，包括本目录。
- 上游 CloudTerminal 仓库顶层、`server/` 与 `apps/cloudterminal_windows/` 都没有提供 `LICENSE` 或 `NOTICE` 文件。本次迁移不新增、也不臆造许可证声明，只如实记录来源与提交号。
- Node 依赖的许可信息保留在 `remote_agent/package-lock.json` 中，Dart 依赖的许可信息保留在 `windows_assistant/pubspec.lock` 中。
- 手机端终端渲染用的 xterm 分支保留 MIT `LICENSE`，位于共享内核 `vendor/xterm/`。

## 身份

agent 使用 `~/.cloudterminal/agent.json`，或 `CLOUDTERMINAL_HOME` 指定的目录。

- 本迁移不读取、不复制、不覆盖已有身份文件。
- 迁移后的 agent 第一次运行时若发现该文件，就继续使用它。已配对的手机因此不受影响。
- 需要干净环境时，给测试或预览设置临时的 `CLOUDTERMINAL_HOME`。
- 身份与注册密钥以明文存放在用户私有目录。该目录不进版本库，也不进日志。

## 协议兼容

手机端、连接助手、agent 共用一套中继协议，没有另立一套。

- 帧类型、请求编号、20 秒请求超时、断线重连与按序补齐都未改写。
- sidecar 是本机附加模式。不加 `--sidecar` 时，agent 行为与原版一致。
- `cloudterminal://pair?relay=&code=&v=1` 配对链接两侧都能解析。
- 中继核心副本的来源与提交号见 `remote_agent/relay-core.json`。公网中继仍独立部署，本次不合并。

## 能力对照

| 原能力 | 状态 | 去向 |
| --- | --- | --- |
| Node agent（PTY、Claude SDK、Herdr、Codex） | 保留 | `companion/remote_agent/src/agent` |
| 进程内局域网中继 | 保留 | `companion/remote_agent/src/relay` |
| 中继协议与配对协议 | 保留 | `companion/remote_agent/src/shared` |
| 端到端与单元测试 | 保留 | `companion/remote_agent/test` |
| sidecar 本机协议 | 保留 | `companion/remote_agent/src/agent/sidecar.ts` |
| 连接助手界面（总览、工具、会话、配对、设置） | 保留 | `companion/windows_assistant/lib/screens` |
| 配对码与二维码 | 保留 | `companion/windows_assistant/lib/screens/pairing_page.dart` |
| 工具探测与绑定 | 保留 | `companion/windows_assistant/lib/screens/tools_page.dart` |
| 手机端远程终端、Herdr、Claude、Codex 界面 | 替换 | Studio 共享内核 `lib/remote_control`，不再随电脑侧重复发布 |
| 手机端外观设置（主题种子、明暗模式） | 替换 | Studio 主 App 的主题。连接助手保留自己的主题 |
| 公网中继服务部署 | 外部 | `cloudterminal-relay-server` 仓库，本次不合并 |
| 开机自启与后台服务安装 | 暂缓 | 原版也没有。需要时另立任务 |

## 不做的事

- 本目录不启动任何服务。运行命令由用户手动运行。
- 不迁移账号、计费或登录状态。
- 不复制签名材料、构建产物、缓存或原仓库的 Git 元数据。
- 不改动公网中继协议，也不要求它随本次迁移发布。
