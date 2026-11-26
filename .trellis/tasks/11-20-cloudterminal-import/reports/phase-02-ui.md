# Phase 02 — UI (pages, widgets, module entry)

Status: **implemented**, code complete for this phase. Not "accepted": no cloud
CI run, no device run, no independent review yet.

Worktree: `D:/MyNewProjects/_wt/cloudterminal-import/work/qfli_studio_core`
(branch `remote/cloudterminal-core`, base `b7f3d40`).
Source read only: `D:/MyNewProjects/_wt/cloudterminal-import/source/cloudterminal`
(HEAD `49b2aac781858929a19307faeb808b83f8154410`). The original
`D:/MyNewProjects/cloudterminal` was not touched, and no install/build/test was
run there or here.

Attempt note: attempt 1 wrote the port and then ended before writing this
report. This attempt inspected that work file by file (token-level diff against
the source, see "Parity evidence"), fixed the gaps it found, and wrote this
report.

## Files created

```
lib/remote_control/remote_computer_page.dart        new module entry (source lib/main.dart, rewritten)
lib/remote_control/theme/remote_theme.dart          source lib/theme/app_theme.dart, reduced to 2 helpers
lib/remote_control/pages/pair_screen.dart           source lib/screens/pair_screen.dart
lib/remote_control/pages/home_screen.dart           source lib/screens/home_screen.dart
lib/remote_control/pages/session_screen.dart        source lib/screens/session_screen.dart
lib/remote_control/pages/herdr_screen.dart          source lib/screens/herdr_screen.dart
lib/remote_control/pages/herdr_terminal_screen.dart source lib/screens/herdr_terminal_screen.dart
lib/remote_control/pages/codex_screen.dart          source lib/screens/codex_screen.dart
lib/remote_control/widgets/remote_terminal_pane.dart  source lib/widgets/terminal_pane.dart, renamed
lib/remote_control/widgets/event_tiles.dart         source lib/widgets/event_tiles.dart
lib/remote_control/widgets/permission_card.dart     source lib/widgets/permission_card.dart
lib/remote_control/widgets/codex_approval_card.dart source lib/widgets/codex_approval_card.dart
lib/remote_control/widgets/herdr_terminal.dart      source lib/widgets/herdr_terminal.dart
lib/remote_control/widgets/herdr_terminal_rows.dart source lib/widgets/herdr_terminal_rows.dart
lib/remote_control/widgets/herdr_status.dart        source lib/widgets/herdr_status.dart
lib/remote_control/widgets/session_card.dart        source lib/widgets/session_card.dart
lib/remote_control/widgets/workspace_sidebar.dart   source lib/widgets/workspace_sidebar.dart
lib/remote_control/widgets/new_session_sheet.dart   source lib/widgets/new_session_sheet.dart
lib/remote_control/widgets/history_sheet.dart       source lib/widgets/history_sheet.dart
lib/remote_control/widgets/dir_picker_sheet.dart    source lib/widgets/dir_picker_sheet.dart
lib/remote_control/widgets/tool_format.dart         source lib/widgets/tool_format.dart
lib/remote_control/widgets/section_label.dart       source lib/widgets/section_label.dart
```

Deliberately **not** ported:

| Source | Why |
| --- | --- |
| `lib/widgets/appearance_sheet.dart` | Belongs to the source `Appearance` controller. Theme mode / seed colour stay host-owned. |
| `lib/state/appearance.dart` | Same: a competing global appearance controller. |
| `lib/main.dart` (`CloudTerminalApp`) | Replaced by `remote_computer_page.dart`. The source root was a second `MaterialApp`. |

Module totals: 39 Dart files, 13,122 lines, plus `lib/remote_control/README.md`.

## Files modified

```
pubspec.yaml   + xterm: ^4.0.0  (dependency_overrides.xterm -> path: vendor/xterm)
pubspec.lock   + xterm 4.0.0 as a relative path package, + 4 transitive entries
```

Both changes came from phase 01. This phase added no new dependency. No file
outside `lib/remote_control/`, `pubspec.yaml`, `pubspec.lock` and `vendor/xterm`
was touched (`git status --short` shows exactly those four entries). Existing AI,
editor, local/cloud terminal, Git and navigation code is unchanged.

## Module entry — `remote_computer_page.dart`

One entry, `RemoteComputerPage`, a route body rather than an app:

- **Boot.** `RemoteStore.open()` once, then `RemoteController.connect()`. A
  caller-supplied `controller:` is not disposed by the page (caller owns it).
  tests use that with `RemoteStore.memory()`.
- **Pairing ⇄ dashboard.** `_RemoteRoot` listens to the controller and swaps
  `PairScreen` / `HomeScreen` through an `AnimatedSwitcher`, keyed by pairing
  state and `agentId`, exactly like the source `_Root`. `PairScreen` receives
  `store.lastRelayUrl` so an unpair does not force retyping the relay address.
- **Background resume.** `WidgetsBindingObserver`. `resumed` calls
  `reconnectNow()` (skips the remaining backoff). It does not replay uncertain
  keyboard input and does not auto-grant a pending permission.
- **Disposal.** `dispose()` removes the observer and disposes the controller it
  created, exactly once. `RemoteController.dispose()` cancels timers and the
  frame subscription and closes the client socket. It sends **no**
  `session_close`. `SessionScreen.dispose()` calls `herdr.unwatch()` and
  `controller.unsubscribe(id)`. So leaving the page releases local resources and
  leaves desktop sessions running. They reappear on reconnect.
- **Unsupported gate.** `RemoteComputerPage.isSupported` is `!kIsWeb`. The page
  decides before any async work and renders an explicit
  "当前平台不支持远程电脑" page (no socket dialled, no storage opened), so a browser
  build never loops on "连接失败". `isSupported` is public so phase 3's host
  navigation can hide the entry instead of pushing a page that can only
  apologise.
- **Boot failure.** A separate `_bootError` state renders a storage-permission
  explanation with the error text. It cannot be confused with "still loading".

No `MaterialApp`, no `Appearance`, no `ThemeMode`, no `colorSchemeSeed` anywhere
in the module (grep-verified). All theming goes through `Theme.of(context)` and
`RemoteTheme`.

## Theme adaptation

`theme/remote_theme.dart` keeps only what the remote screens use:

- `RemoteTheme.mono(fontSize, ...)` — monospace style on
  `EditorFonts.bundledFamily` (`packages/qfli_studio_core/RobotoMono`) with a CJK
  fallback list, so Chinese PTY output and paths are not tofu.
- `RemoteTheme.terminalStyle(...)` — the same family for the xterm renderer.
- `RemoteTheme.statusColor(scheme, status)` — maps wire status names onto the
  host `ColorScheme`, unknown values degrade to `secondary` instead of throwing.

The source's `AppTheme.light/dark(seed)` builders were dropped: the host app
already owns theme mode and seed colour. `home_screen.dart` therefore lost its
`appearance` field and its "外观" popup item. The remaining menu items
(重新连接 / 断开配对) are intact.

## Renderer wiring

`xterm: ^4.0.0` resolves to `vendor/xterm` through `dependency_overrides`, so the
patched CloudTerminal fork is used and no absolute local path appears in
`pubspec.lock` (`path: "vendor/xterm"`, `relative: true`). MIT `LICENSE`,
`README.cloudterminal.md` and `PROVENANCE.md` are retained. `RemoteTerminalPane`
uses `TerminalView` with `RemoteTheme.terminalStyle(fontSize: 13)`.

## Behaviour contracts preserved

| Contract | Where | Note |
| --- | --- | --- |
| Raw PTY bytes | `RemoteTerminalPane._input` → `RemoteController.terminalInput` | `data` is forwarded untouched: no trim, no appended newline, never parsed as a prompt. Key buttons send literal bytes (`\x1b`, `\x03`, …). |
| Resize | `RemoteTerminalPane._resize` | 150 ms debounce, clamped `cols 2..500`, `rows 1..300`. |
| Replay/dedupe | `SessionView` (phase 01) + `session_screen` subscribe | Unchanged. |
| Claude permission/question | `widgets/permission_card.dart`, `session_screen._answer` | Permission card, `AskUserQuestion` option toggles, "all answered" gate. A reply is sent only on a user tap. |
| Codex approvals | `pages/codex_screen.dart` + `widgets/codex_approval_card.dart` | Decision + answers posted from the card's `onRespond` only. |
| Herdr control | `pages/herdr_screen.dart`, `pages/herdr_terminal_screen.dart`, `widgets/herdr_terminal*.dart` | Workspace/tab/pane lists, open/focus/rename/close, direct typing without a local PTY. Responses guarded by selected pane id (phase 01 `HerdrController`). |
| Truthful empty/error states | all pages | Offline, agent-offline, closed session, unloaded view and Herdr-unavailable each render their own notice rather than a spinner forever. |
| Destructive actions | `home_screen` session menu, `herdr_screen` dialogs | Confirm dialogs before close/kill. Nothing fires automatically on reconnect. |

## Parity evidence (this attempt)

Token-level diff (comments stripped, whitespace-insensitive) of every ported
page/widget against the source copy:

- `pages/codex_screen.dart` — only `app_theme`→`remote_theme`, `AppTheme`→`RemoteTheme`.
- `pages/session_screen.dart` — same, plus `terminal_pane`→`remote_terminal_pane`,
  `TerminalPane`→`RemoteTerminalPane`.
- `pages/herdr_terminal_screen.dart` — one removed trailing comma (formatter).
- `pages/herdr_screen.dart`, `pages/pair_screen.dart` — theme rename + trailing
  commas only.
- `pages/home_screen.dart` — theme rename plus removal of the `Appearance` field,
  its constructor argument and the "外观" popup item (intended).
- `widgets/workspace_sidebar.dart` — byte-identical tokens.
- `widgets/event_tiles.dart`, `permission_card.dart`, `new_session_sheet.dart`,
  `history_sheet.dart`, `dir_picker_sheet.dart`, `herdr_terminal.dart`,
  `herdr_terminal_rows.dart` — theme rename (`AppTheme`→`RemoteTheme`,
  `const TerminalStyle`→`RemoteTheme.terminalStyle`) and formatter commas only.

`RemoteTerminalPane` additionally carries the rename rationale in its doc
comment: the host's `TerminalPane` (`lib/editor/terminal_pane.dart`) owns
line-oriented local/cloud execution, and PTY bytes never go through
`ShellBackend.execute`/`sendLine` (no `ShellBackend` reference exists in the
module).

## Checks run (permitted locally)

| Check | Result |
| --- | --- |
| `dart format --output=none --set-exit-if-changed lib/remote_control` | 39 files, 0 changed |
| `dart analyze lib/remote_control` | "No issues found!" (uses the phase-01 `package_config.json`, where `flutter` and `xterm` resolve) |
| `python scripts/ste-lint-zh.py lib/remote_control/README.md` | 0 hard violations (0 baseline) |
| `git diff --check` | clean. No CRLF or trailing whitespace in new files |

Not run, by instruction: tests, builds, emulators, device/VM/WSL/Docker/adb/hdc,
live pairing. No local result here is device or CI evidence.

## Known limitations / follow-ups

1. **Host navigation entry not added.** `implement.md` phase 3 assigns "one host
   remote-computer entry with existing product gates". The module is reachable
   through `RemoteComputerPage.open(context)` / `RemoteComputerPage.isSupported`,
   but no menu item exists yet. Deliberate: this phase must not touch existing
   navigation.
2. **UI strings are hardcoded Chinese** as in the source. The host `i18n` layer
   is not used. Localising the module is a separate decision (source had no ARB
   files for these screens).
3. **No tests yet.** `core/test/remote_control` is phase 4. Nothing in this phase
   claims test coverage.
4. **`isSupported` is `!kIsWeb`.** That is exact for every target the host
   currently builds (web = no `dart:io`). A future non-web target without
   `dart:io` would take the stub path. The connection loop would surface the
   truthful `UnsupportedError` text, but the page would not pre-gate it.
5. **Runtime behaviour (socket, replay, Herdr streaming) is unverified here.**
   Only static analysis and source parity were checked.
