# Implement

1. Read the parent prd.md, this prd.md and the relevant .trellis/spec/frontend files.
2. Write design.md (short) before code. Report to the root session if it changes a shared interface.
3. Implement in small steps. After each step run focused tests, then commit as type(scope): summary with explicit paths.
4. On finish, add a Result section here: commits, tests run, what was not verified.

## Result

### Commits

`qfli_studio_core` (branch `main`):

| Commit | Scope |
| --- | --- |
| `e4f5280` feat(ai): add chat, responses and messages protocol adapters | `ai_service.dart` + fixture tests |
| `a5977fe` feat(ai): inject chat/responses/messages endpoint into agent transport | `api_client.dart`, `settings_store.dart`, `settings_page.dart`, `ai_panel.dart` |
| `1009d9b` feat(ai): add web_search and web_fetch tools with an SSRF guard | `vibe_web_tools.dart` + tests |
| `9706270` fix(ai): send string content on responses input items | Responses encoder + fixtures |
| `e2740e8` fix(test): keep the ai settings dialog test off the fake clock io path | widget test |
| `e322694` feat(ai): fall back to a direct request when the web relay is missing | `vibe_web_tools.dart` direct search and fetch |
| `58c8c4e` fix(ai): follow redirects on the direct web path | redirect handling + `test/vibe_web_direct_live_test.dart` |

`qflistudio` (branch `main`):

| Commit | Scope |
| --- | --- |
| `5a3403a` feat(ai): serve web_search and web_fetch behind an SSRF guard | `azurekiln-qfli-server/src/{web-search,web-fetch}.js`, `routes/ai.js`, tests |

### Interface published to Pi-A (for controller wiring)

`lib/services/api_client.dart`

```dart
enum AiRoute { relay, direct }

class AiEndpoint {
  const AiEndpoint.relay({AiProtocol protocol = AiProtocol.chat});
  const AiEndpoint.direct({
    required String baseUrl,
    required String apiKey,
    required String model,
    AiProtocol protocol = AiProtocol.chat,
  });
  bool get isUsable;   // direct 需要 baseUrl 与 model
}

Future<AiChatResult> ApiClient.aiChat({
  required String token,
  required List<Map<String, dynamic>> messages,
  List<Map<String, dynamic>>? tools,
  Future<void>? abortTrigger,
  AiEndpoint? endpoint,   // 省略或 relay 时走中转 /api/ai/chat
});
```

`lib/vibe_coding/vibe_web_tools.dart`

```dart
const Set<String> kVibeWebToolNames = {'web_search', 'web_fetch'};
bool get vibeWebToolsAvailable;
bool offlineOnlyProduct();
List<Map<String, dynamic>> vibeWebToolSpecs();
List<Map<String, dynamic>> vibeToolSpecsWithWeb();   // 本地工具 + 联网工具
Future<VibeWebToolResult?> executeVibeWebTool({
  required String name,
  required Map<String, dynamic> arguments,
  required ApiClient api,
  required String token,
  bool Function()? onlineAllowed,
});   // null 表示不是联网工具，调用方继续走本地分支
```

Controller wiring needed from Pi-A: pass `tools: vibeToolSpecsWithWeb()` and
route `web_search`/`web_fetch` through `executeVibeWebTool` before the local
switch, using the same `onlineAllowed` predicate. `VibeWebToolResult` already
carries `summary` and `modelText`, so the existing tool card needs no change.

### Tests run and observed

- `flutter test` on `ai_protocol_adapter_test`, `ai_settings_dialog_test`,
  `ai_test`, `vibe_web_tools_test`, `api_client_offline_test`: **68 passed**.
- `node --test test/web-tools.test.js`: **12 passed**.
- Live, all three protocols against the debug upstream
  (`test/ai_protocol_live_test.dart`, env credentials): each returned a real
  `web_search` call, and the follow-up answer cited a real URL. Evidence in
  `qfli_studio_core/build/ai-live/{chat,responses,messages}.json`.
- Live search provider (Bing RSS): 3 real results with title, URL and snippet.
- Live fetch: `https://flutter.dev/` returned 4043 characters of cleaned text.
- Route-level acceptance with a stubbed auth identity: `/api/ai/web_search` and
  `/api/ai/web_fetch` returned 200; `127.0.0.1`, `localhost` and
  `169.254.169.254` were blocked with 400; an empty query returned 400.
- Key leak check: `git grep` for the debug key across both repos found nothing.
- Live direct fallback (`test/vibe_web_direct_live_test.dart`, env gate):
  `web_search` without the relay returned **8 results** per query for both
  `Flutter 教程` and `dart language`, each with a real title and URL. First hit
  for `Flutter 教程` was `Flutter 教程 | 菜鸟教程`
  (`https://www.runoob.com/flutter/flutter-tutorial.html`).
- Live direct fetch: `https://flutter.dev/` returned 4007 characters of cleaned
  text. Direct SSRF guard rejected `127.0.0.1`, `localhost:8080` and
  `169.254.169.254` live.
- Unit tests after the fallback work: `flutter test test/vibe_web_tools_test.dart`
  reports **39 passed**.

### Defects found and fixed during acceptance

1. `_send` had lost its `abortTrigger` parameter, so cancellation could no
   longer abort an in-flight request. Restored.
2. The Responses encoder sent typed content parts; the gateway shim rejects
   them. Reproduced with a direct probe and switched to string content plus
   separate `function_call` items, which real OpenAI also accepts.
3. `stripTags` stripped before decoding CDATA, so real Bing titles were dropped
   while the hand-written fixture passed. Fixed the order and re-verified live.
4. `pickTag` built its regex inside a template literal, where `\\s` became a
   literal backslash, so every tag lookup returned empty against real RSS.
5. The offline gate lived only in `ApiClient`, so a refused web tool reported a
   generic `network` error instead of `OFFLINE_ONLY`. The tool now checks first.
6. The direct search path did not follow redirects, so every `web_search` failed
   with `目标站点返回 302`: `www.bing.com` redirects to `cn.bing.com` before it
   serves RSS. Now follows up to 3 hops, re-checking scheme and SSRF on each hop.
7. `extractPageText` kept `<title>` inside the body text, so the page title was
   duplicated into the answer. The head block is now removed first.
8. `_DirectFailure` had no `toString`, so any direct error surfaced as
   `Instance of '_DirectFailure'` instead of the real reason.
9. The settings dialog test hung because real file IO was awaited inside
   `testWidgets`' fake clock. Layout cases no longer do IO.

### Standing limitations at the end of this task

Three facts are true as this task closes. Read them before assuming the web
features work in every environment.

1. **The relay endpoints are not deployed.** `/api/ai/web_search` and
   `/api/ai/web_fetch` exist in `azurekiln-qfli-server` and pass their tests, but
   they are not live on `qfli.suanxiwanjie.cn` (probed: 404). Every web tool call
   in the released app therefore relies on the device-side direct fallback. The
   server work is code-complete, not deployed.
2. **Only the Chat protocol streams.** `AiService` streams for Chat. Responses
   and Messages each read one non-streaming reply. The direct endpoint path in
   `aiChat` is also not streaming: it returns after the body completes. Users on
   a direct endpoint see no token-by-token output even on Chat.
3. **The direct fallback needs open access to the search source.** It works only
   when the device can reach `www.bing.com`/`cn.bing.com` and the target page
   directly. Behind a firewall, a captive portal, or a region that blocks the
   source, both the relay and the fallback fail, and the tool reports both
   reasons.

### Streaming on the Chat path: workload assessment

Not implemented in this task. Scope if picked up later.

- **Server side is free.** The chat adapter already sends `stream: true` and
  parses SSE frames into text deltas. Nothing to build there.
- **Transport needs a callback.** `ApiClient.aiChat` currently returns one
  `AiChatResult`. Streaming needs an `onDelta` callback threaded through the
  same call, which then also has to carry the tool-call fragments that arrive
  split across frames.
- **Agent loop needs a mid-turn hook.** `vibe_coding_controller` consumes one
  final reply today. It must accept partial text and still assemble the tool
  call before dispatch, otherwise a streamed turn cannot execute tools.
- **UI needs an incremental message.** The transcript renders a finished
  message. A streamed turn needs a growing message plus a stop action.
- **Tests need a fake SSE stream.** One `MockClient` that emits frames in
  pieces, plus a cancellation case.

Estimated size: one focused session for transport plus tests, a second for the
controller and UI wiring. Main risk is the tool-call fragments, not the text
path. Blocked until Pi-A's controller rewrite lands, because the controller is
the file that must change.

### Not verified

- Streaming exists only for the Chat protocol; Responses and Messages read one
  non-streaming reply. Recorded in `design.md` rather than faked. See the
  streaming assessment above.
- `test/vibe_coding_controller_test.dart` cannot run while Pi-A rewrites
  `vibe_coding_controller.dart`; it currently fails to compile on that file
  (not mine). The web tools are therefore not yet reachable from the agent loop
  until Pi-A wires `vibeToolSpecsWithWeb` and `executeVibeWebTool`.
- No OHOS device run. Nothing here is platform-specific, but packaged-device
  acceptance remains outstanding.
- `QFLI_SEARCH_PROVIDER` is documented in code only; `.env.example` is not mine
  to edit.
