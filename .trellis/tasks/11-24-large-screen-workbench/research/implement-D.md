# Implement D: inline GitHub Home tab and Profile connection

User approved complete plan with 继续. IMPLEMENT now, no planning gate.
Task: D:/MyNewProjects/qflistudio/.trellis/tasks/11-24-large-screen-workbench
Core root: D:/MyNewProjects/_wt/large-screen-workbench/qfli_studio_core
WRITE ONLY Core:
- lib/github/ (existing auth/controller and new scope/mapping if needed)
- lib/pages/git/github_repository_picker.dart and new GitHub widgets here
- lib/pages/home_page.dart, lib/pages/home_project_tabs.dart, lib/pages/profile_page.dart
- test/github* and test/home_project* (preserve existing behavioral assertions)
No lib/app.dart or lib/shell/ edits; parent integrates the app-owned scope.
Read design.md, existing GitHub tests and mobile-files-agents spec. Begin patch
after <=6 focused reads. Avoid long recursive search/replanning loops.

Implement GitHubScope InheritedNotifier<GitHubAuthController> in
lib/github/github_scope.dart with maybeOf(context). Parent will own one controller
and restore/dispose it. Legacy picker standalone fallback remains for its tests.
ProfileTab adds GitHub connection panel (OAuth/PAT/connect/reconnect/disconnect).
Remove connection controls from Home menu; connection no longer requires opening
repository picker. Profile should work independently of the Studio login state.
Extract shared GitHub repository list from old picker; Home GitHub scope displays
this list directly with search/refresh/pagination/clone. No extra picker route.
GitHub tab appears after auth connected, participates in same TabController,
swipes and saved order. On disconnect remove without resetting other tabs; return
history if it was active. Persist hidden GitHub order for reconnection. Preserve
all Agents tab retention/order regressions from v5.0.12. Do not build list until
selected. Clone progress stays visible and does not force a different Home scope.
Clone through existing GitCloneService pipeline, never credentials in URLs/logs.
Expose optional HomeTab parameters embedded=false and showAgentsScope=true so
parent can use HomeTab(embedded:true,showAgentsScope:false) in 300px sidebar.
Embedded mode omits duplicate page title, moves toolbar actions into overflow,
keeps project lists and local/cloud/workspace functionality. Phone defaults stay.
GitHub repo rows open existing mapped local project or clone in-place. Store
mapping in a dedicated credential-free file. Do not delete projects on disconnect.

Add meaningful tests for direct list, connect/disconnect, retained ordering and
clone errors. Tests only cloud CI; no local product tests/probes/builds. Local
format/analyze allowed. Parent runs pub get. Do not commit/push/create worktrees.
Finish with changed paths, required parent API wiring, concrete limitations.
