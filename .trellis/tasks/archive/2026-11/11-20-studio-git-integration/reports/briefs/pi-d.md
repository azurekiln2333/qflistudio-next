Active task: D:/MyNewProjects/qflistudio/.trellis/tasks/11-20-studio-git-integration

You are already trellis-implement, Pi D. Implement directly without subagents.
Read common.md, task artifacts and implement.jsonl first. Start in
D:/MyNewProjects/_wt/studio-git-integration/qflistudio. Sibling core/plugin belong
to this isolated integration directory and may be edited within your ownership.

Own tracked pubspec.yaml/pubspec.lock, .github/, tool/ci/ in app/core/plugin,
plugin tool/import_artifacts.py and native_libs.lock.json tooling/contracts,
example manifests if CI requires a fix, and release/dependency specs. Do not edit
product lib/, native C/bindings, UI, or plugin test fixtures owned by A/B/C.
Do not fabricate lockfile hashes or final commit refs. Coordinate pending pins
through your report. No commit/push/tag or binary import yet; root handles them.

Read research/cloud-delivery.md. Add release/studio-git-ui-20261120 plugin trigger
and preserve existing Dart/native jobs. New API requires rebuilding Android/iOS/
OHOS libraries. Read reports/pi-a-api.md as it appears. Check required exports,
source SHA/API version, checksums and import provenance so old binary/new Dart
cannot ship. Cloud plugin tests must load newly built libraries, not stale blobs.

Wire core qfli_git dependency with a clearly documented temporary exact existing
Git commit until root has new artifact commit; final release MUST pin the new
artifact commit. Do not commit a machine-local path. Update lockfiles only through
legitimate resolution, or leave explicitly pending for cloud/root. Keep overrides
owned by B intact. Lazy native loading must allow desktop core tests.

Prepare app cloud validation and package assertions for the new Git backend/UI.
Preserve full core suite, all eleven installers, Java contract and assistant.
Add Git preview publication family while retaining v5.0.5-remote.*. Record plugin
Dart commit and native source/API version in build provenance. Do not reduce gates
or introduce continue-on-error. Write package payload checks for native libs and
CA. Cloud commands only; no local tests/builds/services/emulators.

Inspect existing Android Kotlin resolution failure from audit before deciding if
any code change is warranted; a new cloud result is required. Do not blindly
upgrade the toolchain. Finish reports/pi-d-cloud.md with changed files, exact
pending pins, native artifact import steps and cloud verification/release order.
