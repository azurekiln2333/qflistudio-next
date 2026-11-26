# Backend cross-layer review, November 21

Read-only review of the integration worktrees. No product edits, local tests or builds were performed. Line numbers reflect the draft inspected during active Pi work and may move.

## 1. Remote branch checkout has incompatible behavior on both adapters

Evidence:
- Core `lib/pages/git/git_dialogs.dart:542` offers `GitBranchChoice.checkout(branch.name)` for remote entries such as `origin/main`.
- Core `lib/git/native_git_backend.dart:294` forwards that string unchanged.
- Plugin `native/src/qfli_git.c:936` only calls `git_branch_lookup(..., GIT_BRANCH_LOCAL)` in `qg_checkout_branch`.
- Core `lib/git/cli_git_backend.dart:439` runs `checkout origin/main --`, which checks out the remote ref as detached HEAD. The subsequent push implementation refuses a detached HEAD.

Result: selecting the same remote branch fails on mobile and detaches desktop HEAD. The UI reports a normal branch switch in the latter case.

Fix: define one explicit remote-selection contract. Either create a named local tracking branch, with collision/upstream handling in both adapters, or disable remote checkout in the branch-switch dialog and retain remote refs only for merge selection. Do not silently detach. The task already requires selecting remote tracking refs for merge after fetch, so removing only remote checkout does not prevent that flow.

Owners: Pi B for adapter semantics, Pi C for dialog contract, Pi A if a tracking-branch native API is added. Cloud regression: select a remote-only branch and assert either explicit refusal or attached local branch with the correct upstream.

## 2. Nested project directories use inconsistent repository/path identities

Evidence:
- CLI constructor keeps the requested project directory (`cli_git_backend.dart:17`). `_exec` uses it as cwd (`:152`).
- `snapshot()` accepts any directory inside a worktree and uses porcelain v1 status (`:224`), whose paths are relative to the repository root.
- `stage`, `unstage` and `diff` reuse those returned paths relative to the original project cwd.
- `GitRepositoryQueue.run` resolves symlinks but does not resolve a repository worktree root.
- Native snapshot requires `.git` directly under the requested root (`native_git_backend.dart:162`, `:584`) and therefore rejects a nested project that desktop accepts.

Example: open project `/repo/sub`; status returns `sub/file.dart`; stage then targets `/repo/sub/sub/file.dart`. Two project roots `/repo` and `/repo/sub` also use separate queues despite mutating one index. `stageAll` from the subdirectory stages only its subtree while the snapshot lists the full repository.

Fix: resolve and retain the actual worktree root before accepting snapshots or mutations, and use that identity consistently for queueing, process cwd and relative paths. If discovery cannot fit the frozen synchronous factory, do lazy resolution in each adapter before the first queued operation. Alternatively reject a nested project explicitly and consistently rather than accepting it with wrong paths. Preserve init/clone behavior for nonexistent repositories and respect the editor's displayed operation target.

Owner: Pi B. Cloud regression: open repository root and its nested project directory in separate instances, verify path operations and shared serialization; include a symlink alias.

## 3. Unstaging a displayed rename leaves an unintended deletion staged

Evidence:
- CLI `parseStatus` correctly records the old path for rename entries.
- `GitPageController.unstage` (`lib/store/git_page_controller.dart:160`) sends only `[change.path]`.
- CLI `unstage` (`lib/git/cli_git_backend.dart:329`) resets exactly those supplied paths.

Example: staged rename `a.txt -> b.txt`; clicking unstage resets only `b.txt`. `a.txt` remains deleted in the index, so the next commit can delete `a.txt` despite the UI action saying the rename was unstaged.

Fix: preserve rename semantics across the contract and reset both old and new paths for an actual rename. Do not blindly apply this to copied files, because the current model conflates R and C. A safe smaller alternative is to request status without rename/copy detection and display independent deletion/addition entries consistently. Native status currently does not enable rename detection or expose old paths, so coordinate the representation instead of assuming both adapters already agree.

Owners: Pi B for representation/backend, Pi C for controller path selection, Pi A only if native rename metadata is added. Cloud regression must inspect the index after unstaging, not only the emitted argument list.

## 4. Failed pull --rebase hides changed repository state and offers merge completion

Evidence:
- CLI supports `pull --rebase` (`cli_git_backend.dart:522`).
- CLI snapshot derives state only from `MERGE_HEAD` (`:270`), so a repository in `rebase-merge` or `rebase-apply` is labeled `clean`.
- Controller failure path skips snapshot refresh (`git_page_controller.dart:453`). A failed pull can already have changed disk and index before stopping at conflicts.
- UI `_mergeInProgress` treats any conflict as merge (`git_local_view.dart:54`) and offers `git-complete-merge` (`:402`).
- CLI `completeMerge` requires `MERGE_HEAD`, which a rebase conflict does not supply.

Result: a real rebase conflict first leaves the old snapshot visible; after manual refresh the UI presents a completion action that cannot work for that state.

Fix: discover operation state via git-path locations for merge, rebase-merge and rebase-apply; refresh repository state after failed mutating commands while retaining the original error; refresh clean editor buffers even when an operation partially changed disk. Keep rebase recovery explicit. The task excludes interactive rebase, so identify the state and explain the supported recovery path instead of labeling it a merge.

Owners: Pi B for state discovery, Pi C for error-refresh/editor and action gating. Cloud regression: a pull-rebase conflict must preserve the failure, expose current conflicts and rebase state, and never enable merge completion.
