# Phase 04a — core test port

Status: **implemented** (test code written and statically checked). The tests were
**not executed**, by instruction: this phase may not run tests, builds, VMs or
devices locally. "Implemented" therefore means the port exists, preserves the
source assertions, and analyzes clean — not that the suite passes. CI and the
first real execution belong to phase 04b.

Worktree: `D:/MyNewProjects/_wt/cloudterminal-import/work/qfli_studio_core`
(branch `remote/cloudterminal-core`).
Source read only: `D:/MyNewProjects/_wt/cloudterminal-import/source/cloudterminal`
(HEAD `49b2aac781858929a19307faeb808b83f8154410`).
No production file was edited in this phase. No install, build, test run, VM,
emulator, Docker or device command was executed. The original
`D:/MyNewProjects/cloudterminal` was not touched.

## Files created

All paths are relative to the core package root. `test/remote_control/` is new.
`test/fixtures/` is new in the core but mirrors the source copy.

| File | Source | Lines |
| --- | --- | --- |
| `test/remote_control/pairing_uri_test.dart` | `test/pairing_uri_test.dart` | 389 |
| `test/remote_control/remote_controller_test.dart` | `test/remote_controller_test.dart` | 680 |
| `test/remote_control/terminal_test.dart` | `test/terminal_test.dart` | 279 |
| `test/remote_control/codex_test.dart` | `test/codex_test.dart` | 372 |
| `test/remote_control/herdr_test.dart` | `test/herdr_test.dart` | 3,794 |
| `test/remote_control/herdr_direct_input_test.dart` | `test/herdr_direct_input_test.dart` | 1,914 |
| `test/support/fake_relay.dart` | `test/support/fake_relay.dart` | 156 |
| `test/support/codex_fixture.dart` | `test/support/codex_fixture.dart` | 138 |
| `test/support/remote_control_app.dart` | **new**: host shell + theme for tests | 48 |
| `test/fixtures/herdr_pS_visible_ansi.txt` | same | 20 |
| `test/fixtures/herdr_pZ_visible_ansi.txt` | same | 4 |
| `test/fixtures/herdr_wrap_proof.txt` | same | 6 |

Each ported file starts with a provenance header naming the source file and
HEAD. The three fixtures are byte-identical to the source (MD5
`e82f26e9cdb098f521bf9fe19f0585ae`,
`d960095ed7067cdc06dd6ffbc9359fe7`,
`a07a81e4bba0535d3214cb15228126e7`).

## Adaptations, and only these

The port was mechanical: a script rewrote package paths and the names below,
then `dart format` normalised layout (the source files were formatted with an
older style). Token-level comparison against the source confirms the body
changes are exactly these edits.

1. **Package paths.** `package:cloudterminal/models|net|screens|state|widgets/`
   became `package:qfli_studio_core/remote_control/models|transport|pages|state|widgets/`.
   The socket is at `transport/relay_socket.dart`, so tests import the interface
   from there, not the conditional-export connector: a fake socket never needs
   the `dart:io` client.
2. **`AppStore` → `RemoteStore`** (`state/app_store.dart` →
   `state/remote_store.dart`). `RemoteStore.memory()`, `setPairing`,
   `setString` and `lastRelayUrl` are unchanged from the source store, so no
   test line changed beyond the identifier.
3. **`TerminalPane` → `RemoteTerminalPane`** (and its file name
   `remote_terminal_pane.dart`) in `codex_test.dart`. The widget's constructor
   and behaviour are unchanged. The rename exists so the host's own
   `lib/editor/terminal_pane.dart` cannot be confused with it.
4. **Source app root replaced by a test shell.** `codex_test.dart` mounted
   `CloudTerminalApp` (`lib/main.dart`), which owned a `MaterialApp` and a
   global `Appearance` controller. The module deliberately does not create a
   `MaterialApp` — `RemoteComputerPage` is a route body that inherits the host
   navigator/theme — and `Appearance` was not ported. The test now mounts
   `TestRemoteApp(store:, controller:)`, defined in
   `test/support/remote_control_app.dart`: one `MaterialApp` around the real
   `RemoteComputerPage`, with the same store/controller injection. The page
   calls `connect()` exactly as the source app root did and, like the source,
   does not dispose a caller-supplied controller.
5. **Theme helper.** `AppTheme.light(AppTheme.seeds.first.color)` became
   `remoteTestTheme()` in the same support file: a seeded Material 3
   `ThemeData`. The source `AppTheme` also styled app bars, cards, buttons and
   inputs. The ported assertions never read a colour or a text style. They look
   for widgets, labels and wire frames, so the seeded palette is sufficient.
   This is the one deliberate visual difference in the ported widget tests.
6. **Dropped `Appearance` in `herdr_direct_input_test.dart`.** The
   `HomeScreen to pane` test created `Appearance(AppStore.memory())` only to
   pass it to `HomeScreen`. Since the appearance controller was not ported,
   that construction and the `appearance:` argument are gone, and the test
   disposes `remote` directly (`addTearDown(remote.dispose)`). The remaining
   test body, including the assertion that reaching a pane sends no
   `create_terminal`, is untouched. The migrated `HomeScreen` has the same
   constructor minus `appearance`.
7. **Relative helper paths.** `test/support/*` stays shared at
   `test/support/` (the core already keeps helpers there), so tests import
   `../support/fake_relay.dart`, `../support/codex_fixture.dart` and
   `../support/remote_control_app.dart`. `herdr_test.dart` and
   `herdr_direct_input_test.dart` still import `controllerFor` from
   `terminal_test.dart`, as in the source.

No assertion was deleted, relaxed, skipped or re-timed. `Thread`/`Future`
waits, `pumpAndSettle` calls and `expect` arguments are the source ones except
where the token diff above shows an identifier swap.

## Parity evidence

Counted on the source file and the ported file:

| File | `test(` | `testWidgets(` | `expect(` | `group(` |
| --- | --- | --- | --- | --- |
| `pairing_uri_test.dart` | 18 | 0 | 73 | 2 |
| `remote_controller_test.dart` | 20 | 0 | 62 | 4 |
| `terminal_test.dart` | 3 | 3 | 35 | 0 |
| `codex_test.dart` | 3 | 5 | 47 | 0 |
| `herdr_test.dart` | 84 | 45 | 417 | 11 |
| `herdr_direct_input_test.dart` | 8 | 43 | 154 | 9 |
| **total** | **136** | **96** | **788** | **26** |

Every row is equal between source and port. `codex_fixture.dart` has **zero**
changed tokens. `fake_relay.dart` differs only in the two import-path tokens.

## Checks run

```
dart analyze test/remote_control \
  test/support/fake_relay.dart test/support/codex_fixture.dart \
  test/support/remote_control_app.dart
# exit 0, "No issues found!"

dart format --output=none --set-exit-if-changed test/remote_control \
  test/support/fake_relay.dart test/support/codex_fixture.dart \
  test/support/remote_control_app.dart
# exit 0, "9 files (0 changed)"

git diff --check
# exit 0
```

Additional static checks: no trailing whitespace and a final newline in every
new file. No remaining `AppStore`, `CloudTerminalApp`, `AppTheme`,
`Appearance` or `package:cloudterminal` reference outside the provenance
headers. `scripts/ste-lint-zh.py` is a prose linter and is not applicable to
Dart sources (it reports every `;` as a violation). Run on this report, it
reports 0 hard violations.

## Not verified here (truthful limits)

- **The suite has not run.** Static analysis proves imports, names and
  signatures resolve. It cannot prove the widget flows still produce the
  expected labels. Those flows were ported in phase 02 and the label strings
  asserted here were found verbatim in `lib/remote_control/`, but that is
  evidence, not a test pass.
- The two structural adaptations (host shell, seeded theme) are the most likely
  places for a runtime surprise. If CI fails there, the fix belongs in
  `test/support/remote_control_app.dart`, not in weakened assertions.
- `herdr_test.dart` reads fixtures through `File('test/fixtures/<name>')`, so
  the suite must be started from the package root, as in the source repository.
- Platform coverage is unchanged from the source: these are VM/host tests of
  the module, not device acceptance. No OHOS/Android/iOS check was attempted.
- CI wiring is deliberately absent. Phase 04b owns it.