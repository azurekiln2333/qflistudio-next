# Pi C contracts

Core: `D:/MyNewProjects/_wt/studio-git-integration/qfli_studio_core`.
Scope: R3, R6, R7, R8 service layer only.
No Home, labels, editor, sharing, clone or dependency edits.

## B: Home integration

New owner: `lib/services/cloud_project_actions.dart`.

```dart
final actions = CloudProjectActions(auth: widget.auth, store: widget.store);
// ChangeNotifier. Dispose with the Home state.
List<Project> get projects; // current account only
bool get available;
bool isBusy(Project project);
Future<void> refresh(); // owns list generation and scoped merge
Future<CloudDeleteResult> deleteProject(Project project);
Future<CloudCacheStatus> inspect(Project project);
Future<CloudCacheStatus> cacheProject(Project project); // also update
Future<CloudSnapshot> prepareSnapshot(Project project);
Future<void> clearCache(Project project);
CloudCacheStatus status(Project project);
```

Use `actions.projects` for cloud rows.
Keep `store.projects.where((p) => !p.isCloud)` for local rows.
Do not issue an independent `cloudProjects` merge in Home.
`refresh()` rejects old results after delete or account change.
Delete begins by invalidating list generations.
Remote failure keeps registry and cache.
Remote success awaits registry persistence even after logout.
The persisted deletion fact targets the captured origin/account/project only.
No new account credential is consulted for that local cleanup.
Complete refresh reconciles missing rows only within its captured scope.
`CloudDeleteResult` has `remoteDeleted`, `error`, `cleanupError`.
Remote success plus cleanup error is not a failed remote delete.
Deletion keeps cache files by default.
Never promise recycle-bin recovery for remote deletion.

Cache uses `CloudCachePhase.notCached/caching/cached/failed`.
`CloudCacheStatus` has `phase`, `completedFiles`, `totalFiles`,
`downloadedBytes`, `fileCount`, `bytes`, `cachedAt`, `error`.
A prior good manifest survives a failed update.
`cached` does not promise remote freshness.
Cache metadata loads through `inspect()` after list refresh.
Clear refuses an active editor, export lease or pending edits.
It does not delete remote data.

Scope model: `lib/models/cloud_project.dart`.
`CloudProjectScope(origin: ApiConfig.origin, accountId: auth.user!.id)`.
Project gains optional `cloudAccountId` and `cloudOrigin`.
Unknown-owner old registry rows stay preserved, not reassigned.
New rows use canonical account-scoped paths.
Old mirrors are never moved or deleted.
B should pass `scope: capturedScope` and `session: capturedSession`
on new cloud registration.
Creation/open accept the same optional `scope` and `session`.
Registry writes recheck the session before atomic publication.

## D: cloud export integration

Exact low-level entry point in `lib/services/cloud_cache_service.dart`:

```dart
import '../models/cloud_project.dart';
import '../services/cloud_cache_service.dart';

final capturedGeneration = auth.sessionGeneration;
final session = CloudSession(
  scope: CloudProjectScope(
    origin: ApiConfig.origin,
    accountId: stableAccountId, // captured auth.user!.id, not a display name
  ),
  token: capturedToken,
  isCurrent: () => auth.token == capturedToken &&
      auth.user?.id == stableAccountId &&
      auth.sessionGeneration == capturedGeneration,
);
final CloudSnapshot snapshot = await CloudCacheService.instance.prepareSnapshot(
  project: project,
  session: session,
);
try {
  snapshot.ensureCurrent();
  // snapshot.path is a payload-only directory.
  // Map the validated project-relative selection into snapshot.path.
  // ZIP with the existing ZIP safety and check ensureCurrent before sharing.
} finally {
  await snapshot.release();
}
```

Home callers may use `actions.prepareSnapshot(project)` as a convenience.
This calls the identical low-level service with a fenced auth capture.

`CloudSnapshot` has `path`, `fileCount`, `bytes`, `cachedAt`,
`ensureCurrent()` and idempotent `Future<void> release()`.
It represents the complete current remote file tree.
It excludes unsent workspace edits and cache metadata.
Refresh downloads every file with `cloudFileTree/cloudReadFile`.
It publishes only after all files and paths validate.
Partial download never yields a snapshot.
It never calls destructive `pullAll` or prune.
Empty remote directories cannot be inferred from this API.

## Cache path and editor compatibility

`projects/cloudProjects/<origin-hash>/<account-hash>/<cloud-id>/`.
Workspace: `<cloud-id>/workspace/`.
Immutable snapshot payload: `<cloud-id>/snapshots/<generation>/files/`.
Manifest and operation metadata stay outside payload.
IDs are stable, safe and never derived from tokens or titles.

`CloudSyncService.open` stays source-compatible.
It gains optional scope and session injection.
The shared active session is set by Home actions.
Existing editor calls capture this session at open.
A scope/token change stops later network operations.
Known legacy mirrors remain untouched.
Unowned legacy cache paths fail closed rather than upload as another account.

## Authoritative auth revision

Root approved a narrow `lib/store/auth_store.dart` extension.
Public getter: `int get sessionGeneration`.
`load`, `signIn`, `signOut` and `clearLocalData` advance it before awaiting.
Profile, points and avatar refresh do not advance it.
Capture it together with token/account for every async cloud operation.
C uses it to reject same-token A-B-A results.
Stale user-info/profile/load responses cannot overwrite a newer login.
The optional `AuthStore(api: ...)` seam keeps regression sources offline.

## Validation and ownership

Only local format, analysis and diff checks will run.
Regression test sources are for cloud CI only.
Targeted C-source and regression-source analysis passed.
B/D consumer analysis passed.
See `pi-c.md` for final checks and reviewed limitations.
Workers do not stage, commit or push.
Root separates R3/R6/R7/R8 hunks.
