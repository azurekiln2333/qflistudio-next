# Editor Fonts And Pager Updates

- Home pager selection uses a `ValueNotifier` to update navigation and `TickerMode`; changing the selected page must not rebuild the whole shell.
- Create pager children lazily, reuse their widget instances, and wrap visited pages in `RetainedPage`. Disable implicit neighbor preloading to avoid starting unrelated page work.
- Adjacent navigation keeps its short slide animation. Distant navigation jumps to the destination without constructing all intermediate pages.
- Pages must observe the state they display directly. Home cloud actions and tutorial publishing controls observe login transitions; profile changes alone must not rebuild project lists.
- The app root observes theme and startup readiness. Editor settings changes must not rebuild `MaterialApp`.
- Cache editor file views by `OpenFile` identity, retain visited views, and pause inactive tickers. Invalidate cached views on theme/dependency or editor setting changes and remove closed files from the cache.
- `SettingsStore` persists font choice, size, line height, bold, and italic. Font settings apply to both code and line numbers; pinch zoom persists when the gesture ends.
- Roboto Mono defaults to bold, including font reset. The `editorBoldDefaultVersion` marker migrates existing defaults once while preserving subsequent user choices.
- Auto-save receives every content change, including edits while a file is already dirty. Selection-only changes do not save. Capture immutable content and its revision immediately, and serialize local saves and cloud pushes per file without a debounce timer. A completed older save must not clear a newer dirty revision. Preserve pending local writes when the editor closes.
- Bundle Roboto Mono regular, bold, italic, and bold italic under the shared package's fonts manifest. Refer to its package-qualified family through `EditorFonts.bundledFamily`; all code, terminal, and preview defaults share this family across platforms. Keep normal UI text on the application theme fonts.
- Migrate the previous `systemMono` default to Roboto Mono on settings load. The optional system font choice uses `platformMono`, so explicit choices remain persistent. Resetting editor fonts selects Roboto Mono.
- Preserve and bundle the upstream OFL license, registering it once with `LicenseRegistry`. Chinese and unsupported glyphs use system fallback. Native `Typeface` objects cannot be passed to Flutter.
- The vendored `CodeEditorStyle` forwards weight and slant into the text and paragraph strut styles.
- Cache file modification time in `OpenFile`, updating it during asynchronous file reads/saves. Do not call `statSync` from a cursor or selection rebuild.
- Use static analysis for routine checks; do not add or run tests unless requested. Device frame-time improvements require device profiling before claiming measured gains.

## Embedded Agent Navigation

- `EditorPage` owns pane navigation in its existing AppBar. On narrow and medium
  layouts, `AgentEntryButton` opens Agent or returns to the editor. On wide
  layouts it expands or collapses the Agent dock. `AgentPaneSwitcher` retains
  the two bodies with Offstage and must not add a separate navigation row.
- Below `Breakpoints.sidebarPersistent`, the Agent action uses the former Undo
  toolbar slot. Undo remains available in the overflow menu. This preserves
  project-title width. The code-selection toolbar only appears while the editor
  pane is visible.
- `SidebarSectionSwitch` lives inside the original `FileExplorer` card header.
  `FileExplorer.sections` replaces the body and contextual actions for Sessions.
  Preserve `WorkbenchState` selection, tree state and 44-pixel touch targets in
  both the persistent sidebar and drawer. Background-session badges stay on
  the Agent toolbar action and exclude the foreground session.
- Existing checks: `editor_top_bar_title_test.dart` verifies toolbar placement,
  compact widths, text scaling, and badges. `editor_agent_embed_test.dart`
  verifies navigation, pane retention, lazy activation, and offline gating.
