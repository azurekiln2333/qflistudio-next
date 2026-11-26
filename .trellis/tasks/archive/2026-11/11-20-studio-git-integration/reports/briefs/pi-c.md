Active task: D:/MyNewProjects/qflistudio/.trellis/tasks/11-20-studio-git-integration

You are already trellis-implement, Pi C. Implement directly without subagents.
Read common.md, task artifacts, implement.jsonl and core UI/workspace specs first.
Your cwd is D:/MyNewProjects/_wt/studio-git-integration/qfli_studio_core.

Own lib/pages/git_page.dart, lib/pages/git/, lib/store/git_page_controller.dart,
lib/pages/home_page.dart, lib/editor/editor_page.dart,
lib/services/git_clone_service.dart, and tests named git_page*_test.dart,
git_clone*_test.dart, git_navigation*_test.dart. Add a focused Git UI spec if needed.
Do not edit lib/git/ or tracked manifests (other workers own them).

Implement actual local Git UI using the frozen design.md GitBackend contract.
Pi B is creating its files now; do not duplicate them. Group staged/unstaged files,
show real diff/history, offer stage/unstage/stage-all, index-only commit with
explicit identity, branches/checkout, fetch and merge, remote config and push.
Show conflict files and completeMerge after resolution. Include init for empty
projects and repository errors. Retain the existing server-backed cloud flow.
Never show mandatory actions as a permanent disabled placeholder.

Add Home clone entry using the backend factory, AppPaths, ProjectStore registration
and operation-owned cleanup. Offer masked operation-scoped HTTPS credentials.
Do not reuse Studio auth token or persist Git PATs. Native fetch+merge is explicit,
desktop pull --rebase remains clear. All errors and busy state must resolve safely.

Capture active editor document owner before dialog/await. Reject orphaned owners.
Use primary project only without an open file. Protect dirty buffers before
checkout/merge/pull. Refresh clean buffers/tree after disk changes. Do not change
workspace membership, offline-only product entry policy, remote UI or thinking UI.

Implement mounted/generation guards, cancel/dispose, narrow/mobile layouts and
scrollable keyboard-safe dialogs. Write meaningful UI/navigation/clone fixtures
for cloud execution only. NO LOCAL TESTS/BUILDS. Read process/network/ownership
specs where relevant, and use exact interfaces rather than assumptions.

Start reports/pi-c-ui.md early and update with actual file edits. Finish with
implemented user paths, static checks and cloud acceptance cases.
