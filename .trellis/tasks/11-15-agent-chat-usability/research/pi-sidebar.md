Active task: D:/MyNewProjects/qflistudio/.trellis/tasks/11-15-agent-chat-usability
You are already trellis-implement. Read research/dispatch-common.md and task artifacts, then implement directly.

Own sidebar integration only: lib/editor/file_explorer.dart, editor_page.dart,
agent/editor_sidebar_tabs.dart, agent/session_list_view.dart, and related editor tests.
User: put Files/Sessions switching INSIDE the original sidebar header. Delete
the detached segmented row and redundant switch. Preserve file/project/workspace
actions, tree state, lazy Agent activation, offline gating, drawer/desktop parity.
Read FileExplorer header around 1148-1378, EditorPage _buildSidebar ~1468 and
_buildExplorerCard ~3747. The shared header must remain when sessions is selected,
so the user can return to Files. Keep touch targets >=44 and avoid squeezed labels.
Smallest sensible shared-header change; no new external wrapper strip. Update
obsolete placement tests. Render/inspect if the existing preview harness helps.
Other workers own chat, composer, runtime/store; do not edit those. No commits.
