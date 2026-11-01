# Concurrency review retrospective

## 1. Root cause category

Cross-layer contracts and implicit assumptions caused the placement defects.
A serialized database decision did not cover the later HTTP cleanup interval.
Only the old owner was persisted. A second gateway could miss the new requester.
Reset similarly searched owners while an in-flight requester was represented
by a different field. Explicit requester reservation closes that interval.

The initial executor fence assumed a container port or a recorded PID identified
all processes sharing one engine. Separate namespaces invalidated that model.
An exclusive-create lock file then had publication/stale-unlink races. A helper
that held flock for Node introduced a separate helper-lifetime failure mode.

## 2. Why intermediate fixes were incomplete

Requester persistence prevented double placement but did not initially extend
reset lookup to requesters. Cancelling the requester then fenced successful
cleanup but left the failed-DELETE retry path able to re-place the command.
Both success and failure continuations must prove the same operation token.

The first cancellation fixture left another node free. Correct scheduling chose
that node and never reached the intended cleanup barrier. A test that waits for
an unreachable barrier establishes neither correctness nor a production defect.

## 3. Prevention mechanisms

| Mechanism | Concrete contract | Status |
| --- | --- | --- |
| Persistent ownership | Reserve owner and requester under one shared lock | Implemented |
| Completion fencing | Every success/failure continuation checks affected rows | Implemented |
| Cancellation tests | Delayed cleanup succeeds/fails with another expired node available | Passed in SQLite/HTTP suite |
| Route integration | Real Express router, abort, audit and stream ordering | Passed |
| Kernel fence | Node retains inherited flock descriptor; never unlink path | Implemented; Linux tests passed |
| Runtime evidence | Distinguish static, Linux, MySQL and live model results | Recorded separately |

## 4. Systematic expansion

Apply the same token review to dispatch, finalization, reset, quarantine,
reclamation and release. A timeout is evidence of uncertainty, not absence of
work. Never repeat an ambiguous command on a second node.

UI preparation is also an asynchronous ownership interval. Vibe now marks
preparation busy before awaiting save and rechecks owner/execution before send.
Disk reload compares revision after IO because clean state alone cannot prove
the user did not edit and save during the wait.

## 5. Knowledge capture

The executable contracts are captured in the root backend
`ai-terminal-pool.md`, updated `terminal-isolation.md`, and shared-core frontend
`vibe-coding.md`. No template tree exists in these application packages.
No commit or publication is part of this verification record.
