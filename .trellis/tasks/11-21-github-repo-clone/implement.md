# Execution
1. Read PRD/design/context. User authorized immediate implementation.
2. Re-dispatch to existing Herdr w37 panes pC/pG/pH/pJ, and confirm working state.
3. A/C/D publish contracts early. B starts R2 and independent UI.
4. Implement owned files; coordinate integration.
5. Add focused cloud regression sources. Local format/static only.
6. Root reviews isolation, deletion races, cache ownership and ZIP content.
7. Root commits each R1-R8 separately with explicit paths/hunks; no concurrent staging.
8. Record hashes/dependencies in reports/commit-ledger.md.
9. Record unrun cloud checks and external OAuth configuration honestly.
Local allowed: format, targeted Dart/Flutter analysis, native syntax, git diff --check, ste-lint-zh.py.
No local runtime tests/builds/services/emulators/devices. No real account deletion/clone/share for validation.
Cloud cases: OAuth/pagination/cancel, token redaction, clone isolation, cloud-delete failure/stale refresh, cache scope/partial download/unsent edits, ZIP selection/binary/path safety/native lifetime, restart cache state.
Workers do not stage/commit/push or modify other worktrees. Root owns requirement commits after review.
