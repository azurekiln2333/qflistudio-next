# 运行远程电脑连接助手

`companion/windows_assistant` 是一个 Flutter Windows 桌面工程。它只负责“连接助手”界面。真正的后台逻辑由 Node sidecar（`companion/remote_agent/src/agent/main.ts --sidecar`）提供。

手机端的远程电脑功能在 Studio 主 App 里。这个助手与主 App 是两件不同的东西。助手用于在电脑上完成配对、查看中继状态、探测工具和绑定会话。

## 前置条件

| 依赖 | 版本 | 用途 | 检查命令 |
| --- | --- | --- | --- |
| Flutter SDK | 见 `pubspec.yaml`（`sdk: ^3.11.5`） | 构建与运行 | `flutter --version` |
| Node.js | 24 LTS（`>= 23.6`） | 启动后台 sidecar | `node --version` |
| 助手依赖 | — | sidecar 运行所需 | `cd companion/remote_agent && npm ci` |
| Visual Studio 2022 与“使用 C++ 的桌面开发”工作负载 | — | 仅构建 Windows 桌面目标时需要 | `flutter doctor -v` |

先安装一次 sidecar 依赖。命令在仓库根目录运行：

```powershell
cd companion/remote_agent
npm ci
```

如果跳过这一步，助手会提示“找不到后台服务或 Node.js”。

## 方式 (a)：已安装 Visual Studio C++ 工作负载

确认工具链就绪：

```powershell
flutter doctor -v
```

输出中应出现：

```text
[√] Visual Studio - develop Windows apps
```

然后运行桌面版：

```powershell
cd companion/windows_assistant
flutter run -d windows
```

这是完整功能的形态。助手能用 `Process.start` 启动 Node sidecar，因此中继连接、配对码、二维码、工具探测和会话列表全部可用。

## 方式 (b)：未安装 Visual Studio，用 Chrome 预览界面

`flutter build windows` 与 `flutter run -d windows` 需要 C++ 工具链。缺少工具链时，可以先用 web 目标查看界面：

```powershell
cd companion/windows_assistant
flutter run -d chrome
```

### 这个形态下会发生什么

- 布局、主题、导航和各页面骨架都能看到。
- 后台服务无法启动。助手用 `dart:io` 的 `Process.start` 拉起 sidecar，web 目标不支持该 API。
- 界面会显示“找不到后台服务或 Node.js”的提示。配对码、工具列表和会话都是空的。
- 这是预期行为，不是缺陷。web 预览只用于确认界面。
- 要验证真实连接与配对，请走方式 (a)，或在 Windows 桌面构建上验证。

## 安装 Visual Studio C++ 工作负载

用 winget 安装 Build Tools。它比完整 IDE 小，足够构建 Flutter Windows 应用：

```powershell
winget install Microsoft.VisualStudio.2022.BuildTools --override "--add Microsoft.VisualStudio.Workload.VCTools --includeRecommended"
```

- 该命令不会自动运行，请在自己的终端里手动运行。
- 安装完成后重开终端，再运行 `flutter doctor -v` 确认 `[√] Visual Studio - develop Windows apps`。
- 已装完整版 Visual Studio 时，在 Visual Studio Installer 里勾选“使用 C++ 的桌面开发”即可。

## 一条命令启动

`run.cmd` 先检查 Flutter、Node.js 与 Visual Studio，再选择方式 (a) 或 (b)：

```powershell
companion\windows_assistant\run.cmd
```

脚本逻辑：

1. 找不到 `flutter` 时打印安装指引并退出。
2. 检测到 Visual Studio Windows 工作负载时运行 `flutter run -d windows`。
3. 未检测到工具链时打印安装指引，然后运行 `flutter run -d chrome` 预览界面。

脚本不会静默安装任何东西。设置 `RUN_LAUNCHER_DRY_RUN=1` 只打印将要运行的分支，不启动 Flutter。

## sidecar 路径

助手按下列顺序查找 Node agent 目录，命中第一个即停止：

1. 环境变量 `CLOUDTERMINAL_AGENT_DIR`（打包分发时可指定）。
2. 当前工作目录的 `../remote_agent`（从本工程目录运行时命中）。
3. 从当前运行文件所在目录向上逐级查找 `remote_agent`。这样 `build/windows/x64/runner/Release` 下的发行版也能找到 `companion/remote_agent`。

三处都不存在时，助手把当前工作目录交给 sidecar。sidecar 自己报启动失败，助手不编造路径。

Node 运行文件默认是 `node.exe`（非 Windows 上是 `node`）。可用环境变量 `CLOUDTERMINAL_NODE` 指定打包的运行时。

## 身份与设置

sidecar 沿用 CloudTerminal 的身份目录。默认路径是 `~/.cloudterminal/agent.json`。设置 `CLOUDTERMINAL_HOME` 可以改用隔离目录。

- 助手不会复制、迁移或覆盖已有的身份文件。
- 已有配对的手机在身份不变时继续可用。
- 要重新配对，在助手界面里运行“重置配对”。该动作会生成新身份，所有已配对手机都要重新配对。
- 测试与预览使用临时 `CLOUDTERMINAL_HOME`，不接触真实身份。

## 常见问题

- **`flutter run -d windows` 报缺 C++ 工具链**：按上面的 winget 命令安装，或改走方式 (b)。
- **界面提示找不到后台服务**：确认已运行 `cd companion/remote_agent && npm ci`，并且 `node --version` 不低于 23.6。
- **web 预览里功能不可用**：符合预期。web 无法启动 Node sidecar。请安装 Visual Studio 后改用 `-d windows`。
- **助手与手机端的关系**：助手在电脑上完成配对和工具准备。手机端在 Studio 主 App 的“远程电脑”入口操作会话。
