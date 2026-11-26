# Release CI implementation

Date: 2026-11-20

Worktree: `D:/MyNewProjects/_wt/release-v5.0.5/qflistudio`

The coordinator owns commits, pushes, final core SHA selection, and tags. This worker has not committed, pushed, run tests, built packages, or launched a local companion.

## Changed files

- `.github/workflows/app-installers.yml`: release branch trigger, 5.0.5 metadata, pinned default Flutter 3.50.0, pinned core fallback, strict full verification jobs, and gated prerelease publication.
- `pubspec.yaml`: `5.0.5+5000005`.
- `ohos/AppScope/app.json5`: version name `5.0.5` and code `5000005`.
- `lib/main.dart`: client HTTP profile version `5.0.5`. The existing release-version test requires this to match the package metadata; the merged source still had `5.0.1`.
- `companion/remote_agent/scripts/e2e.ts`: adds `--demo`, using the existing scripted provider with the real relay and AgentCore. It checks pairing, streaming deltas, tool permissions, tool results, question answers, and final success. Subscription precedes the prompt, avoiding loss of fast streamed events. Cleanup waits for the child to stop before removing temporary directories. Pair codes and credentials are not printed by the harness.

## Verification jobs

`verify-flutter` runs full core and app analyze/test as separate matrix entries. It uses the pinned OHOS SDK with the real source intact, because both suites resolve the OHOS platform enum by name. The app's nested Windows assistant gets its own package configuration before recursive analysis. Core tests receive the app and Java receiver as sibling checkouts.

`verify-companion` runs on Ubuntu 24.04 and Windows 2022 with Node 24.14.1. It performs `npm ci`, type checking, all tests, and `npm run e2e -- --demo --timeout 60`. This protocol E2E does not validate a live Claude account and consumes no paid provider usage. The existing default live E2E remains available for explicitly authorized manual use.

`verify-assistant` runs on Windows 2022 with official Flutter. It installs the Node sidecar dependencies before all assistant tests so the IPC test's dependency condition does not silently skip it.

Analysis and test failures remain failures. Later independent test steps still run after an earlier analysis failure to provide useful logs. The workflow does not consult the old known-failure list or allow failures through.

## Publisher

Only `v5.0.5-remote.*` tags can run the publisher. The job requires all three verification jobs and all six installer jobs, including their matrix targets. It checks the exact set of eleven artifact names, version, app/core commits, SDK version/commit/mode, run URL, build mode, signing metadata, and the device-validation declaration. It checks each artifact's SHA256SUMS and archives targets separately. The GitHub Release is a prerelease with `latest=false`. Write permission is limited to the publishing job.

The newly used `actions/download-artifact` pin is `9000827ccba6bdab643e8b6fd33ac0654aef8333` (v8.0.2). Its official `action.yml` declares `using: node24`.

## Static inspection

- Parsed the complete workflow with PyYAML BaseLoader.
- Parsed all 13 new Bash run blocks using Git for Windows Bash `-n`; no commands in those blocks were executed.
- Parsed the publisher's inline Python with `ast.parse`.
- Confirmed full SHA pins for every external action in the workflow.
- Confirmed eight core setup calls use the pinned fallback: six builders and two verification setup calls.
- `git diff --check` passes.
- No local dependency installation, TypeScript check, Flutter analysis, test, or build was run. Cloud jobs must provide execution evidence.

## Coordinator follow-up

1. Replace temporary `CORE_REF` `c51be377e20275b13eb147219d540f8b787ad08d` with the final pushed core commit before committing the release workflow.
2. Inspect cloud failures and fix their owners. Do not weaken the publisher gate.
3. The fixed Java checkout is public HEAD `18b8c661c3681756a85bce8666fbcc280d033117`. Its committed receiver emits `progress` and lacks `formatAggregate`. The current core contract test requires aggregated output and rejects `progress`. The local Java checkout has uncommitted interop edits, which this worker did not copy or alter. This is a real cross-repository contract mismatch and will block the full suite until addressed.
4. Device validation and production signing remain unverified. The release notes state the exact signing limitations.
