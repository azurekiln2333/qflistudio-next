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

## 2. Signatures

```dart
// vibe_skills.dart
VibeSkill? parseVibeSkill(String text, {required String fallbackName});
enum VibeSkillSource { projectQfli, claude, agents, builtIn }
const int kVibeSkillMaxBodyChars = 12 * 1024;
const int kVibeMaxSkillEntries = 40;
const int kVibeMaxSkillIndexChars = 4 * 1024;
const Map<String, Set<String>> kVibeBuiltInSkillLanguages;   // '*' = 全部语言

// vibe_rules.dart
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
- Discovery order decides duplicates: `.qfli/skills`, `.claude/skills`,
  `.agents/skills`, then built-in (`assets/skills/`). The first hit wins.
- The prompt carries only the index: name plus description. It is capped at
  `kVibeMaxSkillIndexChars` and `kVibeMaxSkillEntries`; a full body enters the
  conversation only when the model asks for it, and is then truncated at
  `kVibeSkillMaxBodyChars` with a visible flag.
- Built-in skills with `'*'` apply to every language. A language-scoped skill is
  hidden from projects of other languages.
- Project rules merge in `kVibeRuleFiles` order. Each file is capped at
  `kVibeMaxRuleFileChars` and the merged text at `kVibeMaxRulesChars`, truncated
  by line with a marker.
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
| frontmatter absent | name from the directory; empty description → not a skill |
| description missing | skip the file, keep loading the others |
| duplicate name across sources | earlier source wins, later one ignored |
| index over the char cap | truncate at an entry boundary, keep whole entries |
| body over the char cap | truncate and mark |
| rule file over its cap | truncate by line with a marker |
| merged rules over their cap | truncate the tail, keep source order |
| plan item over the title cap | `VibePlanException`, tool reports `error(plan)` |
| repeated identical call | guard stops the round with a real explanation |
| round budget exhausted | `phase = failed`, `lastError` names the limit |

## 5. Good / Base / Bad Cases

- Good: a project `.qfli/skills/web-app-scaffold/SKILL.md` overrides the built-in
  skill of the same name for that project only.
- Base: no project skills or rules; the built-in table and the system prompt
  provide the defaults.
- Bad: injecting every body into the system prompt, letting a skill text change
  the tool list, or raising the round budget to hide a stalled loop.

## 6. Tests Required

- `flutter test --no-pub --concurrency=1 test/vibe_coding_skills_test.dart
  test/vibe_coding_plan_test.dart test/vibe_coding_controller_test.dart`;
  together they cover the loader order and caps, the rule merge, plan parsing
  and the guard thresholds.
- `flutter analyze --no-pub lib` stays clean for `lib/vibe_coding`.
- The e2e `static_site` and `python_fix_loop` scenarios still pass with skills
  enabled, which proves the skills did not change tool behavior.

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
