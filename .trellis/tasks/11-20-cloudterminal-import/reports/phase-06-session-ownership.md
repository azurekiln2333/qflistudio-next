# Remote lifecycle review follow-up

The migration core is ready for coordinator review and cloud execution. No local test or build ran. No commit or push was made by this reviewer.

## Reviewed and fixed

- R1: `HomeScreen` passes Herdr only to terminal sessions. `SessionScreen` also guards its own injection boundary. Claude text remains a structured `send` request.
- R2: pane routes claim unique leases before deferred work. Stale routes cannot move or stop the replacement watch. Pane/tab chips reject stale leases, including after a pending tab-focus reply. The supported Studio navigation replaces pane-capable destinations. Embedders that stack them must explicitly reclaim ownership when revealing an older destination.
- R3: the module exposes a host exit. `HomeScreen._exit` closes the drawer before invoking the host callback. Flutter's drawer removes its local history when the reverse animation starts. `TestRemoteHost` now uses a navigator key. The owned-controller exit regression observes its Codex notice stream closing.
- R4: both migrated Codex host tests retain and dispose their injected controller. The idempotent test owner permits assertions plus teardown fallback.
- R5: `RemoteController` keeps identity owner sets per session. Final release alone unsubscribes. Overlapping owners share the same subscription request and its error, instead of letting the second owner silently succeed before the first request resolves. Connection changes, explicit close, final release and disposal clear the cached requests. Error cleanup checks request identity and connection epoch before touching replacement state.
- R5 input follow-up: the shared PTY emulator also had a replacement race. The outgoing `RemoteTerminalPane.dispose` cleared the replacement's input and resize callbacks. It now clears only callbacks it still owns. Deferred resize also checks ownership.
- Harness: fake-async connection setup advances via `tester.pump`. Page-boot cases start with an unconnected fixture. Direct Claude request slicing uses the total request count. Teardown unmounts widgets before disposing controllers.
- Cloud fixture: `herdr_pS_visible_ansi.txt` contains 75-cell padded rows. The old no-fill claim contradicts the captured bytes. The corrected test enumerates each expected transformed row. It preserves ANSI sequences, the reverse-video cursor, real empty rows and line endings. The fixture and production transform remain unchanged. Separate no-fill tests remain intact.

## Regression coverage

`remote_module_regression_test.dart` covers Claude isolation, Herdr route transitions, stale leases, narrow/wide exits, drawer exit and host ownership. `session_ownership_test.dart` covers real animated PTY/Claude replacement, reconnect cursors, event deduplication, live output after old-route disposal, PTY input after replacement, A-to-B-to-A, final unsubscribe, shared failures, retry and stale request failure. Fake agent output is gated on actual wire subscriptions, so an erroneous unsubscribe prevents delivery.

## Exact static checks

- `dart format` on changed Dart files: exit 0.
- `dart analyze lib/remote_control test/remote_control test/support`: exit 0, `No issues found!`.
- `git diff --check`: exit 0. Git printed only existing LF-to-CRLF checkout notices.

Cloud execution is still required. No device validation is claimed. Stage only reviewed `lib/remote_control`, `test/remote_control`, and `test/support/remote_control_app.dart` changes. Exclude the unrelated unfinished `.github/` and `tool/ci/` files.
