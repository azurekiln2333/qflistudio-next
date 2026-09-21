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
