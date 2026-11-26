# Phase 05 — Review fixes R1–R4

Status: in progress (report created before code edits; final sections filled after implementation).

Task: `D:/MyNewProjects/qflistudio/.trellis/tasks/11-20-cloudterminal-import`
Core worktree: `D:/MyNewProjects/_wt/cloudterminal-import/work/qfli_studio_core`
Source of truth: `reports/remote-review.md` (R1–R4), `prd.md`, `design.md`, `implement.jsonl` specs.

## Intended boundary

Only these paths are edited:

- `lib/remote_control/state/herdr_controller.dart` — route-owned pane-watch lease (R2).
- `lib/remote_control/pages/session_screen.dart` — terminal-kind guard (R1) + lease use (R2).
- `lib/remote_control/pages/home_screen.dart` — no Herdr controller for Claude routes (R1) + visible module exit (R3).
- `lib/remote_control/pages/herdr_terminal_screen.dart` — lease use (R2).
- `lib/remote_control/pages/herdr_screen.dart` — remember the pane without opening a watch from the list (R2).
- `lib/remote_control/widgets/herdr_terminal_rows.dart` — pane/tab chips select through the owner lease (R2).
- `lib/remote_control/widgets/workspace_sidebar.dart` — visible 返回 Studio entry (R3).
- `lib/remote_control/pages/pair_screen.dart` — visible exit in the unpaired state (R3).
- `lib/remote_control/remote_computer_page.dart` — host exit callback + explicit controller ownership (R3).
- `test/support/remote_control_app.dart` — corrected ownership comment and an explicitly owning test shell (R4).
- `test/remote_control/codex_test.dart` — controller teardown for the two widget tests (R4).
- `test/remote_control/herdr_test.dart`, `test/remote_control/herdr_direct_input_test.dart` — coherent update to the lease-based test-facing contract (R2).
- `test/remote_control/remote_module_regression_test.dart` — new regressions for R1–R3.
- `reports/phase-04a-tests.md` — correction of the false ownership sentence (R4).
- this report.

No production behaviour outside the remote-control module changes. No local tests/builds are run;
regressions are written for cloud CI. Static analysis, formatting and `git diff --check` only.

## R1 — Claude sessions stay out of Herdr

(To be completed.)

## R2 — Route ownership for live pane watching

(To be completed.)

## R3 — Visible return to Studio

(To be completed.)

## R4 — Codex test controller ownership

(To be completed.)

## Regression coverage

(To be completed.)

## Static commands and results

(To be completed.)

## Remaining limits

(To be completed.)
