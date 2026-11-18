# pi-A：把 agent 嵌入原编辑器页

先读 `RULES-rework.md`。

- worktree：`D:\MyNewProjects\_wt\pi-a\qfli_studio_core`
- 分支：`rework/pi-a`
- status：`TASK\status\pi-A-rework.md`

## 目标

用户从主页打开项目，直接进原编辑器页。agent 嵌在这个页面里。没有第二个页面。

## 独占范围

- `lib/editor/editor_page.dart`（只加不改）
- `lib/editor/retained_editor_host.dart`（只在必须时，改动最小）
- `lib/editor/agent/**`（新目录）
- 删除清单见 design.md §11.3
- 测试：`test/editor_agent_embed_test.dart`（新）

## 不得改

- `lib/pages/home_page.dart`。必须与基线一致。
- 基线里原有的测试文件。
- `lib/chat/**`、`lib/shell/workbench_agent_pane.dart`、`lib/shell/login_gate.dart`（pi-C）。
- `lib/session/**`、`lib/vibe_coding/**`、`lib/shell/agent_runtime_factory.dart`（pi-B）。

## 你会用到的现成件

- `WorkbenchState`（`lib/shell/workbench_state.dart`）：会话 id、侧边栏分段、主体分段、收起状态。
- `Breakpoints`、`layoutOf`（`lib/layout/breakpoints.dart`）：断点只能从这里取。
- `WorkbenchAgentPane`（`lib/shell/workbench_agent_pane.dart`）：对话流加输入卡片。
- `studioAgentRuntime`（`lib/shell/agent_runtime_factory.dart`）：应用级 runtime。
- `AgentRuntime.statusOf`、`liveChanges`、`markSeen`、`cancelAll`：会话状态。基线里是占位，pi-B 实现。

## 步骤

1. 读 design.md §11.1 至 §11.5。
2. 读 `lib/shell/workbench_shell.dart`、`lib/sidebar/workbench_sidebar.dart`、`lib/pages/project/project_page.dart`。它们要删，但里面有可复用的代码。
3. 读 `lib/editor/editor_page.dart` 的这些位置：构造 141-205，状态 207-262，`_toggleExplorer` 1243，`build` 2372-3248，`_buildExplorerCard` 3428。先复制一份到 `_scratch\pi-a\`。
4. 在 `lib/editor/agent/` 创建：
   - `editor_agent_host.dart`：持有 `WorkbenchState`。懒创建 runtime。首帧不创建。
   - `editor_sidebar_tabs.dart`：分段「文件 | 会话」。下面是原文件树或会话列表。
   - `session_list_view.dart`：会话列表。从旧文件搬来。加状态标记，读 `runtime.statusOf` 与 `liveChanges`。
   - `agent_dock.dart`：宽屏右栏。头部有会话标题、新会话按钮、收起按钮。里面放 `WorkbenchAgentPane`。
   - `agent_pane_switcher.dart`：中屏和窄屏的分段条，以及保活容器。
5. 改 `editor_page.dart`，按 design.md §11.2 的 7 点。一点一个小 Edit。
   - 门控：`StudioProfile.current?.offlineOnly != true`。
   - 给 `EditorPage` 加可选参数 `agentRuntime`，供测试注入。为空时用 `studioAgentRuntime`。
   - 删除上一轮加的 `onOpenAgent` 参数。`case 'ai'` 改为调用 agent 面板开关。
   - 专注模式（`focusMode`）下，agent 控件和 AppBar 一起隐藏。
6. 删除旧文件（design.md §11.3）。`grep` 确认没有残留引用。
7. 运行旧测试，必须全过：`retained_editor_test`、`widget_test`、`retained_editor_restore_control_integration_test`、所有 `editor_*` 测试。失败就改实现，不改测试。
8. 写 `test/editor_agent_embed_test.dart`，覆盖：
   - 打开项目只推一个路由。返回一次回主页。
   - 宽屏有 Agent 面板和「文件 | 会话」。窄屏有分段条。
   - 发送消息、切换会话不推路由（NavigatorObserver）。
   - 跨断点后，编辑器内容和对话流不丢。
   - 离线产品没有任何 agent 控件。
   - 最小化再恢复，Agent 面板状态保留。
   - 后台会话待确认时，agent 图标有角标。
   - agent 面板未展开时，不创建 runtime。
9. 提交到你的分支。例：`feat(editor): embed the agent panel into the editor page`。分多次提交。

## 完成标准

- CHECKLIST 的 A1-A5、B1-B7、E2、E3、F5、G8 全部通过。结果写进 status。
- `flutter analyze --no-pub` 无问题。
- `flutter test --no-pub` 只有 3 个既有失败。
