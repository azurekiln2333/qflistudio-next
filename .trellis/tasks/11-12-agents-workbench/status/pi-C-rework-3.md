# pi-C 第三轮返工状态

worktree `D:\MyNewProjects\_wt\pi-c\qfli_studio_core`，分支 `rework/pi-c`。

## 已完成

- 第一步：`git merge --ff-only rework/integration` 成功，`ed0525b` → `a43b7df`，快进 30 个文件。
  合并前 worktree 只有一个未跟踪文件 `tool/agent_preview_test.dart`，内容与集成分支逐字节相同；
  已移到 `_scratch/pi-c/agent_preview_test.dart.untracked-20261114` 备份，合并后由 git 重新落盘。
- D1、D2：切换会话后模型名和推理强度不再丢。
  - `ComposerState` 构造新增 `modelId`、`reasoningEffort`，静默落值（不发通知，避免构建期标脏）。
    没有模型时强制 `reasoningEffort` 为 null。
  - `WorkbenchAgentPane._createComposer` 用同项目已打开会话的选择做种子，没有时用模型列表第一项；
    权限模式一并沿用。模型选择本来就按项目记住（design §11.6），新会话不再回到空值。
  - `ComposerCard.didUpdateWidget` 在 `state` 对象变化时也调 `_syncDefaultSelection`，
    模型列表晚到时仍能补上选择。
  - 新测试：`D1/D2 切换会话后模型名和推理强度不丢`。会话一选 Model B 加 `max`，切到会话二后
    仍显示 `Model B` 和 `max`，且找不到「默认模型」。
  - 新测试：`D1/D2 模型列表晚到时切换会话也能补上模型名和推理强度`。模型还在加载时切到会话二，
    列表到达后会话二补上 `Model A` 和 `low`。
- G4：`lib/chat/attachment_picker.dart` 的工作区说明 `agent` 改为 `Agent`。
  全仓再 grep 用户可见文案（单双引号、Text/tooltip/hint/label/message/title/subtitle），
  只剩这一处；其余命中是 import 路径、`ValueKey`、`debugPrint` 的 `[agent-perf]`，不是界面文案。
- G7：附件选择器空状态加主操作按钮「关闭」（`attachment-empty-close`），点击关掉面板。
  新测试：`G7 an empty source offers a close action`，断言按钮存在且点击后面板消失。
- C3：`awaitingApproval` 时状态行写「等待你确认写入」，不再写「思考中…」。
  优先级：排队中 → 等待你确认写入 → `activity` → 思考中…。
  新测试：`C3 等确认时状态行写「等待你确认写入」`，同时断言找不到「思考中…」。
- 提交四次：`0434faf`（D1/D2）、`0f1837b`（C3）、`c866634`（G4、G7）、
  `7e9f618`（模型列表晚到时的切换测试）。

## 进行中

- 无。

## 请求

- 环境问题，不属于任何人的实现：`test/interop_arkts_contract_test.dart` 的
  `Java receiver the module exports the ability the Studio target names` 失败，
  原因是 `Directory.current.parent` 下缺 `qfli_java`（worktree 在 `_wt/pi-c/`，
  同级只有 `qflistudio`）。主目录布局下应能通过，需要大脑在集成环境确认。

## 未验证

- 全量 `flutter test --no-pub`：`+1607 ~9 -4`。4 个失败 = `editor_run_target_test` 的 3 个既有失败
  （RULES 允许）+ 上面那个缺 `qfli_java` 的环境失败。没有其他失败。
- 相关测试重跑：`chat_transcript_test`、`chat_attachment_picker_test`、`workbench_agent_pane_test`、
  `composer_state_test`、`chat_composer_card_test` 共 80 项，`All tests passed!`。
- `flutter analyze --no-pub`：`No issues found!`（8.1s）。
- 真机与截图：未做，不在 pi-C 范围。
