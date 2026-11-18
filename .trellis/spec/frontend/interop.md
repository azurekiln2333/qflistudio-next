# Studio to sibling-app interop

## 1. Scope / Trigger

Apply this contract to `qfli_studio_core/lib/interop/`, editor run actions,
`StudioProfile`, and the OHOS bridges in Studio and the language apps.
The owning task is `.trellis/tasks/11-01-ohos-app-interop/`.

Status: `Draft`. The foreground route remains a compatibility path. The separate
Java background route is experimental. Its UI must not promise absence of a
visible launch transition until hardware evidence establishes that behavior.
Build success and simulated API tests do not establish device acceptance.

The user approved separate routes on 2026-11-05. Preserve the existing Run
button, foreground receiver, dialog, channels, and Vibe routing. Keep the new
action explicit. Never fall back from background execution to foreground or
online execution automatically.

## 2. Signatures

```dart
const String kInteropProtocol = 'qfli-interop/1';

// Optional StudioProfile fields. Null hides the corresponding feature.
final InteropRunner? interopRunner;
final InteropRunner? backgroundInteropRunner;

const backgroundRunner = InteropRunner(
  transport: MethodChannelBackgroundInteropTransport(),
);

// Both routes implement the existing interface.
Future<InteropProbe> probe(InteropTarget target);
Future<InteropLaunch> start(InteropTarget target, InteropRequest request);

// InteropLaunch owns Stream<InteropEvent> events and Future<void> cancel().
// InteropRun exposes stdout, stderr, exitCode, cancel, and diagnostics.
// Background launches also provide stop(): Future<InteropStop>.
// InteropStop carries exitCode, message, and confirmed. Only an authenticated
// receiver terminal frame makes confirmed true; local failures keep it false.
Future<InteropRun> run({
  required String projectRoot,
  required String language,
  required String entryFile,
  String stdin = '',
  Duration timeout = const Duration(seconds: 60),
});
```

| Boundary | Foreground route | Experimental background route |
| --- | --- | --- |
| Dart transport | `MethodChannelInteropTransport` | `MethodChannelBackgroundInteropTransport` |
| Method channel | `qfli_interop/bridge` | `qfli_interop/background` |
| Event channel | `qfli_interop/bridge/events` | `qfli_interop/background/events` |
| Studio native owner | `StudioInterop.ets` | `StudioBackgroundInterop.ets` |
| Java receiver | `InteropAbility` | `InteropBackgroundService` (appService extension) |
| Results | `InteropBridgeAbility` launch | `com.azurekiln.qfli.interop.background.EVENT` |
| Cancellation | Studio-local cancellation marker | `com.azurekiln.qfli.interop.background.CANCEL` |
| Editor presentation | Existing run dialog | Existing `TerminalPane` |

Background method arguments:

- `start`: `{bundleName, abilityName, parameters}`. Java's bundle is
  `com.azurekiln.qfli.java`. The receiver must be the windowless
  `InteropBackgroundService` extension, with `InteropBackgroundAbility` kept
  only as a fallback that a device round must report as degraded.
- The receiver must not be a UIAbility. A visible receiver takes the foreground
  from Studio, the suspend manager then freezes Studio, and every later result
  frame is refused with `freezePid`. The extension creates no window, so Studio
  keeps the foreground and delivery works. Evidence:
  `tasks/11-01-ohos-app-interop/research/pi-D-20261109.md`.
- Studio requests a transient allowance before the launch, not after it. Asking
  after the launch returns `9900002`, which means the foreground transition has
  not settled yet, not that the quota is spent.
- `parameters`: `InteropRequest.toLaunchParameters()` plus `zipPath`.
- `start` returns `{notificationEnabled: true}` after launch succeeds.
  A platform rejection retains its diagnostic message.
- `cancel` and `dispose`: `{sessionId, sessionToken}`. A method reply alone
  does not prove receiver termination.
- Background `probe()` returns `unknown` locally. It never starts an ability.

## 3. Contracts

### Payload and shared protocol

The project crosses app sandboxes as one ZIP under a file-URI read grant.
`writePayloadZip()` creates it in Dart. Studio converts `zipPath` to a URI and
sets `FLAG_AUTH_READ_URI_PERMISSION` on the Want. The receiver opens the granted
URI, copies the ZIP into its own cache, and validates the extracted paths and
size. A raw path inside Studio's sandbox is not a receiver-readable payload.

The MethodChannel request includes `files` and `filesDigest`. Studio validates
file metadata and size. The cross-app Want carries `payloadUri`, not source bytes.
Do not claim that the receiver verifies the ZIP digest: the shared receiver
currently revalidates paths, file count, and decoded size after extraction.

| Field or limit | Contract |
| --- | --- |
| `protocol` | Exactly `qfli-interop/1` |
| `sessionId` | 8–64 characters, `[A-Za-z0-9_-]` |
| `sessionToken` | 16–64 alphanumeric characters. Runner generates fresh random hex |
| `language` | Background route accepts only `java` on OHOS |
| `action` | `compile`, `run`, or `analyze`. Editor background action uses `run` |
| `entry` and payload paths | Relative POSIX paths under the collected project. No absolute, traversal, hidden, drive-prefixed, or control-character segments |
| Project payload | At most 64 files and 256 KiB decoded bytes. Reject oversize payloads |
| `stdin` | At most 4 KiB. No NUL |
| `timeoutMs` | 1000–120000 ms |

The foreground ZIP directory is `<cache>/qfli_interop/out/`. The background
route passes `<cache>/qfli_interop_background` as the ZIP writer's cache root.
This separation matters because the writer removes stale output files.
Never point both live routes at the same output directory.

### Foreground compatibility boundary

The current Java foreground receiver aggregates compiler/program output into
one final response and starts Studio's `InteropBridgeAbility` to deliver it.
Do not describe this path as real-time background streaming.

The foreground cancel method marks the session locally. Its Dart transport
closes its subscription, and the shared runner may report exit 130. That is
not an acknowledged native process stop. Do not copy this behavior into the
background transport or document it as verified process-tree cleanup.

The working-tree preservation baseline is
`tasks/11-01-ohos-app-interop/research/background-baseline-20261105.json`,
relative to `.trellis/`. It covers nine files, including uncommitted work.
Compare against these hashes when checking isolation, not only Git HEAD.
The permitted change to `StudioInterop.ets` is adding `export` to
`validateRequest` and `payloadZipPath`, without changing their bodies.

### Background lifecycle and event authentication

- Claim one active background session before asynchronous preparation. A
  concurrent request fails as busy instead of replacing channel ownership.
- Return an owned `InteropLaunch` before the native start completes. Subscribe
  to the Dart event channel before invoking native `start`. Buffer early events
  until `InteropRunner` attaches its listener.
- Studio awaits the native CommonEvent subscription before starting Java.
  Java verifies the system-injected caller bundle against
  `com.azurekiln.qflistudio`, not only the caller's claimed parameter.
- Both CommonEvent subscriptions restrict `publisherBundleName`. Result and
  cancel messages target the recipient bundle. `data` contains JSON with the
  session ID and token. Result messages also carry protocol, sequence, event
  kind, text, and optional exit code/error code.
- Authenticate session ID and token before parsing result content. Ignore
  foreign sessions, wrong tokens, duplicates, and reordered events. The Dart
  sequencer rejects a sequence gap rather than claiming a complete transcript.
- Normalize only integral wire fields (`seq` and `exitCode`). Finite integral
  doubles may become integers. Fractional and non-finite values remain invalid;
  normalization must not round them into valid events or change payload data.
- A receiver emits at most one terminal event. Queue publications so a terminal
  frame cannot overtake an in-flight output frame. Do not replay streamed output
  inside the final result.
- Queuing the terminal frame must not discard output already queued before it.
  Reject new sends after terminal ownership is claimed, while draining the
  earlier output chunks in sequence.
- Register an authenticated cancellation gate during receiver creation. Keep
  it subscribed until the runner's subscription is ready, then recheck its
  recorded cancellation before starting work. If disposal precedes subscription
  completion, unsubscribe the captured handle after registration settles.
- Refusing a second request must preserve the first request, including while
  the first is waiting for foreground callbacks and has no runner yet. The busy
  refusal does not terminate the ability that owns the first request.
- Wait for both `onWindowStageCreate` and `onDidForeground` before requesting a
  transient task. Window creation or `onForeground` alone does not establish
  completion of the foreground transition. This new path requires API 20.
  After obtaining the allowance, minimize the window before JDK preparation.
- Bound preparation, JDK setup, compilation, and execution by
  `min(timeoutMs, actualDelayTime - 2500)`. Reject an allowance below 1000 ms.
  A rejected allowance is a real failure, not permission to run unbounded.
- The receiver stops and polls its native JVM process before sending a terminal
  acknowledgement. `cancelJava` currently targets that JVM PID. It does not
  prove cleanup of arbitrary `ProcessBuilder` descendants.
- Dart enforces an independent total deadline of `timeoutMs + 10 seconds`.
  It requests cancellation and waits up to 3 seconds for a terminal event.
  A cancelled method call does not substitute for that event.
- The native start reply has its own `startupGrace` bound (10 seconds by
  default). Missing that reply is a transport failure (127). A successful
  start without a terminal result still reaches the total deadline (124).
- Missing stop acknowledgement produces exit 127. A total deadline produces
  exit 124 even if a subsequent cancellation acknowledgement reports 130.
  Cancellation before any launch may finish locally with 130.
- End the event subscription, timers, native session, and session ZIP on every
  terminal path. Make repeated cancellation idempotent. Native disposal retains
  only a bounded acknowledgement window for a receiver that starts late.

### Editor and notification ownership

The menu action `后台运行（实验）` appears only for an OHOS Java entry with an
available `backgroundInteropRunner`. It checks the captured project owner,
entry containment, and unsaved buffers. Existing running work blocks a new run.

Open the retained terminal before preparation. Call `TerminalPane.showLocal()`
before `beginPreparation()` so an online tab cannot own this local task.
Pass the new run's streams, exit future, and cancel function to `attachOutput()`.
Stop and page disposal must reach that same cancel function. No modal run
dialog or automatic fallback belongs to the background action.

Studio owns notification ID `27051`. Request permission while Studio is in the
foreground. Refuse the launch when permission or the initial publication fails.
Show actual stages and the terminal result. Exclude source code, output, and
session tokens from notification text. Serialize updates so delayed progress
cannot overwrite completion or a newer session. A notification is a status
surface, not a grant of background execution time.

## 4. Validation & Error Matrix

| Condition | Required result |
| --- | --- |
| Non-Java or non-OHOS background request | Explicit unsupported diagnostic, no launch |
| Background session already active | Busy diagnostic, preserve the active session |
| Missing receiver or native channel | Exit 127, actionable diagnostic, no foreground fallback |
| Invalid entry, empty payload, or oversized payload | Refuse before cross-app launch |
| Notification denied or first publication fails | Exit 127 with platform diagnostic, no launch |
| Foreign publisher/session/token | Drop the event without ending the current run |
| Authenticated malformed event or sequence gap | Fail honestly, dispose the session, no success claim |
| Compiler/program nonzero exit | Preserve real stderr and exit code |
| User Stop with terminal acknowledgement | Preserve the receiver's terminal outcome |
| Stop without acknowledgement | Exit 127 and state that confirmation was not received |
| Receiver budget or Dart deadline expires | Exit 124. Attempt native cancellation and bounded cleanup |
| Page closes while background work runs | Invoke the owned cancellation and release resources |
| Late async preparation after cancellation | Clean late files. Never start compilation afterward |

## 5. Good / Base / Bad Cases

- Good: the explicit background action streams actual Java output into the
  local terminal and reports a confirmed terminal result.
- Base: no notification permission or no compatible receiver yields a visible
  failure while the existing foreground action remains independently available.
- Bad: changing the ordinary Run button to use the new route, returning a
  synthetic success, treating a cancel method reply as a worker exit, or
  promoting simulated API results to proof of a flicker-free device experience.

## 6. Tests Required

Run focused shared-core tests after transport or UI changes:

```text
flutter test --no-pub test/interop_background_transport_test.dart test/editor_background_run_test.dart
```

Assert channel isolation, early terminal delivery, token/session validation,
sequence gaps, cancellation acknowledgement, total timeout, notification
refusal, busy rejection, and ZIP separation. UI tests must prove the default
button still uses the foreground transport, the experimental menu is gated,
output uses TerminalPane, online-tab selection cannot change ownership, and
page disposal cancels the new run.

Run `node scripts/test-ohos-background-bridge.cjs` in Studio after native caller
changes. It executes the transpiled ArkTS bridge with mocked platform APIs.
Assert subscribe-before-start, partial-start disposal, late-event cancellation,
notification ordering, and missing-event failure. It is not a hardware test.

Run `node tool/verify_interop_background.cjs` in `qfli_java` after receiver
changes. Cover the window-plus-foreground start gate, transient-task rejection,
the total budget, cancellation, process reaping, and late preparation cleanup.

Changes to the shared codec/payload additionally require the existing
`interop_protocol_test.dart`, `interop_runner_test.dart`, and
`interop_zip_test.dart`. Build fresh Studio and Java HAPs after ArkTS changes.
Record on-device output, exit codes, notification visibility, cancellation,
timeout, and foreground/window behavior before accepting the background route.

## 7. Wrong vs Correct

Wrong: silently redirect the ordinary Run backend to an unverified route.

```dart
interopRunner: const InteropRunner(
  transport: MethodChannelBackgroundInteropTransport(),
),
```

Correct: keep a distinct optional runner and explicit UI action.

```dart
interopRunner: const InteropRunner(),
backgroundInteropRunner: const InteropRunner(
  transport: MethodChannelBackgroundInteropTransport(),
),
```

Wrong: finish cancellation after the platform accepts the `cancel` method.

Correct: wait for the authenticated terminal event within the acknowledgement
budget. If it never arrives, report that failure and release owned resources.
