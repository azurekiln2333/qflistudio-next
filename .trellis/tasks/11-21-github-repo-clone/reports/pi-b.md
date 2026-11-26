# Pi B implementation report

Task: `11-21-github-repo-clone`.
Core: `D:/MyNewProjects/_wt/studio-git-integration/qfli_studio_core`.
App: no B edits.
Remote-account-binding worktrees: untouched.

## Scope and result

B implements UI and clone allocation only. A owns GitHub HTTP/authentication and
credentials. C owns cloud/store/cache operations. D owns ZIP/native sharing.
B consumes `contracts-a.md`, `contracts-c.md`, and the updated D signature.

- R1: added a Home GitHub entry and repository picker. OAuth is the default.
  PAT remains explicit and obscured. Browser authorization uses the existing
  `RunnerService.openUrl`. The code and URL remain selectable. Repository pages
  accumulate through A's controller. Selection uses repository IDs. Multiple
  selected requests feed the existing independent Home clone tasks. The URL
  clone dialog, progress, cancellation and registration pipeline remain intact.
- R2: the default exclusive allocator now reserves children of
  `AppPaths.projectsRoot()/gitProjects`. Existing paths do not move. The safe
  prefix uses the sanitized segment. `Directory.createTemp` retains ownership.
  Root committed these two files as `16a6a47`. B has not written either file
  since acknowledging the R2 freeze.
- R3: Home uses `CloudProjectActions.refresh` and its current-account project
  projection. Home no longer independently fetches/merges cloud lists. Cloud
  delete has a permanent-server-deletion confirmation and a duplicate-action
  guard. Failed remote deletion leaves the card/cache to C. Remote success with
  local cleanup failure gets different feedback. Local recycle deletion stays.
- R5: added ZIP export/share beside the existing `.qsz` export. OS handoff is not
  claimed as recipient delivery. Unsupported sharing offers saving the exact
  retained ZIP. Save cancellation does not remove the ZIP or source project.
- R6: the same Home action passes captured token/account ID and the existing
  cloud facade to D. D captures C's snapshot before filesystem awaits and checks
  its generation before native handoff. Home also fences later UI/save fallback.
- R7 UI adapter: cloud creation passes captured `CloudProjectScope` and session
  into `CloudSyncService` and `ProjectStore.addCloudProject`. Path/cache storage
  implementation remains C-owned. Unowned legacy rows remain in the registry
  but are not reassigned or rendered as the current account's cloud projects.
- R8: cards show notCached/caching/cached/failed, snapshot time, file count and
  bytes. Download progress uses measured file counts only. Cache/update/clear
  remain distinct from remote delete. The clear dialog says remote data stays.
  Initial display inspects complete manifests rather than directory existence.
  Grid height accounts for the extra rows. Cloud cards hide local file-manager
  reveal because their working directory may not exist yet.

## B files

Production:

- `lib/pages/git/github_repository_picker.dart` (new, R1).
- `lib/pages/home_page.dart` (R1/R3/R5/R6/R7-adapter/R8).
- `lib/widgets/project_card.dart` (R3/R5/R6/R8).
- `lib/widgets/project_dialogs.dart` (R3/R8).
- `lib/i18n/studio_localizations.dart` (R1/R3/R5/R6/R8 labels).
- `lib/services/git_clone_service.dart` (R2, frozen for root).

Regression sources:

- `test/git_clone_destination_test.dart` (new, R2, frozen).
- `test/github_repository_picker_test.dart` (new, four R1 widget cases).
- `test/project_card_cloud_actions_test.dart` (new, five R3/R6/R8 widget cases).
- `test/home_search_archive_test.dart` (three new R5 cases, existing export kept).
- `test/home_project_scope_test.dart` (R3/R7 isolation expectation updates).

Coordination: `reports/contracts-b.md` and this report.
No dependency, cloud implementation, store, editor, native or App files changed
by B. Shared worktree status also contains other workers' files.

## Requirement / hunk map for root

Do not stage whole shared UI files as a single requirement. Split additions by
these symbol/comment anchors. Nearby import/constructor/enum edits may need an
edited patch, because Git combines adjacent additions into one displayed hunk.
B has not staged or committed anything.

| Requirement | Files and hunk anchors |
| --- | --- |
| R1 | Full new picker and picker test. Home: picker import, `github_repositories` menu dispatch/item, `_cloneGitHubRepositories`, and extracting the existing clone body to `_runCloneRequest`. Labels: block `// R1` through `refresh`. |
| R2 | Already committed by root as `16a6a47`: allocator hunk and full `git_clone_destination_test.dart`. Both remain frozen. |
| R3 | Home: `CloudProjectActions` import/lifetime, auth generation and deletion guard fields, `_projectsFor` scoped projection, `_reloadProjects` replacing independent cloud merge, `_deleteProject` cloud dispatch, `_deleteCloudProject`, card `cloudBusy`. Dialog: `showDeleteCloudProjectConfirm`. Card: remove enabled guard. Labels: `// R3` block, including `cloudDeleteSucceeded` with no local recovery promise. Scope test: signed-out cloud rows hidden. |
| R5 | Home: `ArchiveShareService` import, `_shareProject` local branch and retained-ZIP save fallback, local card `onShare`. Card: `share` enum/callback/menu, share-aware directory check. Labels: `// R5/R6` block except cloud-preparation line. Three Home archive share tests. Preserve `.qsz` code. |
| R6 | Home: cloud branch of `_shareProject`, captured token/account ID/facade, cloud card share availability. Card: cloud share menu available without local directory. Labels: `preparingCloudShare`. Cloud card share test. Depends on C/D service commits. |
| R7 | Home creation: captured scope/session, scope/session arguments for create/open and registry registration, live-generation/token/account checks after registration and other awaits. This is only the consumer adapter to C's path/ownership change. |
| R8 | Home: `_inspectCloudCaches`, cache listener/rendering, grid extent adjustment, `cacheStatus/onCache/onClearCache`, `_cacheProject`, `_clearProjectCache`. Card: cache fields/actions and `_CloudCacheSummary`. Dialog: `showClearCloudCacheConfirm`. Labels: `// R8` block. Cloud metadata/action widget tests. |

Shared helpers/imports should first enter the earliest dependent requirement.
R3 establishes cloud facade lifetime/scoped projection. R6/R8 then consume it.
R5 establishes the share callback/result/fallback. R6 enables cloud behavior.
R3/R7 legacy isolation is one shared expectation change, not duplicate hunks.
No per-requirement commit has been made by B. Root owns serial index updates.

### Approved review delta after the first freeze

Only Home, labels and this report were reopened for the approved fixes.
All other B UI files and the committed R2 files remain unchanged.

- R3 label hunk: add `StudioLocalizations.cloudDeleteSucceeded(name)` in all three
  locales. `_deleteCloudProject` uses it only on successful remote deletion.
  Local `_deleteProject` keeps `deletedProject`, including its recycle behavior.
- Shared R3 auth-fence hunk: `_accountGeneration` becomes the immutable record
  `(home: _homeGeneration, session: widget.auth.sessionGeneration)`. Every existing
  Home cloud fence now reads the live AuthStore revision, including before its
  delayed persistence notification. A-B-A with the same token/account cannot
  revive an older operation. Local Home epoch also invalidates widget replacement
  and disposal. `_onAuthChanged` observes the revision as well as identity/token.
  C owns the new AuthStore getter and its mutation sites, not B.
- R7 registration hunk: `ProjectStore.addCloudProject` receives both `scope` and
  the captured `session`. After registration, Home rechecks live generation,
  token and account before reporting success or emitting activity events.
- R6/R8 have no new feature hunks in this delta. Their pre-existing generation
  comparisons consume the shared live fence. Stage the helper with R3 before
  its later R6/R8 consumers. R3 now depends on C's session-generation addition.

## Latest approved review checks

This section supersedes the earlier static snapshot for Home and labels.
Only the two approved production files and this report changed in this delta.
No tests or other production files were edited. R2 commit `16a6a47` stays intact.

```powershell
& D:/ProgramFiles/flutter_ohos/bin/cache/dart-sdk/bin/dart.exe format --output=none --set-exit-if-changed lib/pages/home_page.dart lib/i18n/studio_localizations.dart
```

Final result at 2026-11-21 23:18 +08:00:
`Formatted 2 files (0 changed)`, exit 0.

```powershell
& D:/ProgramFiles/flutter_ohos/bin/cache/dart-sdk/bin/dart.exe analyze lib/pages/home_page.dart lib/i18n/studio_localizations.dart
```

Final result at 2026-11-21 23:18 +08:00: `No issues found!`, exit 0.
C published the contracted getter before this final run. This supersedes the
23:13 dependency-only failure while the getter was not yet present. B made no
AuthStore edits and added no token/account fallback.

The full targeted UI/regression-source analysis command recorded below was also
rerun at 23:18 +08:00 and returned `No issues found!`, exit 0. Tests were not run.

```powershell
git diff --check -- lib/pages/home_page.dart lib/i18n/studio_localizations.dart
```

Final result at 23:18 +08:00: exit 0. Full `git diff --check` also returned
exit 0 with only Git's pre-existing cloud-sync line-ending notice.
Report lint returned zero findings, exit 0.

B's code is frozen again. Root may stage the approved R3 and R7 additions using
the updated symbol-based hunk map. No further edits without explicit findings.

## Earlier static checks actually run

SDK: `D:/ProgramFiles/flutter_ohos/bin/cache/dart-sdk/bin/dart.exe`.
Working directory for commands below is the Core root.

```powershell
& D:/ProgramFiles/flutter_ohos/bin/cache/dart-sdk/bin/dart.exe analyze lib/pages/home_page.dart lib/pages/git/github_repository_picker.dart lib/widgets/project_card.dart lib/widgets/project_dialogs.dart lib/i18n/studio_localizations.dart test/github_repository_picker_test.dart test/project_card_cloud_actions_test.dart test/home_project_scope_test.dart test/home_search_archive_test.dart test/home_fab_scope_test.dart test/home_project_tabs_widget_test.dart test/home_git_clone_tasks_test.dart test/project_card_git_test.dart
```

Final targeted result at 2026-11-21 22:49 +08:00: `No issues found!`, exit 0.
Earlier independent analysis also included frozen R2 service/test and reported
`No issues found!`. No post-freeze formatting write targeted either R2 file.

Final no-write format verification, 2026-11-21 22:49 +08:00:

```powershell
& D:/ProgramFiles/flutter_ohos/bin/cache/dart-sdk/bin/dart.exe format --output=none --set-exit-if-changed lib/pages/home_page.dart lib/pages/git/github_repository_picker.dart lib/widgets/project_card.dart lib/widgets/project_dialogs.dart lib/i18n/studio_localizations.dart test/github_repository_picker_test.dart test/project_card_cloud_actions_test.dart test/home_project_scope_test.dart test/home_search_archive_test.dart
```

Result: `Formatted 9 files (0 changed)`, exit 0.

```powershell
git diff --check
```

Result: exit 0. Git prints its existing LF-to-CRLF working-copy notice for the
C-owned cloud sync source. It reports no whitespace errors.

```powershell
& D:/ProgramFiles/flutter_ohos/bin/cache/dart-sdk/bin/dart.exe analyze lib
```

Final full-library result at 2026-11-21 22:50 +08:00: no errors, exit 0. One
existing informational lint remains in `chat/composer_card.dart:313`
(`curly_braces_in_flow_control_structures`). This supersedes the earlier shared
WIP check: C fixed its nullable scope error and D fixed its async-context lint.
B did not edit any of those files.

From the planning root:

```powershell
python D:/MyNewProjects/qflistudio/scripts/ste-lint-zh.py D:/MyNewProjects/qflistudio/.trellis/tasks/11-21-github-repo-clone/reports/pi-b.md
```

Result: zero findings, exit 0.

## Regression sources, not runtime results

- R1: default OAuth, obscured PAT, paging plus two selected clone requests,
  disconnect clearing selection, narrow/large text and keyboard viewport.
- R2: real default allocator parent, exclusive destinations for overlapping
  clones, preserved pre-existing sibling data.
- R3/R8: permanent remote delete versus cache clear confirmations, busy menu
  guards, distinct update/clear/delete callbacks, four states and metadata.
- R5: real Home ZIP handoff, retained ZIP save fallback, dismissed unsupported
  share preserves both source and output. Existing `.qsz` tests remain.
- R6: cloud card offers sharing even without a local working directory.
- R7: signed-out users cannot inherit an unowned registry cloud row.
- Existing Home tab/FAB/clone progress/branch-card tests were statically analyzed.

No test, clone, real deletion, browser auth, native sheet, build, service,
emulator or device command ran locally. Cloud CI must execute these sources.

## Documentation-only closeout

Applied the `trellis-update-spec` skill after reviewing the existing frontend
index, `project-storage.md`, `home-recovery.md`, `authentication.md`, repository
layout and the frozen C/D source contracts. Added:

- `.trellis/spec/frontend/cloud-project-cache.md` in the planning root.
- One precise frontend index row marked `Active (frozen integration source)`.

The new seven-section guide explicitly names studio-git-integration Core as its
source authority. It does not claim the root App has released these contracts.
It records actual C/D signatures, scope/path ownership, authoritative
`AuthStore.sessionGeneration` fencing, durable deletion and cleanup failures,
immutable complete snapshots versus mutable workspace, dirty/active/push/lease
clear guards, every-prefix portable path validation, cache status and ZIP payload
boundaries. It references existing local storage/recovery specs without repeating
their local metadata or recycle-bin rules.

Checks actually run at 2026-11-22 00:00 +08:00:

```powershell
python D:/MyNewProjects/qflistudio/scripts/ste-lint-zh.py D:/MyNewProjects/qflistudio/.trellis/spec/frontend/cloud-project-cache.md
```

Result: zero findings, exit 0. A read-only structural check verified exactly seven
numbered sections, all local spec links and one exact index entry.
`git diff --check` on the two spec paths returned exit 0, with only Git's existing
line-ending notice for the frontend index.

A read-only SHA-256 check confirmed all nine frozen B Core source files and all
26 cumulative staging copies still match their recorded hashes. This closeout
changed only the new spec, its documentation index row and this report. No
product edits, staging-bundle changes, Git-index writes, tests, builds, commits,
pushes or commit-ledger edits occurred.

## Remaining validation / release dependencies

- OAuth needs a registered GitHub OAuth App with device flow enabled and public
  `QFLI_GITHUB_CLIENT_ID` in the release configuration. No client secret ships.
- Platform secure-vault availability is A/D-owned. Failure must remain explicit,
  not a plaintext fallback. Verify plugin registration in cloud builds.
- Native file-sharing behavior and receiver lifetime need cloud/device coverage.
- C owns deletion/list races, snapshot completeness and unsent-edit safety tests.
- D owns ZIP selection/path safety, account-switch-before-share and native tests.
- No commits, staging or push by B. Root serializes one requirement per commit.
