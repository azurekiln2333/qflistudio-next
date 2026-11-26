# Git UI cloud release audit

Read-only inspection on November 21, 2026, around 02:34 Asia/Shanghai. No local tests, builds, commits, pushes, or product edits were performed by this reviewer. Pi D may be changing the audited files concurrently, so re-read before applying fixes.

## Verified remote state

- Plugin remote `origin`: `azurekiln2333/qflistudio-git`.
- Core/app GitHub remote: `github`, repositories `qflistudio-core` and `qflistudio-next`.
- `release/studio-git-ui-20261120` does not exist on plugin/app remotes yet. Core/app Actions queries return zero runs for this branch.
- App tag `v5.0.5-git.1` is absent. Its release API returns HTTP 404.
- Latest plugin run: `44547642230`, branch `integration/git-ci`, source `36faeb7260359971ad0b4dd180f747afe593e466`, failed.
- In that run, host smoke, Dart, all native platform builds, and iOS simulator flow passed. Only Example Android APK failed, job `135644017316`.
- Its log reports missing Kotlin 2.0.21 stdlib/plugin/BOM while configuring Flutter's included Gradle build. The resolver searched only `https://plugins.gradle.org/m2/` for those modules. Reproduce/fix in cloud; no basis to change Kotlin versions blindly.
- Latest plugin main run `44514336239` passed at `95cb99b538422de18e9a6dca906791f67294452e`.

## CI blockers in the inspected draft

1. Plugin workflow lacks a `release/**` push branch trigger.
2. Plugin Dart job has no dependency on the fresh host native job. Use its same-run library, with the existing `QFLI_GIT_LIBRARY` environment override from `lib/src/library.dart`.
3. `tool/ci/native_contract.json` is missing, although import/provenance/check tools require it.
4. Each `collect_artifacts.py` call must supply `--contract tool/ci/native_contract.json`. This flag is optional in the collector, so omission quietly generates the old schema. iOS also requires an `--nm` executable when checking the contract.
5. Example import steps supply no provenance. New `import_artifacts.py` expects `--commit` and/or `--run`; supply both the current SHA and run URL.
6. `qflistudio/tool/ci/plugin_provenance.py:lock_entry` uses JSON parsing for `pubspec.lock`, which is YAML. It will fail every app setup until fixed.
7. Core lacks the tracked `qfli_git` Git dependency. Use a full immutable artifact commit, not a path or branch pin.
8. App `publish-preview` accepts only `v5.0.5-remote.*`. Add the intended Git preview prefix. Update old release text saying Git UI is not integrated when integration passes.
9. Existing native binaries and `native_libs.lock.json` are schema/API v1 from `native-v0.1.1`. Source commit alone is not releasable.

## Available tools and safe API access

`git.exe` and Python 3.13 are installed. `gh` is not installed.

Existing helper:

`.trellis/tasks/11-20-cloudterminal-import/reports/read-ci.py`

It obtains the GitHub password through `git credential fill`, keeps it only in memory, and strips Authorization on redirects. It supports JSON endpoints and binary output via `--output`. Its repository allowlist currently includes only `qflistudio-core`, `qflistudio-next`, and `qflistudio-java`. A task-local copy with `qflistudio-git` added is sufficient for plugin reads/downloads. Do not print credential stdout or put the token into command arguments.

Useful endpoint arguments to that helper:

```text
actions/runs?branch=release%2Fstudio-git-ui-20261120&per_page=10
actions/runs/RUN_ID
actions/runs/RUN_ID/jobs?per_page=100
actions/runs/RUN_ID/artifacts?per_page=100
actions/jobs/JOB_ID/logs
actions/artifacts/ARTIFACT_ID/zip
releases/tags/v5.0.5-git.1
```

Select a run by exact `head_sha`, not merely branch or newest ID. Require `status=completed` and appropriate successful job conclusions. Download each selected artifact by its ID; check the artifact name contains the expected full source SHA, it is not expired, and its manifest source SHA matches. Authenticate API calls, then strip Authorization before following storage redirects.

## Root-owned delivery sequence

All commands below use the three existing sibling integration worktrees. Stage only explicitly reviewed paths. Workers do not touch the index.

1. Finish plugin source, meaningful tests, contract and cloud workflow. Commit reviewed source paths and record `$PluginSource = git rev-parse HEAD`. Push only GitHub:

   `git -C D:/MyNewProjects/_wt/studio-git-integration/qfli_git push origin HEAD:refs/heads/release/studio-git-ui-20261120`

2. Find the plugin Actions run whose `head_sha` equals `$PluginSource`. Wait for fresh host/API/Dart/native/example checks. Resolve failures from job logs without local execution. Record `$PluginRun` and its URL.

3. Download the Android, OHOS and iOS artifacts from this exact run into a task-owned cloud-artifacts directory. Extract each ZIP into its own platform directory, rejecting absolute or traversal ZIP paths. Do not reuse old release assets.

4. Import all three platforms in ONE invocation. Separate invocations overwrite the native lock instead of merging it:

```powershell
python tool/import_artifacts.py --artifact $AndroidArtifact --artifact $OhosArtifact --artifact $IosArtifact --commit $PluginSource --run $PluginRunUrl
```

   Run from the plugin integration worktree. This is artifact import and hash/provenance verification, not local compilation or test execution. Review exact binary changes, then commit the generated platform files plus `native_libs.lock.json`. Record the full `$PluginArtifact` commit and push it to the same GitHub branch.

5. Set core's `qfli_git` dependency URL to the GitHub repository and `ref` to `$PluginArtifact`. Commit reviewed core files and dependency lock if tracked. Push:

   `git -C D:/MyNewProjects/_wt/studio-git-integration/qfli_studio_core push github HEAD:refs/heads/release/studio-git-ui-20261120`

   Record `$CoreCommit`. Current `core-check.yml` triggers all branches and runs the full suite under pinned OHOS Flutter. Pi D should also provide a meaningful Git/native check route where appropriate. Inspect the exact SHA's full cloud result.

6. Set app workflow `CORE_REF` to `$CoreCommit`. Preserve Java `60d97c783f29da767fafe503980812101f6aa61f`. The app intentionally uses the portable sibling dependency `path: ../qfli_studio_core`; immutable checkout is supplied by `CORE_REF`. Do not replace this architecture with a local absolute path.

7. Commit reviewed app workflow/tooling/manifests, record `$AppCommit`, and push:

   `git -C D:/MyNewProjects/_wt/studio-git-integration/qflistudio push github HEAD:refs/heads/release/studio-git-ui-20261120`

   Inspect branch cloud checks and installer matrix. Confirm no remaining placeholder pins or old API payloads.

8. Recheck remote tag collision immediately before creating the preview tag. Create `v5.0.5-git.1` on the reviewed `$AppCommit` and push that explicit tag only to `github`. Never push a CNB tag. Never move an existing tag.

9. Wait for the tag run's complete verification/installer matrix and publication. Check release asset count, checksums, native API v2 exports, CA payload, plugin/core/app/source provenance and actual archive contents. The old baseline has eleven Studio target archives plus the Windows assistant archive. Report signing/device limitations exactly as recorded by the artifacts.

The source commit, native artifact commit, core commit, app commit, preview tag, run ID and asset URLs must remain distinct evidence. No new Git installer exists until this sequence reaches the successful tag release.
