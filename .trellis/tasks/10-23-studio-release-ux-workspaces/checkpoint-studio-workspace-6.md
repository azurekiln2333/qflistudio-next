studio-workspace: harness deadlock fixed offline in both files. No new test started after the explorer invocation exited. Slot released.

Live handles: verified zero. `Get-Process dart,flutter_tester` returns nothing after the analyzer run; the only process that existed was the tester child root already terminated. Nothing of mine is running.

Result from the grant: main_workspace_sessions_test.dart 6 PASS, exit 0 (log %TEMP%\ws-sessions.log). Explorer run produced no product failure - it never executed a test body: it hung at the first test before mount, exactly the pattern root diagnosed.

Root cause (both files): store IO awaited directly in the testWidgets body before any pump.
- test/main_workspace_explorer_test.dart: `final workspace = await fixture.saveWorkspace([...]);` ran WorkspaceStore.save outside the real zone. Its queued write continuations are fake-zone timers that no pump had advanced yet, so the first pump never completed.
- test/main_saved_workspaces_tab_test.dart: same, plus `await fixture.saveSession(workspace, 'older.dart');` before mount.

Fix: seeding now runs in the real zone, mirroring the sessions test.
- explorer: all 4 tests use `late SavedWorkspace workspace; await tester.runAsync(() async { workspace = await fixture.saveWorkspace([...]); });`
- tab: test 1 seeds save+saveSession in one `tester.runAsync` block; test 2 uses `(await tester.runAsync(fixture.saveWorkspace))!`.
No product code touched; editor_page.dart untouched (C lock intact).

flutter analyze clean on both files.

Remaining real failure: none known. The explorer file's 4 cases (primary fallback, remove+re-add expansion, removed-root metadata, 1100x175 short panel) have never executed yet, so their status is unverified rather than failing. Next grant should start with:
  flutter test --no-pub --concurrency=1 --timeout 60s test/main_workspace_explorer_test.dart
using the cached snapshot wrapper, then main_saved_workspaces_tab_test.dart, then the two legacy files. I will not chain them.

Awaiting root's next explicit grant (Web, then SQL).
