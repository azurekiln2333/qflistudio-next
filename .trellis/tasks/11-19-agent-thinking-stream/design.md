# 技术设计：Agent 思考过程实时流式显示

## 1. 边界

| 层 | 仓库 / 分支 | 负责 |
|---|---|---|
| 服务端中转 | `azurekiln-qfli-server`，基于 `main` `d919a91` | 新流式路由、思考内容回传、空闲超时、限额、审计 |
| 传输与协议适配 | `qfli_studio_core`，基于 `rework/integration` `b7f3d40` | `ApiClient.aiChatStream`、三种协议的 SSE 解析、中转 NDJSON 解析、回退 |
| Agent 循环与历史 | 同上 | 控制器消费事件流、历史携带思考内容、按字节裁剪、会话文件压缩 |
| 界面 | 同上 | 思考气泡、自动收起、用户覆盖、AI 标记、直连设置的思考开关 |

主应用 `qflistudio` 不改代码，只改本任务文档和规范。
`editor/ai_panel.dart` 继续用非流式 `aiChat`，不受影响。

## 2. 回合事件契约（内核内部）

所有路径都转换成同一种事件流。Agent 循环只认这个类型，不按协议分支（遵守 `spec/frontend/ai-protocols.md` §3）。

```dart
/// 一次模型回合的增量事件。放在 lib/services/ai_turn_event.dart。
sealed class AiTurnEvent {}

/// 思考内容增量。
final class AiReasoningDelta extends AiTurnEvent { final String text; }

/// 正文增量。
final class AiContentDelta extends AiTurnEvent { final String text; }

/// 某个工具调用开始（第一次看到名字）。只用于界面提示，不执行。
final class AiToolCallStarted extends AiTurnEvent {
  final int index;
  final String name;
}

/// 回合结束。result 是权威结果，写历史、执行工具都只用它。
final class AiTurnCompleted extends AiTurnEvent { final AiChatResult result; }
```

`AiChatResult` 增加字段：

- `reasoning`（String，默认空串）：本轮完整思考内容。
- `rawMessage` 可以带内部字段：
  - `reasoning_content`（String）：Chat 协议和中转路径使用。
  - `reasoning_blocks`（List）：只用于直连 Messages 协议。保存 `{type: thinking, thinking, signature}` 和 `{type: redacted_thinking, data}`，原样回传。

错误照旧抛 `ApiException`。流中途出错时，先发出的增量已经显示，随后流抛错。

`ApiClient` 新增方法，`aiChat` 保持不变：

```dart
Stream<AiTurnEvent> aiChatStream({
  required String token,
  required List<Map<String, dynamic>> messages,
  List<Map<String, dynamic>>? tools,
  Future<void>? abortTrigger,
  AiEndpoint? endpoint,
  String? model,
  String? reasoningEffort,
});
```

## 3. 服务端中转

### 3.1 新路由

`POST /api/ai/chat/stream`。鉴权、请求体结构、限流、并发与 `/chat` 相同（复用 `validateRequest`、`withRequest`）。

上游请求在原有字段上加 `stream: true` 和 `stream_options: {include_usage: true}`。

响应格式沿用在线终端的先例（`src/terminal-client.js:221-246`）：

- 响应头：`Content-Type: application/x-ndjson; charset=utf-8`、`Cache-Control: no-store, no-transform`、`X-Accel-Buffering: no`。
- 背压处理：抽取终端的 `openStream` 写入逻辑为共用函数，AI 和终端都调用它。
- 每行一个事件：

| `type` | 字段 | 说明 |
|---|---|---|
| `start` | `model`、`aiGenerated: true` | 拿到上游 200 后发出 |
| `reasoning` | `text` | 上游 `delta.reasoning_content` 或 `delta.reasoning` |
| `content` | `text` | 上游 `delta.content` |
| `tool_call` | `index`、`name` | 某个调用第一次出现名字时发一次 |
| `result` | 与 `/chat` 响应相同，`message` 另带 `reasoning_content` | 校验通过后的权威结果 |
| `error` | `status`、`error` | 响应头已发出后的错误，带内传递 |

头发出前的错误（鉴权、限流、请求校验、上游非 200）照旧返回 HTTP 状态码和 `{error}`，和 `/chat` 一致。

### 3.2 上游 SSE 组装

- 按行读，只处理 `data:` 行。`[DONE]` 结束。`:` 开头的注释行（DeepSeek 的 keep-alive）只用来重置空闲计时。
- 工具调用按 `index` 累积 `id`、`name` 和 `arguments`。结束后交给现有 `validateToolCalls`（允许 `index`），再去掉 `index`。
- 正文和思考分别累积。结束后走 `resultData` 同一套规则，生成 `result`。
- 上限：
  - 正文 512 KiB（沿用 `MAX_RESPONSE_TEXT`）。
  - 思考 512 KiB（新增 `MAX_REASONING_TEXT`）。
  - 上游总字节 4 MiB（新增 `MAX_STREAM_BYTES`）。
  - 单行 1 MiB。
  - 超限时发 `error` 事件（502），并中断上游。

### 3.3 超时

| 计时 | 变量 | 默认 | 范围 |
|---|---|---|---|
| 首字节 | 沿用 `QFLI_AI_TIMEOUT_MS` | 60 秒 | 不变 |
| 空闲 | 新增 `QFLI_AI_STREAM_IDLE_MS` | 60 秒 | 5–300 秒 |
| 总时长 | 新增 `QFLI_AI_STREAM_MAX_MS` | 600 秒 | 60–1800 秒 |

任何字节到达都重置空闲计时。客户端断开时中断上游，沿用 `withRequest` 的 `res.close` 处理。注意流正常结束时也会触发 close，这时上游已经读完。

### 3.4 思考内容回传

- `MESSAGE_KEYS` 加 `reasoning_content`，只允许 `assistant` 角色携带。值必须是字符串，不超过 256 KiB。其他角色带这个字段返回 400。
- `validateMessage` 把它保留在规范化消息里，转发给上游。`/chat` 和 `/chat/stream` 都生效。
- `/chat` 的 `resultData` 也带回 `reasoning_content`。这是新增字段，旧客户端忽略它。
- 整个请求体上限 512 KiB 不变。客户端负责按字节裁剪历史（§5.3）。路由的 `express.json` 上限 640 KiB 不变。

### 3.5 审计和日志

流正常结束后写审计：action 仍为 `ai.chat`，detail 写 `model=… toolCalls=N stream=1 reasoningChars=N`。不记录思考内容和正文。中途失败写 `ai.dispatch_failed` 日志，带 `phase: stream`。

### 3.6 兼容性

- 旧客户端只调 `/chat`，行为不变。新增的 `reasoning_content` 是附加字段。
- 新客户端遇到旧服务端，`/chat/stream` 会返回 404。客户端自动回退到 `/chat`，把结果包装成单个 `AiTurnCompleted`。所以服务端和客户端谁先上线都可以。

## 4. 客户端传输与协议适配

### 4.1 中转路径

- 用 `http.AbortableRequest` 发 POST，按行解码 NDJSON，把每行映射成 `AiTurnEvent`。
- 404 或 405 时回退 `aiChat`。
- 超时改为首字节 90 秒、空闲 90 秒，不设总时长上限。服务端已经有总时长上限。
- 收到 `error` 事件时抛 `ApiException(status, error)`，沿用 `_aiErrorMessage` 的文案规则。

### 4.2 直连路径

`AiService.encodeRequest` 增加 `stream` 参数，流式时各协议加对应字段。响应是 `text/event-stream` 时按协议解析。响应是 JSON 时说明上游不支持流式，就整体解码，只发一个 `AiTurnCompleted`。

| 协议 | 请求 | 思考事件 | 正文事件 | 工具调用 | 结束 |
|---|---|---|---|---|---|
| Chat | `stream: true` | `delta.reasoning_content`，或 `delta.reasoning` 为字符串时 | `delta.content` | `delta.tool_calls[]` 按 `index` 累积 | `[DONE]` |
| Responses | `stream: true`。思考开关开启时加 `reasoning: {summary: "auto"}` | `response.reasoning_summary_text.delta`、`response.reasoning_text.delta` | `response.output_text.delta` | `response.output_item.added`（function_call）加 `response.function_call_arguments.delta` | `response.completed`，用其 `response` 走现有 `_decodeResponses` |
| Messages | `stream: true`。思考开关开启时加 `thinking: {type: enabled, budget_tokens: 8192}`，`max_tokens` 提到 16384 | `content_block_delta` 的 `thinking_delta` | `text_delta` | `content_block_start`（tool_use）加 `input_json_delta` | `message_stop` |

### 4.3 思考内容回传（直连）

- Chat：历史里的助手消息带 `reasoning_content` 时，编码器原样发出。这个字段只有在上游曾经返回过思考内容时才存在，所以不会发给不认识它的上游。
- Messages：助手消息带 `reasoning_blocks` 时，编码器把这些块放在该消息 `content` 的最前面，然后才是 text 和 tool_use。签名原样保留。这是 Anthropic 在开启思考的工具循环里的要求。
- Responses：不回传思考内容。无状态调用不回传思考项也能继续对话。实现时用真实接口核实，如果需要回传，就记为延后项。

### 4.4 直连设置的思考开关

- `SettingsStore` 新增 `aiThinking`（bool，默认 false），存进设置文件。旧文件没有这个字段时按 false 读。
- 设置页的直连区域加一个开关，文案为「请求思考过程」。
- 开关只影响 Responses 和 Messages 的请求字段。Chat 协议不需要额外参数，由模型自己决定是否思考。
- 默认关闭的理由：不支持思考的模型收到 `reasoning` 或 `thinking` 参数会返回 400。

## 5. Agent 循环与历史

### 5.1 消费事件流

`vibe_coding_controller.dart` 把 `await _api.aiChat(...)` 换成 `await for (final event in _api.aiChatStream(...))`。`AgentRequestScheduler.run` 的名额要覆盖整个流的消费过程，不能在拿到 Stream 对象时就归还。

每轮的界面消息：

1. 收到第一个 `AiReasoningDelta` 时，追加一条 `VibeMessage(kind: reasoning, pending: true)`，并记下开始时间。
2. 之后的思考增量拼接到这条消息上。
3. 收到第一个 `AiContentDelta` 或 `AiToolCallStarted` 时，思考消息改为 `pending: false`，写入 `durationMs`。
4. 正文增量追加或更新一条 `pending` 的助手文本消息。
5. 收到 `AiTurnCompleted` 后，用 `result` 校准思考和正文的最终文本，再走现有的工具执行流程。

界面刷新按 §6.1 处理：每帧最多刷新一次，只重绘正在增长的消息。

### 5.2 取消和失败

- 取消时触发 `abortTrigger`，退出 `await for`。已显示的思考和正文消息改为 `pending: false` 并保留。这一轮不写入模型历史，和现在一样。
- 流中途失败时，保留已显示的内容，然后走现有的 `_fail`。

### 5.3 历史

- 助手历史条目保存 `reasoning_content` 和 `reasoning_blocks`（如果有）。
- `_sanitizeHistory` 保留这两个字段：前者必须是字符串，后者必须是由 Map 组成的列表，且只保留已知键。
- `_trimHistory` 在现有 80 条的规则上，再加一条字节预算：序列化后的历史超过 448 KiB 时，从最旧的完整轮次开始丢。裁剪起点不能是 `tool` 条目，这条规则不变。448 KiB 给中转的 512 KiB 留出余量。

### 5.4 界面消息模型

- `VibeMessage` 新增 `kind`（`text` | `reasoning`，默认 `text`）和 `durationMs`（int?）。
- `AgentMessageView` 新增 `role: 'reasoning'` 和 `durationMs`，`toJson` 和 `fromJson` 都处理。旧会话文件没有这些字段，照常读取。
- 思考消息的 `aiGenerated` 恒为 true。
- 门面新增 `ValueListenable<String>? liveTextOf(String messageId)`。消息在流式中时返回它的实时文本，结束后返回 null。界面用它只重绘这一条消息（§6.1）。这个签名放进阶段 0 的契约提交。

### 5.5 会话文件压缩

`agent_session.dart` 新增一种压缩触发条件：`hs` 快照超过 20 行，或文件超过 8 MiB。

触发后重写 `.jsonl`，只保留文件头、全部 `m` 行和最后一份 `hs`。

- 计数在追加 `hs` 时累加。打开会话时用现有的反向扫描顺带统计。
- 重写沿用现有的 `_rewrite`，大文件交给独立 isolate 处理。

## 6. 界面

在 `chat_transcript.dart` 里，`role == 'reasoning'` 的消息渲染成 `ThinkingBubble`：

```
┌ 💭 思考中… 12 秒 ─────────────── ▾ ┐   pending：默认展开，计时每秒刷新
│ 思考内容（弱化配色，可选中复制）     │
└────────────────────────────────────┘
┌ 💭 已思考 18 秒 ───────────────── ▸ ┐   完成：默认收起
└────────────────────────────────────┘
  内容由 AI 生成
```

- 展开状态取用户手动设置过的值。没设置过时等于 `pending`。手动设置按消息 id 存在 transcript 的 State 里，不落盘。
- 恢复的会话里 `pending` 为 false，所以默认收起。
- 没有 `durationMs` 时（例如取消），标题写「已思考」，不写秒数。
- 「内容由 AI 生成」标记始终显示在气泡下方，收起时也显示。
- 顶部状态行保留：它还承担排队和等待确认的提示。
- 点击区域至少 44×44，与现有侧栏规范一致。

### 6.1 流畅度（硬性要求）

- **只重绘正在增长的那条消息。** 流式消息各自持有一个 `ValueNotifier`。增量只更新它，不调用控制器或门面的 `notifyListeners`，所以对话列表不重建。回合结束时才整体通知一次。
- **每帧最多刷新一次。** 增量先进缓冲，用 `SchedulerBinding.scheduleFrameCallback` 在下一帧合并写入。这条规则替换 §5.1 的 50 毫秒合并。
- **分块渲染，只重排最后一块。** 长文本按换行切成约 2 KB 的块。已完成的块缓存成固定的 widget，增量只让最后一块重新布局。正文和思考内容都用这套做法。
- **流式时用普通 `Text`。** 结束后再换成可选中的 `SelectableText`。`SelectableText` 在长文本上布局开销大。
- **流式时气泡高度固定。** 展开的思考气泡流式时最高 240 像素，内部滚动并自动跟随末尾。这样对话列表的布局不会每帧跳动。结束后用户展开时显示完整内容，仍然分块渲染。
- **收起的气泡不构建正文。** 收起时只渲染标题行。
- **解析不阻塞界面。** NDJSON 和 SSE 按行解析，单行 JSON 解码开销很小，留在主 isolate。服务端已经限制单行最长 1 MiB。
- **验收方法。** 用 `tool/device_ui.sh` 读鸿蒙真机的性能日志，对应 prd AC14。

## 7. 取舍

- **中转用 NDJSON 而不是透传上游 SSE。** 服务端能统一校验工具调用、执行限额，客户端只解析一种中转格式。代价是服务端要写一个 SSE 组装器。
- **`result` 事件是唯一权威结果。** 增量只用于显示，历史和工具执行只认最终结果。服务端校验失败时不会执行任何半成品工具调用。
- **思考消息作为单独的消息条目。** 不在助手文本消息里加字段，这样持久化、恢复和渲染都是独立路径，对现有文本消息零影响。
- **直连思考开关默认关闭。** 现在没有产品开放直连，默认关闭不影响任何用户。以后开放直连时再决定默认值。

## 8. 上线与回滚

- 测试全部在 GitHub Actions 上跑。服务端已有工作流，所有分支推送都跑 verify。内核新增 `.github/workflows/core-check.yml`，所有分支推送都跑 `flutter analyze` 和 `flutter test`。Flutter 版本由阶段 0 按内核 `pubspec.yaml` 的 SDK 约束确定。
- CI 通过后直接推送、打 tag，不再询问用户（prd D8）。
- 服务端先上线：改动是附加的，旧客户端不受影响。推送 `main` 会由 CNB 更新 `latest`，生产机的 watchtower 会自动拉取。
- 回滚服务端：按 README「升级与回滚」把 `QFLI_SERVER_IMAGE` 固定到旧 digest。新客户端会自动回退到 `/chat`。
- 回滚客户端：回退内核提交即可。服务端的新路由无人调用，没有副作用。

## 9. 待实现阶段核实

- DeepSeek 的模型列表里哪个模型会思考，以及如何开启思考。用真实接口确认气泡能出现。
- DeepSeek 流式输出的工具调用格式是否与 OpenAI 一致。
- OpenAI Responses 无状态调用不回传思考项时，工具循环是否正常。
- 生产链路的反向代理是否缓冲 NDJSON。终端已经在生产上流式工作，预计没有问题，上线后用真机确认。
