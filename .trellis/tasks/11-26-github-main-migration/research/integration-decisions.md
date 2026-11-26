# Migration integration decisions

## Publication boundary

The approved app migration covers `D:/MyNewProjects/qflistudio` to
`E:/MyNewProjects/QFLIProjects/qflistudio-next`.
GitHub `azurekiln2333/qflistudio-next` is public.

The publication parent is `c5f4bc3afe9c81ba488fd3f544d43c3dac061512`.
The local recovery ref `migration-pre-publication` retains `5a86e410` and its
unreviewed preservation parents. Never publish this ref or push all refs/tags.
The reviewed working-tree changes are consolidated onto the public baseline.
The existing remote history is not rewritten.

## Branch and worktree dispositions

The full inventory is in `branches.json` and `branches.md`.

- All ancestral/equal branches are already included by the public baseline.
- The two original local progress commits are retained as reviewed task/spec content.
- The unique public GitHub client ID fix from `1052f3b` is integrated into the
  current installer workflow and specifications, without reverting newer builds.
- The harness branch has an equivalent public patch already included.
- The unrelated server split remains in its independent repository, with the
  app's duplicate embedded server removed. See `server-split-disposition.md`.
- The artifact backup and pre-publication refs remain private recovery material.
- Remote-account work is retained under `preserved-remote-account`, with original
  patch bases and explicit missing Core API/relay publication blockers. It is not
  applied wholesale to runtime code. Its older whole-file snapshots regress newer
  app behavior. Future agents must port and validate the documented changes.
- Terminal/workspace historical source and progress are retained under
  `preserved-terminal-task`. Forty source/patch/YAML files retain original bytes;
  process reports have minimal summaries. Raw logs and generated bundles remain local.
- Linked worktrees and backups are retained. An ancestral branch does not prove
  that its dirty worktree is disposable.

## Portable progress and privacy

Portable skills, workflow scripts, tasks, specifications and journals are tracked.
Generated staging copies, installers, native payload downloads, caches and machine
signing configuration are excluded. The Gradle wrapper JAR is a source tool input.

The device screenshot, captured HTML page and two original DOCX files remain in
private recovery storage. Ten raw UI captures already existed in the public
baseline and are removed from the new tree; this does not erase their old history.
Report JSON email fields are redacted. Public commit/run/artifact identifiers and
reviewed source attribution are retained. See `report-redactions.json` and the
corrected `publication-audit` reports for exact scope and hashes.

Six staging helper scripts are preserved separately under `preserved-staging-tools`.
The original task retains its four root helpers and final verification summary.

## CI and dependency contracts

Every build, test, analyzer, dependency resolution and packaging command runs on
GitHub-hosted runners. Local work is limited to editing, Git and metadata review.
The app references `../qflistudio-core`; Dart package identity is `qfli_studio_core`.

Core remains pinned to `476a30acee21dc486ee2849dd8064a7be665e4d5` and its Git plugin
to `697291a27818612ae9dc53d83d4f99fa5887908e`. Their owners have not supplied final
migration replacements. The plugin owner confirms the new immutable native release
and hydration contract is pending. Do not substitute `native-v0.1.1`.

The Android typed Gradle DSL uses NDK `27.0.12077973` consistently with CI.
Explicit CI test signing is non-production. The OHOS build keeps the published
`6.1.1(24)` target and API 26 build tools; a target API upgrade is outside migration.
No signed-store release or physical-device acceptance is claimed.

SDK/pub/Gradle/CocoaPods/OHOS tool caches are cloud-only. They are dependency caches,
not a claim that a new reusable native producer release has been completed.
Current plugin payload provenance and ABI checks remain mandatory.

## Acceptance update

Code commit `da74782075d4bb31f92546c18031c340df1adb21` passed its own cloud run
`45908020703`: 18 successful jobs, no failed jobs, and one tag-only publication
skip. See `cloud-acceptance.md/json` for exact tests, artifacts and adaptations.
The target has pulled this code revision. The final bookkeeping commit still
requires exact-SHA cloud dispatch, final target pull/content comparison and
Herdr acknowledgement. Follow `migration-handover.md` for the receiver's work.
Cleanup remains gated by `cleanup-plan.md`; no WSL distribution has been started,
unregistered or deleted.
