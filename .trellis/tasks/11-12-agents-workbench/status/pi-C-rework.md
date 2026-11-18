# pi-C 返工状态：Agent 面板的反馈、错误、输入卡片

worktree `D:\MyNewProjects\_wt\pi-c\qfli_studio_core`，分支 `rework/pi-c`，基线 `wip/baseline-20261114`。

## 已完成

- `_bootstrap` 重写：首帧后先本地打开会话，模型和技能各自并发加载，网络调用不阻塞显示和发送。
  `models()` 永不返回时会话照常显示、照常能发（D3 测试）。
- 不 dispose facade：用 `runtime.open` 取实例，切换只换显示，旧会话继续跑，切换时调
  `runtime.markSeen`。`FakeAgentFacade.disposeCount` 断言为 0。
- 每个会话一个 `ComposerState`（`_composers`），无会话时用「新会话」草稿，草稿和附件按会话保留。
- 空会话：面板里就有输入卡片，发送后在原处建会话，不跳转。
- 反馈（design §11.6）：同一帧内清空输入、`_echo` 追加用户消息、发送键变停止键；顶部不确定进度条；
  状态行 `activity` →「思考中…」，queued →「排队中」，超 3 秒追加「已等待 N 秒」；工具条目转圈、完成打勾或叉。
- 错误：按 `lastErrorInfo.kind` 选 §11.6 文案，带「重试」，折叠「详情」显示状态码和 `detail`；未知分类回退原文。
- 模型选择始终显示：加载中「模型…」加转圈；空或失败「默认模型」，点开说明原因并给「重试」；推理强度仅当前模型支持时出现。
- 切换竞态：`_openToken` 序列号，快速 A 到 B 只显示 B；新会话回传 id 当作同一会话，回声和停止键不闪掉。
- 对话流：`ListView.builder`，每条按 id 缓存 widget，内容没变就复用，流式更新只重建末尾条目
  （反向验证：去掉缓存后一次更新重建 3 条）；`hasEarlier` 为真才显示「载入更早的消息」，滚到顶调 `loadEarlier()`。
- 小屏（追加要求）：工具行按缩放后的等效宽度选档，先收推理强度的文字，再收权限的文字，模型名留到最后。
  390 宽下 `+`、盾牌「每次询问」、「DeepSe…」、推理图标（提示「推理强度：low」）、发送键都不溢出；
  900 宽下权限文案、完整模型名、`low` 三处文字都在。点击目标 ≥ 44×44，软键盘弹出时卡片按 `viewInsets.bottom` 上移。
- 权限图标不用问号：只读 `visibility`、每次询问 `shield`、自动接受 `bolt`，都带 tooltip。
- 追加要求 1-6 逐条：①每个按钮都有文字或图标加提示 ②模型名省略后仍见 6 个字符
  ③权限是图标加「每次询问」，不用问号 ④先收推理强度文字、再收权限文字、模型名留到最后
  ⑤390 宽测试断言模型名与权限文案都在 ⑥截图用 pi-D 的工具导出，未提交。
- 模型名省略规则：chip 内边距 10 → 8，390 宽下拉丁模型名能看见 6 个字符加省略号（中文名约 4-5 个）；行宽 ≥ 380 时推理强度也带文字。
- 模型按钮不吃空白：左侧一组放进 `Expanded`，模型是组内唯一可伸缩项。之前 `Spacer` 与它平分剩余宽度，模型被挤成图标。
- 提示只挂一遍：权限、模型、推理强度的提示由 chip 提供，`PopupMenuButton` 不再重复设 `tooltip`。
- 用词统一：项目、会话、项目文件、工作区文件、对话流、输入卡片、Agent 面板；`login_gate.dart` 的 `agent` 改为 `Agent`。
- 测试：新增 `test/workbench_agent_pane_test.dart` 30 例（C1-C6、D1-D4、D6、E2 显示、H1-H5、分页与长对话、
  流式只重建末尾、滚到顶载入、会话回传回归、文字缩放 1.3、390 宽文案）；`chat_composer_card_test` 增 7 例
  （D5 桌面/移动回车、模型加载态、空列表回退、390 宽文案、长模型名省略宽度、宽窗口带推理文字）；两个回归例已反向验证。
  `test/support/fake_agent.dart` 只加字段：`errorInfo`、`activity`、`hasEarlier`、`loadEarlier`、
  `disposeCount`、`sendGate`、`facades`、`openBlockers`、`modelsGate`。
- 预览截图：`check/screens/pi-c/` 16 张（`tool/preview_agent_pane_test.dart`）；`check/screens/pi-c/append/`
  12 张是追加要求的出图（390 与 900、浅色与深色，用 pi-D 的 `tool/agent_preview_test.dart` 导出）。

## 进行中

- 无。`rework/pi-c` HEAD `ed0525b` 已在 `rework/integration` 中；`tool/agent_preview_test.dart` 是 pi-D 的，
  按 brief 未跟踪、未提交。
- 阶段 2（查 pi-B）亦完成：报告 `check/pi-C-checks-pi-B.md`，状态 `status/pi-C-check.md`；
  发现 E4 大小写绕过写租约（已端到端取证）。

## 请求

- pi-A：`WorkbenchAgentPane` 构造参数未改；`sessionId` 变化即切换会话。面板自己处理登录引导。
- pi-B：我按接口使用 `lastErrorInfo`、`activity`、`hasEarlier`、`loadEarlier()`、`statusOf`、
  `liveChanges`、`liveFacade`、`markSeen`。基线里这几个成员还是占位（`statusOf` 恒 idle、
  `liveFacade` 恒 null、`open` 每次新建），真实实现落地后「切换不丢、并行继续」才真正生效。
- pi-D：`tool/preview_agent_pane_test.dart` 与你的 `tool/preview_test.dart` 不冲突，如需统一入口请合并。
  你的 `tool/agent_preview_test.dart` 我复制到本 worktree 跑过截图，没有提交（按 brief 要求）。

## 未验证

- 未验证真机：只有 widget 测试与离屏截图。触摸手感、真实字体换行未验。
- 未接真实 `AgentFacade`：全部用 `test/support/fake_agent.dart`。真实流式增量、审批时序、429 退避未验（属 pi-B 范围）。
- 全量 `flutter test --no-pub`：1562 通过、9 跳过、4 失败。3 个是允许的 `editor_run_target_test`；
  第 4 个 `interop_arkts_contract_test` 是加载失败，它按 `Directory.current.parent/qflistudio`
  找兄弟仓库，worktree 下没有该目录，属环境问题，与本范围无关（主目录有该兄弟仓库）。
- `flutter analyze --no-pub` 全仓无问题。未跑 `dart format`；新增文件未单独格式化（analyze 无告警）。
