# R4 streaming source audit

Audit date: November 22, 2026. This is a read-only source and dependency audit.
No runtime request, service, device, build, test, push or deployment was used.

## Latest Agent implementation

Source: `D:/MyNewProjects/_wt/studio-git-integration/qfli_studio_core`.

- `VibeCodingController._consumeTurn` consumes `ApiClient.aiChatStream` events.
  Reasoning and content deltas update live messages. Tool execution and history
  use the completed turn result.
- `ApiClient._aiChatStreamDirect` calls `AiService.encodeRequest(stream: true)`.
  It requests SSE and uses the protocol event decoder. Chat, Responses and
  Messages encoders all emit the streaming field.
- `ApiClient._aiChatStreamRelay` posts to `/api/ai/chat/stream` and parses NDJSON
  reasoning, content, tool-call and result events.
- A relay HTTP 404 or 405 falls back to `/api/ai/chat` and emits one completed
  turn. A direct upstream returning JSON instead of SSE also completes as a
  whole response. These compatibility paths do not provide live text deltas.
- Relevant committed changes are `fdd06c6` (transport), `05c7eb0` (Messages tool
  block registration) and `9570129` (Agent streaming loop and reasoning history).

The latest Agent source therefore implements real streaming. This source check
does not establish that the installed client or production server uses it.

## Legacy AI panel

The separate `lib/editor/ai_panel.dart` official-relay branch still calls
`AiService.relayChat` with `ApiClient.aiChat`. `AiService.relayChat` awaits the
whole response before yielding its content. That panel's relay path is not
the Agent streaming path described above. No legacy-panel rewrite was made.

## Server source

`D:/MyNewProjects/_wt/thinking/server/azurekiln-qfli-server` is at `81515f4`.
Its `src/routes/ai.js` registers `/chat/stream`. `src/ai-client.js:chatStream`
forwards `stream: true` and `stream_options: {include_usage: true}` to the
upstream, then emits events through the shared NDJSON writer. The preceding
writer refactor is `afbbf33`.

The separate `D:/MyNewProjects/azurekiln-qfli-server` checkout remains at
`d919a91`. Its inspected AI route/client sources do not contain that streaming
route. Repository contents do not establish which image production runs.

## Current planning-root App dependency

`D:/MyNewProjects/qflistudio/pubspec_overrides.yaml` and that checkout's
`.dart_tool/package_config.json` both resolve Core to
`D:/MyNewProjects/_wt/integration/qfli_studio_core`, at `b7f3d40`.
The inspected older Core controller and API client do not contain
`_consumeTurn` or `aiChatStream`.

The paired integration App's package configuration instead resolves to its
matching integration Core. This audit changed no dependency override.

## Result boundary

The latest integration Agent has streaming source. The planning-root App still
uses older Core source. The legacy AI panel's official-relay path remains a
whole response. Runtime and deployment acceptance are unverified.
