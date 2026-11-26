# Remote-control migration review

Review date: 2026-11-20. Reviewer: `recent_task_evidence`.

Scope: read-only inspection of the migrated core, host entry, companion lifecycle, and tests. No local tests, builds, runtime probes, agents, installs, or device commands were run. The original `D:/MyNewProjects/cloudterminal` was not modified. This report is the only reviewer-written file.

Core paths below are relative to `D:/MyNewProjects/_wt/cloudterminal-import/work/qfli_studio_core`. App paths are relative to its sibling `qflistudio` worktree. Implementation line numbers describe the first inspected snapshot. Test review was updated after the `04a-tests` report appeared at 13:45 on 2026-11-20.

## Release findings

### R1 — P1: Claude text can be sent to a Herdr terminal

Evidence:

- `lib/remote_control/pages/home_screen.dart:135` constructs `SessionScreen` for both terminal and Claude sessions. Line 138 always passes the shared Herdr controller.
- `pages/session_screen.dart:69` starts watching Herdr whenever that controller exists. `_followFocusedPane()` at line 119 has no session-kind guard.
- `_send()` at line 187 selects `herdr.watchedPaneId` without checking the session kind. Lines 190–192 send the text and Enter to that pane when the ID exists.
- The Claude composer at lines 487–494 also exposes the Herdr hint/action from the shared selection.

Trigger: the desktop has a focused Herdr pane, the user opens a Claude structured session, then submits a message. The text reaches the shell or TUI instead of the selected Claude session. The shell can execute the submitted text.

Fix: only terminal sessions may participate in Herdr following, subscriptions, input routing, or composer actions. Pass no Herdr controller to a Claude session at the host boundary and guard the session component itself. Claude submission must call `RemoteController.send` with that Claude session ID.

Regression: open a Claude session with an available, focused Herdr pane and a remembered Herdr selection. Submit distinct text. Assert exactly one Claude `send` request, no `herdr_send_text`, no `herdr_send_keys`, and no Herdr prompt action. Exercise the actual `HomeScreen` opening path as well as direct component use.

### R2 — P2: disposal of an old route cancels the new route's watch

Evidence:

- `pages/home_screen.dart:120` calls `_home()`, which pops prior inner routes, then immediately pushes a new route.
- `pages/session_screen.dart:145` calls `suspendWatching()` unconditionally during disposal.
- `pages/herdr_terminal_screen.dart:88` does the same.
- `state/herdr_controller.dart:167` has no owner check. It clears the shared pane subscription and sends `herdr_watch(null)`.

Trigger: switch between two terminal routes while the old route's reverse transition is active. The new route can watch pane B before old route A is disposed. A then clears B's subscription. The new screen may freeze, show a missing-pane notice, or fall back to its PTY.

Fix: give pane watching a route-owned lease. The controller's existing watchdog watcher count does not express pane ownership.

Suggested contract:

1. Each mounted pane-capable route creates a unique token. The controller stores the current token.
2. Claim the token synchronously before scheduling that route's initial watch. Claiming ownership alone need not notify listeners.
3. Route operations that set, resume, follow, or clear the pane require the current token. Reject stale tokens before changing either the subscription or remembered selection.
4. A route's disposal releases its own token. Only the current owner's release sends `herdr_watch(null)` and clears cached screens. Releasing a superseded token is a no-op.
5. Deferred initialization and focus listeners check ownership as well as `mounted`. An old mounted route must not reclaim a watch during a transition.
6. Pane-row selection operates through the active route's lease, or another explicitly current-owner controller operation. Keep the remembered pane separate from the active lease.
7. Reconnect only restores the currently owned subscription. Controller disposal still tears down all watches. Preserve the separate reference count for structure polling.

Avoid using a pane ID as the owner. Two routes can show the same pane, and an A→B→A sequence can reuse that ID.

Regression: retain real route animations. Switch A to B, let B establish its watch, then finish A's disposal. Assert B remains selected and streamed and no trailing `herdr_watch(null)` cancels it. Also cover two route instances displaying the same pane, stale deferred callbacks, terminal→Claude, and final owner disposal. The final disposal must stop streaming while preserving the remembered pane.

### R3 — P2: the paired module has no visible host exit

Evidence:

- `pages/home_screen.dart:187` creates an inner navigator.
- `_navigationButton` at line 70 is a drawer button below 1000 px and null at wider sizes.
- The managed home AppBar at line 328 uses that button. Automatic back handling sees the first inner route, not the outer Studio route.
- `widgets/workspace_sidebar.dart` exposes remote destinations and a drawer-close action, but no Studio-return action.
- `remote_computer_page.dart` adds no host-exit control around the paired dashboard.

Trigger: open the remote module from Studio and finish pairing on a desktop. The screen has no visible control that pops the host route. A narrow-screen drawer also lacks this action.

Fix: expose a clear return-to-Studio control. Capture or inject the host route's exit callback outside the inner navigator. Keep internal back navigation available for nested remote pages. Exit must release local resources without sending `close_session` for desktop processes.

Regression: mount a Studio-like host home and push `RemoteComputerPage` as a second route. Cover paired and unpaired states at narrow and wide widths. Activate the visible exit control and assert the host home returns. Test owned-controller cleanup separately from caller-injected controllers.

### R4 — P2, test port: two Codex widget tests lose controller cleanup

Evidence:

- Captured source `lib/main.dart:52–55` explicitly disposes `widget.controller` when `CloudTerminalApp` is removed.
- Migrated `remote_computer_page.dart:135` treats an injected controller as caller-owned. Its `dispose()` at line 176 only disposes controllers the page created.
- `test/support/remote_control_app.dart:30` incorrectly says that not disposing caller-supplied controllers matches the source app. The phase-04a report repeats this claim.
- `test/remote_control/codex_test.dart:149` and `:199` create controllers inline inside `TestRemoteApp`. Neither test retains and disposes its controller. Both remove the widget tree at the end.

Result: those two tests leave the fake socket, frame subscription, and controller alive. The source widget supplied cleanup that the new test shell no longer supplies. No runtime failure is claimed without CI execution, but the resource ownership change is definite.

Fix: retain each controller and register explicit teardown, or make an explicitly owning test wrapper. Keep the production page's documented injected-controller ownership unchanged. Correct the helper comment and phase report. An exit test should assert client socket closure and absence of `close_session`.

## Ported-test review

The completed `04a-tests` port contains six suites: `pairing_uri_test.dart`, `remote_controller_test.dart`, `terminal_test.dart`, `herdr_test.dart`, `herdr_direct_input_test.dart`, and `codex_test.dart`. Test fixtures and a replacement host shell are also present. Its report states that analysis and formatting passed, but no tests ran. The report counts 232 tests and 788 assertions. This reviewer did not rerun those checks.

Confirmed coverage in the code:

- Pairing parsing, code exchange, relay changes, and invalid payloads.
- Structured events, permissions, duplicate sequence suppression, reconnect resubscription, and auth/offline errors.
- PTY bytes, terminal replay, and resizing.
- Herdr input ordering, uncertain-input dropping, paste-target capture, pane switching, remembered selection, and terminal rendering.
- Codex protocol fixtures and approval/history paths.

Coverage gaps identified by inspection:

- No Claude-with-active-Herdr routing-isolation regression was found.
- `herdr_test.dart:3117` tests a complete unmount followed by remount. It does not overlap two animated routes, so it cannot detect R2.
- `test/support/remote_control_app.dart:45` mounts `RemoteComputerPage` as `MaterialApp.home`. It cannot detect R3 because no host route exists underneath.
- No migration-specific atomic/ordered disk-persistence test was found in these six suites.
- No explicit module-exit assertion that desktop sessions remain alive was found. Existing teardown calls are not that assertion.
- Source mobile navigation/acceptance suites are not part of the completed six-suite port. Their absence leaves additional host-integration acceptance work.

The absolute Windows/source paths in Herdr fixtures are data fields, not filesystem dependencies. The actual fixture reader at `herdr_test.dart:2199` reads `test/fixtures/$name`. The referenced fixture files are present. Do not flag the fixture path literals as source-checkout access.

## Other verified observations

- `RemoteController.dispose()` closes the client connection and does not issue `close_session`.
- The companion agent's `clientLeft()` removes client subscriptions and watch state. It does not close desktop sessions. Explicit session closure remains a separate operation.
- PTY input remains raw. Herdr queued input retains pane identity and drops uncertain work after failure/disconnect.
- The server's pane-read publication checks both generation and state identity, including repeated pane selections.
- Permission and approval controls still require explicit actions in the inspected paths.

These observations are static evidence only. Cloud CI and device acceptance remain separate evidence requirements.

## Unresolved inspection leads

- Compare the source Android cleartext setting and iOS ATS/local-network declarations with the host product's supported relay modes. No platform failure is claimed from this static difference alone.
- Review the companion README's licensing statements against source provenance and retained notices. Do not invent a source-wide license.
- Check the Windows assistant launcher's Chrome fallback against the actually copied platform scaffold and its `dart:io` imports.

## Status

R1, R2, and R3 remained present in the inspected implementation. R4 was found in the completed test port. Fixes and focused regressions are required before release approval. Phase `04b-ci` started after the test port finished. No green runtime result is claimed by this review.
