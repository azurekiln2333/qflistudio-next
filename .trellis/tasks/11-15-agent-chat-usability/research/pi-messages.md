Active task: D:/MyNewProjects/qflistudio/.trellis/tasks/11-15-agent-chat-usability
You are already trellis-implement. Read research/dispatch-common.md and task artifacts, then implement directly.

Own lib/chat/chat_transcript.dart, lib/shell/workbench_agent_pane.dart,
composer_state.dart if needed, related transcript/pane tests. Add basic actions:
copy user/assistant text, edit a user message into the composer, resend a user
message through existing send pipeline. Prefer a compact discoverable menu,
available by touch and mouse. Label edit as 编辑后重发. Preserve old conversation;
editing prepares a draft for explicit send. Do not silently overwrite a nonempty
draft: retain/restore it or confirm replacement. Direct resend must preserve the
independent unsent draft. Keep actual attachment paths, guard busy/pending actions,
avoid duplicate sends, preserve per-session isolation/failure rollback.
Coordinate additive AgentMessageView attachment/raw-text metadata with loading
worker w37:pH, who owns vibe_agent_facade.dart; do not edit that file yourself.
Composer worker w37:pG owns composer_card.dart; coordinate focus needs with them.
Also inspect session switch stale-history/races in your owned pane and fix any
concrete issues, coordinating findings from loading worker. Avoid unrelated
refactors. No commits. Report exact tests and behavior.
