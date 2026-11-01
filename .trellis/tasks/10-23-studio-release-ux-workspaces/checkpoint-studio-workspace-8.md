studio-workspace: acceptance assertion authored (tests only). No page writes; no runs. Holding for stable API + slot (points suite currently running).

NEW file: test/main_output_no_analyzer_test.dart (1 mounted test, main product, no analyzer)
- StudioProfile.current is main (qfliStudioKey) with codeAnalyzer left null.
- Mounts the real EditorPage with initialOpenPath on src/main.dart; waits for CodeEditor.
- Real gesture: tap tooltip '更多' -> tap 'Output · 输出'.
- Asserts: EditorOutputPanel is present (so the absence checks are not vacuous); NO text containing '未安装本地代码检查器' and NO '检查不可用'; CodeEditor still findsOneWidget (normal editor child stays mounted behind the panel).
- Teardown: unfocus, pump 6s to expire timers, drop the tree, takeException (re_editor detach artifact).

Why it is meaningful: _onAnalysisChanged currently returns early when _analysis.analyzer == null, so a main product must log nothing. If C's new logger appends the unavailable reason for main/no-analyzer, the Output panel renders '检查不可用 · 当前产品未安装本地代码检查器' and this test fails. Exact strings taken from editor_analysis_controller.dart: '当前产品未安装本地代码检查器'.

flutter analyze clean. No page/API dependency beyond the existing widget types (EditorPage, EditorOutputPanel, CodeEditor) and the existing menu labels; if C renames the menu item, the test fails loudly at the 'Output · 输出' assertion rather than silently skipping.

Scope respected: editor_page.dart untouched (C lock, currently modified by C202/native); test/main_workspace_actions_test.dart not touched (native release agent).

Slot queue after the current points suite, on root's explicit grant (one at a time, cached snapshot):
1. test/main_workspace_explorer_test.dart (4, includes actual 1100x175)
2. test/main_workspace_sessions_test.dart (6, includes the Run-gesture assertion)
3. test/main_saved_workspaces_tab_test.dart (2)
4. test/main_output_no_analyzer_test.dart (1, new)
5. legacy workspace_editor_session_test + file_explorer_state_test (4 + 12)

Report: zero live handles from me right now.
