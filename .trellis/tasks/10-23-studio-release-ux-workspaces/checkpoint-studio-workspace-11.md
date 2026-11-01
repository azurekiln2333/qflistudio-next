studio-workspace: 26/26 GREEN, EXIT=0, LIVE=0. Slot released. Home popup patch is ready for native Home1.

EXACT RESULT (one serial invocation, cached dart + flutter_tools.snapshot, --no-pub --concurrency=1 --timeout 60s):
  command: & "D:\ProgramFiles\flutter_ohos\bin\cache\dart-sdk\bin\dart.exe" "D:\ProgramFiles\flutter_ohos\bin\cache\flutter_tools.snapshot" test --no-pub --concurrency=1 --timeout 60s test/main_workspace_sessions_test.dart test/main_saved_workspaces_tab_test.dart test/main_output_no_analyzer_test.dart test/main_editor_short_height_test.dart test/workspace_editor_session_test.dart test/file_explorer_state_test.dart
  tail: 00:18 +26: All tests passed!
  EXIT=0
  LIVE=0 (dart + flutter_tester) immediately after exit
  log: %TEMP%\ws-batch3.log

Breakdown (26): sessions 6, tab 2, output-no-analyzer 1, real-EditorPage-shortheight 1, legacy workspace_editor_session 4, legacy file_explorer_state 12.

HOME POPUP PATCH STATUS (source-only, ready for native Home1):
- lib/pages/home_page.dart, four popup Rows 445-500 (import_project, add_existing, new_cloud, remove_missing): each label Text is now wrapped in Expanded with overflow: TextOverflow.ellipsis. Consistent across all four.
- Gates preserved: add_existing still behind AppPaths.isDesktop; new_cloud still behind !_isMainStudioProduct && offlineProfile != offlineOnly && auth.isLoggedIn; import_project still gated by _archiveBusyLabel.
- dart format applied; flutter analyze clean on home_page.dart.
- Not verified by me by design: native Home1 runs it after my release (58px addExisting / 100px removeMissing at available width 256).

TWO TEST-HARNESS CORRECTIONS made in this slot (tests only, no product change):
1. Real EditorPage 1100x175: the page intentionally suppresses the activity panel when bodyHeight < minEditorHeight + 96, so asserting EditorOutputPanel there was wrong. The test now asserts the primary invariant only: real page mounts, FileExplorer sidebar present, CodeEditor mounted, takeException() null before AND after the real 更多 -> Output gesture. Tree/header assertions untouched; no weakening.
2. Orphan Run acceptance: cross-project tab labels are "owner/name" (tabLabel), so the finder uses textContaining('main.dart') + ensureVisible; the tab switch only commits when indexIsChanging goes false, so it waits for editor.current to become main.dart; and the Run notice can queue behind a reconcile snackbar for 4s, so the wait window is 7s. Assertion is unchanged in strength: real Run gesture, notice present, file bytes still 'one\ntwo'.

Also fixed earlier this slot: tab test now waits for _open's filesystem resolve before reading sessionInfos (was reading too early).

Locks held: no editor_page/controller/terminal/debug/output writes; editor_page.dart mtime remains C's. Native main_workspace_actions_test.dart untouched. Home+content runner may proceed.
