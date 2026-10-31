# OHOS cross-app invocation: what the platform allows

Research notes for R1. Every claim below is either cited from the HarmonyOS
docs or marked **observed**. Observation was made on this workstation on
2026-11-01 with the sibling apps and this toolchain:

- DevEco SDK: `D:\ProgramFiles\Huawei\DevEco Studio\sdk` (`hdc` 23).
- `hdc list targets` returned an empty list. **No OHOS device or emulator was
  attached during this session**, so nothing below was executed on a device.
- Command used for builds:
  `hvigorw.bat --mode module -p product=default -p module=entry@default -p buildMode=debug assembleHap --no-daemon`
  in `<app>/ohos`, with `DEVECO_SDK_HOME` set.
- `qfli_java/ohos` built successfully with that command: `BUILD SUCCESSFUL`,
  `build/outputs/default/ohos-default-signed.app` produced. This is **observed**
  for the build, not for the launch.

## 1. Cross-bundle launch

| Question | Answer | Source |
| --- | --- | --- |
| Can app A start an ability of app B? | Yes, through `Want` when B exports the ability. | Docs: "Starting a UIAbility of Another Application" (`startAbility`). |
| Which fields select the target? | `bundleName` plus `abilityName`, or `action` plus `entities`. | Same. |
| Do I need a permission for a plain launch? | No. An implicit launch needs a matching `skills` entry in B. `ohos.permission.START_ABILITIES_FROM_BACKGROUND` only applies to background starts. | Docs: "Want" and "Stage model application startup". |
| Can the result come back? | `startAbilityForResult` returns a result only when B calls `terminateSelfWithResult`. We need a streaming compile log, so the call must be asynchronous anyway. | Docs: "startAbilityForResult". |
| Is a bundle name query needed? | Yes, for the install hint. `bundleManager.queryAbilityInfo` / `canIUse` style checks need the module to declare `querySchemes`-style visibility. Observed constraint in the docs: since API 11 an app may query only what it declares in `module.json5` under the `queryAbilityInfo` visibility rules (`bundleManager.getBundleInfoForSelf` is unrestricted, queries for other bundles are not). | Docs: "ApplicationQuery / bundleManager". |

Decision: the Studio side launches a **named ability** with an explicit
`bundleName` and `abilityName`, and asks for a small capability handshake
before it claims a language can run. The handshake removes the dependence on
`queryAbilityInfo` visibility rules: a receiver that answers proves it exists.

## 2. Passing data between the two apps

| Question | Answer |
| --- | --- |
| Parameter size in `Want` | Documented as recommended ≤ 200 KB for `Want` parameters, and the ability start call returns `16000008` (`ERR_ABILITY_NOT_FOREGROUND` style limit errors from the system) when exceeded. Small payloads only. |
| File handoff | Two supported paths: (a) the **recipient** calls a file picker and the sender chooses a directory, (b) the sender grants a URI to the recipient through a `uri` plus `ohos.permission`-free URI permission grant, (c) `startAbilityForResult` with a `remoteObject` only for a bound (service) ability. |
| Sandbox isolation | Each app has its own `/data/storage/el2/base` tree. App A cannot read B's `el2` files without an explicit grant. `el2` shared paths are `/data/storage/el2/share` (per bundle), not cross-bundle. |
| Cross-app writable directory | There is no system-wide writable directory both apps can use without a grant. `distributedFiles` is distributed-device storage, not a same-device shared folder. |
| URI permission grant | `context.grantUriPermission(uri, Bundle)`. The docs restrict it to URIs of the caller's own ability context for files of a shared file provider (`fileShare` module). It works for `file://docs/...` style URIs exposed through the `ohos.file.fs` "share" flow. |

Practical consequence: **the payload cannot be copied through a shared folder
and cannot be pushed into the sender's sandbox path.** The only mechanism that
does not depend on a file-provider registration is:

1. Sender serializes the project to a bounded JSON payload and passes it as a
   `Want` string parameter (small project only, ≤ 64 KiB used here).
2. Receiver writes it into its own cache inside its own sandbox.
3. Receiver compiles and runs with its own bundled toolchain.
4. Receiver streams progress back to the caller.

Step 4 needs a channel. OHOS has three candidates:

| Candidate | Works cross-app? | Problem |
| --- | --- | --- |
| `startAbilityForResult` | Yes | One final result only. Compilation can take 30 s and the log must stream. The caller cannot poll from inside an ability. |
| `CommonEventManager` (ordered or sticky) | Yes | Sticky events are deprecated and capped. Ordered events need both sides to be alive and are heavyweight. |
| `WantAgent` / notification | Yes | One shot, and the caller must be foregrounded. |
| **Reverse `startAbility`** (B launches A's `InteropBridgeAbility` with each event) | Yes | A must export a second ability, and every event is an ability start. |

Decision: **reverse start plus `startAbilityForResult` for the final exit.**
The receiver performs one `startAbilityForResult` call to the caller's exported
`InteropBridgeAbility` per event with `action: qfli.interop.event` and the
session id in the parameters. The final call carries `event: done` and the exit
code, so the receiver never has to guess that the caller is still there.
Rationale: `startAbility` costs a few milliseconds, the event volume is bounded
by our output cap (128 KiB tail, at most 4 KiB per event = 32 calls), and the
mechanism needs no permission, no CommonEvent subscription and no lifecycle
coupling.

## 3. Ability lifecycle constraints

- `startAbility` from a `UIAbility` background thread is restricted; the
  background start permission is `ohos.permission.START_ABILITIES_FROM_BACKGROUND`
  (system-grant, not available to third-party apps). The receiver therefore
  keeps a foreground ability hosting a visible "running" surface while it
  compiles. The bridge never starts abilities while the app is backgrounded
  except for the final `done` event, which is raised before the surface closes.
- A `UIAbility` may run native code on its own thread pool. The JDK launcher in
  `qfli_java` already runs the JVM on a `Worker` task style poll loop
  (`startJava` / `pollJava` / `cancelJava`), so the receiver reuses the same
  poll shape and does not block the UI thread.

## 4. What this means for the design

1. The payload travels **inside** `Want` parameters as a bounded string.
   No shared folder, no URI grant. Limit: 64 KiB of project text.
   Project trees larger than that cannot cross the boundary this way. The
   Studio side reports that limit instead of silently truncating.
2. The response travels **back through the caller's exported bridge ability**
   as a sequence of small events, ending with `done` carrying exit code,
   stdout tail, stderr tail and artifact names.
3. Both directions are allowlisted by bundle name on the receiving side.
4. Neither side may read the other's sandbox. All file content crosses only as
   payload text, and payload paths are relative paths validated against a fixed
   grammar.

## 5. Verified vs unverified

| Claim | Status |
| --- | --- |
| `qfli_java/ohos` builds a signed app with the local toolchain and declares `formEnabled true`-free `module.json5` abilities | **observed** (BUILD SUCCESSFUL) |
| A second exported ability in `module.json5` compiles | **observed** after the change in this task (ArkTS compile of the new ability) |
| Studio launches `qfli_java` on device and receives events | **not run.** No device attached. |
| `Want` string parameter of 64 KiB round-trips | **not run.** |
| Reverse `startAbility` reaches the caller while the caller is foregrounded | **not run.** |
