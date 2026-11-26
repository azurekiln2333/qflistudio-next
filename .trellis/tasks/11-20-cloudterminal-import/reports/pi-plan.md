# Pi plan — CloudTerminal → QFLIStudio remote_control

Phase 1 (foundation) owner. Source of truth is the captured copy
`D:/MyNewProjects/_wt/cloudterminal-import/source/cloudterminal` (HEAD
49b2aac781858929a19307faeb808b83f8154410). The original workspace is untouched.

## Change boundary (trellis-before-dev)

Behaviour gap: Studio has no remote-computer data/state layer at all. The
behaviour to add is CloudTerminal's paired-relay session layer, expressed as a
new `lib/remote_control` module in the shared core, with no change to existing
editor terminals, Agent chat, Git or AI code.

Where the behaviour lives in the source (all read, none modified):

| Source path | Responsibility |
| --- | --- |
| `lib/models/protocol.dart` | Wire mirror of `server/src/shared/protocol.ts` (sessions, events, Codex) |
| `lib/models/herdr.dart` | Herdr wire types + pane snapshot replay maths |
| `lib/models/pairing_uri.dart` | `cloudterminal://pair?relay=&code=&v=` parsing |
| `lib/net/relay_socket.dart` | Socket surface, dart:io WebSocket, relay URL normalisation |
| `lib/state/app_store.dart` | `cloudterminal.json` private store + `Pairing` |
| `lib/state/remote_controller.dart` | Connection loop, request IDs/timeouts, replay routing |
| `lib/state/session_view.dart` | Ordered events, sequence dedupe, xterm emulator |
| `lib/state/herdr_controller.dart` | Herdr cache, push sink, watchdog, in-flight guard |
| `lib/state/codex_catalog.dart` | Codex project/thread paging |
| `lib/state/codex_thread_view.dart` | Codex transcript, notices, approvals |
| `third_party/xterm` | Patched xterm.dart 4.0.0 (OHOS shortcut patch) |

Files created in this phase (all new; nothing existing is rewritten):

- `core/lib/remote_control/models/{protocol,herdr,pairing_uri}.dart`
- `core/lib/remote_control/transport/{relay_socket,relay_connector,relay_socket_io,relay_socket_stub}.dart`
- `core/lib/remote_control/state/{remote_store,remote_store_backend,remote_store_backend_io,remote_store_backend_stub,session_view,remote_controller,herdr_controller,codex_catalog,codex_thread_view}.dart`
- `core/lib/remote_control/README.md`
- `core/vendor/xterm/**` (LICENSE, README.cloudterminal.md, PROVENANCE.md, lib/, pubspec.yaml, CHANGELOG.md, analysis_options.yaml)
- `core/pubspec.yaml` (add `xterm` dependency + path override)

Explicitly **not** in this phase: pages/widgets, host navigation entry, the
desktop companion, tests/CI. Those are phases 2–4.

## Deviations from a literal copy, and why

1. `AppStore` → `RemoteStore`, file `cloudterminal.json` → `qfli_remote_control.json`.
   Required by design (private namespace, no automatic reuse of source
   credentials). Atomic temp-write-then-rename is preserved; writes are now also
   **serialised** through a future chain so two rapid updates cannot interleave
   temp files ("keep writes atomic and ordered"). Corrupt JSON still starts empty
   and a missing plugin/filesystem still falls back to memory.
2. `dart:io` is pushed behind a platform boundary instead of sitting in the
   module core:
   - `transport/relay_socket.dart` keeps the `RelaySocket`/`RelayConnector`
     surface and `normalizeRelayUrl` (pure Dart).
   - `transport/relay_socket_io.dart` holds the `dart:io` `WebSocket` client.
   - `transport/relay_socket_stub.dart` is the browser-safe entry that throws a
     truthful `UnsupportedError`.
   - `transport/relay_connector.dart` is the conditional export selecting one.
   - `state/remote_store_backend*.dart` does the same for persistence.
3. `xterm` is resolved from `core/vendor/xterm` so an app build never points at
   the source checkout (AC10). The upstream patch and MIT LICENSE are retained;
   provenance pins the migrated source revision.
4. Wire semantics are copied verbatim: request IDs (`r<n>`), 20 s default
   timeout, backoff with jitter, `hello`/`hello_ok`/`presence`/`msg` frames,
   `seq`-based dedupe, `reset` replay, raw PTY bytes, bounded output, Herdr
   prefix/chunk reconciliation, Codex approval payloads. No field was renamed.

## Architectural map

```
lib/remote_control/
  models/      pure data mirrors of the relay wire contract (no dart:io)
  transport/   socket surface + conditional native/stub implementation
  state/       RemoteStore (persistence), RemoteController (link),
               SessionView (events + emulator), HerdrController, Codex*
  (phase 2)    pages/, widgets/  — RemoteComputerPage, RemoteTerminalPane
```

Ownership: `RemoteController` owns one paired connection, all request IDs,
timers and subscriptions. `SessionView` owns ordered events, streaming, tool
results, permissions and replay. `HerdrController` owns Herdr caches and the
watchdog. `CodexCatalog`/`CodexThreadView` own catalog pages and one transcript.
`RemoteStore` owns the private JSON document only.

## Validation available in this environment

No `.dart_tool`/`package_config.json` in the worktree and no permitted
`pub get`, so `dart analyze` cannot resolve `package:flutter` here. Permitted
checks: `dart format` and `git diff --check`. Test suites are written for cloud
CI (phase 4). Recorded honestly in `phase-01-foundation.md`.
