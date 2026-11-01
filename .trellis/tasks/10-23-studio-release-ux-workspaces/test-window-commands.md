# Test window command list — studio-workspace

Run from `D:/MyNewProjects/qfli_studio_core` after the store agent finishes and root grants
the window. Nothing here writes to `lib/editor/editor_page.dart` (C-locked).

## 0. Gate (no test)

```powershell
cd D:/MyNewProjects/qfli_studio_core
flutter analyze --no-pub lib/editor/file_explorer.dart lib/editor/retained_editor_host.dart lib/workspace lib/pages/home_page.dart test/main_workspace_sessions_test.dart test/main_workspace_explorer_test.dart test/main_saved_workspaces_tab_test.dart
```

## 1. Main workspace sessions (6)

```powershell
flutter test --no-pub --concurrency=1 --timeout 90s test/main_workspace_sessions_test.dart
```

Expected: promotion/standalone reuse, id-only identity + primary fallback, standalone ignores
legacy cross-root history, workspace session persisted only to the workspace document,
membership shrink keeps the dirty orphan and persists only the survivor, missing-primary
survivor restore.

## 2. Main workspace explorer (4, includes the actual 1100x175 panel)

```powershell
flutter test --no-pub --concurrency=1 --timeout 90s test/main_workspace_explorer_test.dart
```

Expected: primary fallback drops root A and browses B (fails if the membership check is
circular), remove+re-add restores `other/`, removed-root metadata opens nothing, and the
1100x175 header/tree case reports no RenderFlex overflow at text scale 1.0 and 2.0.

Isolate just the short panel if it fails:

```powershell
flutter test --no-pub --concurrency=1 --timeout 60s --plain-name "1100x175" test/main_workspace_explorer_test.dart
```

## 3. Main Home workspace cards (2)

```powershell
flutter test --no-pub --concurrency=1 --timeout 90s test/main_saved_workspaces_tab_test.dart
```

Expected: tapping a card hands the host the newest session (not the card snapshot); tapping a
card whose record was deleted opens nothing and shows "已被删除".

## 4. Legacy child contract (unchanged behavior, must stay green)

```powershell
flutter test --no-pub --concurrency=1 --timeout 90s test/workspace_editor_session_test.dart
flutter test --no-pub --concurrency=1 --timeout 90s test/file_explorer_state_test.dart
```

Expected: 4 and 12 passing. These files are at HEAD except for an explicit child `productKey`
(`forge`) in setUp, so they exercise the preserved multi-root legacy path, not narrowed scope.

## 5. One combined run (final confidence pass, single process)

```powershell
flutter test --no-pub --concurrency=1 --timeout 120s test/main_workspace_sessions_test.dart test/main_workspace_explorer_test.dart test/main_saved_workspaces_tab_test.dart test/workspace_editor_session_test.dart test/file_explorer_state_test.dart
```

## Reporting

Capture each run to a log and quote the summary line:

```powershell
flutter test --no-pub --concurrency=1 --timeout 90s test/main_workspace_explorer_test.dart *>&1 | Tee-Object -FilePath "$env:TEMP\ws-explorer.log" | Select-Object -Last 15
```

## If something hangs

- `tester.pump()` with no duration does not advance fake time; store writes queue on timers.
  Only `pump(Duration(milliseconds: 50))` inside a `runAsync`-assisted loop drains them.
- Never `await store.settle()` from inside a `testWidgets` body: it deadlocks against the fake
  zone. Use the poll loops already in these tests.
