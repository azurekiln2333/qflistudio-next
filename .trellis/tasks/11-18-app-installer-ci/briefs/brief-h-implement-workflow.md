# Brief H: implement the installer workflow

Rules (non-negotiable, read first):
- Never run git reset, checkout --, restore, stash, clean, switch, rebase, amend, push, or any history rewrite.
- Never touch D:/MyNewProjects/qflistudio or D:/MyNewProjects/qfli_studio_core (the user's main trees with large uncommitted work). Read-only access to them is fine.
- Work only in D:/MyNewProjects/_wt/app-installers/qflistudio (branch ci/app-installers, already checked out). Its sibling ../qfli_studio_core is a clean clone; do not modify it.
- Only ADD new files. Do not modify any file that is already tracked in the repo.
- Commit with explicit paths only: `git add <paths> && git commit -m "<conventional message>"`. No Co-Authored-By or "Generated with" lines, no AI attribution of any kind.
- Never run `flutter config` (global settings shared with the user's Flutter install).

Read first (in this order):
1. D:/MyNewProjects/qflistudio/.trellis/tasks/11-18-app-installer-ci/prd.md (requirements, AC1-AC7)
2. D:/MyNewProjects/qflistudio/.trellis/tasks/11-18-app-installer-ci/design.md (the design you implement; follow it exactly)
3. D:/MyNewProjects/qflistudio/.trellis/tasks/11-18-app-installer-ci/implement.md section 3 and 4
4. Research in the same task folder: research/app-build-facts.md, research/ci-patterns-and-node24.md, research/arm64-toolchain-probe.md
5. Template to adapt (read-only): D:/MyNewProjects/qfli_python/.github/workflows/app-{windows,linux,apple,android,ohos}.yml, D:/MyNewProjects/qfli_python/.github/actions/{app-setup,setup-ohos}/, D:/MyNewProjects/qfli_python/tool/ci/*, D:/MyNewProjects/qfli_python/windows/installer/qfli_python.iss

Deliverables (exact paths, all new, inside the worktree):
- .github/workflows/app-installers.yml
- .github/actions/app-setup/action.yml
- .github/actions/setup-ohos/{action.yml,setup.sh,LICENSE} (copy from qfli_python; keep the cache step removed)
- tool/ci/{resolve_flutter.sh,setup_flutter.sh,app_version.sh,run_logged.sh,stage_artifact.sh,package_linux.sh,thin_macos_app.sh,strip_ohos_signing.py}
- windows/installer/qflistudio.iss

Hard constraints:
- `uses:` may only be these, pinned by full SHA with a `# vX.Y.Z` comment, or a local `./qflistudio/.github/actions/...` path:
  - actions/checkout@3d3c42e5aac5ba805825da76410c181273ba90b1 # v7.0.1
  - actions/cache@55cc8345863c7cc4c66a329aec7e433d2d1c52a9 # v6.1.0
  - actions/upload-artifact@cf430e030ddbb5b0abf93d22962f4752f3646cd9 # v7.0.2
  - actions/setup-node@949feb2413d6458794dcd2491c4babbbce0c15c1 # v7.1.0 (OHOS job only)
  No other action. No FORCE_JAVASCRIPT_ACTIONS_TO_NODE24 or similar env.
- Toolchains: OHOS job uses the fork https://gitcode.com/openharmony-tpc/flutter_flutter.git tag 3.27.5-ohos-1.0.1 commit 12587c79e88aacf3172a84e536f226457d037594. Every other job uses official Flutter resolved once by a `resolve-flutter` job (latest stable from releases_linux.json, or the workflow_dispatch input `flutter_version`), installed by `git clone --depth 1 --branch <version> https://github.com/flutter/flutter.git` and verified against the resolved commit.
- Workspace layout: app checked out to `qflistudio/`, core (azurekiln2333/qflistudio-core, ref = input `core_ref` or `main`) to `qfli_studio_core/`. `defaults.run.working-directory: qflistudio`, `shell: bash`.
- Triggers exactly as prd.md R6 (main + ci/** pushes, v* tags, PRs to main with paths filter, workflow_dispatch with inputs flutter_version and core_ref). permissions contents: read. concurrency per ref with cancel-in-progress.
- Matrix and runners exactly as design.md section 3. Artifact and file names exactly as design.md section 7.
- Every architecture assertion in prd.md AC5 must fail the job when it does not hold.
- OHOS: run setup-node (24.14.1) AFTER setup-ohos so its PATH entry wins; export NODE_HOME; fail unless `node --version` is v24.14.1. Before relying on PATH, read how the fork invokes hvigor (D:/ProgramFiles/flutter_ohos/packages/flutter_tools/lib/src/ohos/ and the hvigorw script semantics in the HarmonyOS command-line tools) and make sure hvigor really runs on that Node. Document what you found in a comment in the workflow.
- Windows arm64 (windows-11-arm): verify from the upstream Flutter source (tag of the resolved version; raw.githubusercontent.com/flutter/flutter/<tag>/bin/internal/update_dart_sdk.sh and .ps1) whether the bash entry point `bin/flutter` downloads the arm64 Dart SDK on MINGW arm64. If it does not, invoke `flutter.bat` on Windows. State the evidence in a comment.
- macOS: `FLUTTER_XCODE_ARCHS=<arch> flutter build macos --release`, then tool/ci/thin_macos_app.sh as design.md section 5 says.
- Android: debug keystore created in the job with keytool and passed through ANDROID_KEYSTORE_PATH / ANDROID_KEYSTORE_PASSWORD / ANDROID_KEY_ALIAS / ANDROID_KEY_PASSWORD (see android/app/build.gradle.kts). `flutter build apk --release --split-per-abi --target-platform android-arm,android-arm64,android-x64`.
- Linux: icon and .desktop for the package come from files already in the repo (pick an existing PNG app icon, for example under macos/Runner/Assets.xcassets/AppIcon.appiconset/). Application id com.azurekiln.qfli.qflistudio, binary qflistudio.
- Every job writes BUILD_INFO.txt (Flutter version + commit, app commit, core commit, runner image, tool versions) and SHA256SUMS via stage_artifact.sh, and uploads one artifact per platform/arch.
- Comments in the workflow and scripts in English, short, matching the template's density.

Self-check before you report (implement.md section 4):
- Download the actionlint release binary for windows_amd64 from https://github.com/rhysd/actionlint/releases (latest) into D:/MyNewProjects/_scratch/actionlint/ and run it on the workflow. Zero findings required.
- `bash -n` every shell script; `python -m py_compile tool/ci/strip_ohos_signing.py`; shellcheck if available.
- `grep -rhoE 'uses:\s*\S+' .github | sort -u` matches the allowlist above.
- Run tool/ci/resolve_flutter.sh locally and show its output.
- Run strip_ohos_signing.py on a COPY of ohos/build-profile.json5 in a temp dir and show the result has no signingConfigs material.

When done, reply in the terminal with: the commit list (git log --oneline e018db9..HEAD), the self-check results, and any deviation from design.md with its reason. At most 40 lines.
