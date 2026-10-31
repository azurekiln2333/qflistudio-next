# Vibe agent skills

## 1. Scope / Trigger

Apply this contract when adding a skill, changing skill discovery order, the
prompt index, the plan tool or the loop guards. The source of truth is
`qfli_studio_core/lib/vibe_coding/vibe_skills.dart`, `vibe_plan.dart`,
`vibe_rules.dart` and `vibe_loop_guard.dart`, owned by the
`vibe-agent-skills` task. The acceptance side is `vibe-e2e.md`.

Status: `Draft`. The loader, the limits and the built-in skill table exist.
`vibe_plan.dart`, `vibe_rules.dart` and `vibe_loop_guard.dart` landed after this
draft was written; re-read them before relying on any detail below.

## 2. Signatures

```dart
VibeSkill? parseVibeSkill(String text, {required String fallbackName});

enum VibeSkillSource {
  projectQfli('.qfli/skills'),
  claude('.claude/skills'),
  agents('.agents/skills'),
  builtIn('内置技能'),
}

const int kVibeSkillMaxBodyChars = 12 * 1024;
const int kVibeMaxSkillEntries = 40;
const int kVibeMaxSkillIndexChars = 4 * 1024;
const Map<String, Set<String>> kVibeBuiltInSkillLanguages;
```

## 3. Contracts

- `SKILL.md` frontmatter is a leading `---` block carrying `name` and
  `description`. A file without a description is not a skill.
- Discovery order decides duplicates: project `.qfli/skills`, then
  `.claude/skills`, then `.agents/skills`, then built-in. The first hit wins.
- The prompt carries only the index: name plus description, capped at
  `kVibeMaxSkillIndexChars` and `kVibeMaxSkillEntries`. A full body enters the
  conversation only when the model asks for it.
- A body over `kVibeSkillMaxBodyChars` is truncated and flagged; never silently.
- Built-in skills with `'*'` apply to every language. A language-scoped skill is
  hidden from projects of other languages.
- Skills describe procedure. They cannot grant tools, widen path boundaries or
  bypass the read-before-write rule.

## 4. Validation & Error Matrix

| Condition | Required behavior |
| --- | --- |
| frontmatter absent | derive the name from the directory, description empty → not a skill |
| description missing | skip the file, keep loading others |
| duplicate name across sources | earlier source wins, later one ignored |
| index over the char cap | truncate at an entry boundary, keep whole entries |
| body over the char cap | truncate, set `truncated` |
| skill asks for a forbidden tool or path | tools still enforce their own boundary |
| skill directory is a symlink escape | rejected by the project path guard |

## 5. Good / Base / Bad Cases

- Good: a project `.qfli/skills/web-app-scaffold/SKILL.md` overrides the built-in
  skill of the same name for that project only.
- Base: no project skills; the built-in table provides the defaults.
- Bad: injecting every skill body into the system prompt, or letting a skill
  text change the tool list.

## 6. Tests Required

- `flutter test --no-pub test/vibe_coding_controller_test.dart` for the loop with
  skills present.
- A loader test covering order, duplicate resolution, language filtering and both
  caps.
- `flutter analyze --no-pub lib/vibe_coding` stays clean.
- The e2e `static_site` scenario still passes with the built-in skills enabled,
  which proves the skills did not change tool behavior.

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
