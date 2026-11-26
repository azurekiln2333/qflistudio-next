# Studio Git integration research

## Scope and inspected revisions

This is an integration plan based on source inspection on 2026-11-20. It is not
an implementation or device acceptance report. No local tests or builds ran.

| Repository | Inspected checkout | HEAD |
| --- | --- | --- |
| Core | `D:/MyNewProjects/_wt/release-v5.0.5/qfli_studio_core` | `72c0b0955e4ddd5215dc818327fa5a67a4be22f7` |
| App | `D:/MyNewProjects/_wt/release-v5.0.5/qflistudio` | `6d1b96d7118740f71e5dadf393cc8bd58238b6af` |
| Plugin | `D:/MyNewProjects/qfli_git` | `95cb99b538422de18e9a6dca906791f67294452e` |

The original CloudTerminal checkout is outside this task. No product source was
changed during this research. Paths below are relative to the named repository.
Line references describe these revisions and may move during implementation.

## Current behavior and integration boundary

Core `lib/services/git_service.dart:8` is a static desktop CLI wrapper. Its
platform gate at line 9 accepts Windows, macOS and Linux. It probes `where` or
`which` at line 12 and runs Git with the project working directory at line 22.
There is no backend interface, cancellation, timeout or per-repository queue.
`GitResult` at line 4 is a stdout/stderr/exit-code record.

Core `lib/pages/git_page.dart:14` receives a Project and AuthStore. It selects
the cloud path from `project.isCloud` at line 31. The existing page exposes
commit, status, history, remote configuration, push, pull and local init at
lines 233-286. It displays text output, not a typed repository model. Local
mobile projects are rejected at lines 195-218. The core and app manifests do
not currently depend on qfli_git.

Desktop behavior must remain intact: `GitService.pull` at line 59 invokes
`pull --rebase`; push at line 57 uses `push -u origin HEAD`. Native fetch plus
merge must not silently replace desktop rebase. Desktop credential-manager and
SSH support must continue through the installed Git client.

Cloud Git is a separate server operation. Core
`lib/services/cloud_sync_service.dart:276` calls
`lib/services/api_client.dart:1562`, which posts an action, optional message and
optional URL to `/api/cloud/projects/$id/git`. Preserve this path and its Studio
login requirement. Do not run the local native plugin on a cloud cache.

## Plugin capability matrix

Plugin `pubspec.yaml:27` declares Android, iOS and OHOS FFI targets.
`lib/src/library.dart:26` selects the native library. Desktop loads fail without
the test override. Use native Git only on declared mobile targets, with lazy
initialization on first use. `QfliGit.ensureInitialized` at
`lib/src/repository.dart:305` installs the CA asset and initializes the library.

| Capability | Existing desktop/cloud UI | Native API at inspected plugin HEAD | Integration rule |
| --- | --- | --- | --- |
| Init | Desktop | `init`, line 433 | Available for local projects. |
| Status | Both | `status`, line 631; `head`, line 646 | Preserve combined index/worktree flags. |
| Stage and commit | Both | `addAll`, line 475; `commit`, line 486 | Require author identity for native commits; stop after staging failure. |
| History | Both | Missing | Add a bounded plugin API or capability-gate mobile history. |
| Remote configuration | Both | Missing | Add a native/Dart API or gate it; never edit `.git/config` in the UI. |
| Push | Both | `push`, line 694 | Requires an explicit refspec; handle detached and unborn HEAD. |
| Pull with rebase | Desktop | Missing | Preserve desktop command; expose fetch/merge as distinct mobile operations. |
| Fetch | No separate button | `fetch`, line 661 | Uses an existing named remote. |
| Clone | No Home entry | static `clone`, line 374 | Add a separate clone-and-register flow. |
| Branch create/checkout | No existing UI | lines 513 and 533 | Explicit branch name is supported; enumeration is missing. |
| Merge/conflicts | No existing UI | lines 555, 588 and 604 | Display merge outcome and conflicts; never report conflicts as success. |
| Diff, branch enumeration, upstream configuration | No existing page implementation | Missing | Defer or extend the plugin explicitly. |

The native header also lacks remote configuration. Fetch/push resolve an
existing remote in `native/src/qfli_git.c:429` and line 456. Clone creates a
usable origin, so clone-based mobile workflows can work without pretending
that arbitrary initialized repositories already have a remote.

`GitStatusEntry.statusBits` at plugin `lib/src/repository.dart:58` preserves
combined status flags. `GitHead` at line 100 reports detached HEAD using a null
branch. `MergeOutcome` at line 27 distinguishes up-to-date, fast-forward, merge
and conflicts. `GitException` at line 135 exposes cancellation and conflict
classification. Map these into typed core models instead of parsing messages.

`QfliGit.open` at line 472 creates a descriptor; it does not validate a repository
immediately. Probe head/status before showing an opened repository as ready.
Operations run in isolates and release their native repository handles per call.
There is no repository close method to invent in the adapter.

## Minimum backend contract

Introduce an instance-based `GitBackend` selected for a captured Project/root:

1. Cloud project: `CloudGitBackend` with the existing server contract.
2. Local desktop: `CliGitBackend` with current command semantics.
3. Local Android/iOS/OHOS: `NativeGitBackend` using qfli_git.
4. Other platforms: explicit unsupported state.

Keep the interface operation-specific. Do not dispatch arbitrary CLI argument
lists through the native adapter. A practical first contract contains backend
kind, capabilities, repository snapshot/status, init, stage-all, commit,
history, remote configuration, push, and clearly separate synchronization
methods such as desktop pull-rebase and native fetch/merge. Methods unsupported
by a backend must not produce enabled controls. Add branch/conflict operations
only when their UI and acceptance criteria are included in the task.

Keep the existing text result adapter for the output pane. Add typed state for
branch/head, status, conflicts and errors where the UI must make decisions.
The backend contract owner must freeze signatures before UI and navigation
workers implement callers. Avoid a large speculative API for future features.

One controller should own busy state, current operation, cancellation and
disposal. Use `try/finally` and mounted/generation checks around awaited work.
The current `_runLocal` at core `lib/pages/git_page.dart:54` can leave busy state
set after an exception and update a disposed page. `_runCloud` at line 70 also
lacks post-await mounted checks. The commit dialog at line 105 starts commit
even when staging fails. Stage and commit must be one serialized intent with
an explicit stage-all description and failure short-circuiting.

Serialize mutations by normalized physical repository root, including requests
from multiple page instances. Capture the root and operation identity before
dialogs or awaits. Never reroute an in-flight operation when the active tab
changes. For native network operations, use plugin `CancelToken` at line 167
and retain it until completion. For long desktop commands, use the established
ProcessSupervisor contract rather than adding more unowned `Process.run` calls.

## Navigation and editor ownership

Core `lib/editor/editor_page.dart:1120` currently opens Git for `widget.project`,
which is the primary project even when the active file belongs to another root.
Follow `_runProject` at line 2163: capture the active document, reject an orphan
and resolve `projectRootPath` plus owner name before awaiting. When no document
is active, use an explicitly defined primary-project fallback. Show the selected
project in the Git page so the target remains visible.

Checkout, merge and pull can change files under open buffers. Integrate the
existing owner-specific dirty guard at `editor_page.dart:2736` before those
operations. Block unsafe changes until the user resolves affected dirty buffers.
After successful disk changes, refresh the explorer through `_treeRefresh`
(`editor_page.dart:3844`) and reload clean buffers through
`lib/editor/editor_controller.dart:275`. Do not force-reload dirty documents.
Preserve saved-workspace membership and retained editor identity.

Core `lib/editor/editor_quick_bar.dart:414` hides Git under `!offlineOnly`.
`test/offline_editor_gates_test.dart:67` covers this policy. Preserve that scope
for this main-app task. A future local-only Git feature in offline products
requires an explicit product decision. The existing API network gate does not
intercept native FFI networking, so clone/fetch/push/pull also need a backend
request-boundary offline check.

## Clone and project registration

Core Home has archive import, existing-folder registration and create-project
actions at `lib/pages/home_page.dart:477`, line 501 and line 525. It has no clone
entry. Add clone as a separate coordinator, not a special case inside GitPage.

Use `lib/services/app_paths.dart:96` and line 127 for the private projects root
and collision-safe destination selection. Reserve ownership of a new destination
and never clone over an existing user directory. Cleanup after cancellation or
failure must remove only the directory created by this operation. Register only
after clone succeeds. Handle registry failure as part of the same owned flow.

`lib/store/project_store.dart:438` implements `addExisting`. It validates the
directory, detects language, writes `.qfli/project.json` and registers the
project. `_registerLocalProject` at line 199 contains persistence rollback.
Reusing registration can add an untracked metadata file to the clone. Document
that behavior and do not silently commit it or change repository ignore rules.
The archive import flow at line 397 provides an existing ownership/cleanup model.

## Identity and credentials

Core `lib/store/auth_store.dart:14` persists Studio account authentication in
`auth.json`; its service token is not a Git host token. Never reuse it for Git
or store a PAT in that file. Native author name/email and host authentication
are distinct inputs. The minimum credential design is operation-scoped in-memory
username/token input. Persist non-secret author identity separately if needed.

Plugin `native/src/qfli_git.c:225` implements credentials with username/token.
Missing tokens fail at line 235; retry loops are bounded at line 238. There is
no SSH key configuration API. Expose HTTPS repository URLs for native workflows,
reject embedded credentials and redact secrets from output and exceptions.
Do not place PATs in command arguments or remote URLs. Desktop retains its
existing Git credential transport.

## Dependency and native artifact provenance

Pin the reviewed full Dart package commit. The inspected plugin reports package
version `0.1.0`, while `native_libs.lock.json` identifies native release
`native-v0.1.1` and native source
`85406ecf4e299c4ca0606b3b70540ca386dad6f0`. These are different identities and
must be recorded separately. The native lock lists libgit2 1.9.7, mbedTLS 3.6.8
and CA bundle 2026-11-05.

Tracked native `.so` and XCFramework artifacts exist at the inspected plugin
HEAD, despite the README saying binaries are not committed. Use the tracked
lock and inspected artifacts as evidence. Verify the final app dependency graph,
packaged ABI libraries and CA asset in cloud CI. Do not depend on a developer's
local path override or copy the original CloudTerminal checkout into the graph.

## Parallel Pi ownership proposal

Freeze the contract and capability scope first. Then dispatch four bounded
workers with exclusive file ownership:

| Worker | Owned work | Integration boundary |
| --- | --- | --- |
| Pi 1 | Backend contract, native/CLI/cloud adapters, typed result mapping and meaningful backend fixtures | Own new `lib/git/` service files and the legacy GitService migration. Publish signatures first. |
| Pi 2 | Git page/controller, author/token/remote dialogs, capability-aware actions and result/conflict presentation | Own `lib/pages/git_page.dart` and new Git UI files. Consume Pi 1 contract. |
| Pi 3 | Home clone entry, clone coordinator, project registration hook, editor owner selection and dirty-buffer guards | Own Home/editor integration files. Do not edit backend implementation or the Git page. |
| Pi 4 | Pinned dependency, app/core manifests, cloud CI and packaged native artifacts | Own manifests/workflows and produce cloud run/package evidence. |

If remote configuration or history is required for mobile parity, finish a
separate bounded plugin extension before adapters depend on it. Assign one
plugin owner for `repository.dart`, native headers and C implementations.
Do not have multiple workers edit that API concurrently. Report capability gaps
explicitly if the initial scope instead gates those controls.

## Cloud acceptance plan

The user prohibited local tests/builds. Run required verification in cloud CI
after review and push, and identify every result by repository SHA and run URL.

- Backend tests: platform/cloud selection, explicit unsupported capabilities,
  status flags, unborn/detached HEAD, failed staging, merge conflict mapping,
  cancellation, per-root mutation ordering and offline network rejection.
- UI tests: mobile actions, desktop/cloud compatibility, author/token validation,
  disposed-page completion, duplicate actions, visible errors, narrow screens and
  scrollable dialogs with keyboard insets.
- Ownership tests: active foreign-root file, no-file fallback, orphaned owner,
  tab switch during a dialog, dirty buffers and clean-buffer/tree refresh.
- Clone tests: destination collision, cancellation, network failure, registration
  failure and cleanup that preserves every pre-existing directory.
- Cloud native tests: clone a disposable repository, commit with explicit author,
  fetch, push, branch/checkout and deliberate conflict. Check the precise native
  and Dart revisions under test. Keep test credentials out of artifacts/logs.
- Build Android and OHOS installation packages with the new plugin included.
  Build iOS on an available supported cloud runner if it is a release target.
  Inspect each packaged native library and the CA asset, then provide installable
  artifacts for the user's acceptance. Mocks do not establish device FFI loading
  or real Git host authentication.

Do not tag the integration complete until the selected mobile features are
present in the shipped dependency graph and cloud artifacts. Keep cloud build
evidence separate from user/device acceptance.

## Applicable Trellis specifications

- Root `.trellis/spec/frontend/repository-layout.md`: separate sibling Git roots,
  worktree isolation and dependency path resolution.
- Root `.trellis/spec/frontend/process-lifecycle.md`: process ownership,
  cancellation, process-tree termination and disposal.
- Core `.trellis/spec/frontend/offline-workspace.md`: multi-root ownership,
  physical-path validation and dirty-buffer preservation.
- Core `.trellis/spec/frontend/saved-workspaces.md`: retained workspace identity,
  orphan recovery and intrinsically measurable scrollable dialogs.
- Core `.trellis/spec/frontend/project-transfer.md`: owned import directories,
  persistence before success and cleanup boundaries.
- Core `.trellis/spec/backend/offline-network-policy.md`: request-boundary network
  gates; native networking must not bypass the product policy.
- Core `.trellis/spec/frontend/quality-guidelines.md`: existing widget helper and
  lifecycle conventions.
