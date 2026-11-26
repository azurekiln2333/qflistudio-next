# Acceptance evidence

Status: implementation review in progress. The paths below describe the
isolated worktrees recorded in `task.json`. They are not evidence of a released
installer or a successful device session.

| AC | Implementation evidence | Cloud / device evidence still required |
| --- | --- | --- |
| AC1: three desktop systems display a valid code | Core `desktop/desktop_remote_page.dart`; companion `sidecar.ts`; installer staging for Windows/Linux/macOS | Build and launch each installer; generate and expire a real code |
| AC2: copy a phone-readable link | Existing PairingUri contract; desktop QR/link presentation; companion CLI pairing output | Copy each platform link into a real phone and pair |
| AC3: read real Agent sessions | `desktop-discovery.ts`; `tool-streams.ts`; Core companion controller | Discover/open actual Herdr, Claude and Codex histories on each desktop system |
| AC4: account device list and online state | Core account controller/API/models/page; Relay device-list endpoint | QFLI grant exchange against an isolated test stack; verify live agent metadata |
| AC5: account bind and phone connection | Code-only binding endpoint; direct short-code bind; account-token WebSocket hello | New-account flow from unpaired phone through bind to actual session |
| AC6: revoke old tokens and sockets | Relay binding/token transaction; auth-cache and pending-join generations | Execute Relay security suite and inspect actual connection closure |
| AC7: account isolation | Subject from the QFLI live session; active device binding required on Relay | Run two-account denial, owner and revoke-race fixtures |
| AC8: manual pairing and four session types | Existing manual paths and protocol consumers retained | Run existing terminal/Herdr/Claude/Codex suites and companion E2E |
| AC9: no credential disclosure | Hash-only grants; isolated Relay credential store; authenticated attach; redacted diagnostics | Run log-capture tests and inspect cloud artifacts for forbidden fields |
| AC10: checks cover target paths | Dedicated QFLI/Relay verification workflows; Core suite and three-platform companion CI | All cloud checks must execute successfully; real devices remain a separate gate |

## Execution boundary

Only format, static analysis, syntax checks, dependency resolution, documentation
lint and diff checks are permitted locally. Regression tests are written for
cloud CI and remain unexecuted here. No service, migration, build, simulator,
Docker/WSL or adb/hdc command may be used to claim acceptance.

No code has been committed, pushed, deployed or released in this task.
The integration Core ref remains a local branch until the reviewed commits
exist. Release provenance must be rewritten from the actual committed Relay
source and final Core SHA before a release is eligible.
