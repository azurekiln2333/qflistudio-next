# Parallel clone release evidence

## Source chain

- Native source: `194a6c9dd70873a472e441b67875766541572372`.
- Native payload run: `https://github.com/azurekiln2333/qflistudio-git/actions/runs/44863517943`.
  Android, OHOS and iOS collectors succeeded. Their same-run artifacts were
  imported without changing native source or provenance. The initial host
  prerequisite failed on a stale API 2 test assertion; it did not execute smoke.
- Plugin Dart bridge and imported payloads: `e6d01736b9523baf31778f6b1983fa51dcac35e6`.
- Final plugin including host feature-probe fix:
  `697291a27818612ae9dc53d83d4f99fa5887908e`.
- Final plugin run: `https://github.com/azurekiln2333/qflistudio-git/actions/runs/44867887807`.
  Every runnable job passed. Publish artifacts was correctly skipped on a branch.
- Final Core: `c619f9ff0e83341f4efb548ea58eb7af42a9f51f`.
- Final Core run: `https://github.com/azurekiln2333/qflistudio-core/actions/runs/44868816632`.
  Full analyze and complete test suite passed.
- App: `0a649f2618517074fe0c3804c440aa03cd0e55a9`.
- App immutable tag: `v5.0.5-git.7`. Branch and tag pushed atomically to GitHub.
- The complete `v5.0.5-git.7` App run `44870753378` passed all 18 expanded
  jobs, including frozen native payload iOS integration and preview publication.

## Version 5.0.6 integration

- User explicitly requested version 5.0.6, main integration and four Pi workers.
- Four existing Herdr Pi panes C/H/G/J performed version changes, workflow
  changes, branch ancestry review and CI/provenance review.
- App: `1cea02946e5191f2a76bd8915ff0a527547f0463`, version `5.0.6+5000006`.
- App GitHub main and annotated tag `v5.0.6` were pushed atomically.
- Authoritative tag workflow:
  `https://github.com/azurekiln2333/qflistudio-next/actions/runs/44872268037`.
- Core GitHub main was fast-forwarded to the exact verified `c619f9ff` commit.
- Plugin GitHub main was fast-forwarded to the exact verified `697291a2` commit.
- App main now contains all feature history. The four named remote App topic
  branches were deleted atomically with exact SHA leases after proving every
  tip was an ancestor of the new main: `release/studio-git-ui-20261120`,
  `release/v5.0.5-preview.1`, `remote/cloudterminal-app`, `ci/app-installers`.
- A final `git ls-remote --heads github` returned only App main at `1cea0294`.
- Static YAML/version checks passed. All verification/build jobs and publication
  dependencies are unchanged. Stable tags publish normal latest releases and
  preview tags publish prereleases. Local runtime checks remain prohibited.
- Downloaded the 5.0.6 OHOS artifact and independently verified its BUILD_INFO:
  App `1cea0294`, Core `c619f9ff`, plugin `697291a2`, native source `194a6c9d`,
  API 3, plugin_pending 0. All three SHA256SUMS entries passed, including HAP.
  Canonical artifact SHA-256 matches both the GitHub API and upload log:
  `d7cbcd7f8805903ff3444e3f2885fd15800ee4efb372fb5fb18200729872d6d4`.
  The HAP remains unsigned and requires the user's certificate/profile.
- The first local artifact response retained a 3,405,762-byte failed partial
  response before the complete ZIP because curl retried into stdout. The final
  19,376,633 bytes match the exact uploaded artifact digest. Preserve the initial
  response as evidence and use `app506-ohos-artifact-verified.zip` for the exact
  archive. The local reader now uses distinct temporary files for each attempt.

## Verified behavior

- Native smoke: two simultaneous HTTPS clones both completed and each emitted
  receiving progress. API 3 library export contract passed.
- Plugin: 65 tests passed. New real-native regressions verify independent
  clone progress, final checkout progress before completion, observer exception
  isolation and cancellation isolation. Nine example tests also passed.
- Production mobile payload: static importer and native-lock verifier passed
  for ten locked files from source `194a6c9`.
- Plugin example iOS integration passed against rebuilt API 3 native source.
  App iOS gate must additionally verify the frozen committed payload.
- Core: corrected only erroneous widget hit-target and optional metadata mock
  assumptions after the first full cloud run; the final full run passed.
- Local checks were formatting, static analysis, dependency resolution, diff
  and artifact hash/provenance checks. No local runtime tests or builds ran.
- Four Herdr Pi workers implemented/reviewed assigned scopes. Independent
  reviewers checked UI/service, FFI resource ownership and release provenance.

## Host fix

libgit2's strict C90 stat probes run before its own Linux `_GNU_SOURCE` flag is
installed. The cloud host workflow now sets `CFLAGS=-D_GNU_SOURCE` before
configuration. This fixes feature visibility without forcing detected results
or changing mobile native source. The complete subsequent host run passed.

## Editor entry answer

Already present in the Core used by `v5.0.5-git.6`: horizontal editor quick bar,
Git tree icon after Ports. The Git page shows HEAD and a Branches action. Agent
mode replaces quick actions; focus mode hides them; layouts with insufficient
window height move them to the top overflow menu. Narrow width alone does not
trigger that fallback. This task did not change entry placement.

## Final publication

The authoritative 5.0.6 tag run `44872268037` completed successfully. All 18
expanded jobs passed, including complete App/Core suites, companion and Java
checks, Windows assistant, frozen native payload iOS integration, all installer
targets and final publication.

Release `https://github.com/azurekiln2333/qflistudio-next/releases/tag/v5.0.6`
is published, non-draft, non-prerelease and returned by `releases/latest`.
It contains 13 uploaded assets: eleven App target ZIPs, the Windows assistant ZIP
and the release SHA256SUMS. The publication gate validated all BUILD_INFO pins,
API 3 provenance, package checksums and assistant provenance before uploading.

Android uses a debug certificate. Windows is unsigned. macOS is ad-hoc signed
and not notarized. iOS and OHOS require signing before installation. Runtime
checks and builds ran only in GitHub Actions; no physical-device validation ran.

No implementation or publication work remains for this task.
