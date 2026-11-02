# Server acceptance design

Scope: PRD row `w37:p7`, items 1, 2, 3 server, 5, 6, 7 server, and 9 server.
Deliverable: `docs/compliance/acceptance/server.md`.

Use separate server planning files because the task directory is shared with
other acceptance workers. Do not edit business code, gateway files, shared task
metadata, or another worker's report.

Start real QFLI and moderation processes against disposable local SQLite data.
Use a local gateway fixture for userinfo, login, registration, and erase responses.
State the fixture boundary explicitly. It cannot prove production gateway or
Huawei behavior. Seed verified, unverified, admin, rate-test, and erase accounts.

Record method, path, request body, status, sanitized response excerpt, assertions,
and code evidence for each assigned item. Query SQLite for audit and deletion
evidence. Preserve test scripts and raw evidence in an isolated temporary folder.
Embed the relevant excerpts and replay instructions in the committed report.

Exercise log fields and retention, all realname-gated route groups, Huawei
skip/bind refusal, administrator deletion and reports, rate/IP/pre-review,
account erasure success and dependency failure, and removed search/AI metadata.
Use HTTPS verification normally. Do not contact production with destructive tests.

Classify each result as pass, fail, deployment retest, or unverified. A passing
unit test is supporting evidence only. Report business failures for coordinator
assignment and continue independent checks without fixing production code.

## Moderation identity retest (2026-11-03)

Verify item 7 after fixes 3463632, 715ed33, and 59ab6af. The gap is whether
QFLI-generated identity fields leak into the independent moderation database,
including its audit and review payloads, before or after account erasure.

Use a new HTTP harness in this server task subdirectory. Start the unmodified
QFLI entry point and moderation entry point in separate processes with fresh
SQLite databases. A local OAuth fixture supports real HTTP login and erasure.
Configure a random test-only HMAC key and compare stored subjects against
independently calculated HMAC-SHA256 values. Exercise posts, comments, all three
report targets, text/IP blocks, and queued review payloads. Scan every table and
database/WAL bytes for all synthetic QFLI user IDs and gateway subjects. Repeat
the scan after erasure and retain the original moderation records.

Restart QFLI in production mode without a subject key, then with a short key.
Check that post, comment, and profile publication fail with HTTP 503 and do not
create content or moderation records. Reports may remain locally queued by the
existing contract. Use only disposable local data and generated credentials.

Run the previous frozen 86-assertion script without changing it. Append results
and evidence to the existing report. Only this report and server task directory
may change. Business code, deployment files, shared task metadata, and other
acceptance reports stay read-only. Production rollout and historic production
records cannot be established by this local retest.
