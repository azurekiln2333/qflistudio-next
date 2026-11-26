# Scoped Cloud Project Cache and ZIP Sharing

## 1. Scope / Trigger

Apply when changing cloud project lists, deletion, cache, editor mirrors or ZIP
sharing. Source authority is the frozen implementation for task
`11-21-github-repo-clone` in
`D:/MyNewProjects/_wt/studio-git-integration/qfli_studio_core`.
This documents that integration checkout, not a released root App dependency.
Confirm the resolved Core before use, per [Repository Layout](./repository-layout.md).
[Project Storage](./project-storage.md) owns local metadata and directories.
[Home Recovery](./home-recovery.md) owns local recycle-bin recovery, not remote deletion.

## 2. Signatures

Paths below are relative to that Core:

- `models/cloud_project.dart`: `CloudProjectScope({required String origin,
  required String accountId})`, `CloudSession({required CloudProjectScope scope,
  required String token, required bool Function() isCurrent})`,
  `void CloudSession.ensureCurrent()`.
- `services/cloud_project_actions.dart`: `CloudProjectActions({required AuthStore
  auth, required ProjectStore store, ApiClient? api, CloudCacheService? cache})`.
  Observable getters: `projects`, `available`, `scope`. Methods:
  `Future<void> refresh()`, `Future<CloudDeleteResult> deleteProject(Project project)`,
  `Future<CloudCacheStatus> inspect(Project project)`,
  `Future<CloudCacheStatus> cacheProject(Project project)`,
  `Future<void> clearCache(Project project)`, `CloudCacheStatus status(Project project)`,
  `bool isBusy(Project project)`, `Future<CloudSnapshot> prepareSnapshot(Project project)`.
- `services/cloud_cache_service.dart`: `CloudCacheService.instance.prepareSnapshot(
  {required Project project, required CloudSession session}) -> Future<CloudSnapshot>`.
  `inspect`, `update` and `clear` take `(Project project, CloudSession session)`.
- `CloudSnapshot`: payload-only `path`, `fileCount`, `bytes`, `cachedAt`,
  `void ensureCurrent()` and idempotent `Future<void> release()`.
- `store/project_store.dart`: `Future<ProjectResult> addCloudProject({required
  String name, required String cloudId, required String cachePath, String language
  = '', CloudProjectScope? scope, CloudSession? session})`. Async callers pass both
  captured scope and session. `removeDeletedCloudProject(Project project,
  CloudProjectScope scope) -> Future<void>` records confirmed remote deletion.
- `services/archive_share_service.dart`: `shareProject(Project project, {String?
  token, String? accountId, CloudProjectActions? cloudActions})` and
  `shareSelection(Project project, {required String selectedPath, String? token,
  String? accountId, CloudProjectActions? cloudActions})` are static methods returning
  `Future<ArchiveShareResult>`. Its fields are `status` (`shared` or `unsupported`)
  and retained ZIP `path`.
- `services/share_service.dart`: `ShareService.shareFile({required String path,
  required String title, String mimeType = 'application/zip'}) -> Future<bool>`.
  Native method is `qflistudio/platform.shareFile` with only path/title/MIME.

## 3. Contracts

### Ownership and auth

Use `CloudProjectScope(origin: ApiConfig.origin, accountId: auth.user!.id)`.
`Project.cloudOrigin` and `cloudAccountId` identify ownership. Never adopt unowned
legacy rows or move their mirrors. Home combines local registry rows with
`actions.projects`, not all retained cloud rows. C owns cloud refresh/merge tickets.

`AuthStore.sessionGeneration` advances synchronously before awaits in `load`,
`signIn`, `signOut` and `clearLocalData`. Profile/points changes do not advance it.
Capture generation, token and account together. Compare the live generation after
awaits and before publication/native handoff. Token/account equality alone misses
A-to-B-to-A, including a reused token before delayed auth notifications.
Home also fences widget replacement/disposal. C shares one auth binding across
facades, so disposing an export facade does not invalidate an editor's session.

### Paths, payload and publication

`AppPaths.cloudProjectRoot({required scope, required cloudId,
String? projectsRootOverride})` resolves beneath `AppPaths.projectsRoot()`:

```text
cloudProjects/<SHA256(origin)>/<SHA256(accountId)>/<cloudId>/
  owner.json, manifest.json, status.json, workspace.json
  workspace/                           mutable editor mirror
  snapshots/<generation>/files/        immutable complete remote payload
```

Scope hashes never use tokens or display names. Cloud IDs match
`[A-Za-z0-9][A-Za-z0-9_-]{0,127}` and exclude Windows reserved device names.
Cache ownership metadata stays outside payload directories.

Downloads use a fresh remote file tree and Base64 file bytes in an operation-owned
stage. Validate every file, compare path/mtime trees before and after download,
rename the complete stage, then publish the manifest. Failure preserves the prior
complete snapshot. Never use destructive `pullAll`/prune to prepare sharing.
The remote file-list API cannot establish empty remote directories.
A snapshot is not the mutable workspace and does not include unsent local edits.
Workspace population uses its synchronized baseline and preserves local conflicts.

Validate portable paths before filesystem access and when restoring manifests.
`CloudCachePaths.relative` rejects absolute/traversing paths, backslashes, colons,
control characters, empty/dot segments, trailing dot/space, reserved device names
and Windows-invalid characters. Validate **every case-folded prefix**, not just
leaf filenames: reject `A/x` plus `a/y`, duplicate leaves and file/directory
collisions such as `a` plus `a/b`. `noLinks` checks every existing ancestor,
including the configured root. Manifest reads verify hashes, byte/file counts and
absence of extra payload files. ZIP selection also rejects links and escapes.

### Deletion, clearing and status

Remote deletion invalidates list tickets before network I/O. Server failure keeps
registry/cache. Confirmed success awaits scoped registry removal and persists a
`deletedCloud` tombstone keyed by origin/account/project, even after logout.
It uses no replacement account credential. Disk failure retains the in-memory
tombstone and returns `CloudDeleteResult(remoteDeleted: true, cleanupError: ...)`.
Retry local persistence, not remote deletion. Do not claim durable success on that
failure. Tombstones prevent old refresh/reload resurrection. Complete refresh reconciles
missing rows only within its captured scope. Remote deletion keeps cache bytes
and never promises local recycle-bin recovery.

`clearCache` is local-only. Require owner/session checks, no active editor,
pending push, dirty marker or export lease, and a clean on-disk workspace baseline.
Reject unknown cache entries. Repeat session/activity checks immediately before
synchronous removal, with no intervening await. Failed guards preserve all bytes.

`CloudCachePhase` is `notCached/caching/cached/failed`. `CloudCacheStatus` separates
live `completedFiles/totalFiles/downloadedBytes` from last-complete
`fileCount/bytes/cachedAt`, plus safe `error`. Failed updates retain prior metadata.
`inspect` validates manifests after restart. Interrupted downloads report failure,
not a complete cache. Cached does not promise current remote freshness.

### ZIP boundary

Cloud sharing invokes `cloudActions.prepareSnapshot(project)` before any unrelated
filesystem/path-provider await, retaining that exact login generation.
Recheck `snapshot.ensureCurrent()` after preparation awaits and immediately before
native handoff. Release the lease in `finally`. ZIP only `snapshot.path` or the
validated selected subtree, never its parent, workspace, manifest or owner files.
Local sharing needs only the project. `.qsz` import/export remains separate.

Finished ZIPs live in `applicationSupport/archive_shares/share-*` and remain after
handoff, dismissal or unsupported transport. `shared` means OS handoff, not receiver
delivery. `unsupported` offers saving that retained ZIP via `PickerService.saveDocument`.
Preparation/native failures throw. Never send tokens to native sharing or substitute
text sharing. No immediate deletion after an uncertain native handoff.

## 4. Validation & Error Matrix

| Condition | Required result |
| --- | --- |
| Login generation changes, including same-token A-B-A | `sessionChanged`, no stale publication or native sheet |
| Refresh ticket predates delete or newer refresh | Reject stale merge, no card resurrection |
| Server DELETE fails | Keep card/cache, report remote failure |
| DELETE succeeds then logout | Await durable removal for the original scope |
| DELETE succeeds but registry write fails | Keep in-memory tombstone, report `cleanupError`, retry persistence |
| Download partial, tree changes or manifest fails checks | No share snapshot, retain previous complete payload |
| Prefix collision, traversal, link or owner mismatch | Reject before write/export, preserve foreign data |
| Clear meets active/pending/dirty/lease guard | Recoverable `busy`/`dirty`, no local or remote deletion |
| Native share unavailable | `unsupported` plus retained ZIP, not successful delivery |

## 5. Good / Base / Bad Cases

- Good: refresh downloads immutable remote bytes while an editor keeps dirty
  workspace bytes. ZIP uses only the leased snapshot.
- Base: a valid complete manifest restores count/bytes/time after restart without
  claiming the server has not changed.
- Bad: delete with local recycle-bin text, infer cache completeness from a folder,
  clear an active workspace, or validate only complete leaf paths.

## 6. Tests Required

Cloud regression sources are in the integration Core, not runtime evidence:

- `cloud_project_actions_test.dart`: failed DELETE preserves every byte, deferred
  success after logout survives registry reload, stale list cannot resurrect rows,
  scopes isolate equal IDs, and facade disposal preserves another session.
- `cloud_cache_service_test.dart`: partial/update failure retains old manifest,
  every-prefix case/type collisions fail before writes, scope changes publish no
  snapshot, manifest extras/hash mismatch fail, clear guards preserve dirty/leased
  data and pending local deletions.
- `cloud_auth_generation_test.dart`: authoritative generation rejects same-token
  A-B-A and stale load/profile results without invalidating profile updates.
- `archive_share_test.dart`: selected/binary-only ZIP, no metadata/parent leakage,
  account switch before handoff, retained ZIP lifetime and honest native errors.
- `project_card_cloud_actions_test.dart`: four cache states, measured metadata,
  independent delete/clear confirmations and disabled duplicate destructive actions.

Local validation is format/static analysis and document lint only. Tests, builds
and native receiver validation remain cloud/device follow-up unless authorized.

## 7. Wrong vs Correct

Wrong: after awaiting a directory lookup, use the current account to download a
mutable workspace, ZIP the cache parent, then delete the ZIP after opening a sheet.

Correct: capture the scoped snapshot immediately and keep the immutable lease:

```dart
final pending = actions.prepareSnapshot(project);
final snapshot = await pending;
try {
  snapshot.ensureCurrent();
  await ProjectZipService.exportSelectionToFile(
    projectRoot: snapshot.path,
    selectedPath: snapshot.path,
    destination: retainedZipOutsidePayload,
  );
  snapshot.ensureCurrent();
  await ShareService.shareFile(path: retainedZipOutsidePayload, title: project.name);
} finally {
  await snapshot.release();
}
```
