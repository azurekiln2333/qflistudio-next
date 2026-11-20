# windows_assistant — 远程电脑连接助手

Studio 的远程电脑功能需要一台已配对的电脑。本工程就是电脑侧的准备工具。它是独立的 Flutter Windows 应用，不依赖 Studio 主 App，也不嵌入主 App。

它做四件事：

- 启动并托管 Node agent（`../remote_agent`），由 agent 主动连出到中继。
- 显示中继在线状态、注册重试次数和最近一次错误。
- 创建一次性配对码和二维码，供手机输入或粘贴配对链接。
- 探测本机工具（Herdr、Codex、Claude），并绑定或解绑会话。

手机上的远程电脑界面在 Studio 主 App 里。两处分工不同：这里准备连接，主 App 使用连接。

## 快速开始

```powershell
cd companion/remote_agent
npm ci
cd ../windows_assistant
flutter run -d windows
```

需要 Visual Studio C++ 工作负载。缺少工具链时的替代路径、工具链安装命令和常见问题见 [LAUNCH.md](LAUNCH.md)。

## 目录

| 路径 | 作用 |
| --- | --- |
| `lib/main.dart` | 应用入口，创建 `SidecarClient` 并解析 agent 目录 |
| `lib/engine/sidecar_client.dart` | 本机回环 socket 上的 JSON 行协议客户端 |
| `lib/state/assistant_controller.dart` | 助手状态，只反映 sidecar 推送的真实数据 |
| `lib/models/pairing_uri.dart` | `cloudterminal://pair?relay=&code=&v=` 解析，与 `../remote_agent/src/shared/pairing.ts` 对齐 |
| `lib/models/tool.dart` | 快照、工具、绑定与流事件模型 |
| `lib/screens/` | 总览、工具、会话、配对、设置五个页面 |
| `test/widget_test.dart` | 纯模型与组件测试，不启动 sidecar |
| `test/sidecar_ipc_test.dart` | 跨层测试。启动真实 sidecar，缺少依赖时跳过 |

## 来源与维护

本工程从 CloudTerminal 的 `apps/cloudterminal_windows` 迁移而来（源 HEAD `49b2aac781858929a19307faeb808b83f8154410`）。

迁移只改了三处，其余保持原样：

1. `lib/main.dart` 的 agent 目录解析，改指向 `../remote_agent`，不再依赖原仓库结构。
2. `test/sidecar_ipc_test.dart` 的 sidecar 工作目录，改为 `../remote_agent`。
3. 面向用户的路径文案（`LAUNCH.md`、`README.md`、`run.cmd` 注释）与错误提示。

界面、状态机和协议都未改写。协议契约见 `../remote_agent/README.md` 与 Studio 共享内核的 `lib/remote_control/README.md`。

## 身份

sidecar 使用 `~/.cloudterminal/agent.json`，或 `CLOUDTERMINAL_HOME` 指定的目录。本工程不复制、不迁移、不覆盖已有身份文件。测试使用临时目录。

## 不做的事

- 不替代 Studio 的手机端远程电脑界面。
- 不直连中继。所有连接由 sidecar 持有。
- 不在 web 目标上提供功能。web 只能预览界面。
