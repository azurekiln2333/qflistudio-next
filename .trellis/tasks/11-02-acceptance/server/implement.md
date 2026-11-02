# Server acceptance execution

- [x] Read task requirements, contracts, ownership, and existing local harness.
- [x] Write isolated planning artifacts before running acceptance.
- [x] Record revisions and inspect the assigned server implementation.
- [x] Build disposable fixtures without modifying business files.
- [x] Start real moderation and QFLI HTTP services with SQLite.
- [x] Execute each assigned item and capture sanitized raw evidence.
- [x] Report failures to the coordinator without business-code changes.
- [x] Write initial server.md with verdicts and deployment retest commands.
- [ ] Wait for the p3 fix commit and rerun all five failed assertions.
- [ ] Append the retest evidence without replacing initial failures.
- [ ] Run the controlled-Chinese linter and verify evidence references.
- [ ] Commit only server.md and these server planning files.
- [ ] Append Result with commit, tests, gaps, and required user actions.

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
