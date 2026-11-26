# Inspected baselines and workspace boundaries

All product writes belong below `D:/MyNewProjects/_wt/studio-git-integration/`.
All three branches are `release/studio-git-ui-20261120`.

| Sibling | Exact starting commit | Reason |
| --- | --- | --- |
| qflistudio | 6d1b96d7118740f71e5dadf393cc8bd58238b6af | Published remote.2 preview, including thinking UI and remote computer integration |
| qfli_studio_core | 72c0b0955e4ddd5215dc818327fa5a67a4be22f7 | Exact core tested in remote.2 |
| qfli_git | 89e656bd2c9f879c4fc7e6a0a343e17dc7d0f84a | main 95cb99b plus existing Dart CI 36faeb7 and CI-only documentation 89e656b |

Plugin additions after main contain no product-code changes. Existing main
contains native-v0.1.1 prebuilts. New C exports require new cloud-built binaries
before final app packaging. Old binaries plus new bindings are not integration.
Java stays pinned at `60d97c783f29da767fafe503980812101f6aa61f` in cloud CI.

Existing root checkouts and release-v5.0.5 worktrees remain untouched.
Never write to `D:/MyNewProjects/cloudterminal`, including its Git index.
The previous conversation audit is authoritative background:
`../11-20-cloudterminal-import/research/session-audit.md`.

Trellis channel currently accepts only claude/codex. Use the installed Pi CLI
directly with fresh named sessions and task-owned logs. Do not rename Codex to Pi
or take over user terminal panes. Retain Pi's configured default model.
