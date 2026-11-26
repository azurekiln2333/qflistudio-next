# Pi D implementation handoff

Task: `11-21-github-repo-clone`.
Core root: `D:/MyNewProjects/_wt/studio-git-integration/qfli_studio_core`.
App root: `D:/MyNewProjects/_wt/studio-git-integration/qflistudio`.

Status: owned source frozen after the cloud-open lifecycle and Windows native-share review fixes. Local validation is static only. Root owns all index/commit operations; D does not stage or commit. No tests, builds, native receivers, services, devices, CI, staging, commits or pushes ran. Previous remote-account-binding worktrees remain untouched.

## Implemented behavior

### R4 selection ZIP and native share

- FileExplorer exposes an optional editor-injected `onShareEntry(Project owner, String path)` callback.
- The shared long-press/secondary-click menu offers ZIP sharing for a file, folder or root.
- Existing `_ownerOf(node.path)` chooses the longest owning workspace root. Tokens are not stored in tree state.
- Editor blocks duplicate share operations, captures identity, invokes the service, and offers Save ZIP when native sharing is unavailable. Post-await context uses explicit mounted guards. Cloud fallback also fences identity changes.
- `ProjectZipService.exportSelectionToFile` packages only the selection, preserving binary bytes, relative subtree paths and empty local folders. It does not add sibling files or synthetic project metadata.
- Filesystem traversal and compression run in an isolate. Paths must remain inside the selected project. Links, link ancestors, unsupported file types, unsafe ZIP names, existing output and project-local share output are rejected. Entries are rechecked before reading. Each ZIP is staged before publication.
- Existing `.qsz` import/export code is unchanged apart from formatter wrapping; shared output is `.zip` / `application/zip`.
- Native output lives under application-support `archive_shares/share-*`, separate from source/cache metadata. ZIP remains after handoff, cancellation or unsupported status. A native error may have an uncertain handoff outcome, so it also retains the ZIP. Only failed preparation removes its own operation directory.

### R5 local project service for B

- `ArchiveShareService.shareProject(Project, {token, accountId, cloudActions})` returns `ArchiveShareResult(status: shared|unsupported, path)`.
- Local calls require only Project. Native error/preparation failure throws; unsupported is not success.
- B wired Home to this service and owns Home labels, busy state and Save ZIP UI. D did not edit those files.
- `shared` means native handoff, not proof of recipient delivery. Sheet cancellation has no distinct bridge result. Source projects are never deleted.

### R6 complete scoped cloud snapshot

- Cloud calls require C's CloudProjectActions. There is no fallback to the workspace cache or destructive pullAll/prune.
- The service validates captured token/account ID, then invokes `prepareSnapshot(project)` synchronously before its first path-provider/filesystem await. C captures the operation's login generation immediately.
- The returned snapshot's ensureCurrent is checked before/after preparation and immediately before native sharing. A delayed A-B-A request cannot adopt a fresh account generation.
- Selection is mapped project-relative into the payload-only snapshot root. Manifests and operation/cache parent files stay out of the ZIP.
- Snapshot lease is released in finally. The finished ZIP remains independent of that lease.
- Partial/failed downloads never launch native sharing. The remote API cannot represent empty directories, so no empty-remote-folder guarantee is made.

## Review fixes and frozen Windows contract

### Editor cloud-open lifecycle (R7)

`initState` now starts one `_openCloudSync()` Future with internal error handling. A service returned after unmount is disposed immediately: its constructor increments CloudWorkspaceActivity, but an unattached service is invisible to page.dispose. Open errors and unexpected initial-pull errors are consumed, the owned subscription/service are released, and a still-mounted page switches to offline/error state. No unhandled initialization Future or orphaned activity lease is intended. Optional `cloudSyncOpener(Project)` is a deterministic test seam only; production still calls CloudSyncService.open.

### Windows native file-sharing signature (R4)

Dart/native method signature remains `qflistudio/platform.shareFile({path: String, title: String, mimeType: 'application/zip'}) -> bool`. True means ShowShareUIForWindow accepted handoff; false is reserved for unavailable WinRT/interop support. Invalid input, busy preparation, closed owner and real failures use sanitized error codes.

`WindowsArchiveShare(HWND)` owns per-window state. It asynchronously obtains a StorageFile and registers DataRequested, sets a nonempty title and `SetStorageItems(..., true)`, then calls IDataTransferManagerInterop.ShowShareUIForWindow. StorageFile/event state stays alive independently of FlutterWindow. Disposal completes pending Flutter replies before messenger destruction, cancels pending open, and revokes the event. It never deletes the retained ZIP. Native selection/sheet completion is not claimed as recipient delivery.

Path validation matches path_provider_windows application-support layout using RoamingAppData plus VERSIONINFO CompanyName/ProductName. It allows only archive_shares/share-*/<name>.zip, rejects traversal/ADS and reparse points at the app-owned levels, and shares one file, never a parent directory.

Build requirements: MSVC/Visual Studio C++ desktop toolchain with Windows SDK **10.0.19041 or newer** including C++/WinRT projections; C++20; `windowsapp.lib`, `runtimeobject.lib`, `shell32.lib`, `version.lib` (plus existing dwmapi). New archive_share.cpp opts into exception translation within that translation unit because stock runner `_HAS_EXCEPTIONS=0` must not suppress C++/WinRT error handling. main.cpp initializes the HWND thread with RoInitialize(RO_INIT_SINGLETHREADED), destroys the window/resources before RoUninitialize, and balances successful initialization on failure paths. No package manifest capability or NuGet dependency was added. No native build or runtime validation ran.

A confirmed it owns App dependency resolution and generated Flutter registrant integration. D's source/staging copies exclude pubspec, lockfiles and generated registrants. All obsolete custom credential-vault code remains removed; A's direct flutter_secure_storage backend is the only credential owner.

## Native support matrix

| Target | Implementation | Status / follow-up |
| --- | --- | --- |
| Android | Core plugin ACTION_SEND, EXTRA_STREAM, ClipData, temporary read grant, non-exported QfliArchiveProvider | Java syntax and manifest parsed. Runtime provider/receiver validation unrun. |
| OHOS | App Share Kit SharedData with app file URI, general.zip-archive, dedicated subtree/link checks | ArkTS syntax parsed; installed SDK declarations inspected. HAP/device validation unrun. |
| iOS | App UIActivityViewController, active scene presenter and iPad popover anchor | Source reviewed against local Flutter implicit-engine registrar header. Apple compile/device validation unrun. |
| macOS | App NSSharingServicePicker, retained picker and archive URL | Source reviewed; native compile/receiver validation unrun. |
| Windows | Per-HWND IDataTransferManagerInterop, real StorageFile, DataRequested/SetStorageItems, native share UI | Implemented and source-reviewed only. Requires C++20 and Windows SDK 10.0.19041+; native compile/receiver validation unrun. Unsupported systems return false for Save ZIP. |
| Linux | Explicit shareFile false | Save ZIP fallback. No text/open-folder stand-in. |
| Other shells/web | Missing native method becomes unsupported | Save/export support depends on the host. No new web support claimed. |

Android provider exposes only prepared ZIPs under its dedicated application-support subtree, never parent files/cache. Provider is read-only and not exported. No broad storage permission was added.

## Credential/backend agreement with A

A superseded the initial custom channel proposal with direct flutter_secure_storage. D removed only D-created obsolete additions:

- QfliGitHubVault.java and Windows github_vault.h.
- All githubCredential handlers and Apple Security/Keychain helpers.
- Own temporary Advapi32 CMake addition. The current Windows CMake diff is only the later R4 WinRT share adapter/build linkage.
- Linux/OHOS custom credential-unavailable handlers.

A owns the dependency/lock/plugin backend. No competing custom vault remains. Browser support added to Android and Apple uses HTTP(S) URLs without userinfo. Desktop/OHOS existing opener behavior remains unchanged. OHOS secure-storage availability is A's explicitly unsupported/fail-closed contract, not a D plaintext fallback.

## Owned files and requirement/hunk map

All paths below are relative to the corresponding Git root. Root serializes the index and requirement commits.

### Core

| File / hunk | Requirement |
| --- | --- |
| android/src/main/AndroidManifest.xml provider declaration | R4 |
| android/src/main/java/com/azurekiln/qfli/core/QfliArchiveProvider.java (new) | R4 native read-only ZIP transport |
| android/src/main/java/com/azurekiln/qfli/core/QfliPickerPlugin.java shareFile case/imports | R4 |
| same Java file openUrl case | R1 support requested by A; stage separately from share case |
| lib/services/share_service.dart shareFile | R4 |
| lib/services/project_zip_service.dart exportSelectionToFile/_exportSelection | R4; existing .qsz code preserved |
| lib/editor/file_explorer.dart callback/menu/dispatch | R4 |
| lib/editor/editor_page.dart callback and onShareEntry wiring | R4 local entry; cloudActions construction/fences are R6 integration |
| same editor file cloudSyncOpener seam, _openCloudSync ownership/error handling, initState replacement | R7 service-lifecycle dependency; isolated from share hunks |
| test/editor_cloud_open_lifecycle_test.dart (new) | R7 late-open disposal plus sync/async/after-unmount error regression sources |
| lib/services/archive_share_service.dart (new), enum/result/_prepareAndShare/selection boundary | R4 shared foundation |
| same new file shareProject wrapper | R5 |
| same new file cloud branch (prepareSnapshot/ensureCurrent/release) | R6 |
| test/archive_share_test.dart (new), selection/path/binary/native lifetime/unsupported cases | R4/R5 regression sources |
| same test, cloud payload/A-B-A/partial failure cases | R6 regression sources |
| test/file_explorer_state_test.dart callback fixture + long-press folder/right-click file owner case | R4 |

Editor reuses B-owned localized fallback strings. Root must include those label hunks no later than the editor callback integration. Other Home/i18n/cloud/store/AppPaths/clone/pubspec changes visible in the shared worktree belong to A/B/C, not D.

### App

| File / hunk | Requirement |
| --- | --- |
| ios/Runner/AppDelegate.swift shareFile channel / presenter | R4 |
| same file openUrl branch | R1 support; split from share branch |
| macos/Runner/MainFlutterWindow.swift shareFile/picker | R4 |
| same file openUrl branch | R1 support; existing desktop opener already exists |
| ohos/entry/src/main/ets/entryability/EntryAbility.ets fileIo/fileUri imports + shareFile branch | R4 |
| windows/runner/flutter_window.h channel/share owner; flutter_window.cpp validation/handler/disposal | R4 native file share |
| windows/runner/archive_share.h and archive_share.cpp (new) | R4 WinRT per-HWND file handoff and lifetime owner |
| windows/runner/main.cpp RoInitialize/RoUninitialize, runner/CMakeLists.txt source/features/libs | R4 WinRT build/apartment dependency |
| linux/runner/my_application.cc shareFile handler/registration | R4 unsupported/save fallback |

No App pubspec or manifest permissions changed. Android provider manifest belongs to Core and is merged by normal plugin registration.

## Static checks actually performed

All commands ran only against the two requested worktrees and owned source paths.

1. Dart SDK: `D:/ProgramFiles/flutter_ohos/bin/cache/dart-sdk/bin/dart.exe`, version 3.11.5.
2. `dart format` on share_service, project_zip_service, archive_share_service, file_explorer, editor_page, archive_share_test and file_explorer_state_test: passed; latest pass had no remaining formatting edits after the explicit mounted guards.
3. Final targeted `dart analyze` on those seven files plus editor_cloud_open_lifecycle_test.dart (eight files): **No issues found**. Final `dart format --output=none --set-exit-if-changed` on all eight: **0 changed**. Earlier runs caught one braces lint and two BuildContext lints; all were corrected and analysis repeated cleanly.
4. JDK 25 Java compiler API `JavacTask.parse()` only, with `-proc:none`, for QfliPickerPlugin.java and QfliArchiveProvider.java: **SYNTAX_DIAGNOSTICS=0**. This did not compile Android classes or launch code.
5. Core AndroidManifest.xml parsed as XML: passed.
6. Installed ArkTS/TypeScript parser createSourceFile on App EntryAbility.ets: **ARKTS_PARSE_DIAGNOSTICS=0**. This is syntax only, not ArkTS semantic compilation.
7. Installed SDK source review confirmed CoreFileKit exports fileIo/fileUri, fileIo.lstatSync/isSymbolicLink, Share Kit SharedRecord.uri, SharedData(record), and general.zip-archive UTD. Local path_provider_ohos source confirms application-support maps to filesDir. Apple path-provider source confirms macOS bundle-identifier suffix.
8. `git diff --check` for all owned Core paths and all App changes: passed. Git reports an existing LF-to-CRLF conversion warning for AppDelegate.swift, not a whitespace error.
9. Source search over owned native roots for githubCredential/QfliGitHubVault/github_vault/import Security: no matches after cleanup. No dependency files were edited by D.

## Regression sources added, not executed

- archive_share_test.dart: selected binary only; selected subtree/empty folders; path/output rejection; escaping-link refusal; ZIP MIME/native lifetime; unsupported save path; complete cloud payload only; A-B-A during gated path preparation; partial snapshot failure prevents native share; native error propagation.
- file_explorer_state_test.dart: long-press selected folder then right-click selected file in the second workspace root, asserting owner and path.
- editor_cloud_open_lifecycle_test.dart: real CloudSyncService activity counter is released when the delayed open completes after page disposal; synchronous open error, asynchronous open error and error after unmount are consumed without an active lease. Four regression sources, unrun.
- C owns complete snapshot download/path/scope tests. B owns Home share/fallback tests.

## Cumulative staging copies (root-owned integration)

Prepared `reports/staging/d/{R1,R7,R4,R5,R6}/{core,app}/` with **only changed paths per stage**. Overall replay order remains R1 → R7 → R3 → R4 → R5 → R6 → R8; D has no R3/R8 changes.

- R1: 3 browser-only native paths (Core Android and App Apple channels).
- R7: 2 paths (editor cloud-open lifecycle and four regression sources), no share imports/callback yet.
- R4: 20 paths (local selection ZIP, local editor callback, native file sharing including Windows, local tests). No project wrapper or cloud sharing. Cloud menu is hidden until R6.
- R5: 2 paths (local shareProject wrapper and corresponding local test calls).
- R6: 4 paths (final archive service/editor/explorer/tests, enabling cloud snapshot/session fences and cloud menu).

These are 31 complete cumulative copies for 21 D-owned paths, not staged Git files. `manifest.json` records each prior/current SHA-256 and final source hash. Replaying the **written copies** reaches all 21 frozen source files byte-for-byte. Both Git indices and all source hashes remained unchanged during generation. Fifteen intermediate/final Dart stage candidates parsed/formatted through formatter stdin; only report copies were formatted. Source stayed frozen. `diffs/R*.patch` are review aids. The generator writes only below reports/staging/d.

See `reports/staging/d/README.md` for replay instructions/dependencies and `manifest.json` / `format-verification.json` for machine-readable evidence. A confirmed it owns App dependency resolution and generated registrants; D staging excludes pubspec/lock/registrants. B's R4 labels and C's R7/R6 service/model stages are required before the matching consumer copies. Root alone applies/stages/commits.

## Remaining verification and gaps

- No local flutter test, test runner, build, CI, native service, simulator or device executed.
- Run regression sources in cloud CI, including existing project_zip_test .qsz compatibility and symlink cases on a host that can create links.
- Native Android/iOS/macOS/OHOS/Windows compilation and real receiver-read-after-dismissal checks remain unrun. No Windows C++ compiler/SDK semantic check ran locally; only source and build-wiring review plus diff checks.
- Linux native file sharing remains intentionally unsupported; Save ZIP is the truthful fallback. Windows returns unsupported only when WinRT sharing or its interop class is unavailable.
- Retained ZIPs currently have no automatic expiry. This avoids premature receiver breakage but requires a future explicit user/storage-lifecycle cleanup policy; this task does not delete them on a timer.
- Runtime archive race safety under adversarial concurrent filesystem replacement still requires native/host testing. The Dart exporter rejects links and rechecks ancestors before reads; it does not claim an OS-level immutable source lease for local projects.
- Root must split mixed R1 browser-support and R4 sharing hunks, plus R5/R6 service hunks, before serial requirement commits. No commits were made by D.
