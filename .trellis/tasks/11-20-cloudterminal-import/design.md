# Design

## Ownership

Use two fresh sibling target worktrees:

- Core: D:/MyNewProjects/_wt/cloudterminal-import/work/qfli_studio_core, branch remote/cloudterminal-core, base b7f3d40.
- App: D:/MyNewProjects/_wt/cloudterminal-import/work/qflistudio, branch remote/cloudterminal-app, base e018db9.
- Source copy: D:/MyNewProjects/_wt/cloudterminal-import/source/cloudterminal.
- Reports: this task's reports directory.

Do not edit the main app/core checkout or any existing thinking/Git worktree. The app's uncommitted signing and platform settings are not part of this baseline. Integration must later apply only this task's reviewed changes to the active checkout.

## Module boundary

Create lib/remote_control in the shared core. Preserve source layers as models, transport, state, widgets, and pages. Expose one RemoteComputerPage and a narrow navigation entry. Keep module-private types out of unrelated editor and Agent code.

The source TerminalPane is a remote PTY viewport. The host TerminalPane is a local/cloud execution owner. Rename the migrated widget to RemoteTerminalPane. Do not feed PTY bytes through ShellBackend.execute or sendLine, which have line-oriented semantics.

Use a host adapter for theme and lifecycle. Source HomeScreen can become an internal remote dashboard, but source main.dart, its application root, and a competing global Appearance controller must not become a second app shell. Reuse the host typography, theme, routing, and compact-screen conventions.

## Renderer and dependencies

Copy the patched xterm package into core/vendor/xterm. Preserve its LICENSE and README.cloudterminal.md. Pin the migrated source revision in a provenance note. Do not replace this fork with an unrelated package version. Resolve the path inside the core so app builds do not depend on the source repository.

Source transport and persistence import dart:io. Keep native behavior behind a platform boundary. Add a browser-safe unsupported entry if host imports require it. Do not advertise browser support.

## Connection and event contract

RemoteController owns one paired connection, requests, IDs, timers and subscriptions. Keep SessionView, HerdrController and CodexThreadView semantics. Relay reachability and desktop agent availability are distinct states.

Preserve the source wire contract, including request IDs, timeouts, reconnect/resubscribe, sequence ordering, replay reset, raw terminal input, geometry and bounded output. Disconnect must settle pending requests. Duplicate replay events must not duplicate rendered output.

Route Claude permission and question replies, Codex approvals, and destructive remote actions through explicit user controls. Do not grant permissions automatically during reconnect or migration. Connection configuration is independent of Studio's API/AI endpoint and login state.

## Persistence and lifecycle

Use a new private file such as qfli_remote_control.json. Do not read cloudterminal.json automatically or search the source machine for live credentials. Keep writes atomic and ordered. Preserve plaintext-versus-encrypted truth in documentation. No secret belongs in debug output or project exports.

The module owner initializes the connection only after the entry is used. It observes app resume and performs reconnect. Its final disposal closes sockets, timers, subscriptions and child controllers once. Switching module tabs should preserve active sessions, while a deliberate exit has a documented cleanup path.

## Companion ownership

Place the desktop Node agent under app/companion/remote_agent. Copy only tracked source, package manifests, protocol fixtures and required launch assets from the captured source. Preserve the existing agent/relay protocol. Correct launcher and sidecar paths to the new layout.

Inspect apps/cloudterminal_windows before porting its launcher. Preserve companion-specific functionality that is not already supplied by Studio's remote UI. Avoid shipping a second copy of the remote client UI merely to retain the old app shell. Record a capability map with retained/replaced/deferred status and concrete destinations.

The public cloudterminal-relay-server remains external. The isolated QFLI terminal service remains external. Do not merge either service into the business server.

## Active work boundaries

- Thinking-stream: do not edit ai_service.dart, api_client.dart AI methods, vibe_coding_controller.dart, chat_transcript.dart, or shared AI settings for this task.
- Git: do not add qfli_git dependency or implement GitBackend here. Remote commands execute on the paired desktop. Mobile local Git remains a separate feature.
- Host navigation: inspect StudioProfile, product feature gates, main_workspace_page.dart and main.dart. Prefer a small route/entry change. Do not expose new online features in offline language products by accident.
- Existing local/cloud terminal remains governed by editor-terminal.md and process-lifecycle.md.

## Source protection

research/source-baseline.json records source HEAD, status, index hash, and 1029 tracked content hashes. The captured copy contains 264 allowlisted files and excludes credentials, signing material and Git metadata. Workers use the copy. Verify the live source against the baseline using read-only commands before final acceptance. If an external actor changes it, report the delta and do not restore it.

## Rollback

All implementation stays on new remote/cloudterminal-* branches. Reverting the host entry disconnects this feature without changing existing terminals. Do not delete source files or rewrite shared history. Preserve third-party notices and record missing top-level source license information without inventing a license.

## Additional compatibility details

StudioProfile.toolsTabBuilder is an existing host extension point. Prefer the main product feature page for the new entry. Keep offline language products unchanged. The source supports one paired computer, not account-based multi-device management. Pairing is manual input or pasted links, not a camera-scanner feature.

Source agent identity defaults to ~/.cloudterminal/agent.json and supports CLOUDTERMINAL_HOME. Preserve explicit existing identity use, but do not auto-copy or overwrite it. Never start a live agent during implementation. Launchers and Windows sidecar lookup must work from the migrated companion location and must not rely on the source checkout.

Closing the phone view must release local subscriptions without killing desktop sessions. Reconnect must not retry uncertain keyboard input. Guard Herdr responses by the selected pane identity so old reads cannot update a newly selected pane.
