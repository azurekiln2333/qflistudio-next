# Client and consolidated acceptance design

Scope: take over the former w37:p6 acceptance row as w37:p7. Verify items 3 client,
8, 9 client (including a global client/server Bing call scan), 10, and 12. Deliver
docs/compliance/acceptance/client.md and docs/compliance/2026-11-验收记录.md.

The missing behavior is independent evidence for the delivered client, test
gates, and the combined twelve-item verdict. The implementation remains read-only.
Only the two reports and this isolated client task directory may change.

Record revisions, dirty paths, tool versions, exact bounded commands, exit codes,
and raw output in a temporary evidence directory. Run full Flutter tests and full
analyze for qfli_studio_core and qflistudio. Run full Node tests and available lint
for azurekiln-qfli-server and azurekiln-moderation. If a lint command is absent,
record that fact and run all JavaScript syntax checks as separate evidence. Keep
Flutter commands sequential to avoid the shared SDK lock. Independent Node gates
may run alongside them. Time out and stop only processes started by this task.

Audit complete commit messages from 2026-11-02 00:00:00 +08:00 in the four logical
projects. The server is a subdirectory of the qflistudio Git root, so record both
its path-filtered history and the parent root's complete history. Check subjects
against Conventional Commits and bodies for attribution/signature lines. Do not
rewrite history. Scan executable client/server sources for direct and constructed
Bing endpoints, separate tool-removal text from calls, and preserve match context.

Use existing compliance widgets plus independent task-local widgets to verify
the real Home -> Profile -> Settings navigation and count agreement/privacy taps.
Trace Huawei phone rejection, consent withdrawal, erasure, AI labels, file headers,
and custom endpoint policy through their production call sites. Keep native host
fixtures explicit and do not claim that simulated host behavior proves a device.

Do not connect to, query, unlock, install on, or otherwise operate 192.168.68.207.
Item 10 remains 'needs physical device'. Document Mate 60 portrait and Mate X5
folded/unfolded replay steps, status/cutout rectangles, and required screenshots.

Read server.md and moderation.md as evidence owned by their acceptance workers.
Preserve their dates, limitations, and newest appended results in the combined
table. List deployment retests, physical-device checks, and user-only actions
separately. A local green test gate does not establish production deployment.
