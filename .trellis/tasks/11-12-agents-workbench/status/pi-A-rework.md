# pi-A 返工：把 agent 嵌进原编辑器页

worktree `D:\MyNewProjects\_wt\pi-a\qfli_studio_core`，分支 `rework/pi-a`，6 个提交。
`flutter analyze --no-pub`：无问题。

## 已完成

- 新增 `lib/editor/agent/`：`editor_agent_host.dart`（持 `WorkbenchState`，运行时懒解析）、
  `editor_sidebar_tabs.dart`（文件 | 会话 + 44×44 分段控件）、`session_list_view.dart`（状态标记、
  重命名、删除确认、全部停止、空状态）、`agent_dock.dart`（宽屏右栏、收起竖条、对话流本体、
  顶栏入口带角标）、`agent_pane_switcher.dart`（中窄屏分段条 + `Offstage` 保活）。
- `editor_page.dart`：加 `agentRuntime` 参数、顶栏 agent 入口、菜单项「Agent 面板」、侧边栏分段容器、
  宽屏右栏、中窄屏分段条、`GlobalKey` 跨断点保活、本页提供 `LoginGateScope`。
- 删 design §11.3 清单 6 个文件；`grep -rn "ProjectPage|ProjectEntryPage|openProjectPage|WorkbenchShell" lib test` 无结果。
- 新增 `test/editor_agent_embed_test.dart`（16 项）。
- 输入卡片记忆：`EditorPage` 允许注入 `ComposerDefaultsStore`，生产走 `FileComposerDefaultsStore`（design §4 第 9 条）。

### 验收（本分支实测）

| 项 | 结果 | 证据 |
|---|---|---|
| A1 | 通过 | 「打开项目只推一个路由」：pushes 1→2 |
| A2 | 通过 | 同项：`pop` 一次后回主页、`EditorPage` 消失 |
| A3 | 通过 | 上面那条 grep 无输出 |
| A4 | 通过 | 「发送消息和切换会话都不推路由」：pushes 不变 |
| A5 | 通过 | 「工作区入口同样直达编辑器页」：`openEditorPage(workspace:)` 只推 1 个路由，页内显示「示例工作区」 |
| B1 | 通过 | `git diff wip/baseline-20261114 -- lib/pages/home_page.dart` 为空 |
| B2 | 通过 | `git diff --stat -- test`：只删了 §11.3 授权的 `workbench_shell_test`、`project_page_test`，其余未改 |
| B3 | 部分 | 1513 通过、3 个 `editor_run_target`（允许）、1 个 `interop_arkts_contract_test` 加载失败。该测试及其 import（`interop_protocol`、`interop_targets`）相对基线 diff 为空，与本改动无关 |
| B4 | 通过 | 「离线产品任何宽度都没有 agent 控件」：宽屏与抽屉都无入口/分段/面板 |
| B5 | 通过 | `--numstat` +309/−23；删除行只有 `onOpenAgent` 与 `case 'ai'` 分支（brief 授权），其余是包一层容器 |
| B6 | 通过 | 「最小化再恢复，Agent 面板状态保留」：`WorkbenchAgentPane` State 同一份，草稿仍在 |
| B7 | 通过 | `editor_pad_layout`、`terminal_*`、`editor_run`、`retained_editor`、`offline_background_and_shortcuts`、`main_workspace_sessions`、`workspace_project_switch` 共 126 项全过 |
| E2 | 通过 | 「列表状态标记正确」：待确认/失败文案与 `session-status-<id>` |
| E3 | 通过 | 「后台会话待确认时 agent 图标有角标」：`editor-agent-badge` 从无到有 |
| F5 | 通过 | 「agent 面板未展开时不解析运行时」：`EditorAgentHost.runtimeResolutions == 0` |
| G8 | 通过 | 「跨断点编辑器内容和对话流都不丢」：`CodeEditor` 与 `WorkbenchAgentPane` State 同一份，草稿保留 |
| §4.9 | 通过 | 「选模型后按项目记下」：选 `Model A` 后存储里该项目的 `modelId` 为 `model-a` |

补充检查（不在本次关卡，但已做）：新文件 `grep "Color(0x"` 无结果，只用主题 token（G6）；新文件用户可见文案全为中文，唯一英文是术语「Agent 面板」，无堆栈（G5）。

## 进行中

- 无。

## 请求

1. 基线 `editor_pad_layout_test` 要求菜单「AI 助手」打开旧 `AiPanel` 并量其矩形，与 design §11.2 第 4、5 点冲突。按 RULES「旧测试失败说明实现错了」，我保留「AI 助手」原行为，agent 走新入口，故现在有两个 AI 入口（不符 §4 第 12 条）。是否授权改该测试那两处断言？
2. 侧边栏分段位置：基线断言 `FileExplorer` 高度恒为 `body.height - 24`，`main_editor_short_height_test` 在 1100×175 断言无溢出；侧边栏内加任何竖向控件都会破坏这两条。故常驻侧边栏的分段放顶栏（图标 + tooltip），抽屉里的分段带文字。若要分段固定在侧边栏顶部，需授权改这两条断言。
3. `WorkbenchAgentPane`（pi-C）切换会话时 `dispose` 旧 facade，违反 §11.4「界面不得 dispose facade」，请 pi-C 修。
4. `WorkbenchAgentPane` 的输入卡片记忆已由编辑器页接线（注入 `ComposerDefaultsStore`，生产用文件实现），此请求关闭。

## 未验证

- 真机（鸿蒙）：G1 各宽度截图、G2 文字缩放 1.3、F6 实测耗时，均未做。
- 与 pi-B 的并行会话注册表联调：本分支基线里 `statusOf`/`liveFacade` 仍是占位，E1/E4-E7 归 pi-B。
- `interop_arkts_contract_test` 以 `Directory.current.parent + 'qflistudio'` 取文件，在 worktree 下指向 `_wt/pi-a/qflistudio`（不存在）；主目录下该文件存在。与本改动无关，未修。
