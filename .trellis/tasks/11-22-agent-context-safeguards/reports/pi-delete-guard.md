# R3 Deletion Guard Handoff

## Owned source

- `lib/services/project_config_guard.dart` (new shared path policy).
- `lib/editor/file_explorer.dart` (disabled context-menu deletion and two
  mutation checks around confirmation and backup).
- `lib/services/cloud_sync_service.dart` (preflight before cache/activity and
  remote mutation, retaining the captured session).

All source paths belong to the integration Core. No controller, API, facade,
skill loader, Agent model or Git index was edited.

## Behavior

The precise protected set and API are recorded in
`../../../spec/frontend/project-config-protection.md`. The policy protects
named nodes, descendants, containing directories, case variants and canonical
aliases. It rejects invalid/outside paths and refuses inspection failures.
Ordinary file deletion retains recycle-bin backup. Reads and normal edits are
not blocked by this deletion policy.

The editor and managed Agent file tools have no file move/rename/delete-tool
entry beyond the editor deletion covered here. No new interface was invented.
Home's explicit project deletion remains unchanged. Shell commands receive no
new sandbox or security guarantee.

Cloud preflight reads `fileTree` through the captured scoped session. It
validates each remote path and checks protected descendants before setting
dirty/activity markers or calling remote DELETE. Failed preflight makes no
dirty/activity mutation. When a previously synchronized local file was already
deleted, `workspaceIsClean` still finds the missing baseline path because
`seen.length != baseline.length`. `clear` refuses that mismatch before removal.
An untracked file does not acquire an invented pending deletion.

## Verification

Targeted Dart analysis of all three owned files passed with no issues.
No-write formatting passed for the same files. Owned diff whitespace checks
passed. Static review traced configuration nodes, subtrees, parent directory
scans, canonical aliases, raw traversal, Windows name aliases, ordinary files
and preserved cloud session fences.

No runtime test, build, local service, device, stage, commit or push ran.
