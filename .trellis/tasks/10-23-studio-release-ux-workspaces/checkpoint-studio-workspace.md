studio-workspace checkpoint (page lock honored)

PAGE LOCK: no editor_page.dart writes since 02:05:38 local (before handoff). Only file_explorer.dart touched after handoff. I will not edit editor_page.dart until C releases.

Page is stable; do NOT replace from a snapshot. 4 of my page edits already landed in the shared tree and must be preserved:
1. _saveHistory: workspace snapshot skips files in _orphanedPaths (so a removed member's path is never written back; recovery only via 另存为…).
2. _isOrphaned + _reconcileWorkspaceMembers now key orphans by workspacePathKey (normalize+absolute, Windows case-folded).
3. _reconcileWorkspaceMembers snackbar deferred with WidgetsBinding.addPostFrameCallback — it is called from didUpdateWidget, and calling showSnackBar during build throws.
4. (earlier) workspace params/apply/restore/save, _orphan guards in save/autosave/run, popup item recover_orphan, AppBar workspace subtitle.

Remaining page-specific changes from me: NONE. C owns page integration. Notes for C, no action requested:
- retain `if (_isOrphaned(f)) continue;` in _saveHistory (just after the isWithin check) and the post-frame snackbar; removing either reintroduces "deleted dir recreated by autosave" / build-phase showSnackBar assert.
- didUpdateWidget: same workspace id + changed members updates _workspaceMembers and calls _reconcileWorkspaceMembers; dirty orphans kept, clean tabs closed.
- retained_editor_host.dart is mine (not page): workspace key = workspace id only; primary fallback updates session.project + bumps workspaceRevision and now notifyListeners() so ListenableBuilder reaches EditorPage even when the session is already active.

DONE in my scope since last report:
- file_explorer: fixed RenderFlex overflow by removing fixed heights — header Column child SizedBox(48) -> ConstrainedBox(minHeight 48); workspace row IconButton visualDensity.compact + 40x40 constraints; tree row SizedBox(34) -> ConstrainedBox(minHeight 34) + vertical 3 padding. Rows now grow with text scale instead of clipping.
- file_explorer: restored legacy `_workspaceSelectionRevision` race guard in _restoreLegacyWorkspace (revision captured before load, re-checked after load and after each Directory.exists); bumped on legacy apply, on _applyWorkspaceState, and on explicit workspace save/update/delete. Child legacy behavior preserved.
- Home/dialog remove(): WorkspaceStore.remove may now throw and keep the entry. saved_workspaces_tab catches and shows a retryable SnackBar; workspace_dialogs keeps the dialog open with an inline "可重试" error. No false success.
- Legacy child tests restored to HEAD (not narrowed) and given an explicit child productKey (forge); main-only behavior lives in new test/main_workspace_sessions_test.dart.

Verification so far (all before the test freeze):
- flutter analyze clean: lib/workspace, file_explorer.dart, editor_page.dart, retained_editor_host.dart, home_page.dart, 3 test files (re-run after explorer edits: file_explorer + lib/workspace clean).
- flutter test workspace_editor_session_test.dart: 4 passed (child legacy contract).
- flutter test file_explorer_state_test.dart: 12 passed (child legacy contract).
- flutter test main_workspace_sessions_test.dart: 5 passed (promotion/reuse, id-only identity + primary fallback, standalone ignores legacy cross-root history, workspace session saved to workspace doc only, missing-primary survivor restore). A 6th (membership shrink: clean tab closed, dirty orphan kept, file untouched, orphan excluded from snapshot) was green on assertions except the final persisted-doc check, which was still being diagnosed when the freeze landed.
- Root cause of the earlier test hangs: tester.pump() without a duration never advances fake time, so store write continuations (timers) never fire; pump(Duration(ms:50)) is required. `settle()` inside runAsync deadlocks — do not await it from a testWidgets body.

TESTS: holding. No flutter test runs from me until root announces the window.

Known limitation: main_workspace_sessions_test.dart test 6 currently asserts the persisted workspace doc has only the survivor; last observed state still had both owners, so either a late queued write or the poll was reading pre-write memory. Needs one window slot to finish; everything else in that file is green.
