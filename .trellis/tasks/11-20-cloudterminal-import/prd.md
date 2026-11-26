# CloudTerminal integration

## Goal

Bring CloudTerminal's remote computer features into QFLIStudio through the shared core. Keep the source workspace unchanged. Deliver usable remote sessions, not a second application embedded inside Studio.

## Authorization

On 2026-11-20 the user requested session audits, a new migration task, careful planning, and no changes to D:/MyNewProjects/cloudterminal. The user then explicitly instructed: “你trellis创建完就派下去给pi做哈”. This authorizes Pi implementation after these task artifacts are ready. Do not ask again for task creation or implementation approval. Deployment and public release are separate from this local migration.

## Confirmed background

- Source HEAD: 49b2aac781858929a19307faeb808b83f8154410.
- The source has one dirty planning document. Its application code is clean.
- Source features include paired connections, remote PTY sessions, Herdr control, Claude sessions, and Codex app-server sessions.
- The public relay is already a separate project. The source server directory contains the desktop Node agent and a local relay.
- Studio resolves its active core to rework/integration at b7f3d40. Its editor terminal runs local commands and authenticated cloud sandbox commands.
- The Git plugin is published, but Studio has not adopted its API. The thinking-stream task has four green branches but awaits integration.

## Requirements

R1. Source protection. Treat the original cloudterminal directory and its Git metadata as read-only. Work from the captured source copy. Never run installers, builds, tests, formatters, worktree commands, or runtime services in the original source.

R2. Product entry. Add a clear “远程电脑” entry in Studio's existing navigation. Use the shared core for behavior. Keep the host application theme, navigation, and lifecycle. Avoid a nested MaterialApp.

R3. Connections. Preserve manual pairing, supported pairing URI parsing, reconnect, agent-offline status, request timeouts, and unpairing. Persist settings in a new app-private namespace. Do not import existing source credentials or reuse Studio login tokens.

R4. Remote terminal. Preserve PTY input bytes, resize, replay, sequence deduplication, output bounds, and reconnect behavior. Keep terminal output separate from line-oriented local and cloud execution.

R5. Herdr. Preserve real workspace, tab, and pane lists, output, terminal controls, input, and truthful empty/error states.

R6. Remote agents. Preserve Claude tool streams, permission decisions, questions and responses. Preserve Codex thread history, streaming, approvals, and supported account/model options. Remote approvals remain explicit user actions.

R7. Companion. Preserve a maintainable copy of the desktop agent, its protocol, and launcher assets required by current clients. Adjust paths for the new location. Keep the existing public relay protocol compatible. Document how to run the companion independently.

R8. Compatibility. Retain all four remote modes on supported native platforms. Gate unsupported browser behavior explicitly. Do not turn desktop remote commands into local mobile shell execution.

R9. Existing product. Keep editor terminals, run actions, Agent chat, Git integration boundaries, authentication, and other products intact. Do not migrate in-flight thinking or Git branches as part of this task.

R10. Verification. Put tests and build checks in cloud CI. Do not run local test suites, temporary test probes, builds, emulators, VMs, WSL, Docker VMs, adb, or hdc. Local static inspection, formatting, targeted analysis, and Chinese lint are allowed. Do not claim device validation from desktop or CI results.

## Acceptance criteria

| ID | Observable result |
| --- | --- |
| AC1 | Original source HEAD, index hash, status and tracked content hashes equal the recorded baseline. |
| AC2 | Studio opens one remote computer entry under its current theme and navigator. |
| AC3 | Pair, reconnect, unpair, authentication failure, and agent-offline states match the source behavior. |
| AC4 | PTY input, resize, replay and cancellation preserve raw terminal semantics. |
| AC5 | Herdr lists and controls operate on actual server data without fabricated sessions. |
| AC6 | Claude permission/question flows and Codex approval/history flows retain their protocol behavior. |
| AC7 | Pairing data uses its own private namespace and never appears in logs, fixtures, exports, or credentials shared with Studio. |
| AC8 | Closing the remote module disposes its resources. Returning from background reconnects safely. |
| AC9 | Local/online editor terminals and existing navigation retain their behavior. |
| AC10 | A clean cloud checkout resolves all migrated dependencies without an absolute local path. |
| AC11 | Companion launch paths and protocol compatibility have reproducible cloud checks. |
| AC12 | The handoff records commit IDs, exact CI results, unverified device cases, and any deferred capability. |

## Outside this task

Public relay deployment, production account/billing changes, GitBackend implementation, mobile Git UI, thinking-stream integration, and automatic main/release pushes. Do not copy signing material, build outputs, caches, archives, credentials, or source repository metadata.

## Completion rule

Code delivery and validation evidence are separate. A Pi report or successful compilation alone is not full acceptance. Mark this task complete only after the acceptance table has evidence. Record a genuine external blocker without fabricating a pass.
