# Implement

1. Read the parent prd.md, this prd.md and the relevant .trellis/spec/frontend files.
2. Write design.md (short) before code. Report to the root session if it changes a shared interface.
3. Implement in small steps. After each step run focused tests, then commit as type(scope): summary with explicit paths.
4. On finish, add a Result section here: commits, tests run, what was not verified.

## Result

### Commits

| Repo | Commit | Scope |
| --- | --- | --- |
| qflistudio | `ecf9134` | design.md and research notes |
| qfli_studio_core | `95fe2c4` | protocol, payload, transport, runner, dialog, two test files |
| qflistudio | `f5af762` | StudioInterop, InteropBridge, InteropBridgeAbility, module.json5, string.json |
| qfli_java | `dbf2656` | InteropAbility, InteropReceiver, module.json5, three string.json |
| qflistudio | `eb9d4fd` | EntryAbility registration of the interop channels |
| qfli_studio_core | `0bdd4c6` | ArkTS contract test |
| qflistudio | `add9202` | design.md correction to the shipped payload directory |

Each commit used `git commit -F <file> -- <explicit paths>`. Staged work that
belonged to other sessions in `qfli_java` was left untouched and is still
staged.

### Implemented

- `qfli_studio_core/lib/interop/`: `interop_protocol.dart`,
  `interop_payload.dart`, `interop_transport.dart`, `interop_targets.dart`,
  `interop_runner.dart`, `interop_run_dialog.dart`.
- `qflistudio/ohos/entry/src/main/ets/interop/`: `StudioInterop.ets`,
  `InteropBridge.ets`, `InteropBridgeAbility.ets`, plus registration in
  `EntryAbility.ets` and the exported ability in `module.json5`.
- `qfli_java/ohos/entry/src/main/ets/interop/`: `InteropAbility.ets`,
  `InteropReceiver.ets`, plus the exported ability in `module.json5`.

### Tests run

- `flutter analyze --no-pub lib/interop <three interop test files>`: no issues.
- `flutter test --no-pub test/interop_protocol_test.dart`: 38 passed.
- `flutter test --no-pub test/interop_runner_test.dart`: 20 passed.
- `flutter test --no-pub test/interop_arkts_contract_test.dart`: 12 passed.
- `hvigorw assembleHap` in `qflistudio/ohos`: BUILD SUCCESSFUL.
- `hvigorw assembleHap` in `qfli_java/ohos`: BUILD SUCCESSFUL, before and after
  the receiver was added.

### Not verified

- No OHOS device or emulator was attached (`hdc list targets` was empty), so
  the cross-app launch, the event relay and a real compile were never executed.
  Nothing in this task claims a device result.
- The ArkTS validation and relay logic is covered only by source-level contract
  tests and by the build.
- SHA-256 is implemented locally to avoid a new dependency in ten apps. It is
  pinned against published digests, but the receiver does not recompute the
  digest on device yet, so the integrity check has only been exercised in
  Dart.
- Python and C receivers were not built. The reason and the reuse path are in
  `design.md` section 8.
- The `javadoc`-style package parse and the main class resolution were checked
  by reading `JavaRunner`, not by running a project on device.

### Cross-owner interfaces (unchanged, still needed)

1. `lib/services/studio_profile.dart` needs an optional
   `InteropRunner? interopRunner` field so the editor can offer the run action.
   Until then the runner, the dialog and the routing are usable from code and
   tests, and the editor shows no button.
2. Vibe `run_command` (owner B) should call
   `InteropRunner.tryRunCommand(projectRoot:, language:, command:)` on OHOS and
   use the result when it is not null. Implemented and tested here; wiring it
   into the controller is owner B's edit.

### Incident to note

While restoring a stashed-looking change, I overwrote uncommitted work in
`qflistudio/ohos/entry/src/main/module.json5` with the committed version. The
device types (`2in1`, `tablet`) and `ohos.permission.GET_NETWORK_INFO` were
restored to the working tree immediately and are unstaged. `qfli_java` was
checked and had no such loss.

## Follow-up: editor entry, module.json5 audit, device check

### 1. Editor entry (done)

`qfli_studio_core` commit `76d00fd`.

- `lib/services/studio_profile.dart`: added the optional
  `final InteropRunner? interopRunner;` constructor field and its import.
  The file had no uncommitted work from anyone else when this was done
  (`git status --porcelain` returned nothing for it), so it was committed whole.
- `lib/editor/editor_page.dart`: added `_interopTargetFor`, `_entryFileOf`,
  `_runInSiblingApp`, one popup item `interop_run` and its switch case.
  The file was also clean beforehand. The commit contains only insertions
  (4 hunks, 118 added lines, 0 deletions), which the hunk list below shows.
- `test/interop_entry_decision_test.dart`: pins the entry-to-receiver
  decision, including that an unknown extension produces no menu item.

Behaviour:

- The menu item appears only when the project entry maps to a receiver.
- The probe runs before the dialog. A missing sibling app shows
  `InteropTargets.installHint`, which names the product and bundle.
- Unsaved buffers in the project are refused with a count rather than run
  from disk.
- The dialog streams real output and can cancel; the exit code is written to
  the output pane and recorded as a run.

Editor hunks (pure insertion):

```
@@ -59,0 +60,2 @@      import '../interop/interop_run_dialog.dart'; import '../interop/interop_targets.dart';
@@ -2012,0 +2015,87 @@ _interopTargetFor / _entryFileOf / _runInSiblingApp
@@ -2300,0 +2390,2 @@  case 'interop_run':
@@ -2441,0 +2533,27 @@ PopupMenuItem('在 <product> 中运行')
```

A `dart format` run reformatted 1221 lines of `editor_page.dart` outside my
changes. I reverted the file to HEAD and re-applied only my three edits, so the
committed diff is insertion-only. Do not run `dart format` on that file as part
of this task.

### 2. Cross-owner interfaces

- Item 1 from the earlier Result (`StudioProfile.interopRunner`) is now dead:
  the field exists and the editor consumes it. A language app still has to pass
  an `InteropRunner` instance to show the item; that is one constructor line in
  each app's `main.dart`.
- Item 2 (`run_command` routing) remains owner B's edit. A is now changing the
  controller and was told to call `InteropRunner.tryRunCommand`. I did not touch
  `lib/vibe_coding/**`. Note: `flutter analyze --no-pub lib` currently reports
  one error in `lib/vibe_coding/vibe_coding_controller.dart:824`
  (`abortTrigger` parameter undefined), which belongs to that in-flight work.

### 3. `module.json5` audit

Your instruction assumed I had overwritten and restored the whole file. I
re-checked it. `git diff HEAD` on
`qflistudio/ohos/entry/src/main/module.json5` is now exactly the two
other-session changes, and **none of my interop changes remain in it**:

```
warning: in the working copy of 'ohos/entry/src/main/module.json5', LF will be replaced by CRLF the next time Git touches it
diff --git a/ohos/entry/src/main/module.json5 b/ohos/entry/src/main/module.json5
index 8efe315..5ed9e93 100644
--- a/ohos/entry/src/main/module.json5
+++ b/ohos/entry/src/main/module.json5
@@ -6,7 +6,7 @@
     "description": "$string:module_desc",
     "mainElement": "EntryAbility",
     "deviceTypes": [
-      "phone"
+      "phone", "2in1", "tablet"
     ],
     "deliveryWithInstall": true,
     "installationFree": false,
@@ -59,6 +59,7 @@
     ],
     "requestPermissions": [
       {"name" :  "ohos.permission.INTERNET"},
+      {"name" :  "ohos.permission.GET_NETWORK_INFO"},
       {
         "name": "ohos.permission.READ_PASTEBOARD",
         "reason": "$string:pasteboard_reason",
         "usedScene": {
```

Line-by-line reading:

| Line | State now | Owner |
| --- | --- | --- |
| `deviceTypes` | `phone`, `2in1`, `tablet` | other session, restored |
| `InteropBridgeAbility` entry | present in HEAD (`f5af762`), absent from this diff | mine, committed |
| `ohos.permission.GET_NETWORK_INFO` | present | other session, restored |

**Conclusion, and the thing to check:** my `InteropBridgeAbility` block was
committed in `f5af762`, and this working-tree diff no longer shows it, which
means the block is in HEAD and the JSON is consistent. What I cannot prove is
whether the pre-overwrite version also had anything else on the same lines I
touched. What I restored is exactly what `git diff` showed me before I
overwrote it: `deviceTypes` on one line and `GET_NETWORK_INFO` after `INTERNET`.
If your original had more there, only your copy can confirm it.

### 4. Device

`hdc list targets` was run again and printed `[Empty]`, exit 0. **No OHOS
device or emulator is available**, so a real cross-app launch, compile and run
is still unverified.

### 5. Tests run for this follow-up

- `flutter analyze --no-pub lib/editor/editor_page.dart lib/services/studio_profile.dart lib/interop`: no issues.
- `flutter test --no-pub` on the four interop test files: 85 passed.
- `flutter analyze --no-pub lib`: one pre-existing error in
  `lib/vibe_coding/vibe_coding_controller.dart`, owned by A.

### 6. Main app wiring (done)

`qflistudio` commit `6153ea7`.

`lib/main.dart` now passes `interopRunner: const InteropRunner(),` into
`qfliStudioProfile`, with
`import 'package:qfli_studio_core/interop/interop_runner.dart';`.

Only the main app starts the link. The language apps are receivers, so their
`main.dart` files were not touched.

That file already held 51 lines of another session's uncommitted work
(`contentRepositoryFactory`, `StudioContentRepository`, the startup binding,
and more). The committed change is 4 insertions and 0 deletions: the import,
one comment pair and the runner line. The index was built from HEAD plus only
that change, so the other session's 52/9 diff is still unstaged in the working
tree exactly as it was.

`flutter analyze --no-pub lib/main.dart`: no issues.

**This entry is verified only at compile and unit-test level.** No OHOS device
or emulator is available (`hdc list targets` is empty), so nothing here shows
that a tap on the entry reaches a sibling app, that the receiver compiles, or
that output comes back. What is verified: the editor's entry decision, the
protocol codec, the payload limits, the command routing, the install hint and
the ArkTS contract, all by tests, plus both OHOS builds.

### 7. Correction on commit discipline

My first attempt at this wiring used `git commit -F <file> -- lib/main.dart`.
That pathspec did not restrict the commit: it committed the working-tree file,
which carried the other session's 51 lines. I reverted it immediately with
`git reset --soft`, restored the index with `git restore --staged --source=HEAD`,
confirmed the working tree still held the 52/9 diff, and committed again with no
pathspec after verifying `git diff --cached --stat` showed 4 insertions.

The lesson, for the next pass: `-- <path>` on `git commit` selects which files
join the commit, not which content. To commit a subset of one file, build the
index first and commit without a pathspec.
