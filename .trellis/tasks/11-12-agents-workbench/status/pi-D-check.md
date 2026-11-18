# pi-D 阶段 2 状态：交叉检查 pi-C

角色：检查人（阶段 2）。检查对象 pi-C（Agent 面板的反馈、错误、输入卡片）。
报告：`check/pi-D-checks-pi-C.md`。worktree `D:\MyNewProjects\_wt\check-d\qfli_studio_core`（`check/pi-d`，内容 `rework/integration` a43b7df）。

## 已完成

- 读完 `RULES-rework.md`、`CHECKLIST.md`、`briefs/phase2-check.md`，并读了 pi-C 的 brief 与 status。
- 重点项全部有证据：C1-C6、D1-D6、G2-G7、H1-H5（共 23 项）。结果：通过 18，不通过 5。
- 独立测试 `tool/pi_d_check_test.dart`（未跟踪、未提交）24 例全过，全部自建场景，未复用 pi-C 的断言。
- 环境：`flutter analyze --no-pub` → `No issues found! (ran in 12.2s)`；
  全量 `flutter test --no-pub` → `+1604 ~9 -4`，失败仅 `editor_run_target_test` 3 例（允许）
  + `interop_arkts_contract_test` 1 例（已知环境问题，按要求忽略）。
- I1-I4 全查：I1 无密钥（lib/test/tool 与 status/check 文档均无匹配，只命中 `_password` 变量名）；
  I3 `check/pi-d` reflog 只有一次 `reset: moving to HEAD`（03:08:39，worktree 建立时，早于 pi-C 首个提交）；
  I4 提交信息无 AI 署名。I2 见「请求」。
- 4 个自设破坏性场景全过：models 永不返回 + open 抛错仍可输入；4000 字错误详情 390 宽不溢出；
  只有附件也能发送；运行中切走再切回停止键与进度条都在、`disposeCount == 0`。
- 截图交付：`tool/agent_editor_scenes_test.dart`（未跟踪、未提交）用
  `EditorPage(agentEnabled: true, agentRuntime: FakeAgentRuntime(...))` 出图，
  输出 `check/screens/integration/` 18 张（390 宽 7 场景 × 浅/深，加 900/1280 的空会话）。
- 未改 `lib/`、`test/`；worktree 只有 3 个未跟踪的 `tool/` 文件，无提交。

## 进行中

- 无。

## 请求

- pi-C：修 D1、D2。切到另一个会话后模型 chip 变「默认模型」、推理强度 chip 消失。
  `WorkbenchAgentPane._composerFor` 给每个会话新建 `ComposerState`（`modelId` 为 null），
  而 `ComposerCard.didUpdateWidget` 只在 `models` 变化时调 `_syncDefaultSelection()`。
  后果：切会话后发送的 `modelId`/`reasoningEffort` 为 null，服务端用默认模型。
  建议换 `state` 时也调 `_syncDefaultSelection()`，或在 `_createComposer()` 里带上当前选择。
  证据：`tool/pi_d_switch_test.dart` 输出 `Found 0 widgets with text "Model One"`。
- pi-C：G4 `lib/chat/attachment_picker.dart:233` 用户可见文案写小写 `agent`，同批其它文案已统一为「Agent」。
- pi-C：G7 `attachment_picker.dart` 的 `_emptyState` 没有主操作按钮，「这个项目还没有文件」时只能关掉选择器。
- pi-C：C3 文案。`awaitingApproval` 时状态行写「思考中…」，建议写「等待你确认」。
- 未分配：G5 `vibeToolLabel` 缺 `search_text` 映射，对话流把 `search_text` 原样显示给用户。
  该文件与基线一致，属基线遗留，不是本轮回归。
- 大脑：I2 主目录在快照后被写过。`home_page.dart`、`retained_editor_test.dart` 的 mtime 是 02:52:10
  （快照 02:51:48），现在已无 diff；`git reflog` 无新提交，HEAD 仍是 `573d1b6`。
  与 pi-A、pi-C 两方独立取证一致，无法归因到具体 pi。请确认这是有意的清理并记一笔。

## 未验证

- 900/1280 宽的对话流截图：harness 在 medium/wide 下点不到会话行，`running`/`long`/`failed-*`/
  `sessions`/`drawer` 只出了 390 的图，900/1280 只保留 `empty`。宽屏可参考 pi-C 的
  `check/screens/pi-c/append/*-900x1000-*`。
- 截图里代码区是色块：测试环境没注册代码编辑器的字体族，属出图工具限制，不是应用缺陷。
- 真机未验：触摸手感、真实字体换行、真实 `AgentFacade` 的流式增量与 429 退避（属 pi-B 范围）。
