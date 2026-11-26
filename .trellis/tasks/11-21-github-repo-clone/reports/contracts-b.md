# Pi B UI contract and change boundary

Pi B exclusively edits Home, `pages/git/github*`, `widgets/project_card.dart`,
`widgets/project_dialogs.dart`, `i18n/studio_localizations.dart`,
`services/git_clone_service.dart`, and focused UI/clone test sources.

R2 changes only the default destination parent to
`AppPaths.projectsRoot()/gitProjects/`. `Directory.createTemp` still reserves an
exclusive directory per operation. No registered project path moves.

R1 UI will consume A's published GitHub controller/models. Selection translates
into independent `GitCloneRequest` values and reuses Home's existing clone runner,
progress rows, registration, cancellation and error handling. The old URL dialog
remains accessible. A owns dependencies and credentials.

R3/R8 Home consumes C's refresh/delete/cache controller. Cache rendering needs
phase, completed/total file count, bytes, last success time and safe error text.
Cloud delete confirmation is distinct from local recycle-bin deletion. B does
not implement a parallel cloud downloader or registry mutation service.

R5/R6 add an explicit ZIP share action beside the existing `.qsz` export action.
`ArchiveShareService.shareProject(project, token: token, accountId: accountId)`
returns `shared` or `unsupported` with a retained ZIP path. An unsupported result
offers saving that exact ZIP, never another download and never false success.
Home captures account identity before cloud actions and discards stale UI results.

Workers must not edit Home or labels. No staging, commits, dependency edits,
store/cloud/editor/native changes, or remote-account-binding worktree changes.
Validation is local formatting/static analysis and cloud regression sources only.
