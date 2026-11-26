# R1 secure-storage integration status

Active backend: `flutter_secure_storage` 11.2.0 only. No custom `githubCredential.*` native handlers or alternate vault remain. Core A owns the Core manifest/lock and Dart wrapper. App A owns dependency resolution/registrants and the secure-storage App configuration below. D owns the existing native share/browser runner handlers only. No build or vault runtime call was made.

Package sources checked earlier: resolved `flutter_secure_storage` README, public API/options, Android config and minimum SDK, and platform registrations. No further research was performed during this final integration pass.

## App paths modified by A

| Path | Change |
| --- | --- |
| `.github/workflows/app-installers.yml` | Linux build job installs `libsecret-1-dev`. |
| `android/app/src/main/AndroidManifest.xml` | Keeps `android:allowBackup="false"`; references precise backup rules. |
| `android/app/src/main/res/xml/backup_rules.xml` | Excludes only the GitHub namespace and wrapped-key preferences from legacy cloud backup. |
| `android/app/src/main/res/xml/data_extraction_rules.xml` | Excludes the same two preferences from cloud backup and device transfer. |
| `ios/Runner.xcodeproj/project.pbxproj` | Sets Runner Debug/Profile/Release `CODE_SIGN_ENTITLEMENTS`. |
| `ios/Runner/Runner.entitlements` | App-owned Keychain access group with no cross-app group. |
| `linux/flutter/generated_plugin_registrant.cc` | Registers `flutter_secure_storage_linux`. |
| `linux/flutter/generated_plugins.cmake` | Adds Linux secure storage to the plugin build list. |
| `macos/Flutter/GeneratedPluginRegistrant.swift` | Registers the federated Darwin vault plugin. |
| `pubspec.lock` | Records `flutter_secure_storage` 11.2.0 and federated plugin implementations, resolved through the App's Core path dependency. |
| `tool/ci/package_linux.sh` | Adds `libsecret-1-0` to `.deb` runtime dependencies. |
| `windows/flutter/generated_plugin_registrant.cc` | Registers `flutter_secure_storage_windows`. |
| `windows/flutter/generated_plugins.cmake` | Adds Windows secure storage to the plugin build list. |

`pubspec.yaml` in the App remains unchanged: `qfli_studio_core` is already a path dependency and owns the direct plugin declaration. `flutter pub get` in the App refreshed supported registrants; Android/iOS generated registrant files are ignored outputs and contain the plugin registration locally. OHOS generated registration intentionally excludes it.

The pre-existing D native files were not modified: `ios/Runner/AppDelegate.swift`, `macos/Runner/MainFlutterWindow.swift`, Linux runner, OHOS entry ability, and Windows runner. D's share/browser changes remain separate, with the existing D staged hunks untouched.

## Configuration details and remaining release requirements

- **Android:** the resolved Flutter `minSdkVersion` is 24 and the plugin requires API 24. Core uses `storageNamespace: com.azurekiln.qfli.github`, isolating data preferences and wrapped-key preferences. Backup rules exclude only those namespace-specific encrypted preferences/key records, retaining backups of unrelated app data. The manifest continues to prohibit backup globally (`allowBackup=false`), so current behavior is stricter than the narrow exclusions.
- **iOS:** the Runner target points Debug/Profile/Release at the entitlement file. Core uses app-specific Keychain account and `unlocked_this_device`. Signing and real Keychain behavior remain unverified.
- **macOS:** Core uses `MacOsOptions(usesDataProtectionKeychain: false)`; this avoids Keychain Sharing/provisioning requirements for this single-app secret. Darwin plugin registration is present.
- **Windows:** plugin registration is present. The package requires C++ ATL in the Visual Studio build tools; release CI image must supply it. This external runner prerequisite has not been verified here.
- **Linux:** compile requires `libsecret-1-dev`, package runtime requires `libsecret-1-0`, and the user session needs Secret Service (GNOME Keyring/KWallet). All package/workflow declarations are present; runtime keyring availability has not been tested.
- **OHOS/Web:** upstream plugin has no OHOS implementation; Web LocalStorage is excluded too. Core uses conditional `dart.library.io` platform detection and denies GitHub login before OAuth/PAT HTTP requests on OHOS/Web. No plaintext fallback exists. OHOS GitHub login remains unavailable until a reviewed vault exists.
- **OAuth deployment:** release still needs a registered GitHub OAuth App with Device Flow enabled and a public `QFLI_GITHUB_CLIENT_ID` compile-time define. No production ID or app configuration was supplied/validated. No client secret is required or shipped.

## App-side permitted check evidence

- `flutter pub get` at the App root succeeded and resolved `flutter_secure_storage` 11.2.0 via the Core path package. This was dependency resolution only, not a build.
- Local static inspection confirmed plugin registration in Linux, macOS and Windows tracked outputs, and in the generated Android/iOS registrant outputs. OHOS registration intentionally omits the plugin.
- No App tests, analyzer, native build, runtime, device, or service check was run in this final pass.

App A-owned R1 paths above are now frozen. Root owns the index and serial requirement commits.
