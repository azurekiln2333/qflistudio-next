# Pi C — Studio Git UI, clone entry, editor ownership

Status: implementation complete and committed at Core `75bd342`. Product code is
frozen. Standalone core cloud run `44809141095` passed: 2394 visible passes,
26 pre-existing skips, no new failures.

Worktree: `D:/MyNewProjects/_wt/studio-git-integration/qfli_studio_core`

## Shipped scope

Entries below are exact paths relative to `qfli_studio_core`, all present in
`75bd342`.

### Git page and local repository UI

- `lib/pages/git_page.dart` — `GitPage` stays the single public route. Cloud
  projects keep the existing server flow unchanged (`addAll` then `commit`,
  status/log/remote/push/pull). The page now labels that flow as whole-directory
  server staging and never pretends to support index-only operations there.
  Local projects build a `GitBackend` through the factory, with an optional
  injected `backend` for tests.
- `lib/pages/git/git_local_view.dart` — real local repository view: captured
  project name/path, branch plus short OID, state chip, backend label, staged and
  unstaged sections, per-file diff/stage/unstage, index-only commit, history,
  branches, remotes, fetch/merge/push, desktop-only pull-rebase, conflict card and
  cancellation for network operations. Complete-merge is offered only for a real
  `merge` state. Rebase, cherry-pick and revert stop states get an explicit
  recovery card instead of a button that cannot work. Checkout, merge and pull
  refresh clean editor buffers even when the command fails.
- `lib/pages/git/git_dialogs.dart` — commit, identity, credentials, diff,
  history, branch, merge, remote names and branch-name dialogs, all scrollable
  with keyboard-inset padding. Remote-tracking refs are listed but not tappable:
  they are merge targets, never checkouts.
- `lib/pages/git/git_clone_dialog.dart` — clone URL/name/credential prompt.
- `lib/pages/git/git_worktree_guard.dart` — `GitWorktreeChangeRequest`,
  `GitWorktreeGuard`, `GitWorktreeChanged` (with `diskMayHaveChanged`).

### Controller

- `lib/store/git_page_controller.dart` — one session per repository: monotonic
  operation token, stale results never publish, busy label cleared on every path,
  reads and mutations share one busy state so a diff cannot race a mutation,
  snapshot refresh after both success and failure (the failure keeps its error),
  rename-aware unstage, remote-ref checkout refusal, idempotent `close()` that
  every caller awaits, synchronous `super.dispose()`.

### Clone coordinator

- `lib/services/git_clone_service.dart` — `GitCloneRequest`,
  `GitCloneDestination`, `GitCloneService`. The destination is created with
  `Directory(parent).createTemp('<name>_')`, one exclusive filesystem call, so a
  racing creator can never share the path and cleanup can never delete another
  actor's directory. Cancellation is re-checked after allocation and after the
  clone. Only the returned temp path is ever removed. Registration happens only
  after a successful clone, writes `.qfli/project.json` with `strict: true`
  (preserving an existing language/type) so the random directory suffix never
  becomes the project name, and recoverable clone data is preserved when
  registration fails.

### Home and editor

- `lib/pages/home_page.dart` — clone entry with busy label and cancel, plus
  registration-driven list refresh after a successful clone.
- `lib/editor/editor_page.dart` — Git navigation captures the active document
  owner before any await, refusing an orphaned owner and falling back to the
  primary project only when no document is open. The dirty-buffer guard resolves
  through save or explicit consent and never force-reloads. The post-operation
  refresh reloads clean buffers only, closes tabs deleted on disk and keeps
  workspace membership.

### Tests (mine)

- `test/git_local_view_widget_test.dart` — local view renders instead of the
  unsupported card. The remote branch is not tappable and never calls `checkout`.
  A refused guard stops checkout. An allowed guard refreshes exactly once with
  `diskMayHaveChanged: false`. `rebase_merge` shows the interruption card with
  `变基进行中` and no complete-merge. A real `merge` with unresolved conflicts keeps
  completion disabled.
- `test/editor_git_navigation_test.dart` — drives the real editor in a two-root
  workspace: opening the secondary project's file and pressing Git pushes
  `GitPage` for the secondary owner with the backend built for that project. And
  a dirty secondary buffer makes the real guard refuse, with `checkoutCalls == 0`
  and the unsaved text and disk content intact.

Root-owned tests I did not write or edit: `test/git_page_controller_integration_test.dart`,
`test/git_clone_service_integration_test.dart`, `test/git/**`.

### Root fixture fixes applied to my tests

- `git_local_view_widget_test.dart`: the rebase assertion matched two widgets
  because the header chip and the interruption card both render the state label,
  it is now scoped to the card via `find.descendant`, keeping the exact text and
  the assertion that complete-merge is absent.
- `editor_git_navigation_test.dart`: the fake backend's `snapshot` field collided
  with `GitBackend.snapshot()` and was renamed. The workspace save moved inside
  `tester.runAsync`. The explorer row is waited for instead of assumed after one
  frame. The guard future is observed through a completion flag pumped to
  completion instead of being awaited through `runAsync`, and the unmount drain
  pumps while real I/O runs. The duplicate outer `settle()` was removed because
  awaiting a test-zone future after `postTest` destroys the fake clock cannot
  drain and only produced a 5 s timeout.

## Contract consumed

`lib/git/git_models.dart`, `lib/git/git_backend.dart` (`GitBackend`,
`GitBackendFactory`, `GitCloneCancellation`, `GitOperationException`) as frozen in
design.md. No `lib/git/` edits, no `lib/services/` cloud API changes.

## Known limits

Closed by Pi B at `75bd342`, checked in the adapters and no longer current risks:

- **Nested project directories are refused.** `lib/git/cli_git_backend.dart:350`
  (`_requireWorktreeRoot`) compares `rev-parse --show-toplevel` with the project
  root and throws `kind: 'invalid'` with 请打开仓库根目录. It runs before snapshot,
  stage, unstage, diff, commit, branch, merge and the network calls.
  `lib/git/native_git_backend.dart:212` (`_rejectNested`) does the same for the
  plugin path. A nested project is rejected instead of staging `sub/sub/a.dart`.
- **Remote refs are refused in the adapters too.**
  `lib/git/cli_git_backend.dart:577` verifies `refs/heads/<name>` with `show-ref`
  before touching the index, so `checkout origin/main` cannot detach HEAD.
  `lib/git/native_git_backend.dart:326` requires a matching non-remote branch and
  otherwise throws 本地没有分支 …, 请先切换到本地分支. The UI and the controller keep
  their own refusal as the first line of defence.
- **Rename unstage is consistent by construction.** `lib/git/cli_git_backend.dart:272`
  passes `--no-renames`, so a move arrives as an independent deletion plus an
  addition and the single-path reset the controller performs is the correct one.
  The controller still resets `oldPath` and `path` together when a snapshot does
  report a rename, so a future representation change stays correct.

Still open:

1. **Pull-rebase recovery is terminal-only.** A stopped rebase is detected and
   explained, not continued or aborted from the page. The snapshot reports
   `rebase` from `rebase-merge` or `rebase-apply`, and the page shows the
   recovery card instead of a merge completion.
2. **Cache-directory write in tests.** `ProjectConfig.write` in the clone path
   writes real files, so those tests need CI file I/O, and nothing here fakes it.
3. **Device and desktop acceptance is unproven.** Every result below is a Linux
   CI run of the core test suite. The native plugin is exercised through its Dart
   adapter, not on a real OHOS, Android or iOS device, and no macOS or Windows
   desktop run is recorded.

## Cloud status actually evidenced

- Final run `44809141095` at `75bd342`: passed, 2394 visible tests, 26
  pre-existing skips.
- Original full-core run `44805454280` was cancelled, not failed: 2666 tests
  started, 2665 finished, one foreign-owner case still pending at cancellation,
  and zero errors.
- Intermediate run `44807763080` at `a8973c9` had two errors, both the outer
  `tearDown` `settle()` timeout that was later removed. Test bodies and the
  bounded unmount drain passed there.
- Not claimed: any device acceptance, macOS/Windows desktop run, or mobile
  installer verification. Those remain cloud/device follow-ups, not established
  by the runs above.

## Checks performed locally

`dart format` on every edited file, `flutter analyze --no-pub` on the owned
libraries and both UI tests (clean), `git diff --check`. No local tests, builds,
emulator, VM, container, adb or hdc. No commits, staging or tags from this
worker, and root coordinates all Git writes.
