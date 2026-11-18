# Execution

1. Dispatch the four scoped implementations to existing idle Pi panes.
2. Collect root-cause evidence for session stalls and coordinate shared contracts.
3. Review full changes against the PRD and inspect generated previews.
4. Run targeted Dart analysis and affected existing tests; fix regressions.
5. Build the signed debug OHOS HAP with `tool/build_studio_hap.sh --debug`.
6. Install via HDC using a Windows-native local path. Launch if unlocked.
7. Record exact validation, device outcome, and remaining limitations. Commit only task-owned changes using Conventional Commits.

## Sidebar header correction

1. Replace the capsule with one ordinary toggle icon at the far right.
2. Apply the same explicit 44x44 action size and 20px icon size in both modes.
3. Verify target position, target section, and action access at 280px and 320px with text scale 1.3.
4. Run `flutter test --no-pub test/editor_agent_embed_test.dart test/editor_top_bar_title_test.dart` and analyze the three changed editor files.
5. Inspect the rendered header in both sections before the OHOS rebuild.

## Sidebar correction results

- `flutter test --no-pub test/editor_agent_embed_test.dart test/editor_top_bar_title_test.dart`: 35 tests passed.
- `flutter analyze --no-pub lib/editor/agent/editor_sidebar_tabs.dart lib/editor/editor_page.dart lib/editor/file_explorer.dart`: no issues.
- `git diff --check`: passed.
- Chinese text lint on the changed descriptions: zero hard violations.
- `tool/build_studio_hap.sh --debug`: succeeded.
- HDC overwrite install to `192.168.68.207:46551`: succeeded, bundle `com.azurekiln.qflistudio`, version `5.0.1`.
- Launch attempt returned `10106102` because the device screen was locked. Device UI inspection remains unverified. Widget tests measured the rendered buttons in both modes at 44x44 with 20px icons.
