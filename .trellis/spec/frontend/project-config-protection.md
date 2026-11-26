# Project Configuration Deletion Protection

## 1. Scope / Trigger

Apply when changing managed project-file deletion or adding a file rename or
move operation. Source authority is the integration Core at
`D:/MyNewProjects/_wt/studio-git-integration/qfli_studio_core`.
This contract does not claim that the planning-root App resolves that Core.

## 2. Signatures

`services/project_config_guard.dart` owns `ProjectConfigGuard`:

- `pathError({required String projectRoot, required String absolutePath})`
  returns a nullable error after lexical and canonical path checks.
- `deletionError({required String projectRoot, required String absolutePath})`
  returns `Future<String?>` and also scans containing directories.
- `relativeDeletionError(String relativePath, {Iterable<String> descendants})`
  checks portable cloud paths and known remote descendants.

Callers display a non-null error and perform no deletion.

## 3. Contracts

The exact protected names are `.git`, `.gitignore`, `.gitattributes`,
`.gitmodules`, `.editorconfig`, `.trellis`, `.agents`, `.codex`, `.claude`,
`.qfli`, `.vscode`, `.idea`, `AGENTS.md` and `CLAUDE.md`. Name comparison ignores
case. The policy protects each node and its descendants. It also protects a
selected directory containing any protected node. Other dotfiles remain
deletable. Configuration reads and ordinary edits remain available.

Reject the project root, outside paths, NUL and raw dot traversal. Resolve local
aliases against the real project root. Check the resolved relative path again.
Missing leaves inherit an existing ancestor's canonical path. Windows protected
name checks also account for trailing dots, spaces and alternate data streams.
Directory scans do not follow child links. Inspect encountered links for
protected targets or escapes. Inspection failures refuse deletion.

`FileExplorer` disables deletion in the context menu after the same full check.
It checks again before confirmation and after recycle-bin backup. Cloud
`pushDelete` validates the local path, reads the scoped remote tree and protects
remote descendants before marking activity, updating cache or sending DELETE.
Retain the captured `CloudSession` across those awaits.

The current Agent file tools expose list, read, write and edit. They expose no
delete, move or rename operation. The editor also has no file rename/move
entry. Any future relocation must check the source and any overwritten
destination with this policy before mutation.

Whole-project deletion from Home remains governed by its separate confirmation
and recycle/cloud lifecycle. No terminal or command-shell sandbox is added.

## 4. Validation & Error Matrix

| Operation | Expected result |
| --- | --- |
| Delete `.git` as file or directory | Refuse |
| Delete `.trellis/workflow.md` | Refuse |
| Delete a directory containing `AGENTS.md` | Refuse |
| Delete an alias into protected configuration | Refuse |
| Delete an ordinary `src/main.dart` | Preserve normal recycle/delete flow |
| Read or edit `.trellis/workflow.md` | This deletion policy does not block it |
| Cloud tree preflight fails | No remote DELETE or dirty/activity mutation |
| Explicitly delete a whole project from Home | Separate project lifecycle |

A failed cloud preflight may occur after the editor removed local files. A
previously synchronized file remains in `workspace.json`.
`CloudCacheService.workspaceIsClean` compares actual files and their hashes with
that baseline, including the number of paths. A missing baseline file makes
the workspace unclean. `clear` refuses that mismatch before removing bytes.
This protection does not invent a pending deletion for an untracked file.

## 5. Good / Base / Bad Cases

- Good: use the full async guard for a selected directory, then repeat it after
  confirmation and backup.
- Base: use `relativeDeletionError` on validated remote paths, including the
  candidate's descendants from the current scoped file tree.
- Bad: disable only the `.git` menu item while permitting its parent deletion.

## 6. Validation Required

Run targeted Dart analysis for the policy, `file_explorer.dart` and
`cloud_sync_service.dart`. Check no-write formatting and whitespace diffs.
Review ordinary paths, protected descendants, containing directories, casing,
canonical aliases and stale cloud sessions. This session permits static
verification only. Runtime tests, builds, services and devices were not run.

## 7. Wrong vs Correct

Wrong: compare only `basename(path) == '.git'` at the menu layer.

Correct: reuse the shared guard at the menu and mutation boundaries. Include
protected descendants, parent deletion and canonical aliases. Keep explicit
whole-project deletion in its existing lifecycle.
