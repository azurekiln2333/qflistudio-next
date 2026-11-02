# W3 release implementation

1. Inspect the version sources, local toolchain, and signing profile types.
2. Align the app and HTTP profile to 5.0.1/5000001.
3. Test version consistency and run a release-mode trial build.
4. Wait for the coordinator's explicit test-green notification.
5. Build and verify the final signed HAP. Record its SHA256.
6. Record device smoke as deferred until an explicit unlock notification.
7. Commit explicit owned paths and append the required Result.

## Validation plan

- Run the release consistency test and analyze changed Dart files.
- Run the content validator required by the frontend release contract.
- Preserve the original SHA256 of `ohos/build-profile.json5`.
- Verify the signed artifact's version, profile type, and signature.
- Record the coordinator's full-suite result separately from local checks.
- Run the controlled Chinese linter on task documents.

## Progress

- 2026-11-03: Read the PRD and applicable compliance/build contracts.
- Found both debug and release provisioning profiles for the app bundle.
- Requested the coordinator's test-green notification before the final build.
- Aligned pubspec, the OHOS manifest, and the HTTP client profile.
- `flutter test --no-pub test/release_version_test.dart --reporter expanded`:
  1 passed.
- `dart analyze lib/main.dart test/release_version_test.dart`: no issues.
- `dart run tool/validate_content.dart`: passed, 1820 tutorials and 1820 examples.
- Trial `assembleHap` with `buildMode=release`: passed, 42 tasks executed.
- The Flutter Hvigor plugin overrides manifest versions from ignored
  `ohos/local.properties`. Synchronized that local file to 5.0.1/5000001.
  The first trial's generated manifest was 5.0.0/5000000. It is not the final HAP.
- Device preflight layout contained `ScreenLockRootComponent` and
  `ScreenLockWidgetView`. Stopped device work without installing or starting
  the app. Reported this to the coordinator.
- The aligned trial build passed with 42 tasks. Its generated HAP reports
  `versionName=5.0.1`, `versionCode=5000001`, and `debug=false`.
- Trial signing with the existing `releaseKey` passed. `verify-app` confirmed
  the release profile, code signatures, package digest, and permission signature.
  This trial artifact is not the final package.
- The original `ohos/build-profile.json5` SHA256 remains
  `ca364510a82e457cd302f00c04a4eee826b29f2c8ca2a74af19ce8eb2d3eac56`.
- The aligned trial was signed and verified separately at
  `D:/AppData/Local/Temp/qfli-w3-release/qflistudio-5.0.1-5000001-trial-release-signed.hap`.
  Its SHA256 is
  `53b39fa9b4006b4e390b396dfd25d8e7a40d79862b32b9273289e30419b65a18`.
  It was recorded as a trial artifact before the test-green notice.
- 2026-11-03: Received the coordinator's explicit test-green release approval.
  Verified the recorded final results: core 1363 passed, 9 skipped, 0 failed.
  Main app 8 passed, 0 failed.
- Verified `offlineOnly` is absent from the production main app profile.
  The coordinator confirmed its removal in `646c8e9`.
- Final build source: qflistudio `20382e2`, shared core `6ac1442`.
  Shared-core worktree is clean. Signing configuration matches its original hash.
- Device smoke remains deferred by the coordinator's explicit instruction.
  This packaging turn will perform no device operations.

## Local build commands

Run from `D:/MyNewProjects/qflistudio/ohos` with the installed DevEco SDK/JBR
and the temporary OHPM wrapper used by the repository's build environment.

```powershell
$env:DEVECO_SDK_HOME = 'D:/ProgramFiles/Huawei/DevEco Studio/sdk'
$env:JAVA_HOME = 'D:/ProgramFiles/Huawei/DevEco Studio/jbr'
$env:ohpmBin = Join-Path $env:TEMP 'qfli-w3-release/ohpm.bat'
& 'D:/ProgramFiles/Huawei/DevEco Studio/tools/node/node.exe' `
  'D:/ProgramFiles/Huawei/DevEco Studio/tools/hvigor/hvigor/bin/hvigor.js' `
  --mode module -p module=entry@default -p product=default `
  -p buildMode=release assembleHap --no-daemon --no-incremental --analyze=false
```

The default product uses the existing debug identity. A machine-local helper
at `%TEMP%/qfli-w3-release/sign-existing.cjs` signs the unsigned release build
with the existing `releaseKey`. It loads credentials in memory using the
installed Hvigor decoder and invokes SDK `hap-sign-tool.jar sign-app`.
It does not rewrite the signing configuration or export credential values.
`verify-app` extracts verification materials only under `%TEMP%`.

## Result

Status: **completed**, verified at 2026-11-03 04:16 +08:00.
The coordinator confirmed that tests are green and authorized the final build.
Rebuilt the HAP after that notification and verified its release signature.
The coordinator requested task completion with device smoke deferred until an
explicit `设备已解锁` notification.

### Commit

- `d58f72e` — `chore(release): align version 5.0.1 across app manifests and HTTP headers`
- `20382e2` — `docs(release): record the signed trial and pending test gate`

Build source: qflistudio `20382e2`, shared core `6ac1442`.
Application sources remained unchanged throughout the final build.
The main app retains its online profile after `646c8e9` removed `offlineOnly`.

### Artifact

| Field | Verified value |
| --- | --- |
| Version name | `5.0.1` |
| Version code | `5000001` |
| Pubspec version | `5.0.1+5000001` |
| HTTP header | `harmonyos-app/5.0.1` |
| Final HAP absolute path | `D:/MyNewProjects/qflistudio/ohos/entry/build/default/outputs/default/qflistudio-5.0.1-5000001-release-signed.hap` |
| Final HAP SHA256 | `788fe80a0dcea38d089a4e94212aa94d0b36a912930b5cc809dc2232616c1511` |
| Final HAP size | `83698118` bytes |
| Signing type | **release**, existing `releaseKey`, AppGallery distribution profile |
| Build mode | `release`. Generated HAP metadata has `debug=false` |
| Signing material | Existing local files. No new material required |

The versioned HAP above is the final signed package for this task.
The earlier trial artifact remains separate under `%TEMP%`.
The generated default `entry-default-signed.hap` uses the debug identity.
Use the versioned release-signed path above for the final artifact.

### Commands and results

- `flutter test --no-pub test/release_version_test.dart --reporter expanded`:
  **1/1 passed**, including manifest/profile/header consistency.
- `dart analyze lib/main.dart test/release_version_test.dart`:
  **no issues found**.
- `dart run tool/validate_content.dart`: **passed**.
  All content types meet the release minimum. Totals are 1820 tutorials and
  1820 examples.
- `hvigor.js --mode module -p module=entry@default -p product=default
  -p buildMode=release assembleHap --no-daemon --no-incremental --analyze=false`:
  **passed**, 42 tasks executed in 1 minute 17.180 seconds on the final build.
  Existing ArkTS warnings remain in the build log.
- `node %TEMP%/qfli-w3-release/sign-existing.cjs releaseKey <unsigned-hap>
  <final-release-signed-hap>`: **passed** using existing credentials in memory.
- SDK `hap-sign-tool.jar verify-app`: **passed**.
  It verified the release profile, code signatures, package digest, and
  permission signature.
- Final HAP metadata/hash check: **passed**.
  Bundle is `com.azurekiln.qflistudio`. Version is `5.0.1/5000001`.
  The HAP has `debug=false`. Its verified embedded profile is `release`
  with `app_gallery` distribution.
- `python scripts/ste-lint-zh.py <task design.md> <task implement.md>`:
  **passed**, no controlled Chinese violations.
- Full-suite evidence from `11-02-fix-test-suites/implement.md`, confirmed by
  the coordinator before the final build:
  `qfli_studio_core` **1363 passed, 9 skipped, 0 failed**.
  `qflistudio` **8 passed, 0 failed**.

Final build log: `D:/AppData/Local/Temp/qfli-w3-release/final-build.log`.
Final signature verification log:
`D:/AppData/Local/Temp/qfli-w3-release/final-verify.log`.

The signing invocation uses the local helper documented above. Verification:

```powershell
$finalHap = 'D:/MyNewProjects/qflistudio/ohos/entry/build/default/outputs/default/qflistudio-5.0.1-5000001-release-signed.hap'
& 'D:/ProgramFiles/Huawei/DevEco Studio/jbr/bin/java.exe' -jar `
  'D:/ProgramFiles/Huawei/DevEco Studio/sdk/default/openharmony/toolchains/lib/hap-sign-tool.jar' `
  verify-app -inFile $finalHap `
  -outCertChain (Join-Path $env:TEMP 'qfli-w3-release/final-certchain.cer') `
  -outProfile (Join-Path $env:TEMP 'qfli-w3-release/final-profile.p7b')
Get-FileHash -LiteralPath $finalHap -Algorithm SHA256
```

### Device smoke

Status: **deferred by coordinator instruction**.
Target: `192.168.68.207:46551`.
Earlier preflight text contained `ScreenLockRootComponent` and
`ScreenLockWidgetView`. The coordinator confirmed that the device remains
locked and explicitly prohibited device operations during final packaging.
This packaging turn performed no device operations.
No application was installed, uninstalled, or started by this task.
No screenshots were read.

Startup, the settings agreement/deletion entries, and Huawei-only login are
**not verified on this final build**. Resume smoke only after an explicit
`设备已解锁` notification. Use `install -r` and preserve installed applications.
Task completion records the authorized packaging scope, not a device-smoke pass.

### User actions and remaining work

- Unlock the specified device and send `设备已解锁` for the later smoke run.
- Publish the hosted user agreement in AGC and provide its HTTPS URL.
  `userAgreementUrl` is currently empty in the shared core.
  Configure that URL and rebuild to make the entry open the published document.
- Confirm the hosted privacy declaration and complete AGC version submission
  using the final release artifact.
- Release signing material is already available. No signing-material request
  remains for the user.
- Final packaging is complete. Device smoke is the only deferred technical
  verification in this task.

`ohos/build-profile.json5` remains byte-identical to its initial local state.
No signing material, credential, HAP, or signing configuration was committed.
