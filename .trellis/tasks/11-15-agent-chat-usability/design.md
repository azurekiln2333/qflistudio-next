# Design and ownership

Use existing widgets and the existing send/runtime interfaces. Keep one source
of truth for sidebar section, session identity, and per-session composer state.

The first implementation pass used four Pi workers for separate file groups.
The follow-up visual correction uses these owners:

1. Layout: `file_explorer.dart` and `editor_page.dart`.
2. Toggle: `editor_sidebar_tabs.dart`.
3. Regression checks: `editor_agent_embed_test.dart`.
4. Visual review: inspect the rendered shared header across both modes and narrow widths.

The coordinator reviews all changes, resolves shared-file edits, checks visual
results, and handles build/deployment and commits. Workers must not stage,
commit, push, or change task activation. Do not spawn further workers.

The sidebar header has one row. The project selector stays at the left.
Contextual actions follow it. One Files/Sessions icon toggle sits at the far
right. Every header action uses a 44x44 target and a 20px icon in both modes.
Use explicit size and padding on popup menu buttons because their defaults can
differ from adjacent icon buttons. Reserve at least 96px for the project
selector at narrow widths.

Editing means preparing an explicit new send with the original message retained.
Direct resend must not consume a separate unfinished draft. User messages with
attachments must retain their actual source paths, without reconstructing them
from display text. Any required additive message-view metadata is coordinated
with the loading worker and must remain compatible with old persisted messages.
