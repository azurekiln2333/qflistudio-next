# Agent 思考过程实时流式显示

## Goal

Agent 对话实时显示模型的思考内容。思考内容放在 AI 消息气泡里，可以展开和收起。现在的做法是只在对话列表顶部显示一行「思考中…」，本任务替换这个做法。

## 用户决定（2026-11-19）

- D1：单独开任务，不并入 `11-15-agent-chat-usability`。
- D2：直接做「实时思考流」，思考内容边生成边显示。「每轮结束后补气泡」不单独交付。
- D3：交互按用户看过的草图做，细节见 R5。
- D4：官方中转、直连 Chat、直连 Responses、直连 Messages 四条路径都做。
- D5：后端（官方中转）一起做完。
- D6：本任务不开放直连模式。各产品的 `allowCustomAiEndpoint` 保持现状，以后由用户决定。
- D7：测试全部在云端 CI 运行，不在本机跑测试套件。服务端用现有的 GitHub Actions（所有分支都跑 verify）。内核目前没有 CI，本任务新增 GitHub Actions 工作流。
- D8：CI 全部通过后，直接推送、打 tag、等 CI，不再询问用户。这包括服务端 `main`，推送即上线生产。
- D9：界面不能卡顿，长流也要流畅。这是硬性验收项，见 R15。

## 现状（证据）

服务端（`azurekiln-qfli-server`）：

- 中转只有非流式路由 `POST /api/ai/chat`（`src/routes/ai.js:24`），总超时默认 60 秒（`src/ai-client.js:39`）。
- `resultData` 丢掉上游的 `reasoning_content`（`src/ai-client.js:344`）。
- 请求校验只允许 `role`、`content`、`tool_calls`、`tool_call_id` 四个消息字段（`src/ai-client.js:18`）。客户端无法回传思考内容。
- 在线终端已经用 NDJSON 流式推事件，带 `X-Accel-Buffering: no`（`src/terminal-client.js:221-246`）。生产链路支持流式响应。
- 中转上游按合规要求指向 DeepSeek 官方接口（`README.md:355`、`:369`）。
- 推送 `main` 会更新 `latest` 镜像，生产机的 watchtower 自动拉取（`README.md:450-516`）。推送等于上线。

DeepSeek 接口：

- 思考模式下请求带 `tools` 时，此前所有助手消息的 `reasoning_content` 都要原样回传，否则返回 400。来源：<https://api-docs.deepseek.com/guides/thinking_mode>。
- 流式时思考内容在 `choices[0].delta.reasoning_content`。

客户端（`qfli_studio_core` 集成 worktree，分支 `rework/integration`）：

- Agent 循环每轮整体等待结果。`vibe_coding_controller.dart:418` 调用 `_api.aiChat`。中转与直连都整轮读取（`api_client.dart:1596`、`:1679`），客户端超时 90 秒。
- 三种协议的解码器只读正文和工具调用（`lib/services/ai_service.dart:235`、`:350`、`:483`）。
- Messages 协议编码器没有开启思考（`ai_service.dart:389`）。
- 历史清洗只保留已知字段，会丢掉思考内容（`vibe_coding_controller.dart` 的 `_sanitizeHistory`）。运行中历史保留 80 条，恢复时保留 60 条。
- 状态行「思考中…」在对话列表顶部（`lib/chat/chat_transcript.dart:392-397`）。
- 界面消息模型是 `AgentMessageView`（`vibe_agent_facade.dart:83`）。
- 会话保存在 `agent_sessions/<会话id>.jsonl`（`lib/session/agent_session.dart:1-11`）。界面消息和模型历史分开保存。每次发送结束时追加新消息，再追加一份完整历史快照（`vibe_agent_facade.dart:992-1015`）。现有压缩只在坏行过半时触发（`agent_session.dart:475`）。
- 直连模式由 `StudioProfile.allowCustomAiEndpoint` 控制，默认关闭（`lib/services/studio_profile.dart:125`、`:256-261`）。所有产品都没有开启它。原因是鸿蒙正式版的隐私披露只列了「本站服务器转发的 DeepSeek」。
- 直连模式下模型目录为空，输入框不显示推理强度选择器。直连设置只有地址、密钥、模型和协议四项（`lib/store/settings_store.dart:115-123`）。
- 规范 `.trellis/spec/frontend/ai-protocols.md` 要求 Agent 循环不按协议分支。
- 合规要求 AI 回复显示「内容由 AI 生成」（`api_client.dart:77` 引用的整改任务书 §3-W2、§3-W3）。

## Requirements

- R1：官方中转新增流式回合接口，把思考内容、正文和工具调用按增量推给客户端。旧接口 `POST /api/ai/chat` 的行为不变，已发布的旧版客户端继续可用。
- R2：服务端接受助手消息携带思考内容，并转发给上游。
- R3：Agent 循环按增量消费回合结果，循环本身不按协议分支。
- R4：模型历史保存每条助手消息的思考内容。清洗、裁剪、保存和恢复都保留它。
- R5：界面显示思考气泡。
  - 思考时气泡展开，内容逐字出现，标题显示「思考中… N 秒」。
  - 正文或工具调用开始时，气泡自动收起，标题改为「已思考 N 秒」。
  - 用户可以点击展开或收起。用户手动操作过的气泡，不再自动展开或收起。
  - 一轮回复里，思考在前，正文和工具卡片在后。
- R6：AI 正文也逐字显示。
- R7：思考气泡带「内容由 AI 生成」标记。
- R8：模型不返回思考内容时，不显示思考气泡，其余行为与现在一致。
- R9：用户取消时，客户端和服务端都中断在途请求。界面保留已显示的思考内容和正文。
- R10：恢复会话时，历史里的思考气泡默认收起。
- R11：服务端保留现有限额：限流、并发、工具调用校验、正文 512 KiB 上限和审计日志。
- R12：直连 Chat、Responses、Messages 三种协议都按增量解析，并回传各协议要求的思考内容。
- R13：直连设置新增「请求思考过程」开关，默认关闭。开关只影响 Responses 和 Messages 的请求字段。
- R14：会话文件不能因为思考内容无限增长。旧历史快照累积到阈值时，应用重写文件。
- R15：流式期间界面不卡顿。思考内容或正文达到 300 KB 时，滚动对话列表仍然流畅。
- R16：内核仓库新增云端 CI，推送任何分支都运行 `flutter analyze` 和 `flutter test`。

## Acceptance Criteria

- [ ] AC1（R1、R5、R6）：用官方中转和会思考的模型发一条需要工具调用的请求。第一个思考字到达后 1 秒内出现气泡，内容持续增长。正文开始时气泡自动收起。
- [ ] AC2（R2、R4）：同一会话连续三轮工具调用都成功，上游不返回 400。
- [ ] AC3（R4、R10）：关闭应用再打开同一会话，思考气泡收起显示。再发一条消息，请求成功。
- [ ] AC4（R1）：`POST /api/ai/chat` 的响应结构除新增 `reasoning_content` 外不变。现有服务端测试全部通过。
- [ ] AC5（R8）：用不思考的模型对话，不出现思考气泡，正文仍然逐字显示。
- [ ] AC6（R9）：思考途中点取消，服务端中断到上游的请求，界面保留已显示的内容。
- [ ] AC7（R5）：用户手动展开一个已收起的气泡后，后续增量不会把它收起。
- [ ] AC8（R7）：思考气泡下方显示「内容由 AI 生成」，收起时也显示。
- [ ] AC9（R11）：超限请求和格式错误的工具调用，仍然返回现有的错误码。
- [ ] AC10（R12）：三种直连协议各有一组录制的流式样本测试，覆盖思考、正文和工具调用。Messages 样本还覆盖签名回传。
- [ ] AC11（R13）：开关关闭时，Responses 和 Messages 请求里不出现思考参数。开关打开时出现。
- [ ] AC12（R14）：一个会话追加 25 份历史快照后，文件里只剩最后一份。
- [ ] AC13：鸿蒙真机上跑通 AC1、AC3、AC6，并保存截图。
- [ ] AC14（R15）：鸿蒙真机上流式输出 300 KB 思考内容，同时滚动对话列表。性能日志里 95% 的帧不超过 16.7 毫秒，没有超过 100 毫秒的帧。
- [ ] AC15（R16）：内核和服务端的分支推送后，GitHub Actions 运行并全部通过。

## Out of Scope

- 编辑器 AI 面板（`editor/ai_panel.dart`）保持非流式。
- 开放直连模式，或修改任何产品的 `allowCustomAiEndpoint`。
- 思考内容的搜索、复制按钮和导出。
- OpenAI Responses 思考项的回传，除非实现阶段核实它是必需的。
