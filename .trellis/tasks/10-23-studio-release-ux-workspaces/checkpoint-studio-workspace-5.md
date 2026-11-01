studio-workspace: circular membership check fixed in file_explorer.dart. Page lock and test freeze unchanged (editor_page.dart still 02:05:38, no Flutter runs).

Fix: in didUpdateWidget the fallback check no longer uses _workspaceMembersOrdered (which derives from _workspace -> _browsing, so the stale root A always looked allowed). It now uses the resolved widget membership only:

  final allowed = [widget.project, ..._workspaceProjects];
  if (!allowed.any((p) => p.equals(project.path, _browsing.path))) _browsing = widget.project;

_workspaceProjects is rebuilt earlier in the same method from widget.workspaceMembers excluding widget.project, so `allowed` == resolved members (plus the effective primary), independent of what is currently browsed. Comment in code records why the getter must not be used here, so it does not regress.

Audit of the remaining _workspace/_workspaceMembersOrdered uses: all are display/state paths that run after browsing has already been validated (dialog member list, _notifyWorkspace, expansion capture, tree build, header count). initState sets _browsing = widget.project for any workspace session (remembered-browsing is workspace-independent and null when a workspace is present), so mount cannot introduce a non-member root for a saved workspace.

Regression catch: test/main_workspace_explorer_test.dart 'primary fallback ...' asserts root(A) is absent after reopening W with primary B. With the circular check A stayed browsed, so that assertion would fail - the test does catch it once run.

flutter analyze clean: lib/editor/file_explorer.dart + test/main_workspace_explorer_test.dart.

Queue for the window: main_workspace_explorer_test (3), main_saved_workspaces_tab_test (2), main_workspace_sessions_test (6).
