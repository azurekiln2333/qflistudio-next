# Cloud acceptance — GitHub main migration

Date: 2026-11-26 UTC. Repository: `azurekiln2333/qflistudio-next`.
Task: `.trellis/tasks/11-26-github-main-migration`.
Agent: `w65:p4`. Model: `gpt-6.1-sol`, verified through `PI_MODEL`.

## Verdict and exact boundary

**The required cloud jobs passed for App commit `da74782075d4bb31f92546c18031c340df1adb21`.**

- Workflow: **App installers**, push to `main`, run **45908020703**, attempt **1**.
- Created: **2026-11-26 22:57:49 UTC**. Terminal update: **23:09:04 UTC**. Terminal success observed through the API at **23:13:42 UTC**.
- **19 jobs total: 18 success, zero failure, one skipped.** All 18 required jobs passed. The separate publication job was skipped because its release-tag condition was false for this main push. This run did not publish a release.
- Six app platforms produced **11 architecture-specific app artifacts**. One Windows assistant artifact and seven diagnostics artifacts bring the total to **19**.
- Every artifact API record was nonempty, unexpired, and associated with this exact run and SHA. Exact IDs, names, SHA-256 API digests, byte sizes and expiry times are recorded in `cloud-acceptance.json`.

This is an exact-SHA CI result, not certification of later documentation commits. The lead owns the planned metadata-only descendant run, final pull, source/target comparison and handover. Record that final result in Herdr/final response rather than creating an endless evidence-commit cycle.

## Method and restrictions

Evidence came from read-only authenticated `gh api` GETs, existing cloud job logs streamed into memory, and source inspection. No artifact archive was downloaded or opened. No local build, test, analyzer, dependency resolution, installation, WSL or container ran. No workflow was triggered, rerun or cancelled. No Git state was changed by this agent. No credential contents were read.

Only this report and `cloud-acceptance.json` were written. Actor/email fields, full raw metadata and signed log-redirect URLs are excluded. TLS/redirect failures were treated as monitoring errors, not CI failures. Requests used bounded retries. Fresh read-only no-cache log requests later supplied exact app/Core/Java/companion counts. On the lead's stop instruction, network reads ended; remaining counts are marked uncollected, not inferred from previous runs. No model turn-limit warning was observed; a cumulative turn count is unavailable.

## Complete job manifest

All jobs below belong to run `45908020703`, attempt 1.

| Job | ID | Hosted runner | Conclusion |
| --- | --- | --- | --- |
| Require GitHub-hosted execution | 140209376909 | ubuntu-24.04 | success |
| Verify Node companion on windows-2022 | 140209403712 | windows-2022 | success |
| Verify pinned Java foreground receiver | 140209403722 | ubuntu-24.04 | success |
| Resolve the Flutter stable version | 140209403759 | ubuntu-24.04 | success |
| Verify app with OHOS Flutter | 140209403763 | ubuntu-24.04 | success |
| Verify Node companion on ubuntu-24.04 | 140209403786 | ubuntu-24.04 | success |
| Verify core with OHOS Flutter | 140209403818 | ubuntu-24.04 | success |
| Studio Git iOS integration test | 140209464686 | macos-15 | success |
| Verify and package Windows assistant | 140209464732 | windows-2022 | success |
| iOS unsigned IPA | 140209464745 | macos-15 | success |
| macOS x86_64 DMG | 140209464751 | macos-15 | success |
| Windows x64 installer | 140209464761 | windows-2022 | success |
| macOS arm64 DMG | 140209464782 | macos-15 | success |
| Linux x64 packages | 140209464800 | ubuntu-22.04 | success |
| Linux arm64 packages | 140209464806 | ubuntu-22.04-arm | success |
| Windows arm64 installer | 140209464811 | windows-11-arm | success |
| Android release APKs | 140209464817 | ubuntu-24.04 | success |
| OHOS unsigned HAP | 140209464944 | ubuntu-22.04 | success |
| Publish verified release or preview | 140213132333 | not allocated | skipped: release-tag condition |

Skipped individual steps are not failed jobs. App skips Core-only Java checkout/fixture alias; Core skips the app-only helper-script step. Successful suites skip failure-report steps. Windows x64 skips the ARM64 batch build path, while ARM64 skips the x64 build path. OHOS skips failure-only hvigor diagnostics. Exact skipped-step names are retained in JSON.

## Current-run tests

Flutter counts use non-hidden `testDone` events. Hidden harness events are excluded. Skips are not counted as executed passes. Node counts come from actual printed summaries. Platform duplicates are not deduplicated into one global total.

| Check | Passed | Failed | Skipped | Evidence/qualification |
| --- | ---: | ---: | ---: | --- |
| Full app suite | **24** | 0 | 0 | Current job 140209403763 JSON stream, `done.success=true`; six hidden completions excluded. Herdr replay-and-keys test explicitly succeeded. |
| Full Core suite | **3,326** | 0 | **27** | Current job 140209403818 JSON stream, `done.success=true`; 359 hidden completions excluded; zero error events. Analyzer log says `No issues found`. |
| Java receiver host contracts | **12** | 0 | 0 | Current Node host-test summary; not a Java/HarmonyOS device-runtime test. |
| Windows companion | **242** | 0 | **1** | 243 total; cancelled/todo zero. Scripted-provider E2E passed. |
| Linux companion | **242** | 0 | **1** | 243 total; cancelled/todo zero. Scripted-provider E2E passed. |
| App payload helper suite | **19** | 0 | not separately reported | Current Python summary: `Ran 19 tests in 0.035s`, `OK`. Other helper-suite totals were not collected. |
| Windows assistant / sidecar | uncollected | uncollected | uncollected | Current job succeeded. Exact current test counts were not collected before network reads stopped. |
| Git iOS simulator integration | uncollected | uncollected | uncollected | Current job succeeded, completed 23:09:03 UTC. Exact current test count was not collected. This is not physical-device validation. |

The app analyzer step passed. A successful analyzer using `--no-fatal-infos` does not itself mean zero informational diagnostics. No previous-run counts fill the two uncollected rows.

## Platform/signing boundary

| Platform / targets | Produced CI packages | Signing and validation limits |
| --- | --- | --- |
| Windows x64, ARM64 | Installer/portable artifacts | Unsigned; no Authenticode production-signing claim. Successful package jobs do not establish physical-device acceptance. |
| Linux x64, ARM64 | DEB/archive artifacts | Unsigned. |
| macOS x86_64, ARM64 | DMG artifacts | Ad-hoc signing, not notarized. |
| Android x86_64, armeabi-v7a, arm64-v8a | Release-mode APK artifacts | **CI test signing with a generated debug key. Non-production, not a store release key.** No AAB/store-signing claim. |
| iOS ARM64 | Unsigned IPA artifact | Requires Apple signing and provisioning before installation. |
| OHOS ARM64 | Unsigned HAP artifact | Requires HarmonyOS certificate/profile before installation. |

These are not six production-signed, store-ready or physically device-tested releases. Physical-device/full installed-app behavior is not established. The package pipeline's inspections are cloud evidence, not an independent local unpack/re-hash by this agent.

## Pins and adaptations

- App: `da74782075d4bb31f92546c18031c340df1adb21`.
- Core: `476a30acee21dc486ee2849dd8064a7be665e4d5`. Canonical sibling directory: `qflistudio-core`. Dart package/import identity remains **`qfli_studio_core`**.
- Java contract: `60d97c783f29da767fafe503980812101f6aa61f`.
- OHOS Flutter: **3.41.10-ohos-1.0.1**, commit `adaf911c35c9136a7d18fc424d714c9ec7724e60`. Current Core log confirms the SDK revision.
- Official Flutter configured version: **3.50.0**. The resolver job passed; its exact resolved commit log was not collected. `ab2912035e160d9cad6306df307576da6128ebdb` is the earlier audit reference only, not newly extracted current evidence.
- Git plugin: **0.1.0**, commit `697291a27818612ae9dc53d83d4f99fa5887908e`, API **3**. Current Core setup log confirms the plugin commit. Existing native-source pin: `194a6c9dd70873a472e441b67875766541572372`; not independently extracted from downloaded artifacts.
- Android: NDK **27.0.12077973**, CMake **3.22.1**. OHOS tools **26.0.0.821**, API **26**. Configured Node **24.14.1**.

Explicit adaptations:

1. **Pinned Core fixture alias, runner only:** Core verification creates `qfli_studio_core -> qflistudio-core`. The pinned ArkTS contract test hardcodes its own old sibling directory. The alias changes neither Core source nor assertions and does not rename the canonical checkout or Dart package. Owner-accepted temporary compatibility remains necessary until Core removes that self-path assumption.
2. **App UTF-8 test decoder:** terminal output uses streaming `utf8.decoder`; the exact non-ASCII replay assertion remains. Current replay-and-keys test passes.
3. **App asynchronous key delivery:** the fake completes a `Completer` from `sendKeys`; the test waits up to two seconds and retains the exact `up` assertion. Core's 12 ms batching delay is unchanged. This is synchronization of the test with the existing adapter, not a removed assertion.
4. **Standard-Flutter runner compatibility:** existing non-OHOS setup patches the shared Core's OHOS-only Huawei view on the runner. OHOS full App/Core verification disables that patch. Original Core commit provenance does not imply a byte-identical standard-SDK runner tree.
5. **OHOS packaging:** runner-local signing entries are stripped. Tooling comes from the `ErBWs/ohos-sdk` third-party redistribution, not an official Huawei download channel.

Strict unchanged-lockfile reproducibility is not claimed: package resolution can warn about lock drift. Existing plugin/native provenance checks remain part of CI. The app consumes pinned Git native payloads rather than rebuilding their native source in this run. The earlier audit distinguishes failed-overall imported producer `44863517943` from independently successful pinned-plugin run `44867887807`; this report does not turn that producer history green. Language execution remains delegated through `InteropRunner`; app installer coverage is not sibling language-runtime coverage.

## Artifact API inventory

All records below were associated with run **45908020703** and SHA **da74782075d4bb31f92546c18031c340df1adb21**. All were nonempty and `expired=false`. All expiry timestamps are UTC on **2026-12-10**. **Exact SHA-256 API digests are in the JSON artifact records**, not independently recomputed installer hashes. The 19 records comprise 11 app targets, one assistant and seven diagnostics.

| Artifact name | API ID | Bytes | Expiry UTC on 2026-12-10 |
| --- | ---: | ---: | --- |
| qflistudio-5.0.14-android-armeabi-v7a | 15159655163 | 17,654,803 | 23:01:52 |
| qflistudio-5.0.14-android-x86_64 | 15159625478 | 18,052,541 | 23:01:49 |
| qflistudio-5.0.14-windows-arm64 | 15159551055 | 35,237,594 | 23:03:25 |
| qflistudio-5.0.14-android-arm64-v8a | 15159456530 | 17,922,163 | 23:01:55 |
| verification-windows-assistant | 15159196809 | 2,134 | 23:01:17 |
| qflistudio-5.0.14-macos-x86_64 | 15159051373 | 22,768,949 | 23:01:24 |
| qflistudio-5.0.14-linux-arm64 | 15158922067 | 32,293,064 | 23:00:10 |
| qflistudio-5.0.14-windows-x64 | 15158876993 | 36,577,793 | 23:00:30 |
| verification-companion-ubuntu-24.04 | 15158856758 | 8,039 | 22:59:37 |
| qflistudio-5.0.14-macos-arm64 | 15158776823 | 21,735,013 | 23:02:08 |
| qflistudio-5.0.14-ios-arm64 | 15158711861 | 18,167,730 | 23:00:56 |
| verification-flutter-app | 15158607832 | 2,269 | 23:00:12 |
| git-ios-integration-45908020703 | 15158584448 | 174,724 | 23:08:30 |
| verification-flutter-core | 15158578668 | 207,380 | 23:04:12 |
| qflistudio-5.0.14-linux-x64 | 15158513062 | 33,016,861 | 22:59:31 |
| qflistudio-5.0.14-ohos-arm64 | 15158349378 | 20,260,292 | 23:01:23 |
| qfli-remote-assistant-5.0.14-windows-x64 | 15158339469 | 186,360,180 | 23:00:57 |
| verification-java-interop | 15158314071 | 806 | 22:58:09 |
| verification-companion-windows-2022 | 15158224490 | 7,611 | 22:59:50 |

Archive-member completeness and individual installer checksums were not independently inspected. Actions artifacts have limited retention; publication was skipped, so this is not evidence of new permanent release assets.

## Prior failures — history only

- **45897093931 / `3ffde9d495f129ed8362e23d739178b69b1ceb09`:** the canonical-import scanner matched multiline Dart documentation rather than a quoted directive. Shared setup failed; skipped downstream work was not a pass.
- **45897522770 / `76e1f80ab2df6c3b1f7ae62a2648f3c52683ad11`:** app Herdr test decoded UTF-8 bytes with `String.fromCharCodes`, causing pi mojibake at line 748. Core suite failed loading because its source fixture lookup hardcoded `qfli_studio_core`.
- **45905107524 / `b1ef723958d2a4d7a77927f95f380116338cb314`:** 17 jobs succeeded, app verification failed, publication skipped. Herdr replay passed, but line 755 expected `sendKeys:w37:p14:up` while the recorded calls were `[refresh]`. Historical counts: app 23 pass/one fail, Core 3,325 pass/27 skips, assistant 12 pass, iOS integration one pass. **None of those counts substitutes for missing current counts.**
- Independent Core baseline **45689025146**, same Core SHA, used old checkout name `qfli_studio_core`; it passed 3,326 tests with 27 skips. Current acceptance was checked independently, not inherited from that baseline.

## Evidence and handoff

Sanitized evidence endpoints:

- `GET /repos/azurekiln2333/qflistudio-next/actions/runs/45908020703`
- `GET /repos/azurekiln2333/qflistudio-next/actions/runs/45908020703/attempts/1/jobs?per_page=100`
- `GET /repos/azurekiln2333/qflistudio-next/actions/runs/45908020703/artifacts?per_page=100`
- `GET /repos/azurekiln2333/qflistudio-next/actions/jobs/<job_id>/logs` (fresh read-only query; no saved archive)
- Check-run summaries were queried but contained no test counts.
- `.github/workflows/app-installers.yml` supplies tag gating, configured pins and signing conventions. `cloud-ci.md` retains the separate historical/native-provenance audit.

The lead owns committing the two reports, the metadata-only descendant's exact-SHA validation, final source/target pull and equality checks, and handover. This CI agent makes no preservation/parity claim about the tracked source files or the 129 preserved files. After report read-back, writes and network requests freeze unless the lead assigns further work.
