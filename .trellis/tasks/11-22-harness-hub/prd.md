# PRD：Studio 内置完整 harness 体验

## 目标

用户在 Studio 里管理本机和远程电脑上的全部 AI 编程会话。

## 背景

- 任务 11-20 原样迁入 CloudTerminal，形成独立的“远程电脑”页面。
- 该页面保留源应用的首页和导航，与 Studio 的 Agents 界面割裂。
- 任务 11-21 正在接入账号绑定，沿用 Node companion 作为桌面桥。
- 桌面版尚无本机终端会话管理，无法读取 Herdr，也无法启动其他 harness。
- 内置 Agent 已有技能机制，但不识别 Trellis 工作流。

## 需求

R1. Studio 用一个统一的 Agents 界面展示全部会话。
R2. 会话来源包括内置 Agent、Claude Code、Codex、Pi、Herdr 窗格和普通 shell。
R3. 用户可添加 OpenCode、Gemini、ZCode、dsh 等其他 harness。
R4. 桌面版在 Windows、macOS、Linux 上启动和控制本机终端会话。
R5. 桌面版检测已安装的 harness，并按 harness 启动新会话。
R6. 桌面版读取本机 Herdr 的工作区、窗格和 Agent 状态。
R7. 桌面版实时显示 Herdr 窗格，并可发送提示词和按键。
R8. 未安装 Herdr 时，Studio 用自带会话管理提供同等能力。
R9. 手机端在同一界面切换到已绑定电脑，查看和控制该电脑的会话。
R10. 配对和账号绑定移入设置页，不再占用独立首页。
R11. 结构化会话显示对话记录，并支持审批和提问回复。
R12. 每个会话都能切换到原始终端视图。
R13. 内置 Agent 读取项目里的技能目录。
R14. 内置 Agent 识别 Trellis 项目，并注入当前任务上下文。
R15. 内置 Agent 提供 Trellis 任务面板和 Trellis 斜杠命令。

## 验收标准

AC1. 桌面版三种系统都能启动 shell、Claude Code、Codex 和 Pi 会话。
AC2. 桌面版能列出本机 Herdr 的全部 Agent，状态与 `herdr agent list` 一致。
AC3. 桌面版打开 Herdr 窗格后，输出实时刷新，输入立即送达。
AC4. 关闭会话视图不会结束桌面会话。
AC5. 结束会话需要用户在界面上确认。
AC6. 手机端从同一会话列表切换本机和已绑定电脑。
AC7. 手机端终端提供 Esc、Tab、Ctrl、Alt、方向键和粘贴键。
AC8. 旧的远程会话协议保持兼容，手动配对继续可用。
AC9. 内置 Agent 在 Trellis 项目中显示当前任务和阶段。
AC10. 内置 Agent 能调用项目技能目录里的 SKILL.md。
AC11. 未识别的 harness 可通过配置文件添加，不改代码。
AC12. 自动检查覆盖会话模型、Herdr 解析、技能发现和 Trellis 读取。

## 约束

- 不改变 relay 和 companion 的现有会话协议。
- 不合并任务 11-21 的账号绑定工作，只在其分支基础上开发。
- 不在本地运行测试、构建、模拟器、虚拟机或服务。
- 不自动批准任何权限请求。
- 不读取、复制或输出任何令牌、密钥和凭据。
- 不重置、清理或覆盖用户工作树里的改动。

## 范围外

- 用 Dart 重写 Node companion。
- 公网 relay 部署。
- 局域网自动发现设备。
