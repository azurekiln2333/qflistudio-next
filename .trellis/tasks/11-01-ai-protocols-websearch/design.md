# Design

## Scope and ownership

This child owns four kinds of change. Each change lands in one owner's files.

| Surface | Files |
| --- | --- |
| Protocol adapters | `qfli_studio_core/lib/services/ai_service.dart` |
| AI relay calls | the AI methods in `qfli_studio_core/lib/services/api_client.dart` |
| Settings | AI section of `lib/pages/settings_page.dart`, AI fields in `lib/store/settings_store.dart` |
| Web tools | `qfli_studio_core/lib/vibe_coding/vibe_web_tools.dart` |
| Relay search | `qflistudio/azurekiln-qfli-server/src/**` |
| Tests | `qfli_studio_core/test/ai_*_test.dart`, `qflistudio/azurekiln-qfli-server/test/**` |

Pi-A owns the controller and every other `lib/vibe_coding/**` file. I publish the
web-tool interface below and do not edit the controller.

## Probed upstream facts (2026-11-01, debug credentials)

Model `deepseek-v4.1-flash`, base `https://newapi.azurekiln.cn/v1`.

| Endpoint | Request shape | Tool-call reply shape |
| --- | --- | --- |
| `POST /chat/completions` | `{model, messages[], tools[]}` | `choices[0].message.tool_calls[]`, id `call_...` |
| `POST /responses` | `{model, input, tools[]}`, tool has `name` at top level | `output[]` with `function_call` items (`call_id`, `name`, `arguments`) |
| `POST /v1/messages` | `{model, system, messages[], tools[]}` | `content[]` with `tool_use` blocks |

`/messages` accepts `Authorization: Bearer`. The gateway sets
`billing_usage.source: oai_chat` (`semantic: openai`), so it does not translate
Anthropic semantics. Do not rely on `anthropic-version` gating, but still send
`anthropic-version: 2023-06-01` for true Anthropic endpoints.

All three mark tool-call messages with more than one call. Every protocol answer
returned a native `web_search` call when that tool was offered, so the upstream
does not emulate search. Our relay must serve it.

## R2 — one adapter layer, three protocols

### Internal shapes stay OpenAI-shaped

`VibeCodingController` already stores history as OpenAI Chat messages
(`role`, `content`, `tool_calls`, `tool_call_id`). Keeping that shape as the
internal form means zero controller churn and one conversion point per protocol.
Anthropic and Responses conversion is pure Dart with no network dependency, so
fixtures cover it without sockets.

```text
internal (OpenAI chat)  <--->  adapter  <--->  wire body
     ^                                            |
     +--- decode(reply) <-------------------------+
```

### Public surface (`lib/services/ai_service.dart`)

```dart
enum AiProtocol { chat, responses, messages }   // persisted as a stable id
String get id;                                  // 'chat' | 'responses' | 'messages'
String label(String);                           // 'OpenAI Chat (/chat/completions)'
AiProtocol parseAiProtocol(String?);

abstract final class AiService {
  static String endpointFor(String baseUrl, [AiProtocol protocol = AiProtocol.chat]);

  /// Wire JSON body. Pure: no IO, no credentials.
  static Map<String, dynamic> encodeRequest({
    required AiProtocol protocol,
    required String model,
    required List<Map<String, dynamic>> messages,
    List<Map<String, dynamic>>? tools,
    int? maxTokens,
  });

  /// Protocol reply -> internal assistant message, or an AiException.
  static Map<String, dynamic> decodeReply(AiProtocol, Map<String, dynamic> data);

  /// Header set for one request. Never logs the key.
  static Map<String, String> headers(AiProtocol, {String apiKey = ''});
}
```

`decodeReply` returns `{role: 'assistant', content, tool_calls?}` in the same
shape the relay returns. Callers therefore treat direct mode and relay mode
identically. Tool-call ids are passed through unchanged when the upstream
supplies them, and synthesized deterministically (`call_<protocol>_<n>`) when a
protocol omits them, because history round-trips require a stable id.

### Per-protocol mapping

Request:

| Internal | Chat | Responses | Messages |
| --- | --- | --- | --- |
| system message(s) | `messages[role=system]` | `instructions` join | top-level `system` |
| user | `{role:user,content}` | `{role:user,content:[{type:'input_text',text}]}` | `{role:user,content:[{type:'text',text}]}` |
| assistant text | `{role:assistant,content}` | `{role:assistant,content:[{type:'output_text',text}]}` | `{role:assistant,content:[{type:'text',text}]}` |
| assistant tool_calls | `tool_calls[]` | `{type:'function_call',call_id,name,arguments}` | `{type:'tool_use',id,name,input}` |
| tool result | `{role:tool,tool_call_id,content}` | `{type:'function_call_output',call_id,output}` | `{role:user,content:[{type:'tool_result',tool_use_id,content}]}` |
| tools | `{type:function,function:{name,description,parameters}}` | `{type:function,name,description,parameters}` | `{name,description,input_schema}` |

Anthropic `tool_use.input` is an object, so the stored JSON string is decoded.
Assistant text + `tool_use` share one assistant content block list. Consecutive
tool results merge into a single user message, and adjacent same-role messages
are merged, because Anthropic rejects two consecutive users.
`max_tokens` is required by Anthropic (`defaults.maxTokens`, 4096) and is only
added where the protocol expects it.

Reply:

| Chat | Responses | Messages |
| --- | --- | --- |
| `choices[0].message.content` | `output[].type=message.content[].type=output_text.text` | `content[].type=text.text` |
| `choices[0].message.tool_calls[]` | `output[].type=function_call` | `content[].type=tool_use` |

Unknown or malformed shapes throw `AiException('AI 接口返回了无法解析的内容')`.
A reply with neither text nor calls is an error, matching the relay contract.

### Streaming

`AiService.chat` keeps its existing signature and stays the Chat-protocol text
stream used by `AiPanel`. Streaming is optional for the other two protocols
this iteration, because the relay path is non-streaming and the agent loop is
non-streaming. I record this as a known limitation instead of silently
pretending streaming exists. `chat` gains an optional `protocol` argument that
only affects the endpoint and headers; a non-Chat protocol without stream
support falls back to a single non-streaming read.

## R1/R3 — settings, migration, key boundary

`SettingsStore` gains `aiProtocol` (`AiProtocol.chat` default) and persists it
as `'chat' | 'responses' | 'messages'`. Loading accepts only known ids and falls
back to `chat`, so any previously saved settings file keeps working: an old file
has no `aiProtocol`, which means Chat, which is exactly the old behaviour.
No destructive migration is needed and no existing field is rewritten.

Direct mode uses the user's key from settings. Relay mode keeps the server key.
Neither mode writes a key into logs: `AiService` never logs, and the relay logs
only `status`, `model`, message count, tool count and duration.

Settings UI: a `SegmentedButton`/dropdown with the three labels and an inline
hint that names the endpoint each one calls. The dialog is already layout-safe
at phone width (scrollable dialog, single column, `maxWidth` 420), and the
section keeps one column with full-width controls only.

## R4/R5 — web tools

### Provider choice (recorded decision)

Chosen: **Bing RSS** (`https://www.bing.com/search?q=<q>&format=rss&count=N`).

Reasons: no paid key and no account, stable machine-readable RSS, real snippets
and canonical URLs, works for Chinese and English queries, and returns in under
a second. Probed from this host on 2026-11-01: HTTP 200 with ten real items.

Rejected alternatives and why: DuckDuckGo HTML/Lite returned 202/200 but only a
challenge page, which is not a stable contract. `api.duckduckgo.com` returned a
1252-byte stub with no results. Wikipedia search only covers an encyclopedia,
not the web. HuPu/Sogou/Baidu HTML scraping needs brittle selectors. Searx
instances rate-limit and vary per deployment.

The provider sits behind an interface so a paid or self-hosted backend can be
swapped without touching the tool contract:

```js
// src/web-search.js
class SearchProvider { async search(query, { limit, timeoutMs }) }  // -> [{title,url,snippet}]
```

`BingRssProvider` is the single implementation. `QFLI_SEARCH_PROVIDER` selects
the provider name; unknown names fail closed with `503`.

### SSRF guard

`web_fetch` accepts only `http`/`https`, rejects credentials in the URL, and
resolves the host before connecting. It rejects the whole answer set if any
address is loopback, private, link-local, CGNAT, unspecified, multicast,
reserved or IPv6 unique-local/mapped. It follows no redirect to a rejected host
by validating each hop. Fetch caps: 5 redirects, 5 s connect / 15 s total,
512 KiB body, 20 000 characters of extracted text. Only `text/*` and
`application/xhtml+xml` are accepted.

The same guard runs in Dart before a direct-mode fetch, because direct mode
bypasses the relay. The Dart copy is small on purpose: it rejects `localhost`,
literal IPs in private ranges and any host that resolves into a private range.

### Contract published for Pi-A

`lib/vibe_coding/vibe_web_tools.dart`

```dart
const Set<String> kVibeWebToolNames = {'web_search', 'web_fetch'};
bool get vibeWebToolsAvailable;                      // false in offlineOnly
List<Map<String, dynamic>> vibeWebToolSpecs();        // OpenAI function specs
Future<VibeWebToolResult> executeVibeWebTool({        // null => not a web tool
  required String name,
  required Map<String, dynamic> args,
  ...
});
```

`VibeWebToolResult` carries `modelText` (text fed back to the model) and
`summary` (one-line UI text), so the controller keeps its existing tool-card
rendering without a new type. Executor rejects both tools in an offline-only
profile with `error(OFFLINE_ONLY)` and zero network calls.

Result shape fed to the model:

```text
web_search -> 1. <title>\n   <url>\n   <snippet>    (max 8 results)
web_fetch  -> <title> <url>\n\n<clean text, capped>
```

## Relay endpoints (server)

`POST /api/ai/web_search` `{query}` -> `{provider, results:[{title,url,snippet}]}`.
`POST /api/ai/web_fetch` `{url}` -> `{url, title, text, truncated}`.
Both require auth, per-user rate limit, and reuse the AI audit action. Neither
echoes headers, cookies or the key. Unconfigured or offline deployment returns
`503` with a readable message so the app can surface "search unavailable".

## Failure and rollback

Each layer fails closed: unknown protocol id falls back to Chat, unknown search
provider returns 503, rejected address returns a tool error, and an exceeded cap
returns a truncated result with `truncated: true`. Rollback is a per-commit
revert; nothing changes an existing API contract, so no data migration is needed.

## Not covered here

Streaming for Responses/Messages beyond the non-streaming read, a paid search
backend, and packaging acceptance on OHOS devices belong to other owners or
later work.
