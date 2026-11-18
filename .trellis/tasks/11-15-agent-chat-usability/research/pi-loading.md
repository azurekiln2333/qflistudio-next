Active task: D:/MyNewProjects/qflistudio/.trellis/tasks/11-15-agent-chat-usability
You are already trellis-implement. Read research/dispatch-common.md and task artifacts, then implement directly.

Own session-loading diagnosis/fix: lib/session/agent_session.dart,
lib/vibe_coding/vibe_agent_facade.dart, runtime/store tests. User reports opening
sessions still stalls repeatedly. Trace local history decoding, readTail,
readHistory, runtime.open deduplication/caching, and change notifications.
Identify concrete cause(s) and fix at source, preserving offline local history,
pagination, running sessions, cancellation, and old persisted format compatibility.
Do not claim device speed measurements without profiling. Provide meaningful
regressions for demonstrated duplication/races/large-history issues.
DO NOT edit chat_transcript.dart or workbench_agent_pane.dart: message worker owns
them. Send shared-file findings to coordinator w37:pQ or report them early. Message
worker may need additive attachedPaths/raw user message metadata in AgentMessageView;
coordinate with w37:pJ before editing that contract. No commits, no global refactor.
