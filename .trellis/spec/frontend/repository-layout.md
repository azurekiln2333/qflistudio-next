# Flutter Repository Boundaries

## 1. Scope / Trigger

Apply this contract when reviewing dependency layout, cloud installer checkouts or a new-machine clone. The current app repository is `azurekiln2333/qflistudio-next`; the current shared-core repository is `azurekiln2333/qflistudio-core`. Clone destinations are sibling directories `qflistudio-next/` and `qflistudio-core/`. The Dart package identifier remains `qfli_studio_core`. A clone name is not evidence that the sibling checkout exists.

The 11 language apps are independent repositories. Do not assume they are cloned beside the main app. Historical `apps/`, `packages/`, and `qfli_*` filesystem paths in source documents describe the former layout only. Package and import identifiers such as `qfli_studio_core` are not directory names to rename.

## 2. Signatures and clone contract

New machines clone the two required GitHub repositories explicitly:

```bash
git clone --branch main --single-branch https://github.com/azurekiln2333/qflistudio-next.git qflistudio-next
git clone --branch main --single-branch https://github.com/azurekiln2333/qflistudio-core.git qflistudio-core
git -C qflistudio-core checkout --detach 476a30acee21dc486ee2849dd8064a7be665e4d5
```

The final command uses the `CORE_REF` found in the reviewed workflow snapshot. For another app revision, use that revision's reviewed full `CORE_REF`. Record any authorized `workflow_dispatch.core_ref` override and its resolved full SHA. Do not infer that the core `main` head is the compatible version.

The app declares the Dart package `qfli_studio_core` through the relative sibling directory `../qflistudio-core`; it also uses the vendored `re_editor` and `xterm` overrides within that sibling. Keep filesystem directory names distinct from package/import names.

All package resolution, package-version checks, generation, formatting, analysis, tests and builds run in GitHub Actions. Do not run these commands on a developer checkout, including `flutter pub get` and commands with `--no-pub`. Disable IDE automatic builds, tests, dependency setup and Sync. Do not start WSL or download build artifacts into this workspace.

Cloud logs must record both repository SHAs, app package/version, core package/version, the selected `CORE_REF`, and the lockfile's core path/version. Verify that the resolved package configuration points to that core checkout. A path dependency's lock entry does not contain the core Git SHA; record the checkout SHA separately. Fail cloud verification on a mismatch.

The canonical-import check must inspect quoted Dart `import` and `export`
directives. Do not treat prose containing `package:` as an import or allow a
package-name match to span whitespace and comments. Cloud run `45897093931`
exposed this false positive in the pinned core's runtime catalog documentation.

Core `476a30a` has a legacy self-path in `interop_arkts_contract_test.dart`.
The cloud Core verification job temporarily creates a `qfli_studio_core` symlink
to the canonical `qflistudio-core` checkout for that fixture lookup. This leaves
the pinned source, package identity and all assertions intact. It does not prove
that unmodified Core tests support the canonical layout without this adaptation.
Remove the alias after adopting the owner's verified portability fix.

## 3. Contracts

- `qflistudio-next` owns the main app and its app-local tools.
- `qflistudio-core` owns package `qfli_studio_core`, patched `vendor/re_editor`, and the `vendor/xterm` override.
- C/C++ runtime source is maintained in the separately versioned `qflistudio-cpp` repository. Its nested package paths are internal to that repository; do not project former `apps/` or `packages/` paths onto the new-machine workspace.
- No app/core pub workspace is implied by two sibling clones. Verify the checked-out manifests and versions in cloud CI rather than relying on workspace-wide local package resolution.
- Machine-local `pubspec_overrides.yaml` and `.dart_tool/package_config.json` may refer to private worktrees. Never publish those files or treat their paths as the canonical layout.

## 4. Validation & Error Matrix

| Condition | Required result |
| --- | --- |
| The cloud runner lacks the pinned core checkout | Fail before dependency resolution; check out the exact `CORE_REF` into `qflistudio-core/`. |
| App path dependency does not resolve to the pinned sibling | Fail the cloud package/version check. |
| App or core package name/version differs from the reviewed pair | Fail and report both manifest versions and SHAs. |
| An optional language checkout is absent | Do not fail a main-app-only job; run cross-product jobs only with their declared inputs. |
| Python checkout needs its MicroPython gitlink | Initialize that submodule in the owning Python cloud job. |

## 5. Good / Base / Bad Cases

- Good: cloud CI checks out the app and exact reviewed core commit into the two canonical sibling directories, records package/version resolution, then runs its declared jobs.
- Base: a new workstation contains only `qflistudio-next/` and `qflistudio-core/`; no language-app checkout is implied.
- Bad: call `qfli_studio_core` the directory name, assume `qflistudio-cpp/` already exists, or run `pub get` to test a new workstation locally.

## 6. Tests Required (cloud only)

- In GitHub Actions, resolve the app's package graph against the pinned core. Assert manifest package identities/versions, the lockfile's core path/version, the resolved package path, and the independently recorded checkout SHA.
- Run package-version, analysis, tests and installer jobs in GitHub Actions against the exact reviewed SHA pair.
- Cross-product cloud jobs explicitly check out each required language repository, run its own dependency resolution and wiring tests, and run `tool/verify_runtime_matrix.dart` or `tool/verify_ohos_products.dart` when required. Preserve the 12-product identity assertion; a main-app-only job does not require optional language checkouts.
- Record job/run IDs and actual results. A green run for a different app/core SHA pair does not validate this pair.
- Do not describe a release or device verification as complete from a local checkout or stale cloud run.

## 7. Wrong vs Correct

Wrong: use `qfli_studio_core/` as the canonical clone destination, or infer that all 11 language repositories exist beside the app.

Correct: clone `qflistudio-next/` and `qflistudio-core/`, preserve the package identifier `qfli_studio_core`, pin the reviewed core SHA in CI, and check package versions in the cloud.

## 8. CI Installer Layout

The installer workflow deliberately checks out the app as `qflistudio/` and the core as sibling `qflistudio-core/` inside the cloud runner. `qflistudio/` is a CI checkout alias, not the canonical new-machine directory `qflistudio-next/` and not evidence of an existing local folder. Both app names resolve `../qflistudio-core` to the same sibling. Keep workflow working directories and composite-action paths consistent with this alias.

Windows, Linux, macOS, iOS and Android consume one upstream stable version resolved at the start of the run. OHOS uses the pinned OHOS Flutter fork and its own cache. Keep these SDKs separate.

External JavaScript actions use only SHA-pinned Node 24 actions:

- `actions/checkout@3d3c42e5aac5ba805825da76410c181273ba90b1`
- `actions/cache@55cc8345863c7cc4c66a329aec7e433d2d1c52a9`
- `actions/setup-node@949feb2413d6458794dcd2491c4babbbce0c15c1`
- `actions/upload-artifact@cf430e030ddbb5b0abf93d22962f4752f3646cd9`

Local composite actions may wrap these actions. Do not add a Flutter action that brings a Node 20 cache action transitively.

### Release version and verification contract

Update all four version owners together: `pubspec.yaml`, the
`qfliStudioProfile.clientVersion` in `lib/main.dart`, OHOS
`AppScope/app.json5`, and workflow `APP_VERSION`. The workflow's
`publish-release.if` tag allowlist and release-note text must also match.

Pin `CORE_REF` to the full reviewed Core commit. `ci/**` pushes build installers
without publishing. Only the allowed version tags can publish, and publication
depends on every verification and installer job.

Track CI by repository, workflow, exact SHA, and branch. A completion marker
or a green run for an older SHA is insufficient. Preserve run IDs and actual
results. Check both repositories' `main` runs after integration. Do not describe
physical-device acceptance as complete based on CI.

## 9. GitHub Release Integration

Keep the App version, `StudioProfile.clientVersion`, OHOS version name/code and
installer workflow `APP_VERSION` consistent. Stable `v<APP_VERSION>` tags must
publish a normal GitHub release only after every verification and installer gate
passes. Preview tags remain prereleases. Preserve exact Core/plugin commit pins
and native build provenance when promoting a verified build.

Before reporting a release complete, verify that its App history is reachable
from GitHub main. Promote the verified Core and plugin histories to their GitHub
main branches too. Use normal fast-forward updates when possible. Delete a
topic branch only after proving that its complete history is reachable from the
corresponding main. Preserve local dirty checkouts and existing worktrees.

Windows packaging first uses Visual Studio's declared default redistributable.
Keep `Microsoft.VC*.CRT` outside shell quotes so the wildcard expands. If the
default is unavailable, select the newest usable version with version sorting;
never take the first ascending glob from side-by-side toolsets. Match the target
architecture and require `msvcp140.dll` and `vcruntime140.dll`.

`stage_windows_bundle.ps1` copies the release and checks every executable/DLL's
MSVC imports with the selected `dumpbin`. Run this staging step with `pwsh` on
both architectures. Log the inspected binary, tool path and native exit code.
A nonzero tool exit or missing imported runtime must stop packaging. Do not
turn a runner/native-tool crash into a skipped dependency check.

## 10. Preview release verification

`app-installers.yml` pins `CORE_REF` and `JAVA_REF` to full GitHub commit IDs.
The complete app/core suites use the OHOS Flutter fork, with
`ohos-platform-tooling: "false"` for SDK-less analysis and tests. The HAP job
enables OHOS generation after installing platform tools. Keep infos visible
across the different SDK exports; warnings and errors remain fatal.

A release tag matching the current `APP_VERSION` publishes this preview. Publication waits for the
app/core suites, Node suites on Windows/Linux, the Java receiver host tests,
the Windows assistant build and every main app installer target. It checks
each artifact's version, source revisions, SDK and checksums before publishing.
Never substitute old artifacts for a failed job in the tagged run.

Download the single assistant artifact with an exact `name` and a full named
destination path. The pinned download action extracts a single pattern match
directly into `path`, even when `merge-multiple` is false. Do not assume the
artifact-name subdirectory used for multiple matches also exists for one match.

The portable Windows assistant carries Node, MSVC DLLs and locked production
agent dependencies. `Start-QFLI-Remote.cmd` sets `CLOUDTERMINAL_NODE` and
`CLOUDTERMINAL_AGENT_DIR`. Packaging runs both the scripted protocol E2E and
the actual sidecar first-run pairing smoke with isolated configuration.
Missing optional Herdr yields an unavailable status; it must not crash startup.

Android preview APKs use a debug certificate. Windows is unsigned, macOS uses
ad-hoc signing, and iOS/OHOS require signing before installation. Cloud host
tests do not establish device or live-provider acceptance. Do not include
developer identities or local signing material in any preview artifact.

## 11. Git plugin release contract

### Scope / Trigger

Apply this contract when changing `qfli_git`, its Core dependency pin, native
payloads, or installer provenance. The App consumes the plugin through Core.

### Signatures

- `plugin_provenance.py --write-env <file>` records the resolved plugin facts.
- `plugin_provenance.py --require-release-ready` rejects incomplete imports.
- `check_git_payload.py --platform <android|ios|ohos> --archive <package>`
  accepts `--abi`, `--contract`, `--lock`, `--plugin-root`, and `--nm`.

### Contracts

The pinned plugin lock uses schema 2 and API 3. All three platform source commits must
match its full `source.commit`. Import all three native artifacts in one command.
Core pins the artifact commit, and the App workflow pins the resulting Core
commit. A source commit with old checked-in binaries is an interim pin only.

The shared setup installs Python 3.13 before provenance checks; system Python
3.10 lacks `hashlib.file_digest`. Each installer records `plugin_commit`,
`plugin_native_source`, `plugin_native_release`, `plugin_native_api_version`,
`plugin_cacert_sha256`, and `plugin_pending=0` in `BUILD_INFO.txt`.

The plugin checkout verifies native bytes against its lock. APK/HAP/IPA checks
verify ABI, exported symbols, and the exact packaged CA digest. Packaging can
strip Android libraries or codesign iOS frameworks, so a packed binary hash
is recorded but is not required to equal the imported binary hash.

OHOS release builds exclude `**/x86_64/**` through the entry module's
`buildOptionSet[name=release].nativeLib.filter.excludes`. The plugin HAR ships
both device and simulator libraries; a target-platform flag alone does not
filter prebuilt HAR payloads. Keep debug simulator libraries and the strict
ARM64-only release payload check.

### Validation & Error Matrix

| Condition | Required result |
| --- | --- |
| Missing native files, wrong API, divergent source, or changed hash | Stop staging. |
| Packed library, required export, or CA missing | Fail the package job. |
| Unresolved plugin facts or different installer pins | Refuse publication. |
| Windows CRLF conversion affects a fingerprinted file | Keep LF via plugin attributes. |

### Good / Base / Bad Cases

- Good: import matching cloud binaries, validate the lock, then pin artifact/Core commits.
- Base: a source-only run may exercise host FFI while mobile binaries are rebuilt.
- Bad: tag the App with an interim plugin pin or substitute an earlier installer.

### Tests Required

Cloud runs execute both Python regression files, real plugin FFI tests, the
complete Core/App suites, platform examples, and the installer matrix. Assert
unborn history, per-file staging, dirty-buffer refusal, owning-project routing,
clone cleanup, missing payload/export/CA rejection, and matching provenance.
User-directed cloud-only validation forbids local test/build execution.

The App's `git-ios-integration` job checks out the exact resolved plugin
artifact commit outside the pub cache. It verifies the native lock and runs the
unchanged example clone/branch/conflict/merge/push integration test on the same
upstream Flutter SDK as the App's IPA job. Keep the bounded test step, verbose
launch logs, and diagnostic upload. Preview publication depends on this job;
an IPA build or a native symbol check alone is not a runtime integration test.

### Wrong vs Correct

Wrong: add project repositories globally to fix Flutter plugin resolution.
The SDK settings use `FAIL_ON_PROJECT_REPOS`. Correct: add Maven Central only
to `settings.pluginManagement.repositories` from the CI init script.

## 12. GitHub client ID in installer builds

### Scope / Trigger

Apply this contract when changing app build commands in `app-installers.yml`.

### Signatures

Bash build commands pass `--dart-define="QFLI_GITHUB_CLIENT_ID=$QFLI_GITHUB_CLIENT_ID"`.
The Windows ARM64 CMD build uses `%QFLI_GITHUB_CLIENT_ID%` instead.

### Contracts

The workflow reads repository variable `vars.QFLI_GITHUB_CLIENT_ID` and falls back to the committed public app identifier. Pass the value to the seven build-command families in the retained contract: Windows x64, Windows ARM64, Linux, macOS, iOS, Android and OHOS. Every architecture/ABI matrix expansion must inherit that define too; seven is not a fixed installer-artifact count. The standalone Windows assistant does not use GitHub login. Never substitute a client secret or personal access token for this public identifier.

This section preserves the release contract from `1052f3b`, renumbered after the existing sections. Documenting or inspecting the wiring does not establish a successful cloud run.

### Validation & Error Matrix

| Condition | Required result |
| --- | --- |
| Repository variable is absent or empty | Use the committed public client ID. |
| Repository variable is set | Compile with that public client ID. |
| Environment variable is set without `--dart-define` | The app receives an empty ID and disables OAuth. |

### Good / Base / Bad Cases

- Good: override the repository variable and pass it to every main-app build command.
- Base: build with the committed public ID and no repository variable.
- Bad: configure only the process environment or use Bash variable syntax in the CMD step.

### Tests Required

Only in GitHub Actions: parse the workflow YAML, syntax-check Bash blocks, and inspect every main-app build command and matrix variant for the define and correct shell syntax. Assert both repository-variable override and empty/unset-variable fallback. Verify OAuth behavior in a cloud test or separately authorized device acceptance. Do not run these checks or builds on a developer PC.

### Wrong vs Correct

Wrong: expect Dart `String.fromEnvironment` to read the runner process environment.

Correct: pass the public value through Flutter's `--dart-define` option.

