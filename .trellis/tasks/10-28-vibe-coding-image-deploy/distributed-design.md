# Terminal pool and business expansion

## Ownership and deployment
Pi A implements the business-side terminal pool after the AI relay. Pi D owns executor health metadata and independent image deployment. The root agent audits integration and business expansion constraints. This is an explicit user scope addition.

Each 2C2G machine keeps one dedicated qfli-runner rootless engine and the current one-session/one-running budget. Add machines to increase total parallel compilation; never multiply the existing 1 GiB budget on one 2 GiB host. The business image can run elsewhere and has no executor socket or Docker permission.

## Pool configuration and compatibility
Keep `QFLI_TERMINAL_URL` / `QFLI_TERMINAL_SECRET` as the legacy single-node path. Add `QFLI_TERMINAL_NODES` JSON with entries `{id,url,secret,draining?}`. Node IDs are stable and unique. Validate every URL/secret using the same local-HTTP-or-HTTPS rules. No public client supplies a node URL or secret. Every business replica uses the same pool configuration and the same MySQL database. Node secrets are independent. A changed endpoint under an existing ID is an operator-controlled replacement, not permission to replay work.

Authenticated executor `/health` retains `ready` and adds capacity metadata: sessions, running, waiting, sessionsLimit, runningLimit, queueLimit. These are telemetry, never proof that an old request did not execute. Node sessionsLimit stays 1 on the current image. Probe timeouts are short and bounded; no unconditional probe dependency is added to general business health.

## Shared scheduling authority
Use the existing database rather than introducing Redis solely for dispatch. Persist node slot ownership, user affinity, operation token and recovery deadlines. Add portable SQLite/MySQL schema through the existing db initializer. Serialize placement with a dedicated singleton coordination row locked through an UPDATE inside `db.transaction`, so multiple business replicas cannot allocate the same slot or the same user twice. Never hold this transaction across HTTP calls.

A slot record needs stable node ID, user ID, phase, random operation token, operation deadline, idle deadline and conservative session deadline. Use database time for cross-host leases or explicitly guard against clock skew. The executor's absolute sandbox lease is 30 minutes; uncertain state must stay reserved until confirmed reset/removal or a deadline that also covers bounded delayed admission. A business-process timeout is not evidence of command failure or sandbox cleanup.

Placement order: reuse the same user's healthy idle assignment; otherwise choose a healthy non-draining free node, ordered by admitted/reserved load with deterministic ties. A user already busy returns conflict. New users never steal an active slot. Existing idle sessions consume actual executor capacity. Reclaim expired idle assignments through a confirmed DELETE for the old user before granting their slot to another user; do not expire a DB row and assume the sandbox vanished. Store a reset/recovery token while doing that HTTP call and verify it before completing the transition. If all nodes are full, return a capacity error without creating extra work.

## Dispatch and completion
Acquire/persist the operation token before issuing the request. Send exactly one command to the assigned node and preserve existing streaming, cancellation and result validation. A successful validated result transitions that token to idle affinity. Completion/reset updates must be conditional on the same token so stale responses cannot free a newer operation. Refusal before execution can release a reservation only when its semantics prove no admission occurred.

On transport failure, malformed/truncated stream, disconnect, gateway crash or unknown cleanup, quarantine the assignment. Do not send the same command to another node. A subsequent explicit reset or controlled recovery can clear it only after that node confirms cleanup. A busy lease expiring is a recovery trigger, not proof the old operation stopped. A node that is unreachable stays unavailable to new sessions; other nodes continue accepting unrelated users.

Draining excludes a node from new placement and retains existing affinity until completion/reset/expiry. Removing or renaming a configured node must not erase outstanding reservations. Surface a recoverable unavailable response for an assigned missing node. Keep `pwd` compatible; reset routes to the owning node and is idempotent when no assignment exists. Log node ID/request ID/status only, never command content, credentials or project snapshots.

## Verification
Test two simultaneous users placed on two nodes, third-user capacity rejection, sticky follow-up, concurrent requests by one user through separate pool instances, unhealthy and draining exclusion, reset fencing, delayed/stale completion, gateway restart persistence and ambiguous transport failure without retry. Use real loopback executor stubs for transport tests and SQLite for coordinator persistence/concurrency; require MySQL integration evidence before claiming multi-host production verification.

## Business services expansion
The API is not fully stateless today. `auth_sessions` and business records are shared through MySQL, but OAuth/Huawei MFA/binding challenges and some rate limits/refresh coalescing are process-local. Cloud project files are local filesystem state. SQL sandbox and terminal runtime are node-local execution state.

Stage 1: one business instance plus many isolated terminal nodes. This is useful immediately and avoids unsupported shared-auth/shared-files claims. Put MySQL on an independently backed-up service; keep executor load off business.

Stage 2: multiple business instances behind a reverse proxy. All use identical session/JWT/encryption keys and shared MySQL. Before enabling unrestricted round robin, move pending OAuth/MFA/binding state into a shared TTL store with atomic one-time consumption, implement cross-instance refresh/rate-limit coordination, and make cloud file mutations use a shared storage service with atomic locks/quotas. Sticky ingress can be a temporary compatibility measure but does not provide recovery after an instance fails. Never recommend shared SQLite files over network mounts.

Stage 3: separate storage, identity/business API, terminal pool and SQL execution pools where load warrants it. Route executions through stable node ownership; do not replicate node-local runtimes by merely adding API replicas. Run migrations as a single release job, retain backward-compatible schemas for rolling updates and test key consistency before admitting an instance. Health/readiness of the general API must not require every executor node to be healthy.

Image update scopes remain separate: business rollout, terminal executor rollout, and immutable sandbox/toolchain revisions. A watch updater replaces only its own scope. Drain a terminal node before controlled upgrades; do not claim ordinary watch replacement preserves active commands. Pin the sandbox image by version/digest and update it together with the executor's validated toolchain contract.
