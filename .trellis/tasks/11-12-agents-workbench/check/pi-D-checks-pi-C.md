# pi-D 检查 pi-C

检查对象：pi-C（Agent 面板的反馈、错误、输入卡片）。
检查 worktree：`D:\MyNewProjects\_wt\check-d\qfli_studio_core`，分支 `check/pi-d`，内容为 `rework/integration`（HEAD `a43b7df`）。
基线：`wip/baseline-20261114`。

## 汇总

通过 21 项。不通过 6 项。未验证 0 项。

- 全量 `flutter analyze --no-pub`：`No issues found! (ran in 12.2s)`
- 全量 `flutter test --no-pub`：`1604 通过、9 跳过、4 失败`。4 个失败 = `editor_run_target_test` 的 3 个（允许）+ `interop_arkts_contract_test` 的 1 个（已知环境问题，按要求忽略）。
- 独立测试：`tool/pi_d_check_test.dart` 24 例全过（自建场景，未复用 pi-C 的断言）。
- 截图：`check/screens/integration/` 18 张。
- 范围合规：`git diff --stat wip/baseline-20261114..rework/pi-c -- lib test` 只动 7 个文件，
  全在 pi-C 的独占范围（`lib/chat/**`、`lib/shell/login_gate.dart`、`lib/shell/workbench_agent_pane.dart`）
  与允许的测试（`chat_composer_card_test`、`support/fake_agent`、新增 `workbench_agent_pane_test`）。
  `--diff-filter=DR` 无删除无重命名；基线里原有的测试文件一个都没改。

## 结果

| ID | 结果 | 证据 |
|---|---|---|
| C1 | 通过 | 独立测试「C1 一帧内清空输入、出现用户消息、发送键变停止键」：只 pump 一帧，输入为空、对话流有该条、`composer-stop` 在、`composer-send` 不在 |
| C2 | 通过 | 独立测试「C2 进度条是不确定进度」：`LinearProgressIndicator.value == null`，且其底边在 `ListView` 顶边之上 |
| C3 | 通过 | 独立测试「C3 状态行随 activity 与排队变化」：`正在写入 lib/a.dart` → `思考中…` → `排队中` 三态都命中 |
| C4 | 通过 | 独立测试「C4 3 秒前不显示，3 秒后显示」：2 秒无 `chat-waiting`，3 秒显示「已等待 3 秒」，5 秒显示「已等待 5 秒」，结束后消失 |
| C5 | 通过 | 独立测试「C5 工具条目」：`tool-spinner-x1`、`check_circle_outline`、`cancel_outlined` 各一，文案 执行中/完成/失败 各一 |
| C6 | 通过 | 独立测试「C6 取消后恢复可输入」：`cancelCount == 1`，发送键回来且输入后可点 |
| D1 | 不通过 | 见「不通过项 1」。切到第二个会话后推理强度按钮消失 |
| D2 | 不通过 | 见「不通过项 1」。模型列表非空，切会话后仍显示「默认模型」 |
| D3 | 通过 | 独立测试「D3 模型加载中」：`models()` 永不返回时显示「模型…」+ 转圈，会话与发送不受影响 |
| D4 | 通过 | 独立测试「D4 草稿与附件按会话保留」：A 写草稿 → 切 B 为空 → 切回 A 草稿还在 |
| D5 | 通过 | 独立测试「D5 桌面 Enter 发送」「D5 移动端回车不发送」：桌面 Enter 发出 1 条，Shift+Enter 不发送；移动端回车不发送。注：widget 测试的按键事件不插字符，换行本身无法在此断言 |
| D6 | 通过 | 独立测试「D6 软键盘弹出时输入卡片上移」：`viewInsets.bottom = 280` 时卡片底边上移 280±1 |
| G2 | 通过 | 独立测试「G2 文字缩放 1.3 在 390 宽不溢出」：`takeException()` 为 null |
| G3 | 通过 | 独立测试「G3 工具行点击目标不小于 44×44」：加号/权限/模型/推理/发送 5 个 key 的 Size 均 ≥ 44 |
| G4 | 不通过 | 见「不通过项 2」。`attachment_picker.dart:233` 用户可见文案写小写 `agent` |
| G5 | 不通过 | 见「不通过项 3」。对话流把 `search_text` 原样显示给用户 |
| G6 | 通过 | `Select-String -Path lib\chat\*.dart,lib\shell\*.dart -Pattern 'Color\(0x'` 无匹配 |
| G7 | 不通过 | 见「不通过项 4」。无文件空状态只有说明，没有主操作 |
| H1 | 通过 | 独立测试「H1 未登录」：`LoginGuideCard` 在、`chat-error` 不在、`ComposerCard` 不在、`openedSessions` 为空 |
| H2 | 通过 | 独立测试「H2 503 文案」：命中「AI 服务暂未开通（服务端未配置），请联系管理员」 |
| H3 | 通过 | 独立测试「H3 429 文案」：命中「请求太频繁，已自动重试仍失败，请稍后再试」 |
| H4 | 通过 | 独立测试「H4 断网文案」：命中「网络不可用，检查网络后重试」 |
| H5 | 通过 | 独立测试「H5 每种错误都有重试」：5 种 kind 各命中文案 + `chat-retry`，展开「详情」见「状态码：503」与原文，点重试 `retryCount == 1` |
| I1 | 通过 | `git grep -nE "sk-[A-Za-z0-9]{8,}|Bearer [A-Za-z0-9]{8,}|password *[:=]" -- lib test tool` 只命中变量名（`_password` 等），无密钥；status/check 文档无匹配 |
| I2 | 不通过 | 见「不通过项 5」。主目录在快照后被写过 |
| I3 | 通过 | `git reflog` 只有 commit 与一次 `reset: moving to HEAD`（03:08:39，worktree 建立时，早于 pi-C 首个提交 03:13:49），无 stash/clean/rebase/merge 越权 |
| I4 | 通过 | `git log --format=%B wip/baseline-20261114..HEAD` 无 `Co-Authored-By`、`Generated with`、AI 署名 |

## 不通过项

1. **D1、D2：切换会话后模型名与推理强度丢失。** 现象：在会话 A 选好模型（chip 显示 `Model One`、推理强度 chip 在），切到会话 B 后 chip 变成「默认模型」，推理强度 chip 消失；此时模型列表非空。原因：`WorkbenchAgentPane._composerFor` 为每个会话新建 `ComposerState`（`modelId` 为 null），而 `ComposerCard.didUpdateWidget` 只在 `models` 列表变化时调 `_syncDefaultSelection()`，换 `state` 时不调。后果：切会话后发送的 `modelId`/`reasoningEffort` 为 null，服务端用默认模型，用户看不到自己选过的模型。负责人：pi-C。建议：`didUpdateWidget` 里 `!identical(oldWidget.state, widget.state)` 时也调 `_syncDefaultSelection()`；或在 `_createComposer()` 里用当前模型选择初始化新 `ComposerState`。证据：`tool/pi_d_switch_test.dart` 输出 `Found 0 widgets with text "Model One"`；截图 `running-390x844-light.png`、`failed-503-390x844-light.png`、`long-390x844-light.png` 的模型 chip 都是「默认模型」，而 `empty-390x844-light.png` 是「DeepSeek…」。

2. **G4：用户可见文案里 `agent` 小写。** `lib/chat/attachment_picker.dart:233`「这些文件来自其它项目，agent 只读，不能修改。」。同批其它文案已统一为「Agent」（`login_gate.dart:81`、`chat_transcript.dart:28`）。负责人：pi-C。建议改成「Agent 只读」。

3. **G5：对话流把工具标识 `search_text` 原样显示。** `vibeToolLabel`（`lib/vibe_coding/vibe_coding_widgets.dart`）只映射 8 个工具，`search_text` 是 `vibe_tools.dart:832` 注册的真实工具，落到 `_ => toolName` 分支。证据：`long-390x844-light.png` 第二条工具条目显示「search_text」。该文件与基线一致（`git diff` 为空），属基线遗留，不是本轮回归。负责人：未分配（建议 pi-B 或后续任务）。建议补 `'search_text' => '搜索文本'`。

4. **G7：无文件空状态没有主操作。** `attachment_picker.dart` 的 `_emptyState` 只有图标、标题、说明，没有按钮；「这个项目还没有文件」时用户只能关掉选择器。无会话空状态同样没有按钮，靠下方输入卡片充当主操作（可接受，但建议在空状态里给一个「新建会话」按钮）。未登录空状态有「登录」按钮，通过。负责人：pi-C。建议给 `_emptyState` 加一个可选 `action`。

5. **I2：主目录在快照之后被写过。** 快照 `_backups\workbench-rework-20261114-025148\`（02:51:48）里 `core-tracked.patch` 含 `lib/pages/home_page.dart`、`test/retained_editor_test.dart`、`tool/vibe_e2e_runner.dart` 的改动；现在主目录这三个文件里前两个已无 diff（`git diff --stat` 只剩 `vibe_e2e_runner.dart` 2 行），且 `home_page.dart`、`retained_editor_test.dart` 的 mtime 是 02:52:10。即快照后 22 秒有人把这两个文件还原了。`git reflog` 无新提交，HEAD 仍是 `573d1b6`。无法归因到具体 pi（早于 pi-C 首个提交）。pi-A 的 `status/pi-A-check.md` 已报同一问题（含 `fake_agent.dart` 03:07:55、`vibe_agent_facade.dart` 03:13:35）。负责人：大脑。建议：确认这是有意的清理，并在任务文档里记一笔。

## 我设计的破坏性场景

1. **models 永不返回 + `open` 抛错。** 结果：界面仍显示输入卡片，出现「打不开这个会话，请重试。」和「重试」按钮，输入框可输入。通过。
2. **4000 字错误详情 + 390 宽。** 结果：`takeException()` 为 null，无溢出；详情在折叠区里。通过。
3. **只有附件没有文字。** 结果：`canSend` 为真，发送键可点，`onSend` 收到 `('', ['lib/a.dart'])`。通过。
4. **运行中切走再切回。** 结果：切回后停止键与进度条都在，`disposeCount == 0`。通过。

## 额外发现

- **C3 文案**：`awaitingApproval` 时状态行写「思考中…」（`activity` 为空）。用户正在被要求确认写入，却看到「思考中」。建议 `awaitingApproval` 时写「等待你确认」。证据：`long-390x844-light.png`。
- **截图工具限制**：`tool/agent_editor_scenes_test.dart`（未跟踪，未提交）用 `EditorPage(agentEnabled: true, agentRuntime: FakeAgentRuntime(...))` 出图。390 宽下 7 个场景全部可出图；900/1280 下无法通过 UI 选中会话（侧边栏/抽屉在 medium/wide 下点不到会话行），因此 `running`/`long`/`failed-*`/`sessions`/`drawer` 只保留 390 的图，900/1280 只保留 `empty`。已删除会误导的 900/1280 图。宽屏对话流可参考 pi-C 的 `check/screens/pi-c/append/*-900x1000-*`。
- **截图里代码区是色块**：测试环境没注册代码编辑器用的字体族，`lib/main.dart` 的正文渲染成方块。这是出图工具的限制，不是应用缺陷；Agent 面板与输入卡片的中文正常。
- **`empty-1280x800-light.png`**：宽屏右栏展开后是「开始一个新的会话」+ 输入卡片，模型 chip 显示「DeepSeek…」（省略号），权限是盾牌图标，推理强度是图标加提示。符合追加要求 1-6。
- **`sessions-390x844-light.png`**：五种状态齐全——运行中（转圈）、排队中（时钟）、待确认（紫点）、失败（红点）、已完成（蓝点），标题与「刚刚」时间都在。
- **`drawer-390x844-light.png`**：抽屉顶部「文件 | 会话」分段，文件分段选中，文件树与「工作区 · 1 个项目」正常。
- **`failed-503-390x844-light.png` / `failed-offline-390x844-light.png`**：错误条文案正确，带「详情」折叠与「重试」。
- **`long-390x844-light.png`**：工具条目（完成/失败）、AI 标识、写确认卡片（拒绝/允许）都正常。
- 未验证：真机触摸手感、真实字体换行、真实 `AgentFacade` 的流式与 429 退避（属 pi-B 范围）。
