# Git integration design

## Boundary

The gap lives in the core Git page, its desktop-only service, and missing plugin
operations. Extend these owners. Preserve the published remote computer and
thinking-stream features. Use `GitBackend` for local projects. Select CLI on
Windows/macOS/Linux and native FFI on Android/iOS/OHOS. Cloud projects retain the
server Git route and Studio login. Never run native Git on a cloud cache.
Native initialization is lazy. Unsupported platforms fail explicitly.

## Frozen local contract

Pi B owns models in `lib/git/git_models.dart`, interface/factory in
`lib/git/git_backend.dart`, and adapters in `lib/git/*_git_backend.dart`.
Pi C consumes these signatures. Types use default constructors with named parameters. Failures throw
`GitOperationException(String message, {String kind = 'operation'})`.

```dart
enum GitBackendKind { cli, native }
enum GitChangeArea { worktree, staged }
enum GitMergeResult { upToDate, fastForward, merged, conflicts }
// GitIdentity: String name, email
// GitCredentials: String username, token (never stringify secrets)
// GitChange: String path; bool staged, unstaged, untracked, conflict;
//            String? oldPath
// GitBranchInfo: String name; bool current, remote; String? upstream
// GitRemoteInfo: String name, url
// GitCommitInfo: String oid, message, authorName, authorEmail; DateTime time
// GitDiffData: String patch; bool binary, truncated
// GitSnapshot: bool isRepository; String? branch, oid;
//              String state; List<GitChange> changes;
//              List<GitBranchInfo> branches; List<GitRemoteInfo> remotes;
//              List<String> conflicts
abstract class GitBackend {
  String get root;
  GitBackendKind get kind;
  Future<GitSnapshot> snapshot();
  Future<void> init();
  Future<void> stage(List<String> paths);
  Future<void> unstage(List<String> paths);
  Future<void> stageAll();
  Future<GitDiffData> diff(String path, {required GitChangeArea area});
  Future<List<GitCommitInfo>> history({int limit = 20});
  Future<String> commit(String message, GitIdentity identity);
  Future<void> createBranch(String name);
  Future<void> checkout(String name);
  Future<GitMergeResult> merge(String ref, GitIdentity identity);
  Future<String> completeMerge(String message, GitIdentity identity);
  Future<void> setRemote(String name, String url);
  Future<void> fetch({String remote = 'origin', GitCredentials? credentials});
  Future<void> push({String remote = 'origin', GitCredentials? credentials});
  Future<void> pullRebase(); // CLI only.
  void cancelNetwork();
  Future<void> dispose();
}
// GitBackendFactory.open(String root) -> GitBackend (no native work yet)
// GitBackendFactory.clone({required String url, required String path,
//   GitCredentials? credentials, GitCloneCancellation? cancellation})
//   -> Future<void>. GitCloneCancellation exposes cancel() and dispose().
```

`staged` names the index-side diff. Dart enums already expose an instance
`index` property, so an enum value cannot use that name.

`GitBackendFactory.open` is synchronous. `GitCloneCancellation` is declared in
git_backend.dart, has a default no-argument constructor, and does no native work
until the chosen adapter uses it. The factory exports git_models.dart for callers.
Model constructors are const. Required named parameters: identity name/email,
credentials username/token, change path, branch name, remote name/url, commit
oid/message/authorName/authorEmail/time. Optional flags default false, nullable
fields default null. GitDiffData.patch defaults to ''. GitSnapshot.isRepository
is required, state defaults to 'clean', lists default const [], nullable fields
default null. Plugin model constructors follow the same field/default rules.

Optional injectable dependencies are allowed for meaningful tests. Report
contract changes in `reports/contract-change.md` before altering other owners'
callers. The coordinator resolves implementation details without another approval.

Non-repository snapshots return `isRepository=false`. Unborn repositories are
still repositories. Bound history, diff and output. Preserve combined index and
worktree flags. Label binary and truncated patches. Handle rename, deletion,
Unicode and empty HEAD. Serialize mutations by physical root across instances.
Validate exact paths, avoid shell interpolation and wildcard pathspec expansion.
Cancel tokens/handles live until actual completion. Use existing CLI process
ownership. Never terminate unrelated processes.

## Plugin contract

Pi A owns C header/source, Dart bindings/repository/public exports and plugin
fixtures. Preserve old methods. Add these GitRepository methods and public types:

```dart
// GitBranch: name, current, remote, upstream (nullable)
// GitRemote: name, url
// GitCommit: oid, message, authorName, authorEmail, time (DateTime)
// GitDiff: patch, binary, truncated
Future<void> stagePaths(List<String> paths);
Future<void> unstagePaths(List<String> paths);
Future<GitDiff> diff({String? path, bool staged = false, int maxBytes = 262144});
Future<List<GitCommit>> log({int limit = 20});
Future<List<GitBranch>> branches();
Future<List<GitRemote>> remotes();
Future<void> setRemote(String name, String url);
```

Use existing isolate, ownership, UTF-8 and error conventions. Update native/Dart
API version together. Validate it before new symbol lookup, so stale binaries
fail clearly. Pi A publishes exact C symbols in `reports/pi-a-api.md` early.
Pi D owns CI export requirements. Build every new native binary in cloud only.

Native fetch and merge are distinct visible actions. Select a remote tracking
branch after fetch. Do not call merge rebase. Desktop retains pull --rebase and
credential helper/SSH behavior. Push uses explicit current-branch refspecs without
force. Detached/unborn HEAD must fail clearly. Init users can configure origin.

## UI and editor

Pi C owns `lib/pages/git_page.dart`, `lib/pages/git/`,
`lib/store/git_page_controller.dart`, `lib/editor/editor_page.dart`, Home clone
entry, `lib/services/git_clone_service.dart`, and corresponding UI tests.
GitPage stays the public route and retains cloud behavior. New per-file staging,
diff and branch features apply to local repositories only. The existing cloud
API lacks those operations: retain its existing addAll/commit flow and label it
explicitly. Do not extend server endpoints or pretend cloud index-only support.
Display captured
project/path, branch and repository state. Group staged and unstaged changes.
Offer diff, stage, unstage, index-only commit, history, branches and remotes.
Conflict files and completion of a resolved merge are real operations.

Capture active document owner before awaits. Use primary project only when no
document is open. Reject orphaned owners. Keep target immutable through dialogs.
Before checkout/merge/pull, require affected dirty buffers to be resolved. Reload
only clean buffers after disk changes, refresh tree, preserve workspace membership.
Optional GitPage arguments `backend`, `beforeWorktreeChange`, `onWorktreeChanged`
may support injection and editor callbacks. Pi C owns both ends.

Use mounted/generation guards and try/finally. Reject duplicate mutations.
Expose cancellation for clone/fetch/push. Disposal must not report success early.
Clone reserves a new AppPaths destination and registers with ProjectStore only
after success. Clean only operation-owned data. Preserve recoverable clone data
when registration fails unless ownership-safe rollback is certain. Registration
may create `.qfli` metadata, which is never silently staged or ignored.

Author identity and Git host credentials are separate. Mask tokens and keep them
in memory. Never put them in URLs, Git config, process arguments, auth.json or logs.
Reject embedded native URL credentials. Retain TLS/CA validation. Apply offline
network policy at native request boundaries. Do not enable Git in previously
offline-only navigation as an incidental change.

## Dependency and release

Pi B may create ignored core `pubspec_overrides.yaml` for sibling plugin analysis.
Pi D owns tracked manifests and lockfiles. Final core dependency pins a full
reviewed Git commit containing matching cloud-built binaries. App CI pins the
resulting core commit and unchanged Java commit. No machine-local paths in commits.

The root coordinator pushes plugin source, observes native CI, imports matching
artifacts with checksums, commits artifact revision, pins core, then pushes app.
In the first plugin source run, native jobs build new libraries before FFI/mobile
checks. Dependent jobs download artifacts from that exact source run and install
them in the job workspace. Never test new Dart bindings against old checked-in
libraries or require a release import before source CI can pass.
Prepare a fresh `v5.0.5-git.1` preview after checking tag availability. Preserve
remote.* release support and all eleven installer targets plus Windows assistant.
Never overwrite tags, force push, or tag CNB. Rollback uses new commits/tags.
