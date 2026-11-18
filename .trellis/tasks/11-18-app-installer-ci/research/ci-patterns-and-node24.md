# Brief B research: CI templates and the Node 24 action audit

Read-only research, gathered on 2026-11-19. Every claim cites a path:line in a local
repository, or the URL that served it. Nothing in `qflistudio` or `qfli_python` was
modified. This file is the only write.

Paths below use these short prefixes:

- `PY/` = `D:/MyNewProjects/qfli_python`
- `ST/` = `D:/MyNewProjects/qflistudio`
- `CORE/` = `D:/MyNewProjects/qfli_studio_core`

---

## 0. Headline answers

| Question | Answer |
| --- | --- |
| Is a zero-warning Node 24 workflow reachable? | Yes, with four actions only. `actions/checkout`, `actions/upload-artifact`, `actions/cache` and `actions/download-artifact` all declare `runs.using: node24` at the versions named in the brief. No `FORCE_JAVASCRIPT_ACTIONS_TO_NODE24` is needed. See §B. |
| Does `subosito/flutter-action` fit? | No. It is a composite that shells out to `actions/cache@v5` (node20) at every tag, and it only reads the official Flutter release JSON. It cannot fetch the OHOS fork. Do not use it. See §2.3 and §3.4. |
| Can we build a real Windows arm64 app on a GitHub runner? | No. Flutter builds `windows-x64` on every Windows host today. The `windows-arm64` target is still open work upstream. See §C.2. |
| Can we build a real Linux arm64 app on a GitHub runner? | Not from an official archive: `releases_linux.json` has no arm64 entry. A git clone builds, but Flutter's own issue says the arm64 artifact packaging is incomplete. See §C.3. |
| Windows-installer tooling on `windows-11-arm` | Inno Setup 6.7.1, NSIS 3.10 and Chocolatey 2.7.5 ship in the arm64 image. A `windows-arm64` binary still needs arm64 MSVC targets, which the image has (`VC.Tools.ARM64`). See §C.2. |

---

## A. Template summary (`PY/.github`)

### A.1 Layout and path dependency resolution

The template keeps two repositories as **siblings inside the runner workspace**. The app
is checked out at `qfli_python/` and the core at `qfli_studio_core/`
(`PY/.github/actions/app-setup/action.yml:29-30`). The literal directory name matters:
the app `pubspec.yaml` depends on `path: ../qfli_studio_core`.

Every app workflow sets a default working directory and shell:

```yaml
defaults:
  run:
    shell: bash
    working-directory: qfli_python
```

(`PY/.github/workflows/app-windows.yml:41-43`, identical at `app-linux.yml:41-43`,
`app-apple.yml:43-45`, `app-android.yml:41-43`, `app-ohos.yml:41-43`.)

`ST/pubspec.yaml` has the same shape and one extra edge:

- `ST/pubspec.yaml:17-18` — `qfli_studio_core: path: ../qfli_studio_core`
- `ST/pubspec.yaml:27-30` — `dependency_overrides: re_editor: path: ../qfli_studio_core/vendor/re_editor`

So a qflistudio job must check out **both** repositories as siblings, with the core
directory named exactly `qfli_studio_core`. `ST/.cnb.yml` already does this and
documents the reason (`ST/.cnb.yml:213-223`).

### A.2 Triggers and inputs

All five app workflows share the same trigger block (`PY/.github/workflows/app-windows.yml:3-24`):

- `push` and `pull_request` filtered by `lib/**`, `assets/**`, `native/**`, the platform
  directory, `pubspec.yaml`, `pubspec.lock`, `tool/ci/**`, `.github/actions/app-setup/**`
  and the workflow file itself.
- `workflow_dispatch` with one optional input, `core_ref`.

`core_ref` is empty by default and falls back to a **pinned commit**
(`PY/.github/actions/app-setup/action.yml:22-26`):

```yaml
ref: ${{ inputs.core-ref || '573d1b6eecf1c2b392ad753264a5a09f62f8335e' }}
repository: azurekiln2333/qflistudio-core
path: qfli_studio_core
persist-credentials: false
```

`PY/.github/actions/app-setup/action.yml:20-26`: the core is fetched with the default
`github.token`, no PAT and no secret. `persist-credentials: false` also holds on the app
checkout (`app-windows.yml:58-60`).

Every job also declares `permissions: contents: read` and a concurrency group keyed on
`github.ref` with `cancel-in-progress: true` (`app-windows.yml:34-39`).

### A.3 `app-setup` composite

`PY/.github/actions/app-setup/action.yml`, four steps:

1. **Check out the core** at the pinned commit, into `qfli_studio_core` (lines 20-26).
2. **`actions/cache@v6`** for the Flutter SDK directory `${{ runner.temp }}/flutter`, with
   key `flutter-12587c79e88a-<os>-<arch>-<cache-scope>` (lines 28-32). `cache-scope` is a
   required input and is the job name, so each target keeps its own SDK copy.
3. **Install the SDK with a git clone**, then export PATH and env (lines 34-41):

```bash
bash tool/ci/setup_flutter.sh "$RUNNER_TEMP/flutter"
echo "$RUNNER_TEMP/flutter/bin" >> "$GITHUB_PATH"
echo "QFLI_FLUTTER_VERSION=3.27.5-ohos-1.0.1 (12587c79...)" >> "$GITHUB_ENV"
echo "QFLI_CORE_COMMIT=$(git -C ../qfli_studio_core rev-parse HEAD)" >> "$GITHUB_ENV"
```

4. **`flutter pub get`** with `flutter config --no-analytics`, skipping
   `--enable-ohos` for every target except `ohos` (lines 43-54). The comment explains
   that the OHOS fork prepares `ohos/` on every pub get and fails without an SDK.

There is **no Flutter action, no `setup-java`, and no `setup-android`** anywhere.
Java comes from the runner image (`JAVA_HOME_17_X64`), and the Android SDK is the image's
`ANDROID_HOME` plus `sdkmanager` for the NDK.

`PY/tool/ci/setup_flutter.sh:10-12` pins the fork:

- repository `https://gitcode.com/openharmony-tpc/flutter_flutter.git`
- tag `3.27.5-ohos-1.0.1`
- commit `12587c79e88aacf3172a84e536f226457d037594`

The script retries `git clone --depth 1 --branch <tag>` three times, then fails on a
commit mismatch (lines 28-52). It re-fetches the tag when a shallow clone lost it, because
`flutter --version` derives the version from the tag (lines 54-56). No credentials are used;
the gitcode repository is public.

### A.4 `setup-ohos` composite

`PY/.github/actions/setup-ohos/action.yml` is a **local copy of `ErBWs/setup-ohos` (MIT)
at commit `4dbb63025116eb6165ceac58a4bf47cbdc5ac721`**, i.e. tag `v2.0.0`. The description
states the cache step was removed "because that step pulled in a Node 20 action"
(`action.yml:2`). The remaining body is one `chmod` (lines 20-22) and one script call
(lines 23-28); the only token passed is `github.token` as `GH_TOKEN` (line 26).

`PY/.github/actions/setup-ohos/setup.sh`:

- Picks the archive from `RUNNER_OS`/`RUNNER_ARCH` (lines 5-18). **Linux arm64 and Windows
  arm64 are rejected**: only Linux X64, Windows X64 and macOS x64/arm64 are handled.
- `gh release download <version> -p "ohos-sdk-*.*" -R ErBWs/ohos-sdk` (line 40), then
  concatenates the split `.aa`/`.ab` parts and verifies `sha256sum` (lines 42-48). This is
  a **third-party redistribution**, not an official Huawei mirror. GitHub Releases need no
  authentication, but `gh` needs `GH_TOKEN`; an anonymous token is used.
- Installs under `$HOME/ohos-sdk/command-line-tools` (lines 26, 72).
- **Node for hvigor comes from inside the HarmonyOS tools bundle**:
  `$WORK_DIR/command-line-tools/tool/node` (lines 59-65), and its `bin` is appended to
  `GITHUB_PATH` (lines 81-82). That Node is Huawei's bundled build, not the runner's. The OHOS
  job also asserts `<tools>/tool/node/bin/node` exists
  (`PY/.github/workflows/app-ohos.yml:143-144`).
- Exports `HOS_SDK_HOME`, `OHOS_NDK_HOME`, and `sdk-version`/`api-version` outputs
  (lines 78-88). `ohpm` and `hvigorw` arrive on PATH from the tools' `bin` directory.

`app-ohos.yml` then:

- installs `libgl1-mesa-dev` before setup (lines 85-88),
- verifies `sdk-pkg.json` `data.apiVersion` is the numeric string `26` (lines 98-135),
- probes `node`, `npm`, `ohpm` and `hvigorw` versions as evidence, not as a gate
  (lines 161-176),
- sets `DEVECO_SDK_HOME` for hvigor (lines 190-194),
- strips the local developer keystore paths from `ohos/build-profile.json5` on the runner
  only, via `tool/ci/strip_ohos_signing.py` (lines 204-208),
- builds with `flutter build hap --release --target-platform ohos-arm64 --no-codesign`
  (line 213), and fails if any `*-signed.hap` appears (lines 214-225).

This matters for `ST`: `ST/ohos/build-profile.json5:3-38` tracks two signing configs with
absolute Windows paths (`C:\\Users\\lichengyu\\.ohos\\config\\...`, `D:/Keystore/...`).
An OHOS job must strip them the same way, or build fails on a path that does not exist.

### A.5 Per-workflow summary

| Workflow | Runner | Format | arm64 handling |
| --- | --- | --- | --- |
| `app-windows.yml` | `windows-2022` (`:48`) | **Inno Setup 6 installer** (`.exe`, per-user, silent-install verified) + portable `.zip` built with 7-Zip | **None.** x64 only. `dumpbin -headers` asserts `8664 machine (x64)` (lines 186-196). |
| `app-linux.yml` | `ubuntu-22.04` (`:48`) | `.deb` via `dpkg-deb` + `.tar.gz` | **None.** x64 only; `ldd`/`nm` checks and a real `dpkg -i` on the runner. |
| `app-apple.yml` | `macos-15-intel` (`:50`), matrix `ios` + `macos` | iOS: `flutter build ios --no-codesign`, zip of `Payload/Runner.app` → unsigned `.ipa` (lines 158-180). macOS: `flutter build macos --release`, `ditto` staging + `hdiutil create -format UDZO` → **one universal DMG** | macOS asserts **both** `x86_64` and `arm64` slices (lines 215-226). No thin DMG exists today. |
| `app-android.yml` | `ubuntu-22.04` (`:48`) | one `flutter build apk --release` → `app-release.apk` | Three ABIs in one APK (`arm64-v8a`, `armeabi-v7a`, `x86_64`), asserted from the zip listing (lines 133-153). Signer is asserted to be `CN=Android Debug` (line 117). |
| `app-ohos.yml` | `ubuntu-22.04` (`:48`) | `flutter build hap --target-platform ohos-arm64 --no-codesign` (line 213) → unsigned `.hap` | arm64 only, asserted as an AArch64 ELF (lines 256-300). |

Details worth copying:

- **Windows**: locate `vswhere.exe` at its fixed path, read the MSVC toolset version from
  `Microsoft.VCToolsVersion.default.txt`, resolve `dumpbin.exe`, and bundle
  `msvcp140.dll`/`vcruntime140.dll`/`vcruntime140_1.dll` from the VS redistributable
  (lines 79-165). Then assert every `msvcp*`/`vcruntime*` import is present in the package
  (lines 267-330). Inno Setup is installed through Chocolatey **only if ISCC is absent**
  (lines 299-320), and the silent install runs with a 10-minute step timeout because a
  dialog would hang the job (line 364).
- **Apple**: `DEVELOPER_DIR: /Applications/Xcode_16.4.app/Contents/Developer` (line 62).
  That directory is still on `macos-15` and `macos-15-intel` but **not on `macos-26`**
  (see §C.1). The DMG step retries `hdiutil create` three times because hosted runners
  throw "Resource busy" (line 298).
- **Linux**: a real `sudo dpkg -i` plus `desktop-file-validate` on the runner (lines
  149-160).
- **Android**: `JAVA_HOME_17_X64` must exist, is exported to `GITHUB_ENV` and prepended to
  `GITHUB_PATH` (lines 70-82); `sdkmanager` installs the pinned NDK and CMake; the packaged
  `libqfli_py.so` is later extracted and checked for ELF machine, `NEEDED` set and 16 KiB
  load alignment with `llvm-readelf` (`app-android.yml:168-235`).

### A.6 `PY/tool/ci/*.sh` helpers

| File | Purpose | Generic enough to copy to `ST`? |
| --- | --- | --- |
| `app_version.sh` | Print `version:` from `pubspec.yaml` without the `+build` suffix. | **Yes, unchanged.** Both apps keep `version:` on one line (`ST/pubspec.yaml:5`). |
| `run_logged.sh` | Tee a command's output and repeat the tail as an `::error title=...` annotation. | **Yes, unchanged.** Escapes `%` and joins lines with `%0A`. |
| `stage_artifact.sh` | Build `build/ci-artifacts/app-<platform>/` with packages, `LICENSE`, `BUILD_INFO.txt` and `SHA256SUMS`. | **Adapt.** Requires `LICENSE` and `native/LICENSE-MicroPython`. `ST` has `LICENSE` (GPL-3, commit `e018db9`) but no MicroPython copy, so the second `cp`
(`stage_artifact.sh:36`) must go. |
| `setup_flutter.sh` | Clone the pinned Flutter OHOS fork and verify the commit. | **Adapt.** Same fork pin is plausible for `ST`, but the script hardcodes nothing about the app, so a copy works; keep `--no-enable-ohos` for non-OHOS jobs as `app-setup` does. |
| `package_linux.sh` | Build `.tar.gz` + `.deb` (install to `/opt/qfli-pyflow`, launcher in `/usr/bin`, `.desktop`, pixmap). | **Rewrite.** Names, `Architecture: amd64`, `Depends:` and the `qfli_python` binary are all hardcoded (`package_linux.sh:22-25`, `:95-98`, `:107`). |
| `strip_ohos_signing.py` | Remove or rewrite local signing material in `ohos/build-profile.json5` on the runner. | **Adapt.** `ST` needs the same treatment; see §A.4. |

The `.iss` installer script itself lives at `PY/windows/installer/qfli_python.iss` and is
invoked with `/D` defines for version, source dir, output dir and base filename
(`app-windows.yml:379-384`). `ST` has **no equivalent**; a new `.iss` is required.

---

## B. Node 24 audit

### B.1 Method

For each action I fetched `action.yml` (falling back to `action.yaml`) at the exact tag:

```
curl -fsSL https://raw.githubusercontent.com/<owner>/<repo>/<tag>/action.yml
```

and read `runs.using`. For SHAs I used `git ls-remote --tags https://github.com/<owner>/<repo>`
and took the peeled `^{}` value where the tag is annotated. Checked on 2026-11-19.

### B.2 Result table

| action | tag | sha | runs.using | verdict |
| --- | --- | --- | --- | --- |
| `actions/checkout` | `v7.0.1` (also `v7`) | `3d3c42e5aac5ba805825da76410c181273ba90b1` | `node24` | **OK.** Use it. `v7` is a moving alias that currently equals `v7.0.1`; pin the SHA. |
| `actions/upload-artifact` | `v7.0.2` (also `v7`) | `cf430e030ddbb5b0abf93d22962f4752f3646cd9` | `'node24'` | **OK.** |
| `actions/download-artifact` | `v8.0.2` (also `v8`) | `9000827ccba6bdab643e8b6fd33ac0654aef8333` | `'node24'` | **OK.** Only needed for a release job that merges platform artifacts. |
| `actions/cache` | `v6.1.0` (also `v6`) | `55cc8345863c7cc4c66a329aec7e433d2d1c52a9` | `'node24'` | **OK.** Use for the Flutter SDK cache. |
| `actions/setup-java` | `v6.2.0` (latest v6.x) | `77dd5b2ce225ea11469928ac317850245a74ae78` | `'node24'` | **OK**, but not needed: the template uses the image JDK (`JAVA_HOME_17_X64`). |
| `actions/setup-node` | `v7.1.0` (also `v7`) | `949feb2413d6458794dcd2491c4babbbce0c15c1` | `'node24'` | **OK**, but not needed: hvigor uses Huawei's bundled Node (§A.4). |
| `actions/setup-python` | `v7.1.0` (also `v7`) | `6d4fd22b20465ccc0f7354476588e8df7c9ca0e0` | `'node24'` | **OK**, but not needed: `ubuntu-22.04`/`24.04` already ship `python3`, and the template only uses `python3` inline. |
| `android-actions/setup-android` | `v4.0.4` | `be39fa834029ff78f1a44aa3bb0819b8fc2bd8fd` | `node24` | **OK** (no quotes in its file), but not needed: `ANDROID_HOME` is preinstalled. |
| `subosito/flutter-action` | latest is `v2.23.0`; **`v2.26.0` does not exist** | `1a449444c387b1966244ae4d4f8c696479add0b2` | `composite` → shells `actions/cache@v5` | **REJECT.** `actions/cache@v5` is node20, so every job using it warns. It also downloads only official Flutter archives, so it cannot install the OHOS fork. |
| `msys2/setup-msys2` | `v2.33.0` | `ec48f7c5447b3140e2b088413ae3a55687bccb6e` | `'node24'` | **OK** if MSYS2 is wanted. Not needed: `shell: bash` already resolves to Git Bash on Windows runners. |
| `openharmony-rs/setup-ohos-sdk` | `v1.0.1` | `b312caf8a43bb836aa24c08f65f97e1f09a89cad` | `"composite"` → `actions/cache@27d5ce7f...` (v5) | **REJECT.** Same node20 leak. It also installs the **OpenHarmony** SDK, not the HarmonyOS command-line tools that the Flutter OHOS fork needs. |

Notes on the SHAs: `actions/cache` `v6`, `v6.1.0` and `v6.2.0` are distinct tags pointing at
`55cc834...`, `d23441a...` and `b843ebf...`; the brief's `v6.1.0` is the middle one. The OHOS
actions are annotated-tag-free (lightweight tags), so only one SHA each.

### B.3 Every `uses:` in the template, recursively

Direct `uses:` in `PY/.github/workflows/*.yml` and `PY/.github/actions/*/action.yml`:

| File:line | Entry | Resolved `runs.using` |
| --- | --- | --- |
| `app-android.yml:58`, `app-apple.yml:75`, `app-linux.yml:55`, `app-ohos.yml:60`, `app-windows.yml:58` | `actions/checkout@v7` | node24 |
| `native-apple.yml:42`, `native-build.yml:41`, `native-ohos.yml:40` | `actions/checkout@v7` | node24 |
| `app-android.yml:230`, `app-apple.yml:343`, `app-linux.yml:180`, `app-ohos.yml:313`, `app-windows.yml:414` | `actions/upload-artifact@v7` | node24 |
| `native-apple.yml:54`, `native-build.yml:108`, `native-ohos.yml:86`, `native-ohos.yml:102` | `actions/upload-artifact@v7` | node24 |
| `native-apple.yml:45`, `native-ohos.yml:46` | `actions/setup-python@v7` | node24 |
| `app-setup/action.yml:20` | `actions/checkout@v7` | node24 |
| `app-setup/action.yml:29` | `actions/cache@v6` | node24 |
| `app-*/**:` | `./qfli_python/.github/actions/app-setup` | composite, clean (deps above are node24) |
| `app-ohos.yml:94` | `./qfli_python/.github/actions/setup-ohos` | composite, clean (vendored, cache step already removed) |

**Recursion result: the template is already Node-24 clean at every tag it names.** The two
composites that must be re-implemented rather than copied are `subosito/flutter-action` and
`openharmony-rs/setup-ohos-sdk` (both composite → `actions/cache@v5` / `v4`).

### B.4 Replacement proposals

1. **Flutter SDK**: keep the template's pattern — a shell script that shallow-clones the
   pinned fork and verifies the commit (`PY/tool/ci/setup_flutter.sh`), wrapped in a
   composite whose only action dependency is `actions/cache@v6`. That is exactly what
   `PY/.github/actions/app-setup/action.yml` does, and it is why that workflow is
   warning-free.
2. **OHOS tools**: keep the vendored, cache-free copy of `setup-ohos`
   (`PY/.github/actions/setup-ohos`), which already documents that the cache step brought
   in node20. Do not adopt `openharmony-rs/setup-ohos-sdk`; it reintroduces that leak and
   targets the wrong SDK.
3. **Anything else**: nothing else is required. `setup-java`, `setup-node`,
   `setup-python`, `setup-android` and `msys2/setup-msys2` are all node24 at current tags
   but are avoided by the template.

---

## C. Runner labels and arm64

### C.1 Verified labels

From `https://github.com/actions/runner-images` `README.md` (fetched 2026-11-19), lines
24-38 of the fetched copy:

| Target | Label | Verified |
| --- | --- | --- |
| Windows x64 | `windows-2025` / `windows-latest`, `windows-2022` | yes (lines 36-37) |
| **Windows arm64** | **`windows-11-arm`**, also `windows-11-vs2026-arm` | yes (line 38, "Windows 11 Arm64 with Visual Studio 2026") |
| Linux x64 | `ubuntu-24.04` / `ubuntu-latest`, `ubuntu-22.04`, `ubuntu-26.04` | yes (lines 24-27) |
| **Linux arm64** | **`ubuntu-24.04-arm`**, **`ubuntu-22.04-arm`**, `ubuntu-26.04-arm` | yes (lines 26, 28, 23) |
| macOS arm64 | **`macos-15`**, **`macos-26`**, `macos-15-xlarge`, `macos-26-xlarge` | yes (lines 32, 34) |
| **macOS intel** | **`macos-15-intel`**, `macos-15-large`, `macos-26-intel`, `macos-26-large` | yes (lines 31, 33) |
| macOS intel, retired | `macos-14` | deprecated; *all* macOS 14 images retired from GitHub Actions on **2026-11-02** (line 41). Do not use. |

Deprecation policy: images begin deprecating once a newer GA OS exists; the repo maintains
at most 2 GA plus 1 beta image per platform (`README.md` lines 118-119, 152-158). Practical
consequence: `windows-2022` and `ubuntu-22.04` are the oldest supported images and should be
treated as time-limited.

Important **Xcode** caveat for a macOS job. `macos-15` and `macos-15-intel` still carry
`/Applications/Xcode_16.4.app` as default (image `20261104.0514.1` and `20260824.0482.1`).
`macos-26` arm64 carries only Xcode `26.0.1 … 26.6` (image `20261102.0473.1`). The template
hardcodes `DEVELOPER_DIR=/Applications/Xcode_16.4.app/...`
(`PY/.github/workflows/app-apple.yml:69`), so that line **cannot** be copied onto `macos-26`.

### C.2 Does Flutter stable build Windows arm64 apps?

**No, not today.** Evidence:

- `packages/flutter_tools/lib/src/commands/build_windows.dart:78-81` (tag `3.50.0`, latest
  stable in `releases_windows.json`):
  ```dart
  final defaultTargetPlatform = (os.hostPlatform == HostPlatform.windows_arm64)
      ? 'windows-arm64'
      : 'windows-x64';
  ```
  i.e. the target follows the **host**. On an x64 host you get x64. On an arm64 host you
  would request `windows-arm64`, but the rest of the chain is not complete.
- `flutter/flutter` issue **#190897** (open, 2026): Windows Arm64 AOT snapshots still use
  ELF, because `gen_snapshot` supports PE/COFF only for x64; the embedder's DLL-path case
  is guarded by `#if FML_OS_WIN && FML_ARCH_CPU_X86_64`.
- `flutter/flutter` issue **#136417** (open): there is still **no Windows arm64 Flutter SDK**;
  the only Windows SDK assumes an AMD64 host and runs under emulation on Arm.
- `flutter/flutter` issue **#129807** (open): the tool still needs work to target Arm64.

So `windows-11-arm` today produces an **x64** `flutter build windows` output, and
`runs-on: windows-11-arm` would only add risk: the image has no `JAVA_HOME_17_X64`,
only `JAVA_HOME_21_AARCH64` and `JAVA_HOME_23_AARCH64` (arm64 image readme, lines 130-131).
Recommendation: build Windows **x64** on `windows-2022` (as the template does), and ship
the arm64 claim only as an explicitly labelled "x64 build, runs under Windows-on-Arm
emulation" note — or drop it.

If an arm64 build is still required, the honest options are (a) wait for upstream, or
(b) cross-compile with `-A arm64` against arm64 MSVC targets on `windows-11-arm`
(`VC.Tools.ARM64` is present in that image) — which Flutter's tooling does not pass today,
so the CMake cache would need a manual `-A arm64` and the AOT snapshot problem in #190897
would still apply. Neither is recommended for this task.

### C.3 Does Flutter stable build Linux arm64 apps?

There is **no official arm64 archive** for Linux or Windows hosts. Counts from
`https://storage.googleapis.com/flutter_infra_release/releases/releases_linux.json` and
`.../releases_windows.json`:

| OS | releases | `dart_sdk_arch` values | archives matching `arm` |
| --- | --- | --- | --- |
| linux | 751 | `''` (431), `x64` (320) | **0** |
| windows | 749 | `''` (431), `x64` (318) | **0** |
| macos | 1023 | `''` (430), `x64` (320), `arm64` (273) | n/a (arm64 supported) |

So an official Linux/Windows arm64 SDK must be **git cloned**. But even a clone is not
enough for a linux-arm64 build according to upstream:

- `flutter/flutter` issue **#188932** (open, "Release Packaging for Linux Arm64"): "Today we
  build the Linux Arm64 engine artifacts — but they are missing from the Linux
  stable_packaging_release_builder. Work around: download the stable x64 package, delete
  the `bin/cache` folder, and re-download artifacts for arm64."
- `flutter/flutter` issue **#186695** (open): `linux-arm64` bots are still being added.

A `ubuntu-22.04-arm` job therefore costs extra work (clone, drop `bin/cache`, re-run
`flutter precache`) and is not supported. Recommendation: build Linux **x64** on
`ubuntu-22.04`, and treat `linux-arm64` as out of scope until #188932 closes — or, if the
deliverable is mandatory, build it with the documented workaround and label it
"experimental, arm64-host only".

### C.4 Does `subosito/flutter-action` support arm64 hosts?

Partly, and not usefully for us:

- `action.yaml` at `v2.23.0` exposes `architecture` defaulting to `${{ runner.arch }}`
  (lines 21-24) and forwards it as `-a` to `setup.sh`.
- `setup.sh` filters releases with `filter_by_arch`, selecting on `dart_sdk_arch == arch`
  (lines 28-31 of the fetched script). On a Linux or Windows **arm64** runner no release
  matches, so the action fails with *"Unable to determine Flutter version for channel …
  architecture … arm64"*.
- On a **macOS** arm64 runner it works (macOS has arm64 archives).
- It also cannot install the OHOS fork: it resolves through the official JSON only, so
  `flutter-version: 3.27.5-ohos-1.0.1` will not be found.

---

## D. macOS single-arch: thin-and-resign vs build-time `ARCHS`

### D.1 How Flutter decides the macOS architectures

`packages/flutter_tools/lib/src/macos/build_macos.dart` (tag `3.50.0`):

- lines 236-240: `hostArch` is `arm64` or `x86_64`.
- lines 248-256: for **release/profile**, `destination` is the *generic* macOS platform and
  `archs` is `'arm64'` only when the `macOSArm64Only` feature flag is enabled; otherwise
  `archs` is `null`, i.e. **universal by default**.
- lines 259-266: `EXCLUDED_ARCHS` is read from the Xcode project's build settings and
  passed to `xcodebuild` (line 321), and `ARCHS=$archs` is passed when set (line 323).
- lines 283-290: the tool **throws a tool exit** if you enable the arm64-only flag while
  `EXCLUDED_ARCHS` still contains `arm64` ("No Valid Target Arch").
- lines 267-278: on Xcode 27+, Flutter warns that x86_64 is no longer required and suggests
  `flutter config --enable-macos-arm64-only`.

The feature flag (`lib/src/features.dart`, `const macOSArm64Only`): config setting
`enable-macos-arm64-only`, env override `FLUTTER_MACOS_ARM64_ONLY`, available on all
channels, **disabled by default** today.

Critically: x86_64-only is **not reachable through this flag at all**. The flag only narrows
to arm64.

### D.2 Option 1 — thin every Mach-O, then ad-hoc re-sign

```
flutter build macos --release            # universal .app
find <app> -type f -exec sh -c 'file -b "$1" | grep -q Mach-O' _ {} \; -exec lipo -thin x86_64 {} -output {} \;
codesign --force --deep -s - <app>
```

Plus: produces exactly the two DMGs the brief asks for from any one macOS runner; keeps the
project files untouched; the template's inspection step (`lipo -archs` per slice) still
applies after thinning.

Minus: `lipo -thin` rewrites each Mach-O **after** Xcode signed it, so **every** nested code
object (the main executable, `App.framework`, `FlutterMacOS.framework`, every pod framework
and dylib, and anything under `Contents/Frameworks`) needs re-signing, in the right order.
`codesign --deep` performs that walk but is documented by Apple as unsuitable for
distribution signing; for **ad-hoc** signatures that caveat is tolerable, yet it is still the
fragile part. Additional risks: `--deep` does not re-sign files it does not recognise as code;
extended attributes and the sealed-resource (`_CodeSignature/CodeResources`) hashes must be
regenerated; and the entitlements file must be re-applied (`--entitlements`) or the app loses
its sandbox setting.

### D.3 Option 2 — `ARCHS`/`EXCLUDED_ARCHS` at build time

Two sub-variants, both run `flutter build macos --release` with the Xcode setting applied:

- **`ARCHS=x86_64`** on the `flutter build macos` command line (xcodebuild settings given on
  the `flutter` command line are forwarded by Flutter as env → Xcode settings). Flutter sees
  `buildSettings['EXCLUDED_ARCHS']` only, so `ARCHS` from the project is honoured and nothing
  conflicts; the flag's "No Valid Target Arch" guard never fires because the flag is off.
- **`EXCLUDED_ARCHS=arm64`** in `macos/Runner/Configs/Release.xcconfig`. Flutter reads this
  from the project and forwards it (build_macos.dart:259-266, 321). This variant **breaks**
  if anyone later enables `flutter config --enable-macos-arm64-only`: the tool exits at
  build_macos.dart:283-290. Note `ST/macos/Runner/Configs/Release.xcconfig` currently
  contains only two `#include` lines and no arch settings, and
  `ST/macos/Runner.xcodeproj/project.pbxproj` has no `EXCLUDED_ARCHS`/`ARCHS` overrides
  (only `CODE_SIGN_IDENTITY = "-"` at lines 450, 526, 582 and `ONLY_ACTIVE_ARCH = YES` at
  line 548).

Plus: Xcode builds each slice once for the single arch; the signature Xcode writes is the
signature shipped (the project already uses `CODE_SIGN_IDENTITY = "-"`, i.e. ad-hoc
"Sign to Run Locally", and the template's `codesign --verify --deep --strict` check plus
`Signature=adhoc` assertion at `app-apple.yml:257-266` passes unmodified); no post-hoc Mach-O
rewriting, so `ditto` + `hdiutil` cannot invalidate anything.

Minus: it is a build-time project setting, so it must be expressed somewhere durable; and
`flutter build macos` must be run **twice** (once per arch) to produce two DMGs, doubling
macOS runner minutes. Also `ARCHS` on the flutter command line is passed through
`environmentVariablesAsXcodeBuildSettings`, which only forwards *environment variables* — the
robust way is to set it in the environment (`ARCHS=x86_64 flutter build macos --release`) or
in the xcconfig, and to verify with the existing `lipo -archs` inspection step.

### D.4 Recommendation

**Use option 2, with `EXCLUDED_ARCHS` set from a job-level env var rather than a tracked
xcconfig edit, and `ARCHS` as the primary switch.**

Rationale:

1. The signature Xcode produces survives to the DMG. Option 1's whole risk surface
   (re-signing order, `--deep` semantics, entitlements re-application, sealed resources) is
   removed, and the template's existing ad-hoc verification step keeps working unchanged.
2. Flutter's tool has an explicit, supported path for exactly this:
   `EXCLUDED_ARCHS` is read from the project and forwarded (build_macos.dart:259-266, 321),
   so the intent is not a hack.
3. Option 2 fails loudly. If a later Flutter release turns `macOSArm64Only` on by default,
   option 2 needs one line changed; option 1 keeps "working" while silently producing
   universal binaries and then thinning them — a defect that only shows up after a manual
   `lipo` check.
4. Two DMGs are a deliverable, not an optimisation: two builds are required either way,
   because a thinned binary is still a separate artifact that needs its own checksums,
   staging and `BUILD_INFO.txt`.

Concrete shape:

- `macos-15` (arm64) builds the `arm64` DMG; `macos-15-intel` builds the `x86_64` DMG. On
  each, set `ARCHS` to the slice being shipped.
- Keep `DEVELOPER_DIR=/Applications/Xcode_16.4.app/Contents/Developer` (present on both
  `macos-15*` images, absent on `macos-26`), or move to `macos-26` and use its default
  Xcode 26.6 — but then both jobs must move.
- Keep the template's post-build assertions and add the negative one:
  exactly one arch from `lipo -archs`, and `-1`/`arm64`/`x86_64` as appropriate.
- Do **not** enable `flutter config --enable-macos-arm64-only`; it makes the x86_64 DMG
  impossible (build_macos.dart:248-256).

---

## E. Concrete recommendation for `ST/.github`

- **Windows** — `windows-2022`; x64 only; Inno Setup installer + portable zip. Port the
  template's MSVC-runtime bundling and silent-install check; write a new `qflistudio.iss`.
  Ship arm64 only as a documented emulation note, or defer.
- **Linux** — `ubuntu-22.04`; x64 `.deb` + `.tar.gz`; port `package_linux.sh` with new names.
  Treat `linux-arm64` as blocked on flutter/flutter#188932.
- **macOS / iOS** — `macos-15` and `macos-15-intel`, matrix; two thin DMGs via `ARCHS`
  (option 2, §D.4) plus the unsigned IPA as in `app-apple.yml:158-180`.
- **Android** — `ubuntu-22.04`; one APK with three ABIs; assert `CN=Android Debug`.
  `ST/android/app/build.gradle.kts:43` already pins NDK `27.0.12077973`, the same as the
  template.
- **OHOS** — `ubuntu-22.04`; vendored `setup-ohos` **without** its cache step, plus a
  signing-strip step for `ST/ohos/build-profile.json5` (which tracks local Windows keystore
  paths, lines 3-38). Note `setup.sh:5-18` rejects arm64 runners, so this job must stay x64.
- **Actions allowlist** (all node24, pinned by SHA):
  `actions/checkout@3d3c42e5…`, `actions/upload-artifact@cf430e03…`,
  `actions/cache@55cc8345…`, and optionally `actions/download-artifact@9000827c…`.
  Nothing else. No `FORCE_JAVASCRIPT_ACTIONS_TO_NODE24`.
- **Sibling checkout** — the app as `qflistudio/` and the core as `qfli_studio_core/`, since
  `ST/pubspec.yaml:17-18` and `:27-30` resolve through `../`. `ST/.cnb.yml:213-223` already
  documents this layout.
