# Pi D cloud CI handoff

Owner: Pi D (dependency and GitHub CI wiring) for
`11-20-studio-git-integration`, branch `release/studio-git-ui-20261120`.

No local test, build, emulator or probe run happened at any point. GitHub
Actions is the only runner. Everything below was established by source review
plus the static checks listed at the end.

## Final scope

| Area | Delivered | Status |
| --- | --- | --- |
| Plugin `qfli_git/.github/workflows/native.yml` | `release/**` push trigger; `dart-checks` gated on a host build from the same run and fed that run's library through `QFLI_GIT_LIBRARY`; `--contract` on every collector; iOS collectors pass `--nm`; importers pass `--commit` and `--run` | handed to root, committed |
| Plugin `qfli_git/tool/ci/native_contract.json` | API v2 contract: 28 exports, `symbolPrefix`, per-platform packaging paths, CA bundle, upstream pins | committed |
| Plugin `qfli_git/tool/ci/collect_artifacts.py` | `--contract` required; manifest schema 2 carries `apiVersion`, `requiredExports`, `contractSha256`; strict Mach-O line parsing and per-architecture `nm -arch` queries; host builds exempt from the 16 KiB LOAD gate while mobile payloads keep it | committed |
| Plugin `qfli_git/tool/ci/check_library.py` | host check validates format and exports only; `--require-page-alignment` opts into the mobile gate | committed |
| Plugin `qfli_git/tool/import_artifacts.py` | local imports require both `--commit` and `--run`, with a 40-hex SHA and an https run URL; contract mismatch refused | committed |
| Plugin regression tests | `test_collect_artifacts.py`, `test_import_artifacts.py`, `test_macho_exports.py`, `test_check_library.py` updated or added for the API v2 fixtures, provenance rules, fat-binary headers and host alignment | committed |
| App `tool/ci/plugin_provenance.py` | `pubspec.lock` read as YAML (PyYAML when importable, strict fallback otherwise) with shared validation; `QFLI_PLUGIN_PENDING` always emitted; native lock, contract digest, CA digest and binding/header API agreement enforced | frozen, app candidate |
| App `tool/ci/check_git_payload.py` | packaged-payload check against contract and native lock; records `packedSha256` as informational | frozen, app candidate |
| App `tool/ci/stage_artifact.sh` | refuses `unknown`/`pending` plugin facts, `plugin_pending != 0` and API other than 2; `QFLI_PLUGIN_PENDING` defaulted before `set -u` | frozen, app candidate |
| App `.github/workflows/app-installers.yml` | `git.*` preview tag path; per-package and cross-package plugin fact validation; `--lock` on all three payload call sites; release body; helper-script unittest step | frozen, app candidate |
| App `.github/actions/app-setup/action.yml` | SHA-pinned `actions/setup-python` 3.13 ahead of every provenance call, with a hard failure when `hashlib.file_digest` is unavailable | frozen, app candidate |
| App `tool/ci/test_plugin_provenance.py`, `test_check_git_payload.py` | 20 + 20 cloud-only regression tests | frozen, app candidate |

Core `pubspec.yaml` / `pubspec.lock` were explicitly reassigned to root before I
touched them, so the `qfli_git` full-SHA pin and the final `CORE_REF` are not
mine. I never edited core manifests.

## Release-only ABI fix

`ohos/entry/build-profile.json5`, committed as `cbce35c`, app candidate
`f47151c`.

Cause: the pinned `qfli_git` HAR ships both payloads,
`ohos/libs/arm64-v8a/libqfli_git.so` and `ohos/libs/x86_64/libqfli_git.so`.
hvigor `ProcessLibs` collects `[...allHarLibs, ...outputLibs, ...cangjieLibs,
...localLibs]` and hard-links every entry into the packaging output, so the
entry HAP staged `libs/x86_64/` as well. The release checker correctly failed
with `HAP ABI set is ['arm64-v8a', 'x86_64'], expected only arm64-v8a` after the
HAP itself built (55.4 MB, arm64 `libflutter.so` and `libapp.so` both present).

`externalNativeOptions.abiFilters` was rejected as the fix: it selects the ABIs
that CMake/Ninja compile locally and never filters prebuilt HAR libraries.

Applied, release-scoped only:

```json5
"buildOptionSet": [
  {
    "name": "release",
    "nativeLib": {
      "filter": {
        "excludes": ["**/x86_64/**"]
      }
    }
  }
]
```

Selection chain confirmed in the shipped DevEco plugin:
`BuildModeConst.RELEASE === "release"`; `getBuildOptNameFromMapping` falls back
to that constant when no `buildModeBinder` maps the target; the module-level
`buildOptionSet` entry with that name is merged into the target build option;
`ProcessLibs.init` reads `s.getNativeLibOption().filter` into `filterRule`; and
`processLibs` drops any library where `minimatch(relativePath, pattern)` hits,
logging `The filter condition excludes matched ...`. The workflow really builds
release: `flutter build hap --release --target-platform ohos-arm64
--no-codesign` (`app-installers.yml:1878-1880`), so `--release` yields
`buildMode=release` and the entry applies. Debug has no `buildOptionSet` entry,
so the simulator keeps x86_64.

The checker was not weakened and the pinned pub cache and plugin were not
mutated.

## OHOS payload tool path fix

`.github/workflows/app-installers.yml`, step `Verify qfli_git native payload and
provenance`.

Run `44807880481` proved the ABI filter works: the HAP inspector printed
`hap_abis=arm64-v8a` and the HAP built normally. The job then failed before the
payload check opened the archive:

```
check_git_payload: .../command-line-tools/sdk/native/llvm/bin/llvm-nm
cannot read the packed library: [Errno 2] No such file or directory
```

`HOS_SDK_HOME` is the command-line-tools SDK root; the LLVM toolchain sits under
the NDK root, which `setup-ohos/setup.sh:88` exports as
`OHOS_NDK_HOME=$HOS_SDK_HOME/default/openharmony`. The step now resolves the
tool once and guards it:

```bash
llvm_nm="$OHOS_NDK_HOME/native/llvm/bin/llvm-nm"
if [ ! -x "$llvm_nm" ]; then
  echo "::error::llvm-nm is missing or not executable: $llvm_nm"
  exit 1
fi
```

and passes `--nm "$llvm_nm"`. A future path drift now names the exact missing
file instead of surfacing as a subprocess errno inside the checker. The Android
step already used its own `$toolchain/llvm-nm` and was untouched. The HAP
inspector, `--require-release-ready`, `--platform ohos`, `--abi arm64-v8a`,
`--contract`, `--cacert-sha256`, `--lock` and `--plugin-root` are unchanged, as
are the release filter, the pinned pub cache and the checker.

## Verification boundaries

Verified, static only:

- Python syntax via `py_compile` on every edited or added helper and test file.
- AST audit of both app test suites: 40 tests, every commit literal exactly 40
  hex characters.
- `ast` structure and `parse_lock_subset` behaviour against a real lock shape.
- Workflow and composite-action YAML parse; all seven embedded `PY` heredocs
  compile.
- Plugin contract cross-checked against `native/include/qfli_git.h` and
  `lib/src/bindings.dart`: API 2, 28 exports, no drift either direction.
- `ohos/entry/build-profile.json5` parsed as JSON5 and every key validated
  against `ohos-module-build-profile-schema.json`; glob checked against
  `x86_64/...` (excluded) and `arm64-v8a/...` (kept).
- OHOS payload step asserted by parsing the workflow: NDK-root `llvm-nm` path,
  `-x` guard, `--nm "$llvm_nm"`, no remaining `HOS_SDK_HOME/native/...`, and all
  six checker arguments plus the release-ready gate intact.
- `git diff --check` clean on every edit.

Not verified, by design:

- No Dart, Flutter, native, hvigor or Gradle execution anywhere.
- No simulator, emulator, VM, container or device.
- Nothing about runtime behaviour of the new native symbols beyond the header
  and binding agreement.
- Payload library bytes are deliberately not compared to the native lock:
  Android strips shared objects and iOS codesigns framework binaries, so the
  packaged bytes differ legitimately. Only format, ABI, exported symbols, the
  contract digest and the CA digest are gated.
- Whether the final cloud run is green. Run `44807880481` failed on the
  `llvm-nm` path after the ABI filter was proven correct; the corrected run had
  not started when this report was written.

## Ownership boundary at handoff

App product files are frozen: `.github/workflows/app-installers.yml`,
`.github/actions/app-setup/action.yml`, `tool/ci/plugin_provenance.py`,
`tool/ci/check_git_payload.py`, `tool/ci/stage_artifact.sh`, both app test
suites, and `ohos/entry/build-profile.json5`. Root owns the core `qfli_git` pin
(`75bd342`), `CORE_REF`, and all commits, pushes and tags. I made no commit,
staging, push or tag in any checkout, and ran no local test or build.

## Carried risks

1. `nativeLib.filter.excludes` matches on the library's relative path. If a
   future plugin reverts to a single-ABI HAR this pattern becomes inert rather
   than harmful, but the checker is what proves the ABI set.
2. The app-side payload check trusts `QFLI_PLUGIN_ROOT` as resolved by
   `plugin_provenance.py`; a path dependency would still be refused there by the
   `source != git` check, not by the payload check.
3. `stage_artifact.sh` now fails a release stage on any missing plugin fact. A
   job that forgets to run `plugin_provenance.py --write-env` fails loudly
   instead of writing `unknown` into `BUILD_INFO.txt`.
