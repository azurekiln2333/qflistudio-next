# Server acceptance execution

- [x] Read task requirements, contracts, ownership, and existing local harness.
- [x] Write isolated planning artifacts before running acceptance.
- [x] Record revisions and inspect the assigned server implementation.
- [x] Build disposable fixtures without modifying business files.
- [x] Start real moderation and QFLI HTTP services with SQLite.
- [x] Execute each assigned item and capture sanitized raw evidence.
- [x] Report failures to the coordinator without business-code changes.
- [x] Write initial server.md with verdicts and deployment retest commands.
- [x] Wait for the p3 fix commit and rerun all five failed assertions.
- [x] Append the first retest evidence without replacing initial failures.
- [x] Run the controlled-Chinese linter and verify evidence references.
- [x] Verify the remaining three failures after the follow-up fix commit.
- [x] Commit only server.md and these server planning files.
- [x] Append Result with commit, tests, gaps, and required user actions.

Local evidence and scripts stay in an isolated system temporary directory.
The committed report contains response excerpts and reproduction steps.
Production configuration and real gateway effects remain separate verdicts.

Initial HTTP baseline: af5829dd1b78eac67b920218c373b1d75f1e7a71.
Moderation baseline: 6d6754c907b1e3b6caf162a55a2292edc6469022.
The corrected rubric produced 79 passes and 5 failures across 84 assertions.
The five failures concern registration user ID, pending-post admin detail and
list visibility, cross-actor audit deidentification, and failed-erase auditing.
Registration information and registration audit retention are separate contracts.
Deleting a 366-day-old registration audit is consistent with the 365-day policy.
Long-term registration information in the real gateway remains unverified.
Scoped supporting unit tests passed 83 of 83 on the initial server revision.
User assigned business fixes to w37:p3. This reviewer only reruns acceptance.

Initial evidence:
D:/AppData/Local/Temp/qfli-server-acceptance-20261102-p7-099baf6f149948bd8f53bc88445de02a/run-1793611163252/

First retest baseline: ac4d0b85cb6f37d10df6dedbfb5b9b6d5446d1b0.
The new processes produced 81 passes and 3 failures across 84 assertions.
First registration still lacks a user ID despite a successful gateway profile.
Real authOptional does not populate req.user, so admin pending list/detail still fail.
The two original erasure assertions pass. All original audit rows and timestamps
were retained while target references were replaced and admin actor IDs stayed intact.
The failed erasure now appends user.deactivate_failed (audit count 44 to 45).
The remaining failures were reported to the coordinator and fixer.
The detail-only cross-actor reference is a separate, unverified boundary to check.
First retest evidence:
D:/AppData/Local/Temp/qfli-server-acceptance-20261102-p7-099baf6f149948bd8f53bc88445de02a/run-1793613015772/

Second retest baseline: 390fad5a500d8f52247a63a5a12042d4f69e9436.
Fix commits reviewed: 60732a9, 936f9d6, and 7285f82.
The new processes passed 86 of 86 assertions with no source changes during the run.
All five original failures pass. Two added assertions cover administrator deletions
whose audit detail alone contains the erased user's ID. Twelve original audit rows
and timestamps were retained, administrator actor IDs stayed intact, and raw erased
user identifiers were absent. The local report row now survives with a pseudonym.
Complete server tests: 145 total, 144 passed, 0 failed, 1 opt-in MySQL pool skip.
The server code remains read-only for this worker.
Second retest evidence:
D:/AppData/Local/Temp/qfli-server-acceptance-20261102-p7-099baf6f149948bd8f53bc88445de02a/run-1793614305018/

## Result

Delivered docs/compliance/acceptance/server.md with original requirement text,
individual HTTP methods, sanitized response excerpts, verdicts, evidence paths,
and exact post-deployment retest commands. Initial and first-retest failures stay
in the report. The opening and second-retest section give the latest local verdict.

Acceptance commits:

- e5c0ed2 test(compliance): record initial server acceptance evidence
- 6357f19 test(compliance): record server fix verification gaps
- 82ea73b test(compliance): record passing server acceptance retest

Tests and checks:

- Real QFLI and moderation HTTP processes used separate disposable SQLite files.
- Initial run: 79/84 assertions passed, with five failures handed to w37:p3.
- First fix retest: 81/84 passed. New registration and real admin auth still failed.
- Final run at 390fad5: 86/86 passed, including all five original failures.
- Two added checks cover administrator-deletion detail references on erasure.
- Twelve original audit rows and timestamps survived with deidentified user refs.
- The local report row survived erasure with a deidentified reporter ID.
- node --test --test-timeout=60000 "test/*.test.js": 145 total, 144 pass, 0 fail,
  1 opt-in MySQL terminal-pool skip.
- python scripts/ste-lint-zh.py on the report and both server planning files:
  zero findings.
- verify-evidence.mjs checked three frozen script hashes and required sections.
- git diff --check passed for the owned documentation paths.

Evidence root:
D:/AppData/Local/Temp/qfli-server-acceptance-20261102-p7-099baf6f149948bd8f53bc88445de02a/

Outstanding evidence:

- Production deployment, runtime retention configuration, nginx source ports, and
  the real AI upstream require the documented post-deployment retest.
- Live Huawei login, first-registration profile lookup, gateway erasure, token
  revocation, and long-term registration information retention remain unverified.
- Real MySQL behavior was not exercised. The explicit MySQL test remains skipped.
- Moderation-center report status synchronization and erasure of its reporter ID
  belong to the moderation acceptance scope. The observed limits are in the report.
- Client-only criteria belong to the client acceptance worker.

User action: grant qfli_account_erase to the existing qfli client in gateway admin.
Do not treat the local gateway fixture as proof that this live grant exists.

Only the server acceptance report and isolated server planning files were edited.
Business code, gateway code, shared task metadata, and other reports stayed read-only.
All commits used explicit paths and temporary message files. No push was run.

## Moderation identity retest plan (2026-11-03)

- [x] Read the new fix commits and the current acceptance contracts.
- [x] Define the retest boundary before writing the new harness.
- [x] Add an independent HTTP/SQLite retest harness in this server subdirectory.
- [x] Exercise real login, post, comment, report, review, and blocked requests.
- [x] Scan moderation tables, audit results, and database files before erasure.
- [x] Erase a user, verify sessions, and repeat the complete moderation scan.
- [x] Restart production-mode QFLI without a key and check failClosed behavior.
- [x] Check a too-short key and unchanged moderation records.
- [x] Run the previous frozen 86-assertion script and retain its hash.
- [x] Append sanitized evidence and limitations to server.md.
- [x] Run the Chinese linter, evidence checks, and explicit-path diff checks.
- [x] Commit only the report and owned server task files.
- [x] Append the new Result and print the final terminal handoff.

Execution evidence:

- Baseline: cad26560e991ccc25e29d8aa942ef7ef9084c893.
- Moderation: 6d6754c907b1e3b6caf162a55a2292edc6469022.
- New independent harness: moderation-pseudonym-retest.mjs in this directory.
- Final run: 69/69 assertions passed in fresh production-mode service processes.
- Every QFLI user and gateway subject in this fixture was included in the scan.
- All 11 moderation tables, audit API pages, SQLite/WAL/SHM files had zero raw IDs.
- Author and reporter erasure retained identical moderation rows with pseudonyms.
- Missing and five-character keys refused post/comment/nickname/bio requests with
  503 moderation.unavailable. Content and moderation records stayed unchanged.
- Reports retained the existing local queued behavior without upstream records.
- Restoring the configured key allowed a post to enter the pending review queue.
- All five service children stopped and both business source trees stayed unchanged.
- Frozen original script: 86/86 passed. Its SHA-256 stayed
  42aa73bb3eddea3b7aea229cfa0cd1b1eb3df7e72b761ca201fff3c7685e861a.
- Full server suite: 154 total, 153 passed, 0 failed, 1 opt-in MySQL test skipped.

New evidence:
D:/AppData/Local/Temp/qfli-server-pseudonym-20261103-p7-nffJeH/

Frozen-script regression evidence:
D:/AppData/Local/Temp/qfli-server-acceptance-20261102-p7-099baf6f149948bd8f53bc88445de02a/run-1793648048450/

Complete server unit evidence:
D:/AppData/Local/Temp/qfli-p7-unit-20261103-3atjey9n/

## Result (2026-11-03 moderation identity retest)

Commit: c1b8a13 test(compliance): verify moderation identity pseudonyms.

Appended item 7 evidence to docs/compliance/acceptance/server.md. Earlier failure
evidence remains intact. The committed independent harness starts unmodified
QFLI and moderation entry points with disposable SQLite data and a local gateway.

Commands and final results:

- node .trellis/tasks/11-02-acceptance/server/moderation-pseudonym-retest.mjs:
  69/69 assertions passed. Real HTTP login, publication, reports, text/IP blocks,
  queued reviews, two erasures, production failClosed, and recovery all passed.
- node <previous-evidence-root>/server-acceptance-retest-two.mjs:
  the unchanged original 86-assertion script passed 86/86.
- node --test --test-timeout=60000 "test/*.test.js" in azurekiln-qfli-server:
  154 tests, 153 passed, 0 failed, 1 opt-in MySQL pool test skipped.
- python -X utf8 scripts/ste-lint-zh.py on server.md, design.md, and implement.md:
  zero findings.
- node --check on the new harness and git diff --check on all owned paths passed.
- Independent evidence verification checked script hashes, all snapshot scans,
  exact preservation of moderation rows after erasure, the original report prefix,
  69/69 and 86/86 summaries, unchanged business sources, and child termination.

The moderation database, its audit API, and SQLite/WAL/SHM files contain none of
the four fixture users' raw local IDs or gateway subjects before or after erasure.
Missing and too-short keys return 503 for post, comment, nickname, and biography
publication. Reports retain the existing locally queued contract. These checks
do not establish removal of raw IDs from historic production data.

Outstanding evidence: production rollout, historical production records, real
gateway erasure and grant behavior, and MySQL still require separate verification.
User action: inject an independent random QFLI_MODERATION_SUBJECT_SALT with at
least 16 characters into production, and grant qfli_account_erase in gateway admin.

Only server.md and this isolated server task directory changed. Business code,
deployment configuration, shared task files, and other workers' output stayed
read-only. All five service children stopped. No push or prohibited Git operation
was run. The terminal handoff reports the work commit, bookkeeping commit, tests,
remaining evidence, and required user actions.
