# Local Git UI

## 1. Scope / Trigger

Apply when changing project-card repository metadata or keyboard handling in Git dialogs and the editor symbols bar. Product sources live in the resolved Core checkout.

## 2. Signatures

- `readProjectGitBranch(String projectRoot) -> Future<String?>` reads local HEAD metadata.
- `ProjectCard.gitRefreshRevision` invalidates the displayed branch.
- `showGitDialog<T>(context, builder, barrierDismissible)` uses a native Flutter dialog route.
- `SymbolsBar` owns the fixed `symbols-hide-keyboard` action.

## 3. Contracts

- Card metadata reads are asynchronous and read-only. Do not start Git, load FFI, collect full status, scan parents, or watch a project recursively for a card label.
- Support `.git/HEAD` and relative or absolute `gitdir:` files. Show unborn branch names and seven-digit detached commit IDs. Hide unavailable metadata and local labels for cloud projects. Never persist the branch into `.qfli/project.json`.
- Refresh after Home pull-to-refresh, standalone editor return, retained editor visible-to-hidden transition, and App resume. Hosted `openEditorPage` completes immediately, so its returned Future does not represent an editor return. Remove listeners on controller replacement and disposal.
- Ignore stale asynchronous branch results. Keep long labels to one line with ellipsis and a complete tooltip inside the existing card height.
- Flutter `AlertDialog` already animates `MediaQuery.viewInsets`. `showGitDialog` must not add the same keyboard padding again. Keep forms scrollable. Mobile clone does not autofocus before a field tap.
- Keep keyboard dismissal fixed at the far right of the 44-point symbols bar. Wrap its button in `CodeEditorTapRegion` and issue `TextInput.hide` while retaining editor focus. Mobile `re_editor` cancels the selection on unfocus, so dismissal must not call `unfocus()`. Do not change source, selection, symbol insertion, or horizontal scrolling.
- Use standard visual density and a shrink-wrapped tap target for the 44-by-44 dismissal button. Material3 padded tap targets impose a 48-point minimum, while compact density shrinks the target. Keep the bar's top border in `foregroundDecoration`; decoration padding would reduce its 44-point content height to 43. Assert the rendered bounds in narrow layouts.

## 4. Validation & Error Matrix

| Condition | Behavior |
| --- | --- |
| Missing, malformed or unreadable HEAD | No branch label; project still opens |
| Ordinary directory or cloud project | No local branch badge |
| Linked worktree or unborn branch | Display the full branch name |
| Mobile keyboard opens | Apply its inset once; form and actions remain reachable |
| Long branch or large text | Constrain and truncate without adding card height |
| Retained editor minimizes after checkout | Reload visible Home card labels |

## 5. Good / Base / Bad Cases

- Good: read only the root HEAD and refresh from explicit UI lifecycle signals.
- Base: an unknown directory renders its normal card with no badge.
- Bad: add outer keyboard padding around an AlertDialog that still sees the original inset.
- Bad: assume awaiting a retained editor's open call detects returning Home.

## 6. Checks

Use targeted static analysis for local checks. Honor a user's cloud-only runtime constraint. Focused cloud regressions live in `git_branch_label_test.dart`, `project_card_git_test.dart`, `git_clone_dialog_layout_test.dart`, and `symbols_bar_keyboard_test.dart`. Assert actual dialog surface geometry, input-method hiding, retained-controller minimize, and narrow large-text layouts.

Keyboard dismissal coverage must mount a real `CodeEditor`, preserve a non-collapsed selection and editor focus, and assert that the input method remains hidden after pumping. Testing only a standalone button misses the mobile editor's focus listener.

## 7. Wrong vs Correct

Wrong: wrap `AlertDialog` with `AnimatedPadding(bottom: viewInsets.bottom)`.

Correct: pass the dialog builder directly to `showDialog`; let `AlertDialog` own keyboard insets.
