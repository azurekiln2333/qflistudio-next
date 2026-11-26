# Design and change boundary

The implementation root is the matching integration Core:
`D:/MyNewProjects/_wt/studio-git-integration/qfli_studio_core`.

## R1: Context accounting and UI

The controller owns the actual request history, tools and usage response. Add a
read-only snapshot derived from that history. Attribute skill indices and
loaded bodies only while they are actually present. Categories are mutually
exclusive. All local token counts are estimates. Provider input usage describes
the last completed request and is displayed separately.

Pass the snapshot through AgentFacade to the shared Workbench composer. Add a
reusable ring and detail popup. The popup supports tap and pointer hover. Model
metadata may carry a nullable context window. A per-model composer preference
can supply an explicit local capacity when metadata is missing. Never infer a
capacity from a model name or silently invent one.

The accounting worker owns `vibe_coding_controller.dart`, the new context model
and the optional capacity metadata in `api_client.dart`. Root owns facade,
composer state/draft, context widgets and Workbench wiring.

## R2: Trellis project entry

The skill worker owns `vibe_rules.dart` and `vibe_skills.dart`. Reuse discovery,
source ordering and limits. Recognize actual Trellis workflow content rather
than an arbitrary empty directory. Keep detailed source reads on demand.
Do not change model tools or bypass project file boundaries.

## R3: Protected project configuration

The deletion worker owns a shared path policy and editor delete/rename checks.
Apply the policy before filesystem or cloud mutation. Check configuration
nodes, descendants, containing directories and resolved aliases. Keep the
policy specific to configuration names rather than all dotfiles.
No command-shell sandbox or terminal security guarantee is added here.

## R4: Streaming audit

Inspect existing controller, transport and backend routes. Record precise
dependency and revision evidence. Avoid claiming runtime or release success
from static source alone. No protocol rewrite is planned without a concrete
defect.

## Coordination

Workers report static evidence and freeze owned source. Root alone stages and
commits. Keep requirement files separate. Integration-source commits do not
change the dirty planning-root App dependency automatically.
