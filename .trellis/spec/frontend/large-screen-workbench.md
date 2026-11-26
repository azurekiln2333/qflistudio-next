# Phone and large-screen workbench contracts

## 1. Scope / Trigger

Apply when changing app entry routing, retained editors, desktop/tablet chrome,
GitHub entry points, device classification, or Windows directory drops.
Implementation lives in sibling Core/App worktrees. Device acceptance remains
separate from cloud compilation and widget tests.

## 2. Signatures

- `QfliApp(formFactor: AppFormFactor?, githubController: GitHubAuthController?)`
  owns its default GitHub controller; injected controllers remain caller-owned.
- `resolveAppFormFactor(operatingSystem, displaySize, channel?)` resolves once
  at app entry. Desktop systems always return desktop. Native mobile reports
  phone/tablet. Fallback uses full display logical short side >= 600.
- `RetainedEditorController.activeSessionKey` and `resumeSession(key)` restore
  the exact session, including a saved workspace of the same primary project.
- `LargeScreenController.registerFiles(owner, WidgetBuilder)` exposes the real
  editor's file explorer. It owns presentation only, never a second editor.
- `HomeTab(embedded: false, showAgentsScope: true, onOpenProfile: null)` preserves
  phone defaults. The workbench uses embedded=true and showAgentsScope=false.
- `GitHubScope(controller, child)` shares authentication with Profile and Home.
- `DesktopFolderDrop(store, onOpen, onError, channel?).start()/dispose()` connects
  native intake to existing project registration and retained editor opening.

## 3. Contracts

- Phone retains Home-to-editor navigation. Desktop/tablet use the workbench as
  MaterialApp.home, with the retained editor host inside its center. Root
  dialogs therefore cover the whole workbench. Phone keeps its existing host.
- Window width only changes sidebar presentation. Narrow tablet/desktop windows
  remain workbenches. The 80dp NavigationRail and one sidebar slot never become a phone
  project-list route. WorkbenchTheme is scoped below the app's common theme.
- Explorer (Projects | Files pages) and Agents switch one retained sidebar. Each file explorer is
  created on first visit and keyed by its editor owner. Hidden bodies exclude
  input, focus and semantics and disable tickers.
- Utility pages hide, rather than close, the active retained session. Profile
  is reached from the bottom avatar; returning restores its exact session key.
- GitHub is a ProjectScope in the existing Home TabController/TabBarView. Known
  expired connections keep a reconnect entry. Explicit disconnect hides the
  tab without deleting its saved position or local projects.
- GitHub connection controls live in Profile. The inline list searches,
  refreshes, paginates, clones and opens local mappings in place. Hidden Profile
  cancels only the device authorization flow it owns.
- `github_project_links.json` stores version=1 and links from `github.com:<id>`
  to local project IDs. It never stores tokens, URLs containing credentials or
  paths. Registry relocation therefore does not invalidate project identity.
- Native `qflistudio/form_factor`: `getFormFactor` returns phone/tablet. Unknown
  replies and missing bridges use the full-display fallback. Android maximum
  window metrics are a classification approximation; foldables need devices.
- Native `qflistudio/folder_drop`: Dart `takePending` returns queued batches and
  arms live delivery. Native `incoming` carries `{id: String, paths: List<String>}`.
  Native `rejected` carries `{message: String}`. IDs are unique per process.
  Registration uses the actual Flutter HWND; successful OleInitialize calls,
  including S_FALSE, must be balanced. Revoke before destroying the window.
- Intake registers original directories without copying/moving/deleting them.
  Same-batch duplicate paths open once; a later drop reopens the existing
  project. Registration alone does not open an editor.

## 4. Validation & Error Matrix

| Input/state | Required result |
| --- | --- |
| Desktop window resized below breakpoint | Same editor/rail; overlay sidebar |
| Project and saved workspace share primary project | Resume exact session key |
| Missing/invalid form-factor reply | Full display fallback; startup proceeds |
| Invalid/expired stored GitHub token | Reconnect entry; no clone credential |
| Explicit GitHub disconnect | Hide tab; preserve order and local checkout |
| Mapping write fails after clone | Keep clone; never delete successful files |
| Repeated native batch ID | Ignore replay |
| Repeated path in a later batch | Reuse project and reopen retained session |
| One directory cannot register | Report error; preserve source/current editor |
| Service disposed during registration | No subsequent UI callback |

## 5. Good / Base / Bad Cases

Base: phone opens a project through Home using existing navigation.
Good: tablet opens A, edits unsaved text, opens B, returns to A, opens Profile,
then resumes the same controller, selection and file tree after window resize.
Bad: selecting a rail icon pushes another workbench, constructs a second
editor, classifies a narrow iPad as a phone, or deletes a failed drop source.

## 6. Required cloud checks

Keep existing phone assertions; inject AppFormFactor.phone where a test
specifically exercises phone navigation on a desktop CI host. Cover both
desktop/tablet workbench identity, dirty buffers, selection, sidebar retention,
utility return and close cleanup in retained_editor_test.dart. Cover native
channel fallback, delayed startup drops, repeated directory opens, malformed
batches and disposal. Cover GitHub tab insertion/removal/order, inline list,
Profile authorization lifecycle and credential-free project link persistence.
Run native platform builds for Windows/iOS/Android/OHOS. Do not describe these
as Explorer drag or tablet touch acceptance; those still require real devices.

Await project identity and completion of the editor transition in widget
fixtures. During the fade both editors are onstage. After a project-list tap,
allow real filesystem I/O through `tester.runAsync`; fixed frame pumping does
not complete the directory-existence check. Assert retained editor and terminal
controller identity after returning to a project, Profile and resized windows.
Dispose semantics handles before the test callback returns; addTearDown runs
after the binding's outstanding-handle invariant.

## 7. Wrong vs Correct

Wrong: `MediaQuery.width < 600 ? HomePage() : Workbench()`.
Correct: resolve device family once; use width only to lay out its shell.

Wrong: deduplicate folder paths for the whole process, suppressing future opens.
Correct: deduplicate within each batch, reuse registry identity on later drops.

Wrong: instantiate GitHubAuthController independently in Profile and Home.
Correct: root owns one controller; views never dispose or cancel another view's
repository operation.

The center, compact scrim and sidebar Positioned children must each have a
stable key. Inserting an unkeyed Positioned scrim ahead of an unkeyed sidebar
reuses the wrong slot and disposes the file tree during resize. Keep the
existing desktop/tablet file-tree identity assertions across both breakpoints.

## 8. Workbench UI cleanup (task 11-25-workbench-ui-cleanup)

Supersedes earlier rules where they conflict.

#### 1. Scope / Trigger
Apply to desktop/tablet shell navigation, embedded editor chrome, project/session entry, MD3 density, retained center overlays, tool pages, UI zoom and screenshot fixtures. Phone navigation, presentation and form-factor resolution are unchanged. Replace obsolete references to a 52dp rail or independent Projects/Files activities.

#### 2. Signatures
- `WorkbenchActivity.values`: `explorer, agents, tools, tutorial, settings, profile`. Legacy static `projects/files` aliases do not create destinations and must not be used to select an Explorer page.
- `ExplorerPage { projects, files }`; `LargeScreenController.explorerPage`, `showProjects()`, `showFiles()`, `toggleSidebar()`.
- `showCenterOverlay(WidgetBuilder)` / `closeCenterOverlay()` retain the existing editor host behind a standalone conversation.
- `sidebarWidth`, `setSidebarWidth(double)`, `resetSidebarWidth()`; bounds 220–480dp, default/reset 300dp. Non-finite values are ignored.
- Owner-bound `bindProjectActions` / `unbindProjectActions` forward creation, folder, clone and recent-project commands to the existing retained Home owner. Unbind only the matching owner.
- `LargeScreenWorkbench(..., formFactor: AppFormFactor?)`, `LargeScreenScope(..., formFactor: AppFormFactor?)`, `LargeScreenScope.isDesktop(context)` propagate the resolved family for presentation. Native platform remains the default for bare module fixtures. Native harness capability/auto-registration decisions still use the actual platform, not injected visual density.
- `WorkbenchTheme.from(base, formFactor: ...)`, `WorkbenchProjectsPanel`, `WorkbenchProjectRow`, `WorkbenchFocusOutline` own workbench-only visuals.
- `shortcutLabel(...)` supplies platform labels. Native `MenuItemButton.shortcut` carries keyboard metadata.

#### 3. Contracts
- One visible entry per action. Menu items and keyboard shortcuts do not count as duplicates. One retained editor host remains authoritative.
- Project clicks must open/resume the exact retained session key, clear center overlays and call `showFiles()`, including same-project and promoted-workspace cases. Back to Projects changes presentation only. `showWorkspace()` alone is not a project-open transition.
- Editor `_toggleExplorer` must call `shell.showFiles()`, not the legacy Files alias. Popup/status notifications do not clear a conversation or change Explorer page.
- Both Explorer pages use a retained 200ms horizontal transition. Hidden bodies exclude focus/input/semantics and disable tickers. Key center/scrim/sidebar slots and owner-keyed file panels to preserve State during resizing.
- The default visible Explorer owns project actions/list. Show only an instructional center prompt beside it. Start/Recent welcome appears when Explorer is hidden or another activity owns the sidebar; do not duplicate project commands/list in both surfaces.
- Native 80dp NavigationRail has labeled 24dp destinations with an MD3 capsule indicator, Settings and avatar at the bottom. Short windows scroll without dropping controls.
- Desktop: compact/shrinkWrap; project header/search/row 40/36/32dp, editor title/status 40/24dp, menus 32dp. Tablet controls use 48dp targets. Explicit design exceptions remain 36dp tabs and 40dp tablet file rows; do not infer density from width.
- Sidebar drag target is 6dp desktop / 48dp touch. Agent drag target is 8dp desktop / 48dp touch. Both keep a 1dp scheme-role line and resize cursor. Agent preference is 320–720dp, reset 400dp, inclusive of handle; effective width yields 240dp to source. Start dragging from displayed, not hidden preferred, width. Collapse occupies zero width and retains content without input/semantics/tickers.
- Colors use ColorScheme roles. State overlays are hover 8%, pressed/focus 10%, plus a focus ring on custom controls. Avoid applying compact density twice to explicitly sized menu rows.
- Workbench editor omits phone AppBar, quick bar, default symbols, file/session switch and collapsed Agent rail. Symbols react live to `largeScreenSymbolBar`. Editing/Git/cloud/online-terminal/content/close actions and Agent New Session/Stop All stay reachable through More. Stop All enablement updates while the menu is open. Status diagnostics are read-only beside the single Problems action.
- Shell shortcuts: platform Ctrl/Cmd+B, Shift+E, Shift+A, comma. Project commands: Shift+N / O / Shift+G reuse existing Home services. Editor terminal/panel/Agent/tab/new-file/F5 commands use the PRD table; W/J/L remain terminal-owned during prompt focus. Remove child L only when an Agent action exists; save delegates to page persistence.
- Utility pages hide rather than destroy editor state. Settings is 240dp list-detail with only the selected category in detail <=720dp. Profile content <=720dp. Tutorial/example and ToolsBrowser grids use 280dp minimum cards and 16dp gaps. ToolsBrowser workbench layout does not write phone density/column preferences; phone controls/rendering remain intact.
- Tooltips wait 500ms. Floating notices are centered within the center region and <=480dp; place the shell messenger's root Scaffold inside that region. Preserve per-editor messengers.

#### 4. Validation / Error Matrix
| State | Expected |
| --- | --- |
| No project | Projects page only; no project-required popup |
| Open same/other project | Exact requested retained session, Files, overlay cleared |
| Promoted workspace / utility return | Exact saved key and buffer/tree/terminal identity |
| Incidental editor notification | Overlay and Explorer unchanged |
| Compact resize | Same file-panel State, keyed slots, no new editor |
| Non-finite divider width | Ignore; bounds/reset remain valid |
| Constrained Agent drag | Immediate movement from displayed separator |
| Editor hidden or medium Agent selected | Remove root selection overlay and detach its listeners |
| No Agent product | Source L keeps line selection; no reserved no-op chord |
| Tools density compact / saved two columns | Workbench auto-grid; phone preference unchanged |
| Injected tablet on desktop CI | Standard/padded touch chrome; native capabilities unchanged |

#### 5. Good / Base / Bad Cases
Base: phone opens projects through existing Home navigation. Good: edit A, open B, return to exact A/workspace key, show projectless chat, open B to dismiss it, resize and recover the same buffers/tree/terminal. Bad: separate Files rail entry, duplicate welcome list, unkeyed scrim, second editor, swallowed unavailable shortcut or preferred-width drag dead zone.

#### 6. Required Cloud Checks
Run new workbench, density, explorer, editor-cleanup, Agents-entry/view/visual, intake, settings/zoom, tools-grid and screenshot suites plus the full original suite. Migrate only removed large-screen UI assertions under design 11.2 with requirement comments. Preserve phone assertions; inject `AppFormFactor.phone` only when a phone fixture needs it. Cover overlay render/retention/detach in the actual shell and replacement shared hubs in an already-mounted editor. Compare 1440x900, 1024x768 desktop and 1180x820 tablet, light/dark. Phone pixel parity, native OS chords, touch targets, IME, scaled drag/selection still require device evidence.

#### 7. Wrong / Correct
Wrong: `shell.select(WorkbenchActivity.files)`; correct: `shell.showFiles()`.
Wrong: use native desktop detection for an injected tablet's visual density; correct: propagate resolved form factor through the existing scope while retaining native detection for capability decisions.
Wrong: assume Offstage hides a root ContextMenuController overlay; correct: explicitly close it when retained visibility/tickers/medium-pane visibility changes.
Wrong: overwrite persisted tools columns for wide windows; correct: use a scope-only layout branch without changing the store.

### Sessions

#### Routing contracts
`resolveSessionProject(..., workbench: true)` enables strict resolution. Local desktop roots reuse exact registered local projects or register the original existing directory with `ProjectStore.addExisting`; never copy/move or choose an unrelated root. Remote paths never match local roots. Preserve legacy phone resolver defaults. Missing/unusable/failed registration opens `WorkbenchSessionView(row, hub, onClose)` in the existing center overlay, never the project-required dialog.

#### Handle lifecycle
Standalone views serialize replacement opens with generations, expose reason/retry, detach only their matching active handle and never stop sessions or close a newer shared-hub handle. Overlay wrappers follow replacement shared hubs and dispose only owned fallback hubs. Normal workbench/Home callers reuse their owned shared hub. Filesystem widget entry work must complete in `tester.runAsync`.

#### Adaptive intake
Gate visuals on mounted LargeScreenScope, not viewport width. Attachment menu stays open for multi-select and returns paths only after confirm; Escape/outside/cancel returns null without consuming drafts or changing ownership. Focus a menu item for Escape. Assert localized native shortcut text, not a nonexistent accelerator-label wrapper. Phone keeps AttachmentPickerSheet. ShareIntakeHost may launch above the scope through navigatorKey.currentContext: discover the mounted scope in that navigator subtree without registering inherited dependencies on visited InheritedElements. Workbench intake uses a centered <=560dp dialog with the same typed choices/cancellation retention; phone keeps its sheet.

### Zoom

#### Signatures / persistence
`SettingsStore.largeScreenSymbolBar` / `setLargeScreenSymbolBar`: default false. `uiScale` / `setUiScale`: 0.5–2.0, rounded 0.1 steps, serialized persistence. `UiZoom(settings, enabled, mouseWheelEnabled, child)` is outermost in MaterialApp.builder and observes changes without rebuilding MaterialApp.

#### Geometry / input / validation
Divide MediaQuery size, padding, viewPadding and viewInsets by scale, lay out at reduced size, then transform from top-left. At 1.0 omit Transform but retain the same keyed navigator subtree. Narrow early FocusManager handling reserves only platform zoom chords so editors/terminal cannot swallow them; unregister on disposal. Register modified desktop wheel signals before descendant scrollables; plain wheel scrolls normally, tablet wheel does not zoom. Feedback lasts one second. Phone disables layer/shortcuts and ignores saved desktop zoom. Verify bounds/persistence, aliases, focused-child priority, scaled taps/drags/selections/insets/dialogs, navigator/focus identity across 100%, and listener/timer cleanup. Native OS/IME behavior still requires devices.

### Screenshots and verification

#### Screenshot contract
`test/screenshots/workbench_screenshots_test.dart` skips unless environment `QFLI_SCREENSHOTS=1`. Cloud job `screenshots` installs fonts-noto-cjk and runs only the opted-in harness with the pinned SDK/App revision. Actions, including upload-artifact, are SHA-pinned to existing repository-approved versions. Output: 36 `build/screenshots/<size>-<theme>-<scene>.png` files, six scenes for each of three viewports and two themes.

Use real bundled RobotoMono faces, SDK MaterialIcons and Noto CJK. Register actual UI glyph fonts rather than leaving Ahem. Isolate PathProvider and temporary project/settings/auth data; use real QfliApp/shell/editor controls with deterministic host fixtures, never native process discovery. At each scene assert the destination and required public control; missing navigation must fail instead of silently capturing the previous scene. Capture welcome with Explorer hidden to respect R5. Await filesystem readiness and image conversion/encoding in tester.runAsync; bounded frame pumping avoids permanent spinners. Keep host/editor ownership cleanup deterministic and do not recreate editors to navigate scenes.

#### Verification policy
No local flutter test/build/emulators/VMs/WSL for this task. Allowed local checks: dependency resolution, explicit changed-file formatting, full-package analysis and Git/static inspection. Cloud full suite and PNG/device review remain separate acceptance gates. Do not suppress warnings to reach clean analysis. Integration removed two baseline infos with braces/import-only edits; no runtime change was intended.
