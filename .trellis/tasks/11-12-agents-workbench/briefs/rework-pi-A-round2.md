# pi-A 第二轮

先读 `RULES-rework.md`。

- 你的状态文件换成 `TASK\status\pi-A-rework-2.md`。四节，不超过 60 行。
- 最后一条回复：`DONE <该状态文件路径>`。

## 大脑的决定

回答你的请求 1、2、3。

目标：基线里的旧测试一个都不改。同时界面按用户要求，把「文件 | 会话」放在侧边栏顶部，文件树之上。

做法：用一个开关把两种形态分开。

1. `EditorPage` 新增参数 `agentEnabled`，默认 `false`。
   - 关闭时，编辑器页与基线行为一致。菜单「AI 助手」仍打开旧 `AiPanel`。没有 agent 入口、没有分段、没有右栏。
   - 直接构造 `EditorPage` 的旧测试因此不受影响。
2. 开启由宿主决定。在 `retained_editor_host.dart` 构造 `EditorPage` 时传 `agentEnabled: StudioProfile.current?.offlineOnly != true`。`home_page.dart` 不动。
3. 开启时：
   - 菜单「AI 助手」改为打开 Agent 面板。应用内只有一个 AI 入口。旧 `AiPanel` 不再显示。
   - 「文件 | 会话」分段放在侧边栏顶部，文件树卡片之上。去掉你放在顶栏的替代分段。
   - 顶栏保留一个 agent 图标按钮，带角标。
4. 抽屉里的分段保持现状。
5. 其余行为不变。

## 验证

1. 运行全部旧测试。开启模式下，走宿主的旧测试如果失败，改实现，不改测试。
2. `editor_pad_layout_test`、`main_editor_short_height_test` 不改一行就必须通过。
3. 新增或更新你自己的测试：
   - 开关关闭：没有 agent 控件，「AI 助手」仍打开旧 `AiPanel`。
   - 开关开启：分段在侧边栏顶部，「AI 助手」打开 Agent 面板。
4. 如果开启模式下，旧测试只能靠改断言才能通过，停下来。在状态文件的「请求」里写清是哪条测试、哪条断言、为什么。不要自己改。

## 其他

- 请求 3（`WorkbenchAgentPane` 切换会话时 dispose facade）已转给 pi-C，你不用管。
- 每个 worktree 旁已加 `qflistudio` 目录链接。`interop_arkts_contract_test` 现在能找到文件。重跑全量测试，确认它不再失败。
- 提交到你的分支。
- 把 `agentEnabled` 传给页内所有构造 `EditorPage` 的地方，例如切换项目时的回退分支。
