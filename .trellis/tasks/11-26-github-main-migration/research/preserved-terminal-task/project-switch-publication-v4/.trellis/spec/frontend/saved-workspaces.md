# Explicit saved workspaces in the main product

## 1. Scope / Trigger

`isMainStudioRelease` selects the main `qflistudio` product (including the
compatible null-profile shell). Its named workspaces are independent documents.
Language products retain the legacy [offline workspace](offline-workspace.md)
history contract. Home's cloud scope, cloud creation and automatic cloud fetch
are hidden for the main release; registered cloud data is preserved.

## 2. Signatures

- `WorkspaceStore({Directory? root})` uses the override as the workspace
  directory, or `AppPaths.storageDirectory()/workspaces` by default.
- `save({existing?, required name, required members, required primary,
  session?})` returns `({String? error, SavedWorkspace? workspace})`.
- `saveSession(SavedWorkspace, WorkspaceSessionSnapshot)`, `remove(String id)`,
  `load({bool force = false})`, and `settle()` return `Future<void>`.
- `resolve(SavedWorkspace, ProjectStore)` returns `WorkspaceResolution` with
  `projects`, `missing`, `primary`, `primaryMissing`, and `isEmpty`.
- `openEditorPage(..., workspace?, workspaceProjects?, workspaceStore?)` opens
  a standalone session when `workspace` is null.
- `EditorPage(..., onProjectSelected?)` lets the retained owner open a project
  outside the active workspace; without an owner it pushes a standalone page.

## 3. Contracts

Each `<id>.json` contains version, id, name, creation/update timestamps, ordered
member references (`projectId`, `path`, `name`, `primary`), and session
metadata (owner-relative documents/cursors/active tab and per-root expansion).
Source buffers are never stored in this document. Names are trimmed, nonempty
and unique ignoring case. A one-project workspace is valid. Type and language
are resolved from the current registered project rather than copied into member
references.

Snapshot mutable inputs before enqueueing. Serialize store calls in invocation
order and transactions across instances addressing the same physical directory.
Read current disk state inside the transaction, merge the fields the caller
owns, atomically replace the document, and only then publish memory. Metadata
updates without an explicit session retain the latest session; session saves
retain latest name/membership/timestamps. Session saves do not reorder Home.
Deleted workspace ids cannot be recreated by stale timers or metadata dialogs.

Retained workspace identity is its id, independent of effective primary path.
Promotion of a standalone session keeps its live state; subsequent standalone
opens use one distinct standalone session. Reopening W after its primary A
disappears resumes W with survivor B and preserves B's live dirty buffers.
Main standalone history ignores foreign-owner documents and remembered foreign
tree roots. Child products continue restoring legacy multi-root history.

The explorer's project selector is independent of saved-workspace membership.
Selecting a member changes the browsing/default creation target only: retain
all roots in primary/member order, their loaded children, expansion and scroll.
Never derive that membership by prepending the selected project to a list that
excludes the primary; that drops the primary when a secondary is selected.
Selecting an external project opens/resumes a separate standalone editor with
`workspace: null`, so its tree, file ownership, history and run identity agree.
Keep the original workspace and its dirty buffers live and recoverable. A bare
saved-workspace explorer without a navigation owner disables external choices.
Legacy language-product unsaved browsing retains its history contract.

On reopening, validate registry membership and actual directories. Skip missing
members and report them; select a surviving primary. Reconcile retained tabs:
close clean tabs of unavailable members, retain dirty buffers for explicit Save
As recovery, and block their original-root save, autosave and run. Retaining
expansion metadata for a removed root does not restore its membership.

Workspace management dialogs explicitly use `AlertDialog(scrollable: true)`
with ordinary, intrinsically measurable project children. Let the dialog own
the content scroll while keeping its actions outside that scroll. Do not nest
a shrink-wrapping `ListView` under a width-only or maximum-height constraint:
the OHOS SDK's scrollable dialog asks for intrinsic height, which a viewport
cannot provide. That layout exception leaves the modal barrier visible without
a usable dialog. The same layout contract applies to legacy project selection.

## 4. Validation & Error Matrix

| Condition | Behavior |
| --- | --- |
| Empty/duplicate name or no local member | Return a useful save error; keep dialog open. |
| Missing secondary | Report and open surviving members. |
| Missing primary | Report and use a survivor in the same retained session. |
| All members missing | Actionable empty state; no editor using an invalid root. |
| Malformed document/id mismatch | Skip document; never traverse outside workspaces. |
| Write/delete fails | Preserve memory; propagate or return error for visible retry. |
| Session save after deletion | No-op; never resurrect metadata. |
| Metadata save after deletion | Return a save-as-new error. |
| Root removed then re-added | Restore its stored expansion; preserve other roots. |
| Selector chooses current workspace member | Preserve the complete ordered tree and its view state. |
| Selector chooses external project | Replace visible tree through a standalone editor; never add it to the workspace. |

## 5. Good/Base/Bad Cases

Good: W(A,B) and standalone A have independent session metadata; missing A falls
back to B without a second live W. Base: a single local project can be saved as
a named workspace. Bad: a hidden retained timer recreates a workspace the user
deleted, or a standalone A restores unrelated B tabs from legacy history.

## 6. Tests Required

Run `workspace_store_test.dart`, `main_workspace_sessions_test.dart`, legacy
`workspace_editor_session_test.dart` and `file_explorer_state_test.dart`, retained
editor and owner-run regressions. Assert disk JSON as well as controller state.
Cover concurrent metadata/session writes and failed deletion retries, missing
primary/secondary/all, same live session fallback with dirty buffers, standalone
reuse after promotion, actual tree fallback and remove/re-add expansion.
Keep child profiles explicit in legacy tests. Drain fake-time queued writes with
bounded duration pumps and real IO; awaiting them entirely inside `runAsync`
can deadlock. Include the explorer at 1100x175 and large text.
`workspace_dialog_layout_test.dart` must physically click settings through a
retained `EditorPage`, using OHOS/Chinese phone and desktop layouts plus an
Android control. Assert hit-testable title/name/actions, last-project selection
with ten registered projects and a 300px keyboard inset, persisted membership,
single-project save, unchanged source, retained page identity and cancellation
returning toolbar input. Include the explicit language-product legacy dialog.
Advance the initial frame and the keyboard-inset animation before scrolling
or clicking; finder presence alone does not establish a visible dialog.
`workspace_project_switch_test.dart` must physically use the project selector:
select B/A within W(A,B), then external C, restore W and select C again. Assert
unchanged root order/expansion/scroll and dirty buffers for internal switches,
standalone identity and correct owner for C, unchanged W membership, retained
session reuse, and a non-host page's route/Back fallback.
Also cover standalone-to-standalone selection and resuming an existing session.
Open the initially collapsed explorer through its toolbar before clicking rows;
mounted tree text can be clipped and is not evidence that it receives input.
Use a nonzero scroll offset and drain each project's queued history via
`ProjectHistory.load` after unmounting before deleting a temporary fixture.

## 7. Wrong vs Correct

Wrong: `byId(id) ?? staleWorkspace` before autosaving, or a session key containing
the primary path as a required identity component. Correct: update only an
existing disk document in the serialized transaction and locate a retained
workspace by id; update its effective primary/members without rebuilding buffers.

Wrong: derive saved roots from `[selected, ...membersWithoutPrimary]` or only
replace the explorer's root when an external project is selected. Correct:
derive saved roots from the primary and configured members, update only the
member creation target, and delegate external selection to a standalone editor
whose project, file ownership and history all identify the chosen project.
