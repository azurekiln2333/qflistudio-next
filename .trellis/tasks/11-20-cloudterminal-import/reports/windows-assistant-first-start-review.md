# Windows assistant first-start release review

Scope: isolated release checkout `D:/MyNewProjects/_wt/release-v5.0.5/qflistudio`.
Owner: remote_review. Ready for root integration. No commit or push performed.

## Fixed release blockers

- A fresh installation without bootstrap or saved relay now starts its LAN relay.
- The pairing URI advertises a non-loopback IPv4 address. A missing LAN address produces an actionable error instead of an unusable phone QR code.
- Removed the sidecar's no-op emitter replacement, which previously detached RelayLink's outbound sink and silently discarded replies to paired phones.
- Saving a remote address persists `connectionMode: remote`; clearing it persists `connectionMode: local` and removes its registration key.
- Snapshots expose the running connection mode. The assistant displays that mode explicitly.
- Typing a relay address enables Save. Settings subscribe to controller updates, including success notices and command errors.
- Mode changes retain the existing restart contract and now visibly ask users to close and reopen the assistant.

## Cloud regressions added

- `companion/remote_agent/scripts/sidecar-smoke.ts`: launches the real sidecar from an empty temporary config/cwd with no bootstrap and no forced local mode, reads IPC state, validates the advertised LAN address, pairs a phone WebSocket, authenticates it, and requires real `info` and `list_sessions` replies.
- The helper uses the executing Node runtime and only production dependencies, so root's packaging gate can execute it from the assembled portable package.
- `companion/remote_agent/test/relay-sidecar.test.ts`: reuses the smoke chain, then verifies remote registration-key configuration and both mode changes across actual process restarts.
- `companion/windows_assistant/test/sidecar_ipc_test.dart`: exercises the fresh default through the real Flutter IPC client, checks mode/address, and allocates a temporary free port instead of a shared fixed port.
- `companion/windows_assistant/test/settings_page_test.dart`: checks typing enables Save, outgoing configuration, live notice display, clearing notices, and error display.

## Static validation performed

- TypeScript `tsc --noEmit`: exit 0 across agent source, scripts, and tests. Dependency declarations were resolved read-only through the original source's existing installation with a temporary compiler config. No dependencies were installed.
- Dart `analyze lib test`: exit 0, no issues. Existing dependency paths were copied into the release checkout's ignored `.dart_tool/package_config.json` and its own package URI was adjusted. The original package configuration was not changed.
- Dart formatter: exit 0 on all changed Dart files.
- Node syntax checks: exit 0 for sidecar, LAN helper, smoke script, and relay-sidecar test.
- `git diff --check`: exit 0.
- No tests, assistant process, or builds ran locally. Runtime results remain pending cloud CI.

## Boundaries and remaining qualification

- The original `D:/MyNewProjects/cloudterminal` checkout was only read.
- Root owns workflow, installer packaging, commits, pushes, tags, and cloud run monitoring.
- Smoke validates the advertised LAN address but connects its test phone over loopback to avoid runner firewall dependencies. A physical phone on the user's LAN remains the final install acceptance check.
- Address selection reuses the existing main agent's first non-internal IPv4 strategy. Machines with several NICs may require selecting a reachable network address via the agent's existing public URL option.
