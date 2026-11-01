# Design

- Extend TerminalPane with local/online modes sharing output/input UI and a pane-owned API client. Retain state while hidden; cancel on editor disposal.
- Add authenticated NDJSON POST /api/terminal/exec/stream forwarded to /v1/exec/stream. Request: {command, files?}; files are bounded {path,content} base64 snapshots written only inside the sandbox. Keep JSON /exec compatible.
- Events: {type:'progress',stage,position?}, {type:'stdout'|'stderr',text}, {type:'result',stdout,stderr,exitCode,cwd}, {type:'error',message,status}. Result retains bounded output for legacy calls; streaming App must not replay it.
- Actual phases: queued, initializing, ready, uploading, running, cleaning. Stream Docker output while collecting the existing bounded result; decode events at the App API boundary.
- Admission FIFO before session reservation: 8 pending, 20 seconds max wait, one pending/active request per user. Defaults 1 session and 1 running operation. Full session capacity rejects; failed deletion remains charged.
- Trusted immutable snapshot helper reads bounded Docker stdin and validates normalized relative paths. Copy to a fresh per-run sandbox directory. Limits: 64 files, 256 KiB decoded, 384 KiB HTTP body. No host paths or mounts.
- Use the fixed account slice CPUQuota=100%, MemoryHigh=768M, MemoryMax=1G, swap=0, TasksMax=1024. runsc ignores its own cgroup management on systemd 239; the service verifies the actual account budget and sandbox PID membership. Command deadline is 60 seconds; workspace/tmp are 256/64 MiB. Queue regulates bursts only.
- Dockerfile mirror arg changes Debian deb822 URIs without disabling apt signature verification; use download timeouts and bounded retries.
- Rollback closes online execution or restores the previous isolated executor, never host shell execution.

## Toolchain Continuation

- Debian trixie supplies signed language packages. Node 24.15.0 and Dart 3.13.5
  use fixed official SHA-256 downloads. Image schema remains `image=1`; the new
  toolchain label is `io.qfli.terminal.toolchains=2`, with default tag `:2`.
- `src/sandbox.js` owns command/create environment arguments. Both operations
  include the SDK PATH and executable workspace TMPDIR, with restrained Java,
  Go and Cargo defaults.
- Bootstrap prepares rootless prerequisites and the dedicated account, updates
  the previous image, and runs `deployment/verify-runtime.mjs` before enabling
  the executor. Verification holds the same port lock and uses actual Sessions.
- Each smoke command compiles/runs standard-library code without network. Package
  managers are present, but external dependency downloads remain unavailable.
- The supervisor is `65533:65533`; user commands are `65532:65532`. Runtime
  testing proved that same-UID SIGSTOP can suspend gVisor PID 1 despite
  nondumpable mode. The distinct UID denies signals without adding capabilities.
  The protected readiness marker remains in sticky `/tmp`; readiness creates
  `/workspace/.tmp` as the user before accepting any command.
- A source fingerprint records successful runtime validation. A matching active
  release checks authenticated health without restarting the engine/executor.
