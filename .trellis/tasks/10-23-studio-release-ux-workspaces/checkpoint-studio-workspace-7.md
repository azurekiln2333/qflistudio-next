studio-workspace: author-only change landed; no tests started; zero live handles; page still C-locked (editor_page.dart 02:05:38). C202 integrated Run/debug orphan guards are untouched by me.

Added ONE focused assertion to the existing shrink test in test/main_workspace_sessions_test.dart (test 6), after the orphan/snackbar/disk checks:

  // Select the orphaned dirty tab and use the real Run gesture
  await tester.pump(const Duration(seconds: 5));            // let the earlier snackbar expire
  await tester.tap(find.descendant(of: find.byType(TabBar).first, matching: find.text('main.dart')));
  await tester.pump();
  expect(editor.current?.name, 'main.dart');                 // orphan is the active buffer
  await tester.tap(find.byTooltip('运行（长按运行当前文件）'));  // the real AppBar Run gesture
  await tester.pump();
  expect(find.textContaining('项目已从工作区移除'), findsOneWidget);
  expect(File(.../dart/main.dart').readAsStringSync(), 'one\ntwo',
      reason: 'normal Run must not save an orphaned buffer');

It exercises the same onTap as a user tapping Run (not _runProject directly), so it covers C202's guard path: selected orphan -> recovery notice, and the deleted project file is byte-identical afterwards (no save, no directory recreation).

flutter analyze clean on the file. No product code touched.

Queued for my next slot (root grants after Web then SQL; I will not chain):
1. test/main_workspace_explorer_test.dart   (4 cases; first real execution of primary fallback, remove+re-add, removed-root metadata, and the actual 1100x175 panel at scale 1.0/2.0)
2. test/main_workspace_sessions_test.dart   (6 cases; now includes the Run-gesture assertion)
3. test/main_saved_workspaces_tab_test.dart (2 cases; fake-zone seeding fixed)
4. test/workspace_editor_session_test.dart + test/file_explorer_state_test.dart (legacy 4 + 12)

Remaining unverified work: the actual-1100x175 and action test have not run yet. Known-pass evidence stays main_workspace_sessions 6 PASS (pre-Run-assertion) exit 0.
