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
