Active task: D:/MyNewProjects/qflistudio/.trellis/tasks/11-20-studio-git-integration

You are already the trellis-implement sub-agent, running in the actual Pi CLI.
Implement directly. Do not spawn another implement/check worker. The user has
explicitly ordered: finish the Trellis plan and immediately dispatch Pi work.
Planning is complete and implementation is authorized. Do not ask for approval
or stop at another plan. Product boundaries are in prd.md/design.md/implement.md.

Read those three task files and every real entry of implement.jsonl relative to
D:/MyNewProjects/qflistudio. Read your worktree AGENTS.md and relevant actual core
or plugin specs before editing. The shared design freezes cross-owner interfaces.
Other Pi workers are writing concurrently to distinct files. Inspect current
state, preserve others' work, and modify only your ownership. Read others' files
freely. Report required contract changes to reports/contract-change.md.

All product writes belong only under D:/MyNewProjects/_wt/studio-git-integration/.
Do not edit original root repos, release-v5.0.5, or D:/MyNewProjects/cloudterminal.
Do not modify CloudTerminal HEAD/index/content. Do not reset/clean/force-push or
bulk stage. Do not stage, commit, push or tag in this worker; root handles shared
indexes and release coordination. Do not change global settings/model/provider.

USER PROHIBITION: no local tests, builds, services, emulators, VMs, WSL, Docker,
adb or hdc. Write meaningful regression tests and cloud workflows but do not run
tests locally. Reading, formatting, static analysis and syntax checks are allowed.
If dependencies for analysis are missing, record that and wire cloud analysis.
Do not use a local runtime smoke check as a substitute for forbidden local tests.

Do not silently reduce scope, hide mandatory actions as unsupported, or put TODO
placeholders behind enabled buttons. Complete your assigned production code and
fixtures. Preserve desktop/cloud behavior and the previous remote/thinking UI.
Secrets must not appear in logs, persisted config, process args, or reports.

Write progress to your own report early and update it as work proceeds. Include
exact changed files, interfaces, validation performed, remaining cloud work and
known limitations. Exit only after actual implementation or a concrete blocker.
Process exit is not task acceptance. The coordinator will review the full diff.

Chinese technical edits follow one action per sentence, active voice, stable
terms, <=25 characters for instructions and <=40 for explanations. Preserve
confidence words. Root scripts/ste-lint-zh.py is available for mechanical checks.
English implementation reports/specs are acceptable and avoid terminology drift.
