# Published remote preview

Release: https://github.com/azurekiln2333/qflistudio-next/releases/tag/v5.0.5-remote.2

Published at 2026-11-20 18:42:10 +08:00 as a prerelease, not a draft.
The authorized cloud release workflow is complete. Physical-device acceptance
remains with the user; no device or live-provider result is claimed.

## Exact sources

- App: `6d1b96d7118740f71e5dadf393cc8bd58238b6af`.
- Core: `72c0b0955e4ddd5215dc818327fa5a67a4be22f7`.
- Java receiver contract: `60d97c783f29da767fafe503980812101f6aa61f`.
- App/core development branch: `release/v5.0.5-preview.1`.
- Java branch: `release/studio-v5.0.5-interop`.
- App annotated tag: `v5.0.5-remote.2`.
- Only GitHub received these release pushes. Main was not merged by this task.

## Cloud evidence

Final run: https://github.com/azurekiln2333/qflistudio-next/actions/runs/44720423052

All 17 jobs passed, including publication. This covers full app/core analysis
and tests, Java host receiver regressions, Node tests on Windows/Linux,
Windows assistant tests and build, and all 11 main application targets.

Core JSON reports 2579 successful testDone records and 26 skips, with no
failure/error records and final success=true. Counts include loading/setup.
The packaged assistant also ran the scripted-provider protocol E2E and a real
sidecar first-run pairing/request/reply smoke. The latter validates the LAN
address in the pairing URI but connects the synthetic phone over loopback.

Published assets: 11 app ZIPs, 1 Windows assistant ZIP and SHA256SUMS.
The publisher checked source/version/SDK/run provenance and each package's
internal hashes before upload. A separate post-publication check downloaded
SHA256SUMS and matched all 12 ZIP entries to GitHub's published asset digests.
It also verified the checksum file's digest. All assets are uploaded.

The Android arm64 ZIP was downloaded after publication. Its size and SHA-256
match GitHub. Its BUILD_INFO identifies the final app/core commits and run.
It contains `QFLIStudioN-5.0.5-android-arm64-v8a.apk`.

Evidence is under `reports/cloud/`: `tag2-run.json`, `tag2-jobs.json`,
`tag2-core.log`, `tag2-core.failures.json`, `tag2-publish.log`,
`release-remote2.json`, `release-remote2-verification.json`,
`release-remote2-SHA256SUMS`, and `android-arm64-downloaded.json`.

## Installation

User steps: [install-preview.md](install-preview.md).

- Android arm64: https://github.com/azurekiln2333/qflistudio-next/releases/download/v5.0.5-remote.2/qflistudio-5.0.5-android-arm64-v8a.zip
- Windows x64 app: https://github.com/azurekiln2333/qflistudio-next/releases/download/v5.0.5-remote.2/qflistudio-5.0.5-windows-x64.zip
- Windows x64 assistant: https://github.com/azurekiln2333/qflistudio-next/releases/download/v5.0.5-remote.2/qfli-remote-assistant-5.0.5-windows-x64.zip

The assistant ZIP includes Node and production dependencies. Extract the whole
archive and run `Start-QFLI-Remote.cmd`. Read the relay address and short code
on its Pairing page. On the phone, open Tools > Remote Computer > Enter short
code, enter the address/code and connect. Camera scanning is not implemented.

Android uses a debug certificate and cannot replace a differently signed app.
Back up projects before changing an existing installation. Windows is unsigned.
macOS has ad-hoc signing and no notarization. iOS/OHOS need signing before
installation. The Java receiver changes have host checks only, not a new Java
installer or a target-device execution result.

## Scope and preservation

Includes the latest reviewed Studio base, integrated thinking-stream UI,
remote terminal/Herdr/Claude/Codex module, and Windows assistant. Studio's
Git plugin UI is not integrated. The server thinking branch was not deployed.

No local tests, builds, services, emulators or device runs were executed.
Local checks were limited to source review, formatting, type/static analysis,
syntax, Git whitespace checks and downloaded artifact inspection.

The final original-source check at 2026-11-20 18:50:01 +08:00 reports no change
to HEAD, index, tracked-file hashes or dirty status in
`D:/MyNewProjects/cloudterminal`. All three isolated release worktrees are clean.

The earlier `.1` tag is retained. Its tests/builds passed, but publication failed
on a single-artifact extraction directory mismatch. No `.1` release exists.
The `.2` tag corrects that publisher path and passed a new complete cloud run.
The duplicate branch run 44720409250 was cancelled only after confirming the
same commit had an active complete tag workflow.
