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
