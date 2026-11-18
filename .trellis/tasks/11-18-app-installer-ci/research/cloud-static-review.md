# Cloud static review — app-installers workflow

- Date: 2026-11-18
- Scope: `.github/workflows/app-installers.yml`, `.github/actions/{app-setup,setup-ohos}`, `tool/ci/*`
- Path: worktree `D:/MyNewProjects/_wt/app-installers/qflistudio`, branch `ci/app-installers`, reviewed HEAD `7e1eee6`
- Method: **static only**. No Flutter build, no `pub get`, no `flutter config`, and no main code edit.

## 0. Blocking finding

### B1 — `flutter config --no-enable-ohos` did not exist in the upstream SDK

File: `.github/actions/app-setup/action.yml`, step *Resolve Dart packages*. Fixed in commit `075fe05`.

The step originally ran two `flutter config` calls against the SDK it just installed:

| Workflow line | Call | SDK that must accept it |
| --- | --- | --- |
| former `action.yml:93` | `flutter config --no-enable-ohos` | upstream `3.50.0` (unsupported) |
| current `action.yml` | `flutter config --enable-<platform>-desktop` | upstream `3.50.0` |

`--no-enable-ohos` is a flag of the HarmonyOS fork only. Upstream Flutter has no
`ohos` feature, so `flutter config --no-enable-ohos` exits non-zero with an
unrecognised-option error, and `set -euo pipefail` in the composite step turns
that into a failed job. Five of the six jobs would stop at *Resolve Dart
packages*, before any build: `windows` (both arches), `linux` (both arches),
`macos` (both arches), `ios`, `android`.

The comment above the call states the opposite assumption — that the fork is the
only SDK that reacts to the flag. The guard is also unnecessary: a job without a
HarmonyOS SDK never runs that SDK, so there is nothing to disable.

**Fix applied:** the call and its `if` guard were removed. The workflow keeps
`flutter config --no-analytics` and the `--enable-<platform>-desktop`
calls. The OHOS job needs no statement because the fork enables `ohos` by
default.

The template source (`D:/MyNewProjects/qfli_python/.github/actions/app-setup/action.yml`)
carries the same guard. It never fails there only because every template job
runs the fork. The guard cannot be copied into a workflow that also runs
upstream stable.

## 1. Checks that passed

| Check | Command | Result |
| --- | --- | --- |
| Workflow lint | `actionlint .github/workflows/app-installers.yml` | exit 0 |
| Bash parse of every `run:` block | `python tool/ci/check_run_blocks.py …` | **49 parsed, 1 skipped, 0 failed** |
| Python sources | `python -m py_compile tool/ci/{strip_ohos_signing,check_run_blocks}.py` | exit 0 |
| `uses:` allowlist | grep over workflow and both composite actions | only the four pinned actions plus the two local ones |

The one skipped block is the arm64 Windows build step
(`.github/workflows/app-installers.yml:184-192`). It declares `shell: cmd`, so
`check_run_blocks.py` reports it instead of parsing it. It was reviewed by hand:
the `if not exist` guard is valid `cmd` syntax.

### `uses:` audit (AC4)

| Action | Ref | Runtime |
| --- | --- | --- |
| `actions/checkout` | `3d3c42e5…` v7.0.1 | node24 |
| `actions/cache` | `55cc8345…` v6.1.0 | node24 |
| `actions/setup-node` | `949feb24…` v7.1.0 | node24 |
| `actions/upload-artifact` | `cf430e03…` v7.0.2 | node24 |
| `./qflistudio/.github/actions/app-setup` | local | composite |
| `./qflistudio/.github/actions/setup-ohos` | local | composite |

No `FORCE_JAVASCRIPT_ACTIONS_TO_NODE24`, so AC3 has no suppressed warning to
hide behind.

## 2. Bugs found and fixed before this review

These are already in the commits. They are recorded here because each one would
have failed the cloud run.

| # | Location | Symptom | State |
| --- | --- | --- | --- |
| F1 | five OHOS/Android `python3 - <<'PY'` blocks | terminator indented by YAML; bash read the body as commands | fixed; `check_run_blocks.py` now rejects it |
| F2 | OHOS *Verify the tools layout* | `fi` and the next `if` on one line | fixed |
| F3 | OHOS job | `setup-ohos` appends its `bin` (with the tools' own `node`) to `GITHUB_PATH`, beating `setup-node` | fixed; Flutter and Node are prepended after the tools |
| F4 | Windows PE check | `$machine` used where the matrix value arrives as `$PE_MACHINE` | fixed |
| F5 | Windows *Locate MSVC* | `vswhere -requires` made a hard gate | fixed; component is a preference, toolset layout decides |
| F6 | Android | keystore written to `$RUNNER_TEMP` | fixed; now `$HOME/.android/debug.keystore` |

## 3. Matrix and artifact naming

| Job | Runner | Arch | Artifact |
| --- | --- | --- | --- |
| `windows` | `windows-2022`, `windows-11-arm` | x64, arm64 | `qflistudio-<ver>-windows-<arch>` |
| `linux` | `ubuntu-22.04`, `ubuntu-22.04-arm` | x64, arm64 | `qflistudio-<ver>-linux-<arch>` |
| `macos` | `macos-15` | x86_64, arm64 | `qflistudio-<ver>-macos-<arch>` |
| `ios` | `macos-15` | arm64 | `qflistudio-<ver>-ios-arm64` |
| `android` | `ubuntu-24.04` | 3 ABIs | three artifacts, one per ABI |
| `ohos` | `ubuntu-22.04` | arm64 | `qflistudio-<ver>-ohos-arm64` |

Eleven artifacts for eleven targets (AC2). Names are unique per matrix cell, so
`upload-artifact` never merges two uploads into one name.

### Version passing

`APP_VERSION: "5.0.1"` sits in the workflow `env` and is the only place the
OHOS job can read a version, because the fork does not report one. A guard step
in `resolve-flutter` (`.github/workflows/app-installers.yml:113-121`) compares
`tool/ci/app_version.sh` with that value and fails when they differ, and
publishes the value as the `app-version` output. The other jobs derive the
version from `pubspec.yaml` at packaging time. The two sources cannot drift
without the guard failing first.

`pubspec.yaml` reports `5.0.1` and `ohos/AppScope/app.json5` reports
`versionName 5.0.1`, so the OHOS file name and its `BUILD_INFO.txt` agree today.

## 4. AC status — static evidence only

| AC | Static evidence | Cloud gate still open |
| --- | --- | --- |
| AC1 | workflow exists; `workflow_dispatch` declares `flutter_version` and `core_ref` (`.yml:43-52`) | a manual run starts |
| AC2 | 11 upload steps, `if-no-files-found: error` | all 11 artifacts appear |
| AC3 | four node24 actions, no force flag | Annotations show no Node 20 warning |
| AC4 | table above | — (static, done) |
| AC5 | per-platform arch checks are present | each check runs against a real package |
| AC6 | `flutter --version` runs in the composite after install (`action.yml:92`) | log lines show the resolved version |
| AC7 | OHOS job requires `v24.14.1` twice: `NODE_HOME/bin/node` and `node` | hvigor log shows that Node |

## 5. Left to the cloud run — not verified locally

1. **AC1, AC2, AC3, AC5, AC6, AC7** — every item above needs a real run.
2. **Runner image contents** — `windows-11-arm` Visual Studio layout, MSVC
   redistributable directory, `7z`, `Inno Setup 6`, Inno `Ver` constant for
   `x64compatible`, `macos-15` Xcode, `ubuntu-22.04-arm` and `ubuntu-24.04` apt
   packages, and the JDK 17 environment variables.
3. **`actions/setup-node` cache key** — no pin to check offline; the step reports
   the resolved path and version, which is the evidence AC7 reads.
4. **`gitcode.com` reachability** from GitHub runners, the fork tag
   `3.27.5-ohos-1.0.1`, and commit `12587c79…`.
5. **`ErBWs/ohos-sdk` release `26.0.0.821`** — the download, the split archive
   and its `sha256`, and whether its `sdk-pkg.json` reports API `26`.
6. **`qflistudio-core` at `main`** — the checkout succeeds and the pub cache
   resolves against the sibling path. The workflow takes `main` by default; a
   moved branch head is not pinned.
7. **Upstream compatibility of the app code** — `flutter pub get`, `analyze` and
   a first build on `3.50.0`. This stays with the upstream-compat probe; nothing
   here exercises it.
8. **`FLUTTER_XCODE_ARCHS`** — confirmed to be a real pass-through in
   `xcodeproj.dart` (`environmentVariablesAsXcodeBuildSettings`). Whether Xcode
   builds narrower with `ARCHS` alone is unverified; `thin_macos_app.sh` is the
   guarantee either way.
9. **Android signing** — `android/app/build.gradle.kts:38` uses
   `signingConfigs.getByName("debug")` and reads no `ANDROID_*` variable. The
   workflow still writes a keystore at `$HOME/.android/debug.keystore` and
   exports `ANDROID_KEYSTORE_*`. That matches the default debug location the
   Gradle plugin uses, so the signature check should agree, but only a run proves
   the signer DN is `CN=Android Debug`.
10. **OHOS HAP layout** — the fork writes
    `build/ohos/hap/entry-default-unsigned.hap`; the step falls back to
    `ohos/entry/build/…` and to `find`. The ABI directory is assumed to be
    `libs/arm64-v8a/`.
11. **Windows arm64** — whether `flutter.bat` on `windows-11-arm` really fetches
    the arm64 Dart SDK and produces `build/windows/arm64/runner/Release`.

## 6. Conclusion

The only static blocker found in this review was fixed in `075fe05`. The later
Windows arm64 output-path guard was fixed in `7e1eee6`. The workflow now parses:
`actionlint` exits 0 and all 49 bash `run:` blocks parse, with the single
`shell: cmd` step checked by hand. No local build was run, so AC1-AC7 remain
cloud gates and §5 is the checklist for reading the first run.
