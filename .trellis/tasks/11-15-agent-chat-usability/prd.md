# Embedded Agent usability revision

## Scope

Continue the user's editor revision. The active app resolves shared code to
`D:/MyNewProjects/_wt/integration/qfli_studio_core`, baseline `fd1f5f4`.
Do not edit the inactive sibling core or unrelated app changes.

## Requirements

- Put Files/Sessions switching inside the original sidebar header. Remove the detached segmented row. Both the file tree and session list occupy the same existing sidebar card and share its header. Only the body and contextual header actions change. File mode exposes file/workspace actions; session mode exposes new-session and existing session-menu actions. Preserve drawer/desktop navigation.
- Render section switching as one ordinary icon button at the header's right edge. Remove the segmented capsule. Use the same 44x44 action target and 20px icon size in Files and Sessions modes.
- Restore the project-directory selector's temporary browsing behavior in ordinary project mode. Choosing another directory changes the file tree only; opening a file can cross project roots without switching the editor or Agent project. In saved-workspace mode, reuse that entry for multi-select additions to the current workspace, retaining current members and persisting additions.
- Diagnose repeated session-loading stalls. Fix demonstrated local loading or rendering causes, preserve offline history, pagination, running sessions, and fast-switch consistency.
- Balance the shared composer: bring the attachment action to the left, separate permission/model selectors, reduce the send button's visual size, and keep a comfortable right inset. Preserve accessible tap areas and narrow-screen behavior.
- Offer message copy and user-message edit/resend. Editing restores a draft for explicit send. Resending uses the existing send pipeline. Preserve prior messages, attachments when available, unsent drafts, and failure recovery. Prevent duplicate sends while busy.
- Validate related analysis and existing behavioral/layout checks. Inspect light/dark and narrow/wide views. Rebuild OHOS and replace the app on `192.168.68.207:46551` without clearing user data.

## Acceptance

- One integrated sidebar header remains on both sections.
- The right-edge section toggle matches neighboring icon actions in both modes, with no capsule or second toolbar row.
- Ordinary project-directory selection changes browsing only. Workspace selection adds multiple projects without changing the editor or removing existing members.
- Session changes never briefly show the previous conversation or erase drafts.
- Repeated session opening avoids redundant disk work. Any performance claims distinguish source findings, automated checks, and measured device evidence.
- Composer controls fit at 320/360/424 logical pixels and increased text scale.
- Copy, edit, resend, busy guards, attachments, and failure restoration work.
- Targeted checks pass and the signed HAP installs successfully.

## Exclusions

No terminal-bootstrap work, provider redesign, unrelated refactors, release tags,
or remote pushes are part of this revision.
