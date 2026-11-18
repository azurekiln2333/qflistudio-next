# pi-A 状态（W-A 布局壳、导航、侧边栏、登录引导、集成）

## 已完成

- 契约落地：`lib/layout/breakpoints.dart`、`lib/shell/workbench_state.dart`、`lib/shell/login_gate.dart`。
- 工作台壳 `lib/shell/workbench_shell.dart`：三档宽度（<720 抽屉、720–1100 常驻侧栏、≥1100 三栏）。
  编辑器与对话流用同一个 `KeyedSubtree` + `GlobalKey` 包装。跨断点 Element 原地更新。
- 侧边栏 `lib/sidebar/workbench_sidebar.dart`：「会话 / 文件」分段，文件段复用 `editor/file_explorer.dart`。
- 登录引导：`LoginGuideCard` + `ensureLoggedIn`，未登录显示卡片，不弹错误。
- `home_page.dart`：点项目改为 `openProjectPage`（主页 → 项目页）。移除不再使用的
  `retained_editor_host` import。其他入口（tools/tutorial/examples/profile）未动。
- 阶段 2 第 1 步：`lib/shell/workbench_agent_pane.dart` 把 `ChatTranscript` + `ComposerCard` +
  真实 `AgentRuntime` 接进工作台右栏与 Agent 分段。`lib/shell/agent_runtime_factory.dart` 装配
  `VibeAgentRuntime`（会话落 `agent_sessions/`）。
- 阶段 2 第 1 步（draft）：`ProjectEntryPage` 把 C 的 `ProjectPage.onOpenSession(sessionId, draft)`
  接到 `WorkbenchShell(initialSessionId, draft)`。
- 阶段 2 第 2 步：`editor_page.dart` 增加 `onOpenAgent`（基线脏文件，改动最小：一个字段 + `case 'ai'`
  分支。未传时保留原内嵌 `AiPanel`。工作台传入后，AI 入口切到对话流。
- 测试：`test/workbench_shell_test.dart` 18 例全通过（断点、状态、登录门控、跨断点保活、
  抽屉/常驻、收起展开、侧栏空状态与列表、阶段 2 接线、项目入口）。
- `flutter analyze`（core，lib 与全仓）：无问题。

## 进行中

- 修 3 个测试文件的导航步骤（只改步骤，未删用例、未放宽断言）：
  `retained_editor_test.dart` 已改 `_Fixture.open`（主页 → 项目页 → 编辑器入口 → 工作台编辑器）
  与 `_minimize`（收起后回主页）。**仍有 8 例失败**，原因见「请求」。
  `widget_test.dart`（3 例）、`retained_editor_restore_control_integration_test.dart`（2 例）未开始。

## 请求

- **阻塞点（需大脑决策）**：从 `HomePage` 推出 `ProjectEntryPage` 后，路由内容实际宽度约 476，
  而测试视口是 390（`retained_editor_test.dart:777` 设 `physicalSize=390`、
  `dpr=1`）。因此项目页上的「编辑器」入口（AppBar 动作或 FAB）中心点在 x≈440，
  `tap()` 报 “outside the bounds of the root of the render tree”。已排除：`StackFit`、
  FAB 默认 hero tag 冲突、路由过渡未完成（多轮 pump 与 `pumpAndSettle` 均无效）。
  未定位宽度放大的根因。高度吻合、只有宽度不对，现状指向 `MaterialApp.builder` 的 `RetainedEditorHost`
  覆盖层（`editor/retained_editor_host.dart:476` 起 `Stack(fit: StackFit.expand)`）这条线索，
  尚未证实。该文件在基线脏清单内且属 `editor/`，不在我的独占范围。
- 请确认：`editor/retained_editor_host.dart` 是否可授权我最小改动（把宿主改为可嵌入中栏），
  或由 pi-C/大脑给出窄屏下的项目页入口位置约定。
- pi-C：`ProjectPage` 的 AppBar 在窄屏只有 2 个动作时，第一个动作在测试里也不可达，
  建议给编辑器动作加 `ValueKey`，并确认窄屏动作不溢出。
- 请求大脑确认：`_openEditor` 目前走 `openEditorPage`（保留最小化/恢复、会话选择器等既有行为），
  因此编辑器是宿主全屏覆盖，不是三栏中栏。真正的三栏嵌入需要改 `editor/`。

## 未验证

- `flutter build windows --debug` 冒烟：未运行（修测试优先，预算用尽）。
- 两个仓库全量 `flutter test`：未跑完。已知 core 有 `editor_run_target_test` 3 例既有失败，
  另有本项引入的 `retained_editor_test` 8 例、以及 `widget_test` 3 例、
  `retained_editor_restore_control_integration_test` 2 例未修。
- studio 仓库 `flutter analyze` / `flutter test`：未运行。
- 真机/桌面实际观感、触摸区、深色模式：未验。
- 工作区文件附件受 `read_file` 沙箱限制（pi-C 已提），未处理。
