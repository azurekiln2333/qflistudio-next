studio-workspace: stale-card fix in Home tab (lib/workspace/saved_workspaces_tab.dart). Page still C-locked (editor_page.dart 02:05:38), tests still frozen, no Flutter runs.

_open no longer trusts the card's SavedWorkspace:
1. If the store is not loaded yet, load first (avoids a false "deleted").
2. Resolve the latest by id: `final latest = _workspaces.byId(workspace.id)`. If null -> refresh the list and show "该工作区记录已被删除，列表已刷新"; no editor is opened (old code would have opened a workspace whose session writes are now no-ops).
3. resolve(latest, store) so WorkspaceResolution carries the current document, not the snapshot.
4. After the missing-members dialogs, re-read by id ("该工作区记录已被删除，未打开") because a delete can land while a dialog is open.
5. openEditorPage receives the freshest document (workspace: current), so the retained session keys/members/session come from the store, not from a stale card.

Store-notify-after-session-write: tolerated. The tab builds cards from _workspaces.workspaces inside ListenableBuilder, so a notify rebuild yields fresh cards; and even a card built before the notify is safe because the tap path re-reads by id. _replace inside saveSession updates the in-memory list, so byId is current with or without the notify.

Editor-side staleness (informational, no change): EditorPage/FileExplorer keep the object they were opened with; saveSession only uses workspace.id and reads the current document from disk, so a stale object cannot corrupt members/session. Retained host re-syncs on reopen when updatedAt or the member list differs.

Regression tests (written, not run): NEW test/main_saved_workspaces_tab_test.dart, real tab inside RetainedEditorScope:
- card built, then a newer session is saved; tapping the card must hand the host the newest documents ('newest.dart'), not the card snapshot.
- card tapped after its record was deleted (notify pending): no session is created and the "已被删除" snackbar shows.
Both compile; flutter analyze clean (test + lib/workspace + retained_editor_host.dart).

Added to retained_editor_host.dart (my file): read-only `sessionInfos` getter (key, project, workspace) for shell chrome/tests. No behavior change, no new public mutation surface.

Still waiting on the root test window; queue now: main_workspace_explorer_test (3), main_saved_workspaces_tab_test (2), main_workspace_sessions_test (6).
