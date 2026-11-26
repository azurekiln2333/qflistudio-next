# Offline workspace sessions

## 1. Scope and trigger

Language-product explorer roots, tree expansion and editor view sessions share
`history.json`. The main product uses [explicit saved workspaces](saved-workspaces.md)
and single-project standalone history instead.
Concurrent updates must merge their owned fields, and multi-root tabs must retain
the correct project identity across real EditorPage reconstruction.

## 2. Signatures

`ProjectHistory.save(projectPath, cursors:, openFiles:, activeFile:, expandedDirs?,
documents?)`, `saveExpandedDirs(projectPath, dirs, treeRootExpanded?)`, and
`saveWorkspaceRoots(projectPath, roots)` serialize per resolved physical project
path, falling back to a canonical lexical path when the directory is unavailable.
Existing symlink/junction aliases must share the same lane. Resolve the queue key
before enqueueing to preserve invocation order.
`load(projectPath)` observes writes queued before/during the load.

`ProjectDocumentSession(projectPath:, relativePath:, cursor:, isActive: false)`
describes an ordered tab. `EditorController.openPath` receives owner name/path/type.

## 3. Contracts

Legacy `openFiles`, `activeFile`, and `files` remain main-project-relative. Additive
`documents` records hold owner root, relative source path, cursor and active flag in
tab order. Tree expansion, root visibility, membership and document records survive
other fields' updates. Copy mutable collections before queueing writes.

Persist selection endpoints as physical source line indices, converting both
through `controller.codeLines.index2lineIndex`. Visible indices change when a block
is folded, while restored documents start unfolded. Preserve selection direction
and offsets, and use the same cursor for additive and legacy fields.

Explorer membership is stored under the primary editor project. Each root retains
its own expanded directories and collapsed/expanded root flag. Removing a root
preserves files, currently open tabs and that root's saved expansion.

Restoration resolves only the current owner or another registered local project.
Use its current name/type. Missing, duplicate, absolute/traversing and physically
outside-root linked files are skipped. Removing a tree root does not prohibit its
already-open tabs from restoring while that owner remains registered.

Source text is not persisted in view-session metadata. Dirty buffers are retained
by the existing live editor host, not by history.json.

## 4. Validation and error matrix

| Condition | Behavior |
| --- | --- |
| Legacy history | Expanded root/no extra roots; restore old main-root tabs/cursors. |
| Malformed document record | Skip row; retain valid rows and legacy fields. |
| Unregistered/foreign cloud owner, missing file or escaped path | Skip tab without touching source. |
| Duplicate source path | Restore once, retaining original order. |
| Concurrent editor/tree/membership writes | Merge without lost fields. |
| Async restore returns for a stale tree generation | Ignore it. |
| Page closes before initial restoration completes | Preserve the prior session. |
| File creation/deletion under a secondary root | Use that root; deletion first creates its correctly attributed recycle-bin backup. |
| Create inside a collapsed directory | After restoration, expand and persist the parent before showing the new entry. |
| Editor closes during backed-up deletion | Finish the authorized filesystem operation; skip disposed editor/UI callbacks. |
| Run with a secondary-root tab active | Capture that owner before awaiting saves; use its configured entry, working directory, preview root and audit identity. |
| Another workspace root has dirty or unsaveable files | Run saves only the selected owner's buffers; unrelated roots do not block execution. |
| Long-press Run | Validate the selected file against its lexical and physical owner root before saving; never fall back to another entry. |

## 5. Good, base and bad cases

Good: B/local.h, A/main.dart, B/other.cpp restore in that order, with A active and
independent cursors; B headers use C++ owner type. Base: one old root restores as
before. Bad: saving only paths within A while silently dropping B's tabs.

## 6. Required tests

Run `workspace_editor_session_test.dart`, `file_explorer_state_test.dart`,
`project_history_concurrency_test.dart`, retained-editor, run/terminal and full core
tests. Test real page reconstruction, tab order/active/cursors, malformed and stale
records, independent expansion, queued field merges, removal/re-addition, search,
secondary-root create/backed-up delete and narrow/large-text toolbars.
Include folded selections across roots, create-triggered expansion reconstruction,
disposal during backed-up deletion and actual filesystem alias concurrency where
directory links are supported. Scope tree finders to the explorer: a dialog's
editable text can otherwise falsely satisfy a newly-created entry check. Drain
queued fake-time history continuations by pumping while allowing real IO to run;
do not await those continuations inside `tester.runAsync`.
`editor_run_test.dart` additionally exercises secondary-root tap/long-press,
switching back to the primary root, owner capture across asynchronous saves and
tab switches, unrelated save failures and HTML preview factory dispatch.

## 7. Wrong versus correct

Wrong: load a stale whole session, mutate one field and overwrite another queued
writer, or save partial tabs while initial restore is still running. Correct:
snapshot each caller's fields, queue by normalized project identity, read remaining
fields inside the queue, and capture a complete editor session after restoration.
