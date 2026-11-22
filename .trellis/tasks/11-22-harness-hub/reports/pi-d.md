# Pi-D report — skills, Trellis, studio host

Branch: `harness/pi-d` in both worktrees.
Core base: `f9b6485` (harness hub contract). App base: `d31ad29`.
All commits are in `D:/MyNewProjects/_wt/harness/pi-d/qfli_studio_core`. The app
worktree has no source change; only `flutter pub get` regenerated platform
plugin registrants (see Risks).

## Summary

Delivered the Pi-D section of `reports/brief.md`:

1. Skill discovery now covers `.agents/skills`, `.claude/skills`,
   `.pi/skills` and `.codex/skills` under both the project and the user home,
   in addition to the existing `.qfli/skills`. `SKILL.md` frontmatter is
   parsed for name and description; the body is read on demand.
2. Trellis support: a bounded workflow entry in the project rules, a Dart
   reader for `.trellis` (developer, tasks, current task, spec indexes), a
   compact session context, a task panel model plus a read-only panel view, and
   `/trellis:continue` / `/trellis:finish-work` routing.
3. `StudioAgentHost` exposes the built-in Vibe sessions through the harness
   contract without changing controller behaviour.

## Commits

| Commit | Subject |
| --- | --- |
| `56da9af` | feat(agent): discover project skills and inject Trellis context |
| `db47ef6` | fix(agent): read enough bytes for multi-byte skill bodies |
| `ec110b2` | fix(agent): gate Trellis slash commands on a real workflow |

## Files

### New

| File | Purpose |
| --- | --- |
| `lib/trellis/trellis_project.dart` | `TrellisProject`, `TrellisTask`, `TrellisTaskPhase`, `TrellisTaskDoc`, `TrellisSpecIndex`, `hasWorkflow`, `taskNameOfRef`, bounded `readTextHead` |
| `lib/trellis/trellis_context.dart` | `buildTrellisContext`, `clampTrellisContext`, `compactScriptContext`, `TrellisContextLoader`, `VibeTrellisContextSource` |
| `lib/trellis/trellis_commands.dart` | `TrellisSlashCommand`, `kTrellisSlashCommands`, `matchTrellisSlashCommand`, `trellisCommandArguments`, `routeTrellisSlashCommand`, `clampTrellisCommand` |
| `lib/trellis/trellis_panel.dart` | `TrellisTaskPanel`, `TrellisPanelTask`, `buildTrellisTaskPanel` |
| `lib/trellis/trellis_task_panel_view.dart` | `TrellisTaskPanelView` read-only panel widget |
| `lib/harness/studio/studio_agent_host.dart` | `StudioAgentHost`, `StudioSessionHandle`, `kStudioHostId`, `kStudioProviderId` |
| `test/trellis_project_test.dart` | detection, task reading, current task, panel |
| `test/trellis_context_test.dart` | context text, script compaction, rule entry, slash commands |
| `test/vibe_skill_discovery_test.dart` | new skill directories, lazy bodies, frontmatter |
| `test/studio_agent_host_test.dart` | host identity, session list, status mapping, open/reply/stop/detach, launch |
| `test/support/trellis_fixture.dart` | shared fixture project builder |

### Modified

| File | Change |
| --- | --- |
| `lib/vibe_coding/vibe_skills.dart` | `VibeSkillSource.pi` / `.codex`; `userSkillDirNames` / `projectSkillDirNames`; `userSkillsDirs`; `lazyBodies`; `VibeSkill.bodyPath` / `withoutBody` / `resolveBody`; `readVibeSkillBody`; `_sourceFor` matches the last two path segments |
| `lib/vibe_coding/vibe_rules.dart` | `kVibeTrellisRuleEntry`, `hasTrellisWorkflow`, entry reserved before rule files |
| `lib/vibe_coding/vibe_coding_controller.dart` | `VibeProjectAgentContext` implements `VibeTrellisContextSource`; `_loadTrellis`, `_routeSlashCommand`; Trellis text merged into the `projectRules` section; `use_skill` awaits `resolveBody` |
| `lib/vibe_coding/vibe_agent_facade.dart` | `AgentRuntime.skills()` loads metadata only (`lazyBodies: true`) |
| `test/vibe_coding_skills_test.dart` | three project-directory tests now pass `includeUserSkills: false` so the host home cannot change their result |

## Behaviour

### Skill discovery

- Project order: `.qfli/skills` → `.claude/skills` → `.agents/skills` →
  `.pi/skills` → `.codex/skills`. First hit wins inside the project.
- User order: the same five directories under `$HOME` (or `%USERPROFILE%`).
  User skills override built-ins and lose to project skills.
- `lazyBodies: true` reads only 16 KiB per `SKILL.md` for metadata. The body
  is read by `VibeSkill.resolveBody()` and capped at
  `kVibeSkillMaxBodyChars` with a visible marker.
- Reads are 4× the character cap in bytes, because one UTF-8 character can be
  4 bytes. The old 2× factor silently truncated Chinese bodies without the
  marker (`db47ef6`).
- A directory symlink is rejected, a missing `SKILL.md` is skipped, an empty
  description is not a skill.

### Project instructions

`AGENTS.md`, `CLAUDE.md` and `.qfli/rules.md` were already merged by
`loadVibeRules`. The Trellis entry now reserves its budget before those files,
so a long `AGENTS.md` cannot evict it. The entry only names files to read; it
never injects workflow, spec or skill bodies.

### Trellis reading

- Detection requires a normal `.trellis` directory with a normal, non-empty
  `workflow.md`. Links and empty files are rejected.
- Tasks come from `.trellis/tasks/*/task.json`, capped at 64 KiB each. A
  broken or title-less file is skipped without failing the project.
- The current task comes from the newest `last_seen_at` entry in
  `.trellis/.runtime/sessions/*.json`, or from an explicit
  `currentTaskName` override.
- Phase mapping: `planning` → 1.1, `in_progress` → 2.1, `completed`/`done` →
  3.3, `archived` → archived, anything else → unknown.
- Spec indexes are the `.trellis/spec/<layer>/index.md` files that exist.

### Context injection

`VibeCodingController` loads the Trellis context once per session, on the first
`send`, and appends it to the `projectRules` section of the system prompt. It
is clamped to 1,600 characters (`kTrellisContextMaxChars`) and 8 listed tasks.

`TrellisContextLoader(preferPython: true)` runs
`python ./.trellis/scripts/get_context.py` through `ProcessSupervisor` with an
8-second bound, compacts the output, and falls back to Dart parsing when the
script is missing, slow or fails. The default is Dart-only, so no process is
started by the ordinary editor path.

### Slash commands

`/trellis:continue` and `/trellis:finish-work` resolve in this order:

1. a visible skill named `trellis-continue` / `trellis-finish-work`;
2. `.pi/prompts/trellis-*.md` or `.claude/commands/trellis/*.md` in the
   project;
3. the bounded built-in instruction text.

Expansion rewrites the last user history entry; the chat bubble keeps what the
user typed. The command is ignored outside a Trellis project.

### Studio host

`StudioAgentHost` implements `HarnessHost` with `kind: studio`, `id: studio`,
label `内置 Agent`.

- `watchSessions()` emits `AgentSessionStore.sessionsOf(projectId)` mapped to
  `HarnessSessionInfo`, and re-emits on session-store and runtime-live changes.
- Status mapping: `running`/`queued` → working, `awaitingApproval` → blocked,
  `finishedUnread` → done, `idle` → idle, `failed` → unknown. A background
  failure is not reported as done.
- Capabilities: transcript, prompt, approve, stop. No raw terminal.
- `open()` wraps the shared `AgentFacade`; the transcript stream replays the
  current messages then appends, capped at 200 entries. A pending write
  approval becomes a `TranscriptEvent` with `requestId` and `allow`/`deny`
  options; `reply()` maps `allow`/`yes`/`approve` to acceptance and anything
  else to rejection.
- `detach()` removes listeners only. `stop()` cancels the run; the session
  record and its history stay.
- `launch()` creates a session for the project and opens it.

## Contract change requests

None. `lib/harness/harness_host.dart` is unchanged.

Two members of the contract are intentionally left unused by this host and may
warrant a comment in the contract, not a change:

- `HarnessSessionHandle.terminal` is always null for the studio host. The
  built-in agent has no raw PTY; its output is structured tool results.
- `HarnessReply.requestId` is not matched against a live request. The Vibe
  facade has at most one pending write approval, so a stale id is a no-op
  rather than an error.

## Dependencies

None added. Reused `package:path`, the existing `ProcessSupervisor`, the
existing `VibeSkillLibrary` and the existing `AgentRuntime` /
`AgentSessionStore` contract.

## Static checks

Run in `_wt/harness/pi-d/qfli_studio_core`:

```text
flutter pub get                 # resolved, no dependency change
dart format lib test            # clean
dart analyze lib test           # 2 infos, both pre-existing on untouched files
```

Remaining infos, both present on the base commit and not caused by this work:

- `lib/chat/composer_card.dart:346` — `curly_braces_in_flow_control_structures`.
- `lib/harness/harness_host.dart:6` — `unnecessary_import` (`dart:typed_data`).

Run in `_wt/harness/pi-d/qflistudio`:

```text
flutter pub get                 # resolves qfli_studio_core to this worktree
flutter analyze lib             # 1 info: pre-existing unnecessary_import in lib/main.dart
```

Per the brief, `flutter test` was not run. The new tests are written for cloud
CI:

```text
flutter test --no-pub test/trellis_project_test.dart test/trellis_context_test.dart \
  test/vibe_skill_discovery_test.dart test/studio_agent_host_test.dart \
  test/vibe_coding_skills_test.dart
```

## Unverified acceptance items

These are stated as unverified, not as passing:

- AC10 (the built-in agent can call `SKILL.md` from the project skill
  directories): the loader and `use_skill` path are covered by tests, but no
  test ran here and no live model round happened.
- AC9 (current task and phase shown for a Trellis project): the reader, the
  context text and the panel model are unit-tested; the `TrellisTaskPanelView`
  widget has no widget test and was never rendered.
- AC12 (automatic checks for the session model, Herdr parsing, skill discovery
  and Trellis reading): only the skill and Trellis parts are mine; they are
  written but not executed.
- `TrellisContextLoader(preferPython: true)` is never exercised against a real
  Python process. Only the "script missing → Dart fallback" path is covered.
- The studio host was never rendered in the Agents surface; Pi-C owns that
  wiring.

## Risks

- **Skill discovery now reads five user directories.** A developer machine with
  skills under `~/.claude/skills` or `~/.codex/skills` sees them in every
  project. Three existing tests were made deterministic with
  `includeUserSkills: false`; any new test that builds `VibeSkillLibrary`
  without a bundle or user-dir argument is host-dependent.
- **`VibeSkillLibrary` still defaults to `bundle ?? rootBundle`.** In a plain
  `test()` without a widget binding, accessing `rootBundle` throws during
  construction. New tests must pass a bundle; the pre-existing tests already
  did.
- **Current-task detection reads `.trellis/.runtime/sessions/*.json`.** Those
  files are per-session task pointers, not agent transcripts, and only
  `platform`, `last_seen_at` and `current_task` are read. With several agents
  in one repository the newest pointer wins, which may not be the session the
  user is looking at. An explicit override is available
  (`TrellisProject.load(currentTaskName:)`).
- **`launch()` leaves an empty session record when the runtime is signed out.**
  `AgentSessionStore.create` runs before `AgentRuntime.open` can throw
  `AgentLoginRequired`. The record is harmless but visible in the list.
- **`stop()` on a studio session cancels the run, it does not delete the
  session.** The hub UI must label it accordingly; deleting history is a
  separate action.
- **`flutter pub get` in the app worktree regenerated platform plugin
  registrants** (`linux/`, `macos/`, `windows/`). They are left uncommitted;
  the app itself has no source change.
- **`TrellisTaskPanelView` is unrendered.** It compiles and is deliberately
  dependency-free, but layout at narrow widths is unverified.

## Assumptions

- "Phase" in the task panel means the task status mapped onto the three
  workflow phases, not the position inside `implement.md`.
- The built-in agent is a per-project host: `StudioAgentHost` is constructed
  with one `projectId` and `projectRoot`, matching how the editor page scopes
  its sessions.
- Slash command expansion belongs in the controller, so every host (editor
  page, hub, future surfaces) gets it without duplicating the routing table.
- The Trellis rule entry text is copied from the frozen integration Core
  wording (`_wt/studio-git-integration/qfli_studio_core`) so a merge does not
  produce two different prompts.

---

# Fixes after review (`reports/check-c.md`)

Reviewer: Pi-C. Fix commit: `d73db50` on `harness/pi-d` (13 files,
+731/−78). Contract file untouched (`git hash-object` matches the base
`0a26aab6`). App worktree still has no source commit.

Check results after the fixes (core worktree, scoped):

```text
dart format lib test                 # clean
dart analyze lib test                # 2 infos, both pre-existing
dart analyze lib/harness/studio test/studio_agent_host_test.dart   # no issues
```

The two remaining infos are unchanged from the base commit and live in files
this branch does not touch: `lib/chat/composer_card.dart:346` and
`lib/harness/harness_host.dart:6`. `flutter test` was not run, per the brief.

## Finding-by-finding

| # | Severity | Status | What changed |
| --- | --- | --- | --- |
| 1 | 中高 (security) | **固定** | Two-switch gate |
| 2 | 中 | **固定** | `open()` ownership check |
| 3 | 中 | **固定** | `sendPrompt` throws when busy |
| 4 | 中 | **固定** | One status map, `liveChanges` listener |
| 5 | 低-中 | **固定** | `reply()` checks `requestId` + options |
| 6 | 低-中 | **固定** | Directory listing + skill/rule reads guarded |
| 7 | 低 | **固定** | `providers()` reflects sign-in |
| 8 | 低 | **固定** | `launch()` validates, no orphan record |
| 9 | 低 | **部分固定** | Text compare before building; index cursor rejected |
| 10 | 低 | **固定** | Failure becomes a system transcript event |
| 11 | 低 | **固定** | Cycle guard, non-null return, `isEmpty` |
| 12 | 低 | **固定** | Controller context uses `lazyBodies` |
| 13 | 备注 | **固定** | Single `hasTrellisWorkflow` implementation |
| 14 | 备注 | **驳回** | Spec owned by another task, main tree only |
| 15 | 备注 | **固定（文档）** | `stop()` semantics documented; UI copy is Pi-C |
| 16 | 备注 | **固定** | Injectable skill library; test no longer reads `$HOME` |
| 17 | 备注 | **部分固定** | 4 new test files/cases for the top gaps |

## 1 (fixed) — executation of the project script needs consent

`lib/trellis/trellis_context.dart` now has a second switch:

```dart
const TrellisContextLoader({
  this.preferPython = false,
  this.allowProjectScript = false,
  ...
});

bool get runsProjectScript => preferPython && allowProjectScript;
```

`load()` only calls `_runScript` when `runsProjectScript` is true, so opening a
repository still cannot execute its Python. `_runScript` now also rejects a
`get_context.py` that is not a plain file (`typeSync(..., followLinks: false)`),
so a symlink planted in `.trellis/scripts` cannot redirect execution to another
file. `trellis_project.dart`'s header no longer claims the same thing as the
script path; it now states the file never executes anything and points at the
two switches.

New tests (no process is started in any of them):

- `does not run the project script without explicit consent` — plants a
  `get_context.py` that would write a marker file, loads with
  `preferPython: true` only, asserts the marker does not exist and the Dart
  context is still produced.
- `runs the script only when both switches are on` — truth table for
  `runsProjectScript`.
- `ignores a symlinked get_context.py` — with both switches on, a symlink is
  refused and the Dart path still returns usable context.

What is still open: the success path of `_runScript` against a real Python has
no test (it needs a Python interpreter and a fixture script, which the brief
disallows running here). Until root wires a desktop setting for
`allowProjectScript`, the script path stays off.

## 2 (fixed) — `open()` can cross projects

`lib/harness/studio/studio_agent_host.dart`:

```dart
final meta = _sessions.metaOf(sessionId);
if (meta == null || meta.projectId != projectId) {
  throw ArgumentError.value(sessionId, 'sessionId', '会话不属于本项目');
}
```

Tests: `refuses to open a session of another project`,
`refuses an unknown session id`.

## 3 (fixed) — `sendPrompt` silently drops input

Before calling the facade, the handle now refuses when the state is
`running`, `cancelling` or `awaitingApproval`:

```dart
if (_facade.state != AgentRunState.idle &&
    _facade.state != AgentRunState.failed) {
  throw StateError('会话正在运行，请先停止或等待本轮结束');
}
```

Test: `refuses to send a prompt while the session is busy` (asserts the text
never reached the facade).

## 4 (fixed) — handle status and the duplicated mapping

Both `StudioAgentHost._statusOf` and the handle's `_mapStatus` are gone; a
single top-level `mapStudioLiveStatus(AgentLiveStatus)` is the only mapping.
The handle now also listens to `_runtime.liveChanges` and drops that listener
in `detach()`, so queue entry/exit and the unread `finished`/`failed` states
reach `handle.status` even when the facade does not notify.

Test: `status follows the runtime even without a facade notification` (only
`runtime.notifyLive()`; no facade notification).

## 5 (fixed) — `reply()` ignored `requestId`

```dart
final key = _approvalKey;
if (key == null || reply.requestId != key) return;
```

Options are now explicit: `allow`/`yes`/`approve`/`always` accept,
`deny`/`no`/`reject` reject, anything else throws `ArgumentError` instead of
turning into a silent rejection of a real write.

Tests: `ignores a reply with a stale request id` (the pending approval must
survive) and `rejects an unknown choice instead of silently denying`. The
existing `deny` test was updated to pass the real `requestId`.

## 6 (fixed) — one unreadable skill directory killed the session

`lib/vibe_coding/vibe_skills.dart` wraps the listing:

```dart
try {
  entries = await Directory(dir).list(followLinks: false).toList();
} on FileSystemException {
  return const [];
}
```

`vibe_coding_controller.dart` also stops trusting the context: `_skills` and
`_rules` now come from `_readSkills()` / `_readRules()`, which catch and
degrade to an empty list / empty string. A broken skill or rule read no longer
leaves `phase` stuck at `running`.

Test: `a failing skill or rule read does not stall the session`.

## 7 (fixed) — `providers()` always said available

`StudioAgentHost` takes an optional `signedIn` callback (default: assumed
signed in, so nothing changes for callers who do not wire it yet) and reports
`available: _signedIn()`. Root should pass the real token check when wiring the
host.

Test: `reports the provider as unavailable when signed out`.

## 8 (fixed) — `launch()` created a record before authenticating

`launch()` now validates first (provider id, empty `args`, `cwd` inside the
project root) and deletes the record it just created if `open()` throws:

```dart
final meta = await _sessions.create(projectId, title: request.title);
try {
  return await open(meta.id);
} on Object {
  await _sessions.delete(meta.id);
  rethrow;
}
```

A `cwd` outside the project or a non-empty `args` throws `UnsupportedError`
rather than being ignored.

Tests: `leaves no session record when the agent is signed out`,
`refuses a working directory outside the project`,
`refuses launch arguments instead of ignoring them`. The existing launch test
now passes the project root as `cwd`.

## 9 (partially fixed) — full transcript re-scan per change

`_onFacadeChanged` now compares `_lastText[message.id]` with the message text
before constructing a `TranscriptEvent`, so a streaming turn allocates one
event per changed message instead of one per message plus one per delta. The
review's suggested index cursor is **rejected**: `AgentFacade.messages` is a
plain list the facade may rewrite (retry replaces the tail, `loadEarlier`
prepends), so a monotonic index would silently skip messages. The residual
cost is O(n) map lookups per notification, not O(n) allocations.

## 10 (fixed) — failures were invisible

When the runtime reports `failed` and `AgentFacade.lastError` is non-empty, the
handle publishes one `TranscriptRole.system` event with a stable id
(`error:<hash of text>`). The same error is published once; a new error text
publishes again. It is also evaluated at open time, so reopening a failed
session still shows the reason.

Test: `publishes a system entry when the run fails`.

## 11 (fixed) — panel recursion and return type

`lib/trellis/trellis_panel.dart`:

- `append()` keeps a `seen` set and returns early on a revisit, so
  `children` pointing at each other can no longer overflow the stack.
- `buildTrellisTaskPanel` returns a non-nullable `TrellisTaskPanel`; the doc
  comment explains that a non-Trellis project never reaches it because
  `TrellisProject.load` already returns null.
- `isEmpty` is now `currentTask == null && activeTasks.isEmpty &&
  specIndexes.isEmpty`.

Tests: `survives a task graph whose children point at each other`,
`a project with only spec indexes is not empty`. The existing panel test no
longer needs the `!`.

## 12 (fixed) — controller still read every skill body

`VibeProjectAgentContext.skills()` now builds the library with
`lazyBodies: true`, the same as `VibeAgentRuntime.skills()` and the sidebar.
`use_skill` already resolved bodies on demand, so nothing else had to move.
Covered indirectly by `injects the Trellis context once per session` (the
context is exercised through the same `VibeProjectAgentContext`).

## 13 (fixed) — two `hasTrellisWorkflow` implementations

`lib/vibe_coding/vibe_rules.dart` no longer has its own detection:

```dart
bool hasTrellisWorkflow(String projectRoot) =>
    TrellisProject.hasWorkflow(projectRoot);
```

Important consequence: the read limit is now the 4 KiB one from
`TrellisProject.hasWorkflow`, not the old `kVibeMaxRuleFileChars * 2` (8 KiB).
`TrellisProject` does not import `vibe_rules.dart`, so there is no cycle. The
existing rule-budget tests still pass unchanged because they only need a
non-empty `workflow.md`.

## 14 (rejected) — `vibe-skills.md` not updated

Rejected, not forgotten. `.trellis/spec/frontend/vibe-skills.md` exists only in
the main tree (`D:/MyNewProjects/qflistudio`), belongs to the
`11-01-vibe-agent-skills` task and is marked `Draft` as that task's product.
Editing it from this branch would write outside the worktree pair, which the
brief forbids, and would race the owning task. The implementation is still the
source of truth for the five directories and the two new enum values; root
should sync the spec when merging. The drift is listed again in the risk
section above.

## 15 (fixed as documentation) — `stop()` semantics

The contract says "Ends the session". The implementation only cancels the
current turn. Rather than change behaviour (deleting a conversation is a
different action), `StudioSessionHandle.stop()` now documents that it stops the
round only and that UI copy must say “停止本轮”, not “结束会话”. Pi-C owns that
string; this branch cannot change the widget.

## 16 (fixed) — a test depended on the developer home directory

`VibeAgentRuntime` accepts an optional `skillLibraryFactory`, and
`test/vibe_agent_facade_test.dart` injects a library with
`includeUserSkills: false` and an empty asset bundle. `skills lists project
skills for the sidebar` no longer scans `$HOME`, so its result and runtime no
longer depend on the machine. Production behaviour is unchanged (same
`VibeSkillLibrary` with `lazyBodies: true`).

## 17 (partially fixed) — test gaps

Added:

- `test/vibe_trellis_session_test.dart` — controller integration: the Trellis
  context lands in the system prompt, is read once per session, skills/rules
  are re-read per send, `/trellis:continue` rewrites **this** user message
  while the chat bubble keeps the typed text, a failing skill/rule read does
  not stall the run, and a non-Trellis project gets no context.
- `test/trellis_context_test.dart` — the script gate (3 cases).
- `test/trellis_project_test.dart` — panel cycle guard and spec-only `isEmpty`.
- `test/studio_agent_host_test.dart` — project boundary, busy prompt, stale
  request id, unknown option, failure event, live-only status change, signed
  out launch and availability, `cwd`/`args` rejection.

Still missing (stated as unverified, not as done):

- `_runScript` success/non-zero/timeout against a real Python process.
- `VibeAgentRuntime.skills()` returning metadata only (the `lazyBodies` flag is
  exercised by library tests, not by an assertion on the runtime).
- Multi-subscriber `watchSessions()` on the studio host and
  `dispose()`-then-`open()` (the second is covered by the host's `StateError`
  guard, but without a test).
- `TrellisTaskPanelView` still has no widget test and has never been rendered.

## Integration notes for root (unchanged by this fix)

1. Two “内置 Agent” sources will list the same sessions (this host and Pi-C's
   surface). Pick one registration.
2. `StudioAgentHost.dispose()` is terminal; construct one per hub, not an app
   singleton.
3. The Trellis rule entry duplicates uncommitted work in
   `_wt/studio-git-integration`; keep one copy when rebuilding linearly.
   `vibe_rules.dart` now re-exports the detection from `TrellisProject`, so the
   merge must take that file's version of the check too.
4. `HarnessHosts.registerDefault` is still unwired in the app worktree.
5. The 7 platform registrant files from `flutter pub get` stay uncommitted.

One addition from this fix: when wiring the host, pass `signedIn` so the
provider list reflects the token, and keep `allowProjectScript` off until a
desktop setting exists.
