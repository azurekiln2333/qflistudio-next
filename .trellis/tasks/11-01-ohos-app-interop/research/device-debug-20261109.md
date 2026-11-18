# Device debug: background Java interop, 2026-11-09

## Device and scope

- Target: `192.168.68.207:46551`.
- OS reports `OpenHarmony-7.0.0.105`.
- Studio: `com.azurekiln.qflistudio`.
- Receiver: `com.azurekiln.qfli.java`, `InteropBackgroundAbility`.
- Root operates the device. Herdr workers inspect or change their assigned files.
- Existing project `BackgroundSmoke` was run without changing its source.

## First device run

Both fresh HAPs installed successfully. After unlocking, Studio opened the
project and invoked the explicit `后台运行（实验）` menu item.

At 10:21:13, the terminal reported an internal failure and exit 127:

```text
BussinessError 9900002: Transient task verification failed.
Request is not allow after the preset time of entering background.
```

Filtered device evidence is in `output/device-debug-20261109/baseline.log`:

- 10:21:13.414: `RequestSuspendDelay` for JVMX PID 55230 was rejected.
- 10:21:13.415: ArkCompiler recorded the exception at
  `InteropBackgroundRunner.ets:377`, inside `reserveAllowance()`.
- The retained log contains one allowance request for this run.
- 10:21:13.480: ArkCompiler reported the JVMX app in background.
- Broader tail logs report its foreground lifecycle later, around 10:21:13.666.

The initial full-buffer capture and newest 10,000-line capture missed the
failure. A tag-filtered capture recovered it:

```text
hdc -t 192.168.68.207:46551 shell "timeout 3 hilog -x -T JSAPP,TRANSIENT_TASK,ArkCompiler"
```

`capture_interop.py` applies an additional local app filter before saving.
Do not publish broad device logs: they include unrelated applications.

The 02:22:34 Java HAP already contained `reserveAllowance` and the specific
stale-background retry message. A read-only inspection of `ets/modules.abc`
confirmed this. The old run therefore warrants checking the error object's
actual `code` type. Existing logs do not establish that type.

## Diagnostic receiver installed at 10:34

Changed files in the sibling `qfli_java` repository:

- `InteropBackgroundAbility.ets`: lifecycle timing, load the existing plain
  ArkUI idle page, and log its completion. Treat null, undefined, and code 0
  callbacks as successful content loading.
- `InteropBackgroundRunner.ets`: log allowance attempts, elapsed time, error
  code type, message, and granted duration. Normalize a numeric string code
  with `Number(code)` while retaining the exact stale-background message and
  five-attempt limit. Other failures remain failures.
- `tool/verify_interop_background.cjs`: add content callback shape coverage and
  adapt window-stage mocks.

The idle-page change and error-code normalization remain hypotheses until a
device run succeeds. No execution allowance check was bypassed.

Validation:

- Receiver harness: 18 PASS.
- `hvigorw assembleHap --mode module -p product=default -p buildMode=debug`:
  successful, 18.950 seconds.
- Signed HAP: `qfli_java/ohos/entry/build/default/outputs/default/entry-default-signed.hap`.
- Artifact timestamp: 2026-11-09 10:34:08. Size: 228131340 bytes.
- `hdc install -r`: `install bundle successfully`.

## Pending hardware acceptance

The device relocked before the diagnostic run. `aa start` returned 10106102.
Root requested a manual unlock. `setmode 602` was accepted, but it did not
prevent relocking. After checking the tool help, root woke the display and set
`power-shell timeout -o 600000`, which explicitly overrides screen-off time to
ten minutes. Restore it with `power-shell timeout -r` after testing.
The launch still returns 10106102. A swipe also leaves the keyguard visible.
No unlock credentials or lock-screen bypass were used.

Still pending: real stdout and exit 0, compiler stderr, streamed output,
confirmed Stop, deadline handling, notification visibility, and visible
receiver transitions. Host tests and HAP installation do not establish these.
