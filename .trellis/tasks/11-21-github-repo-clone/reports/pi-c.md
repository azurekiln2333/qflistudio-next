# Pi C delivery

## Scope and roots

Active task: `11-21-github-repo-clone`.
Core: `D:/MyNewProjects/_wt/studio-git-integration/qfli_studio_core`.
No remote-account-binding file changed in this assignment.
No Home, labels, editor, sharing, clone, dependency or App edits.
Root approved the narrow AuthStore session-generation extension.
Workers leave changes unstaged. Root owns requirement commits.

## Contracts

`reports/contracts-c.md` contains callable B/D signatures.
B consumes `CloudProjectActions` for refresh, delete and cache.
D consumes `prepareSnapshot` and releases its payload lease.
Workspace export checks owner scope, not Home list membership.

## Requirement and hunk map

| Requirement | Files / symbols | Purpose |
| --- | --- | --- |
| R7 base | `models/cloud_project.dart`: scope/session/exception/activity | Stable origin/account identity and operation fences |
| R7 base | `models/project.dart`: cloudOrigin/cloudAccountId | Persist owner without adopting unowned old mirrors |
| R7 base | `app_paths.dart`: cloudProjectRoot | `projects/cloudProjects/<origin-hash>/<account-hash>/<cloud-id>` |
| R7 base | `cloud_cache_paths.dart` | Portable relative paths, collision and link rejection |
| R7 base | `cloud_cache_service.dart`: roots/owner/stage/manifest/baseline | Complete immutable snapshots separate from editor bytes |
| R7 base | `cloud_sync_service.dart`: open/capture/pull/push | Scoped sessions, no prune, preserve unsent local edits |
| R7 base | `api_client.dart`: scopedCloud/ScopedCloudApi and encoded ID paths | Capture token/origin and recheck account generation |
| R7 base | `project_store.dart`: scoped registration/merge/query | Keep same cloud ID independent across accounts |
| R7 base | `store/auth_store.dart`: sessionGeneration/load/refreshMe/updateProfile | Authoritative same-token A-B-A fence without invalidating profile updates |
| R7 tests | `cloud_auth_generation_test.dart` | Synchronous revision, stale load/401/profile and same-token A-B-A |
| R3 | `cloud_project_actions.dart`: deleteProject | Reuse cloudDeleteProject and distinguish server/local cleanup |
| R3 | `project_store.dart`: refresh tickets/deletedCloud/removeDeletedCloudProject/reconcile | Durable scoped deletion facts and awaited registry persistence after logout |
| R6 | `cloud_cache_service.dart`: prepareSnapshot | Fresh complete payload, lease/release and no partial fallback |
| R6 | `cloud_project_actions.dart`: prepareSnapshot | Auth-scoped convenience for Home/editor owners |
| R8 | `models/cloud_project.dart`: CloudCachePhase/CloudCacheStatus | Status/progress/count/bytes/time/error projection |
| R8 | `cloud_cache_service.dart`: status/inspect/update/clear/status.json | Observable manifest-derived status and safe clear |
| R8 | `cloud_project_actions.dart`: cache facade/listeners | B integration only, no C UI edits |

R7 is the service foundation for R3/R6/R8.
Root should split these symbol groups into requirement commits.
Some new files contain multiple groups and need partial staging.
R3 must follow R7 scoped identity helpers.
R6/R8 must follow R7 snapshot storage.
No stage, commit or push command has run.

## Implemented safety

- Origin/account keys use SHA-256, never a token or display name.
- Cloud IDs have a strict portable component format.
- Paths reject absolute names, traversal, backslashes, links and aliases.
- Duplicate case-folded paths and file/directory collisions fail closed.
- Every download uses an operation-owned stage.
- The file tree is re-read after downloads to detect concurrent changes.
- The complete manifest publishes only after every file succeeds.
- Prior immutable snapshots survive failed updates.
- Manifest loads validate hashes, bytes, count and extra payload files.
- Workspace and snapshot payloads are separate directories.
- Snapshot export never calls pullAll or prune.
- Pull no longer prunes remote-deleted local files.
- Pull preflights local differences before changing known clean files.
- Clear refuses editor activity, pending pushes, dirty bytes and export leases.
- Clear checks ownership and never calls the remote delete endpoint.
- Remote deletion preserves local cache and unsent edits.
- Remote failure preserves registry and cache.
- Successful deletion awaits registry write and reports cleanup failure separately.
- Refresh tickets and persisted scoped tombstones block stale result resurrection.
- Confirmed remote deletion finishes its exact local cleanup after account change.
- Complete refresh reconciles missing rows only in the captured account.
- Offline editor opening restores a validated snapshot without a remote pull.
- Local file changes and pending local deletions both block destructive updates.
- Auth session generation changes synchronously before login/logout/load awaits.
- Profile and points updates leave the session generation unchanged.
- Unknown-owner legacy mirrors stay untouched and are not rebound to a login.

## Static validation

Dart SDK: `3.11.5`, resolved OHOS SDK package configuration.
No pub get, dependency resolution or lockfile change by C.

- `dart format` on all 13 C-owned Dart files: passed.
- Targeted `dart analyze` on those 13 files: `No issues found!`.
- Consumer analysis: `archive_share_service.dart`, `home_page.dart`,
  `project_card.dart`, `project_dialogs.dart`, `editor_page.dart`:
  `No issues found!` (exit 0).
- `git diff --check`: exit 0.
  Git only warns that `cloud_sync_service.dart` uses LF in this CRLF checkout.
- `ste-lint-zh.py` on both C reports: zero hard violations.
- Final format verification: 13 files, zero changes.

Final reviewed entry points:

- `auth_store.dart:31`: sessionGeneration.
- `project_store.dart:636`: scoped merge and full-list reconciliation.
- `project_store.dart:721`: awaited exact-scope remote-deletion fact.
- `cloud_cache_service.dart:79`: manifest-backed inspect.
- `cloud_cache_service.dart:134`: fresh payload-only snapshot.
- `cloud_cache_service.dart:331`: owned safe clear.
- `cloud_project_actions.dart:140`: remote delete and cleanup result.

The 13 files are listed below.
No runtime tests, builds, services, devices or real cloud operations ran.

## Exact owned files

Modified:

- `lib/models/project.dart`.
- `lib/services/api_client.dart`.
- `lib/services/app_paths.dart`.
- `lib/services/cloud_sync_service.dart`.
- `lib/store/project_store.dart`.
- `lib/store/auth_store.dart` (root-approved revision extension).

New:

- `lib/models/cloud_project.dart`.
- `lib/services/cloud_cache_paths.dart`.
- `lib/services/cloud_cache_service.dart`.
- `lib/services/cloud_project_actions.dart`.
- `test/cloud_cache_service_test.dart`.
- `test/cloud_project_actions_test.dart`.
- `test/cloud_auth_generation_test.dart`.

Report files:

- `reports/contracts-c.md`.
- `reports/pi-c.md`.

## Regression sources

- `test/cloud_cache_service_test.dart`.
- `test/cloud_project_actions_test.dart`.
- `test/cloud_auth_generation_test.dart`.

Sources cover account/origin paths, binary complete snapshot, failed download,
restart status, unsafe paths, links, pending edits/deletions and safe clear.
Deferred DELETE sources cover logout, account switch and restart tombstones.
Refresh sources cover duplicate delete, stale lists and scoped reconciliation.
Auth sources cover same-token A-B-A, stale profile/401/load and points refresh.
They are written for cloud CI and have not executed locally.

## Gaps and integration notes

- API lists files only. Empty remote directories are not promised.
- Remote file tree has no server snapshot transaction.
  Before/after tree checks detect listed path/mtime changes.
- Legacy mirrors remain on disk. This change does not move active editor paths.
- Snapshot generations remain until explicit cache clear.
- Auth revision dependency is resolved in the approved narrow extension.
  `sessionGeneration` is public and used by cloud captures.
- B now passes scope and session on addCloudProject.
  The session fences queued registry publication.
  C did not edit Home.
- Native sharing and ZIP safety are D-owned.
- Home confirmation, labels and rendering are B-owned.
- D owns disposal of services that finish opening after editor unmount.
  C dispose is idempotent and releases editor activity after pull failure.
- Snapshots are application-private and immutable by convention.
  Hash validation detects external file changes when reopening a cache.
- Same path/mtime file rewrites cannot be detected by the server list API.
  Server version/hash/transaction support would be needed for stronger freshness.

## R7 reopened blocker: portable prefix aliases

Only these source files reopened after the first freeze:

- `lib/services/cloud_cache_service.dart`.
- `test/cloud_cache_service_test.dart`.

The earlier validator compared complete file names only.
It accepted `A/x.txt` together with `a/y.txt`.
Windows merges those parent directories and breaks manifest spelling.

R7 hunk map:

- `_tree` at line 398 validates the complete namespace before downloading.
- `_validatePortablePaths` at line 421 records every path prefix.
  Each folded prefix has one exact spelling and one file/directory type.
  Repeated directories with identical spelling remain valid.
  File aliases, directory aliases and file/directory collisions fail closed.
- `_readManifest` at line 487 validates all listed paths before payload reads.
  It reuses the same validator with the `manifest` error code.
- Regression sources at lines 210-286 cover five conflict shapes.
  Each runs in both insertion orders for remote trees and manifests.
  Remote cases assert zero file reads and no published manifest.
  Manifest cases assert namespace rejection before missing payload checks.
- The valid shared-prefix restart source begins at line 288.
  It expects three cached files and three bytes after manifest inspection.

Final reopened checks:

- `dart format`: both files formatted.
- Format verification: two files, zero changes, exit 0.
- Targeted `dart analyze`: `No issues found!`, exit 0.
- `git diff --check` on the two paths: exit 0.
- Both files are still untracked, so a separate whitespace scan checked them.
  Trailing whitespace findings: zero.
- Report document lint: zero hard violations.

No tests, builds, services, staging or commits ran for this correction.
No other product source or regression file reopened.
Public contracts and snapshot layout remain unchanged.

## Freeze

C source is complete and frozen after the final static pass.
No tests, builds, services, devices, staging, commits or pushes ran.
Root may now split R7/R3/R6/R8 symbol groups and review cloud CI gaps.
