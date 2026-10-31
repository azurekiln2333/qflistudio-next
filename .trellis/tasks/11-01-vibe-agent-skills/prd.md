# Vibe agent maturity: skills, plan, one-sentence site

## Goal

The in-app agent builds a small project from one sentence and is extensible with existing skill formats. Working directory is the editor's open project.

## Requirements

- R1: Load skills from `<project>/.qfli/skills/*/SKILL.md`, and from `.claude/skills` and `.agents/skills` when present. Parse frontmatter `name` and `description`. Put only the index in the prompt. Expose a `use_skill` tool that returns the body on demand.
- R2: Load project rules from `AGENTS.md`, `CLAUDE.md`, `.qfli/rules.md` into the system prompt with a size cap.
- R3: Ship built-in skills: `web-app-scaffold` (static site), `bug-fix-loop`, `project-review`. Store them as assets.
- R4: Add a `todo` plan tool. The panel shows the live plan.
- R5: Raise the round limit by task size. Add loop guards: repeated identical call, no-progress rounds, read-before-edit.
- R6: After writing a web project, the agent verifies it (file list, HTML sanity via `run_command` or a built-in check) before claiming success.
- R7: Default cwd is the editor project root. Paths stay inside it (existing guard).
- R8: Wire `vibe_web_tools.dart` (owned by B) into the controller once B publishes it.

## Acceptance

- [ ] Unit tests: skill parsing, index prompt, `use_skill`, plan tool, loop guards.
- [ ] Prompt "做一个待办事项小网站" against the debug upstream produces a working multi-file site (run through D's harness).
- [ ] Panel shows plan and skill use. No UI overflow at phone width.
- [ ] Debug key absent from the diff.
