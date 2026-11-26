# Pi D recovery report — plugin repository methods

Task: `11-20-studio-git-integration`
Worktree: `D:/MyNewProjects/_wt/studio-git-integration`

## Completed

Edited `qfli_git/lib/src/repository.dart`:

- Added `GitRepository.stagePaths(List<String>)` using `qg_stage_paths`, with a
  temporary NUL-terminated `const char **` array and per-string/array cleanup in
  `finally`.
- Added `GitRepository.unstagePaths(List<String>)` using `qg_unstage_paths`.
- Added `GitRepository.diff({String? path, bool staged = false, int maxBytes = 262144})`
  using `qg_diff_json`; null path passes `NULL`, and parsed with `parseDiff`.
- Added `GitRepository.log({int limit = 20})` using `qg_log_json`, parsed with
  `parseLog`.
- Added `GitRepository.branches()` using `qg_branches_json`, parsed with
  `parseBranches`.
- Added `GitRepository.remotes()` using `qg_remotes_json`, parsed with
  `parseRemotes`.
- Added `GitRepository.setRemote(String, String)` using `qg_remote_set_url`.
- Added `_withUtf8Array<T>` helper: allocates the pointer array only for
  non-empty input, copies UTF-8 strings, frees strings then array in `finally`.
  Empty input passes `nullptr` with count 0.
- All operations retain the existing `Isolate.run` + `_withRepo` pattern, so
  `checkApiVersion()` runs before any lazy v2 symbol lookup, and native repo
  handles, errors, JSON strings and path arrays are freed.

Edited `qfli_git/lib/qfli_git.dart`:

- Exported `GitBranch`, `GitCommit`, `GitDiff`, `GitRemote`.
- Exported `parseBranches`, `parseDiff`, `parseLog`, `parseRemotes`.

Added `qfli_git/test/repository_git_ui_test.dart`:

- Parser coverage for diff (`patch`, `binary`, `truncated`, defaults, malformed),
  log (Unix seconds to UTC, Unicode, defaults, missing oid/time, non-array),
  branches (current/remote/upstream, defaults, Unicode, missing name), and
  remotes (name/url, missing URL, null, missing name).

## Verification

- No local tests, builds, native runs or services were executed.
- Native C v2 bindings already present and were not modified; API version check
  remains `qgApiVersion = 2`.
- Existing public API and dirty UI/CI work preserved.
