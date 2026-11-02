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
