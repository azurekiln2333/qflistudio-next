# Pi A plugin handoff

Source commits on `release/studio-git-ui-20261120`: `15d6c66` (API v2 plugin
source), `d002bd3` (unborn-head fix in `qg_log_json`), `e30` (imported API v2
artifacts). Plugin source is frozen. No local test or build ran. Only static
checks ran.

## Files owned by Pi A

| Path | Change |
| --- | --- |
| `native/include/qfli_git.h` | API v2 header: seven symbols plus contract comments |
| `native/src/qfli_git.c` | stage, unstage, diff, log, branches, remotes, set remote |
| `native/test/smoke.c` | host smoke covers the v2 surface |
| `lib/src/bindings.dart` | FFI bindings for the seven symbols |
| `lib/src/repository.dart` | Dart types, parsers, repository methods |
| `lib/qfli_git.dart` | public exports for the new types and parsers |
| `test/native_git_ui_test.dart` | new FFI regression suite |
| `example/integration_test/flow_test.dart` | file URL for local clone and push, stage markers |

## Fixture fix: local clone and push use file URLs

Commit `e30` ran the example integration test on an iOS simulator twice and hung
after `Xcode build done.` in both runs (14m34s, then 51m), with no test output
and an orphan `simctl` child at cancellation. The log showed no Flutter or Dart
failure, so the stall sits in the simulator install or launch step.

The fixture also carried a defect that fails as soon as the app reaches the test
body: `GitRepository.clone` was handed a bare directory path, and the plugin
rejects a remote URL without a transport (`remote URL needs a scheme such as
https://`).

Changed in `example/integration_test/flow_test.dart`:

- `GitRepository.clone(url: Uri.directory(sourcePath).toString(), ...)`.
- `_addRemote(..., 'bare', Uri.directory(barePath).toString())`.

The plugin URL validation is unchanged, and no assertion was added, removed or
softened: the file still carries 19 `expect(...)` calls, the same count as
`HEAD`.

Markers were added so a cloud log names the stage that stalled. They use
`debugPrint` from `package:flutter/foundation.dart`, which keeps `avoid_print`
clean, and all print `[qfli-git-flow]`:

- `setup: ensureInitialized start` / `done`
- `setup: directories created`, `setup: source commit done`,
  `setup: bare repository init done`
- `stage: clone start` / `done`, `stage: diverged branch created`,
  `stage: merge start`, `stage: merge done with conflicts`,
  `stage: merge commit done`, `stage: push start` / `done`,
  `stage: remote verified`
- `teardown: removing fixture directory`

If a rerun hangs, the last marker names the stalled stage, and `setup:
ensureInitialized start` without its `done` pairs points at plugin init instead
of the simulator. No marker prints a temporary path.

Cloud evidence for this defect: `reports/tag-git1-ios.log` lines 12706-12715
show the setup stage completing and the clone failing with `remote URL needs a
scheme`. The current production SDK `.1` launched the app and reached the
fixture before that failure. The older SDK runs at `e30` never reached a test
assertion, so their launch path stays unproven rather than cleared.

## API v2 symbols

`qg_stage_paths`, `qg_unstage_paths`, `qg_diff_json`, `qg_log_json`,
`qg_branches_json`, `qg_remotes_json`, `qg_set_remote`. `QG_API_VERSION` is 2.

## Review fixes from `herdr-review-a.md`

1. `git_repository_head_tree` is not public. A new `qg_head_tree` helper uses
   `git_repository_head` then `git_reference_peel` and frees the reference on
   every path. An unborn or missing HEAD yields a NULL tree.
2. `qg_head_json` returned the unborn error code with valid JSON. It resets
   `rc` to 0 for `GIT_EUNBORNBRANCH` and `GIT_ENOTFOUND`.
3. `qg_diff_json` encoded the patch text once, after the body loop. Per chunk
   encoding produced invalid JSON, and zero deltas produced `{"patch":,`.
4. Untracked content now appears in worktree diffs through
   `GIT_DIFF_SHOW_UNTRACKED_CONTENT`.
5. Patch text is generated once. `git_diff_print` with a callback stops at the
   byte bound, so a large file never builds a full in-memory patch.

## Diff callback contract

- `git_diff_line.content` omits the origin byte for context, addition and
  deletion lines. The callback writes `line->origin` first, like libgit2
  `git_diff_print_callback__to_buf`.
- The binary flag comes from the delta flags and from
  `GIT_DIFF_LINE_BINARY` in the callback. Either source sets it.
- A positive return from `git_diff_print` is this code's own stop signal. It
  maps to `rc = 0` with `truncated = true`.
- Truncation stops on a UTF-8 boundary and never splits a sequence.

## FFI regression suite
`test/native_git_ui_test.dart` calls `GitRepository` and parses each result
with `jsonDecode`. It covers:

- An empty diff for staged and for worktree.
- A modified file with `-old`, `+new`, and context lines that keep the leading
  space.
- An untracked file that contributes `+hello`.
- Two files in one patch body, once unstaged and once staged.
- A binary file with `binary: true`.
- `maxBytes: 256` with `truncated: true` and a patch of at most 256 bytes.
- A remote URL with embedded credentials, rejected through a closure so a
  synchronous throw is caught too.
- Log and branch metadata.

When `QFLI_GIT_LIBRARY` is unset or points at a missing file, `setUpAll` calls
`fail`. CI fails without the built library. The suite never skips. It passed in
the cloud against the imported API v2 artifacts.

The suite calls no `QfliGit.ensureInitialized`, because host tests lack
`path_provider`. It imports `src/library.dart` for the environment variable and
keeps the public exports unchanged.

## Static checks actually run

- `dart analyze lib test` reported no issues.
- `dart format` wrote the four Pi A files. A second run changed nothing.
- `git diff --check -- native lib test` reported no whitespace error.
- `dart format` wrote `example/integration_test/flow_test.dart`; a second run
  changed nothing.
- `dart analyze example/integration_test/flow_test.dart` reported exactly two
  errors, both pre-existing and environmental, because the example has no
  `.dart_tool/package_config.json` in this checkout:
  - `5:8 Target of URI doesn't exist: 'package:integration_test/integration_test.dart' (uri_does_not_exist)`
  - `21:3 Undefined name 'IntegrationTestWidgetsFlutterBinding' (undefined_identifier)`

  The same import is present at `HEAD`, so `flutter pub get` in CI resolves it.
  The analyzer did not flag `package:flutter/foundation.dart`; `debugPrint` is
  used by `_mark`, so the import stays.
- `dart analyze lib test` stayed clean after the fixture edit.
- `git diff --check -- example/integration_test/flow_test.dart` reported no
  whitespace error. The file is 35 insertions and 2 deletions: the two clone and
  push arguments plus markers and the `_mark` helper.
- The markers carry no temporary-directory values, so a cloud log never records
  a per-run path.

## Known gaps

- API v2 artifacts are already imported at `e30`: ten files passed the strict
  `check_native_install.py` checker, and the FFI and native cloud gates passed on
  `d002bd3` (`host-smoke` run 44802440226). No local run happened; every native
  result above comes from CI.
- iOS simulator launch of the example on the older SDK remains unproven. The two
  cancelled runs at `e30` stopped between `Xcode build done.` and the first test
  output, and nothing in those logs separates a stalled `simctl install` from a
  stall while waiting for the Dart VM service.
- The current production SDK `.1` reached the fixture and failed only on the bare
  clone URL from `reports/tag-git1-ios.log:12706-12715`. That is evidence about
  this SDK and this fixture. It is not evidence that the older SDK launch was
  healthy, and the older-SDK question stays open until a rerun with the file-URL
  fixture reports its stage markers.
- The earlier format concern is resolved. Plugin run `44820553378` at
  `53ad359` passed the format, analyzer, unit/FFI and example-analysis job.

## Next step

Read the rerun of the example iOS job. The last `[qfli-git-flow]` marker names the
stage that stopped, so a marker trail that ends at `stage: clone start` points at
the clone, and one that never leaves `setup: ensureInitialized start` points at
plugin init. Report the job name and log excerpt to Pi A.
