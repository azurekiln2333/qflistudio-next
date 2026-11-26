# Parallel Git clone and live progress

Home blocks a second clone with one busy flag. Native and CLI clone discard transfer progress. Allow overlapping clone tasks and show real progress for each.

- Keep the clone action available while a repository is cloning.
- Give each task a name, live stage, progress bar and independent cancellation.
- Display measured percentages when counts exist. Use an indeterminate indicator otherwise.
- Isolate success, failure and cancellation. Preserve registration and cleanup contracts.
- Bound the task list on small screens. Keep credentials out of progress events.
- Use the three release worktrees. Preserve existing work and the original CloudTerminal workspace.
- Run tests and builds in GitHub Actions. Publish the verified installers under a new tag.

## Approved release closeout

The user requested version 5.0.6 and integration into GitHub main on 2026-11-21.
The user then directed four existing Herdr Pi agents to finish in parallel.

- Integrate the verified App release history into GitHub main without rewriting history.
- Set the App version to 5.0.6 with an incremented build number.
- Publish the immutable v5.0.6 tag through the complete installer workflow.
- Keep Core and plugin pinned to their verified commits unless a real release failure requires a fix.
- Inspect the four GitHub topic branches named by the user. Delete a remote branch only after proving that its complete history is reachable from GitHub main.
- Preserve every unrelated dirty checkout and all existing local worktrees.
- Report cloud validation, installer publication and signing states from evidence.
