# Pad layout and interop regression validation — 2026-11-09

Scope: division D (regression tests and integration acceptance).
Repository under test: `qfli_studio_core` (sibling Git root).
This report is additive. It does not replace `background-design-20261105.md`
or `device-debug-20261105.md`.

## 1. Environment

| Tool | Result |
| --- | --- |
| Flutter | `3.27.5-ohos-1.0.1`, framework revision `12587c79e8` |
| `hdc` | `D:\ProgramFiles\Huawei\OpenHarmony\Sdk\23\toolchains\hdc.exe` |
| `hdc list targets` | `[Empty]` — no OHOS device attached during this run |
| `adb` | `D:\ProgramFiles\platform-tools\adb.exe` |
| `adb devices` | `FA6CP0302212 unauthorized`, `192.168.68.236:41477 device`, `adb-d361e7a0-… device` |

No OHOS device was reachable. Every statement below about runtime behaviour is
therefore limited to Dart widget tests on the host. Nothing in this report is
evidence of on-device behaviour.

### Working tree before any test edit

`qflistudio` (main) had 35 uncommitted paths. `qfli_studio_core` had:

```
 M lib/editor/editor_page.dart
 M lib/editor/terminal_pane.dart
 M lib/interop/interop_protocol.dart
 M lib/interop/interop_run_dialog.dart
 M lib/interop/interop_runner.dart
 M lib/interop/interop_transport.dart
 M lib/services/studio_profile.dart
 M test/interop_arkts_contract_test.dart
 M test/interop_protocol_test.dart
?? lib/interop/interop_background_transport.dart
?? lib/interop/interop_zip.dart
?? test/_scratch/
?? test/editor_background_run_test.dart
?? test/interop_background_transport_test.dart
?? test/interop_zip_test.dart
```

All of it was preserved. This session added one file,
`test/editor_pad_layout_test.dart`, and this report.

## 2. Full-suite baseline (recorded once, not repeated)

`flutter test --no-pub` on `qfli_studio_core`:

```
+1392 ~9 -3
```

Three failures, all in `test/editor_run_target_test.dart`. That file is clean
in Git (`git status` reports nothing) and its last commit is `17fa440
fix(interop): read the probe answer the bridge actually reports`. The failures
are pre-existing baseline failures, unrelated to the Pad layout work.

| Test | Failure point | Assertion | Observed |
| --- | --- | --- | --- |
| `an installed sibling app takes the run tap` | line 47 | `expect(transport.probedLanguages, contains('java'))` | `[]` |
| `a missing sibling app keeps the original path` | line 63 | `tap(find.byTooltip(runTooltip))` | `Found 0 widgets` |
| `an unknown probe keeps the original path` | line 75 | `tap(find.byTooltip(runTooltip))` | `Found 0 widgets` |

The three share one root cause: production no longer probes. The fixture
builds the expected Run tooltip from the probe answer (`_plainTooltip` when the
probe is not `installed`), but `_runButtonTooltip` resolves the target from the
entry file through the static table. A `Main.java` project therefore always
yields `运行（在 QFLIJVMX 中，长按运行当前文件）`, so tests 2 and 3 tap a
tooltip that does not exist. Test 1 keeps the matching tooltip and instead
fails on `probedLanguages`, which only `editor_page.dart` can populate.

Corroborated against Git:

- `git show HEAD:lib/editor/editor_page.dart` contains
  `runner.probe(target.language)` three times.
- The worktree contains it zero times.
- `git status --porcelain test/editor_run_target_test.dart` is empty. The file
  is committed at `17fa440`.

So the fixture expectation is stale, not the page, and the change that broke it
lives in `lib/editor/editor_page.dart`, not in `lib/interop`. Division B
confirmed this independently and it matches. Ownership of
`editor_run_target_test.dart` is outside division D. The finding is reported,
not patched.

## 3. Interop regression (division B and C surface)

Focused run, before any layout change landed:

```
flutter test --no-pub \
  test/interop_zip_test.dart \
  test/interop_protocol_test.dart \
  test/interop_runner_test.dart \
  test/interop_arkts_contract_test.dart \
  test/interop_background_transport_test.dart \
  test/editor_background_run_test.dart
```

Result: **104 passed, 0 failed**.

This covers protocol encode/decode, path validation, ZIP payload, the ArkTS
contract, background transport authentication and sequence handling, and the
editor's background action. The subset that asserts route independence passed:

- `background action is optional and ordinary Run keeps legacy target`
- `enabling background does not redirect ordinary Run`
- `background menu owns terminal output and Stop uses only new runner`
- `background run leaves online tab and page disposal cancels it`
- `background action is hidden for non-Java and non-OHOS`
- `sequence gap and authenticated bad protocol fail with 127`
- `missing cancellation acknowledgement fails honestly with 127`

Those assert the foreground and background routes stay separate. They also
assert that a failure produces a truthful non-zero outcome rather than a
silent switch.

## 4. Pad layout test (new)

File: `qfli_studio_core/test/editor_pad_layout_test.dart`.

The tests mount the **real** `EditorPage` and measure rectangles from its
render objects. They do not assert against a mock or a re-implementation of
the layout maths.

Layout keys the tests depend on, provided by division A:

| Key | Meaning |
| --- | --- |
| `editor-body-wide` | the wide-layout body `Row` |
| `editor-sidebar-slot` | the sidebar's horizontal slot |
| `editor-right-column` | the editor + panels column |

Contract asserted:

1. 719 wide lays out no sidebar slot. 720 wide lays out one. The breakpoint is
   `_wideBreakpoint = 720` in `editor_page.dart`.
2. Below 720 the toolbar control opens the real drawer, which holds the file
   tree. The drawer creates no wide-layout sidebar slot.
3. On a wide page the sidebar spans the body height minus its 12 px margins,
   is 280 px wide, and its right edge never crosses the column's left edge.
4. The Problems, Output, terminal and AI panels each lay out entirely inside
   `editor-right-column`. Every one of these tests expands the sidebar first,
   so `column.left` is 304 and the assertion proves the panel starts right of
   the sidebar. A collapsed sidebar would make the column span the body and
   the check would be vacuous. Each case also asserts the panel starts at or
   after the file-tree card's right edge, so no panel can occupy the left slot.
5. The terminal keeps the sidebar full height while it is open: the card's
   height stays `body.height - 24`. This is the direct check that a bottom
   panel shares the right column instead of taking over the left one.
6. A 800x600 (wide, not Pad) page holds the same contract and does not
   overflow.
7. Focus mode drops the sidebar slot, keeps panels inside the column, and does
   not overflow. The sidebar is expanded before focus mode is entered, so the
   removed slot is a real change of state.
8. The terminal keeps one `TerminalPaneState` across panel switches and across
   the 720 breakpoint in both directions.
9. A 320 px bottom inset (soft keyboard) shrinks the column height without
   changing its horizontal bounds, and the page does not overflow.
10. Crossing the 720 breakpoint by resizing keeps the same `CodeEditor` state
    object, so the editor is not recreated.

### Result

`flutter test --no-pub test/editor_pad_layout_test.dart`:

```
+12: All tests passed!
```

Twelve tests, all green against the final tree.

The set covers every layout requirement this increment owns:

1. `the 720 breakpoint decides between drawer and sidebar`
2. `below 720 the file tree opens in the drawer, not a sidebar`
3. `the sidebar is full height and never overlaps the panels`
4. `Problems panel is laid out inside the right column`
5. `Output panel is laid out inside the right column`
6. `the terminal panel is laid out inside the right column`
7. `the AI panel is laid out inside the right column`
8. `a wide phone keeps the sidebar and refuses to overflow`
9. `focus mode keeps panels inside the right column`
10. `the terminal state survives panel switches and a resize`
11. `a keyboard inset keeps the panel inside the right column`
12. `editor state survives a phone to Pad resize`

Two false starts are recorded so they are not repeated:

- An earlier draft measured while `AnimatedAlign` was still revealing the
  sidebar, which reads a zero-width cell and a column at x = 0. The mount now
  pumps the 200 ms reveal to completion before any rectangle is read, and the
  sidebar is expanded through its real toggle first. The sidebar starts hidden
  by design (`_explorerVisible ?? false`), so a test that never expands it is
  measuring a collapsed layout.
- An earlier draft entered focus mode with the `暂时收起编辑器` button. That
  button calls the host's `onMinimize`, not focus mode. Focus mode is
  `_inlineFocusDocuments.contains(_editor.current)`, and only an inline
  document contribution can toggle it through
  `InlineDocumentRequest.setFocusMode`. The final test builds the smallest
  `InlineDocumentEditor` that exposes such an action and fires it through the
  real toolbar button keyed `inline-action-focus`.

### Notes on the real widget tree

The tests mount the real `EditorPage`, so three preconditions had to be
honored rather than mocked:

- `EditorProblemsBar` renders its `editor-problems-status` entry only when
  `analysis.analyzer != null`. The profile therefore registers a minimal
  `codeAnalyzer` that returns an empty `CodeAnalysisResult`.
- The `More` menu labels are scoped to `PopupMenuItem<String>` when tapped. A
  bare `find.text` also matches text inside the panels and can land on the
  popup barrier.
- Focus mode is reached through an inline document contribution, as described
  above. The fake contribution returns the source editor from `build` and
  exposes only the focus action.
- Every panel assertion runs with the sidebar expanded. A collapsed sidebar
  gives `column.left = 0`, which would let a wrong layout pass.

## 5. What this report does not claim

- No OHOS device evidence. `hdc list targets` returned `[Empty]`.
- No claim that the Java receiver shows no visible window. `prd.md` B6
  requires hardware observation and that requirement stays pending.
- No claim that the background route works end to end. Only the Dart-side
  contract is covered here.
- No HAP build is attributed to this session.

## 6. Pending

1. When an OHOS device becomes reachable, record the device evidence that
   B6 requires before any "no visible window" statement is made. `hdc list
   targets` stays `[Empty]`, so this is a hardware gap, not a code gap.
2. `test/editor_run_target_test.dart` still encodes the removed probe path.
   Its three failures stay in the baseline until the owning division updates
   it. This session owns neither the file nor its fix.

The layout and interop items this division owned are complete. The Pad layout
suite is 12/12, the interop subset is 104/104, and the full-suite delta against
the recorded baseline is exactly the three `editor_run_target_test.dart`
failures.
