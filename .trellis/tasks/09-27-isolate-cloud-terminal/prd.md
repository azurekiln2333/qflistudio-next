# Public Cloud Terminal Isolation

The user authorizes implementation and multiple agents. Terminal files are ephemeral session storage; cloud projects remain independently persistent. Public users may run arbitrary malicious code, so isolation must fail closed.

## Acceptance

- Business API never executes user shell/Git commands on its host or gains Docker access.
- Separate executor receives authenticated internal requests and has no database, OAuth or QFLI JWT credentials.
- Linux, dedicated non-root executor account, rootless Docker, gVisor runsc, cgroup v2 and effective resource controls are required; unavailable controls reject execution.
- Each user has one bounded session and one running command. Preserve workspace during session life only.
- No host bind mounts/volumes/sockets, shared PID/network namespaces, privileged containers or inherited business environment.
- Read-only rootfs, unprivileged container user, dropped capabilities, no-new-privileges, default seccomp, no network.
- CPU/memory/PIDs/tmpfs/output/time/session/concurrency limits; clean all background descendants after every command.
- Timeout, output overflow, disconnect, explicit reset, session expiry and service shutdown remove the whole session. Failed removal retains capacity and blocks new execution until recovered.
- Reconcile owned orphan containers after startup and periodically. Independent in-container hard deadline bounds leftovers after runner failure.
- Stop unsafe host Git endpoints, block cloud symlink/path escapes and protect cloud disk/file/project capacity.
- Keep public API domain and authentication; add reset without exposing runner credentials or host paths to App.
- Supply separate deployment/configuration documents and immutable sandbox image build recipe.

## Evidence Limits

No Docker engine is available in the current Windows workspace. Do not claim runtime isolation proven from syntax checks. Existing developer instructions prohibit adding/running tests without a user request. Perform allowed static checks and document the required Linux deployment validation. Existing database/cloud directory migration conflict is separate and must not be hidden or destructively bypassed.
