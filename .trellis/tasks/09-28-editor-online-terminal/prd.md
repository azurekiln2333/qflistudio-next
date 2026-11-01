# Editor Online Terminal

## Goal

Use the editor bottom terminal for local and cloud execution, expose startup progress immediately, and bound resource use on the user's 2 CPU / 2 GiB server.

## Requirements

- Preserve editor navigation and local/native runners. Online terminal opens in the existing bottom panel with a local/online selector.
- Initialize the ephemeral sandbox on demand; merely opening the App allocates no sandbox.
- Run expands the panel before saving/probing/initializing. Show real initialization, queue, execution, stdout/stderr and final result events.
- If a local runner cannot run a supported entry, submit a bounded project snapshot to the sandbox. No cloud/host directory mounts.
- Small-host defaults: 1 session, 1 running operation, FIFO queue of 8 requests, bounded wait; one admitted/waiting command per user.
- Maintain isolation, cleanup accounting, authentication and fail-closed behavior.
- Fix prolonged Debian downloads with timeouts/retries and a configurable trusted mirror. Document rebuild commands.

## Acceptance Criteria

- Online menu opens the bottom panel without pushing a page.
- Run shows progress immediately and prevents repeated submissions; hiding a panel retains execution until closure/disposal.
- Executor/business/App stream progress without proxy buffering; JSON exec stays compatible.
- Queue removes work on timeout, disconnect, reset or shutdown. Startup/cleanup consume concurrency; failed removal remains charged.
- The single sandbox, Docker, gVisor and executor share a 1 GiB account ceiling, with co-location limitations documented.
- Targeted Dart analysis and JS syntax checks pass; runtime checks require actual Linux evidence.

## Scope

No remote production deployment, database migration or unrelated UI refactor.

## Authorized Continuation: Complete Terminal Toolchains

The later user request expands this task to complete Java, Lua, Node.js,
Python, PHP, Go, Rust and Dart toolchains in the independent terminal repository.
Preserve the existing Alibaba Cloud Linux 3 installation and provide an Ubuntu
24.04 installation path, both with one bootstrap and automatic startup. The
user explicitly requires runtime tests before a deployment recommendation and
standard Git commits for completed stages.

Acceptance requires fresh installation, old-image upgrade, each language's
actual compilation/execution under the normal session limits, effective
account cgroups, isolation, health, rerun and reboot evidence. A configuration
or syntax check alone does not satisfy host compatibility.
