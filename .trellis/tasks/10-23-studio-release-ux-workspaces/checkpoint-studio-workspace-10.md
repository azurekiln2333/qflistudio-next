studio-workspace: holding tests. Authored the REAL EditorPage short-height assertion. No process started; no page writes (editor_page.dart mtime 04:42:48 is C's, not mine).

Gap confirmed: my explorer 1100x175 case mounts FileExplorer standalone, so it never sees EditorPage's outer constraints. At 1100 wide (>= _wideBreakpoint 720) the page also renders the 280px sidebar card with 12px margins, inside a body whose height is 175 - AppBar(56) = ~119, against minEditorHeight = 140. That is the geometry C reported and the explorer-only test cannot reproduce.

NEW file: test/main_editor_short_height_test.dart (1 mounted test, main profile)
- tester.view.physicalSize = 1100x175, dpr 1, addTearDown(reset).
- Mounts the real EditorPage with initialOpenPath on src/main.dart; waits for CodeEditor.
- Asserts FileExplorer is present (so the sidebar card is inside the same short page), Console/tester.takeException() is null.
- Then real gesture: tooltip '更多' -> 'Output · 输出'; asserts EditorOutputPanel present, CodeEditor still present, takeException() null again (opening the bottom panel at this height must not overflow).
- Teardown: unfocus, pump 6s, drop tree, takeException.

Coverage notes, stated honestly:
- At 175 page height the page already gates chrome by available height: showTabs needs >= 220, showSymbols >= 160, showStatus >= 110 (available ~119), so this case exercises sidebar + code view + status bar, NOT the tab strip. If root/C want the tab-strip combination too, the cheapest real-page case is 1100x260 (available ~204 > 160, still under 220 for tabs) or 1100x300 for tabs+status; say the word and I will parameterize the same test over [175, 260, 300].
- The test asserts the invariant (no overflow, editor child mounted), not specific chrome visibility, so it will not break on legitimate layout tuning.

Also authored earlier and still pending: test/main_output_no_analyzer_test.dart (Output/no-analyzer acceptance).

flutter analyze clean on all four owned test files. Zero live dart/flutter_tester handles.

Requested next-batch grant (one serial invocation, cached snapshot, --no-pub --concurrency=1 --timeout 60s):
  test/main_workspace_sessions_test.dart test/main_saved_workspaces_tab_test.dart test/main_output_no_analyzer_test.dart test/main_editor_short_height_test.dart test/workspace_editor_session_test.dart test/file_explorer_state_test.dart

Ordered as sessions6, tab2, output1, shortheight1, legacy4, legacy12. No page/controller/terminal/debug/output writes; native main_workspace_actions_test.dart untouched.
