# pi-B 状态（W-B harness、会话存储）

## 已完成

- 契约落地：`lib/session/agent_session.dart`、`lib/vibe_coding/vibe_agent_facade.dart`（design.md §5 的类与签名齐备）。
- `AgentSessionStore` 文件持久化：`FileAgentSessionStore`，一会话一 JSON，临时文件改名写入，
  坏文件跳过，列表按 `updatedAt` 倒序。
- `AgentFacade` / `AgentRuntime` 包住现有 `VibeCodingController`：消息视图、状态映射、写确认、
  自动持久化、历史恢复（只重放 user/assistant/配对 tool）、`retryLast`、`AgentLoginRequired` 门控。
- 三档权限：`readOnly` 在写工具入口拒绝、`askEveryWrite` 进 `awaitingApproval`、`autoAcceptEdits` 直写。
  拒绝以 `conflict` 回给模型且不写盘；取消与 dispose 都会结束等待，不会挂住整轮。
- `search_text` 工具：模式、路径、结果上限、正则、大小写；跳过隐藏/依赖目录、符号链接与二进制文件。
- 模型列表接 `GET /api/ai/models`，失败回退设置里的单个模型；推理强度按服务端 `reasoning_efforts`
  显示，客户端只在选中时下发 `reasoning_effort`（Chat/Responses；Messages 协议不猜参数）。
- 服务端 `src/ai-client.js` 放行并透传 `reasoning_effort`，`/models` 公布可选值；
  由 `QFLI_AI_REASONING_EFFORTS` 开关控制，未配置时一律不发送。
- skill：新增用户级目录 `~/.qfli/skills`；优先级按大脑决定改为 内置 < 用户级 < 项目级
  （项目技能覆盖同名内置，与改动前一致）。design.md §6 那一句已改正。
- 工作区文件附件：`send` 的 `attachedPaths` 中位于项目外的路径规范化后进入该会话的只读白名单，
  `read_file` 可读；写、编辑、列目录、搜索仍只限项目根。白名单命中后读取时再校验：
  必须是普通文件、不得是符号链接、路径不得经由链接逃逸；上限 64 条。
- 测试：新增 `agent_session`(9)、`vibe_search_text`(12)、`vibe_controller_agent_hooks`(8)、
  `vibe_agent_facade`(13)、`ai_reasoning_effort`(8)、`vibe_attachment_read`(13)，共 63 例通过；
  服务端 `test/ai-relay.test.js` 增 2 例，28 例通过；既有 vibe 测试改 2 处工具数断言（8 → 9）。
- 验证：`flutter analyze lib` 无问题；本范围 14 个测试文件 209 例通过；studio `flutter analyze` 无问题。

## 进行中

- 无。

## 请求

- **给 pi-C：附件传参格式**。`AgentFacade.send(text, attachedPaths: [...])`：
  项目内文件传相对路径（`a/b.txt`，`/` 分隔）；工作区其他项目的文件传绝对路径（反斜杠或正斜杠都行，
  内部统一规范化）。项目外的会登记为本会话只读白名单并以绝对路径写进用户消息，模型即可 `read_file`；
  项目内的保持相对路径，不进白名单。重复自动去重，上限 64 条；目录、符号链接、不存在的路径在读取时
  被拒（`escape` / `not_found`）。白名单只对读取生效，写/编辑/列目录/搜索仍在项目根内。
  白名单不落盘，重开会话后需要重新附加。选择器里那条「agent 取不到正文」的限制标注可以撤掉了。
- `lib/pages/project/project_page.dart:368`（`prefer_function_declarations_over_variables`，pi-C）。
- `test/workbench_shell_test.dart:25`（`unused_element_parameter`，pi-A）。
- 既有失败非本范围：`editor_run_target_test` 3（基线已记录）、`retained_editor_test` 7、
  `retained_editor_restore_control_integration_test` 2、`widget_test` 3。这些文件不引用 vibe/AI 代码，
  报错都是「编辑器/抽屉/主页导航没打开」，判断来自 W-A 布局改动或基线 `editor_page.dart` 改动，请 pi-A 确认。
- 契约新增成员（都是 additive）：`AgentFacade.permission` 读写、`AgentFacade.flush()`、
  `AgentMessageView.pending/aiGenerated`、`AgentSessionStore.metaOf/read/write` + `AgentTranscript`。
- `dart format`（当前 SDK 新风格）重排了 `vibe_coding_controller.dart` 与 `vibe_coding_controller_test.dart`
  的部分既有行，纯格式，无行为变化。
- 服务端改动需部署，且需配置 `QFLI_AI_REASONING_EFFORTS` 才会出现推理强度选择器。

## 未验证

- harness 未接任何界面，也未在真机/桌面跑过；`VibeCodingPanel` 仍无 UI 引用，体验无数据。
- 真实上游是否接受 `reasoning_effort`：只在本地 mock 上游验证了透传。
- 直连模式的模型列表返回空并回退设置模型，未对真实上游 `/models` 验证。
- 移动端 `HOME` 可能为空，此时没有用户级 skill；未在设备确认。
- 附件白名单只在 Windows 上验过（符号链接拒绝已真实触发）；macOS/Linux 与移动端沙箱未验。
- 会话恢复只重放 user/assistant/配对的 tool；终端与文件读缓存、附件白名单都不恢复。
