# pi-C：Agent 面板的反馈、错误、输入卡片

先读 `RULES-rework.md`。

- worktree：`D:\MyNewProjects\_wt\pi-c\qfli_studio_core`
- 分支：`rework/pi-c`
- status：`TASK\status\pi-C-rework.md`

## 目标

用户发送后立刻看到反馈。底部始终有模型选择。切换会话不丢草稿，不停止其他会话。

## 独占范围

- `lib/chat/**`
- `lib/shell/workbench_agent_pane.dart`、`lib/shell/login_gate.dart`
- 测试：`chat_*`、`composer_state_test`、`workbench_agent_pane_test.dart`（新）
- `test/support/fake_agent.dart`（可以加字段，不删已有成员）

## 不得改

- `lib/editor/**`、`lib/session/**`、`lib/vibe_coding/**`、`lib/pages/**`。
- 基线里原有的测试文件。

## 契约

- `WorkbenchAgentPane` 现有构造参数不删不改名。新增参数必须有默认值。pi-A 依赖它。
- 基线里已有这些接口，pi-B 实现真实逻辑，你按接口使用：
  - `AgentFacade.lastErrorInfo`、`activity`、`hasEarlier`、`loadEarlier()`
  - `AgentRuntime.statusOf`、`liveChanges`、`liveFacade`、`markSeen`
  - `AgentFacade` 由 runtime 持有。你不得 dispose 它。
- 你的测试用 `FakeAgentFacade`、`FakeAgentRuntime`。需要时给它们加字段，例如 `errorInfo`、`activityText`。

## 要修的问题（用户原话对应）

| 用户看到的 | 原因 | 位置 |
|---|---|---|
| 发送后什么反馈都没有 | `_bootstrap` 先等网络，再打开会话，再发送草稿 | `workbench_agent_pane.dart:95-114` |
| 底部没有模型选择 | 模型列表为空时选择器被隐藏 | `composer_card.dart:367` |
| 切换会话后，原会话停了 | 切换时 dispose 了旧 facade | `workbench_agent_pane.dart:130-131` |

## 任务

1. 重写 `_bootstrap`：先本地打开会话，再并发加载模型和技能。任何网络调用都不阻塞会话显示和发送。
2. 不 dispose facade。用 `runtime.open` 取实例。切换会话时调 `runtime.markSeen`。
3. 每个会话一个 `ComposerState`。草稿和附件各自保留。无会话时用一个「新会话」草稿。
4. 空会话状态：面板里有输入卡片。发送后在原处创建会话，不跳转。
5. 反馈，按 design.md §11.6：
   - 同一帧内清空输入框，追加用户消息，发送键变停止键。
   - 对话流顶部不确定进度条。
   - 状态行：`facade.activity`，为空时写「思考中…」。`statusOf` 为 queued 时写「排队中」。
   - 超过 3 秒追加「已等待 N 秒」。计时器只在运行中存在。
   - 工具条目运行中转圈，完成后对勾或叉。
6. 错误：按 `lastErrorInfo.kind` 选文案，见 design.md §11.6 的表。带「重试」。「详情」折叠区显示状态码和 `detail`。
7. 模型选择始终显示：
   - 加载中：「模型…」加小转圈。
   - 列表为空或失败：「默认模型」。点开说明原因并提供「重试」。
   - 推理强度只在当前模型支持时显示。
8. 切换会话的竞态：快速 A 到 B，只显示 B。
9. 对话流性能：`ListView.builder`。流式更新只重建末尾条目。滚到顶部时调 `loadEarlier()`，`hasEarlier` 为真才显示「载入更早的消息」。
10. 小屏：工具行不溢出。宽度小于 360 时只显示图标。点击目标不小于 44×44。
11. 用词统一：项目、会话、项目文件、工作区文件、对话流、输入卡片、Agent 面板。

## 测试

覆盖 CHECKLIST 的 C1-C6、D1-D6、H1-H5、E2 的显示部分。要点：

- C1 只 pump 一帧就断言。
- 让 `models()` 永不返回，会话仍然显示且能发送。
- 让 `models()` 返回空，模型选择仍然在，文案是「默认模型」。
- 两个会话的草稿互不影响。
- 切换会话后，旧会话的 facade 没有被 dispose（FakeAgentFacade 记录 dispose 次数）。

## 预览截图（尽量做）

用 widget 测试里的 `RepaintBoundary.toImage` 导出 PNG。参考 `D:\MyNewProjects\qflistudio\tool\preview_test.dart` 的字体加载方式。输出到 `TASK\check\screens\pi-c\`。场景：空会话、运行中、失败、长对话。宽度 390 与 900，浅色与深色。

## 提交

分多次提交到你的分支。例：`fix(chat): show progress and a model selector as soon as a message is sent`。

## 完成标准

- CHECKLIST 的 C、D、H 全部通过。结果写进 status。
- `flutter analyze --no-pub` 无问题。你的范围内测试全过。

## 追加要求（大脑，阶段 1 进行中）

pi-D 的基线预览发现一个界面问题。390 宽下，输入卡片的权限按钮和模型按钮只剩图标，没有文字。推理强度被截成「l…」。证据：`TASK\check\screens\pi-d\preview-baseline\empty-390x844-light.png`。

要求：

1. 390 宽下，工具行每个按钮都有可读的文字，或有明确的图标加提示。
2. 模型按钮显示模型名。名字过长时省略，至少显示 6 个字符。
3. 权限按钮显示图标加短文案，例如「每次询问」。图标不得用问号。
4. 空间不够时，先收起推理强度和权限的文字，保留模型名。
5. 写一个 390 宽的 widget 测试，断言模型名和权限文案都能在界面上找到。
6. 预览工具在 pi-D 的 worktree：`D:\MyNewProjects\_wt\pi-d\qfli_studio_core\tool\agent_preview_test.dart`。可以复制到你的 `tool\` 下出截图。不要 `git add` 它，pi-D 的分支已经提交了它。
