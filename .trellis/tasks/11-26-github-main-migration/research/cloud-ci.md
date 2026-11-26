# Cloud CI audit — GitHub main migration

Audit date: 2026-11-26. Agent: `w65:p4`. Lead: `w65:p1`.
Model: `gpt-6.1-sol`, verified from `PI_MODEL`.
Repository: `azurekiln2333/qflistudio-next`.

## Scope and method

This audit reads committed GitHub state, authenticated GitHub API metadata and existing job logs. It does not run a build, test, analyzer, dependency installation or WSL. It does not download installer/log artifacts, trigger a workflow, edit CI, change Git state or access credentials. Job logs were streamed through authenticated `gh api` GET requests, not saved as downloaded artifact archives. The lead later authorized only these two research files.

The authoritative source snapshot is `c5f4bc3afe9c81ba488fd3f544d43c3dac061512`. Both local `refs/remotes/github/main` and the GitHub main-branch API resolved to this SHA at inspection. Source inspection used `git show c5f4bc3:<path>`, not the stale local `main` working tree. Findings below do not certify a later migration commit.

Machine-readable evidence: `cloud-ci.json` in this directory. Evidence identifiers below map to exact read-only commands/endpoints in that file.

## Executive result

- **Proven for the existing release:** tag run **45689238802**, `App installers`, completed successfully on **2026-11-25 at 20:06:45 UTC**, at `c5f4bc3`. All **18 jobs** succeeded. Six platforms produced **11 architecture-specific app artifacts**. A portable Windows assistant and seven diagnostics artifacts bring the total to **19**. [E01–E04]
- **Not a green latest main-branch run:** main push run **45689221609** at the same SHA failed Android APK dependency resolution. Its Android log reports **Maven Central HTTP 429 Too Many Requests** for Kotlin artifacts. Sixteen jobs succeeded, one failed and release publication was skipped. The later tag run succeeded without a source change. This proves an observed network/dependency failure, not a proven application code defect. [E02, E07]
- **Release assets exist:** stable `v5.0.14`, not draft or prerelease, was published at **2026-11-25 20:06:41 UTC**. It has **13 assets**: 11 app ZIPs, one assistant ZIP and `SHA256SUMS`. [E05]
- **Core pin exists:** `azurekiln2333/qflistudio-core@476a30acee21dc486ee2849dd8064a7be665e4d5` is retrievable from GitHub. Independent `core-check` run **45689025146** passed both `check` and `screenshots`. The app release also independently tested this core pin. [E08, E09]
- **Do not claim production-signed or device-validated releases.** Windows/Linux are unsigned, macOS is ad-hoc signed and not notarized, Android uses a generated debug key, and iOS/OHOS require signing before installation. Physical-device validation is explicitly absent. [E05, E06, E10]

## Platform, architecture and installer matrix

Every job below concluded `success` in run `45689238802`. Every named artifact is present and unexpired in the API manifest. Each app artifact is staged with `BUILD_INFO.txt`, `SHA256SUMS` and `LICENSE`. Publication rechecked provenance and checksums of all 11 app artifacts. Package names below were also observed as `: OK` lines in the publication job log, rather than inferred solely from workflow text. [E03, E04, E06, E10]

| Platform / architecture | Job ID / hosted runner | Package inside the artifact | Signing / actual validation |
| --- | --- | --- | --- |
| Windows x64 | `139470029793` / `windows-2022` | `QFLIStudioN-5.0.14-windows-x64-setup.exe`, `QFLIStudioN-5.0.14-windows-x64-portable.zip` | Unsigned. PE machine and release files checked. MSVC runtime bundled and inspected. Silent install and installed-file inspection passed. |
| Windows arm64 | `139470029943` / `windows-11-arm` | `QFLIStudioN-5.0.14-windows-arm64-setup.exe`, `QFLIStudioN-5.0.14-windows-arm64-portable.zip` | Unsigned. Native ARM64 build uses the batch Flutter entry point. PE/runtime checks and silent-install inspection passed. |
| Linux x64 | `139470029878` / `ubuntu-22.04` | `qflistudio_5.0.14_amd64.deb`, `qflistudio-5.0.14-linux-x64.tar.gz` | Unsigned. ELF machine, shared-library resolution and DEB architecture checked. Real `dpkg` installation passed. |
| Linux arm64 | `139470029909` / `ubuntu-22.04-arm` | `qflistudio_5.0.14_arm64.deb`, `qflistudio-5.0.14-linux-arm64.tar.gz` | Unsigned. Native ARM64 build with the same ELF, package and install checks. |
| macOS x86_64 | `139470029932` / `macos-15` | `QFLIStudioN-5.0.14-macos-x86_64.dmg` | Ad-hoc signed, not notarized. Mach-O thinning/architecture, bundle ID, signature and mounted DMG contents checked. |
| macOS arm64 | `139470029893` / `macos-15` | `QFLIStudioN-5.0.14-macos-arm64.dmg` | Same restrictions. Log records `Signature=adhoc` and verified arm64 Mach-O payloads. |
| iOS arm64 | `139470029822` / `macos-15` | `QFLIStudioN-5.0.14-ios-unsigned.ipa` | `--no-codesign`. Runner/framework slices and bundle ID checked. Git API/CA payload checked. Not directly installable. |
| Android x86_64 | `139470029832` / `ubuntu-24.04` | `QFLIStudioN-5.0.14-android-x86_64.apk` | Release-mode APK signed by a generated Android Debug key. Signature, package ID, exactly one ABI, ELF machine and Git payload checked. |
| Android armeabi-v7a | same Android job | `QFLIStudioN-5.0.14-android-armeabi-v7a.apk` | Same checks for 32-bit ARM. |
| Android arm64-v8a | same Android job | `QFLIStudioN-5.0.14-android-arm64-v8a.apk` | Same checks for AArch64. No AAB/store-signing claim. |
| OHOS arm64 | `139469954304` / `ubuntu-22.04` | `QFLIStudioN-5.0.14-ohos-arm64-unsigned.hap` | `--no-codesign`. HAP CRC/entries, bundle name, arm64-v8a-only ABI, AArch64 Flutter/app libraries and Git payload checked. No signed HAP or APP-store package. |

App artifact names are `qflistudio-5.0.14-<target>` for the 11 targets above, using `macos-x86_64`, `android-armeabi-v7a` and `android-arm64-v8a` literally. Exact artifact IDs, sizes, digests and expiry times are in JSON. All app/test Actions artifacts expire on **2026-12-09 UTC** under the 14-day retention setting. Release assets are a separate published set. No artifact was downloaded by this audit. [E04, E05]

## Independent tests and available logs

A successful package build is not treated as a test result. The workflow has distinct verification jobs and the release job depends on them. [E03, E06]

| Check | Job ID | Observed result | Diagnostic artifact |
| --- | --- | --- | --- |
| Full app analysis/tests on OHOS Flutter | `139469953842` | Analyzer: no issues. JSON test stream: 9 visible test completions, 9 non-skipped successes, 0 failures, `done.success=true`. CI helper suites separately report 18 + 19 passing Python tests. | `verification-flutter-app` |
| Full core analysis/tests on OHOS Flutter | `139469954348` | Analyzer: no issues. JSON stream: 3352 visible completions, including 27 skips; 3325 non-skipped successes, 0 failures, `done.success=true`. Skipped entries must not be reported as executed tests. | `verification-flutter-core` |
| Java foreground receiver host contracts | `139469954098` | 12 pass, 0 fail. Runs the pinned ArkTS/native entry and receiver through Node/platform stubs, not a Java/HarmonyOS device runtime. | `verification-java-interop` |
| Node companion on Windows | `139469954320` | Type check passed. 243 tests, 242 pass, 1 skipped, 0 fail. Scripted-provider E2E passed. | `verification-companion-windows-2022` |
| Node companion on Linux | `139469954359` | Type check passed. 243 tests, 242 pass, 1 skipped, 0 fail. Scripted-provider E2E passed. | `verification-companion-ubuntu-24.04` |
| Windows assistant / sidecar | `139470029960` | Analyze succeeds with 11 non-fatal info findings. 12 non-skipped Flutter test successes, 0 failures. Packaging log: E2E passed; fresh LAN start, pairing, phone info and session replies passed over the test transport. | `verification-windows-assistant` |
| Released Git plugin on iOS simulator | `139470029771` | Fixture HEAD equals `697291a27818612ae9dc53d83d4f99fa5887908e`; Flutter 3.50.0. `00:06 +1: All tests passed!` at 20:04:43 UTC. | `git-ios-integration-45689238802` |
| Independent core repository | `139469218250`, `139469217995` in run `45689025146` | `check`: formatting/analyze/complete suite passed. `screenshots`: capture/upload passed. | Owned by the core repository; not included in the app's 19-artifact count. |

Evidence: job-step API plus streamed actual logs, [E03, E09, E11]. Flutter counts exclude hidden harness events; they describe the recorded stream rather than a count of source files. The core skip count is directly visible as 27 `testDone` events with `skipped:true`. A successful analyzer exit does not mean zero informational diagnostics when `--no-fatal-infos` is used.

Log paths configured for upload: Flutter analysis text and JSON test stream; Node `companion-*.log`; Java host-test log; assistant analysis/test/build logs; iOS flow-test and Runner system logs. Diagnostic uploads run with `if: always()` but `if-no-files-found: warn`, so an upload success alone would not guarantee every intended file exists. Here the seven named diagnostics artifacts all have nonzero API sizes. Their internal archive members were not opened. Existing Actions job logs were independently readable. `run_logged.sh` preserves the command's exit status and repeats its last 60 output lines as an error annotation. [E04, E06, E11]

## Flutter intermediates and native dependency flow

### SDK, package resolution and platform outputs

1. `resolve-flutter` resolved **Flutter 3.50.0** to **`ab2912035e160d9cad6306df307576da6128ebdb`** in the actual log. Ten non-OHOS app target artifacts share that SDK. [E12]
2. OHOS build and app/core suites use **3.41.10-ohos-1.0.1**, commit **`adaf911c35c9136a7d18fc424d714c9ec7724e60`**. OHOS tooling is **26.0.0.821**, API **26**, Node **24.14.1**. Tooling comes from the third-party `ErBWs/ohos-sdk` redistribution, not an official Huawei distribution channel. [E06]
3. `app-setup` checks out the pinned core as a sibling, restores a target/OS/architecture-separated SDK cache under runner temp, verifies the cloned Flutter framework commit, runs cloud `flutter pub get`, and records core/plugin provenance. It does not consume a local D:/E: build tree. [E13, E14]
4. Standard Flutter jobs patch only their runner copy of `huawei_quick_login_view.dart` to an inert widget and scan for remaining OHOS-only APIs. OHOS jobs leave that source intact. `BUILD_INFO.core_commit` identifies the original Git checkout, not a byte-identical unmodified standard-Flutter core tree. [E13, E14]
5. Release intermediates are built within each hosted job: Windows `build/windows/<arch>/runner/Release`; Linux `build/linux/<arch>/release/bundle`; macOS `build/macos/Build/Products/Release`; iOS `build/ios/iphoneos/Runner.app`; Android `build/app/outputs/flutter-apk`; OHOS unsigned HAP under Flutter/hvigor output paths. Packaging consumes those outputs locally within the same job. [E06]
6. Only staged installable packages and diagnostics are exposed as app-run artifacts. There is **no standalone reusable Flutter intermediate/engine artifact job** and no cross-job intermediate transfer before release publication. The publication job consumes the already packaged app/assistant artifacts. [E04, E06]

Native platform flow includes the Windows runner's MSVC CRT, Linux GTK/libsecret/compiler dependencies, Android JDK 17 + NDK 27.0.12077973 + CMake 3.22.1, Apple Xcode/CocoaPods frameworks, and the OHOS CLI/SDK/hvigor toolchain. These are app-build dependencies, not proof of language-specific compiler/interpreter runtime ownership. [E06]

### Shared Git plugin provenance

- Core `476a30a` pins **qfli_git 0.1.0**, commit **`697291a27818612ae9dc53d83d4f99fa5887908e`**. The app's resolved lock and actual job output agree. [E10, E15]
- Plugin native lock schema 2 records API **3**, source **`194a6c9dd70873a472e441b67875766541572372`**, producer run **44863517943**, libgit2 **1.9.7**, mbedTLS **3.6.8**, and CA bundle date **2026-11-05**. Actual app jobs record CA SHA-256 **`427c064216761a1e72a8b30f0d954d08cb6e4435a82091fb865afd20c8497285`**. [E10, E16]
- Committed plugin payloads include Android three-ABI `.so` files, OHOS arm64-v8a/x86_64 `.so` files and an iOS XCFramework with device/simulator slices. The app packages Android three ABIs, OHOS arm64 only and iOS device arm64 only. Desktop Git uses the installed Git CLI. [E05, E16]
- The app does not rebuild libgit2/mbedTLS from native source in this workflow. It resolves the pinned plugin, checks its lock and bundled payload, then verifies API exports/CA/native payloads in Android/iOS/OHOS packages. The release log explicitly reports **API 3 in all packages** and a matching plugin/native source across all 11 artifacts. [E06, E10, E13]
- Important distinction: imported-native producer **44863517943** is **failure overall**. Android/iOS/OHOS native build jobs passed, but host script/contract checks and example iOS integration failed; Dart tests/publication were skipped. Its three native artifacts still exist, expiring **2026-12-05 UTC**. [E17]
- This is not the only plugin validation: the pinned plugin commit **697291a** has a **successful independent run 44867887807**. Host smoke, contract/bindings/lock, all three native builds, Dart analysis/tests, example Android and example iOS simulator all passed. Publication was skipped on that branch. Its later main-branch run **44872145265** failed only the example Android build. Preserve this mixed history rather than calling the imported producer green or calling the pinned plugin entirely untested. [E18]

### Language runtime ownership

**This app owns no language-native runtimes.** At `lib/main.dart:33–48`, the app profile has `runtimeKind: 'multi-runtime'`, `runtimeStatus: 'unavailable'` and an `InteropRunner` delegating language execution to companion apps/toolchains. Root dependencies point to the shared IDE core, not language-native runtime packages. A tracked-tree scan found no `.so`, `.dll`, `.dylib`, `.a`, `.hap`, `.ipa`, `.apk`, `.deb`, `.dmg` or `.exe` payloads in the audited app commit. This is a source/ownership finding, not a claim that packaged installers contain no Flutter or plugin native libraries. [E19]

The shared native Git plugin and Flutter engine are not language runtimes. The separate portable Windows assistant does bundle Node and agent dependencies; its artifact is `qfli-remote-assistant-5.0.14-windows-x64` (186,360,179 bytes). That assistant is a distinct component, not proof that Studio bundles per-language compilers or interpreters. Language runtime repository build/test coverage remains outside this app audit. [E03–E06, E19]

## Exact gaps and release limitations

1. **Post-migration commit not validated.** All package/test evidence covers `c5f4bc3`; no new run was triggered. Require the final merged/path-migrated SHA to pass cloud CI before assigning it the old release's status.
2. **Latest main push is red.** Main run `45689221609` failed Maven/Kotlin HTTP 429. A successful same-SHA tag run proves a successful build opportunity, not a consistently green main pipeline. [E07]
3. **Not formal production signing.** No Authenticode Windows release, signed Linux repository, notarized macOS release, Android store key/AAB, signed iOS IPA or signed OHOS HAP/APP was proven. [E05, E06]
4. **No physical-device/full installed-app runtime acceptance.** Package inspection and Windows/Linux installation checks are proven. App launch/behavior across all six platforms and real-device iOS/OHOS installation are not. The plugin simulator test and scripted companion E2E are narrower checks. Release metadata deliberately says `device_validation=none`. [E05, E06]
5. **Full app/core suites use the OHOS fork only.** Standard Flutter 3.50.0 builds all other targets and tests the assistant/iOS plugin, but an independent full root app/core suite on that SDK is not shown. Core has 27 skipped test cases. Each Node companion suite has one skipped test. [E06, E11]
6. **Native producer history is mixed.** The exact imported native producer is red overall, although its native output jobs pass. The pinned plugin has another independently green run. No signed/published native release at the imported source was proven. [E17, E18]
7. **Strict lockfile reproducibility is not enforced.** Standard Flutter setup warns rather than fails if `flutter pub get` changes `pubspec.lock`. Actual Android and assistant job logs both contain that warning. Plugin/native pin checks remain enforced, but unchanged complete dependency resolution cannot be claimed. Standard-Flutter core source also receives a documented runner-only compatibility patch. [E06, E13, E14, E20]
8. **Artifact lifetime and archive-content limit.** Actions artifacts expire Dec 9; upstream imported-native artifacts expire Dec 5. Published release ZIP metadata and successful cloud checksum checks are proven, but this audit did not independently unpack or hash downloaded artifacts. Diagnostic archive file-level completeness is unverified. [E04, E05, E10, E17]
9. **No reusable intermediate delivery contract.** Flutter/native platform outputs flow into installers in the same job. A separate portable intermediate artifact pipeline is absent, if that is a migration requirement. [E04, E06]
10. **Language runtime coverage is separate.** The app intentionally owns no language-native runtimes; six app installers do not prove language-runtime builds, tests or installers in sibling repositories. [E19]
11. **Preservation, branch reconciliation and E-drive synchronization are not certified here.** This report is a CI sub-audit. Other audit owners must establish Git/Trellis preservation, final source/target equality and handover.

## Lead-gated follow-up: sibling directory migration

No CI or application edits were made by this agent. Wait for the lead's merge. The agreed follow-up changes the directory spelling from `qfli_studio_core` to `qflistudio-core` **without changing the Dart package identity `qfli_studio_core` or core pin `476a30acee21dc486ee2849dd8064a7be665e4d5`**.

The audited release has operational old-directory references in:

- `pubspec.yaml`: shared-core dependency plus `vendor/re_editor` and `vendor/xterm` path overrides.
- `pubspec.lock`: matching three path descriptions.
- `.github/actions/app-setup/action.yml`: sibling checkout directory, recorded `git -C` core revision, compatibility-patch argument and explanatory text.
- `.github/workflows/app-installers.yml`: core verification matrix working directory, dependency resolution path, failure stack-path normalization regex and explanatory text.

Update those path contracts together, then validate the final commit in cloud CI. Preserve `package:qfli_studio_core/...` imports, dependency keys and the core package's `name:`. Do not mechanically replace every underscore occurrence. Root CI owns app/core checkout placement; native runtime repositories are not a reason to add binaries to this app. [E06, E13, E19]

## Evidence retrieval notes

Read-only examples: `gh api repos/<owner>/<repo>/actions/runs/<id>`, `/jobs?per_page=100`, `/artifacts?per_page=100`, `/actions/jobs/<job-id>/logs`, `/releases/tags/v5.0.14`, and `/contents/<file>?ref=<sha>`. Network EOF/TLS/timeouts occurred on a few GETs; successful GETs supplied the facts above. No failed GET was treated as a negative existence finding. No workflow rerun/dispatch, release mutation or artifact download endpoint was invoked.
