/*
 * Studio side of qfli-interop/1.
 *
 * Dart cannot start another bundle; ArkTS can. This file owns four things and
 * nothing else:
 *
 *   1. `probe`  — answer whether a sibling app can be reached at all.
 *   2. `start`  — validate a request and hand it to a sibling app's
 *                 InteropAbility.
 *   3. `cancel` — record a stop request so the run can report it.
 *   4. events   — accept the events the sibling app starts on
 *                 InteropBridgeAbility and forward them to Dart.
 *
 * Every rule here mirrors `qfli_studio_core/lib/interop/interop_protocol.dart`.
 * A rule that exists on only one side is a hole, so change both together.
 */

import { common, Want } from '@kit.AbilityKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { fileIo as fs } from '@kit.CoreFileKit';
import {
  FlutterAbility,
  FlutterEngine,
  FlutterManager,
  MethodChannel,
  MethodCall,
  MethodResult,
  EventChannel,
  EventSink,
} from '@ohos/flutter_ohos';

/** Protocol version carried by every request and event. */
export const PROTOCOL = 'qfli-interop/1';

/** Studio's own bundle name, sent as `callerBundle`. */
export const STUDIO_BUNDLE = 'com.azurekiln.qflistudio';

/** Ability that receives response events from a sibling app. */
export const BRIDGE_ABILITY = 'InteropBridgeAbility';

/** Ability a sibling app exports for a request. */
const TARGET_ABILITY = 'InteropAbility';

const MAX_PAYLOAD_BYTES = 256 * 1024;
const MAX_FILES = 64;
const MAX_PATH_LENGTH = 240;
const MAX_STDIN_BYTES = 4 * 1024;
const MIN_TIMEOUT_MS = 1000;
const MAX_TIMEOUT_MS = 120000;

/** Bundle names Studio accepts events from. */
const ALLOWED_RECEIVERS: string[] = [
  'com.azurekiln.qfli.java',
  'com.azurekiln.qfli.cpp',
  'com.azurekiln.qfli.pyflow',
];

const CHANNEL_METHODS = 'qfli_interop/bridge';
const CHANNEL_EVENTS = 'qfli_interop/bridge/events';

/** Sessions Studio started. An event for any other session is dropped. */
const activeSessions: Set<string> = new Set<string>();

/** Sessions the user asked to stop. */
const cancelledSessions: Set<string> = new Set<string>();

/**
 * The live UIAbility and Flutter engine.
 *
 * InteropBridgeAbility is a second ability in the same process, so it can hand
 * events to the engine that EntryAbility configured. It must not create its own
 * engine: a second engine would not share Dart's channel state.
 */
let hostContext: common.UIAbilityContext | null = null;

/**
 * The context a probe starts an ability from.
 *
 * The probe runs before any run, so it needs the same live ability context the
 * channel handlers use; it is assigned when the channels are configured.
 */
let probeHostContext: common.UIAbilityContext | null = null;
let eventSink: EventSink | null = null;

/** One refusal, with a code the Dart side already understands. */
export class InteropRefusal extends Error {
  code: string;

  constructor(code: string, message: string) {
    super(message);
    this.code = code;
  }
}

function utf8Length(text: string): number {
  let bytes = 0;
  for (let index = 0; index < text.length; index++) {
    const unit = text.charCodeAt(index);
    if (unit < 0x80) {
      bytes += 1;
    } else if (unit < 0x800) {
      bytes += 2;
    } else if (unit >= 0xd800 && unit <= 0xdbff) {
      bytes += 4;
      index++;
    } else {
      bytes += 3;
    }
  }
  return bytes;
}

/** Same grammar as InteropPath.validate on the Dart side. */
function validatePath(path: string): void {
  if (path.length === 0 || path.length > MAX_PATH_LENGTH) {
    throw new InteropRefusal('bad_request', 'payload 路径长度不合法');
  }
  if (path.indexOf('\u0000') >= 0 || path.indexOf('\\') >= 0) {
    throw new InteropRefusal('bad_request', 'payload 路径包含非法字符');
  }
  if (path.charAt(0) === '/') {
    throw new InteropRefusal('bad_request', 'payload 路径必须是相对路径');
  }
  if (/^[A-Za-z]:/.test(path)) {
    throw new InteropRefusal('bad_request', 'payload 路径不能带盘符');
  }
  for (let index = 0; index < path.length; index++) {
    if (path.charCodeAt(index) < 0x20) {
      throw new InteropRefusal('bad_request', 'payload 路径包含控制字符');
    }
  }
  for (const segment of path.split('/')) {
    if (segment.length === 0) {
      throw new InteropRefusal('bad_request', 'payload 路径有空段');
    }
    if (segment === '.' || segment === '..') {
      throw new InteropRefusal('bad_request', 'payload 路径不能包含 . 或 .. 段');
    }
    if (segment.charAt(0) === '.') {
      throw new InteropRefusal('bad_request', 'payload 路径不能包含隐藏段');
    }
  }
}

class PayloadEntry {
  path: string = '';
  content: string = '';
}

function readString(raw: Map<string, string>, key: string): string {
  const value = raw.get(key);
  if (value === undefined) {
    throw new InteropRefusal('bad_request', `缺少参数 ${key}`);
  }
  return value;
}

/**
 * Validates the launch parameters Dart produced, in the order protocol, caller,
 * size, paths. A refused request must not have touched another app.
 */
function validateRequest(raw: Map<string, string>): PayloadEntry[] {
  if (readString(raw, 'protocol') !== PROTOCOL) {
    throw new InteropRefusal('unsupported_protocol', '不支持的协议版本');
  }
  const sessionId = readString(raw, 'sessionId');
  if (!/^[A-Za-z0-9_-]{8,64}$/.test(sessionId)) {
    throw new InteropRefusal('bad_request', '会话标识不合法');
  }
  if (readString(raw, 'callerBundle') !== STUDIO_BUNDLE) {
    throw new InteropRefusal('caller_not_allowed', '调用方包名不匹配');
  }
  if (readString(raw, 'bridgeAction').length === 0) {
    throw new InteropRefusal('bad_request', '缺少回调 action');
  }
  const timeout = Number(readString(raw, 'timeoutMs'));
  if (!Number.isFinite(timeout) || timeout < MIN_TIMEOUT_MS || timeout > MAX_TIMEOUT_MS) {
    throw new InteropRefusal('bad_request', 'timeoutMs 超出范围');
  }
  if (utf8Length(readString(raw, 'stdin')) > MAX_STDIN_BYTES) {
    throw new InteropRefusal('payload_too_large', 'stdin 超过 4 KiB');
  }
  const action = readString(raw, 'action');
  if (action !== 'compile' && action !== 'run' && action !== 'analyze') {
    throw new InteropRefusal('bad_request', `未知 action：${action}`);
  }
  let parsed: Object;
  try {
    parsed = JSON.parse(readString(raw, 'files')) as Object;
  } catch (error) {
    throw new InteropRefusal('bad_request', 'files 不是合法 JSON');
  }
  if (!Array.isArray(parsed)) {
    throw new InteropRefusal('bad_request', 'files 必须是数组');
  }
  const entries = parsed as PayloadEntry[];
  if (entries.length > MAX_FILES) {
    throw new InteropRefusal('payload_too_large', 'payload 超过 64 个文件');
  }
  let bytes = 0;
  for (const entry of entries) {
    if (entry === null || typeof entry.path !== 'string' || typeof entry.content !== 'string') {
      throw new InteropRefusal('bad_request', 'files 的条目缺少 path 或 content');
    }
    validatePath(entry.path);
    // Base64 is 4 characters per 3 bytes. Checking the encoded length first
    // means an over-long payload is refused before anything is decoded.
    bytes += Math.floor((entry.content.length * 3) / 4);
    if (bytes > MAX_PAYLOAD_BYTES) {
      throw new InteropRefusal('payload_too_large', 'payload 超过 256 KiB');
    }
  }
  const entry = readString(raw, 'entry');
  if (action !== 'analyze') {
    validatePath(entry);
    let present = false;
    for (const item of entries) {
      if (item.path === entry) {
        present = true;
        break;
      }
    }
    if (!present) {
      throw new InteropRefusal('bad_request', '入口文件不在 payload 中');
    }
  }
  return entries;
}

/** Whether an event may be forwarded to Dart. */
export function isAllowedReceiver(bundleName: string): boolean {
  return ALLOWED_RECEIVERS.indexOf(bundleName) >= 0;
}

/** Records a started session so stray events from earlier runs are dropped. */
export function registerSession(sessionId: string): void {
  activeSessions.add(sessionId);
  cancelledSessions.delete(sessionId);
  if (activeSessions.size > 8) {
    const iterator = activeSessions.values();
    const first = iterator.next();
    if (!first.done) {
      activeSessions.delete(first.value);
    }
  }
}

export function markCancelled(sessionId: string): void {
  if (activeSessions.has(sessionId)) {
    cancelledSessions.add(sessionId);
  }
}

export function closeSession(sessionId: string): void {
  activeSessions.delete(sessionId);
  cancelledSessions.delete(sessionId);
}

/** Forwards one validated event to the Flutter EventChannel. */
export function publishEvent(event: Map<string, string>): void {
  if (eventSink === null) {
    return;
  }
  const payload = new Map<string, string>();
  event.forEach((value: string, key: string) => {
    payload.set(key, value);
  });
  eventSink.success(payload);
}

/**
 * Writes the payload under the studio cache and returns a manifest path.
 *
 * The manifest exists because a Want cannot carry the files reliably: the
 * documented parameter budget is far below our 256 KiB cap, and a truncated
 * parameter would arrive as a corrupt project. The file path is start-only,
 * short and validated; the receiver reads it back only if the producing app is
 * still the one we started.
 */
function writePayload(context: common.UIAbilityContext, sessionId: string,
    entries: PayloadEntry[]): string {
  const directory = `${context.cacheDir}/qfli_interop/out/${sessionId}`;
  fs.mkdirSync(directory, true);
  const manifest: string[] = [];
  for (const entry of entries) {
    const target = `${directory}/${entry.path}`;
    const parent = target.substring(0, target.lastIndexOf('/'));
    fs.mkdirSync(parent, true);
    const file = fs.openSync(target, fs.OpenMode.CREATE | fs.OpenMode.WRITE_ONLY | fs.OpenMode.TRUNC);
    try {
      fs.writeSync(file.fd, entry.content);
    } finally {
      fs.closeSync(file);
    }
  }
  // The receiver reads `files` from here; the Want only carries the directory.
  const manifestPath = `${directory}/manifest.json`;
  const file = fs.openSync(manifestPath, fs.OpenMode.CREATE | fs.OpenMode.WRITE_ONLY | fs.OpenMode.TRUNC);
  try {
    fs.writeSync(file.fd, JSON.stringify(entries.map((entry: PayloadEntry) => entry.path)));
  } finally {
    fs.closeSync(file);
  }
  return directory;
}

async function start(context: common.UIAbilityContext, raw: Map<string, string>): Promise<void> {
  const entries = validateRequest(raw);
  const sessionId = raw.get('sessionId') as string;
  const bundleName = raw.get('targetBundle') as string;
  if (!isAllowedReceiver(bundleName)) {
    throw new InteropRefusal('caller_not_allowed', '目标不是认可的配套应用');
  }
  const directory = writePayload(context, sessionId, entries);
  registerSession(sessionId);

  const payload: Record<string, Object> = {};
  payload['protocol'] = PROTOCOL;
  payload['sessionId'] = sessionId;
  payload['language'] = raw.get('language') as string;
  payload['entry'] = raw.get('entry') as string;
  payload['action'] = raw.get('action') as string;
  payload['stdin'] = raw.get('stdin') as string;
  payload['timeoutMs'] = Number(raw.get('timeoutMs'));
  payload['callerBundle'] = STUDIO_BUNDLE;
  payload['bridgeAction'] = raw.get('bridgeAction') as string;
  payload['payloadDirectory'] = directory;
  const want: Want = {
    bundleName: bundleName,
    abilityName: TARGET_ABILITY,
    parameters: payload,
  };
  try {
    await context.startAbility(want);
  } catch (error) {
    closeSession(sessionId);
    const failure = error as BusinessError;
    // 16000001: the ability does not exist. 16000003: the bundle is not
    // installed. Both mean the sibling app has to be installed.
    if (failure.code === 16000001 || failure.code === 16000003) {
      throw new InteropRefusal('app_missing', `未检测到配套应用（${failure.code}）`);
    }
    throw new InteropRefusal('transport_failure', `${failure.code}: ${failure.message}`);
  }
}

/**
 * The handshake result the Dart side reads.
 *
 * A bundle query would be a cheaper answer, but `GET_BUNDLE_INFO` is a system
 * permission: on a real device the query fails with 8521226 and the probe could
 * only ever say "unknown". The one check a normal app can always make is
 * whether an ability start is refused because the app is missing, which is
 * what this probe reports.
 *
 *   - `installed: true`  — the platform accepted the start.
 *   - `installed: false` — the platform says the bundle or ability is absent.
 *   - no answer at all  — the start failed for another reason (a refusal, a
 *     permission, a busy system), so the caller must not claim either way.
 */
export interface ProbeAnswer {
  installed: boolean;
  available: boolean;
  protocol?: string;
  diagnostic?: string;
}

/** Start failures that mean "not installed". */
function isMissingApp(error: BusinessError): boolean {
  // 16000001: ability does not exist. 16000003: bundle does not exist.
  return error.code === 16000001 || error.code === 16000003;
}

/**
 * Answers whether a sibling app can run a cross-app request.
 *
 * The check is a real ability start with a request that is safe to send:
 * `action: 'analyze'` runs no compiler and reads no payload directory. The
 * receiver validates every field first, so a probe can never start a build.
 *
 * The start is sent through a Want with no parameters the receiver would act
 * on beyond validation, and the ability the module exports has no `skills`
 * block, so this path cannot be reached by a URI or by an untrusted caller.
 */
export function probe(raw: Map<string, string>): Promise<Map<string, Object>> {
  const result = new Map<string, Object>();
  // The Dart side sends the bundle name as a channel argument, and
  // `onMethodCall` copies it into `targetBundle`. Reading `bundleName` here
  // made every probe answer "unknown app" on a device.
  const bundleName = raw.get('targetBundle');
  if (bundleName === undefined || !isAllowedReceiver(bundleName)) {
    result.set('installed', false);
    result.set('available', false);
    result.set('diagnostic', '未知的配套应用');
    return Promise.resolve(result);
  }
  return probeByStart(bundleName).then((answer: ProbeAnswer) => {
    result.set('installed', answer.installed);
    result.set('available', answer.available);
    if (answer.protocol !== undefined) {
      result.set('protocol', answer.protocol);
    }
    if (answer.diagnostic !== undefined) {
      result.set('diagnostic', answer.diagnostic);
    }
    result.set('languages', new Array<Object>());
    return result;
  });
}

/**
 * Starts the receiver with a harmless analyze request and reads the outcome.
 *
 * `startAbility` reports the platform's own verdict, so no bundle record and
 * no permission are needed. The request carries a random session id so the
 * receiver's reply, if any, is dropped by the Dart session filter.
 */
async function probeByStart(bundleName: string): Promise<ProbeAnswer> {
  const parameters: Record<string, Object> = {};
  parameters['protocol'] = PROTOCOL;
  parameters['sessionId'] = `probe${Date.now()}`;
  parameters['language'] = 'java';
  parameters['entry'] = '';
  parameters['action'] = 'analyze';
  parameters['stdin'] = '';
  parameters['timeoutMs'] = 5000;
  parameters['callerBundle'] = STUDIO_BUNDLE;
  parameters['bridgeAction'] = 'action.system.qfli.interop.event';
  parameters['payloadDirectory'] = '';
  const want: Want = {
    bundleName: bundleName,
    abilityName: TARGET_ABILITY,
    parameters: parameters,
  };
  const context = probeHostContext;
  if (context === null) {
    return {
      installed: true,
      available: false,
      diagnostic: '跨应用通道尚未就绪',
    };
  }
  try {
    await context.startAbility(want);
  } catch (error) {
    const failure = error as BusinessError;
    if (isMissingApp(failure)) {
      return {
        installed: false,
        available: false,
        diagnostic: `未安装 ${bundleName}`,
      };
    }
    // Something other than "not installed" refused the start. Reporting
    // "installed" here would be a guess, so the answer stays unknown.
    console.error(`QFLI_INTEROP_PROBE_REFUSED ${failure.code}`);
    return {
      installed: true,
      available: false,
      diagnostic: `无法确认 ${bundleName}（${failure.code}）`,
    };
  }
  return {
    installed: true,
    available: true,
    protocol: PROTOCOL,
  };
}


function toStringMap(raw: Object): Map<string, string> {
  const source = raw as Map<string, Object>;
  const out = new Map<string, string>();
  source.forEach((value: Object, key: string) => {
    out.set(key, `${value}`);
  });
  return out;
}

/** Registers the method and event channels and remembers the host ability. */
export function configureInteropChannels(engine: FlutterEngine,
    context: common.UIAbilityContext): void {
  hostContext = context;
  probeHostContext = context;
  const messenger = engine.dartExecutor.getBinaryMessenger();
  const methods = new MethodChannel(messenger, CHANNEL_METHODS);
  methods.setMethodCallHandler({
    onMethodCall(call: MethodCall, result: MethodResult): void {
      const raw = toStringMap(call.argument('parameters') ?? new Map<string, Object>());
      const target = call.argument('bundleName') as string;
      if (typeof target === 'string') {
        raw.set('targetBundle', target);
      }
      // The Dart client sends `abilityName`, `language` and `protocol` as
      // channel arguments, not inside `parameters`, so they are copied here.
      for (const key of ['abilityName', 'language', 'protocol']) {
        const value = `${call.argument(key) ?? ''}`;
        if (value.length > 0) {
          raw.set(key, value);
        }
      }
      try {
        if (call.method === 'probe') {
          probe(raw).then((answer: Map<string, Object>) => {
            result.success(answer);
          }).catch((error: Error) => {
            result.error('probe_failed', error.message, null);
          });
          return;
        }
        if (call.method === 'start') {
          if (hostContext === null) {
            result.error('transport_failure', '跨应用通道尚未就绪', null);
            return;
          }
          start(hostContext, raw).then(() => {
            result.success(null);
          }).catch((error: Error) => {
            const refusal = error as InteropRefusal;
            result.error(refusal.code ?? 'transport_failure', refusal.message, null);
          });
          return;
        }
        if (call.method === 'cancel') {
          const sessionId = call.argument('sessionId') as string;
          if (typeof sessionId === 'string') {
            markCancelled(sessionId);
          }
          result.success(null);
          return;
        }
        result.notImplemented();
      } catch (error) {
        const refusal = error as InteropRefusal;
        result.error(refusal.code ?? 'bad_request', refusal.message, null);
      }
    },
  });

  const events = new EventChannel(messenger, CHANNEL_EVENTS);
  events.setStreamHandler({
    onListen(args: Object, sink: EventSink): void {
      eventSink = sink;
    },
    onCancel(args: Object): void {
      eventSink = null;
    },
  });
}

/**
 * Called by InteropBridgeAbility when a sibling app starts it with an event.
 *
 * Returns false when the event is not from an allowed app or not for a session
 * Studio started, so the ability can finish without changing any state.
 */
export function acceptBridgeEvent(callerBundle: string,
    parameters: Map<string, Object>): boolean {
  if (!isAllowedReceiver(callerBundle)) {
    return false;
  }
  const sessionId = `${parameters.get('sessionId') ?? ''}`;
  if (!activeSessions.has(sessionId)) {
    return false;
  }
  const out = new Map<string, string>();
  parameters.forEach((value: Object, key: string) => {
    out.set(key, `${value}`);
  });
  const event = out.get('event');
  if (event === 'done' || event === 'error') {
    closeSession(sessionId);
  }
  publishEvent(out);
  return true;
}

export function payloadErrorMessage(code: string): string {
  const labels: Map<string, string> = new Map<string, string>([
    ['bad_request', '跨应用请求不合法'],
    ['unsupported_protocol', '配套应用版本过旧'],
    ['caller_not_allowed', '调用方不被认可'],
    ['payload_too_large', '项目超过跨应用上限'],
  ]);
  return labels.get(code) ?? '跨应用请求失败';
}

/** The engine EntryAbility created, or null before Dart is running. */
export function hostEngine(context: common.Context): FlutterEngine | null {
  const ability = FlutterManager.getInstance().getUIAbility(context);
  if (ability === undefined) {
    return null;
  }
  return (ability as FlutterAbility).getFlutterEngine();
}
