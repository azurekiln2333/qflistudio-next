# Native Share Targets and External Folders

## 1. Scope / Trigger

Read this when changing native file reception or Apple folder access.
Core owns intake decisions and editor navigation. The app owns system entry
points and must copy incoming files before passing their paths to Dart.

## 2. Signatures

- Share channel: `qflistudio/share_inbox`, Dart calls `takePending`, native
  emits `incoming`.
- Batch: `{id, files, coldStart, source}`. File: `{path, name, bytes, mimeType?}`.
- Folder channel: `qflistudio/platform`. Methods: `pickFolder`,
  `resolveFolders`, `releaseFolder`, `folderList`, `coordinatedRead`,
  `coordinatedWrite`.
- Folder result: `{id, name, path}`. Listing entry: `{name, path,
  isDirectory, size, downloaded}`. Read returns bytes. Write accepts
  `{path, bytes}`.

## 3. Contracts

Android receives `ACTION_SEND`, `ACTION_SEND_MULTIPLE`, and supported
`ACTION_VIEW` URIs. iOS receives document-open callbacks in `SceneDelegate`.
OHOS receives `sendData` and `viewData` through `EntryAbility`.
Keep ordinary launches and existing interop callbacks working.

Copying must not block the UI thread. Bound file counts and copied bytes.
Do not advertise partial or zero-byte failed copies as successfully received
files. Retain cold-start batches until Dart can take them. Rebinding an engine
or activity must preserve a pending batch and detach obsolete handlers.
The Core inbox store validates batch IDs and handles retention and quotas.

The iOS and macOS `ExternalFolderStore` implementations keep security-scoped
bookmarks. Coordinate reads and writes with the system. Start downloading
iCloud placeholders before reading their content. macOS requires user-selected
read/write and app-scoped bookmark entitlements. Do not add a custom iCloud
container: distributed iOS artifacts are unsigned and users re-sign them.

Bookmark options differ by platform. iOS has no security-scope bookmark
options. Create a bookmark with `.minimalBookmark` and resolve it with the
empty/default options. Do not use `.withSecurityScope` or
`.securityScopeAllowOnlyReadAccess` on iOS. Neither exists in the iOS SDK and
the build fails. macOS keeps `.withSecurityScope` for both create and
resolve. Scope grants come from `startAccessingSecurityScopedResource` and
`stopAccessingSecurityScopedResource`, independent of the bookmark options.
Basis: Apple "Providing access to directories" and Apple DTS forum thread
772143.

`UIFileSharingEnabled` and `LSSupportsOpeningDocumentsInPlace` expose app
documents. They do not move those files out of the app's storage container.
External project metadata stays in the app registry; external files remain
owned by their original folder provider.

## 4. Validation & Error Matrix

| Condition | Required behavior |
| --- | --- |
| No Dart listener yet | Keep the batch for `takePending`. |
| Engine/activity recreated | Rebind channel without losing pending input. |
| Copy fails or exceeds budget | Exclude failed output and clean partial copies. |
| User cancels directory picker | Return null. |
| Bookmark unavailable | Report access failure without deleting user files. |
| iCloud placeholder | Download, then coordinate the read. |
| iOS bookmark create/resolve | Use `.minimalBookmark` and default resolve options. |
| macOS bookmark create/resolve | Use `.withSecurityScope` for both. |

## 5. Good / Base / Bad Cases

- Good: cold-start sharing reaches the intake sheet after the editor services
  are ready, and the user chooses import or attachment.
- Base: launching the app without a document follows the ordinary startup.
- Bad: passing temporary provider URIs as durable Dart file paths or clearing
  external folder contents when removing a project.

## 6. Tests Required

Tests run in cloud CI. Local format, Dart analysis, and TypeScript checks are
allowed. `App installers` compiles Android, iOS, macOS, and OHOS native paths.
Core `test/share/` validates the shared intake contract.

Device acceptance must separately cover WeChat open-in, repeated shares,
cold starts, iCloud placeholders, folder access after restart, and actual
re-signed IPA upgrades. A successful cloud build is not device acceptance.

## 7. Wrong vs Correct

Wrong: invoke `incoming` before a copied file is complete, or keep a handler
bound to a destroyed Flutter engine.

Correct: publish only completed inbox files and bind the channel to the active
engine while keeping pending batches independently of that engine.
