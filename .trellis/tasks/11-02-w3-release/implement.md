# W3 release implementation

1. Inspect the version sources, local toolchain, and signing profile types.
2. Align the app and HTTP profile to 5.0.1/5000001.
3. Test version consistency and run a release-mode trial build.
4. Wait for the coordinator's explicit test-green notification.
5. Build and verify the final signed HAP. Record its SHA256.
6. Install on the specified device and collect text-only smoke evidence.
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
  It remains a trial artifact pending the coordinator's test-green notice.

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

Status: **blocked before final packaging**, checked at 2026-11-03 04:03 +08:00.
Version changes and signed release-mode trial builds are complete.
The PRD requires the coordinator's explicit test-green notice before the final
HAP. That notice has not arrived. The 30-minute wait for `w37:p4` timed out.
The coordinator confirmed that service acceptance passed and client test
repairs remain pending. This task is not marked completed.

### Commit

- `d58f72e` — `chore(release): align version 5.0.1 across app manifests and HTTP headers`

### Artifact

| Field | Verified value |
| --- | --- |
| Version name | `5.0.1` |
| Version code | `5000001` |
| Pubspec version | `5.0.1+5000001` |
| HTTP header | `harmonyos-app/5.0.1` |
| Final HAP | Not produced. Awaiting the coordinator's test-green notice |
| Trial HAP absolute path | `D:/AppData/Local/Temp/qfli-w3-release/qflistudio-5.0.1-5000001-trial-release-signed.hap` |
| Trial HAP SHA256 | `53b39fa9b4006b4e390b396dfd25d8e7a40d79862b32b9273289e30419b65a18` |
| Signing type | **release**, existing `releaseKey`, AppGallery distribution profile |
| Build mode | `release`. Generated HAP metadata has `debug=false` |
| Signing material | Existing local files. No new material required |

The trial artifact is verification evidence. It is not the final AGC delivery.
After the test-green notice, rebuild against the tested source, sign the final
HAP, verify it, and record its final path and SHA256 here.

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
  **passed**, 42 tasks executed in 1 minute 17 seconds on the aligned trial.
  Existing ArkTS warnings remain in the build log.
- `node %TEMP%/qfli-w3-release/sign-existing.cjs releaseKey <unsigned-hap>
  <trial-release-signed-hap>`: **passed** using existing credentials in memory.
- SDK `hap-sign-tool.jar verify-app`: **passed**.
  It verified the release profile, code signatures, package digest, and
  permission signature.
- `python scripts/ste-lint-zh.py <task design.md> <task implement.md>`:
  **passed**, no controlled Chinese violations.
- Full client test suite: **pending with the coordinator and w37:p4**.
  Local passing checks do not establish a full-suite pass.

### Device smoke

Target: `192.168.68.207:46551`.
`hdc ... shell uitest dumpLayout` succeeded during preflight.
The text contained `ScreenLockRootComponent` and `ScreenLockWidgetView`.
Stopped device operations immediately and reported the lock to the coordinator.
No application was installed, uninstalled, or started by this task.
No screenshots were read.

Startup, the settings agreement/deletion entries, and Huawei-only login are
**not verified on this build**. Resume smoke after an unlock notification and
the final build. Use `install -r` and preserve installed applications.

### User actions and remaining work

- Keep the specified device unlocked for the final smoke run.
- Publish the hosted user agreement in AGC and provide its HTTPS URL.
  `userAgreementUrl` is currently empty in the shared core.
- Confirm the hosted privacy declaration and complete AGC version submission
  after the final artifact is available.
- Release signing material is already available. No signing-material request
  remains for the user.
- The coordinator must announce that client tests are green. Final packaging
  and device smoke remain release-worker follow-up work.

`ohos/build-profile.json5` remains byte-identical to its initial local state.
No signing material, credential, HAP, or signing configuration was committed.
