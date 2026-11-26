Active task: D:/MyNewProjects/qflistudio/.trellis/tasks/11-20-studio-git-integration

Read reports/herdr-common.md first. You are already the trellis-implement worker. Implement directly.

Ownership: qfli_studio_core/lib/pages/git_page.dart, lib/pages/git/**, lib/pages/home_page.dart, lib/editor/editor_page.dart, lib/store/git_page_controller.dart, lib/services/git_clone_service.dart and new focused UI/controller/clone tests OUTSIDE test/git/**. All paths are relative to the integration core worktree.

Finish the actual visible Studio integration using the existing UI draft: Git navigation for active local project/editor document, changes/stage/unstage/diff, history/branches/remotes, selected staged commit, clone and repo registration. Retain existing cloud server Git flow. Capture editor owner before awaits. Never overwrite dirty buffers. Review mounted/dispose/stale-request generation, error rendering, read/mutation busy coordination, author/token distinction and offline enforcement.

Known clone bug to fix: Directory.createSync() is not exclusive. Existing claim that a racing creator wins is false; cleanup may remove another actor's directory. Use a collision-safe ownership strategy and publish/register only on success. Coordinate contracts by reading lib/git/git_backend.dart; Pi B owns lib/git/** and test/git/**. Do not edit those paths.

Write meaningful CI-only UI/controller/clone tests. No local test/build/app run. Complete review/fixes instead of only reporting the draft as done.
