# Native Share Targets and External Folders

> Covers inbound share intents, the native inbox, destination selection, session attachment and Apple external-folder access. Read this before changing native entry points, shared intake, folder providers or editor navigation.

## 1. Scope and ownership

- The app handles system entry points and copies incoming files before it sends paths to Dart.
- Core owns inbox storage, intake decisions and editor navigation.
- Android and OHOS native code own intent reception. iOS and macOS own document/folder coordination and security-scoped bookmarks.
- Keep ordinary launches and existing interop callbacks working.

## 2. Share channel and payloads

All supported platforms use one method channel, `qflistudio/share_inbox`.

| Direction | Method/payload |
| --- | --- |
| Native → Dart | `incoming` with `{id, coldStart, source, files: [{path, name, bytes, mimeType?}]}` |
| Dart → native | `takePending` for a cold-start batch; `discard {id}` to discard a batch |
| Batch id | `[A-Za-z0-9_-]{1,64}` |

Native code copies received files into `<app data>/shared_inbox/<batchId>/` before it notifies Dart. Copying must not block the UI thread. Bound file counts and copied bytes, and exclude failed or incomplete copies. Android `content://` grants may expire when the activity ends. iOS security-scoped URLs require coordination. Dart reads only app-private copies. Both native and Dart validate batch IDs before joining filesystem paths. An invalid ID must never reach the filesystem. `mimeType` is optional.

`pending` caches only the latest uncaptured batch. Older uncached batches remain for `ShareInboxStore.sweep()` to remove. Do not add a native queue. `takePending` also sets `dartListening`: before the call native code caches the batch; after the call native code emits `incoming`. Engine/activity rebinding must retain pending input and detach obsolete handlers.

## 3. Platform registration

### Android

`android/app/src/main/AndroidManifest.xml` registers:

- `SEND` and `SEND_MULTIPLE` with `mimeType="*/*"`.
- `VIEW` with `scheme="content"` and `mimeType="*/*"`.
- No `http`/`https` VIEW filter. QFLI must not become a browser fallback.
- `MainActivity.onNewIntent` forwards warm intents; `configureFlutterEngine` forwards the cold intent. Keep `launchMode="singleTop"`.

### iOS

`ios/Runner/Info.plist` declares `CFBundleDocumentTypes` using append-only keys; do not reorder unrelated plist entries. `SceneDelegate.swift` forwards document URLs. `AppDelegate.didInitializeImplicitFlutterEngine` configures the channel. Avoid a new Swift file unless the project-file registration is included.

Do not add a Share Extension or App Group. Distributed iOS builds are re-signed by users, and App Group containers do not survive that re-signing model.

### HarmonyOS

`ohos/entry/src/main/module.json5` declares `sendData` with `maxFileSupported: 16` and `viewData` with `maxFileSupported: 1`, both using `scheme: "file"` and `utd: "general.file"`. `EntryAbility.onCreate` handles the cold want; `onNewWant` handles the warm want. Both call `offerShareWant`.

## 4. Limits, retention and destination selection

| Limit | Value |
| --- | --- |
| Files per batch | 16 |
| Maximum individual file | 2 GiB |
| Inbox total | 512 MiB |
| Retention | 7 days |

After the channel starts, `ShareInboxStore.sweep()` removes expired batches first, then removes the oldest batches until the inbox is under the total limit. Swallow cleanup failures: a locked file must not block startup.

`ShareIntakeHost` queues batches, waits for home readiness, then shows `showShareIntakeSheet`. Keep the destination → project → optional-session flow and these tested keys stable: `share-intake-sheet`, `share-intake-into-project`, `share-intake-into-session`, `share-intake-project-<id>`, `share-intake-session-<id>`, `share-intake-new-session`, `share-intake-cancel`.

`copyBatchIntoProject` copies files into `<project>/inbox/`. Resolve duplicate names with `name (1).ext` through `name (99).ext`. Write a `.part` file before renaming it. Return project-relative paths with `/` separators.

To attach shared files to an Agent session, copy them into the project first. Agent `read_file` accepts project-relative paths and has no read-only allow-list. Open the editor with `harnessSession` and `composerPrefill`:

```dart
openEditorPage(
  context,
  project: project,
  // ...
  revealAgentPane: true,
  harnessSession: HarnessSessionTarget(hostId: kStudioHostId, sessionId: id),
  composerPrefill: ComposerDraft(attachments: relativePaths, autoSend: false),
);
```

`ComposerDraft.autoSend` defaults to `true` for existing callers. Share attachment sets it to `false`; the user reviews the prefilled files and presses send.

## 5. External folders and platform channel

The shared folder channel is `qflistudio/platform`. It exposes `pickFolder`, `resolveFolders`, `releaseFolder`, `folderList`, `coordinatedRead` and `coordinatedWrite`.

- Folder result: `{id, name, path}`.
- Listing entry: `{name, path, isDirectory, size, downloaded}`.
- Reads return bytes. Writes accept `{path, bytes}`.
- User cancellation returns `null`.
- External project metadata remains in the app registry. Files remain owned by their original folder provider. `UIFileSharingEnabled` and `LSSupportsOpeningDocumentsInPlace` expose app documents; they do not move those documents out of the app container.

The iOS and macOS `ExternalFolderStore` implementations keep security-scoped bookmarks and coordinate every read and write. Start downloading iCloud placeholders before reading their content. macOS requires user-selected read/write and app-scoped bookmark entitlements. Do not add a custom iCloud container; distributed iOS artifacts are re-signed by users.

Bookmark APIs differ by platform:

- iOS creates bookmarks with `.minimalBookmark` and resolves with empty/default options. Do not use `.withSecurityScope` or `.securityScopeAllowOnlyReadAccess`; those options are not available in the iOS SDK.
- macOS uses `.withSecurityScope` for both creation and resolution.
- `startAccessingSecurityScopedResource` and `stopAccessingSecurityScopedResource` manage scope access independently of bookmark options.

Basis: Apple “Providing access to directories” and Apple DTS forum thread 772143.

## 6. Validation and acceptance

### Tests Required

All formatting, analysis, tests and builds run in GitHub Actions cloud CI. Do not run local package resolution or local validation for this contract. `--no-pub` does not permit local tests. The `App installers` workflow covers Android, iOS, macOS and OHOS compile paths. Core `test/share/` checks shared intake behavior. Assert pending delivery/rebinding, batch-ID rejection, copy failures and quotas, stable destination keys, project-relative attachments and `autoSend: false`.

Device acceptance is separate from cloud CI. It covers WeChat open-in, repeated shares, cold starts, iCloud placeholders, folder access after restart and actual re-signed IPA upgrades. A green cloud build does not prove device acceptance.

| Condition | Required behavior |
| --- | --- |
| Dart listener is not ready | Keep the batch available for `takePending`. |
| Engine/activity is recreated | Rebind the channel without losing pending input. |
| Copy fails, is partial/zero-byte, or exceeds budget | Do not report it as received; clean partial copies. |
| User cancels the folder picker | Return `null`. |
| Bookmark is unavailable | Report access failure; do not delete user files. |
| iCloud placeholder is present | Download it, then coordinate the read. |
| iOS bookmark is created/resolved | Use `.minimalBookmark` and default resolve options. |
| macOS bookmark is created/resolved | Use `.withSecurityScope` for both. |
| A cloud job is green but device acceptance is absent | Report cloud validation only. |

### Good / Base / Bad Cases

- Good: a cold-start share waits for home/services readiness, then lets the user choose project import or a session attachment without auto-sending.
- Base: an ordinary launch without a document follows the existing startup flow.
- Bad: pass temporary provider URIs as durable Dart paths or delete external-folder contents when removing a project.

## 7. Pitfalls: wrong vs correct

- Wrong: pass a provider URI or native inbox path to the Agent. Correct: copy into the project and pass project-relative paths.
- Wrong: announce a file before its copy finishes or count a failed empty copy as received. Correct: publish only complete copies.
- Wrong: clear an external provider's files when a project is removed. Correct: remove only app-owned metadata and report access failures without deleting user files.
- Wrong: bind handlers to an engine that was destroyed. Correct: bind to the active engine and keep pending batches independently.
- Wrong: store received inbox files outside app data or request new storage permissions. Correct: keep native intake in the app-private inbox before project import.
- Wrong: add a second session-targeting parameter. Correct: reuse `harnessSession`; `composerPrefill` is the only editor parameter this feature adds.
- Wrong: commit generated plugin registrants or `generated_plugins.cmake`. Correct: keep generated registration output out of source changes; cloud dependency setup may regenerate it.
