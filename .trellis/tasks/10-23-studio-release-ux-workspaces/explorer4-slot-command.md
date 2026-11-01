# Explorer4 slot — exact command (studio-workspace)

HOLD until the native `tools_review` main Home+content process exits and root grants
"explorer4 only". Do not chain anything after it.

## Exact invocation (cached snapshot, no wrapper re-resolution)

```powershell
cd D:/MyNewProjects/qfli_studio_core
& "D:\ProgramFiles\flutter_ohos\bin\cache\dart-sdk\bin\dart.exe" `
  "D:\ProgramFiles\flutter_ohos\bin\cache\flutter_tools.snapshot" test --no-pub `
  --concurrency=1 --timeout 60s test/main_workspace_explorer_test.dart `
  *>&1 | Tee-Object -FilePath "$env:TEMP\ws-explorer4.log" | Select-Object -Last 25
```

Capture the exit code explicitly (Tee swallows it):

```powershell
$code = $LASTEXITCODE; "EXIT=$code"; Select-String -Path "$env:TEMP\ws-explorer4.log" -Pattern 'All tests passed|Some tests failed|did not complete'
```

Verified cached paths:
- `D:\ProgramFiles\flutter_ohos\bin\cache\dart-sdk\bin\dart.exe` (exists)
- `D:\ProgramFiles\flutter_ohos\bin\cache\flutter_tools.snapshot` (exists)
- `D:\ProgramFiles\flutter_ohos\bin\cache\artifacts\engine\windows-x64\flutter_tester.exe` (exists)

## Scope of this slot

ONLY `test/main_workspace_explorer_test.dart` — 4 cases:

1. primary fallback moves browsing off the deleted root (fails if the membership check is
   circular again)
2. removing and re-adding a root restores its previous expansion
3. expansion metadata of a removed root never opens its files
4. actual 1100x175 panel, text scale 1.0 and 2.0, no RenderFlex overflow; tooltip
   `工作区项目` still present

## Fixture IO status (in place, verified by analyze)

All four tests seed the workspace in the real zone before mounting:

```dart
late SavedWorkspace workspace;
await tester.runAsync(() async {
  workspace = await fixture.saveWorkspace([fixture.first, fixture.second]);
});
```

`mount()` sets `tester.view.physicalSize`/`devicePixelRatio` once (guarded by `_viewSized`,
`addTearDown(tester.view.reset)`), and the 1100x175 case mounts the explorer edge-to-edge
instead of the 360x700 box. `waitForIo` advances fake time with
`pump(Duration(milliseconds: 20))` + `runAsync(delay 5ms)`.

## Do not touch

- `lib/editor/editor_page.dart` — C lock; it is now modified by C202/native (mtime 03:57:52).
  Not mine, do not revert or reformat.
- `test/main_workspace_actions_test.dart` — owned by the native release agent.
- `lib/workspace/workspace_store.dart`, `test/workspace_store_test.dart` — store owner.

## If launcher/test still hangs

Do not retry. Report the live handle (pid, parent pid, start time, CPU) from:

```powershell
Get-CimInstance Win32_Process -Filter "Name='dart.exe' OR Name='flutter_tester.exe'" |
  Select-Object ProcessId,ParentProcessId,CreationDate,CommandLine
```

and release the slot on process exit.
