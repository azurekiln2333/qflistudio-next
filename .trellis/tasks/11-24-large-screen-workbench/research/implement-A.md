# Implement A: workbench chrome only

The user approved the complete plan with 继续. IMPLEMENT now, no new planning gate.
Task: D:/MyNewProjects/qflistudio/.trellis/tasks/11-24-large-screen-workbench
WRITE ONLY in D:/MyNewProjects/_wt/large-screen-workbench/qfli_studio_core:
- lib/shell/workbench_chrome.dart (new)
- test/workbench_chrome_test.dart (new)
No other product files. Parent owns retained editor and shell integration.
Read design.md, relevant Core frontend specs, and existing theme/localization.
Do not scan unrelated tasks. Write a first patch after at most 5 focused reads.

Implement public enum WorkbenchActivity { projects, files, agents, tools, tutorial, settings, profile }.
Implement WorkbenchActivityRail({Key? key, required WorkbenchActivity selected, required ValueChanged<WorkbenchActivity> onSelected, ImageProvider? avatarImage, String? accountLabel}).
52px rail, 44px touch targets, Projects/Files/Agents at top, tools/tutorial below,
settings and avatar at bottom LEFT. Avatar selects profile. Use app theme,
Material icons, accessible labels/tooltips, selected indication, keyboard focus.
Handle tiny heights and text scaling without overflow; no NavigationRail labels
that expand width. Avoid hardcoded product palette. Render avatar fallback.
Implement WorkbenchWelcome({Key? key, required VoidCallback onOpenProject}) with
compact empty workspace message and open-project action. No dashboard metrics.
Add meaningful cloud-only widget tests for callback selection and bottom avatar,
touch target sizes and narrow height. Do NOT run tests/probes/builds locally.
Local formatting/static analysis allowed. Parent runs pub get and owns configs.
Do not commit, push, change task status, create worktrees, or edit original repo.
Finish with changed files, public API, and any actual limitation. Report briefly.
