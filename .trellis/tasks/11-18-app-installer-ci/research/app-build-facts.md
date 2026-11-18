# qflistudio build facts (Brief A output)

Read-only research for `.trellis/tasks/11-18-app-installer-ci`.
Root shorthand: `$S` = `D:/MyNewProjects/qflistudio`, `$C` = `D:/MyNewProjects/qfli_studio_core`.

---

## 1. Flutter / Dart versions

| Fact | Evidence |
| --- | --- |
| App SDK constraint `^3.11.5` | `$S/pubspec.yaml:8-9` |
| Core SDK constraint `^3.11.5` | `$C/pubspec.yaml:7-8` |
| Lockfile `dart: ">=3.11.5 <4.0.0"`, `flutter: ">=3.27.0"` | `$S/pubspec.lock:483-485` |
| Local toolchain is the OHOS fork | `flutter --version` → `Flutter 3.27.5-ohos-1.0.1`, `Tools • Dart 3.11.5` |
| Fork version pinned in repo docs | `$S/docs/huawei-account-kit-research.md:12` and `:54` ("Flutter 3.27.5-ohos-1.0.1 · Dart 3.11.5") |
| Fork engine metadata on this machine | `D:/ProgramFiles/flutter_ohos/bin/cache/flutter.version.json` → `frameworkVersion 3.27.5-ohos-1.0.1`, `dartSdkVersion 3.11.5` |
| CI intent already recorded | `$S/.cnb.yml` (`verify-flutter-workbench` comment: "OHOS fork (3.27.5-ohos-1.0.1)") |
| OHOS SDK targets | `$S/ohos/build-profile.json5:57-62`: `compatibleSdkVersion "5.1.0(18)"`, `targetSdkVersion "26.0.0"`, `runtimeOS "HarmonyOS"` |
| OHOS app version | `$S/ohos/AppScope/app.json5:3-5`: `versionCode 5000001`, `versionName "5.0.1"` |

### Dart constraint vs OHOS fork — conflict and resolution

- Upstream Flutter stable that ships Dart 3.11.5 is **3.38.x**. Flutter 3.27.5 upstream ships Dart 3.6.x,
  so `sdk: ^3.11.5` would *not* resolve on a plain 3.27.5 install.
- The fork is **not** a plain 3.27.5: `dartSdkVersion` is `3.11.5`
  (`D:/ProgramFiles/flutter_ohos/bin/cache/flutter.version.json`). The project satisfies the constraint by
  using the fork everywhere, so `flutter: ">=3.27.0"` (`pubspec.lock:485`) stays the only flutter bound.
- Consequence for CI: **one Flutter install must cover all six platform targets**. Either the fork
  `3.27.5-ohos-1.0.1` (Dart 3.11.5) on every runner — required for OHOS — or OHOS is split into its own job
  with the fork while desktop/mobile jobs use a recent upstream stable (3.38.x, Dart 3.11.5).
  Mixing is a real risk: `.dart_tool/` and `pubspec.lock` produced by different Dart patch levels interact badly.
- No `flutter:` key exists in either `pubspec.yaml`, so there is no extra Flutter floor beyond the lockfile.

---

## 2. Dependencies

### `$S/pubspec.yaml`

| Dependency | Spec | Kind |
| --- | --- | --- |
| `flutter`, `flutter_localizations` | `sdk: flutter` | SDK |
| `qfli_studio_core` | `path: ../qfli_studio_core` | **path dep, sibling repo** (`:13-15`) |
| `cupertino_icons` | `^1.0.8` | pub |
| `re_editor` (dependency_override) | `path: ../qfli_studio_core/vendor/re_editor` | **path dep into the sibling repo** (`:22-24`) |
| dev: `path ^1.9.1`, `flutter_lints ^6.0.0` | | pub |

### `$C/pubspec.yaml`

| Dependency | Spec | Kind |
| --- | --- | --- |
| `flutter`, `flutter_localizations` | `sdk: flutter` | SDK |
| `path_provider ^2.1.5`, `file_selector ^1.0.3`, `path ^1.9.1`, `path_provider_ohos ^2.2.1` | | pub |
| `re_editor ^0.10.0` (+ `dependency_overrides: re_editor: path vendor/re_editor`) | | pub + **vendor path** |
| `archive ^4.0.7`, `http ^1.6.0`, `re_highlight ^0.0.3`, `intl ^0.20.2`, `fast_gbk ^1.0.0`, `xml ^6.6.1` | | pub |
| dev: `flutter_test`, `flutter_lints ^6.0.0`, `path_provider_platform_interface ^2.1.2` | | pub |
| The core is **itself an Android plugin** | `$C/pubspec.yaml:35-40`: `plugin.platforms.android` → `com.azurekiln.qfli.core`, `QfliPickerPlugin` |

### Git deps, submodules, out-of-repo paths

- **No git dependencies at all.** Every non-SDK dep is a pub version constraint.
- **No `.gitmodules` in `$C`** (`if (Test-Path $C/.gitmodules)` → "no .gitmodules").
- `$C/vendor/re_editor` **is tracked** (`git ls-files vendor/re_editor` → `CHANGELOG.md`, `LICENSE`, `README.md`).
  Clean clone of the core repo supplies it, so CI needs no submodule step — only the sibling checkout.
- Only two path deps exist and both point inside the sibling repo; nothing points to a third location
  (`$S/pubspec.yaml:13-15`, `:22-24`).
- **Trap:** `$S/pubspec_overrides.yaml` exists on this machine and redirects both path deps to
  `D:/MyNewProjects/_wt/integration/qfli_studio_core`. It is untracked and ignored only through
  `.git/info/exclude:23` (not `.gitignore`), so a CI checkout is clean — but a local run of the workflow
  on this machine would pick it up. `tool/build_studio_hap.sh:19-21` documents this file.
- `.flutter-plugins-dependencies` is git-ignored (`$S/.gitignore:30`) and is required by
  `tool/lib/hvigor_env.sh:72-77` (`ensure_plugin_manifest`), so `flutter pub get` must run before any HAP task.

### Native code / apt packages on Linux

Resolved plugin set (`$S/.flutter-plugins-dependencies`):

- linux: `file_selector_linux`, `path_provider_linux` (the latter is no-op Dart-only).
- `file_selector_linux` links GTK (`.../file_selector_linux-0.9.3+2/linux/CMakeLists.txt`: `PkgConfig::GTK`).
- `fast_gbk-1.0.0` has **no** CMakeLists/podspec → pure Dart, no apt packages.
- `archive`, `http`, `xml`, `re_highlight`, `intl`, `re_editor` → pure Dart.
- Therefore Linux deps: standard Flutter Linux desktop set — `clang cmake ninja-build pkg-config
  libgtk-3-dev liblzma-dev` (plus `libstdc++-12-dev` on newer images). No plugin-specific extra.

---

## 3. Android

| Fact | Evidence |
| --- | --- |
| Release signing reads `android/key.properties` or `ANDROID_KEYSTORE_PATH` / `ANDROID_KEYSTORE_PASSWORD` / `ANDROID_KEY_ALIAS` / `ANDROID_KEY_PASSWORD` | `$S/android/app/build.gradle.kts:14-42` |
| **No debug fallback — fails on purpose** | `$S/android/app/build.gradle.kts:7-9` (comment) + `:88-99` (`gradle.taskGraph.whenReady` throws `GradleException` if any task name contains `Release` and signing is incomplete) |
| Switch for debug signing | **None exists.** There is no env var or property to opt into the debug key. A trigger workflow that wants debug-signed APKs must either (a) generate a debug keystore and feed it through the four `ANDROID_*` env vars, or (b) add a new opt-in (e.g. `QFLI_ALLOW_DEBUG_SIGNING=1`) — this is a **code change**, flag it to the PRD owner |
| `applicationId` / `namespace` | `com.azurekiln.qfli.qflistudio` (`:44`, `:52`) |
| minSdk / targetSdk / compileSdk | all `flutter.*` defaults (`:55-57`), no override |
| NDK | pinned `27.0.12077973` (`:46-47`) — CI must install exactly this |
| Java | source/target 17, `jvmTarget` 17 (`:49-55`) → **JDK 17 required** |
| AGP | `8.11.1` (`$S/android/settings.gradle.kts:19`) |
| Kotlin | `2.2.20` (`$S/android/settings.gradle.kts:20`) |
| Gradle wrapper | `gradle-8.14-all.zip` (`$S/android/gradle/wrapper/gradle-wrapper.properties:5`) |
| Wrapper committed | `$S/android/.gitignore` first comment: "The Gradle wrapper is committed so a clean clone and CI can build without a preinstalled Gradle." |
| `abiFilters` | **absent** — no `ndk { abiFilters ... }` anywhere in `$S/android/app/build.gradle.kts`; per-ABI APKs come from `flutter build apk --split-per-abi` |
| Core plugin minSdk | 21 (`$C/android/build.gradle*:26`) |
| Keystore ignore rules | `$S/android/.gitignore` (`key.properties`, `**/*.jks`, `**/*.keystore`) |

CI implication: a no-env release build **breaks at configure time**, before compiling. Required workflow steps:
create a keystore (debug key is fine for install-only artifacts) → export the four `ANDROID_*` vars → build.

---

## 4. App identity

| Target | Value | Evidence |
| --- | --- | --- |
| Windows binary | `qflistudio` | `$S/windows/CMakeLists.txt:7` (`BINARY_NAME`) |
| Linux binary | `qflistudio` | `$S/linux/CMakeLists.txt:7` |
| Linux application id | `com.azurekiln.qfli.qflistudio` | `$S/linux/CMakeLists.txt:10` |
| Linux packaging files | **no `.desktop`, no icon install rules present** — `Get-ChildItem linux -Filter *.desktop` → none; `deb`/AppImage packaging must author its own `.desktop` file | — |
| macOS product name | `qflistudio` | `$S/macos/Runner/Configs/AppInfo.xcconfig:9` |
| macOS bundle id | `com.azurekiln.qfli.qflistudio` | `$S/macos/Runner/Configs/AppInfo.xcconfig:12` |
| macOS copyright | `Copyright © 2026 com.azurekiln.qfli.` | `$S/macos/Runner/Configs/AppInfo.xcconfig:15` |
| iOS bundle id | `com.azurekiln.qfli.qflistudio` | `$S/ios/Runner.xcodeproj/project.pbxproj:375` |
| iOS deployment target | `13.0` | `$S/ios/Runner.xcodeproj/project.pbxproj:353`, `:479` |
| OHOS bundle name | `com.azurekiln.qflistudio` (note: **no `.qfli` segment** — differs from every other platform) | `$S/ohos/AppScope/app.json5:3` |
| OHOS display name | `QFLIStudio+` | `$S/ohos/AppScope/resources/base/element/string.json` (`app_name`) |
| OHOS vendor / versionName | `azurekiln`, `5.0.1` | `$S/ohos/AppScope/app.json5:4-5` |
| pubspec version | `5.0.1+5000001` | `$S/pubspec.yaml:5` |

---

## 5. OHOS

### `ohos/build-profile.json5`

- Two `signingConfigs` (`:3-31`):
  - `default` → all material under `C:\Users\lichengyu\.ohos\config\...` — **absolute Windows local paths, absent in CI**, and the file is tracked.
  - `releaseKey` → `D:/Keystore/suanxiwanjie.p12`, `D:/Keystore/Profile/studioRelease.p7b`, `D:/Keystore/suanxiwanjie_release.cer` — **also local-only**.
- `products` (`:53-63`): one product `default`, `signingConfig "default"`, `compatibleSdkVersion "5.1.0(18)"`,
  `targetSdkVersion "26.0.0"`, `runtimeOS "HarmonyOS"`.
- `buildModeSet`: `debug`, `profile`, `release` (`:64-76`).

### Will `flutter build hap --release --target-platform ohos-arm64 --no-codesign` work?

Partly. Two independent blockers, both CI-owned:

1. **hvigor, not `flutter build hap`, does the packaging here.** The project replaces the default flow with a
   hvigor plugin: `$S/ohos/hvigorfile.ts` imports `flutter-hvigor-plugin`, and `$S/ohos/package.json` declares
   that plugin as a **local file dependency** on
   `file:D:\ProgramFiles\flutter_ohos\packages\flutter_tools\hvigor`. In CI the path is wrong, and
   `$S/ohos/.gitignore` ignores `/package.json` and `/package-lock.json`, so the CI checkout has no
   `package.json` at all — `flutter build hap` is expected to **generate** it from `$FLUTTER_ROOT`, so it
   works only if the fork is installed at the runner's Flutter root and `flutter pub get` ran first
   (`.flutter-plugins-dependencies`, see §2).
2. **The two local signing configs reference missing files.** With `signingConfig "default"` selected by the
   only product, hvigor would try `C:\Users\...\.ohos\config\*.cer` and fail. The repo's own scripts avoid this
   by *not* signing: `tool/build_hap.sh:7-11` states the checked-out `.p7b` belongs to a different bundleName, so
   hvigor logs `WARN: No signingConfig found for product default` and emits
   `entry-default-unsigned.hap`. That is the pattern a CI job should copy: remove/ignore `signingConfigs`
   (or point a product at none) and expect `entry-default-unsigned.hap`.
3. `ohos/local.properties` is **untracked** (`git ls-files ohos/local.properties` → empty; listed in
   `$S/ohos/.gitignore`) and holds `hwsdk.dir`, `flutter.sdk`, `flutter.versionName`, `flutter.versionCode`.
   CI must regenerate it.
4. `ohos/node_modules` and `ohos/oh_modules` are **untracked** (`git ls-files ohos/node_modules` → empty;
   ignored in `$S/ohos/.gitignore`). `ohos/entry/oh-package-lock.json5` on disk resolves `@ohos/flutter_ohos`
   to `../../../../ProgramFiles/flutter_ohos/bin/cache/artifacts/engine/ohos-arm64/...` — an absolute local
   path in a lockfile; it is ignored by `$S/ohos/.gitignore` (`**/oh-package-lock.json5`), so CI regenerates it.
   The HAP also needs *both* `ohos-arm64` and `ohos-x64` engine artifacts present in `$FLUTTER_ROOT/bin/cache`.

### hvigor / Node

| Fact | Evidence |
| --- | --- |
| hvigor model version `5.1.0` | `$S/ohos/hvigor/hvigor-config.json5:2` |
| `hvigorfile.ts` imports `@ohos/hvigor-ohos-plugin` | `$S/ohos/hvigorfile.ts:2` |
| Root `oh-package.json5` deps | `dependencies: {}`, `devDependencies: @ohos/hypium 1.0.6` (`$S/ohos/oh-package.json5`) |
| Entry module deps | `dependencies: {}` (`$S/ohos/entry/oh-package.json5`) |
| Actual hvigor binary used locally | `$DEVECO_ROOT/tools/hvigor/hvigor/bin/hvigor.js`, run with DevEco's bundled node (`$S/tool/lib/hvigor_env.sh:60-64`) |
| JDK for hvigor | DevEco bundled JBR, "hvigor needs JDK 17" (`$S/tool/build_studio_hap.sh:20-23`, `:46-49`) |

**Node version for hvigor 5.1.0 — not answerable from this repo.** `hvigor-config.json5` only pins
`modelVersion`, and no `package.json`/lockfile in the repo pins a Node range; the local setup always borrows
DevEco's bundled node. The only Node versions verified *in this repo's CI* are 24.x — `$S/.cnb.yml` uses
`node:24.15.0-bookworm` and `node scripts/check-root-ci.mjs`. Building a real HAP in GitHub Actions therefore
needs DevEco/cmdline-tools' own Node from the HarmonyOS command-line toolchain, not the runner default.
Treat "which Node does hvigor 5.1.0 accept" as **unverified**.

---

## 6. Existing build/packaging scripts

All under `$S/tool/` and `$S/scripts/`; **none** builds a Windows installer, `.deb`, AppImage, `.dmg` or IPA.

| Script | One-line purpose |
| --- | --- |
| `$S/tool/build_hap.sh` | Builds a language-app HAP (`../<app>/ohos`) via DevEco hvigor, unsigned output. |
| `$S/tool/build_studio_hap.sh` | Builds the studio's own HAP (`ohos/` at repo root) debug/release; sets DevEco JBR as `JAVA_HOME`; `--release` needs the `releaseKey` entry in `build-profile.json5`. |
| `$S/tool/sync_ohos.sh` | Runs hvigor `--sync` for a language-app project. |
| `$S/tool/lib/hvigor_env.sh` | Shared env prep (`DEVECO_SDK_HOME`, ohpm shim, `.flutter-plugins-dependencies` check). Windows-only (`cygpath`, `node.exe`, `ohpm.bat`). |
| `$S/tool/device_ui.sh` | Installs/launches the HAP on a connected HarmonyOS device via `hdc`. |
| `$S/tool/generate_studio_content.dart` | Generates `assets/content/` for the studio. |
| `$S/tool/generate_content_catalog.dart` | Generates the content catalog index. |
| `$S/tool/validate_content.dart` | Validates generated course content. |
| `$S/tool/verify_studio_content.dart` | Verifies studio content provenance. |
| `$S/tool/verify_ohos_products.dart` | Checks every product's `ohos/AppScope/app.json5` bundleName (studio = `com.azurekiln.qflistudio`). |
| `$S/tool/verify_runtime_matrix.dart` | Checks the product/runtime matrix for placeholder tokens. |
| `$S/tool/verify_vibe_e2e.dart` | End-to-end acceptance harness for the vibe flow. |
| `$S/tool/preview_test.dart` | Preview/test helper. |
| `$S/tool/new_language_app.dart` | Scaffolds a new language app. |
| `$S/tool/agent_workbench_device.md` | Doc: device install and `pubspec_overrides.yaml` workflow. |
| `$S/scripts/check-root-ci.mjs` (+ `.test.mjs`) | Validates the CNB root pipeline. |
| `$S/scripts/ste-lint-zh.py` | Chinese technical-writing lint. |
| `$S/scripts/test-ohos-background-bridge.cjs`, `test-ohos-huawei-login.cjs` | OHOS bridge / Huawei login harnesses. |

Existing CI packaging: `$S/.cnb.yml` `release-apk` job builds **one** `flutter build apk --release` on tags with
an `ANDROID_KEYSTORE_BASE64` secret and verifies the cert with `apksigner` — **no per-ABI split**, no other platform.

---

## 7. Linux plugins and apt packages

`$S/linux/flutter/generated_plugins.cmake:5-7`:

```
FLUTTER_PLUGIN_LIST: file_selector_linux
FLUTTER_FFI_PLUGIN_LIST: (empty)
```

`file_selector_linux-0.9.3+2` links GTK (`PkgConfig::GTK` in its `linux/CMakeLists.txt`).
Apt set for a Flutter Linux desktop build: `clang cmake ninja-build pkg-config libgtk-3-dev liblzma-dev`.
`path_provider_linux` is Dart-only. No `libsecret`, no `libwebkit2gtk`, no `libblkid` requirement is implied by
this plugin list.

arm64 Linux: the same apt names apply on `ubuntu-24.04-arm`; `ninja-build`/`clang` are multi-arch there.

---

## 8. Windows plugins and Windows arm64 risk

`$S/windows/flutter/generated_plugins.cmake:5-7`:

```
FLUTTER_PLUGIN_LIST: file_selector_windows
FLUTTER_FFI_PLUGIN_LIST: (empty)
```

`file_selector_windows-0.9.3+4` is a plain C++ Win32 plugin — no arch-specific prebuilt binaries.

Likely Windows arm64 problems (all toolchain, not plugin):

- **Flutter Windows arm64 support is new.** The 3.27.5-era toolchain (OHOS fork) predates Windows arm64
  host/target support in `flutter_tools`; building `windows-arm64` with the fork is expected to fail. This is the
  strongest argument for splitting OHOS onto its own Flutter install.
- Project-level: `$S/windows/CMakeLists.txt` targets the default generator (Visual Studio `x64`); an arm64 build
  needs `flutter build windows --release` on an arm64/`x64` host with the MSVC arm64 toolset installed
  (`Microsoft.VisualStudio.Component.VC.Tools.ARM64`). No `arm64` conditional exists in
  `$S/windows/CMakeLists.txt`.
- `windows/runner/Runner.rc`/manifest: no arch pinning was found, so no manifest edit is required.

---

## 9. iOS / macOS pod and entitlement facts

| Fact | Evidence |
| --- | --- |
| **`ios/Podfile` does not exist** | `Get-ChildItem ios` → `Flutter, Runner, Runner.xcodeproj, Runner.xcworkspace, RunnerTests, .gitignore` only |
| **`macos/Podfile` does not exist** | same shape under `macos/` |
| Therefore CocoaPods is **not** configured; no `platform :ios` / `platform :osx` line to read | — |
| No SPM products wired | `grep XCSwiftPackageProductDependency|FlutterGeneratedPluginSwiftPackage` on `$S/macos/Runner.xcodeproj/project.pbxproj` → no matches; `macos/Flutter/` has no `ephemeral/Packages` |
| macOS deployment target | `10.15` (`$S/macos/Runner.xcodeproj/project.pbxproj:464`, `:546`, `:596`) |
| iOS deployment target | `13.0` (`$S/ios/Runner.xcodeproj/project.pbxproj:353`, `:479`) |
| macOS Release entitlements | `app-sandbox`, `network.client`, `network.server` — `$S/macos/Runner/Release.entitlements` |
| macOS DebugProfile entitlements | `$S/macos/Runner/DebugProfile.entitlements` (same family) |
| macOS plugins | `file_selector_macos`, `path_provider_foundation` (from `.flutter-plugins-dependencies`) |
| iOS plugins | `file_selector_ios`, `path_provider_foundation` |

Consequences for CI:

- Because there is no Podfile, `flutter build` will **generate** one on the macOS runner (fine for a clean
  checkout; `build/macos` and `Pods/` are ignored). A missing `pod` binary will break the macOS build.
- `MACOSX_DEPLOYMENT_TARGET = 10.15` means the runner SDK must still allow back-deployment to 10.15 — current
  Apple SDKs emit a deprecation warning but build. App-sandbox is on, which is fine for an unsigned local DMG
  (unsigned + no notarization ⇒ Gatekeeper needs `xattr -dr com.apple.quarantine` on the user side).
- iOS unsigned IPA: valid, since no Podfile / no entitlements / no signing requirements beyond `PRODUCT_BUNDLE_IDENTIFIER`.

---

## 10. Remote reachability (GIT_TERMINAL_PROMPT=0)

```
$ git ls-remote https://github.com/azurekiln2333/qflistudio-core.git HEAD
573d1b6eecf1c2b392ad753264a5a09f62f8335e	HEAD        (exit 0)

$ git ls-remote https://github.com/azurekiln2333/qflistudio-next.git HEAD
e018db9604916f46ae50bd60b5defdebd74b8b1d	HEAD        (exit 0)
```

Both are **public** — no credentials needed, no prompt requested. So a GitHub Actions job can clone the sibling
core repo with a plain anonymous `git clone https://github.com/azurekiln2333/qflistudio-core.git ../qfli_studio_core`,
and cannot trigger a credential prompt.

Remote inventory (for reference): `$S` has `cnb`, `gitcode`, `gitee`, `github`, `gitlab` remotes;
`$C` has `cnb`, `gitcode`, `gitee`, `github`. `HEAD` of `$S` on GitHub matches local `HEAD` (`e018db9`).

---

## Cross-cutting findings the workflow must handle (derived from the evidence above)

1. **Sibling checkout layout is mandatory**: both `pubspec.yaml` path deps assume `../qfli_studio_core`
   (`$S/pubspec.yaml:13-24`). GitHub Actions must `actions/checkout` this repo into `<ws>/qflistudio` and clone
   the core into `<ws>/qfli_studio_core` — a plain `checkout` at the workspace root will not resolve.
2. **Android release cannot run without keys** (`$S/android/app/build.gradle.kts:88-99`) and there is no debug-signing
   switch. The brief asks for debug-key signing, so the workflow must mint a debug keystore and pass it via
   `ANDROID_*`, or a small gradle change is required.
3. **OHOS local signing configs / `local.properties` / `node_modules` / `package.json` are all machine-local**
   (`$S/ohos/build-profile.json5:3-31`, `$S/ohos/.gitignore`, `$S/ohos/local.properties`). A HAP job must regenerate
   them and must produce an **unsigned** HAP (expect `entry-default-unsigned.hap`).
4. **Version skew risk**: `.cnb.yml` already assumes the OHOS fork `3.27.5-ohos-1.0.1` for the whole workbench, but
   `pubspec.lock:484` demands Dart `>=3.11.5`, which only the fork (and upstream ≥3.38) satisfies. Decide one
   Flutter generation per job before writing the matrix.
5. **No installer tooling exists in-repo** (§6), so NSIS/`.deb`/AppImage/DMG/IPA packaging must be authored
   fresh in the workflow. Linux has no `.desktop`/icon install rule to reuse (`$S/linux/CMakeLists.txt`).
