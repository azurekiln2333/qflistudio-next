# Design and ownership
## Authorization and roots
User explicitly requested immediate planning, dispatch/re-dispatch to four existing Herdr Pi workers, and one commit per requirement. This overrides the local skill's additional planning approval gate. Implement now.
Plan root: D:/MyNewProjects/qflistudio
Core: D:/MyNewProjects/_wt/studio-git-integration/qfli_studio_core
App: D:/MyNewProjects/_wt/studio-git-integration/qflistudio
Core base: c619f9ff0e83341f4efb548ea58eb7af42a9f51f
App base: 1cea02946e5191f2a76bd8915ff0a527547f0463
Both roots were clean. Root app resolves older Core without clone. Reuse shipped clone worktree; do not rebuild the pipeline or incidentally change root overrides. Preserve remote-account-binding worktrees.

## R1 GitHub
Default OAuth device flow with public QFLI_GITHUB_CLIENT_ID build configuration, PAT alternative. Verify current official GitHub docs before coding. Handle pending, slow_down, denial, expiry, cancel and timeout. Never ship a client secret. Missing registered OAuth app/device-flow configuration is a documented release dependency, not a coding blocker.
Use /user identity and all /user/repos pages (100/page); validate pagination origin. Fine-grained PAT shows granted repository set. Use platform secure credentials separately from auth.json. No token in URL/log/UI serialization. Unavailable persistence must be reported, never plaintext fallback. Disconnect/account switch invalidate stale requests/selection. Existing GitCredentials owns clone auth.

## R2 Clone location
GitCloneService exclusive allocator parent becomes AppPaths.projectsRoot()/gitProjects. Preserve createTemp ownership, safe names, progress/cancellation, registration and registration-failure preservation. No existing-directory migration.

## R3 Cloud deletion
Reuse ApiClient.cloudDeleteProject. Home currently calls ProjectStore.deleteProject which rejects cloud. Distinct permanent remote deletion confirmation, never local recycle-bin promise. Block duplicate delete. Failure retains card/cache. Success awaits registry persistence. Invalidate stale list results to prevent resurrection. Account changes invalidate scoped mutations. Report cleanup failure separately from remote deletion success.

## R7 cache and R8 state
Canonical projects/cloudProjects/<origin-key>/<account-key>/<cloud-id>/ below configured projects root. IDs must be safe and stable, never display names/tokens. Preserve old mirrors and pending local edits; adopt old data non-destructively, never move/delete active editor data. Cache is not a duplicate local project.
Reuse cloudFileTree and cloudReadFile Base64 binary data. Validate paths against traversal/absolute paths/link escape. Stage under operation-owned scoped directory. Publish complete manifest only after all downloads succeed. Retain last complete snapshot on refresh failure. Do not blindly use pullAll/prune for sharing over unsent edits. Coordinate project mutations/editor sync; return recoverable conflict if needed.
Clearing checks ownership/active writes; never remote deletion. Metadata stays outside exported payload.
One observable service: notCached, caching, cached, failed; completed/total files, bytes, last successful time, last error. Folder existence is not completeness. Derive restart state from manifest/data. Cached does not guarantee remote freshness. B renders status and cache/update/clear. Invalidate scope on account change.

## R4/R5/R6 sharing
FileExplorer long-press/context menu ZIP shares selected file/folder. Use _ownerOf(node.path) for multi-root. Editor injects callback; tokens do not enter tree state. Reuse ProjectZipService safety/off-UI compression. Preserve binary/relative paths. Existing .qsz stays import-compatible; share .zip/application/zip. Exclude cache metadata/unselected parent data; reject escaping links.
Home export/share works for local/cloud. C supplies complete scoped cloud snapshot first. Partial download never launches sharing. API only lists files; do not promise empty remote directories.
Use native file-sharing APIs, not text sharing. Retain ZIP while receivers may read it; do not delete just after opening sheet. Unsupported native share returns accurate result and save/export fallback.

## Ownership
A w37:pC: lib/github/**, GitHub service tests, Core pubspec/lock.
B w37:pG: home_page.dart, pages/git/github*, project_card, project_dialogs, i18n, git_clone_service, Home/clone UI tests.
C w37:pH: cloud_sync_service, new cloud cache/actions/models, project_store, app_paths, scoped api_client, cloud tests.
D w37:pJ: share_service, project_zip_service, archive sharing service, file_explorer/editor_page, Core native Android, App native files/App manifests, share tests.
B alone owns Home/labels. A alone owns Core dependencies. D alone owns App native code; A coordinates native browser/secure storage needs with D. A/C/D publish exact signatures in reports/contracts-{a,c,d}.md early for B. No overlapping edits.

## Commits
Root serializes index mutations. Workers leave unstaged changes and requirement/file/hunk maps. Separate commits R1 GitHub, R2 gitProjects, R3 cloud delete, R4 file-tree share, R5 Home local share, R6 cloud share, R7 cache, R8 cache status. Cross-repo work may need one matching R-number commit per repo. No mixed requirements. Remote task stays separate. No push/release/deployment implied.
