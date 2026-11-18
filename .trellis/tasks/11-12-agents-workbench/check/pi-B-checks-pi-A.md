# pi-B 检查 pi-A

检查 worktree：`D:\MyNewProjects\_wt\check-b\qfli_studio_core`，分支 `check/pi-b`，内容为 `rework/integration`（含 `rework/pi-a` 的 8 个提交）。
对象：pi-A 的 `lib/editor/editor_page.dart`、`lib/editor/agent/**`、`lib/editor/retained_editor_host.dart`、§11.3 删除项、`test/editor_agent_embed_test.dart`。

## 汇总
通过 21 项。不通过 0 项。未验证 0 项。

## 结果
| ID | 结果 | 证据 |
|---|---|---|
| A1 | 通过 | `editor_agent_embed_test`「打开项目只推一个路由，返回一次回主页」：`counter.pushes` 打开后为 2（首屏 + 1），`find.byType(EditorPage)` 为 1。用 `openEditorPage`（home_page 调用的同一函数）计数。 |
| A2 | 通过 | 同上用例：`Navigator.pop()` 一次后 `EditorPage` 为 0，`打开项目` 按钮重新出现。 |
| A3 | 通过 | `git grep -nE "ProjectPage\|ProjectEntryPage\|openProjectPage\|WorkbenchShell" -- lib test` 无输出，退出码 1。 |
| A4 | 通过 | 「发送消息和切换会话都不推路由」：发送后与新建会话后 `counter.pushes` 均等于 baseline，`sessions.sessionsOf` 为 2。 |
| A5 | 通过 | 「工作区入口同样直达编辑器页」：`counter.pushes` 为 2，`EditorPage` 为 1，`示例工作区` 文本可见。 |
| B1 | 通过 | `git diff wip/baseline-20261114..rework/integration -- lib/pages/home_page.dart` 为空。 |
| B2 | 通过 | `git diff --stat ... -- test` 仅含 RULES 允许的上一轮新增系列（`agent_session_test`、`chat_composer_card_test`、`vibe_agent_facade_test`、`vibe_attachment_read_test`、`support/fake_agent.dart`）与 §11.3 授权的两个删除（`project_page_test`、`workbench_shell_test`），其余为新增测试文件。 |
| B3 | 通过 | `flutter test --no-pub` 汇总 `00:51 +1604 ~9 -4: Some tests failed.`。4 个失败 = `editor_run_target_test` 3 个（允许）+ `interop_arkts_contract_test` 1 个（已知环境失败，忽略）。 |
| B4 | 通过 | 「离线产品任何宽度都没有 agent 控件」：1280 与 500 宽下 `editor-agent-toggle`、`AgentDock`、`SessionListView`、`editor-sidebar-section-switch` 全为 0。 |
| B5 | 通过 | `editor_page.dart` 相对基线删除 14 行：`onOpenAgent` 参数/文档/字段（round2 brief 第 5 步授权）、`case 'ai'` 分支（B5 允许）、以及 4 处行内改写（`_buildExplorerCard`→`_buildSidebar`、`return Row`→`final body = Row`、`Column`→`KeyedSubtree(Column)`）。无未授权删除。 |
| B6 | 通过 | 新增用例「最小化再恢复，Agent 面板状态保留」证明面板 State 与草稿保留。我另写临时测试（agent 开启 + 脏缓冲）验证：最小化恢复后 `CodeEditor` State 同一、`controller.text` 不变、面板 State 同一、草稿不变，`takeException` 为 null。 |
| B7 | 通过 | 全量测试仅 4 个允许/已知失败；`retained_editor_test`（终端、标签、运行、快捷键）全过。 |
| E2 | 通过 | 「列表状态标记正确」：`SessionListView` 出现，`待确认`、`失败` 文本可见，`session-status-<id>` 存在。 |
| E3 | 通过 | 「后台会话待确认时 agent 图标有角标」：`notifyLive` 后 `editor-agent-badge` 由 0 变 1。 |
| F5 | 通过 | 「agent 面板未展开时不解析运行时」：`EditorAgentHost.runtimeResolutions` 为 0，`WorkbenchAgentPane` 为 0，分段仍在。 |
| G8 | 通过 | 「跨断点编辑器内容和对话流都不丢」：500→1280→500 后 `CodeEditor` State 同一、`WorkbenchAgentPane` State 同一、草稿文本不变。 |
| G9 | 通过 | 用位置断言代替截图（临时测试，`tool/`，未跟踪，已删）。agent 入口在 390/600/900/1280 均为 48×48、`top=4`、右边缘距屏幕右边恒为 152px：`390→right=238`、`600→448`、`900→748`、`1280→1128`，位置完全一致。侧边栏分段在 600/900/1280 均 `left=20`（侧边栏顶部）。 |
| I1 | 通过 | `git grep -nE "sk-\|Bearer \|password *[:=]" -- lib test tool` 命中均为基线既有代码与测试假值（`sk-abc`、`Bearer token` 等），无真实密钥。`status/`、`check/` 无命中。 |
| I2 | 通过 | 主目录 `D:\MyNewProjects\qfli_studio_core` HEAD 仍为 `573d1b6`（与备份 `core-HEAD.txt` 一致）。相对备份快照有 4 个文件差异（`home_page.dart`、`vibe_agent_facade.dart`、`retained_editor_test.dart`、`fake_agent.dart`），但四者内容均等于 `wip/baseline-20261114`，属大脑建基线时的写入，非 pi-A 范围。 |
| I3 | 通过 | `git reflog show rework/pi-a` 只有 8 次 commit 与 1 次 branch 创建，无 reset/checkout/stash/rebase 等禁止操作。 |
| I4 | 通过 | `git log --format=%B wip/baseline-20261114..rework/integration` 无 `Co-Authored-By`、`Generated with`、`Signed-off-by`、`claude` 命中。 |

## 不通过项
无。

## 我设计的破坏性场景
1. 断点边界 719/720/1099/1100 各展开 Agent 面板。结果：四个宽度均无异常，`WorkbenchAgentPane` 各出现 1 个。
2. 离线产品强制 `agentEnabled: true`。结果：无 agent 图标/竖条/分段/面板；菜单「AI 助手」回落到旧 `AiPanel`，`WorkbenchAgentPane` 为 0，无异常。
3. 连续 5 次展开收起 + 500/1280/800/1280 跨断点拉伸。结果：无异常，注入运行时下 `runtimeResolutions` 为 0（不重复解析）。
4. 发送消息后立刻 1280→500→1280 拉伸。结果：无异常，消息文本仍在。
5. （B6 补证）agent 开启 + 脏缓冲 + 最小化恢复。结果：编辑器 State、脏文本、面板 State、草稿全部保留。

## 额外发现
- B5 的删除清单里，`onOpenAgent` 的移除不在 B5 允许项（只列了 `AiPanel` 块与 `case 'ai'`），但由 `rework-pi-A-round2.md` 第 5 步明确授权，属合规。
- 宽屏侧边栏默认收起（基线行为），「文件 | 会话」分段需先展开侧边栏才可见；顶栏 agent 图标是默认入口。pi-A 已在 status 请求裁决，非缺陷。
- `editor_page.dart` 的 `case 'ai'` 在 agent 开启时开 Agent 面板、关闭时开旧 `AiPanel`，两条路径都有测试覆盖，符合 round2 决定。
- 全量测试 `~9` 个 skip 与基线一致，未新增跳过。
- G9 用位置断言验证：完整 `EditorPage` 在 `runAgentPreview` 下会挂（异步初始化不落地），改用 `pumpFrames`（带 `runAsync`）挂载后量 `getRect`，稳定通过。截图仍建议 pi-D 真机补。
