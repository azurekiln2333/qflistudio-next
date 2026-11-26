# Project card Git branch

Show the current local Git branch on each repository card.

## Acceptance

- Cloned and existing local repositories show their branch.
- Unborn branches remain visible. Detached HEAD shows a short commit ID.
- Ordinary directories and cloud projects do not show a local branch.
- Long branch names truncate without overflowing narrow cards.
- Returning from the editor, pulling to refresh, and resuming the App refresh the label.
- Metadata reads are asynchronous, local, read-only, and do not run Git processes or load native libraries.
- Linked-worktree gitdir files work with relative and absolute paths.
- Read failures do not prevent project cards from opening.

## Boundary

Change the Core card, Home refresh wiring, one small HEAD reader, and focused regression coverage. Keep Git operations, project configuration, the native plugin and source cloudterminal unchanged. No local tests, builds or App launches. Use the existing GitHub checks and release pipeline. Root alone commits, pushes and tags.

## Implementation

Read only the project root's .git/HEAD or its gitdir target. Do not scan parents, traverse files, collect status, or watch recursively. Use a refresh revision from Home and a lifecycle observer on the card. Ignore stale asynchronous results after a path change or disposal.

## Added user requests

- Fix the clone dialog being squeezed above the screen when the mobile keyboard opens. The shared Git dialog wrapper and AlertDialog currently both apply the keyboard inset. Keep only Flutter Dialog's native inset handling and retain scrollable content. Mobile clone must not open the keyboard before the user selects a field.
- Add a keyboard-dismiss button at the far right of the editor's bottom symbols bar. Keep that button fixed while symbols scroll. It must dismiss the input method without editing source or losing the editor selection.
- Include the real retained-editor return path when refreshing project-card branches. Hosted openEditorPage completes immediately; observing only its Future does not detect minimize.

The new scope remains a bounded UI follow-up. Preserve the .3 tag; use a new immutable preview for the combined fixes. All runtime verification stays in GitHub.

## Cloud regression follow-up

The .4 Core suite found two real keyboard-action defects. Mobile re_editor cancels a non-collapsed selection when the editor loses focus. Compact IconButton density also shrinks the requested 44-point button to 40 points. Keep the action inside CodeEditorTapRegion, hide the input method while retaining editor focus, and use standard density for the fixed 44-by-44 button. Keep selection, code, scrolling and hide-method assertions. Limit the production fix to symbols_bar.dart. Publish the correction under a new immutable .5 tag after cloud checks.
