# Pi D sharing contract

Status: implemented; targeted Dart analysis and native syntax/source checks passed. Runtime/native validation remains unrun.
Owned roots are studio-git-integration Core and App. No remote-account-binding files change.

## Change boundary

Adds selection-only ZIP creation and native file handoff. Preserves `.qsz` import/export. D does not edit Home, labels, authentication, cloud/store/paths, clone, or Core dependency manifests.

## Exact public API for B

Import `package:qfli_studio_core/services/archive_share_service.dart`.

```dart
enum ArchiveShareStatus { shared, unsupported }

class ArchiveShareResult {
  final ArchiveShareStatus status;
  final String path; // retained .zip for save/export fallback
}

abstract final class ArchiveShareService {
  static Future<ArchiveShareResult> shareProject(
    Project project, {
    String? token,
    String? accountId,
    CloudProjectActions? cloudActions,
  });
  static Future<ArchiveShareResult> shareSelection(
    Project project, {
    required String selectedPath,
    String? token,
    String? accountId,
    CloudProjectActions? cloudActions,
  });
}
```

Local callers need only the project. Cloud callers pass captured token, stable account ID, and their existing CloudProjectActions facade. Preparation/download/native failures throw. Unsupported returns the retained ZIP path, not success. Save fallback uses `PickerService.saveDocument(suggestedName: ...)`, then copies that ZIP or writes its bytes to the returned document URI.

`shared` means the OS accepted the handoff, not receiver delivery. Native sheet cancellation has no distinct result on the current bridge. Dismissal never deletes the archive or source files.

`ShareService.shareFile({required String path, required String title, String mimeType = 'application/zip'}) -> Future<bool>` calls `qflistudio/platform.shareFile`. False means unavailable; native failures remain errors. No token enters native arguments.

## C integration (frozen)

`cloudActions.prepareSnapshot(project) -> Future<CloudSnapshot>` returns payload-only `path`, `ensureCurrent()` and idempotent `release()`.

D validates captured token/account ID and invokes prepareSnapshot synchronously before the first filesystem/path-provider await. C therefore captures the request's login generation immediately. D checks that same snapshot generation after preparation awaits and immediately before native sharing. It maps the selection to a validated project-relative path inside the snapshot. It releases the lease in finally and retains the finished ZIP.

No destructive pullAll/prune is called. Partial downloads and A-B-A identity changes never reach native sharing. Snapshot metadata outside the payload root does not enter ZIPs. Remote empty directories cannot be inferred from the file-list API.

## File tree

`FileExplorer.onShareEntry: Future<void> Function(Project owner, String path)?` is editor-injected. `_ownerOf(node.path)` resolves multi-root ownership. The tree stores no token. Long-press and secondary-click share the existing menu. Editor owns duplicate-operation protection, account fencing and Save ZIP fallback.

## Native and lifetime

- Output is `.zip` with `application/zip`; `.qsz` stays unchanged.
- Each operation owns one `applicationSupport/archive_shares/share-*` directory. No automatic post-handoff deletion occurs; delayed receivers keep access. Failed preparation removes only its operation directory.
- Android: dedicated non-exported read-only ContentProvider (`QfliArchiveProvider`), restricted to that ZIP subtree, temporary read grants and ClipData. No parent files/cache tree is exposed.
- OHOS: Share Kit, app file URI and `general.zip-archive`, with dedicated-root and link checks.
- iOS: UIActivityViewController; macOS: NSSharingServicePicker.
- Windows: per-HWND IDataTransferManagerInterop GetForWindow/ShowShareUIForWindow, real StorageFile in DataRequested.SetStorageItems, retained file/event lifetime. Build requires MSVC, C++20 and Windows SDK 10.0.19041+ with windowsapp/runtimeobject/shell32/version linkage. Implementation is source-reviewed but native compilation/runtime are unrun. Actual unavailable WinRT systems return false.
- Linux: explicit unsupported false, retained ZIP and save/export fallback. Text sharing or opening a folder is never reported as native file sharing.
- ZIP contains only the selected file/folder or complete payload. Unsafe relative paths and links fail closed.

## Credential/backend agreement

A's superseding contract uses flutter_secure_storage directly. D removed its own obsolete custom Android/Apple/Windows vault files and all githubCredential handlers. No competing backend remains. A owns Core pubspec/lock and plugin registration. D retains Android/iOS/macOS browser openUrl support. Existing desktop/OHOS opener behavior remains unchanged.

## Root requirement split

- R1: D native browser-only support; A owns credentials/dependencies/App registrants.
- R7: editor cloud-open ownership/error handling plus cloudSyncOpener test seam. A late open after unmount is disposed, and initialization failures release service/activity ownership.
- R4: selection ZIP API, explorer/editor callback, native transport (including Windows WinRT), safety/lifetime tests.
- R5: ArchiveShareService whole-local-project entry point; B owns Home action.
- R6: cloud adapter and generation fencing; C owns snapshots/cache, B owns Home action.

Only format, targeted analysis, native syntax/source review and diff checks run locally. Runtime tests, builds and native receiver validation remain cloud/device follow-up. No stage/commit/push.
