# Flutter Repository Boundaries

## 1. Scope / Trigger

Apply this contract when changing an app's package dependencies, creating a language App, or running cross-product validation. `qflistudio`, `qfli_studio_core`, and the 11 `qfli_*` Apps are sibling Git roots. The main App does not own the language App source tree.

## 2. Signatures

- `flutter pub get` runs separately in each repository and updates that repository's `pubspec.lock`.
- `dart run tool/new_language_app.dart <supported-id> [--force]` runs from `qflistudio` and creates `../qfli_<id>` as a Git repository when absent.
- `tool/sync_ohos.sh <app-name>` and `tool/build_hap.sh <app-name>` operate on `../<app-name>/ohos`.
- `dart run tool/verify_runtime_matrix.dart` and `dart run tool/verify_ohos_products.dart` inspect the sibling App manifests.

## 3. Contracts

- Every App declares `qfli_studio_core` at `../qfli_studio_core` and overrides `re_editor` at `../qfli_studio_core/vendor/re_editor`.
- `qfli_c` additionally declares `qfli_c_runtime` at `packages/qfli_c_runtime` within its own Git root.
- `qfli_studio_core` owns the patched `vendor/re_editor` and its own path override.
- No package declares `resolution: workspace`; there is no root Dart pub workspace.
- Before editing shared code, inspect local `pubspec_overrides.yaml` and
  `.dart_tool/package_config.json`. An integration build may resolve
  `qfli_studio_core` to a Git worktree rather than the sibling checkout. Edit
  the resolved checkout and preserve local overrides unless the task changes
  dependency wiring.

## 4. Validation & Error Matrix

| Condition | Expected result |
| --- | --- |
| Shared core sibling checkout missing | `flutter pub get` fails; restore `../qfli_studio_core`. |
| App plugin manifest missing before OHOS Sync | Run `flutter pub get` in that App, then retry Sync. |
| New App target already exists without `--force` | Generator skips it without overwriting files. |
| Python MicroPython gitlink absent after clone | Run `git submodule update --init` in `qfli_python`. |

## 5. Good / Base / Bad Cases

- Good: all sibling repos checked out; run `flutter pub get` in each and build one App independently.
- Base: use the shared core checkout with a local App but leave unrelated Apps absent.
- Bad: reference `apps/qfli_*` or `packages/qfli_studio_core` from the main App after the split.

## 6. Tests Required

- Run `flutter pub get --offline` in the main App, shared core, and every language App; assert all resolve to sibling paths.
- Run `flutter test --no-pub` in each language App; assert the App-specific wiring tests pass.
- Run `flutter analyze --no-pub lib/main.dart` in the main App and `tool/verify_ohos_products.dart`; assert the tool finds all 12 product IDs.

## 7. Wrong vs Correct

Wrong: `qfli_studio_core: {path: ../../packages/qfli_studio_core}` in a language App.

Correct: `qfli_studio_core: {path: ../qfli_studio_core}` and a matching sibling `re_editor` override.
## 8. CI Installer Layout

The installer workflow checks out the app as `qflistudio/` and the shared core as sibling `qfli_studio_core/`. This layout is required by both path dependencies in `pubspec.yaml`.

Windows, Linux, macOS, iOS and Android consume one upstream stable version resolved at the start of the run. OHOS uses the pinned OHOS Flutter fork and its own cache. Keep these SDKs separate.

External JavaScript actions use only SHA-pinned Node 24 actions:

- `actions/checkout@3d3c42e5aac5ba805825da76410c181273ba90b1`
- `actions/cache@55cc8345863c7cc4c66a329aec7e433d2d1c52a9`
- `actions/setup-node@949feb2413d6458794dcd2491c4babbbce0c15c1`
- `actions/upload-artifact@cf430e030ddbb5b0abf93d22962f4752f3646cd9`

Local composite actions may wrap these actions. Do not add a Flutter action that brings a Node 20 cache action transitively.

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

## 9. Preview release verification

`app-installers.yml` pins `CORE_REF` and `JAVA_REF` to full GitHub commit IDs.
The complete app/core suites use the OHOS Flutter fork, with
`ohos-platform-tooling: "false"` for SDK-less analysis and tests. The HAP job
enables OHOS generation after installing platform tools. Keep infos visible
across the different SDK exports; warnings and errors remain fatal.

Only a `v5.0.5-remote.*` tag publishes this preview. Publication waits for the
app/core suites, Node suites on Windows/Linux, the Java receiver host tests,
the Windows assistant build and every main app installer target. It checks
each artifact's version, source revisions, SDK and checksums before publishing.
Never substitute old artifacts for a failed job in the tagged run.

The portable Windows assistant carries Node, MSVC DLLs and locked production
agent dependencies. `Start-QFLI-Remote.cmd` sets `CLOUDTERMINAL_NODE` and
`CLOUDTERMINAL_AGENT_DIR`. Packaging runs both the scripted protocol E2E and
the actual sidecar first-run pairing smoke with isolated configuration.
Missing optional Herdr yields an unavailable status; it must not crash startup.

Android preview APKs use a debug certificate. Windows is unsigned, macOS uses
ad-hoc signing, and iOS/OHOS require signing before installation. Cloud host
tests do not establish device or live-provider acceptance. Do not include
developer identities or local signing material in any preview artifact.
