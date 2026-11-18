# Public Terminal Isolation

## 1. Scope / Trigger

Public users may submit arbitrary shell/code through the terminal. The business
API must never execute those commands or cloud Git on its host. Session files
are ephemeral and cloud projects remain separate persistent business storage.
Implementation owners are `azurekiln-qfli-server/src/terminal-client.js`, its
terminal routes, and the separate `azurekiln-qfli-terminal` package.

## 2. Signatures

- Public `POST /api/terminal/exec`, body `{command:string,files?:[{path,content}]}`.
- Public `POST /api/terminal/exec/stream`, same body, authenticated NDJSON events.
- Public `GET /api/terminal/pwd` returns fixed workspace metadata without creating a session.
- Public `DELETE /api/terminal/session` resets the authenticated user's session.
- Internal `POST /v1/exec`, body `{userId:string,command:string,files?:[{path,content}]}`.
- Internal `POST /v1/exec/stream`, same body, protected NDJSON events.
- Internal `DELETE /v1/session`, body `{userId:string}`.
- Internal `GET /health` is protected by the same internal bearer secret.
- Supported-host bootstrap command: `bash deployment/bootstrap.sh [--source-dir PATH] [--business-env PATH] [--port PORT] [--registry-mirror HTTPS_ORIGIN] [--sandbox-image IMAGE] [--executor-image IMAGE] [--watchtower-image IMAGE] [--no-auto-update|--auto-update]` from a checkout. The script also discovers its adjacent checkout when invoked from elsewhere.
- Runtime verification command: `docker compose run --rm --no-deps --entrypoint node executor deployment/verify-runtime.mjs`, as the dedicated runner, only while the executor is stopped.
- Supervisor command: `/usr/bin/python3 -I /usr/local/lib/qfli/init.py`.
- Initial readiness command: `/usr/bin/python3 -I /usr/local/lib/qfli/ready.py`.
- Cleanup command: `/usr/bin/python3 -I /usr/local/lib/qfli/cleanup.py`.
- Snapshot command: `/usr/bin/python3 -I /usr/local/lib/qfli/snapshot.py`, bounded Docker stdin.

## 3. Contracts

The App supplies its normal QFLI authentication. The business API authorizes the
user and passes a server-selected local `user_<32 hexadecimal digits>` ID to the
executor, with an independent `Authorization: Bearer <internal-secret>` header.
The executor must not receive App tokens, MySQL credentials, OAuth secrets or
the business environment. User input never selects Docker parameters, runtime,
image, uid, cwd, mounts or container name.

Execution results are `{stdout:string,stderr:string,exitCode:integer,cwd:'/workspace'}`.
Output is bounded at 100 KiB combined. Commands are limited to 2000 characters.
Management operations and HTTP bodies also have independent bounds.

NDJSON events are `{type:'progress',stage,position?}` with stages `queued`,
`initializing`, `ready`, `uploading`, `running`, `cleaning`; `queued` positions
are integers from 1 to 8. Output events are `{type:'stdout'|'stderr',text}`;
one final event is `{type:'result',...result}` or `{type:'error',message,status}`.
Business maps executor error codes to approved messages and validates event
fields and final output against streamed output before forwarding the result.
Do not replay final output in streaming consumers. Stream UTF-8 with a decoder
that retains partial multibyte sequences. Encoded stream is capped at 2 MiB,
each line at 700 KiB. Pause Docker output/read the upstream incrementally while
waiting for downstream drain, capped at five seconds; cancellation propagates
through business fetch to the executor and destroys an admitted sandbox.
Set `Cache-Control:no-store,no-transform`, `X-Accel-Buffering:no`, and disable
proxy buffering/cache/compression. Pre-stream failures remain normal HTTP JSON.

Both entry points reject unexpected fields and enforce a 384 KiB request body
before decoding. Optional `files` is nonempty, at most 64 files and 256 KiB total
decoded canonical base64; paths must be valid UTF-8 relative POSIX paths, at
most 512 bytes/16 segments/255 bytes per segment, with no absolute prefix,
empty/dot/dot-dot segments, backslashes, controls, duplicates or file-directory
collisions. Business reserves internal user-ID body overhead. The immutable
snapshot helper revalidates its input under `65532:65534` and nondumpable mode,
creates `/workspace/.qfli-run-<32 random hex>` and uses directory descriptors,
exclusive creation and `O_NOFOLLOW`. No host paths or mounts enter this flow.
With files supplied, shell cwd is the fresh subdirectory; result cwd retains
fixed workspace-root metadata `/workspace`. Snapshots remain session files
bounded by tmpfs and are lost when the session is destroyed.

Business environment: `QFLI_TERMINAL_URL` (loopback HTTP or certificate-validated
internal HTTPS), `QFLI_TERMINAL_SECRET`. Runner environment: a separate file with
`QFLI_TERMINAL_SECRET`, `QFLI_TERMINAL_IMAGE`; Docker child environment contains
only fixed `PATH`, dedicated account `HOME`, local `DOCKER_HOST` and
`XDG_RUNTIME_DIR`. No shell inherits `process.env`.

The image installer targets Ubuntu 24.04 x86_64 or Alibaba Cloud Linux 3,
systemd >=239 and active cgroup v2. Check OS, architecture, systemd and cgroup
mode before downloading or changing the host. Production prepares rootless
Docker/runsc and pulls the prebuilt executor and sandbox images. It never builds
service sources or toolchains and does not install host Node for the new stack.
Builds belong in the root `.cnb.yml` using the three explicit nested contexts.
Standalone service repositories may also use their own `.cnb.yml` files.

Keep the dedicated `qfli-runner` account, subordinate UID/GID ranges, signed
Docker packages, gVisor checksums and actual account limits. The AL3 Docker
repository uses explicit CentOS 8 URLs with signature checking. Preserve
`runsc` arguments `--network=none --ignore-cgroups`; do not add gVisor's
incompatible `--rootless=true` OCI argument or fall back to runc. Registry
mirrors apply only to the dedicated rootless engine and retain TLS validation.

Source selection is explicit path, complete current checkout, complete checkout
adjacent to the script, then complete installed project. Root stages only
allowlisted release files into a temporary readable directory for the runner.
Checkouts under /root or /www/wwwroot do not need permission changes or manual
copies. Keep the private managed runtime under the runner home.

Default images use the standalone CNB repository. Preserve valid installed
registry-qualified overrides; never inherit bare legacy local image names as
implicit pull targets. Validate inherited references before writing env files.
The bootstrap --port option sets QFLI_TERMINAL_HOST_PORT in 1024..65535. An
omitted option preserves the installed value, otherwise defaults to 3101.
Compose binds 127.0.0.1:<host port>:3101; the internal health port stays 3101.

The dedicated user@UID.service has a persistent Delegate=cpu io memory pids
drop-in. Include cpuset only on systemd >=244. Check actual cgroup.controllers
and repair the dedicated manager before starting rootless containers. Keep
resource limits and refuse unavailable controllers; never switch to rootful
Docker or remove limits to make installation succeed.

Watchtower belongs to the auto-update Compose profile. The installer sets
COMPOSE_PROFILES=auto-update only after its pull succeeds. An optional updater
download failure disables updates explicitly and allows the executor install
to proceed. --no-auto-update persists that choice; --auto-update retries it.
Both the unit and installer must read the same private environment/profile.

The new Compose stack runs its executor as container UID 0 mapped to the
non-root runner's host UID. Check `/proc/self/uid_map`, the dedicated local
socket, host PID namespace, host cgroup namespace and read-only `/host/cgroup`
mount. Native non-container execution still requires the dedicated non-root
account. The business container never receives either Docker socket.

Before engine reads or orphan reconciliation, `Sessions.initialize()` acquires
`executor.lock` in the shared runtime directory. Keep a regular nonsymlink file
open and pass its descriptor to `flock -n 3`. Node retains that same open file
description after the helper exits. Close the descriptor only after shutdown.
Do not unlink the lock file or use a per-container port/PID as the fence.
This contract also applies to one-shot runtime verification containers.

The installer reads the existing internal secret without logging it. It stores
only runner configuration in the private stack `.env`. Capture old executor
and sandbox immutable image IDs before pulling mutable tags. On a failed
upgrade, restore those IDs and the previous Compose/environment. Restoring a
`latest` tag alone does not restore the old image. Write private files atomically
as their owner, reject destination links and preserve the old service until
preflight succeeds. A legacy host-service migration retains its rollback path.

One-shot language/isolation verification must finish before enabling the new
stack. Health must then pass. An unchanged release/configuration can return
without restarting Docker or active sandboxes. Linger and the runner's Compose
user service provide reboot startup. The business and executor Compose stacks
have independent restart policies, limits and Watchtower scopes (`qfli-server`
and `qfli-terminal`) with no readiness dependency between them. Automatic
executor replacement interrupts active sessions. Drain that node before a
controlled update. Toolchain-image replacement requires a pull and runtime
verification; do not claim Watchtower hot-migrates active sessions.

Docker must be Linux/rootless under the dedicated `qfli-runner` account with
cgroup v2, default seccomp and gVisor `runsc`. The trusted local image has label
`io.qfli.terminal.image=1`, `io.qfli.terminal.toolchains=3`, supervisor user `65533:65533`, the exact supervisor entrypoint,
no CMD arguments and no volumes. Resolve its immutable image ID at startup.
Validate `/sys/fs/cgroup` with `statfs` (`CGROUP2_SUPER_MAGIC=0x63677270`),
and require the account slice to share that filesystem root's owner, never
the runner's owner. Ubuntu 24.04 user-unit `ProtectSystem=strict` creates a
user namespace mapping only the runner UID; host root appears as overflow
UID 65534. Requiring literal UID 0 rejects the protected service even while
the same checks pass from an installer shell. Preserve the unit protections.
The rootfs is read-only, capabilities are dropped, no-new-privileges is enabled,
and networking is disabled. No host bind mounts, devices, shared namespaces,
privileged mode or Docker socket mounts are allowed.

Default hard budgets: 1 session, 1 admitted operation, one command/session per
user; account CPU 1 core, RAM 1 GiB, zero swap and 1024 host tasks. The sandbox
has 64 guest tasks, 256 MiB `/workspace`, 64 MiB `/tmp`, a 60-second command,
2-minute idle timeout and 30-minute absolute lease. FIFO queue
has at most 8 requests and a 20-second wait, before session reservation. One
user may have one queued or admitted request. Startup, upload and command
cleanup retain the operation slot; independent reset/expiry/orphan removals
also acquire the operation slot. Waiting users reserve no container. Full
session capacity rejects new users even if sessions are idle. Disconnect,
reset, shutdown and timeout remove waiting items and publish changed positions.
Queueing only absorbs bursts; it does not increase CPU/memory throughput.
The workspace
is `nosuid,nodev,exec`; Docker defaults tmpfs to noexec unless exec is explicit.
Temporary storage also uses `noexec`. Compiler TMPDIR is
`/workspace/.tmp`, created by the readiness helper as the command user.
`src/sandbox.js` owns both mount flags and supplies the same SDK PATH
and compiler environment to Docker create and exec; do not overwrite exec PATH
with the old system-only path. Java's default heap is 256 MiB, with one logical
processor, a 64 MiB code cache and 128 MiB metaspace ceiling. Go/Cargo default to
one build job. The image supplies Java 21, Lua, Node 24.15.0 (also running
TypeScript via `--experimental-transform-types`), Python, PHP, Go, Rust,
Dart 3.13.5, Ruby, bash and C/C++; every entry in `src/sandbox.js` `languages`
has a `smoke-languages.sh` case. Kotlin and C# are intentionally absent for
the 1 GiB account budget. Node/Dart downloads, including backup sources, must
match their pinned official SHA-256 values. External dependency downloads remain
disabled. The supervisor reaps at
most 64 children per tick and checks a monotonic deadline during reaping. Do
not use an unbounded SIGCHLD handler: fork/exit storms must not postpone expiry.
Set and inspect guest `nproc=64:64` as well as host `pids.max`; gVisor virtual
processes do not correspond one-to-one with host threads. PID 1 additionally
scans `/proc/<pid>/task` each tick and exits if it sees more than 64 tasks.
This polling guard cannot promise zero transient excess, and guest nproc
behavior requires evidence from the deployed gVisor version.

PID 1 uses the distinct non-root identity `65533:65533`, with no capabilities.
gVisor release-20260921.0 permits same-UID SIGSTOP against PID 1; dumpability
does not control signal permissions. User commands retain `65532:65532`.
PID 1 calls libc `prctl(PR_SET_DUMPABLE,0)` and verifies `PR_GET_DUMPABLE==0`
before publishing `/tmp/.qfli-init-ready`, exact content `ready\n`, owned by
`65533:65533`, mode 0644 in sticky `/tmp`. Before admitting the first user command the immutable `ready.py`
polls for at most two seconds, requires a regular nonsymlink marker with that
uid/gid and exact content, creates the compiler temp directory and emits
`{"ready":true}` with exit 0. The marker remains protected by its owner and
sticky directory; it is never a later-session readiness signal.
This marker is never trusted after a user has run. Failure closes the session.

Cleanup is launched using Docker exec `--user 65532:65534`, while user commands
remain `65532:65532`. Distinct gid protects cleanup's bootstrap from same-uid
ptrace/proc mem/process_vm access; user code has no ability to set that gid.
Cleanup also enables and verifies nondumpable mode before its trusted logic.
Keep uid 65532 so UID-based signal permission can kill user processes.

The trusted cleanup helper excludes only PID 1 and itself, SIGKILLs every other
visible PID, repeats under a two-second bound and requires two empty scans.
Success is exit code 0 with JSON `{"quiescent":true}`. Missing, killed, timed out,
malformed or nonzero helper responses must destroy the entire session.

Reservations, deleting sessions and failed-cleanup tombstones consume capacity.
Unconfirmed Docker creation may complete after a CLI timeout; retain its
reservation until executor and Docker restart/reconciliation establishes a
clean inventory. Creation reservations are persisted before Docker create under
`/run/user/<uid>/qfli-terminal-pending/`; pending markers block executor startup.
Operator recovery stops the executor, restarts its rootless Docker, confirms
owned orphan deletion, then clears its dedicated pending markers. Never free
capacity based only on a timeout or failed inspect or automatically erase these
markers on a process restart.

## 4. Validation & Error Matrix

| Condition | Required result |
| --- | --- |
| Missing isolation/runtime/image prerequisites | Executor unavailable; no host/runc fallback |
| Installer prerequisites, secret, or running unit differ | Stop with an explicit error; preserve the active service and its configuration |
| Host cgroup files show absent/ineffective limits | Reject the sandbox and remove it |
| Invalid internal secret | 401; no Docker work |
| Caller-supplied Docker options or unexpected JSON fields | 400 |
| User command already active or queued | Reject immediately; one request per user |
| Running operation slot occupied | FIFO wait, at most 8 waiting / 20 seconds |
| Session capacity or queue full | Reject with distinct capacity error; reservations remain charged |
| Queued request disconnected/reset/expired/shutdown | Remove waiting item; update positions; no container created |
| Invalid/oversize project snapshot | Reject before Docker; helper failure destroys admitted session |
| Timeout/output overflow/disconnect/observed OOM/helper failure | Destroy entire session |
| Deletion or creation outcome cannot be confirmed | Retain capacity, mark unhealthy, reconcile |
| Workspace lease expires | Destroy session, independently bounded by PID 1 |
| Business cloud Git request | Disabled until separate controlled execution exists |
| Missing release entry, wrong destination type, ownership/permission failure or destination symlink | Bootstrap fails before disabling/stopping the old executor; runner env stays unchanged |
| Bare legacy sandbox image with omitted image flags | Use the CNB default; do not query Docker Hub for the legacy build |
| Invalid explicit port | Reject before host mutation |
| CPU controller still absent after dedicated manager repair | Stop with the controller diagnostic; retain isolation requirements |
| Optional updater pull fails | Disable updater profile explicitly; continue executor verification |

Inspect fields alone are insufficient proof of CPU/memory/PID limits. Read the
container host PID's cgroup membership and actual `cpu.max`, `memory.max`,
`memory.swap.max`, `pids.max`. Document target Linux runtime evidence separately
from static syntax evidence.

Observe container `State.OOMKilled`, changes in the actual cgroup
`memory.events` counters `oom`/`oom_kill`, and command exit code 137. Observed
OOM or SIGKILL exit destroys the session. Do not promise every gVisor guest OOM
is visible through these signals: a killed child may be hidden by an outer
shell returning 0, and guest OOM may not increment host counters. Memory limits
must remain effective regardless of that observation gap.
In AL3 WSL pressure tests, `memory.high=768M` throttled allocations and Docker
management before a host OOM kill (`high` increased; `oom_kill` stayed zero).
Removal timed out, returned `container_cleanup_pending`, and retained one
owned sandbox; health became 503. This is unavailable but fail-closed, not a
successful OOM/recovery test. Recovery requires stopping the executor,
restarting its dedicated Docker, confirming owned orphan removal, then
restarting the executor. Never drop the retained reservation to restore health.
An AL3 legacy upgrade also once returned `sandbox_not_quiescent` after Dart;
the bootstrap correctly kept the executor disabled, and a rerun passed.
Twenty direct-session Dart compilation/cleanup repetitions did not reproduce
it or increase memory high/max/OOM counters. The cause remains unconfirmed;
retain repeated Dart HTTP acceptance coverage and do not report it as fixed.

## 5. Good / Base / Bad Cases

- Good: users take turns running programs in distinct bounded workspaces; files remain in
  each session after cleanup but background processes do not.
- Base: an empty terminal view returns `/workspace` without creating a container.
- Base: `bash deployment/bootstrap.sh --port 3200` installs from the current checkout and publishes the executor on loopback port 3200.
- Bad: a user starts a fork storm or excessive output; session termination and
  retained failed-cleanup accounting prevent admission from exceeding budgets.
- Bad: Docker becomes unreachable after creation; no new work is accepted until
  inventory and removal are confirmed.

## 6. Tests Required

Bootstrap behavior tests source the ordinary Bash functions and use disposable
filesystem fixtures. Cover omitted flags, source precedence, source staging,
legacy-image rejection, port validation/persistence, versioned delegation,
missing controllers and optional updater failure. Compose CLI rendering must
prove default/custom loopback mappings and profile selection. These checks
do not replace live Linux runtime acceptance.

These are acceptance points for explicitly authorized Linux runtime validation;
do not claim them from `node --check` or Python AST parsing:

- Prove networking, host files, Docker socket and business env are inaccessible.
- Verify namespace PID 1 cannot be SIGSTOPped by its peers and PID 1/helper
  cannot be modified through ptrace, proc mem or process_vm, using the deployed
  gVisor implementation rather than assuming host Yama defaults.
- Read effective cgroups and verify CPU/RAM/swap/PID/tmpfs/overall user slice limits.
- Exercise background descendants, fork/exit storms, PID 1 lease, helper death,
  output overflow, command deadlines, disconnects, reset and OOM.
- For OOM, validate both a directly exhausted command and a child killed by
  memory exhaustion whose outer shell ignores failure and returns 0. Record
  guest behavior, host counter visibility and container OOM state. Observed OOM
  must reset the session; unobservable guest OOM remains an explicit evidence
  limitation and must not be reported as fully covered.
- Prove concurrent first requests reserve one slot per user; failed cleanup
  retains capacity, restart removes owned orphans and cannot delete another
  live executor's sessions.
- Verify FIFO admission, changed queue positions, bounded wait, per-user
  exclusivity and removal on reset/disconnect/shutdown. Creating/uploading/
  cleaning must retain operation admission; queued users allocate no sandbox.
- Verify progress and output across the App/business/executor/proxy, including
  UTF-8 split across chunks, slow receivers, errors and incomplete streams.
- Verify snapshot bounds and traversal/symlink rejection against prior session
  files, fresh per-run cwd, quiescence before upload and no host file access.
- Confirm terminal reset removes only session files, with cloud data unchanged.
- On the target Linux host, run the bootstrap, confirm authenticated `/health`
  returns 200, reboot, and confirm linger starts both user services without
  running the installer again. Repeat the installer while the service is active
  and confirm it reports health without restarting Docker or the executor.
- Run `QFLI_TERMINAL_TEST_HOST=1 bash test/bootstrap-upgrade.sh SOURCE_DIR BUSINESS_ENV`
  as root on a disposable installed host. Root-owned writable directories,
  nested root-owned/read-only files, destination symlinks and missing docs/test
  sources must fail while both services retain their PIDs, start timestamps,
  active/enabled states and runner credentials. Repair the fixture, verify
  managed files are overwritten, and repeat without service restarts.

## 7. Wrong vs Correct

Wrong:

```js
spawn('sh', ['-c', command], { cwd: userDirectory, env: process.env });
```

Correct: the business process sends an authenticated bounded internal request;
the separate executor uses argument-array Docker CLI calls under a dedicated
rootless account, validates actual limits, and executes shell only in its owned
gVisor session. An isolated cwd is not a sandbox.

The deployment user slice caps the entire execution account (daemon, gVisor,
Node and sessions): CPUQuota 100%, MemoryHigh 768 MiB, MemoryMax 1 GiB, swap 0,
TasksMax 1024. The single sandbox and runtime/daemon/Node overhead share this
budget and can still cause account OOM. A 2 GiB
co-located machine has roughly 1 GiB left for OS/business/database/control panel;
this is a ceiling, not a guarantee that large compilation or JVM work fits.
Business
accounts have no Docker permissions. Because the former public terminal exposed
business environment variables, rollout requires shutting it down, inspecting
old host processes/persistence and rotating previously exposed credentials.
Code changes do not revoke leaked secrets or remove preexisting compromises.

One executor instance owns one dedicated rootless Docker account/engine; no PM2
cluster or separate network namespace replicas may share that engine. Cloud
storage also needs a separate bounded real filesystem mount: per-user quotas
and reserve-space checks do not prevent disk I/O or capacity exhaustion across
many accounts. Keep DB/logs/OS storage separate and limit authenticated upload
and scan traffic at the business entry point.
