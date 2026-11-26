# Vibe agent skills, rules, plan and loop guards

## 1. Scope / Trigger

Apply this contract when adding a skill, changing skill discovery, editing the
project-rule merge, the plan tool, or the round budget and repeat guards. The
source of truth is `qfli_studio_core/lib/vibe_coding/vibe_skills.dart`,
`vibe_rules.dart`, `vibe_plan.dart` and `vibe_loop_guard.dart`, owned by the
`vibe-agent-skills` task. The acceptance side is `vibe-e2e.md`.

Status: `Draft`. All four files exist and are imported by the controller. The
task has not marked the surface frozen. Re-read the files before coding against
this page.

The Trellis rule entry described below is frozen in the integration Core at
`D:/MyNewProjects/_wt/studio-git-integration/qfli_studio_core`. It does not claim
that the planning-root App resolves to this Core or that a release contains it.

## 2. Signatures

```dart
// vibe_skills.dart
VibeSkill? parseVibeSkill(String text, {required String fallbackName, required VibeSkillSource source});
enum VibeSkillSource { user, projectQfli, claude, agents, builtIn }
const int kVibeSkillMaxBodyChars = 12 * 1024;
const int kVibeMaxSkillEntries = 40;
const int kVibeMaxSkillIndexChars = 4 * 1024;
const Map<String, Set<String>> kVibeBuiltInSkillLanguages;   // '*' = 全部语言

// vibe_rules.dart
String loadVibeRules(String projectRoot);
const List<String> kVibeRuleFiles = ['AGENTS.md', 'CLAUDE.md', '.qfli/rules.md'];
const int kVibeMaxRuleFileChars = 4 * 1024;
const int kVibeMaxRulesChars = 8 * 1024;

// vibe_plan.dart
enum VibePlanStatus { pending, doing, done }
const int kVibeMaxPlanItems = 20;
const int kVibeMaxPlanTitleChars = 120;

// vibe_loop_guard.dart
const int kVibeBaseRounds = 12;
const int kVibeMaxRoundBudget = 30;
const int kVibeRoundsPerExtraTask = 12;
const int kVibeRepeatLimit = 3;
const int kVibeNoProgressRounds = 2;
```

## 3. Contracts

- `SKILL.md` frontmatter is a leading `---` block carrying `name` and
  `description`. A file without a description is not a skill.
- Project skills override user skills, which override built-in skills. Project
  discovery checks `.qfli/skills`, `.claude/skills`, then `.agents/skills`. The
  first hit within the project wins. User skills come from `~/.qfli/skills`.
- The prompt carries only the index: name plus description. It is capped at
  `kVibeMaxSkillIndexChars` and `kVibeMaxSkillEntries`. A full body enters the
  conversation only when the model asks for it, and is then truncated at
  `kVibeSkillMaxBodyChars` with a visible flag.
- Built-in skills with `'*'` apply to every language. A language-scoped skill is
  hidden from projects of other languages.
- Project rules merge in `kVibeRuleFiles` order. Each file is capped at
  `kVibeMaxRuleFileChars` and the merged text at `kVibeMaxRulesChars`, truncated
  by line with a marker.
- A non-link `.trellis` directory with a normal, nonempty `workflow.md` enables
  the Trellis rule entry. Detection reads a bounded head. It does not inject
  workflow content, spec files or skill bodies.
- The entry tells the Agent to read `.trellis/workflow.md`, the applicable
  package/layer spec index and active task documents before editing. Skills
  still use the ordinary index and `use_skill` path. This is prompt guidance,
  not a new tool or a permission boundary.
- Reserve the entry before merging existing rules. The entry and rule files
  share the 8,192-character total. Existing rule files retain their order and
  4,096-character individual cap. Append a remaining-files notice only if it
  fits the available budget.
- The plan is replaced as a whole on each `todo` update. Stale steps never
  survive. Items are capped at `kVibeMaxPlanItems`, titles at
  `kVibeMaxPlanTitleChars`.
- The round budget scales with the plan: `kVibeBaseRounds` plus
  `kVibeRoundsPerExtraTask` per extra task, clamped to `kVibeMaxRoundBudget`.
- The loop guard stops a task when the same call repeats `kVibeRepeatLimit`
  times or produces `kVibeNoProgressRounds` rounds without progress.
- Skills and rules describe procedure. They cannot grant tools, widen path
  boundaries or bypass read-before-write.

## 4. Validation & Error Matrix

| Condition | Required behavior |
| --- | --- |
| frontmatter absent | directory name is available, but empty description means no skill |
| description missing | skip the file, keep loading the others |
| duplicate name across sources | earlier source wins, later one ignored |
| index over the char cap | truncate at an entry boundary, keep whole entries |
| body over the char cap | truncate and mark |
| rule file over its cap | truncate by line with a marker |
| merged rules over their cap | truncate the tail, keep source order |
| normal, nonempty `.trellis/workflow.md` | include the bounded Trellis entry before rule files |
| empty marker directory or empty workflow | do not add the Trellis entry |
| linked `.trellis` directory or linked workflow | do not add the Trellis entry |
| workflow read or text-decoding exception | skip the Trellis entry without failing rule loading |
| existing rules consume the total budget | retain the Trellis entry and truncate later rule text |
| plan item over the title cap | `VibePlanException`, tool reports `error(plan)` |
| repeated identical call | guard stops the round with a real explanation |
| round budget exhausted | `phase = failed`, `lastError` names the limit |

## 5. Good / Base / Bad Cases

- Good: a project `.qfli/skills/web-app-scaffold/SKILL.md` overrides the built-in
  skill of the same name for that project only.
- Good: a Trellis project retains its workflow entry even when `AGENTS.md`
  exceeds the rule budget. Detailed reads happen on demand.
- Base: no project skills or rules. The built-in table and the system prompt
  provide the defaults.
- Bad: injecting every body into the system prompt, letting a skill text change
  the tool list, or raising the round budget to hide a stalled loop.
- Bad: treating an empty `.trellis` directory as a usable workflow, or reserving
  the entry only after long project rules have consumed the total budget.

## 6. Tests Required

- `flutter test --no-pub --concurrency=1 test/vibe_coding_skills_test.dart
  test/vibe_coding_plan_test.dart test/vibe_coding_controller_test.dart`.
  together they cover the loader order and caps, the rule merge, plan parsing
  and the guard thresholds.
- `flutter analyze --no-pub lib` stays clean for `lib/vibe_coding`.
- The e2e `static_site` and `python_fix_loop` scenarios still pass with skills
  enabled, which proves the skills did not change tool behavior.
- CI acceptance for the Trellis entry should assert valid workflow detection,
  empty and linked marker rejection, retained entry under oversized rules,
  preserved rule/skill ordering and the 8,192-character total cap. These are
  acceptance points, not a claim that new tests exist or have run. The
  `11-22-agent-context-safeguards` session used static checks only.

## 7. Wrong vs Correct

### Wrong

```dart
// Every body in the system prompt.
final prompt = skills.map((skill) => skill.body).join('\n\n');
```

### Correct

```dart
// Index only; the body arrives on demand.
final index = skills.map((skill) => '- ${skill.name}: ${skill.description}');
```

### Trellis entry

Wrong: recursively inject every file under `.trellis` into the system prompt.
An empty directory also cannot establish an available workflow.

Correct: call the bounded rule loader, then read details through existing tools.

```dart
final rules = loadVibeRules(projectRoot);
```
