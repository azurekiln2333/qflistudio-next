# Harness Hub — Pi brief

Task dir (read-only except reports/): D:/MyNewProjects/qflistudio/.trellis/tasks/11-22-harness-hub
Read first: prd.md, design.md, implement.md in that dir, then the contract
`lib/harness/harness_host.dart` in your core worktree.
Specs (read-only): D:/MyNewProjects/qflistudio/.trellis/spec/frontend/index.md and the
files it routes to for your layer (editor-terminal.md, process-lifecycle.md,
vibe-skills.md, interop.md, repository-layout.md as relevant).
Prior remote work for context: ../11-20-cloudterminal-import/design.md and
../11-21-remote-account-binding/design.md (do not edit those tasks).

## Hard rules

1. Work ONLY in your pair D:/MyNewProjects/_wt/harness/pi-<x>/{qflistudio,qfli_studio_core}.
   Never edit D:/MyNewProjects/qflistudio or D:/MyNewProjects/qfli_studio_core
   (the user's main trees with uncommitted work), except writing your own files
   under this task's reports/ dir.
2. Git: stay on your branch harness/pi-<x>. Commit with explicit paths only
   (`git add <paths>`). Never run reset, checkout --, restore, stash, clean,
   switch, rebase, merge, push or tag. No Co-Authored-By / Generated-with lines.
3. Local checks allowed: flutter pub get, dart format, flutter analyze (scoped
   to your files), node --check. Do NOT run flutter test, builds, emulators,
   VMs, WSL, servers or live agents. Write unit tests for cloud CI; do not run them.
4. Herdr: read-only commands only (`herdr --help`, `herdr agent list`,
   `herdr api ...` metadata). Never prompt, send-keys, start, attach or focus
   real panes; other agents are running there. In Git Bash prefix herdr with
   MSYS_NO_PATHCONV=1.
5. Never read, copy or print credentials, tokens, auth.json, .env values or
   real session-log contents. Session-log readers are code plus fixtures you
   write yourself.
6. Contract `lib/harness/harness_host.dart` is shared. Do not change it. If you
   must, describe the needed change in your report; root merges contract edits.
7. Reuse existing code (terminal/PTY, xterm vendor, remote_control, chat
   widgets, skill loader). Search before adding a dependency. If you add a
   pubspec dependency, name it in the report.
8. Chinese UI strings and docs follow the project's controlled-Chinese rules
   (AGENTS.md). Code comments match surrounding density.

## Deliverable protocol

- When implementation is complete and committed: write reports/pi-<x>.md
  (summary, commits, files, contract change requests, deps added, static check
  results, unverified acceptance items, risks), then create the empty file
  reports/pi-<x>.done. Then stop and wait.
- Later you will get a cross-check prompt and then a fix prompt. Follow them.

## Pi-A — local host (branch harness/pi-a)

Core `lib/harness/local/`:
- ProviderRegistry: built-ins claude, codex, pi, opencode, gemini, zcode, dsh,
  shell (platform default shell). Detect executables via user config path ->
  PATH -> common install dirs on Windows/macOS/Linux. User providers from
  `<appSupport>/qfli_harness_providers.json` (same schema as built-ins).
  Implements AC11.
- StudioMux: owns PTY sessions (ConPTY on Windows, forkpty on macOS/Linux).
  First inspect core's existing terminal/process code and reuse its PTY
  approach; follow process-lifecycle.md for shutdown. Bounded scrollback,
  resize, explicit stop.
- Log readers for Claude Code (~/.claude/projects), Codex (~/.codex/sessions),
  Pi (~/.pi/agent/sessions): parse jsonl into TranscriptEvent, tail-window
  for large files, map approvals/questions to requestId where the format
  allows. Read-only.
- LocalHarnessHost implements HarnessHost (kind local, id "local"): lists
  StudioMux sessions plus recent log-backed sessions; launch() starts a
  provider in StudioMux; open() returns a handle with terminal and, where a
  log exists, transcript. Desktop only; on mobile/web state = unsupported.
- Tests with fixtures for registry detection, user-config parsing, each log
  reader, and status mapping.

## Pi-B — Herdr host and remote host (branch harness/pi-b)

Core `lib/harness/herdr/` and `lib/harness/remote/`:
- HerdrHost implements HarnessHost (kind local, id "herdr", label "Herdr").
  Locate herdr executable (PATH, common dirs, user setting). Read
  `herdr agent list` / workspace / pane JSON (inspect `herdr --help`,
  `herdr agent --help`, `herdr api --help` for schemas; see
  https://herdr.dev/llms.txt). Map agent_status to HarnessSessionStatus;
  title from terminal_title_stripped / name; cwd; sourceRef = pane_id.
- Live view: run `herdr agent attach <pane>` inside a PTY (reuse the same PTY
  layer core already has; coordinate in your report if you need Pi-A's
  StudioMux). sendPrompt -> `herdr agent prompt`; keys -> send-keys.
  Status refresh driven by `herdr agent wait`/events, not tight polling.
- Herdr missing -> state unsupported plus install hint data for the UI.
- RemoteHarnessHost implements HarnessHost (kind remote) by wrapping the
  existing remote_control RemoteController (SessionView, HerdrController,
  CodexThreadView, Claude). Do not change the wire protocol, request IDs,
  reconnect/replay semantics. detach() releases subscriptions only; approvals
  only from explicit reply().
- Tests: herdr JSON parsing fixtures (use the field names seen in
  `herdr agent list` output), status mapping, remote adapter mapping with a
  fake controller.

## Pi-C — hub and Agents UI (branch harness/pi-c)

Core `lib/harness/hub/` and the Agents UI:
- HarnessHub (ChangeNotifier): registers hosts, current host, merged session
  list, launch menu from providers(). Hosts are injected; use a fake host for
  widget tests and previews.
- Agents UI lives in the EXISTING editor page Agents surface (no nested page,
  no second app shell; keep existing editor logic unchanged). Read how the
  editor page hosts Agents today before designing.
- Desktop: host switcher (local, Herdr, paired computers with online dot, add
  computer), session list grouped by provider with status chips and cwd,
  "new session" menu, session view with tabs Chat (reuse Studio message
  widgets and composer; approval/question buttons call reply()) and Terminal
  (reuse vendor/xterm and RemoteTerminalPane input layer).
- Mobile: list -> detail; terminal key bar Esc, Tab, Ctrl, Alt, arrows, paste
  (port from the remote_control module); only remote hosts and the studio
  host appear.
- Move pairing / account binding / revoke UI into Settings "设备与远程".
  Redirect the old RemoteComputerPage entry to the Agents surface. Do not
  delete remote_control internals other hosts depend on.
- Stop needs a confirmation dialog; closing a view calls detach().
- Widget tests for hub state, host switching, confirm-before-stop, key bar.
- Take screenshots only if a running desktop build already exists; do not
  build. Describe layouts in the report instead.

## Pi-D — skills, Trellis, studio host (branch harness/pi-d)

Core, around the existing Vibe agent and skill code:
- Skill discovery: project .agents/skills, .claude/skills, .pi/skills,
  .codex/skills and the same dirs under the user home; parse SKILL.md
  frontmatter (name, description), load body on demand; merge into the
  existing Vibe skill mechanism per vibe-skills.md; dedupe by name with
  project over user.
- Project instructions: load AGENTS.md (and CLAUDE.md if present) as project
  instructions for the built-in agent.
- Trellis: detect .trellis/workflow.md; Dart reader for tasks
  (.trellis/tasks/*/task.json), current task, developer, spec indexes;
  compact context injected at session start; desktop may call
  `python ./.trellis/scripts/get_context.py` and fall back to Dart parsing.
  Task panel: active tasks, current task, phase, prd/design/implement links.
  Slash commands /trellis:continue and /trellis:finish-work route to the
  same-named skills.
- StudioAgentHost implements HarnessHost (kind studio) over existing Vibe
  sessions so the built-in agent appears in the hub list. Do not change
  vibe_coding_controller behavior beyond the needed hooks.
- Tests with fixture projects for skill discovery, frontmatter parsing,
  Trellis task reading and context text.

## Integration rules (P4, Pi-A)

- In the integration worktrees, do NOT create merge commits. Rebuild the work
  as a linear series on top of the base: ONE commit per requirement/feature
  (e.g. provider registry, local PTY host, session-log readers, Herdr host,
  remote host, hub + Agents UI, mobile key bar, settings device page, skill
  discovery, Trellis context + task panel, studio agent host). Use
  cherry-pick --no-commit / checkout of paths from harness/pi-* branches into
  the integration worktree, then commit each feature with explicit paths.
- Conventional commit messages (feat(harness): ..., feat(agent): ...). No
  Co-Authored-By, no Generated-with, no AI names in messages.
- List the final commit series (hash + subject + requirement IDs) in
  reports/final-review.md.
