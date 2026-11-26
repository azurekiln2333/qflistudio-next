<!-- TRELLIS:START -->
# Trellis Instructions

These instructions are for AI assistants working in this project.

This project is managed by Trellis. The working knowledge you need lives under `.trellis/`:

- `.trellis/workflow.md` — development phases, when to create tasks, skill routing
- `.trellis/spec/` — package- and layer-scoped coding guidelines (read before writing code in a given layer)
- `.trellis/workspace/` — per-developer journals and session traces
- `.trellis/tasks/` — active and archived tasks (PRDs, research, jsonl context)

If a Trellis command is available on your platform (e.g. `/trellis:finish-work`, `/trellis:continue`), prefer it over manual steps. Not every platform exposes every command.

If you're using Codex or another agent-capable tool, additional project-scoped helpers may live in:
- `.agents/skills/` — reusable Trellis skills
- `.codex/agents/` — optional custom subagents

Managed by Trellis. Edits outside this block are preserved; edits inside may be overwritten by a future `trellis update`.

<!-- TRELLIS:END -->

## Cloud-only execution policy

The user approved this rule on 2026-11-26 for every agent and human workflow.
It overrides older task notes, specs, skills and examples that suggest local validation.

- Do not run builds, tests, analyzers, dependency resolution or package installs on this PC.
- Do not run Flutter/Dart/Gradle/CMake/Ninja/Cargo/npm/hvigor build or test commands locally.
- Do not create native or Flutter intermediates, dependency caches, coverage, test output, simulators, containers or WSL build environments locally.
- Do not download GitHub installer artifacts into this checkout.
- Do not download or extract native build artifacts locally.
- Do not start WSL distributions for project work. `--no-pub` is not an exception to the local test ban.
- Run project validation, packaging and artifact generation only in GitHub Actions. Inspect remote jobs and logs with GitHub tools.
- Local work is limited to source editing, Git operations, text/metadata/hash inspection and herdr coordination.
- Disable IDE auto-build, auto-test and automatic dependency setup when opening this workspace.
- Keep portable Trellis tasks, research summaries, specs, journals and support scripts in Git. Exclude runtime state, raw agent transcripts, caches, generated staging copies and downloaded artifacts.
- Never commit signing keys, signing passwords, tokens or machine-specific overrides.
- Treat GitHub `main` as the integration source. Audit branch/worktree changes before merging or cleaning.
- Coordinate with other product owners through herdr. Do not delete shared WSL distributions or sibling worktrees.

Canonical migrated checkout: `E:/MyNewProjects/QFLIProjects/qflistudio-next`.
Canonical core sibling: `../qflistudio-core`; Dart package name remains `qfli_studio_core`.
Migration evidence: `.trellis/tasks/11-26-github-main-migration/`.
The Chinese lint command below must also run only in GitHub Actions.

改写中文技术文本时套用受控中文规则：一句一动作、主动语态、一词一义（同一概念全篇同一个词）、不用分号连接动作、句长（指令 ≤ 25 字、说明 ≤ 40 字）、去掉虚动词（进行 / 加以 + 名词）、套话（需要注意的是、在一定程度上）、营销形容词（无缝、强大、赋能、闭环）与含糊词（若干、一些、相关）； 不得改动情态（可能 / 也许）：置信度是内容。机械首查用 python <repo>/scripts/ste-lint-zh.py <文件>。
