# Isolated OHOS background route

## Decision and boundary

The user approved two separate routes on 2026-11-05. Preserve the foreground
route and add an explicit Java-only background action. Do not change the Run
button, foreground channels, foreground receiver or Vibe routing.

The original files are recorded in `background-baseline-20261105.json`.
Their hashes cover the uncommitted working-tree baseline, not only Git HEAD.

## Data flow

Editor background action -> dedicated Dart transport ->
`qfli_interop/background` -> `InteropBackgroundAbility` -> native JDK.
The existing bounded ZIP is passed with a file-URI read grant.
Results use `com.azurekiln.qfli.interop.background.EVENT`, targeted at Studio.
Cancellation uses `com.azurekiln.qfli.interop.background.CANCEL`, targeted at Java.
Both subscriptions restrict `publisherBundleName`. Messages also match the
protocol, session ID, random session token and increasing sequence number.

Studio subscribes before starting the receiver. Dart also listens before the
native start call. A single active background session avoids event-channel
ownership races. Notifications belong to Studio; permission is requested while
Studio is foregrounded. Denial produces a diagnostic, not fictitious progress.

The new receiver requests a transient task, immediately backgrounds its window,
then compiles/runs with a total deadline bounded by actual granted time. It uses
no reverse `startAbility` to report output. Cancellation reaches the native PID.
Termination removes subscriptions, transient task, timers and session files.

## Platform evidence and limits

The installed API 26 declarations and OpenHarmony official source documentation
were checked. Ordinary CommonEvent publishing/subscription supports targeted
cross-app events. It does not cold-start a killed subscriber or provide runtime.
Transient tasks provide bounded suspension delay, not permanent execution.
Notifications do not grant background runtime.

Public `Window.minimize()` can run from `onWindowStageCreate`. This establishes
a candidate for fast backgrounding, not proof of zero focus change or flicker.
`REQUIRED_HIDE` applies to 2in1/free-window tablets, not ordinary phone startup.
No system-only ServiceExtension/DataShare/staticSubscriber privilege is added.

Official documentation paths (OpenHarmony/docs, master, consulted 2026-11-05):

- `zh-cn/application-dev/reference/apis-arkui/arkts-apis-window-Window.md`
- `zh-cn/application-dev/reference/apis-basic-services-kit/js-apis-commonEventManager.md`
- `zh-cn/application-dev/reference/apis-basic-services-kit/commonEvent/commonEventSubscribeInfo.md`
- `zh-cn/application-dev/reference/apis-basic-services-kit/commonEvent/commonEventPublishData.md`
- `zh-cn/application-dev/quick-start/module-configuration-file.md`
- `zh-cn/application-dev/task-management/transient-task.md`

## Execution and verification

1. Add receiver and caller channels as separate files and manifest registration.
2. Add the optional profile runner and explicit experimental menu action.
3. Test old/new channel isolation, early terminal events, cancellation and timeout.
4. Build fresh HAPs for Studio and Java.
5. Run both paths on an unlocked OHOS device; record foreground/notification/output.
6. Keep strict no-flicker acceptance pending until observed on hardware.

Initial hardware check: `hdc list targets` returned `[Empty]`.
