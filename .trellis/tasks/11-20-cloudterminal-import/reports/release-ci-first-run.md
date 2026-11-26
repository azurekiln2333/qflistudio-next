# First integrated cloud run

Date: 2026-11-20

Repository: `azurekiln2333/qflistudio-next`

Run: `44696650844`

App commit: `d56f44fc3c8f0053cd62bdd9de379b0847be56fd`

Core commit pinned by this run: `db4dadd84d2ed5dcafb9b85594d3166763035cf0`

Result: failed. The publisher was skipped. The run produced all eleven main-app installer artifacts successfully.

## Successful execution evidence

- Windows x64 and arm64 installers.
- Linux x64 and arm64 packages.
- macOS x86_64 and arm64 DMGs.
- iOS unsigned IPA.
- Android's three APK artifacts.
- OHOS unsigned HAP.
- Companion type check on Ubuntu and Windows.
- Companion scripted protocol E2E on Ubuntu and Windows. Both recorded 22 streamed deltas and successful permission/question round trips.
- Full Windows assistant tests, including real sidecar IPC. The JSON reporter ended with `success: true`.

## Actual failures

| Job | Failure | Owner / correction |
| --- | --- | --- |
| Verify core with OHOS Flutter | `flutter pub get` exited with `No Hmos SDK found` before analysis/tests. | CI setup now disables OHOS platform generation only for verification. The OHOS SDK retains its real Dart platform APIs. HAP builds explicitly enable platform generation. |
| Verify app with OHOS Flutter | Same missing Hmos SDK failure. | Same setup correction. |
| Node Ubuntu | 168 tests: 164 pass, 3 fail, 1 skip. `deployment.test.ts:94`, `desktop-terminal.test.ts:11`, `setup-cli.test.ts:20` failed after absent Herdr caused an unhandled `HerdrError`. | Companion source owner must fix optional-tool discovery and rejection handling. Do not hide the fault with test-only `--no-herdr`. |
| Node Windows | 168 tests: 163 pass, 4 fail, 1 skip. Deployment cases at lines 51 and 94 plus desktop-terminal failed after absent Herdr. The setup-cli case instead called missing `..\\start.cmd`. | Companion source/test owner handles Herdr and the migrated launcher path. |
| Windows assistant analysis | Ten `info` diagnostics: Flutter 3.50 deprecates `package:flutter/material.dart` in favor of `material_ui`. No warning/error diagnostics were reported. | Coordinator to choose SDK-compatible migration or explicit nonfatal informational diagnostics. Tests passed. |

Both Node jobs intentionally skipped the optional recorded live Herdr probe fixture because `.build/pi-herdr/herdr-probe` is not committed. This is not evidence of live Herdr acceptance. All deterministic Herdr fixtures were included in the suite.

## Follow-up patch

Changed release app files:

- `.github/actions/app-setup/action.yml`: adds `ohos-platform-tooling`, default true. Verification passes false before `pub get`; HAP uses true.
- `.github/workflows/app-installers.yml`: builds and packages the Windows x64 assistant after its checks. Adds its artifact to the release publisher with strict metadata and checksum verification.
- `tool/ci/package_windows_assistant.ps1`: bundles the Flutter release output, x64 MSVC CRT, official checksum-verified Node 24.14.1, locked production dependencies, source, notices, and a self-locating launcher. Runs the packaged source with the bundled runtime through scripted protocol E2E in the cloud. Checksums include hidden files and use LF for Linux verification.

The companion archive is an additional release asset; it does not replace any of the eleven main-app artifacts. The publisher still requires all original verification/build jobs. Assistant build and package failures also block it.

No test, build, companion process, or dependency installation ran locally. Local validation consisted of YAML parsing, Bash `-n`, PowerShell parser inspection, inline Python syntax parsing, source inspection, and `git diff --check`.

Cloud logs were fetched with the existing Git credential helper in memory. Credentials were not printed or written to files.
