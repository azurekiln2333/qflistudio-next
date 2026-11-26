Active task: D:/MyNewProjects/qflistudio/.trellis/tasks/11-20-studio-git-integration

Read reports/herdr-common.md first. You are already the trellis-implement worker. Implement directly.

Ownership: integration worktree qflistudio/.github/**, qflistudio/tool/ci/**, qflistudio/pubspec*; qfli_git/.github/**, qfli_git/tool/**, qfli_git/pubspec*; qfli_studio_core/pubspec*, qfli_studio_core/.github/**, qfli_studio_core/tool/ci/**. No product lib/native/test edits. Root coordinates final commits/pins.

Finish tracked dependency and GitHub CI wiring for release/studio-git-ui-20261120. Review existing draft app-setup/action.yml, app-installers.yml, stage_artifact.sh, check_git_payload.py, plugin_provenance.py, plugin collect/import/check tooling. Core currently lacks qfli_git dependency; define a portable full-commit Git pin, never an absolute/path dependency. If final artifact commit is unavailable, document the exact pin step and use a real existing full SHA temporarily; root will replace before core commit.

Plugin CI must build fresh API v2 binaries on cloud and run native/Dart checks against artifacts from THAT SAME RUN, not old checked-in v1 binaries. Ensure branch trigger/workflow dispatch and matrix dependencies, symbols/API checks, CA files, artifact manifest/checksums, correct mobile/desktop native packaging and provenance validation. Add focused cloud-only core Git/backend/UI test execution and gate installer delivery on appropriate checks. Preserve all existing release matrix jobs and Java pin 60d97c783f29da767fafe503980812101f6aa61f.

GitHub ONLY. No CNB tag or backend deployment. No local build/test. No push/commit/tag from you. Deliver concrete workflow/tool edits and exact ordered root commands for plugin push -> native cloud artifacts/import -> plugin artifact commit -> core pin/cloud validation -> app pin -> v5.0.5-git.1 preview cloud installers. Verify compatibility by source review and allowed syntax checks only.
