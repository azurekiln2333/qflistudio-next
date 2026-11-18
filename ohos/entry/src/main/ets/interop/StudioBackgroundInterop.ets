/* Independent, opt-in OHOS background route. Never falls back to InteropAbility. */
import { common, Want, wantAgent, wantConstant, StartOptions, contextConstant } from '@kit.AbilityKit';
import { backgroundTaskManager } from '@kit.BackgroundTasksKit';
import { BusinessError, commonEventManager } from '@kit.BasicServicesKit';
import { fileUri } from '@kit.CoreFileKit';
import { notificationManager } from '@kit.NotificationKit';
import notificationTypes from '@ohos.notification';
import {
  FlutterEngine, MethodChannel, MethodCall, MethodResult, EventChannel, EventSink,
} from '@ohos/flutter_ohos';
import { PROTOCOL, STUDIO_BUNDLE, InteropRefusal, validateRequest, payloadZipPath } from './StudioInterop';

const JAVA_BUNDLE = 'com.azurekiln.qfli.java';
const BACKGROUND_ABILITY = 'InteropBackgroundAbility';
/** Windowless receiver. Started through the app service extension API. */
const BACKGROUND_SERVICE = 'InteropBackgroundService';
const SERVICE_ACTION = 'action.system.qfli.interop.background.service';
const RESPONSE_EVENT = 'com.azurekiln.qfli.interop.background.EVENT';
const CANCEL_EVENT = 'com.azurekiln.qfli.interop.background.CANCEL';
const NOTIFICATION_ID = 27051;

interface BackgroundEvent {
  protocol: string;
  sessionId: string;
  sessionToken: string;
  seq: number | string;
  event: string;
  text: string;
  exitCode?: number | string;
  code?: string;
}

class BackgroundSession {
  id: string;
  token: string;
  subscriber: commonEventManager.CommonEventSubscriber | null = null;
  terminal: boolean = false;
  closed: boolean = false;
  cancelled: boolean = false;
  launched: boolean = false;
  noticeEnabled: boolean = false;
  lastSeq: number = 0;
  incomplete: boolean = false;
  sawFrame: boolean = false;
  cancelTimer: number = -1;
  cancelAttempts: number = 0;
  cleanupTimer: number = -1;
  delayId: number = -1;
  pending: Map<string, string>[] = [];

  constructor(id: string, token: string) {
    this.id = id;
    this.token = token;
  }
}

let current: BackgroundSession | null = null;
let sink: EventSink | null = null;
// Serialize status updates so a slow progress publish cannot replace completion.
let notificationQueue: Promise<void> = Promise.resolve();

/**
 * Stage-only diagnostic line.
 *
 * The foreground route logs every stage, so a device run can be read from
 * hilog. The background route crosses a common event instead of an ability
 * start, so without a line here "no output arrived" cannot be told apart from
 * "output arrived and was dropped". Never log payload, token or program text.
 */
function trace(stage: string, detail: string = ''): void {
  console.error(`QFLI_BACKGROUND ${stage} ${detail}`);
}

function notification(session: BackgroundSession, text: string, terminal: boolean): Promise<boolean> {
  if (!session.noticeEnabled) return Promise.resolve(false);
  const operation = notificationQueue.then(async () => {
    const agent = await wantAgent.getWantAgent({
      wants: [{ bundleName: STUDIO_BUNDLE, abilityName: 'EntryAbility' }],
      actionType: wantAgent.OperationType.START_ABILITY,
      requestCode: NOTIFICATION_ID,
      actionFlags: [wantAgent.WantAgentFlags.UPDATE_PRESENT_FLAG],
    });
    await notificationManager.publish({
      id: NOTIFICATION_ID,
      slotType: notificationTypes.SlotType.SERVICE_INFORMATION,
      isOngoing: !terminal,
      tapDismissed: terminal,
      wantAgent: agent,
      content: {
        contentType: notificationTypes.ContentType.NOTIFICATION_CONTENT_BASIC_TEXT,
        normal: { title: 'QFLIStudioN · Java 后台运行', text: text },
      },
    });
  });
  notificationQueue = operation.catch((error: BusinessError) => {
    // No project content or session token is logged.
    console.warn(`QFLI_BACKGROUND_NOTIFICATION_FAILED ${error.code}`);
  });
  return operation.then(() => true).catch(() => false);
}

/**
 * Keeps Studio out of the freeze that silently cuts the result channel.
 *
 * Device evidence, 2026-11-09 23:49 and 23:59: starting the receiver moves the
 * foreground away from Studio, and about three seconds later the suspend
 * manager freezes this process. From then on the event service delivers with
 * `freezePid[<studio pid>,]` and nothing reaches the subscriber, so the terminal
 * frame is lost even though the receiver published it successfully. Studio then
 * also holds no record of the exit code. A process that holds a transient
 * allowance is not frozen. The request has to be made while Studio is still in
 * the foreground: asking after the launch reproduces 9900002.
 */
function reserveSenderAllowance(session: BackgroundSession): void {
  try {
    const allowance = backgroundTaskManager.requestSuspendDelay('QFLIStudioN 等待跨应用运行结果', () => {
      // An expiring allowance is not a run outcome. The terminal frame decides.
      trace('allowance_expired');
    });
    session.delayId = allowance.requestId;
    trace('allowance_ok', `delay=${allowance.actualDelayTime}`);
  } catch (error) {
    const failure = error as BusinessError;
    // The run may still finish: a receiver that keeps Studio foreground (the
    // windowless service) never causes the freeze. Record the degradation.
    trace('allowance_failed', `code=${failure.code}`);
  }
}

function releaseSenderAllowance(session: BackgroundSession): void {
  if (session.delayId < 0) return;
  const id = session.delayId;
  session.delayId = -1;
  try {
    backgroundTaskManager.cancelSuspendDelay(id);
    trace('allowance_released');
  } catch (error) {
    trace('allowance_release_failed');
  }
}

function unsubscribe(session: BackgroundSession): void {
  releaseSenderAllowance(session);
  if (session.cleanupTimer >= 0) {
    clearTimeout(session.cleanupTimer);
    session.cleanupTimer = -1;
  }
  if (session.cancelTimer >= 0) {
    clearInterval(session.cancelTimer);
    session.cancelTimer = -1;
  }
  const subscriber = session.subscriber;
  session.subscriber = null;
  if (subscriber !== null) {
    try {
      commonEventManager.unsubscribe(subscriber, () => {});
    } catch (error) {
      console.warn('QFLI_BACKGROUND_UNSUBSCRIBE_FAILED');
    }
  }
}

function sendCancel(session: BackgroundSession): Promise<void> {
  session.cancelled = true;
  if (!session.launched || session.terminal) return Promise.resolve();
  if (session.cancelTimer < 0) {
    // A start may resolve before the receiver registers its cancellation
    // subscription. Retry this idempotent control within the ACK window.
    session.cancelAttempts = 0;
    session.cancelTimer = setInterval(() => {
      if (session.terminal || ++session.cancelAttempts >= 10) {
        clearInterval(session.cancelTimer);
        session.cancelTimer = -1;
        return;
      }
      publishCancel(session).catch(() => {});
    }, 250);
  }
  return publishCancel(session);
}

function publishCancel(session: BackgroundSession): Promise<void> {
  const message: Record<string, Object> = {};
  message['sessionId'] = session.id;
  message['sessionToken'] = session.token;
  return new Promise<void>((resolve, reject) => {
    commonEventManager.publish(CANCEL_EVENT, {
      bundleName: JAVA_BUNDLE,
      data: JSON.stringify(message),
    }, (error: BusinessError | null) => {
      if (error && error.code !== 0) reject(error);
      else resolve();
    });
  });
}

function disposeSession(session: BackgroundSession): void {
  const wasClosed = session.closed;
  session.closed = true;
  trace('dispose', `terminal=${session.terminal} launched=${session.launched}`);
  if (!session.terminal) {
    sendCancel(session).catch(() => {});
    if (!wasClosed) notification(session, '后台会话已关闭，请查看终端结果', true);
  }
  if (session.launched && !session.terminal && session.subscriber !== null) {
    // Keep a bounded acknowledgement window after Dart gives up. A late
    // accepted event still triggers cancellation instead of orphaning work.
    if (session.cleanupTimer >= 0) clearTimeout(session.cleanupTimer);
    session.cleanupTimer = setTimeout(() => unsubscribe(session), 5000);
  } else {
    unsubscribe(session);
  }
  session.pending = [];
  if (current === session) current = null;
}

export function disposeBackgroundInterop(): void {
  const session = current;
  if (session !== null) disposeSession(session);
  sink = null;
}

function assertActive(session: BackgroundSession): void {
  if (session.closed || session.cancelled || current !== session) {
    throw new InteropRefusal('cancelled', '后台运行已取消');
  }
}

function receive(session: BackgroundSession, data: commonEventManager.CommonEventData): void {
  // Raw delivery first: whether a frame reached this process at all is the one
  // fact the receiver side cannot show, because a dropped frame leaves no log
  // there either. Only the event name and the payload size are recorded.
  const size = typeof data.data === 'string' ? data.data.length : -1;
  trace('raw_frame', `event=${data.event} size=${size} bundle=${data.bundleName}`);
  if (session.terminal || (!session.closed && current !== session) || data.event !== RESPONSE_EVENT) return;
  // publisherBundleName on the subscription is enforced by the event service.
  if (data.bundleName !== undefined && data.bundleName !== '' && data.bundleName !== JAVA_BUNDLE) return;
  if (typeof data.data !== 'string' || data.data.length > 16384) {
    trace('drop_frame', `size=${size}`);
    return;
  }
  let event: BackgroundEvent;
  try {
    event = JSON.parse(data.data) as BackgroundEvent;
  } catch (error) {
    trace('drop_frame', 'json');
    return;
  }
  if (event === null || event.protocol !== PROTOCOL || event.sessionId !== session.id ||
      event.sessionToken !== session.token || typeof event.text !== 'string' || event.text.length > 4096) {
    trace('drop_frame', 'shape');
    return;
  }
  const seq = Number(event.seq);
  if (!Number.isInteger(seq) || seq <= session.lastSeq) {
    trace('drop_frame', `seq=${event.seq} last=${session.lastSeq}`);
    return;
  }
  if (['accepted', 'progress', 'stdout', 'stderr', 'done', 'error'].indexOf(event.event) < 0) {
    trace('drop_frame', `kind=${event.event}`);
    return;
  }
  if (seq !== session.lastSeq + 1) session.incomplete = true;
  const message = new Map<string, string>();
  message.set('protocol', PROTOCOL);
  message.set('sessionId', session.id);
  message.set('sessionToken', session.token);
  message.set('seq', `${seq}`);
  message.set('event', event.event);
  message.set('text', event.text);
  if (event.exitCode !== undefined) message.set('exitCode', `${event.exitCode}`);
  if (event.code !== undefined) message.set('code', event.code);
  session.lastSeq = seq;
  const terminal = event.event === 'done' || event.event === 'error';
  if (!session.sawFrame) {
    // First frame proves delivery across the common-event channel, which is
    // the one part of this route no host test can establish.
    session.sawFrame = true;
    trace('first_frame', `kind=${event.event}`);
  }
  if (terminal) {
    // Interpolation stays on plain string and number values: ArkTS rejects a
    // union inside a template placeholder.
    const exitText = event.exitCode === undefined ? '-' : `${event.exitCode}`;
    const codeText = event.code === undefined ? '-' : event.code;
    trace('terminal', `kind=${event.event} exit=${exitText} code=${codeText}`);
  }
  if (session.closed) {
    if (terminal) {
      session.terminal = true;
      unsubscribe(session);
    } else if (session.cancelled) {
      sendCancel(session).catch(() => {});
    }
    return;
  }
  if (terminal) {
    session.terminal = true;
    const validExit = (typeof event.exitCode === 'number' ||
      (typeof event.exitCode === 'string' && /^-?\d+$/.test(event.exitCode))) &&
      Number.isInteger(Number(event.exitCode));
    const succeeded = !session.incomplete && validExit && event.event === 'done' && Number(event.exitCode) === 0;
    const summary = session.incomplete || !validExit ? '结果不完整，请查看终端' :
      succeeded ? '运行完成' : event.code === 'cancelled' ? '运行已停止' :
      event.code === 'timeout' ? '运行超时' : '运行失败，请查看终端';
    notification(session, summary, true);
    unsubscribe(session);
  } else if (event.event === 'accepted' || event.event === 'progress') {
    // Notifications display stages, never source code or program output.
    notification(session, event.text.substring(0, 120) || '正在运行', false);
  }
  const receiver = sink;
  if (receiver !== null) {
    try {
      receiver.success(message);
    } catch (error) {
      // The foreground bridge guards the same call. A dead engine must not turn
      // one frame into an unhandled throw inside the event callback.
      trace('sink_failed');
    }
  } else {
    session.pending.push(message);
    if (session.pending.length > 64) {
      // Losing output cannot be reported as a successful run.
      disposeSession(session);
    }
  }
}

/**
 * Starts the receiver as invisibly as this platform allows.
 *
 * Documented controls, in order of preference: a windowless app service
 * extension, then `StartOptions.startupVisibility` (hide the started ability
 * after process startup), then a visible start without the launch splash.
 *
 * The survey of 2026-11-10 (`research/harmony-cross-app-survey-20261110.md`)
 * records that both the windowless extension and `startupVisibility` are limited
 * to 2in1 and tablet devices. This device reports
 * `const.product.devicetype=phone`, so every hidden route is expected to be
 * refused. The expectation is not assumed: each variant records its own answer,
 * so one device run settles all of them, and the answer is cached afterwards so
 * later runs stop spending a call on a route this platform already refused.
 *
 * A refused variant validates its options before launching anything, so no
 * request is started twice. An accepted hidden variant would still not be
 * enough on its own: the receiver opens its gate from `onDidForeground`, which a
 * hidden start never reaches, so the receiver side has to handle that case too.
 */
function launchVariant(context: common.UIAbilityContext, want: Want, variant: string): Promise<void> {
  switch (variant) {
    case 'service':
      return context.startAppServiceExtensionAbility({
        bundleName: want.bundleName,
        abilityName: BACKGROUND_SERVICE,
        action: SERVICE_ACTION,
        uri: want.uri,
        type: want.type,
        flags: want.flags,
        parameters: want.parameters,
      });
    case 'visibility': {
      // The field by itself. The SDK requires processMode next to it, so a
      // refusal here is about the field, not about its prerequisite.
      const options: StartOptions = {startupVisibility: contextConstant.StartupVisibility.STARTUP_HIDE};
      return context.startAbility(want, options);
    }
    case 'statusbar': {
      const options: StartOptions = {
        processMode: contextConstant.ProcessMode.ATTACH_TO_STATUS_BAR_ITEM,
        startupVisibility: contextConstant.StartupVisibility.STARTUP_HIDE,
      };
      return context.startAbility(want, options);
    }
    case 'attach': {
      const options: StartOptions = {
        hideStartWindow: true,
        processMode: contextConstant.ProcessMode.NEW_PROCESS_ATTACH_TO_PARENT,
        startupVisibility: contextConstant.StartupVisibility.STARTUP_HIDE,
      };
      return context.startAbility(want, options);
    }
    default: {
      // Last resort: the receiver's window is visible to the user.
      const options: StartOptions = {hideStartWindow: true};
      return context.startAbility(want, options);
    }
  }
}

/** Probe order: hidden routes first, the visible start last. */
const LAUNCH_VARIANTS: string[] = ['service', 'visibility', 'statusbar', 'attach', 'visible'];
/** First variant this process found acceptable. */
let acceptedVariant: string | null = null;

async function startReceiver(context: common.UIAbilityContext, want: Want): Promise<string> {
  if (acceptedVariant !== null) {
    await launchVariant(context, want, acceptedVariant);
    trace('launch_cached', `variant=${acceptedVariant}`);
    return acceptedVariant;
  }
  const refusals: string[] = [];
  for (const variant of LAUNCH_VARIANTS) {
    try {
      await launchVariant(context, want, variant);
      acceptedVariant = variant;
      trace('launch_accepted', `variant=${variant}`);
      return variant;
    } catch (error) {
      const code = `${(error as BusinessError).code}`;
      trace('launch_refused', `variant=${variant} code=${code}`);
      refusals.push(`${variant}:${code}`);
    }
  }
  // Even the visible start failed, so this is a real start failure rather than
  // a preference. The caller reports it as one.
  throw new Error(`后台启动全部被拒绝（${refusals.join(', ')}）`);
}

async function start(context: common.UIAbilityContext, raw: Map<string, string>,
    bundle: string): Promise<Map<string, Object>> {
  validateRequest(raw);
  if (bundle !== JAVA_BUNDLE || raw.get('language') !== 'java') {
    throw new InteropRefusal('unsupported_language', '后台运行暂时只支持 Java');
  }
  if (current !== null) {
    if (!current.terminal) throw new InteropRefusal('busy', '已有后台任务正在运行');
    // A finished session that never received its `dispose` must not lock the
    // route until the app restarts. Its terminal frame is already delivered or
    // lost with the run's own deadline, so retiring it invents nothing.
    trace('retire', 'finished session replaced');
    unsubscribe(current);
    current.pending = [];
    current = null;
  }
  const zipPath = payloadZipPath(raw);
  const session = new BackgroundSession(raw.get('sessionId') as string, raw.get('sessionToken') as string);
  current = session;
  try {
    if (!await notificationManager.isNotificationEnabled()) {
      await notificationManager.requestEnableNotification(context);
    }
    assertActive(session);
    if (!await notificationManager.isNotificationEnabled()) {
      throw new InteropRefusal('notification_disabled', '请允许通知后重试后台运行');
    }
    session.noticeEnabled = true;
    assertActive(session);
    const subscriber = await commonEventManager.createSubscriber({
      events: [RESPONSE_EVENT], publisherBundleName: JAVA_BUNDLE,
    });
    session.subscriber = subscriber;
    assertActive(session);
    await commonEventManager.subscribeToEvent(subscriber, (data: commonEventManager.CommonEventData) => {
      receive(session, data);
    });
    if (session.closed || session.cancelled || current !== session) {
      // Subscription completion can race disposal. The captured handle must
      // be released again even if disposeSession already cleared the field.
      commonEventManager.unsubscribe(subscriber, () => {});
    }
    assertActive(session);
    if (!await notification(session, '正在连接 Java 工具链', false)) {
      throw new InteropRefusal('notification_failed', '无法显示运行通知，请检查通知设置');
    }
    assertActive(session);
    const uri = fileUri.getUriFromPath(zipPath);
    const parameters: Record<string, Object> = {};
    parameters['protocol'] = PROTOCOL;
    parameters['sessionId'] = session.id;
    parameters['sessionToken'] = session.token;
    parameters['language'] = 'java';
    parameters['entry'] = raw.get('entry') as string;
    parameters['action'] = raw.get('action') as string;
    parameters['stdin'] = raw.get('stdin') as string;
    parameters['timeoutMs'] = Number(raw.get('timeoutMs'));
    parameters['callerBundle'] = STUDIO_BUNDLE;
    parameters['bridgeAction'] = RESPONSE_EVENT;
    parameters['payloadUri'] = uri;
    const want: Want = {
      bundleName: JAVA_BUNDLE,
      abilityName: BACKGROUND_ABILITY,
      action: 'action.system.qfli.interop.background.request',
      uri: uri,
      type: 'application/zip',
      flags: wantConstant.Flags.FLAG_AUTH_READ_URI_PERMISSION,
      parameters: parameters,
    };
    // Asked for while Studio still owns the foreground, before the launch can
    // take it away. See reserveSenderAllowance for the device evidence.
    reserveSenderAllowance(session);
    // Mark before awaiting: cancellation during the platform call must be sent.
    session.launched = true;
    const mode = await startReceiver(context, want);
    trace('launched', `mode=${mode}`);
    if (session.cancelled || session.closed) {
      await sendCancel(session);
    }
    const answer = new Map<string, Object>();
    answer.set('notificationEnabled', true);
    return answer;
  } catch (error) {
    const failure = error as BusinessError;
    trace('start_failed', `code=${failure.code}`);
    disposeSession(session);
    if (failure.code === 16000001 || failure.code === 16000003) {
      throw new InteropRefusal('app_missing', '请安装支持后台运行的 QFLIJVMX');
    }
    throw error as Error;
  }
}

function matches(call: MethodCall): BackgroundSession | null {
  const session = current;
  if (session !== null && session.id === call.argument('sessionId') &&
      session.token === call.argument('sessionToken')) return session;
  return null;
}

export function configureBackgroundInteropChannels(engine: FlutterEngine,
    context: common.UIAbilityContext): void {
  const messenger = engine.dartExecutor.getBinaryMessenger();
  const methods = new MethodChannel(messenger, 'qfli_interop/background');
  methods.setMethodCallHandler({
    onMethodCall(call: MethodCall, result: MethodResult): void {
      try {
        if (call.method === 'start') {
          const supplied = call.argument('parameters') as Map<string, Object>;
          const raw = new Map<string, string>();
          supplied.forEach((value: Object, key: string) => raw.set(key, `${value}`));
          start(context, raw, call.argument('bundleName') as string).then((answer) => {
            result.success(answer);
          }).catch((error: Error) => {
            const refusal = error as InteropRefusal;
            result.error(`${refusal.code ?? 'transport_failure'}`, refusal.message, null);
          });
        } else if (call.method === 'cancel') {
          const session = matches(call);
          if (session === null) result.success(null);
          else sendCancel(session).then(() => result.success(null)).catch((error: Error) => {
            result.error('cancel_failed', error.message, null);
          });
        } else if (call.method === 'dispose') {
          const session = matches(call);
          if (session !== null) disposeSession(session);
          result.success(null);
        } else {
          result.notImplemented();
        }
      } catch (error) {
        result.error('bad_request', (error as Error).message, null);
      }
    },
  });
  const events = new EventChannel(messenger, 'qfli_interop/background/events');
  events.setStreamHandler({
    onListen(args: Object, eventSink: EventSink): void {
      sink = eventSink;
      const session = current;
      if (session !== null) {
        for (const event of session.pending) eventSink.success(event);
        session.pending = [];
      }
    },
    onCancel(args: Object): void {
      sink = null;
    },
  });
}
