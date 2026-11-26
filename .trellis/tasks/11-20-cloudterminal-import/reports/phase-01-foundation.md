# Phase 01 — foundation (models, transport, state, renderer)

Status: **implemented**, code complete for this phase. Not "accepted": cloud CI
and device checks are phase 4 and are not run here.

Worktree: `D:/MyNewProjects/_wt/cloudterminal-import/work/qfli_studio_core`
(branch `remote/cloudterminal-core`, base `b7f3d40`).
Source copy read only: `D:/MyNewProjects/_wt/cloudterminal-import/source/cloudterminal`
(HEAD `49b2aac781858929a19307faeb808b83f8154410`). The original
`D:/MyNewProjects/cloudterminal` was not touched.

## Files created

### Module (new)

```
lib/remote_control/README.md
lib/remote_control/models/protocol.dart              <- source lib/models/protocol.dart
lib/remote_control/models/herdr.dart                 <- source lib/models/herdr.dart
lib/remote_control/models/pairing_uri.dart           <- source lib/models/pairing_uri.dart
lib/remote_control/transport/relay_socket.dart       <- split from source lib/net/relay_socket.dart
lib/remote_control/transport/relay_socket_io.dart    <- dart:io WebSocket client (from same file)
lib/remote_control/transport/relay_socket_stub.dart  <- new: browser-safe unsupported entry
lib/remote_control/transport/relay_connector.dart    <- new: conditional export
lib/remote_control/state/remote_store.dart           <- source lib/state/app_store.dart, renamed
lib/remote_control/state/remote_store_backend.dart   <- new: storage contract + memory backend
lib/remote_control/state/remote_store_backend_io.dart     <- new: atomic file backend
lib/remote_control/state/remote_store_backend_stub.dart   <- new: browser-safe backend
lib/remote_control/state/session_view.dart           <- source lib/state/session_view.dart
lib/remote_control/state/remote_controller.dart      <- source lib/state/remote_controller.dart
lib/remote_control/state/herdr_controller.dart       <- source lib/state/herdr_controller.dart
lib/remote_control/state/codex_catalog.dart          <- source lib/state/codex_catalog.dart
lib/remote_control/state/codex_thread_view.dart      <- source lib/state/codex_thread_view.dart
```

### Renderer (new)

```
vendor/xterm/**                 <- source third_party/xterm (82 files: lib/, pubspec.yaml,
                                   LICENSE, CHANGELOG.md, analysis_options.yaml,
                                   README.cloudterminal.md)
vendor/xterm/PROVENANCE.md      <- new: origin, license, the one patch, maintenance rules
```

### Modified

```
pubspec.yaml   + xterm: ^4.0.0  and  dependency_overrides.xterm: path: vendor/xterm
pubspec.lock   + xterm 4.0.0 (path: vendor/xterm, relative: true)
               + convert 3.1.2, equatable 2.1.0, quiver 3.2.2, zmodem 0.0.6 (transitive)
```

The lock change is exactly 39 added lines, all new entries: no existing
resolution moved, and `xterm` is recorded as `path: "vendor/xterm"` with
`relative: true`, so a clean checkout resolves it without an absolute local path
(AC10).

Nothing else in the host package was edited: no existing file under `lib/`,
`test/`, `assets/`, `android/` was rewritten, and the source's `main.dart` and
`Appearance` controller were not copied.

Size: 16 Dart files + 1 README in the module (4,635 lines including the README),
plus `vendor/xterm` (82 files) and its `PROVENANCE.md`.

## What was preserved verbatim

Diff against the source copy (line endings normalised) shows **only** provenance
headers, the `../net/` → `../transport/` import path, and `AppStore` →
`RemoteStore`:

| File | Changed lines vs source |
| --- | --- |
| `models/protocol.dart` | 4 (header comment) |
| `models/herdr.dart` | 5 (header comment) |
| `models/pairing_uri.dart` | header comment + import path |
| `state/session_view.dart` | 4 (header comment) |
| `state/herdr_controller.dart` | 3 (header comment) |
| `state/codex_catalog.dart` | 3 (header comment) |
| `state/codex_thread_view.dart` | 3 (header comment) |
| `state/remote_controller.dart` | import paths, `RemoteStore`, connector name, header comment |

Wire behaviour therefore keeps: frame kinds `hello`/`hello_ok`/`presence`/`msg`/
`error`, request ids `r<n>`, the 20 s default request timeout, exponential backoff
with jitter capped at 30 s, `unauthorized`/`agent_offline`/`rate_limited`
handling, `ConnectionPhase` separation of relay reachability from agent
availability, `_failPending` on disconnect/offline, resubscribe-after-reconnect
with `afterSeq: lastSeq`, `SessionView.applyBacklog(reset:)` clearing
events/results/resolutions, `if (e.seq <= lastSeq) return false` dedupe,
raw `terminal_input` bytes, `terminal_resize` clamping, `maxLines: 2000`
scrollback with replay-time device-reply suppression, Herdr
`prefix`/`chunk` reconciliation with full-replace fallback, the 12 s watchdog with
reference counting, the `_inFlight` action guard, and every Codex
catalog/transcript/approval payload.

## Deliberate deviations

1. **`AppStore` → `RemoteStore`, new file name.** Storage is
   `qfli_remote_control.json` in the host app's private support directory.
   `cloudterminal.json` is never read, so a source installation's pairing is not
   imported (AC7). Atomic write is preserved (temp file, then rename) and writes
   are now also serialised through a future chain so two rapid updates cannot
   interleave temp files ("atomic and ordered"). Corrupt JSON still starts empty;
   a missing plugin channel or filesystem error still degrades to memory instead
   of failing to launch. The secret remains app-private **plaintext**, documented
   in the module README rather than implied as encryption.
2. **`dart:io` behind a platform boundary.** `transport/relay_socket.dart` now
   holds only the `RelaySocket`/`RelayConnector` surface and `normalizeRelayUrl`
   (pure Dart). The `dart:io` `WebSocket` client moved to
   `relay_socket_io.dart`; `relay_socket_stub.dart` throws a truthful
   `UnsupportedError`; `relay_connector.dart` conditionally exports one of them.
   Persistence got the same treatment (`remote_store_backend{,_io,_stub}.dart`).
   `dart:io` now appears in exactly two files, both `*_io.dart`. The stub is a
   safety net only — remote control is not advertised for the browser.
3. **Connector renamed** `connectIoSocket` → `connectRelaySocket`, because the
   function is now platform-selected rather than always `dart:io`. It is a
   transport factory, not wire protocol.
4. **`vendor/xterm` instead of `third_party/xterm`**, pinned by
   `dependency_overrides` so a clean checkout of the core (and any app depending
   on it) resolves the renderer without the source repository (AC10). The MIT
   `LICENSE`, `README.cloudterminal.md` and the single OHOS shortcut patch are
   retained; `PROVENANCE.md` pins source HEAD `49b2aac`.

## Checks run (permitted, local)

| Check | Result |
| --- | --- |
| `flutter pub get --offline` (worktree only, cached packages) | resolved; added `xterm` + 4 transitive deps, `pubspec.lock` updated |
| `dart analyze lib/remote_control` | **No issues found** |
| `dart analyze lib` (whole shared core) | **No issues found** — the migration broke nothing in the host package |
| `dart analyze` on the platform-neutral wire subset alone | **No issues found** |
| `dart format lib/remote_control/` | clean, idempotent (`0 changed` on re-run) |
| `python scripts/ste-lint-zh.py lib/remote_control/README.md vendor/xterm/PROVENANCE.md` | 0 hard violations (both docs I authored) |
| `git diff --check` | clean |
| Trailing whitespace scan of new files | none |
| Line endings | normalised to LF to match the host package |

`flutter pub get` was run with `--offline` so no network fetch was needed. It is
dependency resolution plus targeted static analysis, not a build or a test. No
test suite, emulator, VM, container, `adb` or `hdc` was started. The Chinese
linter is only meaningful for prose: it flags English semicolons in Dart source,
and existing host Dart files show the same volume (e.g. `lib/services/app_paths.dart`:
75), so it was applied to the two documents this phase authored, not to code.

### What this does and does not prove

Proven: the module parses, resolves and type-checks against the real Flutter SDK,
`path_provider` and the vendored `xterm`; the conditional platform exports are
valid in both branches (the analyzer checks the `dart.library.io` branch used
here); the host package still analyzes clean.

Not proven here: runtime behaviour. Nothing exercised a socket, a replay, a
Herdr push or a Codex approval, and no test file exists yet (phase 4). Behaviour
claims above are read from the copied source, not observed.

## Validation limitation (honest)

Before `pub get` ran, the worktree had no `.dart_tool/package_config.json`, so
`package:flutter`, `package:path_provider` and `package:xterm` could not be
resolved and a whole-module `dart analyze` reported 52 resolution artifacts
(`uri_does_not_exist` plus knock-on `undefined_method`/`extends_non_class`/
`undefined_super_member`/`invalid_assignment` for `ChangeNotifier`,
`Terminal`, `UnicodeV11.wcwidth` and friends). That is now resolved as recorded
above; the earlier count is kept here only so the phase log is not rewritten.

Device and cloud-CI validation remain unavailable: no test suite was run, no
build was produced, and no real pairing, PTY, Herdr or Codex session was
observed. "Compiles and analyzes" is not "works".

## Not done in this phase (by design)

- `pages/` and `widgets/`: `RemoteComputerPage`, `RemoteTerminalPane`, the Herdr
  and Codex screens, the host theme adapter, and the single navigation entry
  (phase 2). The PTY viewport must remain separate from the host `TerminalPane`,
  which owns line-oriented local/cloud execution.
- Lifecycle wiring (observe app resume → `reconnectNow()`, dispose once on exit),
  which belongs to the page that owns the controller.
- Companion agent and Windows launcher (phase 3).
- Tests and CI jobs (phase 4). No test file was added or modified here.

## Notes for the next phase

- Import the transport via `transport/relay_connector.dart`, never
  `relay_socket_io.dart`, or the web build breaks.
- Guard Herdr read responses by the pane id they were requested for; the
  controller API is ready for it but the check lives in the screen.
- Reconnect must not retry uncertain keyboard input, and must not auto-grant a
  permission that was pending when the link dropped.
- `RemoteController` is already fully disposable (sockets, frame subscription,
  pending completers, timers, codex notice stream); the page must call
  `dispose()` exactly once and must not keep a second connection loop alive.
