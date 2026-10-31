# Design: Vibe agent maturity

Owner: Pi-A. Files I touch live in `../qfli_studio_core/lib/vibe_coding/`
(A scope) and its focused tests. `lib/editor/**`, `api_client.dart`,
`vibe_web_tools.dart` and `lib/pages/**` belong to other owners.

## 1. Modules

| File | Owner | Role |
| --- | --- | --- |
| `vibe_skills.dart` | A (new) | Parse `SKILL.md`, discover skill roots, cap and compose the prompt index |
| `vibe_rules.dart` | A (new) | Read `AGENTS.md` / `CLAUDE.md` / `.qfli/rules.md` with a byte cap |
| `vibe_plan.dart` | A (new) | `todo` tool spec, argument parsing, `VibePlanItem` snapshot |
| `vibe_loop_guard.dart` | A (new) | Repeated-call, no-progress and read-before-edit guards |
| `assets/skills/**` | A (new) | `web-app-scaffold`, `bug-fix-loop`, `project-review` |
| `vibe_models.dart` | A | Adds `todo`/`use_skill` names, `VibePlanItem`, plan on `VibeToolCall` |
| `vibe_tools.dart` | A | Adds the two new tool specs next to the existing five |
| `vibe_coding_controller.dart` | A | Loads skills and rules, injects guards, round budget, plan state |
| `vibe_coding_widgets.dart` | A | Chinese labels for `todo` and `use_skill` |
| `vibe_coding_panel.dart` | A | Live plan card above the transcript |
| `test/vibe_coding_skills_test.dart`, `test/vibe_coding_plan_test.dart` | A | Focused unit tests |
| `pkg assets:` entry in `qfli_studio_core/pubspec.yaml` | A | Registers `assets/skills/`. No other line changes |

Shared surface stays additive. The constructor keeps its exact signature. New
behaviour arrives through an optional `VibeAgentContext? context` parameter and
through async loading inside `send()`. `CONTRACT.md` gains a section for the new
members.

## 2. Skill loading (R1)

Discovery order, first match per name wins:

1. `<project>/.qfli/skills/<dir>/SKILL.md`
2. `<project>/.claude/skills/<dir>/SKILL.md`
3. `<project>/.agents/skills/<dir>/SKILL.md`
4. packaged `assets/skills/<dir>/SKILL.md`

Frontmatter is the leading `---` block. Only `name` and `description` are read.
Missing `name` falls back to the directory name. Entries without a description
are skipped, because the model cannot choose an invisible skill. The body above
12 KiB is truncated and marked. The index is sorted by name, so the prompt is
stable across runs. A hard cap of 40 entries and 4 KiB of index text bounds the
prompt cost. Package assets are read once (cache) and filtered by the current
project `language`, so a Python project is not offered a web scaffold.

`.qfli` is a protected path for file tools. Reading `.qfli/skills` therefore
uses only the skill loader, never `VibeProjectFiles`, which keeps the path guard
untouched.

`use_skill {name}` returns the body. Unknown names return an error listing the
visible names. Every successful call is recorded in
`controller.usedSkills` (ordered, unique) so the panel can show skill use.

If the project has no directory hint and the prompt mentions a site, page,
HTML or CSS, the index marks `web-app-scaffold` as recommended. This is a
prompt hint only. It never forces a tool call.

## 3. Rules (R2)

Read `AGENTS.md`, `CLAUDE.md`, `.qfli/rules.md` from the project root, in that
order, skipping missing files and refusing symlinks. Each file contributes at
most 4 KiB and the whole block at most 8 KiB. Overflow is cut at a line
boundary and marked `（规则已截断）`. The block is read at `send()` time so a rule
edit applies without rebuilding the session. Rules are injected as a system
message after the base system prompt, before the skill index.

## 4. Plan tool (R4)

`VibePlanItem {id, title, status}` with `status ∈ {pending, doing, done}`.
`todo` accepts `items: [{id?, title, status?}]` and replaces the whole plan, so
the model cannot leave stale steps behind. The controller keeps
`List<VibePlanItem> plan` (unmodifiable) and attaches the plan snapshot to the
`todo` tool entry so the transcript shows history. The tool result reports the
counts and all item titles, which lets the model see the real state.

Guards:

- Up to 20 items, title up to 120 characters, ids defaulted to `1..n`.
- At most one `doing` item. Extra `doing` items are rejected with an error
  instead of being silently normalized.
- `status` strings outside the enum are rejected.
- A plan that claims everything `done` while earlier rounds of this `send` had
  tool failures is returned as an error, so the agent cannot close a task while
  its own last checks were red.

## 5. Loop hardening (R5)

Round budget by task size: base 12, plus 12 when the prompt mentions several
deliverables (`网站`、`页面`、`项目`、`应用`、`site`、`app`、`project` or an explicit
list), capped at 30. `maxRounds` in the constructor stays as the value used when
a caller passes it. The default becomes the computed budget.

Guards, all evaluated per round, all reported through a tool error so the model
sees a real failure:

1. Repeated identical call: the same tool name and canonicalized arguments three
   times in one `send` is refused. The result text tells the model to change the
   approach.
2. No progress: two consecutive rounds whose file tools produced no successful
   write or edit and whose `run_command` produced no exit-code change stop the
   run with `lastError = '连续两轮没有进展…'`.
3. Read-before-edit: `write_file` / `edit_file` on an existing file that this
   `send` never read is refused with a pointer to `read_file`. Files created by
   this `send` are exempt.

Guard rejections do not count as progress, so a model that loops on a guard
still hits rule 2 instead of consuming the whole budget.

## 6. Self verification (R6)

Verification is prompt-level plus a real check:

- The system prompt states that a web deliverable is done only after
  `list_files` shows the files and `run_command` validates them, and that a
  claim without a tool result is a lie.
- `run_command` over a project with `index.html` gets an appended, reported
  hint in the tool result when the model skipped the file list (the hint states
  the files were not listed, it does not claim success).
- The `web-app-scaffold` skill body carries the exact file set and a
  `python3 -m http.server` smoke command, so structure does not depend on the
  model's memory.

## 7. Compatibility and rollout

- Existing tests keep passing: five old tools keep their names and schemas. New
  tools are additive. `vibeToolSpecs()` grows from 5 to 7 entries, so the
  existing assertion on `hasLength(5)` in `vibe_coding_controller_test.dart`
  changes to 7. That is a test-value update, not a behaviour change.
- No new package dependency. `path` and `flutter/services` (root bundle) already
  exist.
- A missing `assets/skills/` in a host App degrades to project-only skills.
- No credential path: the debug key is never read by this scope. Live upstream
  verification is D's harness.

## 8. Validation plan

- `flutter test test/vibe_coding_skills_test.dart test/vibe_coding_plan_test.dart test/vibe_coding_controller_test.dart test/vibe_coding_tools_test.dart test/vibe_coding_panel_test.dart`
- `flutter analyze lib/vibe_coding lib/editor/vibe_editor_bridge.dart`
- Phone-width widget test for the plan card (320 px, no overflow).
