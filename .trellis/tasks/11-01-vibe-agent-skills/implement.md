# Implement

1. Read the parent prd.md, this prd.md and the relevant .trellis/spec/frontend files.
2. Write design.md (short) before code. Report to the root session if it changes a shared interface.
3. Implement in small steps. After each step run focused tests, then commit as type(scope): summary with explicit paths.
4. On finish, add a Result section here: commits, tests run, what was not verified.

## Result

Status: done for R1-R7. R8 waits on the protocol owner.

### Commits (sibling repo `qfli_studio_core`)

| Commit | Scope |
| --- | --- |
| `496242e` | skills loader, rules loader, `todo` / `use_skill` tools, loop guards, round budget |
| `684a490` | panel plan card, skill chips, Chinese tool labels, phone-width widget tests |
| `02b9c61` | `lib/vibe_coding/CONTRACT.md` update for the new members and tests |

Task repo `qflistudio`:

| Commit | Scope |
| --- | --- |
| `9d2c446` | `design.md` in this task directory |

### What shipped

- R1 `lib/vibe_coding/vibe_skills.dart`: front-matter parsing (`name`,
  `description`, YAML block scalars), discovery from `.qfli/skills`,
  `.claude/skills`, `.agents/skills`, packaged `assets/skills/`, first source
  wins, directory-name fallback, 12 KiB body cap, index capped at 40 entries and
  4 KiB. `use_skill` returns the body and records the name in `usedSkills`.
- R2 `lib/vibe_coding/vibe_rules.dart`: `AGENTS.md`, `CLAUDE.md`,
  `.qfli/rules.md`, 4 KiB per file and 8 KiB total, read on every `send`.
- R3 `assets/skills/{web-app-scaffold,bug-fix-loop,project-review}/SKILL.md`,
  registered through the existing directory-style asset entry in
  `pubspec.yaml` (`assets/skills/`), so a new skill needs no pubspec edit.
- R4 `lib/vibe_coding/vibe_plan.dart` plus the `todo` tool: atomic replacement,
  20 items max, one `doing`, duplicate ids and unknown states rejected, all
  `done` refused while the current round had a tool failure. `plan` is exposed
  on the controller and as a snapshot on `VibeToolCall.plan`.
- R5 `lib/vibe_coding/vibe_loop_guard.dart`: budget 12 base, 24 for a multi-step
  prompt, hard cap 30, `maxRounds` still pins the value when passed. Guards:
  third identical call (canonical JSON, key order ignored), two rounds without a
  new fact, read-before-edit against a snapshot taken at send start.
- R6 `write_file` on `index.html` appends a dependency-free Python structure
  check to the tool result. The `web-app-scaffold` skill carries the same check
  plus the acceptance rule.
- R7 read-before-edit uses only project-relative paths through
  `VibeProjectFiles.relative`, so the existing guard still bounds every path.
- UI: plan chip (`计划 n/m`), expandable item list with pending / doing / done,
  one chip per loaded skill, plan snapshot inside each `todo` transcript entry.

The constructor keeps every existing parameter. New behaviour arrives through
the optional `VibeAgentContext? context` and a nullable `maxRounds`.

### Tests run

- `flutter test --no-pub test/vibe_coding_controller_test.dart` 19 cases.
- `flutter test --no-pub test/vibe_coding_skills_test.dart` 11 cases.
- `flutter test --no-pub test/vibe_coding_plan_test.dart` 12 cases.
- `flutter test --no-pub test/vibe_coding_panel_test.dart` 11 cases (one at
  320 px, toggling the plan and collapsing the panel, no overflow).
- `flutter test --no-pub test/vibe_coding_tools_test.dart` and
  `test/vibe_editor_bridge_test.dart`, `test/vibe_send_coordinator_test.dart`
  still pass.
- `flutter analyze --no-pub lib test` reports no issues.
- `dart format` applied to every touched file.
- Shipped assets checked from disk: all three `SKILL.md` files parse with a name
  and a description.

### Not verified

- Live upstream run of `做一个待办事项小网站`. It needs the debug key from
  `C:\Users\lichengyu\.qfli-debug.env` and belongs to the owner of the real-API
  harness. No credential was read or written by this work.
- OHOS device build of the panel. The widget tests cover layout, but not the
  soft-keyboard frame on a real device.
- `vibe_web_tools.dart` (R8). The file does not exist yet. Once the protocol
  owner publishes it, the controller needs one extra tool case and one spec
  entry. Nothing else in this scope changes.

### Cross-owner notes

- Open item for the owner of `vibe_coding_controller.dart`: concurrent
  `tool_calls` in one assistant message can trip the read gate on a file the
  same batch just created. See `handoff.md` in this directory for the fix shape.
  Sequential turns are unaffected, and the debug upstream sends one call per
  turn today.
- `vibe_coding_controller_test.dart` assertion on the tool list changed from 5
  to 7 entries, and the round-limit test now uses distinct real reads because
  the no-progress guard answers earlier. Both are test-value updates.
