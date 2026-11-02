# Implementation plan

1. Confirm requirements, current repository state, and ownership.
2. Write the deployment runbook and moderation pipeline.
3. Add bounded smoke probes and behavior tests.
4. Wait for W2b's committed vendored SDK, then run the local two-process integration.
5. Run Chinese text checks, owned tests, moderation checks, and whitespace checks.
6. Commit explicit owned paths in each repository with Conventional Commits.
7. Append Result with commit IDs, evidence, remaining limits, and operator actions.

## Progress

- Read the PRD, compliance task, rules, interface contracts, deployment artifacts, and applicable backend guidelines.
- Confirmed that production access, pushing, and real credentials are forbidden.
- Confirmed Docker is unavailable in this workstation's task context.
- At task start, W2b's SDK and server manifest changes were uncommitted. Integration waited for that commit.
- Added the runbook, bounded smoke CLI, temporary two-process launcher, and deployment behavior tests.
- Moderation CI committed as `8f74165 ci(moderation): validate and publish CNB deployment images`.
- Verification so far: deployment tests 14/14, CI tests 7/7, moderation tests 45/45, moderation syntax 31 files, Chinese lint zero findings, and runbook Compose/Python parsing passed.
- Runbook tests execute the actual credential issuance, environment merge, image pin, and rollback blocks in temporary directories. Windows newline differences are normalized in assertions.
- Runbook and probes committed as `03868fa feat(deploy): add compliance runbook and bounded smoke checks`.
- The actual `node scripts/publish-ci.mjs verify` entry point passed clean installation, 31 syntax checks, 45 service/SDK tests, and 7 CI tests. Installation audit found zero vulnerabilities.
- The Windows npm shim uses fixed, validated commands without shell-argument warnings in `6d6754c fix(ci): run fixed npm commands without shell argument warnings`.
- All 18 Bash blocks in the runbook passed Git Bash syntax checks.
- Started a standalone moderation process against a temporary database. Health and all six actual seeded variant probes passed (7/7); QFLI-only cases were explicitly skipped in that standalone run.
- W2b committed SDK integration as `c07c974`. The first real two-process run then exposed an unverified-user bypass: Express strips the mount prefix from `req.path`, while the middleware compares it against `/api/...`. Posts/cloud returned 200. Sent the exact evidence to W2a and the coordinator; no business file was changed here. The owned integration runner now reports the failed smoke group while continuing independent SDK/publication/report checks, and still returns failure overall.
- Added canonical/query/uppercase realname probes and a regression that rejects HTTP 401 as a substitute for realname HTTP 403. Deployment behavior tests now pass 15/15. Committed as `60f4ccd test(deploy): cover realname path variants in smoke checks`.
- The real two-process launcher is committed as `acde63e test(deploy): exercise the vendored SDK across real service processes`.
- W2a committed the mounted-path correction as `574a3f9`. The final two-process run after that commit passed all 19 named checks with zero skips. Deployment tests also passed 15/15 after the last probe changes.

## Result

### Deliverables

- Runbook: `docs/compliance/2026-11-上线手册.md`.
- Arbitrary-base-URL smoke CLI: `scripts/compliance/smoke.mjs`.
- Two-process integration: `scripts/compliance/local-e2e.mjs` and the isolated `local-qfli.cjs` fixture.
- Deployment behavior tests: `scripts/compliance/smoke.test.mjs` and `runbook.test.mjs`.
- Moderation CNB pipeline: `D:/MyNewProjects/azurekiln-moderation/.cnb.yml` and `scripts/publish-ci.mjs`, with `publish-ci.test.mjs`.

### Artifact commits

| Repository | Commit | Title |
| --- | --- | --- |
| qflistudio | `03868fa` | feat(deploy): add compliance runbook and bounded smoke checks |
| qflistudio | `acde63e` | test(deploy): exercise the vendored SDK across real service processes |
| qflistudio | `60f4ccd` | test(deploy): cover realname path variants in smoke checks |
| azurekiln-moderation | `8f74165` | ci(moderation): validate and publish CNB deployment images |
| azurekiln-moderation | `6d6754c` | fix(ci): run fixed npm commands without shell argument warnings |

All commits used explicit paths and temporary message files. No branch changes, destructive Git commands, push, signatures, production connections, or real credentials were used.

Integration dependencies: `c07c974 feat(server): call the moderation SDK from the vendored tarball` and `574a3f9 fix(server): gate the realname check on the unmounted request path`. Those business changes belong to W2b and W2a respectively.

### Verification

| Command / check | Result |
| --- | --- |
| `node --test scripts/compliance/*.test.mjs` | 15/15 passed |
| Moderation `node scripts/publish-ci.mjs verify` | clean install, zero audit vulnerabilities, 31 syntax files, 45/45 service+SDK tests, 7/7 pipeline tests passed |
| `python scripts/ste-lint-zh.py docs/compliance/2026-11-上线手册.md --max-chars 25` | zero findings |
| Git Bash `-n` on all runbook Bash blocks | 18/18 passed |
| Runbook Compose and Python parsing | image-only/loopback Compose and four Python blocks passed |
| Standalone real moderation process | health and six seeded variants passed, 7/7 |
| `node scripts/compliance/local-e2e.mjs --moderation-repo D:/MyNewProjects/azurekiln-moderation` | two real service processes, 14 strict smoke checks plus five integration checks passed, zero skips, after SDK and realname fix commits |

The two-process test uses Node 24.15.0, temporary SQLite databases, a loopback identity fixture, and the real server entry points. It does not read production `.env` files. The SDK tarball SHA256 is `e63df6cf97b73fb67dcf33d41b0a5b1c42ea20f1c1908374ef3a337c9fcaaab5`.

The 14 smoke checks cover both health endpoints, six text variants, five realname groups (each requires canonical/query/uppercase paths to deny access), and a bounded 429 quota check. The five additional checks cover verified publication, report forwarding into the independent service, remote pre-review with author-only visibility, persisted decision audit, and HTTP 503 after stopping moderation.

### Remaining limits and operator actions

- Docker CLI is unavailable locally. Container builds, CNB publication, and actual Compose startup were not executed. Production MySQL, nginx reload, TLS ingress, and backup restoration remain deployment acceptance steps.
- The user must create the moderation CNB repository and push the committed code, provide host/registry access, assign an HTTPS hostname/certificate and domestic gateway egress allowlist, issue independent app credentials, and grant `qfli_account_erase` in the gateway console.
- The user must arrange a maintenance window, protected database backups and production migration checks, and two dedicated test sessions for post-deployment strict smoke. No production deployment was attempted by this task.
