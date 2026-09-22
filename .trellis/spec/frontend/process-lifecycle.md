# External Process Lifecycle

## 1. Scope / Trigger

This contract applies whenever a Flutter desktop path starts an operating
system process. Native in-process runtimes do not use this API, but they must
provide equivalent cancellation and disposal behavior.

## 2. Signatures

Use `ProcessSupervisor.start(...)` and retain the returned `ManagedProcess`.
Expose `ManagedProcess.stdout`, `stderr`, `stdin`, `exitCode`, `cancel()`, and
`dispose()` to the UI owner. Do not return a bare `Process` from a new runner.

## 3. Contracts

- Register the process before awaiting the platform starter.
- Drain stdout and stderr, close stdin during cancellation, and await `exitCode`.
- Windows cancellation must attempt `taskkill /PID <pid> /T /F` before direct kill.
- Page or app disposal must call the supervisor's idempotent `dispose()`.
- A completed or cancelled process is removed from `activeProcesses`.

## 4. Validation & Error Matrix

| Condition | Required behavior |
| --- | --- |
| starter throws | remove the pending handle and rethrow the start error |
| natural exit | await both output streams, then publish the exit code |
| cancellation twice | perform one kill path and complete both calls |
| Windows tree kill fails | fall back to `Process.kill()` and still await exit |
| page closes while running | cancel the handle and leave no active process |

## 5. Good / Base / Bad Cases

- Good: `final run = await supervisor.start(...); return run.stdout;`
- Base: a short-lived `Process.run` probe whose result is fully awaited.
- Bad: returning `Process` to a widget and calling only `process.kill()` in
  `dispose()` without awaiting the process or closing its streams.

## 6. Tests Required

- Assert registration happens before a delayed starter resolves.
- Assert stdout/stderr are forwarded and a natural exit removes the handle.
- Assert cancellation is idempotent, waits for exit, and uses tree termination
  on Windows.
- Assert editor/page disposal leaves `activeCount == 0`.

## 7. Wrong vs Correct

### Wrong

```dart
final process = await Process.start('tool', args);
return RunResult(process: process);
```

### Correct

```dart
final process = await supervisor.start('tool', args);
return RunResult(managedProcess: process);
```

## Language runtime and content release contract

### 1. Scope / Trigger

This contract applies when a language App adds an external desktop compiler or
interpreter, a HarmonyOS native runtime channel, or bundled tutorial/example
content.

### 2. Signatures

- A language runner implements `Future<ProgramRunResult?> run({required String projectPath, required String entryFile})`.
- External processes are created through `ProcessSupervisor.start` and exposed
  through `ProgramRunResult.cancel`.
- Aggregate content is stored in `assets/content/tutorials.json` and
  `assets/content/examples.json`; every item has `language` and `type`.

### 3. Contracts

- Desktop C/C++ uses one Clang boundary; `clang` and `clang++` only differ in
  driver mode and language standard.
- HarmonyOS runners call a native channel and never launch a desktop binary.
- Missing native capability returns exit code `127`; it must not emit fake
  program output or be reported as `available`.
- `tool/validate_content.dart` must pass the 100 tutorial and 100 example
  minimum for every supported type before release.

### 4. Validation & Error Matrix

| Condition | Required behavior |
| --- | --- |
| compiler probe fails | C may return `null` for its interpreter fallback; C++ returns a 127 diagnostic |
| native channel missing | return 127 and identify the missing bridge |
| user/page cancellation | invoke `cancel`, await process-tree cleanup, and close output streams |
| content type or metadata missing | validator rejects the entry |
| per-type content count below 100 | release validator fails |

### 5. Good / Base / Bad Cases

- Good: Clang compile and run are both supervised, and the editor receives the
  same cancel function that owns the process.
- Base: JSON and Markdown expose preview/validation capability without a
  misleading program-run action.
- Bad: changing `runtimeStatus` to `available` while the HarmonyOS fixture or
  native `.so` is absent.

### 6. Tests Required

- Assert C/C++ profiles share the Forge product and C++ has a non-zero,
  truthful result when Clang is unavailable.
- Assert `ProgramRunResult.cancel` reaches `TerminalPane` and leaves no active
  supervised process.
- Run `dart run tool/validate_content.dart` and assert every `type` has at
  least 100 tutorials and examples.
- Run `tool/verify_runtime_matrix.dart` and keep unverified products
  unavailable until a target fixture passes.

### 7. Wrong vs Correct

#### Wrong

```dart
return ProgramRunResult(
  title: 'C++ finished',
  stdout: Stream.value('success'),
  stderr: const Stream.empty(),
  exitCode: Future.value(0),
);
```

#### Correct

```dart
final run = await supervisor.start('clang++', args, workingDirectory: projectPath);
return ProgramRunResult(
  title: 'Run main.cpp (Clang)',
  stdout: lines(run.stdout),
  stderr: lines(run.stderr),
  exitCode: run.exitCode,
  cancel: run.cancel,
);
```
