# Implementation Plan

## Phase 1: task activation and baseline

1. Confirm the current task record and preserve any pre-existing worktree changes.
2. Add the research artifact and activate the existing task only after this planning summary is approved.
3. Run baseline `flutter analyze --no-pub` and the existing shared tests to separate inherited failures from new failures.

## Phase 2: navigation, tab boundaries, and localization

1. Refactor `HomePage` and `quick_tools_page.dart` into explicit functions/tutorial/example destinations; remove the visible “快捷功能”/“Quick tools” page wording.
2. Add profile flags for homepage internal tabs and hidden child-app navigation labels; keep root navigation behavior and cloud/community pages intact.
3. Restore editor file tabs as the default, wire `SettingsStore.showEditorTabs`, and add the settings switch.
4. Centralize new labels in `StudioLocalizations` and fix TabBar/NavigationBar/SymbolsBar alignment and spacing.
5. Add widget tests for root vs child navigation composition and tab visibility.

## Phase 2A: product catalog and App consolidation

1. Replace scattered product-name constants with the twelve-entry catalog and update all profiles to use the final names and keys.
2. Merge C and C++ into the `QFLIForge` profile/App: keep both templates, migrate C++ tests/assets/runner code, and update project filtering and entry detection.
3. Remove the duplicate C++ installable App from the pub workspace only after migration tests pass; preserve its useful source history in the Forge change commit.
4. Migrate Android, HarmonyOS, iOS, and macOS identifiers to `com.azurekiln.qfli.<key>` and update labels without overwriting user-owned signing materials. Add a manifest consistency check.
5. Create the missing Rust, Go, SQL, JSON, and Markdown App shells and register them in the workspace. Keep product display names and package keys in the shared catalog.

## Phase 3: typed tutorials, example details, and JSON-backed editing

1. Extend tutorial models/parser/assets with `type`, explicit example lists, compatibility fallback, and tests for all languages.
2. Split example cards into list/detail pages; add copy, import-to-project, temporary-editor, reset-default, and run actions.
3. Implement the JSON-backed editable `ExampleCodeStore` and settings import/export for the example catalog.
4. Add focused tests for type preservation, custom example persistence, reset behavior, and detail action routing.

## Phase 4: project JSON import/export and resource import

1. Implement `ProjectArchiveService` with path validation, text encoding and binary Base64 entries, schema versioning, and atomic restore.
2. Add project import/export commands to the Functions page and Settings page; keep desktop path selection through `file_selector`.
3. Add long-press directory resource import actions for file manager and photo sources; refresh file tree and open-file state after copy; test conflict handling.

## Phase 5: HarmonyOS picker bridge

1. Implement the Dart `PickerService` contract and mockable channel tests.
2. Add `DocumentViewPicker`/`PhotoViewPicker` handlers to the root and each child App `EntryAbility.ets`, plus URI read/write payload handling.
3. Verify API-level compatibility against the checked local SDK declarations and keep file-level fallback for devices without folder capability.
4. Run HarmonyOS host/type checks where available; do not claim native picker success without a real device/emulator interaction check.

## Phase 6: terminal and editor behavior

1. Extract terminal state into multiple sessions with create/switch/close operations and per-session process cleanup.
2. Change prompt rendering to conventional path prompt and remove explanatory working-directory intro text.
3. Add a constrained drag handle for terminal height in editor and standalone terminal page; test min/max clamping and session switching.
4. Make format apply directly without success confirmation; retain only actionable error reporting.
5. Audit narrow-screen and long-content layouts, including symbols bar, tabs, project type selector, details pages, and terminal output.

## Phase 6A: runtime completion

1. Define a runtime capability interface so editor actions distinguish compile/run, preview, query, and non-runnable content.
2. Implement Forge C/C++ routing with real C execution preserved and C++ desktop execution plus a tested mobile subset/runtime milestone; do not mark C++ available before tests prove it.
3. Implement SQL using a bundled SQLite path, including schema/query execution and result rendering.
4. Implement JSON validation/format/preview and Markdown edit/preview workflows.
5. Extend Script with Lua and additional script file types, each with a separate runner status and truthful output.
6. Add Rust, Go, Java, and Dart desktop toolchain runners and document the mobile runtime status until bundled runtimes are verified.

## Phase 7: verification and documentation

- Format all changed Dart files.
- Run `flutter analyze --no-pub`.
- Run shared core tests and all App tests: `qfli_c`, `qfli_cpp`, `qfli_python`, `qfli_java`, `qfli_lua`, `qfli_web`, and `qfli_dart`.
- Run all twelve product profile tests, including Forge's C/C++ templates and the new Rust/Go/SQL/JSON/Note profiles.
- Run JSON asset/schema checks and project archive round-trip tests.
- Run `git diff --check` and inspect `git status --short --untracked-files=all`.
- Validate HarmonyOS sources with the available DevEco/Hvigor toolchain; document any device-only Picker limitation.

## Phase 8: twelve-product HarmonyOS runtime and content release

This phase supersedes the earlier placeholder-runtime milestone. It is a
release blocker: no product is called runnable until its target fixture passes
on a HarmonyOS device or emulator.

### 8.1 Contracts and release gates

- [ ] Add `ContentRepository`, aggregate `tutorials.json` and `examples.json`
  schemas, API adapter boundary, locale/type filtering, and schema validation.
- [ ] Add a content linter requiring 100 substantive tutorials and 100
  substantive examples for each language type: C, C++, Lua, JavaScript,
  TypeScript, Shell, Rust, Go, Java, HTML, CSS, Python, Dart, SQL, JSON and
  Markdown.
- [ ] Add `NativeRuntime` and `ProcessSupervisor` contracts with capability
  status, version, diagnostics, cancellation and disposal semantics.
- [ ] Add release checks that reject placeholder strings such as “开发中” or
  “未就绪” from a product marked `available`.

### 8.2 Parallel subagent tracks

Each track runs in its own worktree through a Trellis channel. Workers must
commit focused changes and include tests; the main agent reviews and merges
only after the track's device/host evidence is attached.

1. **content-catalog**: aggregate JSON, repository adapters, validator,
   migration from the seven existing asset files, and substantive catalogs.
2. **forge-clang**: pin Clang/LLVM, build the shared native bridge, implement
   C/C++ language modes, diagnostics, target runtime, and C/C++ device fixtures.
3. **sql-native**: compile SQLite amalgamation for HarmonyOS, bridge open/query/
   transaction/close, project database lifecycle, and SQL tests.
4. **script-python**: normalize Lua/QuickJS/TypeScript/Shell and MicroPython
   native bridges, probe contracts, limits and script fixtures.
5. **systems-runtimes**: implement or integrate verified Rust, Go, Java and
   Dart runtimes through the common native/Wasm boundary; no placeholder output.
6. **process-safety**: implement process-tree supervision, cancellation,
   editor/terminal ownership, watchdogs, and CPU/process leak regression tests.
7. **ohos-release**: mirror channels/ABI registration across all twelve Apps,
   verify package/signing manifests, build HAPs, and run release smoke tests.

### 8.3 Forge Clang/LLVM sequence

- [ ] Confirm the local DevEco LLVM/Clang version and target triples from the
  checked SDK; do not assume desktop clang is usable in a HAP.
- [ ] Add the pinned upstream source/license manifest and a reproducible native
  build script with size and ABI reports.
- [ ] Build one shared `qfli_clang_bridge` for C and C++ and expose compile,
  diagnostics, artifact execution and cancellation through one C API.
- [ ] Prove C and C++ separately with headers, multiple translation units,
  standard library, stdin, stdout/stderr, timeout and memory-limit fixtures.
- [ ] Only after device proof, replace the C++ placeholder runner and route both
  types through `ForgeProgramRunner`.

### 8.4 SQL sequence

- [ ] Remove the `Process.start('sqlite3')` dependency from
  `SqlQueryService`.
- [ ] Add native SQLite build and a project-local `.qfli/data.sqlite` API.
- [ ] Test DDL, parameterized queries, transactions, errors, cancellation and
  reopen persistence on HarmonyOS.
- [ ] Add optional MySQL connection configuration as a remote feature; never
  fail local SQL usage because no MySQL service is installed.

### 8.5 Dart residual-process gate

- [ ] Replace returned unowned `Process` values with managed run handles.
- [ ] Audit `TerminalPane`, `RunnerService`, Lua runner, local terminal and
  Web-server opener for missing `await process.exitCode`, stream cancellation,
  disposal and process-tree termination.
- [ ] Add an infinite-loop fixture and assert after cancel/page close/app
  shutdown that no Dart child remains. On Windows inspect descendants, not only
  the direct PID.
- [ ] Run the leak suite repeatedly under CPU monitoring before any HAP build.

### 8.6 Verification commands

```text
flutter analyze --no-pub
flutter test --concurrency=1 packages/qfli_studio_core/test
flutter test --concurrency=1 packages/qfli_c_runtime/test
flutter test --concurrency=1 apps/*/test
dart run tool/validate_content.dart
dart run tool/verify_runtime_matrix.dart
git diff --check
hvigorw assembleHap --analyze=normal
```

The full test command is run per App when the aggregate command exceeds the
machine's memory limit. A test pass without a real HarmonyOS fixture is not
accepted as native runtime evidence.

## Risk checkpoints

- Before changing navigation, capture the existing root/community route behavior in widget tests.
- Before changing `SettingsStore`, test loading old settings files without new keys.
- Before writing imported files, test traversal, duplicates, invalid Base64, and conflict paths.
- Before native host edits, compile one host and mirror the exact method contract to the remaining hosts.
- Before final verification, use a small viewport or screenshot test to catch overflow instead of globally suppressing Flutter errors.

## Rollback points

- Navigation/profile changes can be reverted independently from content models.
- Picker host changes are isolated to `EntryAbility.ets` and the Dart platform service; desktop functionality remains available if native compilation is blocked.
- Project archive writes go through a temporary directory, so a failed import does not partially register a project.
