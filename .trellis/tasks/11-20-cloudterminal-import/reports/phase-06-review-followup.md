# Independent review after phase 05

Pi process 22124 exited normally at 2026-11-20 16:10:30 +08:00. Its dispatcher recorded exit 0 and `artifacts_ready_unreviewed`. That status is not acceptance. The phase report remains an unfinished outline. The implementation and new regression suite exist.

Static-analysis evidence in `05-review-fixes-1.jsonl`: `dart analyze lib/remote_control test/remote_control test/support` printed `No issues found!` after two unused declarations were removed. No local tests or builds were run. The shell piped output through `tail`, so the captured shell exit code is not independent evidence of the analyzer's exit code. The analyzer output itself reports no issues.

R1's terminal-kind guards, R2's unique lease, and R4's explicit Codex test cleanup exist. R3's dashboard and pairing exits exist, but the drawer path is defective. Independent review found the following runtime blockers before any cloud run:

1. `test/support/remote_control_app.dart:104` calls `Navigator.of(context)` from `_TestRemoteHostState`. That State's build returns `MaterialApp`, so its context is above the navigator. Use a navigator key or a context captured below MaterialApp's navigator.
2. `test/remote_control/remote_module_regression_test.dart:180` uses `_connect()` before widget mounting. Its awaited `Future.delayed(Duration.zero)` calls at lines 201, 206, and 215 wait for fake-async timers while no `tester.pump` advances them. Pass the tester and pump, or use a correctly controlled microtask-based fixture setup.
3. The same `_connect()` already connects its single FakeSocket. Host-oriented tests then mount `RemoteComputerPage`, whose boot calls `connect()` again. RemoteController.connect tears down the current socket, and the fixture connector returns that closed socket again. Keep the fixture unconnected for page-owned startup, or provide a genuinely fresh socket per connection. Do not weaken the production lifecycle to accommodate a broken fixture.
4. The direct-Claude test records `herdrFramesBefore` as the count of filtered Herdr requests, then skips that count in the unfiltered request list at line 381. Existing requests remain in the tested tail. Record the total request-list length before the action, or compare correctly filtered snapshots.
5. The drawer exit invokes the host `Navigator.pop()` without closing the drawer first. Flutter's drawer adds a LocalHistoryEntry to that same module route. The first pop consumes the entry and leaves the module open. Evidence in installed Flutter source: `packages/flutter/lib/src/material/drawer.dart:530–550` and `widgets/routes.dart:1053–1067`. Close the drawer before invoking the host-exit callback. Keep the existing drawer-exit regression.

Additional review observations:

- The new pane-row handlers reject stale watch writes, but still issue desktop focus actions after a rejected/null lease. Consider gating both the UI enablement and focus action on the route lease. A stale asynchronous tab selection must not retarget the pane after its route loses ownership.
- Several new tests inspect a widget while both old/new routes animate. Finder counts must deliberately select the active route or settle only after the overlap assertion. Do not remove animations to make the test pass.
- A plain push of a second terminal route invalidates the first route's lease. Returning to the still-mounted first route does not reacquire a lease. Current HomeScreen uses pop-and-push for terminal destinations, but embedded callers should have a documented supported navigation contract or a route-awareness fix.
- The unpaired page-owned-controller exit test asserts navigation only. It does not yet verify owned controller disposal. Add a meaningful ownership assertion if the test harness can expose that controller without changing production ownership.

R5 (same session subscription race) is described in `phase-briefs/06-session-ownership.md`. The parent coordinator may implement it directly instead of dispatching phase 06. Do not run phase 06 concurrently with coordinator edits.
