studio-workspace: review-3 items fixed in file_explorer only. Page still C-locked (editor_page.dart last write 02:05:38, before the lock). No Flutter runs (tests frozen).

1) Browsing root can no longer outlive membership.
didUpdateWidget now reacts to workspace id, member list AND primary project path. Before any mutation it calls _captureWorkspaceExpansion() on the live tree, then updates members/primary, then enforces:
  allowed = _workspaceMembersOrdered; if (!allowed.any(path == _browsing.path)) _browsing = widget.project;
So when A disappears and Home resolves W with B, the tree drops A and browses B on the same live host (no widget-tree rebuild, dirty tabs of survivors untouched). Toolbar new file/folder and _ownerOf therefore default to B, not the deleted A.

2) Expansion capture is now a merge, never a replace.
_captureWorkspaceExpansion() starts from copies of the existing maps and overwrites only the roots that are currently mounted (_workspace), keyed through _sessionKey (normalized/Windows-case tolerant). Entries of removed members and of not-yet-restored members survive. _manageWorkspace no longer rebuilds the maps from current members: it captures outgoing live state, applies membership, rebuilds, awaits _restoring, then captures the settled state. Remove -> re-add therefore restores the folder expansion of the re-added root.
Retained metadata still cannot open files: _ownerOf iterates _workspace (mounted members only), so a removed root is unreachable from the tree/search regardless of its expansion entry.

Regression tests (written, not run - frozen): NEW test/main_workspace_explorer_test.dart, mounts the real FileExplorer tree under a main profile:
- primary fallback: W(A,B) with A/src and B/other expanded, then reopen W with primary B/members [B]: A root absent, B root present, B/other still expanded.
- remove + re-add: expand B/other, remove B (root gone), re-add B -> B/other restored expanded (fails on replace-semantics code, passes on merge).
- removed root metadata cannot open files: after removal, no rows and editor.files stays empty.
flutter analyze clean: test/main_workspace_explorer_test.dart + lib/editor/file_explorer.dart + lib/workspace.

audit: EditorController.project remains A after fallback. No default-owner path depends on it. _openFile/_openSearchResult/_create/_delete/_rename/_refresh all resolve the owner via _ownerOf(path) and pass owner name/path/type explicitly to editor.openPath; new file/folder uses _root.path (== _browsing, now guaranteed a member). EditorPage uses widget.project (B) for relative paths, run cwd, terminal and history writes. => No controller/API change needed from root or C.
One caution for C: if new page code adds a path that defaults to _editor.project, it will get A; use widget.project (effective primary) or an explicit OpenFile owner instead.

Still waiting on the root test window to run the three new tests + main_workspace_sessions_test.dart (test 6 fix already applied: fixture now reuses the persisted workspace id; asserts on-disk JSON).
