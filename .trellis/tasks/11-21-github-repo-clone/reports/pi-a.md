# Pi A — R1 GitHub OAuth/PAT final report

**R1 source status: APP FROZEN.** Core R1 was separately frozen and Root has confirmed its bytes unchanged and committed. This report records A's App-side dependency/platform integration, exact paths, completed static checks and remaining release gaps. Root owns index and commits; A performed no stage/commit/push.

## Implementation summary

- Default OAuth uses GitHub's public-client Device Flow. PAT is an explicit alternative.
- GitHub `/user` validates identity; `/user/repos` lists all pages (`per_page=100`, safe same-origin `Link rel=next`) and deduplicates by numeric repository ID.
- UI state and API types live in Core `lib/github/**`; clone handoff builds the existing `GitCloneRequest` with a clean HTTPS repository URL and operation-scoped credential. No credential enters the URL, logs or project data.
- Credentials use `flutter_secure_storage` 11.2.0 only. Core serializes vault operations process-wide and fences intents across controllers. A delayed write that completes after cancel/dispose removes its own value before releasing the vault queue. Newer login and disconnect operations remain serialized after stale writes.
- OAuth and API requests have an injectable bounded timeout for send and response-body reads. Requests disable redirects; repository page links are validated to GitHub API origin before follow-up. Invalid repository JSON returns sanitized errors. Device expiry is rechecked after the polling wait, before network I/O.
- Cloud regression source covers the secure-vault races and identity boundary. Per task policy, no test was run.

## Exact A-owned App R1 paths

| Path | Change |
| --- | --- |
| `.github/workflows/app-installers.yml` | Add Linux `libsecret-1-dev` build dependency. |
| `android/app/src/main/AndroidManifest.xml` | Preserve `allowBackup=false`; reference backup exclusions. |
| `android/app/src/main/res/xml/backup_rules.xml` | Exclude only the GitHub namespace and wrapped-key preferences from legacy backup. |
| `android/app/src/main/res/xml/data_extraction_rules.xml` | Exclude the same values from cloud backup/device transfer. |
| `ios/Runner.xcodeproj/project.pbxproj` | Point Runner Debug/Profile/Release at the Keychain entitlement. |
| `ios/Runner/Runner.entitlements` | App-owned Keychain configuration; no cross-app group. |
| `linux/flutter/generated_plugin_registrant.cc` | Register the secure-storage Linux plugin. |
| `linux/flutter/generated_plugins.cmake` | Add the Linux plugin to the build list. |
| `macos/Flutter/GeneratedPluginRegistrant.swift` | Register the federated Darwin plugin. |
| `pubspec.lock` | Lock the plugin resolved transitively from Core's path dependency. |
| `tool/ci/package_linux.sh` | Add `libsecret-1-0` to the Debian runtime dependencies. |
| `windows/flutter/generated_plugin_registrant.cc` | Register the Windows secure-storage plugin. |
| `windows/flutter/generated_plugins.cmake` | Add the Windows plugin to the build list. |

App `pubspec.yaml` remains unchanged; the app already depends on `../qfli_studio_core`. `flutter pub get` updated that app's dependency lock and supported platform registrations. Android and iOS registrants are generated ignored outputs and include the plugin locally; they are not version-controlled. The OHOS registrant intentionally omits the unsupported plugin.

A did not edit D-owned native runner source. In particular, existing staged changes in `ios/Runner/AppDelegate.swift` and `macos/Runner/MainFlutterWindow.swift` remain D-owned. A did not stage any files or alter the index.

## Checks actually completed

- **Core formatting:** `dart format --output=none --set-exit-if-changed lib/github test/github_auth_controller_test.dart` — exit 0, 0 files changed.
- **Core static analysis:** `dart analyze lib/github test/github_auth_controller_test.dart` — No issues found.
- **App dependency resolution:** `flutter pub get` at App root — succeeded; resolved `flutter_secure_storage` 11.2.0 through Core and regenerated supported platform registrants. This was dependency resolution only, not a build.
- Static inspection confirmed the supported Android/iOS/macOS/Linux/Windows plugin registrants and OHOS's deliberate omission.
- No tests, application builds, native builds, runtime services, device tools, or vault operations were run. No `git diff --check` result is claimed here.

## Remaining release/configuration gaps

- OAuth still needs a registered GitHub OAuth App with Device Flow enabled and public compile-time `QFLI_GITHUB_CLIENT_ID`. Production configuration was not supplied or verified. No client secret is needed or shipped.
- OHOS has no verified upstream plugin vault. Core rejects login before OAuth/PAT requests on OHOS and Web; there is no plaintext fallback. GitHub login on OHOS remains unavailable until a reviewed secure vault is added.
- Linux needs `libsecret-1-dev` at build time, `libsecret-1-0` at runtime, and an active Secret Service provider. CI/deb metadata is updated; a real keyring session was not verified.
- Windows release builders need C++ ATL in the Visual Studio Build Tools image; this prerequisite still needs CI confirmation.
- The plugin requires Android API 24; this app's resolved Flutter `minSdkVersion` is 24. Actual Keystore/Keychain/Windows/Secret Service behavior and iOS signing entitlement behavior remain unverified without native builds/devices.

**A's App-side R1 paths are frozen.** Root may stage/commit the listed paths under R1. This report does not claim deployment configuration or device acceptance.
