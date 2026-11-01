# Verification record

Date: 2026-10-28, Asia/Shanghai.

Implementation and local acceptance meet the PRD. Changes remain uncommitted.
No image was published, no Git push ran and no production service was deployed.

## Observed results

| Check | Result | Evidence |
| --- | --- | --- |
| Live NewAPI model and isolated Python debug loop | 1 passed, 51 seconds | `research/vibe-live-run.log`, `research/vibe-live-evidence.json`, `research/vibe-live-bridge-events.json` |
| Business backend, current relay compatibility fix included | 67 passed, 0 failed, 1 opt-in skip | `research/server-final-tests.log` |
| Real MySQL 8.4 integration | 2 passed, exit 0 | `research/mysql-pool-run.log`, `research/mysql-pool-evidence.md` |
| Shared-core full suite before the final live-fixture assertion update | 1053 passed, 3 skipped | `.artifacts/core-full-tests.log` from repository root |
| Focused shared-core agent/API suites | 45 passed | `.artifacts/vibe-core-tests.log` from repository root |
| Main application entrypoint analysis | No issues | `.artifacts/main-analyze.log` from repository root |
| Current executor suite on Windows | 22 passed, 5 Linux-only skips | `.artifacts/executor-final-test.log` from repository root |
| Root image pipeline checker and negative regressions | Checker passed, 12 tests passed | `node scripts/check-root-ci.mjs`, `node --test scripts/check-root-ci.test.mjs` |
| Business deployment checker | Passed | `node azurekiln-qfli-server/scripts/check-deployment.mjs` |
| Current Linux executor tests | 27 passed, 0 failed, 0 skipped, exit 0 | `research/linux-tests-20261028.log` |
| Linux runtime and Compose | Healthy gVisor execution, effective budgets, Compose accepted | `checkpoint-pi-d-deploy.md`, `research/pi-d-runtime-checkpoint.md` |
| Independent pool race review | No remaining P0/P1 found | Final-2 focused regressions and an independently replayed failed-DELETE cancellation case |
| Real AI route authentication without a middleware stub | Three cases returned 401, zero upstream calls | `research/ai-auth-audit.cjs`, `research/ai-auth-audit.log` |

The requirement-by-requirement final audit is recorded in
[completion-audit.md](completion-audit.md).

## Live scenario

The fixture used the real shared-core controller, file tools, API client,
business relay and Linux gVisor executor. Authentication used a loopback-only
synthetic user. Upstream credentials stayed in the ignored backend `.env`.

1. `math_ops.py` deliberately returned subtraction from `add`.
2. The first actual `python3 verify.py` exited 1 with `AssertionError`.
3. The model called `read_file`, `edit_file` and `write_file`.
4. Local assertions verified changed source, a real source backup and exact
   `result.txt` bytes `42\n`.
5. A fresh terminal snapshot printed `QFLI_VIBE_VERIFIED_42` and the command
   exited 0. `verify.py` also checked the result file's exact bytes.
6. Cleanup reset the synthetic session. Authenticated executor health then
   reported ready with sessions/running/waiting all zero.

The loopback bridge was shut down after evidence capture. Root closed its
temporary WSL keepalive shell after Pi D completed the current Linux suite.
The local executor container and the old service backup were preserved.

The accepted bridge event archive contains only this successful acceptance run.
It records response shapes, tool names and controlled fixture command output.
It contains no upstream credential, authorization header or tool argument text.

## Defects found during real acceptance

- The completion observer initially accepted an idle notification before the
  controller entered running. It now requires running before terminal state.
- An empty query produced a trailing `?`. The bridge now routes by URL pathname.
- NewAPI returned optional numeric tool-call `index` metadata. The response
  normalizer validates and removes it. Client request keys remain strict.
- Final upstream text may contain `tool_calls: null` or `[]`. Both are normalized
  to an absent call list when nonempty text is present. Empty text without calls
  returns 502. Empty text with valid calls remains accepted.
- The first successful repair omitted the result file's trailing newline.
  Acceptance retained its strict byte assertion and added the same assertion to
  the Python verifier, then reran the complete live scenario successfully.

## Deployment and scaling boundary

Production Compose uses prebuilt images. Development build overrides are
separate. Business and executor have independent containers, resource limits,
health checks and Watchtower scopes. Business startup does not depend on
executor health. The executor and terminal updater use a dedicated rootless
engine. User sandboxes receive no Docker socket.

Multiple terminal nodes provide one execution slot per 2C2G node. Shared
database coordination preserves user affinity, requester reservations and token
fencing. Unknown outcomes stay quarantined until confirmed cleanup on the
original node. No ambiguous command is replayed on another node.

Other business services still need shared login challenges, refresh locking,
rate limits, cloud storage and SQL session routing before general multi-replica
deployment. See `docs/deployment/scaling.md` from the repository root.

## Remaining release requirements and limits

- Root `.cnb.yml` is locally validated. The hosted pipeline has not run.
  The service directories are not yet tracked by the parent Git index. A future
  release must include normal source directories or complete submodules before
  the root pipeline can build. No incomplete gitlink was staged.
- There is no claim of a full production installer upgrade/rollback rehearsal.
  Linux evidence covers observed runtime, locking, gVisor execution, effective
  cgroup budgets and Compose parsing. Immutable rollback wiring is reviewed and
  guarded by tests.
- MySQL old-schema ALTER, lock-wait/deadlock rollback and production-scale load
  remain unverified. They are distinct from the passed fresh-schema integration.
- Full shared-core analysis retains two existing errors in
  `tool/preview_test.dart` from an int/String user ID mismatch and existing style
  infos in content tools. Changed library analysis and the main entrypoint pass.
- Windows filesystem-link tests may return early if link creation is denied.
  The suite count alone does not establish Linux link-escape coverage.
- Packaged Android/Harmony/device interaction was not exercised in this task.
  Widget tests and the live controller test establish their stated boundaries.
- Existing unrelated working-tree changes remain intact.
