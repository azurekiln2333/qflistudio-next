# Execution plan

## Dispatch contract

The user explicitly authorized Pi implementation after task creation. One new Pi owns the migration worktrees sequentially to avoid competing edits to shared controllers and navigation. An independent Pi review follows the implementation report. Existing Herdr workers and their tasks are not repurposed.

This process has no HERDR_ENV marker. Use a fresh Pi CLI session outside Herdr. Do not fake the marker or control the user's focused panes. The installed Trellis channel adapter accepts only Claude/Codex, so dispatch Pi directly and retain its JSONL log, session path, PID and exit status in this task.

## Phase 0: prepared by dispatcher

- [x] Audit both workspaces' Claude, Codex and Pi sessions.
- [x] Capture source state and an allowlisted external source copy.
- [x] Create isolated app/core worktrees with pinned base commits.
- [x] Write PRD, design, execution plan and spec manifests.
- [x] Activate this task and launch the named Pi session.

## Phase 1: boundary and protocol

1. Read implement.jsonl, then PRD/design, then the referenced specs.
2. Apply trellis-before-dev. Record change boundary in reports/pi-plan.md.
3. Inventory every current source feature and its destination. Include companion setup and the Windows launcher.
4. Add the remote_control module, namespaced persistence and platform boundary.
5. Preserve paired transport, request handling, replay and lifecycle behavior.

## Phase 2: four user flows

1. Port PTY and its patched renderer without line-oriented conversion.
2. Port Herdr list, terminal, input and control flows.
3. Port Claude structured events, permission decisions and questions.
4. Port Codex threads, history, stream and approval flows.
5. Adapt pages to host theme and navigation. Keep only one app root.

## Phase 3: companion and host

1. Copy and adapt the desktop agent under companion/remote_agent.
2. Preserve required Windows companion behavior with corrected paths.
3. Add one host remote-computer entry with existing product gates.
4. Keep current local/cloud execution, Git ownership and AI ownership intact.
5. Add usage and provenance documentation with no live credentials.

## Phase 4: verification preparation

1. Port relevant fixtures and meaningful regression tests.
2. Add focused cloud CI checks for the module and companion.
3. Run only permitted local static checks and git diff --check.
4. Do not run local tests, temporary probes, builds, emulators, VMs, WSL, Docker VMs, adb or hdc.
5. Record any missing SDK/dependency as a check limitation. Do not install into the source workspace.
6. Write reports/pi-implementation.md with touched paths and an AC evidence table.
7. Write reports/pi-implementation.done only after the report is complete. Never write a green/accepted marker for unrun CI or device checks.

## Phase 5: independent review and integration

A separate review pass checks protocol parity, resource cleanup, secret handling, feature parity, third-party notices, host navigation, and source integrity. Resolve defects on these branches. The coordinator owns commits, any branch push needed for CI, conflict review and final integration. Do not push main, tag a release, or deploy as part of worker implementation.

Cloud CI and target-device acceptance remain visible gates. Device checks require a later explicitly permitted target session. If those gates are unavailable, leave the task in_progress with code ready and the missing evidence listed.

## Worker write allowlist

- D:/MyNewProjects/_wt/cloudterminal-import/work/qfli_studio_core
- D:/MyNewProjects/_wt/cloudterminal-import/work/qflistudio
- This task's reports directory

Workers may read the captured source copy and task/spec documents. They must not write the copy, main checkouts, original source, existing worktrees, user credentials or global configuration. No git reset/restore/clean/stash, branch switching, force push, or mass staging. Do not commit or push from the worker.
