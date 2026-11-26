Active task: D:/MyNewProjects/qflistudio/.trellis/tasks/11-20-studio-git-integration

Read reports/herdr-common.md first. You are already the trellis-implement worker. Implement directly.

Ownership: qfli_git/native/**, qfli_git/lib/**, qfli_git/test/** ONLY, in the integration worktree.

Review and finish the existing API v2 draft end to end: seven new C symbols, header, FFI bindings, public Dart types/methods/exports, smoke tests, parser and native API tests. Existing C changes and repository_git_ui_test.dart are already present; do not discard them. Check memory/error ownership, path safety/literal path handling, empty/unborn repositories, selected-file stage/unstage, bounded diff, history/branches/remotes JSON, compatibility and lazy ABI check. Review use-after-free and output buffer lifetime. Include meaningful CI-only cases for failures and normal flows.

Core adapter depends on stagePaths, unstagePaths, diff, log, branches, remotes, setRemote and the existing clone/fetch/merge/push/commit API. Maintain the design.md contract. Notify root of any necessary contract changes before editing outside scope.

Checked-in binaries are still API v1. Do not pretend they validate v2 or build locally. Pi D owns cloud workflow/artifact tools and will produce matching binaries after root pushes source. Finish product source and tests now.
