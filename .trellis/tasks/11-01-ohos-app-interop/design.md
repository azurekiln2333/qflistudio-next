# Design: OHOS cross-app toolchain interop

Parent: `.trellis/tasks/11-01-vibe-mature-interop/prd.md`.
Research: `research/ohos-cross-app-20261101.md`.

## 1. Decision summary

- Protocol name **`qfli-interop/1`**, carried in `Want` string parameters,
  not in a shared directory.
- Studio starts the sibling app's **`InteropAbility`** with an explicit
  `bundleName` and `abilityName`.
- The sibling app streams events back by starting the Studio's exported
  **`InteropBridgeAbility`** (`action.system.qfli.interop.event`). The last
  event is `done`.
- Java is the first language. C follows through the same receiver; Python is
  wired but reports the limit documented in §8.

**Platform limit (R6).** OHOS gives no cross-bundle writable directory a third
party can use without a file-provider grant, and the Studio project lives in the
Studio sandbox. The payload therefore crosses as **bounded text inside the
`Want`**. Limit: 64 KiB of payload text, 64 files, 256 KiB before base64.
Projects above that are refused with `payload_too_large`, not truncated.

## 2. Owned files

| File | Repo | Scope |
| --- | --- | --- |
| `lib/interop/*.dart` | `qfli_studio_core` | Protocol, transport, runner, progress UI |
| `ohos/entry/src/main/ets/interop/StudioInterop.ets` | `qflistudio` | Studio side of the channel |
| `ohos/entry/src/main/ets/interop/InteropBridgeAbility.ets` | `qflistudio` | Exported receiver for receiver events |
| `ohos/entry/src/main/module.json5` | `qflistudio` | Bridge ability entry |
| `ohos/entry/src/main/ets/interop/InteropReceiver.ets` | `qfli_java`, `qfli_c` | Receiver side |
| `ohos/entry/src/main/ets/interop/InteropAbility.ets` | `qfli_java`, `qfli_c` | Exported entry point |
| `ohos/entry/src/main/module.json5` | `qfli_java`, `qfli_c` | Exported `InteropAbility` |
| task docs, interop docs | `qflistudio` | This file and `research/` |

`lib/services/studio_profile.dart` (runners) and
`lib/vibe_coding/vibe_coding_controller.dart` (`run_command`) belong to other
owners. §7 states the two interfaces that need their agreement.

## 3. Protocol `qfli-interop/1`

### 3.1 Request (`Request`)

Launch parameters on the `Want` to the receiver:

| Parameter | Type | Rule |
| --- | --- | --- |
| `protocol` | string | Exactly `qfli-interop/1` |
| `sessionId` | string | `[A-Za-z0-9_-]{8,64}`, unique per run |
| `language` | string | Allowlist: `java`, `c`, `cpp`, `python` |
| `entry` | string | Relative POSIX path, same grammar as payload paths |
| `action` | string | `compile`, `run`, `analyze` |
| `stdin` | string | ≤ 4 KiB, no NUL |
| `timeoutMs` | number | 1000–120000 |
| `callerBundle` | string | The Studio bundle name |
| `bridgeAction` | string | Action to start on the caller's bridge |
| `files` | string | JSON array `[{"path": ..., "content": <base64>}, ...]` |
| `filesDigest` | string | Lowercase hex SHA-256 of the exact `files` string |

Rules:

- `files` is one JSON string because a `Want` parameter can hold an array only
  through `parameter` typing the receiver may not share. One string keeps the
  digest verifiable.
- Total decoded payload ≤ 256 KiB, file count ≤ 64.
- Path rule: relative, forward slashes only, no `\`, no leading `/`,
  no drive prefix, no empty segment, no `.` or `..` segment, no NUL,
  no control characters, no segment starting with `.`, length ≤ 240.
- The receiver writes files under
  `<its cacheDir>/qfli_interop/<sessionId>/` after re-validating each path.

### 3.2 Response events

Each event is a start of the bridge ability with:

| Parameter | Type | Meaning |
| --- | --- | --- |
| `protocol` | string | `qfli-interop/1` |
| `sessionId` | string | Echo of the request |
| `seq` | number | 1-based, strictly increasing |
| `event` | string | `accepted`, `stdout`, `stderr`, `progress`, `artifact`, `done`, `error` |
| `text` | string | Chunk text or stage name, ≤ 4 KiB |
| `exitCode` | number | Only on `done` |
| `artifacts` | string | Only on `done`, JSON array of relative names |
| `code` | string | Only on `error`, see §3.3 |

### 3.3 Error codes

| Code | Cause |
| --- | --- |
| `bad_request` | A required parameter is missing, malformed, or fails a grammar rule |
| `unsupported_protocol` | `protocol` is not a version this receiver speaks |
| `caller_not_allowed` | `callerBundle` is not in the receiver allowlist |
| `payload_too_large` | File count or decoded size above the cap |
| `payload_integrity` | `filesDigest` does not match `files` |
| `unsupported_language` | Receiver does not implement `language` |
| `toolchain_unavailable` | The app's own toolchain cannot start |
| `compile_failed` | Compiler returned non-zero |
| `run_failed` | Program returned non-zero |
| `timeout` | `timeoutMs` elapsed |
| `cancelled` | Receiver saw a cancel intent |
| `internal` | Anything else; `text` carries the message |

Versioning: a receiver rejects `qfli-interop/2` with
`unsupported_protocol`. A new minor field must be ignorable by an old receiver,
so no field is ever repurposed.

### 3.4 Handshake

Before it offers a run action, Studio sends a request with `action: analyze`,
`language`, and an empty `files` array. A receiver that answers `done` with
exit code 0 is installed and capable. `startAbility` failure maps to
`app_missing`, and the UI shows the install hint.

## 4. Studio side (`qfli_studio_core/lib/interop/`)

| File | Responsibility |
| --- | --- |
| `interop_protocol.dart` | Codecs, grammar validators, error codes, `InteropRequest` / `InteropEvent` |
| `interop_payload.dart` | Project to payload collection with the same limits as `VibeProjectSnapshot` |
| `interop_transport.dart` | `MethodChannel('qfli_interop/bridge')`; `start`, `probe`, `cancel`; `EventChannel('qfli_interop/bridge/events')` |
| `interop_targets.dart` | Language to bundle/ability/product map and the install hint text |
| `interop_runner.dart` | `run()` returns a `ProgramRunResult`-compatible handle |
| `interop_run_dialog.dart` | Progress, streamed output, cancel |

Contracts:

- `InteropTransport` is an interface so tests can run without a device.
- `InteropRunner.run` never invents output. A missing app yields
  `kProgramNotRunExitCode` (127) and a hint, never exit 0.
- Cancellation sets a cancel flag, sends `cancel` on the channel, and completes
  the exit future with `cancelled` text.
- The Studio side validates every event: protocol, session id, sequence order.
  An out-of-order or mismatched event is dropped and reported.

## 5. Receiver side

- `InteropAbility.onCreate` reads the `Want` parameters and calls
  `receive(request)` in `InteropReceiver.ets`.
- `InteropReceiver.ets` is a shared template: the Java and C copies differ only
  in the `LANGUAGE`, `BUNDLE`, and launch section. It validates the request,
  writes the payload, invokes the app's existing native bridge, forwards
  events, and finally emits `done`.
- Event emission is throttled: at most one event per 150 ms, stdout and stderr
  merged in arrival order, tails capped at 128 KiB.
- Java first: `qfli_java` already owns `JavaBridge.ets` with `prepare`, `start`,
  `poll`, `cancel`. The receiver compiles every `.java` payload file with
  `javac` through that bridge, then runs the entry main class.
- C next: `qfli_c` owns `qfli_forge/native` with `start`, `terminalStart`,
  `cancel`.
- The receiver deletes `<cacheDir>/qfli_interop/<sessionId>` on `done` and on
  cancel.

## 6. Security (R5)

- Receiver allowlist: `com.azurekiln.qflistudio` only, compared to
  `callerBundle` **and** to the bundle that actually started the ability when
  the platform exposes it. A mismatch is `caller_not_allowed`.
- Studio bridge allowlist: `com.azurekiln.qfli.java`, `com.azurekiln.qfli.cpp`,
  `com.azurekiln.qfli.pyflow`. Studio answers only sessions it started.
- Payload paths are re-validated inside the receiver and joined with the fixed
  session directory, so no path escapes.
- No file outside the session directory is ever read or written.
- No payload byte is logged. The receiver logs the session id, the language and
  the exit code only.

## 7. Interfaces that need another owner's agreement

1. **`StudioProfile`** needs one optional field so the desktop shell can offer
   the interop run button:
   `final InteropRunner? interopRunner;`
   Owner of `lib/services/studio_profile.dart` adds the field and the language
   apps pass their instance. Until then `InteropRunner` is constructible and
   testable, and the editor does not show the button.
2. **`run_command` in Vibe Coding** (owner B) needs to route a compile or run
   through interop when the platform is OHOS and the language has a receiver.
   Proposed shape:
   `InteropRunner.tryRunCommand({required String projectRoot, required String command, required String language})`
   returns a real exit code and merged output, or `null` to keep the existing
   terminal path. The command grammar accepted by interop is narrow:
   `javac <paths>` and `java <MainClass>`. Any other command returns `null`.

Both items are reported in `implement.md` and are not implemented here.

## 8. Python limit

`qfli_python` loads `libqfli_py.so` through `dart:ffi` on the Flutter side. The
Flutter engine lives in the same ArkTS runtime as the interop ability, so the
FFI loader inside the interop ability resolves the same library. The receiver
policy is the same as Java:

- Copy the payload into a temporary session directory under the app cache.
- Compile each `.py` source in the payload with the bundled MicroPython
  artifact step.
- Run the entry file with the same arguments `PythonRunner` uses.

That path is recorded but not implemented in this task. Acceptance for this
task covers Java on OHOS, C code above it, and Python as a stated follow-up.

## 9. Validation plan

| Test | Kind |
| --- | --- |
| Round trip of request and events, including base64 and digest | Dart unit |
| Grammar rejects: absolute path, `..`, backslash, drive letter, NUL, dot segment | Dart unit |
| Size caps produce `payload_too_large` | Dart unit |
| Digest mismatch produces `payload_integrity` | Dart unit |
| Sequence gaps and wrong session ids are dropped by the transport | Dart unit |
| Missing app maps to exit 127 and a hint | Dart unit |
| Allowlist rejects an unknown caller bundle | Dart unit, ArkTS shape mirror |
| OHOS build of `qfli_java` with the new ability | `hvigorw assembleHap` |
| Device launch, compile, run | blocked: no device attached |

The ArkTS receiver cannot run in the Dart test harness. Its behavior is covered
by a table test that reads the `.ets` source and asserts the allowlist, the
grammar call sites and the event names exist, plus the build.
