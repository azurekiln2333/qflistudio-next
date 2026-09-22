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
