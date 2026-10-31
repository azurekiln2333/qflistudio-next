# Studio to `qfli_*` app interop

## 1. Scope / Trigger

Apply this contract when Studio asks a sibling language App to open, compile or
run a project on HarmonyOS. It covers `qfli_studio_core/lib/interop/**` and the
OHOS `ets/` plus `module.json5` files of `qflistudio` and every `qfli_*` app.
Those paths belong to the `ohos-app-interop` task.

Status: `Draft`. No interop package exists yet. This file records the shape that
the e2e harness and the OHOS build gate will assume. Treat every signature here
as provisional until that task marks it frozen.

## 2. Signatures (proposed)

```dart
/// One request from Studio to a sibling app.
class InteropRequest {
  final String targetAppId;    // qfli_java, qfli_python, ...
  final String action;         // open | compile | run
  final String projectPath;    // absolute, already inside a project root
  final String entryFile;      // relative to projectPath
}

/// One real outcome. No field is filled in by guesswork.
class InteropResult {
  final bool launched;
  final int? exitCode;
  final String stdoutTail;
  final String stderrTail;
  final String? diagnostic;    // set when the target app or channel is absent
}
```

## 3. Contracts

- Interop is one direction per call: Studio initiates, the language App executes.
  The language App never writes into another App's project directory.
- The target is addressed by `appId`, not by bundle name. Bundle names change
  per release and are owned by each App's `AppScope/app.json5`.
- A missing target, a missing native channel or a missing runtime returns
  `diagnostic` with exit code `127`. It must never report `launched: true` or
  emit invented program output.
- Compile and run on HarmonyOS go through the native channel. Studio never
  launches a desktop binary on OHOS.
- Cancellation propagates: Studio cancels the request, the language App kills
  the process tree and returns the real signal, following
  `process-lifecycle.md`.
- Files cross the boundary as paths plus a project snapshot, reusing
  `VibeProjectSnapshot` limits (64 files, 256 KiB) so a large project fails
  loudly instead of silently truncating.

## 4. Validation & Error Matrix

| Condition | Required behavior |
| --- | --- |
| target app not installed | `diagnostic` set, exit 127, no stdout |
| target app installed, channel missing | `diagnostic` names the channel, exit 127 |
| entry file not in the project root | request rejected before launch |
| compile fails | real compiler stderr tail and real exit code |
| user cancels mid-run | process tree killed, `exitCode` reflects the real signal |
| Studio closes while a run is active | language App cleans up; no orphan process |

## 5. Good / Base / Bad Cases

- Good: Studio opens a Java project in `qfli_java`, requests `run`, and shows the
  real compiler and program output.
- Base: the target App is absent; Studio shows the diagnostic and keeps the
  project intact.
- Bad: Studio shells out to `javac` itself, or the language App reports success
  from a cached artifact.

## 6. Tests Required

- A unit test for the request validation (project root containment, entry file
  existence) that runs without HarmonyOS.
- `tool/verify_ohos_products.dart` passes for the touched App.
- `tool/build_hap.sh qflistudio` and `tool/build_hap.sh qfli_java` each produce
  a fresh HAP; record the artifact path and size.
- A live run on OHOS hardware records the real exit code in the e2e report
  (`execution: terminal`).

## 7. Wrong vs Correct

### Wrong

```dart
// Silent fallback that hides a missing channel.
return InteropResult(launched: true, exitCode: 0, stdoutTail: 'ok');
```

### Correct

```dart
return InteropResult(
  launched: false,
  exitCode: 127,
  stdoutTail: '',
  stderrTail: '',
  diagnostic: 'qfli_java 未安装原生运行通道',
);
```
