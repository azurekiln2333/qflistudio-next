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
Studio sandbox. Limit: 64 files and 256 KiB of decoded content. Projects above
that are refused with `payload_too_large`, not truncated.

Amendment 2026-11-05 (device evidence). The first implementation passed a
plain cache path in the Want and the receiver read it directly. On a real
device the receiver's mount namespace resolves that path inside its own
sandbox, so every run was refused with `payload 目录不存在` before any compile.
The payload now crosses as **one zip file shared through OHOS file-URI
temporary authorization** — the platform's own cross-app permission mechanism:
the Want carries `uri` plus `FLAG_AUTH_READ_URI_PERMISSION`, the receiver opens
the granted URI, copies the zip into its own cache and decompresses it there.
Every path, the file count and the byte cap are re-validated after the
decompress. The caller and receiver apps hold different debug certificates, so
certificate-based app-group sharing is not an option here; the URI grant is.

The first draft put the whole payload in a `Want` string parameter. One string
of 256 KiB exceeds the documented parameter budget, and a truncated parameter
would arrive as a silently corrupt project, so the design uses a directory plus a
manifest instead. The digest is still sent, and both sides compute it from the
same encoded JSON, so a mismatch is `payload_integrity` rather than a compile
of the wrong bytes.

Observed 2026-11-01: the Studio side built successfully with this design. The
receiver was not executed, because no device was attached.

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
| `payloadUri` | string | `file://` URI of the payload zip in the caller's cache. The Want also carries that URI and `FLAG_AUTH_READ_URI_PERMISSION`; the receiver opens it, copies the zip and decompresses it into its own cache |

Rules:

- `files` is one JSON string because a `Want` parameter can hold an array only
  through `parameter` typing the receiver may not share. One string keeps the
  digest verifiable. `files` crosses the MethodChannel between Dart and the
  Studio ArkTS bridge; the Want to the receiver carries only the zip URI.
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

Client-local codes: `app_missing`, `transport_failure`, `sequence_gap` and the
Studio-side refusals `busy`, `notification_disabled`, `notification_failed`,
`cancel_failed` never appear in a receiver event. They reach Dart as a platform
or transport error and are reported as 127. Do not read them as protocol codes.

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
  `parseRequest` then `copyPayload` in `InteropReceiver.ets`.
- `InteropReceiver.ets` is a shared template: the Java and C copies differ only
  in the `LANGUAGE`, `ALLOWED_CALLER`, and launch section. It re-validates the
  request, copies the granted zip into its own cache, decompresses it,
  re-validates every path the zip restored, invokes the
  app's existing native bridge, forwards events, and finally emits `done`.
- Event emission follows the child's output tail: each poll reads the bytes the
  child appended since the last poll and sends them as one `stdout` or `stderr`
  event. A run that produced nothing sends nothing; nothing is invented.
- Java first: `qfli_java` already owns `JavaBridge.ets` with `prepare`, `start`,
  `poll`, `cancel`. The receiver compiles every copied `.java` file with
  `javac` through that bridge, then runs the entry main class.
- C next: `qfli_c` owns `qfli_forge/native` with `start`, `terminalStart`,
  `cancel`.
- The receiver deletes `<cacheDir>/qfli_interop/in/<sessionId>` and its work
  directory after `done`, after `error`, and after a timeout.
- The ability stays in the foreground while the child runs, because a sibling
  app may not start abilities from the background.

## 6. Security (R5)

- Receiver allowlist: `com.azurekiln.qflistudio` only. The transmitted
  `callerBundle` must match it, and the ability accepts only that caller. A
  mismatch is `caller_not_allowed`.
- Studio bridge allowlist: `com.azurekiln.qfli.java`, `com.azurekiln.qfli.cpp`,
  `com.azurekiln.qfli.pyflow`, checked against the bundle that actually started
  the bridge ability. Studio answers only sessions it started.
- Payload paths are re-validated inside the receiver and joined with the fixed
  session directory, so no path escapes.
- No file outside the session directory is ever read or written.
- No payload byte is logged. The receiver logs the session id, the language and
  the exit code only.

Review note (2026-11-09): `InteropAbility.handle()` still logs the caller's
parameter key names, `want.uri` and `payloadUri`. That is outside this rule; the
URI alone reveals the Studio sandbox path and the session id. Remove those three
lines once the device evidence they were added for is recorded.

## 7. Interfaces that need another owner's agreement

1. **`StudioProfile`** needs one optional field so the desktop shell can offer
   the interop run button:
   `final InteropRunner? interopRunner;`
   Owner of `lib/services/studio_profile.dart` adds the field and the language
   apps pass their instance. Until then `InteropRunner` is constructible and
   testable, and the editor does not show the button.
2. **`run_command` in Vibe Coding** (owner B) needs to route a compile or run
   through interop when the platform is OHOS and the language has a receiver.
   The implemented entry point is
   `InteropRunner.tryRunCommand({required String projectRoot, required String language, required String command})`.
   It returns an `InteropRun` with real output and exit code, or `null` to keep
   the existing terminal path. The accepted command grammar is narrow: a bare
   `javac` compiles the payload, and `python <relative path>` / `python3 <relative path>`
   runs one file. Anything else returns `null`, so a shell pipeline can never
   change meaning across apps.

Both items are reported in `implement.md` and are not implemented here.

## 8. Python and C follow-up

`qfli_python` loads `libqfli_py.so` through `dart:ffi` on the Flutter side. A
receiver for Python would have to drive that VM from inside the same app, so it
is a separate piece of work with its own verification. `qfli_c` would reuse its
existing `qfli_forge/native` channel the same way the Java receiver reuses
`qfli_jvmx/jdk`.

Both are recorded here and not implemented in this task. Acceptance for this
task covers the protocol, the Studio side, and Java on OHOS.

## 8a. Background route platform review (2026-11-09)

Read-only review of the background increment. Evidence and per-item disposition:
`research/pi-D-20261109.md`.

- **API floor is 20.** Both `UIAbility.onDidForeground` and the Promise form of
  `commonEventManager.subscribeToEvent` are `@since 20`, while both apps build
  with `compatibleSdkVersion 5.1.0(18)`. The background route therefore needs a
  platform at API 20 or later. On an 18/19 platform the first subscribe throws a
  `TypeError` that surfaces as `internal`/127. Record this floor here and refuse
  with a named error instead of throwing.
- **`CommonEventData.bundleName` is not the publisher identity.** The documented
  filter is `publisherBundleName` in the subscribe info, which both sides
  already set. SDK text for `CommonEventData.bundleName` is only "left empty by
  default". A second comparison against it can drop every result frame without
  a trace, so it must not carry authentication on its own.
- **A visible transition was inherent to the UIAbility approach.** The receiver
  loads `pages/InteropIdle` and minimizes only after the transient allowance.
  The start window plus that page were visible for that window. §8b settles it:
  the windowless appService extension returns `801` on this tablet, so `prd.md`
  B6 is not reachable here. Record the 410 ms window as the actual shape.
- **Installed artefacts must be newer than their sources.** In the 2026-11-09
  round the Studio HAP was older than the sender sources, so the newest
  diagnostics could not appear on the device. Compare HAP and source timestamps
  before every acceptance round.
- **Device capture must include ability-manager and common-event tags.** Without
  them a refused start and a broken subscription both look like "no events".

No permission is missing for this route. `requestSuspendDelay`,
`commonEventManager.publish`/`subscribe`, `notificationManager.publish`,
`wantAgent.getWantAgent`, `window.minimize` and the file-URI grant all carry no
`@permission` in the API 23 declarations, and neither `module.json5` needs an
addition.

## 8b. Receiver visibility and result delivery (2026-11-09 proof, 2026-11-10 verdict)

Evidence: `research/pi-D-20261109.md` §2, §3 and the fourth round.

**The problem.** Starting a UIAbility receiver moves the foreground away from
Studio. About three seconds later the suspend manager freezes Studio:

```
23:49:33.832 SUSPEND_MANAGER Freeze pid: 44761 success.
             FROZEN_BY_START_WINDOW_AFTER_PULLED_FROZEN
23:49:34.963 Pid 48108 publish ...EVENT to 100 end(1,0,0,1) freezePid[44761,]
```

Every later frame is refused, even though the publisher got a success receipt.
A visible receiver therefore used to lose the terminal frame and the exit code.

**The verdict.** The windowless routes do not exist on this tablet. Both
implicit starts return `801` (capability not supported), and the receiver is
declared and exported correctly, so the failure is platform gating and not
configuration:

```
09:09:45.699 start_service_refused code=801
09:09:45.703 start_hidden_refused code=801
09:09:45.726 launched mode=visible
```

The transient allowance carried delivery instead. The freeze moved past the
terminal frame by about 2.8 s:

```
09:09:45.696 allowance_ok delay=180000
09:09:46.622 first_frame kind=accepted
09:09:50.365 terminal kind=done exit=0
09:09:52.373 Freeze pid: 32201 success.
```

So the design has one mandatory guard and one open gap:

- Mandatory: Studio holds a transient allowance before the launch. This is now
the only mechanism that keeps result delivery alive.
- Open gap: the receiver is visible for about 410 ms (`onCreate` to
  `minimizeDone`). No documented start option removes it on this device class.

Treat `mode=visible` as the supported shape on tablets, not as a degraded
fallback. On 2in1 hardware the extension branch may still win, so keep the
branching and keep recording `mode=`.

The receiver keeps retrying `9900002` when it takes its own allowance. That
error means "foreground transition not yet settled", not "quota spent".

Platform conditions for the extension route, none of them free:

- `startAppServiceExtensionAbility` is `@since 20`. The project floor is 18.
- The target extension must be declared and exported. An invisible target also
  needs `ohos.permission.START_INVISIBLE_ABILITY`.
- Error `16000200` points at `appIdentifierAllowList`, a real
  `extensionAbilities` field (string array, each `<=128`, `[0-9a-zA-Z]+$`).
  The receiver does not set it today.

Record the branch actually taken (`mode=service|hidden|visible`, plus
`start_service_refused code=`). On this tablet `visible` is the only reachable
branch, so acceptance must be judged on the visible branch.

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
| ArkTS source keeps the same protocol, allowlist, caps and grammar | Dart contract test reading the `.ets` files |
| OHOS build of `qflistudio` with the bridge ability | `hvigorw assembleHap` |
| OHOS build of `qfli_java` with the new ability | `hvigorw assembleHap` |
| Device launch, compile, run | blocked: no device attached |

The ArkTS receiver cannot run in the Dart test harness. Its behavior is covered
by a table test that reads the `.ets` source and asserts the allowlist, the
grammar call sites and the event names exist, plus the build.
