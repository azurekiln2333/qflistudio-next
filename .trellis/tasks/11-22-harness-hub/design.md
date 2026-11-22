# Design：Harness Hub

## 总体结构

Studio 把“一台能跑 harness 的电脑”抽象为 `HarnessHost`。
本机和远程电脑实现同一接口，界面只依赖该接口。

```
Agents 界面（编辑器页内，桌面与手机共用）
        │
        ▼
HarnessHub（主机列表、当前主机、会话列表）
   ├── LocalHarnessHost   仅桌面：PTY 会话 + 日志读取
   │      ├── StudioMux       自带 PTY 会话管理
   │      └── ProviderRegistry  harness 检测、启动参数、日志目录
   ├── HerdrHost          仅桌面：调用 herdr CLI，attach 窗格（独立主机）
   ├── RemoteHarnessHost  包装 11-20/11-21 的 RemoteController
   └── StudioAgentHost    内置 Agent 会话（现有 Vibe 会话）
```

## 接口契约

契约文件：core `lib/harness/harness_host.dart`。基线提交已包含该文件。
所有 Pi 只读该文件。修改契约必须写进报告，由 root 统一合并。

核心类型：

- `HarnessHost`：`id`、`label`、`kind`（local、remote、studio）、`state`、`watchSessions()`、`providers()`、`open()`、`launch()`。
- `HarnessSessionInfo`：会话 ID、主机 ID、provider ID、标题、工作目录、状态、能力集、更新时间、来源引用。
- `HarnessSessionStatus`：working、idle、done、blocked、exited、unknown。
- `HarnessCapability`：transcript、terminal、prompt、approve、stop。
- `HarnessSessionHandle`：`transcript`、`terminal`、`sendPrompt()`、`reply()`、`detach()`、`stop()`。
- `detach()` 只释放视图。`stop()` 结束会话，调用方必须先取得用户确认。

## Provider 注册表

内置 provider：claude、codex、pi、opencode、gemini、zcode、dsh、shell。
每个 provider 声明可执行文件名、启动参数、会话日志目录和状态识别规则。
用户 provider 写在 `<appSupport>/qfli_harness_providers.json`，格式与内置项相同。
检测顺序：用户配置路径 → PATH → 平台常见安装目录。

日志读取：

- Claude Code：`~/.claude/projects/<编码路径>/*.jsonl`。
- Codex：`~/.codex/sessions/**/*.jsonl`。
- Pi：`~/.pi/agent/sessions/<编码路径>/*.jsonl`。
- 读取器只解析，不写入。超大文件按尾部窗口读取。

## 本机终端

桌面版用 PTY 运行会话。Windows 用 ConPTY，macOS 和 Linux 用 forkpty。
Pi-A 先检查 core 现有终端实现，优先复用，不新增重复依赖。
编辑器内现有终端仍受 `editor-terminal.md` 和 `process-lifecycle.md` 约束。
StudioMux 持有 PTY 进程。应用退出时按 `process-lifecycle.md` 结束子进程。
渲染复用 11-20 迁入的 `vendor/xterm` 和 `RemoteTerminalPane` 的输入层。

## Herdr

HerdrHost 只通过 herdr 公开接口工作，不读取 herdr 内部文件。

- 列表：`herdr agent list`、`herdr workspace`、`herdr pane` 的 JSON 输出。
- 状态：映射 `agent_status` 到 `HarnessSessionStatus`。
- 实时视图：在 Studio PTY 里运行 `herdr agent attach <pane>`。
- 输入：`herdr agent prompt`、`herdr agent send-keys`。
- 等待：`herdr agent wait` 驱动状态刷新，不做高频轮询。
- Windows 上直接调用 herdr.exe，不经过 MSYS 路径转换。
- 未安装 Herdr 时，界面显示安装说明，StudioMux 接管全部功能。

## 远程主机

RemoteHarnessHost 把现有 SessionView、HerdrController、CodexThreadView 和 Claude 会话映射到契约类型。
wire 协议、请求 ID、重连、重放和超时语义不变。
桌面版继续通过 Node companion 对外提供远程能力。用 Dart 重写 companion 不在本任务内。

## 界面

去掉独立的“远程电脑”首页。所有会话进入编辑器页现有的 Agents 界面。

- 顶部主机切换：本机、已绑定电脑（在线点）、添加电脑。
- 会话列表按 harness 分组，显示状态标签和工作目录。
- “新建会话”菜单列出检测到的 harness。
- 会话视图有“对话”和“终端”两个标签。对话标签复用 Studio 的消息组件和输入框。
- 内置 Agent 会话与外部会话出现在同一列表。
- 手机端：列表页进入详情页。终端下方显示按键栏。
- 配对、账号绑定和撤销移到设置页的“设备与远程”。
- 旧的 RemoteComputerPage 入口改为跳转到 Agents 界面。

## Trellis 与技能

技能发现目录：项目 `.agents/skills`、`.claude/skills`、`.pi/skills`、`.codex/skills`，以及用户目录下的同名目录。
每个技能读取 `SKILL.md` 的 frontmatter（name、description），正文按需加载。
接入现有 Vibe 技能机制，规则见 `vibe-skills.md`。

Trellis 识别：项目根目录存在 `.trellis/workflow.md`。

- 上下文：读取当前任务、任务状态、开发者和规范索引，生成精简上下文注入会话开头。
- 读取用 Dart 直接解析 `.trellis` 文件。桌面版可选调用 `python ./.trellis/scripts/get_context.py`，失败时回退 Dart 解析。
- 任务面板：列出进行中的任务、当前任务、阶段和产物（prd、design、implement）。
- 斜杠命令：`/trellis:continue`、`/trellis:finish-work` 映射到同名技能。
- 项目指令：读取 `AGENTS.md`，作为内置 Agent 的项目指令。

## 兼容与回滚

全部改动在 `harness/*` 分支。基线是两个仓库的 `release/studio-git-ui-20261120`。
Agents 入口回退后，旧远程页面和编辑器终端保持原状。
