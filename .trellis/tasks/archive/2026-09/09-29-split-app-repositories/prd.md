# Split QFLIStudio apps into independent Git repositories

## Goal

Extract the shared Flutter core and eleven language apps into sibling Git repositories while retaining the main app and preserving local changes.

## Requirements

- Keep the main QFLIStudio application at `D:\MyNewProjects\qflistudio` and make each of the 11 language applications and the shared core a sibling Git repository.
- Preserve committed application history and all current uncommitted source changes.
- Keep `qfli_c_runtime` with the C application and the patched `re_editor` with the shared core, for a total of 13 repositories.
- Each application must resolve the shared core from its sibling checkout and retain its own dependency lockfile.
- Do not push or create remote GitHub repositories without a configured destination and credentials.

## Acceptance Criteria

- [x] The main app, 11 language apps, and shared core are separate Git roots under `D:\MyNewProjects`.
- [x] Every moved tracked or untracked source file is present in the corresponding new repository; pre-existing uncommitted changes stay uncommitted.
- [x] No app relies on the former root pub workspace or an in-tree `apps/` or `packages/` path for package resolution.
- [x] `flutter pub get` resolves for the main app, shared core, and language apps; focused analysis/tests pass where the local toolchain permits.
- [x] The original root repository no longer tracks the extracted application or shared package trees, and documentation gives the new checkout layout and push workflow.

## Constraints

- Preserve unrelated dirty files and local generated data in a recoverable backup.
- New remote repositories have no URLs yet; local repository creation and verified source migration are the deliverable in this task.
