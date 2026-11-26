# Pi B backend report, November 21

Scope: `qfli_studio_core/lib/git/**` and `qfli_studio_core/test/git/**` in
`D:/MyNewProjects/_wt/studio-git-integration`. No local tests or builds were run.
only `dart format`, `dart analyze` and `git diff --check`. Nothing was staged or
committed.

## Edited files

- `lib/git/git_models.dart` — renamed enum value `GitChangeArea.index` to
  `GitChangeArea.staged`. The old name `index` collided with the implicit `index` member every
  enum value inherits, which was a compile blocker.
- `lib/git/cli_git_backend.dart`
  - `_exec` now routes every exit wait through `_waitForExit`, which cancels the
    owned child on timeout **and** on a broken stdout/stderr stream, then rethrows.
    Previously a stream error left a live `git` process behind until page dispose.
    Non-`GitOperationException` failures from process startup/streams are wrapped
    and redacted.
  - `snapshot()` passes `--no-renames` to `git status`, so a move is reported as an
    independent deletion and addition. Both sides are then addressable by
    stage/unstage instead of a single rename entry whose old path the index
    arithmetic missed.
  - `snapshot()` reports `state` from `MERGE_HEAD`, `rebase-merge` and
    `rebase-apply`. A rebase in progress is no longer labelled `clean`.
  - `_requireWorktreeRoot()` compares `git rev-parse --show-toplevel` with the
    requested root (symlinks resolved, case-folded on Windows) and refuses a
    nested project directory. Applied to snapshot, stage, unstage, stageAll, diff,
    history, commit, createBranch, checkout, merge, completeMerge, setRemote,
    fetch, push and pullRebase.
  - `init()` refuses to create a repository whose ancestor already holds a `.git`.
  - `checkout()` verifies `refs/heads/<name>` with `git show-ref --verify` and
    fails with `kind: 'invalid'` instead of detaching HEAD on `origin/main`.
  - `completeMerge()` names an in-progress rebase instead of claiming there is no
    merge to complete.
- `lib/git/native_git_backend.dart`
  - `fetch`/`push` re-check `_online()` inside the queued closure, at the request
    boundary, not only on entry.
  - `_endNetwork` clears `_cancelRequested` for the finished request, so a
    cancelled call no longer pre-cancels the next, unrelated network call.
  - `_rejectNested` walks ancestors for a Git directory and is called by snapshot,
    init, stage, unstage, stageAll, diff, history, commit, createBranch, checkout,
    merge, completeMerge, setRemote, fetch and push.
  - `checkout` refuses a name that is not a local branch before calling native.
- `test/git/native_git_backend_test.dart` — new regressions: nested snapshot,
  nested init (asserts no native init and no `.git` created), nested
  stage/unstage/stageAll/diff/commit/merge/setRemote/history refusal, offline
  policy enforced after queueing, a cancelled request not poisoning the next
  fetch, remote-only checkout refusal, local checkout pass-through.

## Checks actually performed

- `dart analyze lib/git test/git` — 0 errors, 0 warnings, 1 info
  (`depend_on_referenced_packages` for `qfli_git`, see below).
- `dart format lib/git test/git` — no remaining diff.
- `git diff --check` on the owned paths — clean.
- Verified all owned `.dart` files are LF only.

## Remaining issues

Rechecked against core `75bd342` (core run 44809141095, 2394 passed, 26 existing
skips). Status after the committed UI and dependency work:

1. RESOLVED. `pubspec.yaml:28-31` now declares `qfli_git` on the reviewed
   artifact commit `e30e88fcba6cd31d452598cbd6111f3f2acae41e`.
   `dart analyze lib/git test/git` reports no issues, including no
   `depend_on_referenced_packages`.
2. RESOLVED. `lib/pages/git/git_local_view.dart:705` passes
   `GitChangeArea.staged`, and no `.index` spelling remains in the UI or
   controller.
3. RESOLVED. `lib/pages/git/git_local_view.dart:56-61` gates merge completion on
   `state == 'merge'` (or `merge:*` only). Lines 62-72 route `rebase` to a
   separate `_unsupportedOperation` path that explains the recovery instead of
   offering merge completion.
4. RESOLVED. `lib/pages/git/git_dialogs.dart:516-533` renders remote refs as
   disabled entries with an explicit note that they serve merges only. The
   adapter-side refusal remains as the second layer.
5. RESOLVED. `lib/store/git_page_controller.dart:482-497` reloads the snapshot in
   `_fail` before returning, appends a separate log line when the refresh itself
   fails, and keeps the original error message.
6. LIMITED, accepted. CLI snapshots still emit no rename entries because
   `git status --no-renames` is deliberate. `git_local_view.dart:559` and
   `git_page_controller.dart:157-158` still understand `oldPath`, which is now
   only reachable from a backend that reports it. Behaviour is correct: a move
   shows as a deletion plus an addition and each side is individually
   stageable.
7. PARTLY RESOLVED. Root's `test/git/cli_git_backend_integration_test.dart` now
   carries the disposable-repository scenarios and is part of the green core run.
   Still limited: the `_waitForExit` stdout/stderr error path has no direct unit
   test, because it needs a fake `Process` injected through `ProcessSupervisor`.
8. LIMITED by design. `init()` refuses any directory below an existing worktree,
   so a deliberately nested repository cannot be created. This is the minimal
   contract chosen for the task. A future opt-in would need an explicit product
   decision.

No item above is a release blocker. Items 6-8 are behavioural or coverage limits
that match the approved design.

## Cross-owner confirmations

- Pi A: no native API change was needed for these fixes. Nested-root rejection is
  enforced in core before any plugin call, so mobile refuses instead of resolving
  an outer repository.
- Pi C: `GitBackend` signatures are unchanged apart from the enum value rename.
  `fetch`/`push`/`pullRebase`/`cancelNetwork`/`dispose` semantics are unchanged
  except for the stricter policy and cancellation reset described above.
