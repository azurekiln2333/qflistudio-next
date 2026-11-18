# pi-C 状态（W-C 输入卡片、对话流、项目页）

## 已完成

- 契约落地 `lib/chat/composer_state.dart`：`ComposerState`（文本/附件/权限/模型/推理强度/`canSend`/
  `clearInput`/`bindProject`/`loadDefaults`/`flush`）、`ComposerDefaults`、`ComposerDefaultsStore`、
  `FileComposerDefaultsStore`（`composer_defaults.json`，临时文件改名）。默认值按项目存，切项目重载。
- `ComposerCard`：输入区（桌面 Enter 发送、Shift+Enter 换行）、工具行（加号、权限模式、模型、
  推理强度，均 44 高）、卡片内发送/停止同位切换、附件可删 chips、输入 `/` 列出 skill 并插入。
- `attachment_picker.dart`：「项目文件」与「工作区文件」两个来源。项目文件取相对路径，跳过
  `build`/`node_modules` 等，上限 400。工作区文件取同一工作区其它成员目录。
- 附件传参按 pi-B 的约定（`status/pi-B.md` 请求节）：项目内文件给相对路径（`/` 分隔），
  工作区其它项目的文件给绝对路径，由 harness 登记进本会话只读白名单。
  `AttachmentFile.readOnly` 标出跨项目文件。选择器里的提示改为「agent 只读，不能修改」，
  旧的「取不到正文 / 只能看到路径」限制标注已撤。
- `ComposerState.payloadPath` 统一规范附件路径：项目内绝对路径折成相对路径，项目外保留绝对路径，
  无项目根时只统一分隔符。重复路径按规范后的形态去重。
  附件 chip 对跨项目文件只显示最后两段，完整路径放进 tooltip。
- `chat_transcript.dart`：用户/助手/工具三种消息、待运行标记、空状态、失败条与重试、
  写确认卡片插入。`write_approval_card.dart`：路径、摘要、允许与拒绝。
- `lib/pages/project/project_page.dart`：会话列表（新建/重命名/删除，删除二次确认）、
  未登录显示引导卡、底部共享一个 `ComposerCard`。`onOpenSession(sessionId, draft)` 作为交给
  工作台的接缝（阶段 2 由 pi-A 接）。首次发送会先建会话再交接，交接失败时保留输入文本。
- 测试 49 例全通过：`composer_state_test`(13)、`chat_composer_card_test`(10)、
  `chat_transcript_test`(8)、`chat_attachment_picker_test`(8)、`project_page_test`(10)。
  覆盖 implement.md W-C 第 7 条要求的工具行齐全、运行中显示停止、写确认允许与拒绝。
- 验证：本范围 `flutter analyze` 无问题。`flutter analyze lib` 无问题（pi-A 集成代码仍编得过）。
  本范围 `dart format` 无改动。五个测试文件同进程协作无干扰。`workbench_shell_test` 18 例仍通过。

## 进行中

- 无。

## 请求

- pi-A：`test/workbench_shell_test.dart:25` 有 `unused_element_parameter` 警告，全仓 analyze 唯一一条。
- `lib/pages/project/project_page.dart:368` 的 `prefer_function_declarations_over_variables` 已不存在：
  重命名弹窗改成自持控制器的 StatefulWidget 后那一行变成普通字段，本范围 analyze 已干净。
- 既有失败非本范围：`retained_editor_test` 8、`widget_test` 3、`editor_run_target_test` 3、
  `retained_editor_restore_control_integration_test` 2。这些文件不引用 `lib/chat`、`lib/pages/project`
  任何符号，判断来自 W-A 布局改动或既有 `editor_page.dart` 改动。
- 阶段 2 集成时，`ChatTranscript` 需要 pi-A 挂到主面板。`ProjectPage` 的 `onOpenSession` 需接到
  工作台打开会话（含把 draft 带过去）。

## 未验证

- 未在真机/桌面跑过界面，只有 widget 测试。视觉密度、触摸区在 PAD 上的实际手感未验。
- 未接真实 `AgentFacade`，测试全部用 `test/support/fake_agent.dart` 的假实现。
  harness 真实消息流（工具调用增量、审批时序）与 UI 的匹配度未验。
- 附件只传路径，未验证 agent 侧对附件的实际消费方式。与 pi-B 的传参约定（项目内相对、
  项目外绝对）只在本范围单测验过，未与真实 harness 联调。
- pi-A 的工作台面板构造 `ComposerState` 时没传 `projectRoot`（`workbench_agent_pane.dart:63`），
  因此那里的路径规范化只做分隔符统一。选择器已直接产出合规路径，
  影响面仅限将来的拖放与草稿恢复。
- 工作区文件在工作区本身为空、或项目不在任何工作区时的空状态只有单测，未接真实 `SavedWorkspace`
  持久化验证。
- `ComposerDefaults` 的并发写已改为串行队列 + `flush()`，但没有跨进程/崩溃场景测试。
