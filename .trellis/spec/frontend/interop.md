# Studio to `qfli_*` app interop

## 1. Scope / Trigger

Apply this contract when Studio asks a sibling language App to compile, run or
analyze a project on HarmonyOS. It covers `qfli_studio_core/lib/interop/**` and
the OHOS `ets/` plus `module.json5` files of `qflistudio` and every `qfli_*` app,
owned by the `ohos-app-interop` task.

Status: `Draft`. The interface exists in
`lib/interop/interop_protocol.dart`, `interop_targets.dart` and
`interop_runner.dart` and is usable, but the task has not marked it frozen. The
receiver side (`InteropReceiver.ets`) may still move. Re-read those files before
coding against this page.

## 2. Signatures

```dart
const String kInteropProtocol = 'qfli-interop/1';

enum InteropAction { compile, run, analyze }

class InteropTarget {
  final String language;      // wire key, for example java
  final String bundleName;    // observed from the sibling AppScope
  final String abilityName;
  final String productName;
  final Set<String> languages;
}

class InteropRunner {
  bool get isSupported;
  static bool supports(String language);
  Future<InteropProbe> probe(String language);
  Future<InteropRun> run({
    required String projectRoot,
    required String language,
    required String entryFile,
    String stdin = '',
    Duration timeout = const Duration(seconds: 60),
  });
}

class InteropRun {
  final String title;
  final Stream<String> stdout;
  final Stream<String> stderr;
  final Future<int> exitCode;
  final Future<void> Function()? cancel;
  final List<String> diagnostics;   // non-empty when nothing started
  factory InteropRun.failed(String title, List<String> diagnostics);
}
```

`kInteropNotRunExitCode` is `127`, matching `kProgramNotRunExitCode` in
`services/studio_profile.dart`. The interop library keeps its own copy so it
does not import the services layer.

## 3. Contracts

- The payload travels as text inside a `Want`. OHOS gives no cross-bundle
  writable directory, so `interop_protocol.dart` is the only place that decides
  what may cross the boundary.
- Every rule in the Dart codec has a matching check in the receiver
  (`InteropReceiver.ets`). Change both in the same commit.
- The receiver allowlists exactly `InteropStudio.bundleName` and answers only
  `kInteropProtocol`. An unknown version is `unsupported_protocol`, never a
  guess.
- A missing app, an unsupported platform, an entry file outside the project or
  an empty payload returns `InteropRun.failed` with exit code 127. It never
  throws and never reports `stdout` output.
- `run` never launches a desktop binary on OHOS. Compile and run go through the
  native channel of the target app.
- `cancel` reaches the receiver, which kills the process tree and returns the
  real exit code, following `process-lifecycle.md`.
- Bundle names live only in `interop_targets.dart`. A rename is one edit there
  plus the matching `AppScope/app.json5`.

## 4. Validation & Error Matrix

| Condition | Required behavior |
| --- | --- |
| language has no target | `InteropRun.failed` with the install hint, exit 127 |
| transport unsupported on this platform | `InteropRun.failed('当前平台不支持跨应用调用。')`, exit 127 |
| entry file outside `projectRoot` or unreadable | `InteropRun.failed`, exit 127 |
| payload collected but missing the entry | `InteropRun.failed`, exit 127 |
| receiver answers another protocol version | `unsupported_protocol`, no retry |
| payload exceeds `InteropLimits` | `payload_too_large` from the codec, nothing crosses |
| caller bundle not allowlisted | `caller_not_allowed` |
| compile fails | real compiler stderr and real exit code |
| user cancels mid-run | process tree killed, real exit code, no orphan |

## 5. Good / Base / Bad Cases

- Good: Studio runs a Java project through `InteropRunner.run`, and the terminal
  shows the receiver's real compiler and program output.
- Base: `qfli_java` is absent; the terminal shows the install hint and exit 127,
  and the project stays intact.
- Bad: Studio shells out to `javac` itself, or a receiver replies success from a
  cached artifact.

## 6. Tests Required

- `flutter test --no-pub test/interop_protocol_test.dart` and
  `test/interop_runner_test.dart` in `qfli_studio_core`; both run without
  HarmonyOS and cover the codec limits and the runner failure paths.
- `dart run tool/verify_ohos_products.dart` passes for every touched App.
- `tool/build_hap.sh qflistudio` and `tool/build_hap.sh qfli_java` each produce a
  fresh HAP; record the artifact path and size.
- A live run on OHOS hardware records the real exit code in the e2e report
  (`execution: terminal`).

## 7. Wrong vs Correct

### Wrong

```dart
// Silent fallback that hides a missing receiver.
return InteropRun.failed('运行 javac', const ['ok']);
```

### Correct

```dart
final target = InteropTargets.forLanguage(language);
if (target == null) {
  return InteropRun.failed(title, <String>[
    InteropTargets.installHint(language),
  ]);
}
```
