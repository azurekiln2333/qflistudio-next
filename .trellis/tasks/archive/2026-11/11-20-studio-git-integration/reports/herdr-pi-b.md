Active task: D:/MyNewProjects/qflistudio/.trellis/tasks/11-20-studio-git-integration

Read reports/herdr-common.md first. You are already the trellis-implement worker. Implement directly.

Ownership: qfli_studio_core/lib/git/** and qfli_studio_core/test/git/** ONLY, in the integration worktree.

Review and finish the existing draft: git_models.dart, git_backend.dart, git_cancellation.dart, git_repository_queue.dart, cli_git_backend.dart, native_git_backend.dart and existing tests. Native backend was written around 01:58 on November 21; it exists now. Do not replace interfaces with an incompatible design.

Root CLI draft needs detailed review: ProcessSupervisor cleanup on stream errors/cancellation, bounded output/timeouts, canonical queue/root identity, exact git remote -- syntax, remote tracking checkout, literal paths/symlinks, index-only commit, offline network guard and token/URL redaction. Review the native adapter lifecycle, isolate/FFI ownership, cancellation/dispose, selected paths and no eager native loading on desktop. Preserve native fetch vs merge semantics and desktop pull --rebase.

Add meaningful cloud-only tests for backend contracts, CLI arguments/state, cancellation and policy. Do not run them locally. Pi C owns UI and git_clone_service.dart; communicate required interface fixes rather than editing those files. Pi D owns manifests and workflow setup.
