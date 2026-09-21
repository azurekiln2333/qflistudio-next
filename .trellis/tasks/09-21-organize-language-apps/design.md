# Design

## Boundaries

- `StudioProfile` owns product identity, supported project templates, offline/online capability, and whether the homepage's internal content tabs are shown. It no longer controls the editor file-tab visibility.
- `HomePage` owns the top-level page destinations. It composes `HomeTab`, `FunctionsTab`, `TutorialsTab`/`LocalTutorialsTab`, `ExampleCodeTab`, `DiscussionTab`, and `ProfileTab` without nesting tutorial navigation inside functions.
- `SettingsStore` owns persistent UI switches and JSON-backed user content settings. `showEditorTabs` is a user setting with a default of true; profile-specific homepage tab visibility remains separate.
- `TutorialService` parses versioned tutorial JSON into `Tutorial`, `TutorialLesson`, and `ExampleCode` models. `type` is preserved at document and item level; UI never derives it from a file suffix.
- `ExampleCodeStore` owns the editable example catalog: bundled defaults, user additions/changes, reset-to-default, and JSON serialization. It is injected or constructed from `SettingsStore` storage so tests can use a temporary file.
- `ProjectArchiveService` owns JSON export/import. It walks a project directory, records relative paths, text/binary distinction, type metadata, and Base64 bytes for binary files. It validates paths on restore and writes through a temporary directory before replacing/adding the project.
- `PickerService` is the Dart boundary for directory/file/photo selection and JSON save. It uses `file_selector` on desktop and `qflistudio/platform` on HarmonyOS. Native code returns opaque URI plus bytes/operation result, not a fake local path.
- `FileExplorer` owns directory actions and calls a resource import coordinator for long-press import. `EditorController` gets a refresh/reopen hook after imports and keeps open-file tabs consistent.
- `TerminalManager`/`TerminalSession` owns multiple local sessions and process lifetimes. `TerminalPane` renders one selected session and reports a drag-resized extent to its parent; `LocalTerminalPage` and editor terminal use the same manager contract.
- `StudioProductCatalog` is the single product registry. It maps the twelve products to stable keys, display names, package identifiers, supported project types, tutorial types, and runtime capabilities. App entrypoints consume the registry instead of duplicating names.

## Product and package migration

The installable product set is exactly:

```text
qflistudio -> QFLIStudio+ 多语言编辑器（暂定）
script     -> QFLIScript (Lua, JavaScript, TypeScript, shell workflows)
rustcore   -> QFLIRustCore
goshift    -> QFLIGoShift
jvmx       -> QFLIJVMX
webforge   -> QFLIWebForge
pyflow     -> QFLIPyFlow
forge      -> QFLIForge (C + C++)
dartwing   -> QFLIDartWing
sqlab      -> QFLISQLab
json       -> QFLIJson
note       -> QFLINote
```

`qfli_c` becomes the source App for `QFLIForge`; its profile contains both C and C++ templates and dispatches by file type. `qfli_cpp` is removed as an installable workspace member only after its useful tests/assets are migrated. Shared runtime code is moved to `packages` when it is reusable; no two App manifests may claim the same product identity.

For every existing and new App, platform identifiers use `com.azurekiln.qfli.<key>`. The migration updates Android namespace/applicationId, Kotlin source package paths, HarmonyOS `bundleName` and labels, iOS/macOS bundle identifiers, and Flutter display labels. Signing files are treated as user-owned secrets/configuration: a package change is accepted only when its certificate/profile metadata matches the new bundle name; otherwise the build remains explicitly unsigned or is reported as requiring a newly generated profile.

## Runtime capability contract

Each profile declares `runtimeKind`, `runtimeStatus`, and supported file extensions. A language is marked available only when a testable runner is wired in the target build. The initial runtime matrix is:

- C: existing bundled Dart interpreter.
- C++: merged Forge runner; desktop toolchain where available, bundled subset runtime only after parser/interpreter tests pass.
- Python: existing MicroPython native bridge plus desktop fallback.
- Web: existing local static server and browser preview.
- Markdown: editor and rendered preview, no run action.
- JSON: editor, validation, formatting, and structured preview, no program run action.
- SQL: bundled SQLite database/query workflow with local project database files.
- Script: Lua runtime first, then JavaScript/TypeScript/shell runners with per-format availability reported honestly.
- Rust, Go, Java, Dart: desktop compiler/toolchain paths plus a bundled mobile runtime only when a real implementation and tests exist; no fake successful output.

## Navigation model

```text
HomePage
  HomeTab                  (project list; child apps hide its internal scope tabs)
  FunctionsTab             (terminal, project IO, temporary editor actions)
  TutorialsTab             (root: community tutorials; child app: local JSON tutorials)
  ExampleCodeTab           (child app: typed local examples and detail routes)
  DiscussionTab            (root only)
  ProfileTab               (root only)
```

The bottom navigation bar remains the page switcher. In child apps, labels may use icon-only/hidden label behavior while page destinations stay reachable. Internal `HomeTab` scope tabs and language chips are controlled by the profile and hidden for single-language apps.

## Content data flow

```text
assets/tutorials/<language>.json
  -> TutorialService.parse/load
  -> Tutorial { language, type, chapters, examples }
  -> LocalTutorialsTab / ExampleCodeTab
  -> TutorialDetailPage / ExampleDetailPage
```

`ExampleCode` is a first-class model:

```text
{ id, language, type, title, summary, code, output, sourceLessonId }
```

For migration, `TutorialService` creates examples from lesson code when an old JSON document has no `examples` list. Updated assets include explicit `type` and `examples` entries. The service rejects mismatched non-empty document/item types in tests rather than silently relabeling them.

## Project and example workflow

1. New project selection uses `availableTemplates()`. The root profile exposes both C and C++; single-language profiles filter to one template.
2. Example detail either calls `ProjectStore.createProjectFromExample` with the selected template/type or creates a temporary project under an app-managed `temporary/examples/<id>` directory.
3. The existing `EditorPage` opens the generated entry file. It continues to provide edit/save/run/format; a wrapper action supplies reset-default and import/export for temporary examples.
4. User changes are stored by `ExampleCodeStore` as JSON. Reset replaces only the selected user example with its bundled default.

## JSON project archive

The exported document contains `schemaVersion`, project metadata, `language`, `type`, and `files[]`. Each file has a normalized relative path, `encoding` for text or `bytesBase64` for binary data. Import validates no absolute paths, no `..` escape, and no duplicate paths; it writes to a temporary sibling and then registers the restored project. Existing target files require an explicit replace/skip decision.

## HarmonyOS integration

Each generated App's `EntryAbility.ets` registers the same platform methods on `qflistudio/platform`:

- `pickDocument`: `DocumentViewPicker.select` with file/folder mode.
- `saveDocument`: `DocumentViewPicker.save`, returning a writable URI.
- `pickPhotos`: `PhotoViewPicker.select`, returning media URIs.
- `readUri` / `writeUri`: native file-URI access used by the Dart archive/resource layer.

The native layer is duplicated only where Flutter's generated HarmonyOS host requires it; method names and payload contracts are shared in Dart tests and kept identical across root and child App hosts. Desktop and unsupported platforms use `file_selector` or a clear disabled state. Directory selection is attempted only when the SDK/device capability allows it; file archive fallback remains the portable path.

## Terminal model

Each session has an id, working directory, command history, output lines, running process, and collapsed state. A `TerminalManager` limits resource cleanup to the session being closed. The UI displays a conventional prompt from the current directory (`C:\Users\lichengyu>` on Windows), stores command lines without a prefixed explanatory sentence, and uses a `GestureDetector`/`VerticalDivider` drag handle with min/max height constraints.

## Layout and localization

- Shared tab styles define fixed height, centered label alignment, and stable horizontal padding; symbol buttons use a fixed-width item and explicit gap.
- Long labels use `Expanded`, `Flexible`, ellipsis, or scrolling containers. No global error suppression is added.
- All user-facing strings introduced by this task are keys in `StudioLocalizations` for zh-CN, zh-TW, and en. Data/code/path values are not localized.

## Compatibility and rollback

- Existing tutorial documents without `type`/`examples` continue through parser defaults and derived examples.
- Existing `settings.json` loads with default `showEditorTabs=true` and an empty user example catalog.
- Existing projects without `.qfli/project.json` keep extension-derived language detection; imports add explicit metadata.
- If native Picker compilation fails on an SDK variant, the Dart PickerService remains usable through file-level desktop/fallback flows while the native host change is isolated and can be reverted without reverting the content/editor work.
