Active task: D:/MyNewProjects/qflistudio/.trellis/tasks/11-20-cloudterminal-import

You are the assigned Pi implementation worker for a narrow release compatibility fix. Implement directly. Do not spawn another worker. This is a fresh Pi session with the default configured model. The coordinator has explicitly authorized this fix in the new release worktree. Older task documents describe the original migration boundary; this brief extends that boundary only for the four files below.

Working directory: D:/MyNewProjects/_wt/release-v5.0.5/qfli_studio_core

Write allowlist, exactly these four files:
- lib/services/api_client.dart
- test/ai_chat_stream_relay_test.dart
- lib/chat/composer_card.dart
- test/chat_composer_card_test.dart

Other workers are merging thinking/ui and editing chat_transcript.dart. Do not touch their files. Do not change Git state, branches, index, commits, worktrees, workflows, manifests or locks. No commit or push. Do not edit any report file. Return the report in your final answer. Do not touch D:/MyNewProjects/cloudterminal or other source worktrees.

Hard validation limits: do NOT run any test, temporary test probe, build, device command, emulator, VM, WSL, Docker or live service. Static inspection, formatting, targeted static analysis and git diff --check are allowed. If dependencies are missing, report it and do not install them. Do not run pub get. Do not ask permission for this already authorized work.

Before editing, read the target AGENTS.md and relevant source. Read these guidelines:
- D:/MyNewProjects/qflistudio/.trellis/spec/frontend/ai-protocols.md (Draft: current source wins where signatures evolved)
- D:/MyNewProjects/qflistudio/.trellis/spec/frontend/repository-layout.md
- D:/MyNewProjects/qflistudio/.trellis/spec/guides/code-reuse-thinking-guide.md
- D:/MyNewProjects/qflistudio/.trellis/spec/guides/cross-layer-thinking-guide.md
State the smallest behavior gap and four-file change boundary before implementation. Chinese prose/comments must use short active sentences with stable terms. English test names are fine.

Fix A: Relay history projection.
Current aiChat relay and _aiChatStreamRelay send raw messages. Persisted/direct histories may carry reasoning_content and reasoning_blocks. Legacy server main only allows role, content, tool_calls, tool_call_id. New stream relay additionally allows assistant reasoning_content, never reasoning_blocks. A 404/405 stream response falls back to aiChat with the same history and therefore gets rejected by old servers.

Implement one private relay message projection helper in api_client.dart. Create fresh message maps, do not mutate the caller's list/maps or persistent history. Keep role, content, tool_calls, tool_call_id if present. For new streaming relay also keep assistant reasoning_content when present and compatible with its existing wire contract. Always omit reasoning_blocks and other non-wire metadata. Ordinary nonstream aiChat relay uses the conservative legacy four-field set. The 404/405 fallback consequently uses that same legacy projection. Do not change direct route encoding or add retry on arbitrary 400. Do not add public configuration or capability probes. Keep cancellations and existing model/tools/reasoning_effort handling intact.

Add meaningful tests to ai_chat_stream_relay_test.dart without running them:
- Strict mock legacy validation for both 404 and 405, with history containing both thinking fields and tool calls/results.
- New stream request keeps reasoning_content and omits reasoning_blocks/metadata.
- Nonstream relay uses legacy fields.
- Original history remains equal to its snapshot after calls.
- HTTP 400 on the stream is not retried as a legacy request.
Existing direct protocol tests remain unchanged; do not copy or rewrite them.

Fix B: Cross-platform attachment labels.
composer_card.dart _attachmentLabel currently calls host-platform p.isAbsolute. The test uses D:/work/other/src/Util.java, so Linux keeps the full path. Detect absolute POSIX and Windows paths explicitly, including Windows drive paths with either separator and UNC paths. Normalize backslashes for display as currently done, show the last two nonempty segments for absolute paths, and keep full original text in Tooltip. Relative paths keep their normalized full label. Drive-relative D:folder/file must stay relative. Do not change stored attachment paths or introduce filesystem access.

Expand chat_composer_card_test.dart with table-driven or similarly concise coverage for drive slash, drive backslash, UNC slash/backslash, POSIX, and relative paths (including drive-relative). Keep existing behavior for short absolute paths and full original tooltip. Do not merely change the old failing fixture to a Linux path.

Finish with a concise report: exact changed files, behavior, static commands actually run and results, tests added but not run, any uncertainty. A successful process exit is not acceptance; the coordinator reviews the diff.
