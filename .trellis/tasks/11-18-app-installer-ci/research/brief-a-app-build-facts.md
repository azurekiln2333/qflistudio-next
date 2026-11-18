# Brief A: qflistudio build facts (read-only research)

Rules (non-negotiable):
- Read-only. Never run git reset, checkout, restore, stash, clean, switch, rebase, commit, or any command that changes a worktree or history.
- Write only one file: D:/MyNewProjects/qflistudio/.trellis/tasks/11-18-app-installer-ci/research/app-build-facts.md
- Do not edit any other file in any repo. The user has large uncommitted work.
- Prefer grep / targeted reads over reading whole files.

Context: we will write a GitHub Actions workflow that builds installers of the Flutter app in D:/MyNewProjects/qflistudio for: Windows x64+arm64, Linux x64+arm64, macOS x86_64+arm64 (two thin DMGs), iOS unsigned IPA, Android APKs x86_64/armeabi-v7a/arm64-v8a with debug-key signing, OHOS arm64 unsigned HAP. The app depends on the sibling repo via `path: ../qfli_studio_core` (local clone D:/MyNewProjects/qfli_studio_core, GitHub https://github.com/azurekiln2333/qflistudio-core.git).

Answer each question with evidence (file:line). Keep the output concise.

1. Flutter/Dart versions: pubspec.yaml environment (sdk ^3.11.5; any flutter constraint) and pubspec.lock `sdks:`. Which Flutter stable satisfies it? For OHOS: which Flutter OHOS fork version does this project build with? Search docs/, tool/, scripts/, .trellis/spec/, .trellis/tasks/*/ for strings like "3.27.5-ohos", "ohos-1.0", "flutter_flutter", "3.35". Also ohos/build-profile.json5 compatibleSdkVersion / targetSdkVersion / runtimeOS. Note any conflict between the Dart SDK constraint and the OHOS fork's Dart version, and how the project resolves it.
2. Dependencies of qflistudio pubspec.yaml AND D:/MyNewProjects/qfli_studio_core/pubspec.yaml (names + path/git). Flag git deps, path deps outside the two repos, plugins with native code needing extra Linux apt packages, git submodules in qfli_studio_core (.gitmodules). Is qfli_studio_core/vendor/re_editor tracked in git there (git ls-files vendor/re_editor | head -3)?
3. Android: android/app/build.gradle.kts signing logic. In a release build with no ANDROID_KEYSTORE_* env and no key.properties, does it fail on purpose or fall back to debug? Is there an env/property switch for debug signing? applicationId, minSdk, ndk/abiFilters, AGP/Gradle/Kotlin versions (android/settings.gradle.kts, gradle-wrapper.properties), required JDK.
4. App identity: windows/CMakeLists.txt BINARY_NAME; linux/CMakeLists.txt BINARY_NAME + APPLICATION_ID; macos/Runner/Configs/AppInfo.xcconfig PRODUCT_NAME + bundle id; iOS bundle id; ohos/AppScope/app.json5 bundleName; display name.
5. OHOS: ohos/build-profile.json5 signingConfigs (local paths missing in CI?), products; will `flutter build hap --release --target-platform ohos-arm64 --no-codesign` work? hvigor version (ohos/hvigor/hvigor-config.json5), oh-package.json5 deps; is ohos/node_modules tracked (git ls-files ohos/node_modules | head -3)? ohos/local.properties tracked? Which Node versions does that hvigor version support?
6. Existing scripts in tool/ or scripts/ that build installers/packages (Windows installer, deb, AppImage, dmg, hap): names + one-line purpose.
7. linux/flutter/generated_plugins.cmake plugin list and the apt packages they need.
8. windows/flutter/generated_plugins.cmake plugin list; anything likely to fail on Windows arm64.
9. ios/Podfile and macos/Podfile platform versions; CocoaPods or Swift Package Manager; notable macOS entitlements.
10. With GIT_TERMINAL_PROMPT=0 run `git ls-remote https://github.com/azurekiln2333/qflistudio-core.git HEAD` and the same for qflistudio-next.git. Public or needs auth?

When done, reply in the terminal with a summary of at most 40 lines and the output file path.
