Active task: D:/MyNewProjects/qflistudio/.trellis/tasks/11-20-studio-git-integration

You are the assigned trellis-implement worker. Implement directly. Do not spawn another worker. This is the next authorized task, replacing the completed thinking task in this pane.

Read the active task prd.md, design.md, implement.md, implement.jsonl and the relevant specs before editing. Planning is already approved and complete. Continue the existing draft, do not restart it.

All product edits MUST stay under D:/MyNewProjects/_wt/studio-git-integration/{qflistudio,qfli_studio_core,qfli_git}. Your terminal cwd is the root checkout, so use explicit absolute paths or explicit workdir. Do not edit the root product checkouts, previous release/thinking worktrees, or D:/MyNewProjects/cloudterminal. Do not change cloudterminal HEAD, index or content.

NO LOCAL TESTS OR BUILDS of any kind, no VM/emulator/WSL/Docker/adb/hdc or app services. Reading, formatting, syntax/static analysis and git diff --check are allowed. Add meaningful tests for GitHub CI, but do not execute them locally. Do not alter test results to hide failures.

No commits, staging, pushes or tags from workers: root coordinates explicit-path commits and the dependency graph. Do not overwrite other workers' owned files. Report cross-owner needs with exact paths/interfaces. Read any owned file before changing it; substantial existing draft work must be preserved and improved.

Desktop uses managed Git CLI and existing credentials. Android/iOS/OHOS use lazy native FFI. Preserve cloud-project server API. Never load native libraries during desktop startup. Git author and PAT are separate; PAT stays in memory, never URLs/arguments/config/logs. Enforce offline policy. Preserve document ownership and dirty buffers. Clone cleanup must only remove a destination proven owned by this operation.

Final output: concrete edited files, remaining blockers, and exact checks actually performed. A successful shell exit or written plan is not implementation completion. Keep working through your assigned review/fixes, not just a status acknowledgement.
