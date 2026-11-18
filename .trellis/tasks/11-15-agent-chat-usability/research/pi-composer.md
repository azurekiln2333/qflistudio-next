Active task: D:/MyNewProjects/qflistudio/.trellis/tasks/11-15-agent-chat-usability
You are already trellis-implement. Read research/dispatch-common.md and task artifacts, then implement directly.

Own lib/chat/composer_card.dart and test/chat_composer_card_test.dart only.
User: plus action too far from left, permission/model crowded together, send
button too big and too close to right edge. Rework existing card's layout and
spacing coherently: useful text area, plus toward left, visibly separate control
groups, visually compact send/stop, balanced horizontal insets. Accessible hit
targets >=44. Adapt gracefully at 320/360/424 and text scale 1.3, both themes;
desktop retains selector labels. Avoid empty reserved gaps/overflow. Preserve
attachment, model, reasoning, send/stop, keyboard semantics and disabled states.
The message worker owns ComposerState and WorkbenchAgentPane. If focus/edit draft
API is needed, coordinate with w37:pJ. Do not touch those files. Update existing
layout assertions and render previews if practical. No commits.
