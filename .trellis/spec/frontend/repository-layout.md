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
