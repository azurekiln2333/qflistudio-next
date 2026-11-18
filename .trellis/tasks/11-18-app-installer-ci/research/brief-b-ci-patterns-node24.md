# Brief B: CI template + Node 24 action audit (read-only research)

Rules (non-negotiable):
- Read-only. Never run git reset, checkout, restore, stash, clean, switch, rebase, commit, or any command that changes a worktree or history, in any repo.
- Write only one file: D:/MyNewProjects/qflistudio/.trellis/tasks/11-18-app-installer-ci/research/ci-patterns-and-node24.md
- Do not edit any other file. The user has large uncommitted work in these repos.
- Summarize; do not paste whole files. Cite file:line.

Context: we will write a new GitHub Actions workflow for the Flutter app repo D:/MyNewProjects/qflistudio (it has no .github/ today). Targets: Windows x64+arm64, Linux x64+arm64, macOS x86_64+arm64 (two thin DMGs), iOS unsigned IPA, Android x86_64/armeabi-v7a/arm64-v8a APKs (debug key), OHOS arm64 unsigned HAP. Hard requirement: zero "Node.js 20 is deprecated" warnings. Every JavaScript action must declare `runs.using: node24`. No FORCE_JAVASCRIPT_ACTIONS_TO_NODE24 workaround.

Template: the sibling repo D:/MyNewProjects/qfli_python has mature Flutter app workflows: .github/workflows/app-android.yml, app-apple.yml, app-linux.yml, app-ohos.yml, app-windows.yml, .github/actions/app-setup/action.yml, .github/actions/setup-ohos/{action.yml,setup.sh}, and tool/ci/*.sh. That app also depends on qflistudio-core.

A. Summarize the template:
   - triggers/inputs (core_ref, pinned core commit?) and how qflistudio-core is checked out (repo, path, token?), and how `../qfli_studio_core` path deps resolve (workspace layout).
   - app-setup: how Flutter is installed (action / git clone / version pin), caching, Java, Android SDK.
   - setup-ohos: how OHOS command-line tools, SDK, ohpm, hvigor and the Flutter OHOS fork are installed; which Node runs hvigor and where it comes from; download URLs and whether they need auth.
   - app-windows.yml: installer format and tools, runner label, arm64 handling.
   - app-linux.yml: deb + tar.gz steps, runner, arm64 handling.
   - app-apple.yml: iOS unsigned IPA and macOS DMG steps, runner labels.
   - app-android.yml: APK build and signer verification.
   - tool/ci/*.sh helpers: name, one-line purpose, generic enough to copy?
B. Node 24 audit. For each action, fetch action.yml at the tag: `curl -fsSL https://raw.githubusercontent.com/<owner>/<repo>/<tag>/action.yml` (fall back to action.yaml). Record runs.using. Get tag -> commit SHA from `git ls-remote --tags https://github.com/<owner>/<repo>` (use the peeled ^{} SHA for annotated tags). Cover at least: actions/checkout v7.0.1, actions/upload-artifact v7.0.2, actions/download-artifact v8.0.2, actions/cache v6.1.0, actions/setup-java latest v6.x, actions/setup-node v7.1.0, actions/setup-python v7.1.0, android-actions/setup-android v4.0.4, subosito/flutter-action latest, msys2/setup-msys2 v2.33.0, openharmony-rs/setup-ohos-sdk latest, plus every other `uses:` in the qfli_python app workflows and composite actions (recurse into composites). Flag anything on node20 or older and propose a node24 or shell replacement.
C. Runner labels: verify Windows arm64 (windows-11-arm), Linux arm64 (ubuntu-24.04-arm, ubuntu-22.04-arm), macOS arm64 (macos-15, macos-26), macOS intel (macos-15-intel) from https://github.com/actions/runner-images README, with deprecation dates. Does Flutter stable support building Windows arm64 and Linux arm64 apps on those runners? Is there an official Flutter SDK archive for linux arm64 / windows arm64 hosts (check https://storage.googleapis.com/flutter_infra_release/releases/releases_linux.json and releases_windows.json for arm64 entries), or must it be git cloned? Does subosito/flutter-action support arm64 hosts?
D. macOS single arch: `flutter build macos` outputs a universal app. Compare (1) lipo -thin every Mach-O in the .app then ad-hoc re-sign with `codesign --force --deep -s -`, versus (2) EXCLUDED_ARCHS / ARCHS override via xcconfig at build time. Recommend one with reasons.

Put a table in the output: action | tag | sha | runs.using | verdict.

When done, reply in the terminal with a summary of at most 50 lines and the output file path.
