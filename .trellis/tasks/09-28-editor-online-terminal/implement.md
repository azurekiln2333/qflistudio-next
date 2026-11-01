# Implementation

1. Planning complete: inspected ownership, runners, isolation and deployment contracts.
2. Completed: backend streaming proxy/runner, bounded admission FIFO, snapshot helper, deployment budgets/docs. Independent idle/reset removal shares the execution slot; expired admitted sessions reuse their slot without deadlock.
3. Completed: bottom terminal modes, typed event decoder, immediate run progress, supported cloud fallback, retained hidden pane and disposal reset, Docker mirror fix.
4. Completed: four Dart files analyze cleanly; seven JS syntax checks and snapshot Python AST pass. Independent review fixed idle-cleanup accounting, expired-slot deadlock, cancelled partial-line state, narrow toolbar actions and HTTPS CA bootstrap. Scoped whitespace checks pass.
5. Completed: frontend/backend terminal specs and deployment docs updated. Deploy App, business service and executor together. Windows has no Docker/gVisor runtime validation; Flutter rendered device layout also remains unverified. No tests run, no remote deployment, no unrelated changes committed.

Deployment packages are regenerated from source/configuration examples only, excluding live env, data, logs and node_modules. The existing worktree has extensive earlier changes, so no commit was made.

## Toolchain Continuation (2026-09-30)

- [x] Recover user authorization and inspect the independent terminal repository.
- [x] Complete Dockerfile sources and SDK environment; add per-language smoke programs.
- [x] Add a regression test for command PATH/compiler environment propagation.
- [x] Implement old-image detection, actual-session verification and host prerequisite preparation.
- [x] Verify fresh Ubuntu 24.04 bootstrap, all toolchains, actual old-image upgrade, repeat installation and reboot.
- [x] Verify fresh Alibaba Cloud Linux 3 / systemd 239 bootstrap and effective account limits; old-image upgrade passed on retry.
- [x] Verify sandbox isolation, HTTP workflows and lifecycle failures in actual Linux containers on both host families.
- [x] Verify actual CPU throttling, tmpfs exhaustion and guest-task-storm termination/recovery on both hosts.
- [x] Synchronize terminal isolation spec, README, runtime evidence and debugging retrospective.
- [x] Finish both hosts' 20-repeat Dart/C++ HTTP checks and fresh AL3 reboot verification.
- [x] Create stage-scoped conventional commits in the independent terminal repository.
- [ ] Accept direct and outer-shell-ignore OOM recovery, plus the actual production ECS kernel.

Validation environment: a separate `qfli-terminal-test` WSL distribution was
imported from Ubuntu's official minimal 24.04 image, SHA-256
`094dc0afc6ded1c3e5ce71f7d0b48d5db922155097bc8fb1ec19db2ebdd17ece`.
It is stored under `.artifacts/terminal-runtime-test/ubuntu`; existing
`qfli-java-build` build processes and the broken default Ubuntu VHDX were not
changed. WSL evidence must be identified as WSL, not as the production ECS kernel.

The AL3 fixtures use distinct runner UIDs 2000 and 3000 because WSL
distributions share the kernel cgroup tree. The fresh AL3 rootfs initially had
no terminal account, Docker, tar, gVisor or SDK. Its final source build used the
Google Docker Hub mirror; signed AL3/Docker packages and official checksummed
gVisor/Node/Dart downloads remained verified.

The Ubuntu final installer, repeat install and explicit WSL terminate/relaunch
passed. Repeat installation preserved both service PIDs and start timestamps.
All ten compiler/runtime checks used normal Sessions, including Python venv,
Rust/Cargo offline builds and Dart native compilation. HTTP tests cover auth,
malformed requests, 20 C++ builds, capacity, UTF-8 streaming, disconnects, active
reset and separate snapshot directories. Both hosts passed actual helper
protection, injected helper death/deletion failure and orphan reconciliation.
The HTTP suite now also repeats Dart 20 times.

The AL3 legacy image and executor were actually active before upgrade. One
attempt failed after Dart with sandbox_not_quiescent and kept the executor
disabled; rerun passed all ten languages and limit/isolation checks. A direct
run of 20 Dart compilations/cleanups did not reproduce the failure, with account
memory around 232-238 MiB and no high/max/OOM events. Its cause remains
unconfirmed. The direct-run helper was updated while executing and exited with
a shell parsing error after all iterations; subsequent tests use a frozen
helper, and script exit status is verified separately.
The final HTTP suites on both hosts completed with exit 0, including 20 C++
and 20 Dart compilations, UTF-8 streaming, disconnect, active reset and snapshots.
The fresh AL3 terminate/relaunch check also passed with linger, both enabled
services, authenticated health, no service restarts and the fixed cgroup limits.

Memory-pressure acceptance remains incomplete: AL3 memory.events.high rose to
10090, while oom/oom_kill stayed zero. Docker removal timed out,
container_cleanup_pending retained one charged sandbox and health returned
503. Reboot recovered and removed the orphan. This must not be reported as
successful OOM enforcement/recovery; the outer-shell-ignore case was not
reached. No production deployment or public-deployment recommendation is made.

Stage commits: `7b6fecb` completes toolchains and verified Linux bootstrap;
`b01aebc` adds HTTP, lifecycle and resource acceptance scripts. The independent
terminal worktree is clean. Parent worktree changes were not staged or committed.
The final four unit tests passed sequentially with a 64 MiB Node old-space and
1 MiB semi-space after Windows ran short of system commit memory. All three
temporary terminal-test WSL distributions are stopped; qfli-java-build remains
running. This task remains in progress because deployment acceptance and the
earlier App rendered-layout checks are incomplete.

## Upgrade Preflight Repair (2026-10-01)

- [x] Trace the production tar errors to the source-copy ordering after executor disable.
- [x] Add full manifest validation, destination type/ownership/permission checks and archive staging before stopping the executor.
- [x] Preserve overwrite behavior for managed source/tests/docs and keep runner credentials/business data outside the manifest.
- [x] Add an isolated-host regression for blocked upgrades, overwrite and idempotence; synchronize README and terminal spec.
- [x] Run the actual AL3 fixture regression and record service state preservation.
- [x] Commit the scoped repair and rebuild the deployment archive.

The production path ownership is inferred from the tar errors, not remotely
verified. Root-owned writable directories also fail tar metadata changes, so
writability alone is not sufficient. The installer reports the blocked path;
administrators repair ownership explicitly without recursive symlink following.
Production credentials and filesystem state are not read by this local work.

Regression completed with exit 0 on the fresh AL3 fixture (runner UID 3000,
Docker 26.1.3). Six rejection cases retained both services' PIDs, start times,
active/enabled states and runner env. Successful upgrade overwrote stale README
and runtime docs, preserved credentials and passed all ten languages plus
isolation/cleanup/reset/output/deadline checks. Repeated installation did not
restart either service. Four existing unit tests and both Bash syntax checks
also passed. An initial concurrent WSL launch had a Wsl/Service/0x80072746
connection failure; the sequential launch and complete regression passed.

Committed only terminal README/bootstrap/runtime evidence/regression files as
`cb12997 fix(deployment): preflight release overwrite before stopping executor`.
The independent terminal worktree is clean. Rebuilt
`.artifacts/qfli-terminal-deploy.tar.gz` (52,842 bytes); checked its four changed
files match source and it excludes live env, node_modules and Git metadata.
Stopped the AL3 clean test distribution used for this repair. Parent changes
remain unstaged and the broader production acceptance task stays in progress.
