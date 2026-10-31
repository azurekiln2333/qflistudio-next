# AI endpoint protocols

## 1. Scope / Trigger

Apply this contract when adding or changing a model endpoint, a protocol
adapter, the tool-call translation, or the AI section of settings. The source of
truth is `qfli_studio_core/lib/services/ai_service.dart` and the AI methods in
`lib/services/api_client.dart`, owned by the `ai-protocols-websearch` task.

Status: `Draft`. `AiProtocol`, `AiService.endpoint` and `endpointFor` exist. The
per-protocol response translation, the injectable debug endpoint and the search
tools are provisional until that task reports them frozen.

## 2. Signatures

```dart
enum AiProtocol {
  chat('chat_completions'),   // POST {base}/v1/chat/completions
  responses('responses'),     // POST {base}/v1/responses
  messages('messages');       // POST {base}/v1/messages
}

abstract final class AiService {
  static String endpoint(String baseUrl, [AiProtocol protocol = AiProtocol.chat]);
  static String endpointFor(String baseUrl, {AiProtocol protocol = AiProtocol.chat, ...});
}
```

`AiProtocol.parse` maps an unknown or null value to `AiProtocol.chat`. Endpoint
joining accepts a base that already ends in `/v1` or in the protocol path, so a
saved base is never doubled.

## 3. Contracts

- One `AiProtocol` value per request. The client never mixes shapes in one turn.
- The tool definition list stays in the OpenAI function shape regardless of the
  wire protocol. The adapter translates to and from that shape, so the agent
  loop in `vibe_coding_controller.dart` stays unchanged.
- The assistant message is preserved verbatim in the conversation history,
  including `tool_calls`, and every tool result is answered with the matching
  id. A protocol that cannot carry an id must synthesize one and keep the
  mapping for the turn.
- `messages` requires `max_tokens`; the adapter supplies a default when the
  caller omits it.
- The client never sends a model name or a credential. The backend fixes both
  for production paths. Only an explicit debug adapter may carry
  `QFLI_DEBUG_MODEL` and `QFLI_DEBUG_API_KEY`, and only from the process
  environment.
- Errors surface as `ApiException` with a user-readable message. A protocol
  mismatch must not be retried silently across protocols.

## 4. Validation & Error Matrix

| Condition | Required behavior |
| --- | --- |
| base URL ends with `/v1` | append the protocol path only once |
| base URL already ends with the protocol path | use it unchanged |
| unknown protocol id in stored settings | fall back to `chat`, keep the stored value untouched |
| upstream returns no `tool_calls` | finish the turn with the assistant text |
| upstream returns an unknown tool name | tool result reports `error(unknown)` and the loop continues |
| credential variable missing in a debug run | skip the run, never fall back to a production key |
| HTTP 5xx with a request id | append the request id to the user message |

## 5. Good / Base / Bad Cases

- Good: settings store `responses`, the adapter sends `/v1/responses`, and the
  agent still receives OpenAI-shaped tool calls.
- Base: default `chat` with no explicit choice; behavior identical to today.
- Bad: branching on the protocol inside `VibeCodingController`, or reading the
  key from a file inside the app.

## 6. Tests Required

- `flutter test --no-pub test/service_configuration_test.dart` for endpoint
  joining and protocol parsing.
- A tool-call turn per protocol against the debug upstream, recorded by the
  e2e report with the `protocol` field set.
- `flutter analyze --no-pub lib` stays clean for `ai_service.dart` and
  `api_client.dart`.

## 7. Wrong vs Correct

### Wrong

```dart
// Protocol coupling inside the agent loop.
final body = switch (protocol) {
  AiProtocol.messages => {'messages': history, 'max_tokens': 4096},
  _ => {'messages': history},
};
```

### Correct

```dart
// The adapter owns the wire shape; the loop stays protocol-agnostic.
final reply = await api.aiChat(
  token: token,
  messages: history,
  tools: vibeToolSpecs(),
);
```
