# pi-A sidebar integration — final report (frozen)

Task: 11-15-agent-chat-usability (sidebar-integration worker), worktree
`D:/MyNewProjects/_wt/integration/qfli_studio_core`, baseline `e718653`.
Not committed, not staged, not pushed — root integrates.

## Changed paths

- `lib/editor/file_explorer.dart`
- `lib/editor/editor_page.dart`
- `lib/editor/agent/editor_sidebar_tabs.dart`
- `lib/editor/agent/session_list_view.dart`
- `lib/workspace/workspace_store.dart` (only `addMembers`)
- `test/editor_agent_embed_test.dart` (placement test updated + new groups)
- `test/editor_project_browse_semantics_test.dart` (new)
- `test/workspace_add_members_test.dart` (new)

Not touched: `composer_card.dart`, `chat_transcript.dart`,
`workbench_agent_pane.dart`, `agent_session.dart`, `vibe_agent_facade.dart`.

## 1. One card, one header, body swap

`FileExplorerSections` is passed into `FileExplorer`. The card border, the 48px
header row and the switch exist once. `sidebarSection` only selects the body:
file tree or `SessionListView(embedded: true)`. `SessionListView` drops its own
header and uses only a body. The detached segmented strip is gone and
`EditorSidebarTabs` is deleted; `SidebarSectionSwitch` remains.

The header still renders when the runtime is not resolved, so Sessions always
needs one tap to return to Files.

## 2. Header actions follow the section

- Files: new file + overflow/search per width.
- Sessions: new session + "全部停止"; no file action renders.
- Width budget (280px sidebar): `compact` moves new-folder and refresh into the
  `file-explorer-more` labeled menu; `ultraCompact` also moves search there, so
  the project picker keeps usable width (asserted >= 72px in the 280 case).

## 3. Switch semantics

Custom two-segment control, 44x44 hit area (46px container to absorb the 1px
border), `Semantics(button: true, selected: …, label: …)`, tooltips, no label
squeeze.

## 4. Directory picker = temporary browse (plain project)

`_switchProject` no longer calls `onProjectSelected` for the plain case. It
swaps `_browsing`, rebuilds the tree and records `setBrowsedProject`. No route
push, no editor/Agent project change. This was the regression: the old
`isMainStudioRelease && onProjectSelected != null` branch navigated away.

## 5. Workspace mode = additions only, one dialog

The picker title opens the multi-select dialog directly (no popup, no nested
menu). Confirm calls `WorkspaceStore.addMembers`, which:

- re-reads the stored record, so members missing from the registry survive;
- appends only, keeping identity, name, member order;
- passes no `session` to `copyWith`, so the stored session snapshot is kept;
- skips duplicates.

No second dialog, no naming/removal editor, nothing removed implicitly.

## Verification

- `flutter analyze --no-pub` on all 8 changed files: no issues.
- `test/editor_agent_embed_test.dart`: 24/24 pass.
- `test/file_explorer_state_test.dart`: 12/12 pass (existing temporary-switch
  contract intact; no superseded asserts found — no test referenced
  `onProjectSelected`).
- `test/workspace_add_members_test.dart`: 2/2 pass (missing member + session
  preserved; no duplicate append).
- `test/editor_project_browse_semantics_test.dart`: analyzes clean but cannot
  run — `lib/chat/chat_transcript.dart` (owned by J) does not compile
  (`_tileKeyFor`, `_tileKeys`, `_viewportTopGlobal`, `_anchorExtent` undefined).

## Final `addMembers` API (for the spec)

```dart
Future<SavedWorkspace?> WorkspaceStore.addMembers(
  String workspaceId,
  Iterable<Project> additions,
)
```

Contract:

- Snapshots `additions` **before** the write is enqueued; mutating the caller's
  list afterwards cannot change what is written.
- Dedupes **within** the argument: `existing.add(key)` on a taken-set, so a
  path passed twice adds one member. Cloud projects are skipped.
- Re-reads the stored record inside the transaction, so members missing from
  the project registry survive.
- Appends only; identity, name, member order and session snapshot are kept
  (`copyWith(members:)` passes no `session`).
- Returns: updated record; the unchanged record when every addition was already
  a member; `null` when the workspace record is missing/deleted.
- Storage failures are **rethrown** (previously swallowed into `null`), so the
  caller can distinguish a write failure from a deleted workspace.

Caller (`_addProjectsToWorkspace`) shows a snackbar for each case: write
failure, deleted record, and "already a member" — confirm never looks
successful when nothing was written.

## Verification (final)

- `dart format` on all 7 changed files: 0 changed remaining.
- `flutter analyze --no-pub` on all 8 changed files: no issues.
- `test/editor_agent_embed_test.dart`: 27/27 pass, including
  - 280px and 320px at text scale 1.3 (picker >= 72px, all actions reachable),
  - 320px regression case (picker >= 96px, i.e. full-button set not chosen).
- `test/workspace_add_members_test.dart`: 6/6 pass — missing retained member +
  session preserved; duplicate-in-argument; mutable additions snapshot;
  concurrent `saveSession`; deleted workspace returns null.
- `test/file_explorer_state_test.dart`: 12/12 pass.
- `test/editor_project_browse_semantics_test.dart`: analyzes clean but **cannot
  run** — `lib/chat/chat_transcript.dart` (J) does not compile.

## Header budget (fixed)

Old threshold `90+96+132=318` chose the four-button set at 320px while four
buttons actually consume 176px, leaving the picker ~50px.

Now computed from the real budget:

```
actionBudget = width - 8 (chrome) - 90 (switch) - 96 (picker floor)
fitsAll      = actionBudget >= 44 * 4   // new file, new folder, search, refresh
ultraCompact = actionBudget <  44 * 2   // also move search into the menu
```

`SessionListView.headerLeading` removed — it had no callers left.

## FROZEN — 2026-11-16

Stopped on instruction. No further edits from pi-A.

### Stopped process

`flutter_tester` PID 75512 (my hung probe run, started 23:47) terminated.
PID 41896 (root, 22:53) and 73280 (root) left untouched.

### Removed

`test/zz_probe_pushes_test.dart` — deleted. No `zz_probe*` files remain.

### Last edit made before freeze (incomplete)

`_RouteCounter.didPush` in `test/editor_project_browse_semantics_test.dart`
was changed to count only full-screen routes (skip `PopupRoute`). This is
**unformatted and unverified** — root owns finishing the two fixtures.

### Root cause (confirmed by root)

Inside `testWidgets`, a bare `await workspaceStore.save(...)` or
`load(force: true)` runs real disk IO under FakeAsync and can deadlock. Both
new files must wrap standalone store IO in `await tester.runAsync(...)`.

### State of my two new/rewritten fixtures

- `test/workspace_project_switch_test.dart` — 3 tests, **all 3 passed** on the
  last clean run (before the fixture-hardening request). Rewritten from the old
  standalone-navigation contract to: one-dialog additive membership (identity,
  name, order, primary flag, dirty buffer preserved), workspace member selection
  as a temporary tree change, and plain mode browsing without navigation.
- `test/editor_project_browse_semantics_test.dart` — rewritten twice. Current
  state: picker requires opening the sidebar on wide layouts (fixed), store IO
  still awaited directly, `_RouteCounter` change just applied. **Not passing,
  not formatted.** Root to finish.

### Accepted scope (production, verified by root)

Sidebar implementation accepted; root passed 55 workspace regressions, plus my
reported `editor_agent_embed_test` 27/27, `workspace_add_members_test` 6/6,
`file_explorer_state_test` 12/12.
