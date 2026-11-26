# 5.0.5 preview release

User authorization: push code, create a tag, run all verification and builds in CI, and provide installation artifacts. Do not run local tests or builds. The original CloudTerminal workspace remains read-only.

Release bases: app b7272bc and core cbaa4a4. Separate worktrees are under `D:/MyNewProjects/_wt/release-v5.0.5`.

Scope: latest shipped Studio features, completed thinking branches, remote computer module, and desktop companions. Git plugin integration is not implemented and is not a release claim. Live provider/device acceptance is not implied by mock protocol tests.

Published development snapshots as of 2026-11-20 18:20 +08:00:
- App remote/cloudterminal-app: ea1da19.
- Core remote/cloudterminal-core: b8d08a6.
- App release/v5.0.5-preview.1: 6d1b96d7118740f71e5dadf393cc8bd58238b6af.
- Core release/v5.0.5-preview.1: 72c0b0955e4ddd5215dc818327fa5a67a4be22f7.
- Java release/studio-v5.0.5-interop: 60d97c783f29da767fafe503980812101f6aa61f.

Cloud evidence:
- Core 44717746804 passed: 2579 successful testDone records, 26 skips, no failures/errors, final success=true. Counts include loading/setup records.
- App branch 44717854168 passed every verification and all 11 main installer targets, plus Windows assistant packaging. Windows CRT selection/staging and route-wait corrections are validated in cloud.
- Annotated tag v5.0.5-remote.1 was pushed to GitHub on app a4d1efd after branch success. Tag run 44718811722 passed all 16 build/verification jobs and all 11 main-artifact source/hash checks, then failed because a single pattern-matched artifact extracted directly into the download path. No release was created.
- App 6d1b96d corrects the single-assistant download with exact artifact name and named destination. It keeps every provenance/hash check and clarifies manual phone pairing. New annotated tag v5.0.5-remote.2 starts full tag run 44720423052. Old tag .1 is retained unchanged.
- Duplicate branch run 44720409250 was cancelled after verifying the exact same commit and active .2 tag run, to give the final release pipeline capacity. Publication is not complete yet.
- Java 44713004619 passed the native startup and real receiver orchestration tests with OHOS API doubles.
- App 44715221757 passed app verification, Java contracts, both Node platforms (Windows: 172 passed), and Windows assistant tests/build/package. The packaged first-run sidecar smoke passed.
- All targets except Windows ARM64 passed in this run. ARM64 built and passed architecture checks, then its Git Bash runtime dependency step exited with STATUS_SINGLE_STEP. The reviewer also found an incorrectly quoted CRT glob that selected an old fallback runtime.
- Core 44714998138 recorded 2571 successes, 26 skips, and 8 errors. The new route-wait helper registered inherited dependencies on arbitrary ancestor elements, including inherited elements themselves, causing framework assertions and cascading failures. A narrower Navigator-context lookup is being prepared.
- Earlier app run 44710368966 produced all 11 main app artifacts; those artifacts are not substitutes for the final tagged run.
- Source preservation check at 2026-11-20 18:00:10 +08:00 found no HEAD, index, tracked-file or status changes in the original cloudterminal checkout.

Final outcome:
Tag run 44720423052 passed all 17 jobs and published v5.0.5-remote.2 at
2026-11-20 18:42:10 +08:00. All 12 ZIP digests match the downloaded checksum
manifest. The Android arm64 download also passed byte/hash/provenance inspection.
See `reports/release-final.md` for links, evidence and installation limitations.
Only physical-device acceptance remains with the user.

Only GitHub receives this preview tag. CNB tag workflows also deploy unrelated backend services, which is outside this release action. Android uses a test certificate. iOS/OHOS require signing. Do not copy local signing material.

Static diff checking excludes preserved terminal capture whitespace and vendored upstream whitespace. Their bytes are intentional source inputs, not formatting changes.
