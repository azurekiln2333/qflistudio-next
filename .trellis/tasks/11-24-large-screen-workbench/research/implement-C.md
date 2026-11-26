# Implement C: device family independent of viewport width

User approved the final plan with 继续. IMPLEMENT now, no planning gate.
Task: D:/MyNewProjects/qflistudio/.trellis/tasks/11-24-large-screen-workbench
Core: D:/MyNewProjects/_wt/large-screen-workbench/qfli_studio_core
App: D:/MyNewProjects/_wt/large-screen-workbench/qflistudio
WRITE ONLY:
- Core lib/layout/app_form_factor.dart and test/app_form_factor_test.dart
- App ios/Runner/AppDelegate.swift
- App android/app/src/main/kotlin/com/azurekiln/qflistudio/MainActivity.kt
- App ohos/entry/src/main/ets/entryability/EntryAbility.ets
No app.dart, lib/main.dart, Windows or breakpoints edits. Parent owns wiring.
Read design.md and native entry handlers once. No repeated broad exploration.

Public API: enum AppFormFactor { phone, tablet, desktop }
Future<AppFormFactor> resolveAppFormFactor({required String operatingSystem, required Size displaySize, MethodChannel? channel});
displaySize is full FlutterView.display size divided by DPR, not window size.
Desktop OS names return desktop immediately. Mobile attempts dedicated
qflistudio/form_factor channel getFormFactor -> 'phone'|'tablet'.
iOS UIDevice.current.userInterfaceIdiom .pad/.phone.
OHOS deviceInfo.deviceType from actual SDK-supported import. Preserve handlers.
Android use non-window display information (DisplayManager/WindowManager max
metrics as appropriate), not current Activity.resources.configuration width.
No mouse-presence classification. Window resize never changes family.
If native unsupported/fails, display shortest side >=600 gives tablet else phone.
Invalid/zero display size returns phone. No network/plugin new dependencies.
Parent resolves once and owns overrides for tests; your function must support
injected MethodChannel and deterministic fallback tests. Read official SDK docs
or installed SDK source for uncertain APIs; don't fabricate enum/platform types.
Write cloud-only tests; do not run local tests/probes/builds. Formatting and static
analysis allowed. Do not commit/push or touch original/release trees. Return paths.
