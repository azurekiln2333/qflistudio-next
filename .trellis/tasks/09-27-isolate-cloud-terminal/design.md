# Design

## Trust Boundaries

App -> authenticated QFLI API -> loopback or certificate-validated HTTPS executor -> rootless Docker + gVisor session. The API holds only an internal execution secret and no Docker socket/CLI permission. The dedicated executor has no business credentials. User input never selects Docker options, image, mount, runtime, shell binary, uid, cwd or container name.

## Session Contract

Keep `/api/terminal/exec` input `{command}` and output `{stdout,stderr,exitCode,cwd}`. `GET /api/terminal/pwd` projects fixed `/workspace` without executing. Add `DELETE /api/terminal/session` for authenticated reset. Internal endpoints use the business-authorized string user ID and a distinct secret; no App token enters the executor.

Default budgets: 8 total sessions, 4 executing commands, 1 command per user, 0.5 CPU, 256 MiB RAM, no swap, 64 PIDs, workspace tmpfs 64 MiB, temporary tmpfs 32 MiB, 100 KiB combined output, 15 seconds command time, 10 minutes idle and 30 minutes absolute session lifetime. Creating/deleting/failed-cleanup containers remain charged. No request queue. HTTP bodies and management command output/time are bounded.

Use a trusted immutable Python PID1 supervisor with child reaping and a hard deadline. After each successful command a trusted read-only isolated Python helper kills all non-PID1/non-helper processes; if unable to prove quiescence, remove the container. SIGKILL of PID1 or OOM invalidates the session. Sandbox management uses argument-array Docker CLI calls and a minimal whitelisted environment only.

Required checks: Docker Linux/rootless/cgroup v2/seccomp/runsc; local trusted image without declared volumes resolved to image ID; inspect running sandbox PID and host cgroup v2 files to verify actual CPU quota, memory/swap/PIDs. Failure closes service. Avoid startup check deadlocks and races.

Reserve names/slots/user lock before first await. Every create/start/exec error attempts name-based removal and confirms disappearance. Failed cleanup makes executor unhealthy and keeps the slot; periodic reconciliation retries. Readiness gates all execution. Delete/reset operations cannot race active execution into a replacement container.

## Cloud Boundary

Disable host Git operations until a separate sandbox and controlled egress exist. Preserve ordinary project/files/sync. Resolve validated relative paths with component-wise lstat and reject symlinks, `.git`, empty/traversal/absolute paths. Bound user disk/files/projects; a sandbox cannot mount cloud directories. No automatic copy of legacy terminal directories.

## Deployment

Provide a dedicated executor system account and rootless Docker user service; business remains under another account without Docker permissions. Use a systemd user slice budget covering Docker/runsc/executor overhead. Prefer a dedicated execution VM for public operation. No ordinary-runc fallback, open Docker TCP socket, public executor listener or absolute safety claim.
