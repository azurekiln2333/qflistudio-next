const fs = require('node:fs');
const vm = require('node:vm');
const path = require('node:path');
const assert = require('node:assert/strict');
// Executes the real bridge against deterministic platform doubles.
// Set TYPESCRIPT_PATH to typescript.js if TypeScript is not locally installed.
function loadTypeScript() {
  const homes = [process.env.DEVECO_STUDIO_HOME, process.env.DEVECO_HOME,
    process.env.DEVECO_SDK_HOME && path.dirname(process.env.DEVECO_SDK_HOME),
    'D:/ProgramFiles/Huawei/DevEco Studio', 'C:/Program Files/Huawei/DevEco Studio'].filter(Boolean);
  const candidates = [process.env.TYPESCRIPT_PATH, 'typescript', ...homes.map(home =>
    path.join(home, 'tools/hvigor/hvigor-ohos-plugin/node_modules/typescript/lib/typescript.js'))].filter(Boolean);
  for (const candidate of candidates) {
    try { return require(candidate); } catch (error) {
      if (error.code !== 'MODULE_NOT_FOUND') throw error;
    }
  }
  throw new Error('TypeScript not found. Set TYPESCRIPT_PATH to typescript.js or set DEVECO_STUDIO_HOME.');
}
const ts = loadTypeScript();
const sourcePath = path.join(__dirname, '../ohos/entry/src/main/ets/interop/StudioBackgroundInterop.ets');
const source = fs.readFileSync(sourcePath, 'utf8') + '\nglobalThis.__bridgeTest = { start, receive, disposeBackgroundInterop, sendCancel, getCurrent: () => current, setSink: value => { sink = value; } };';
const code = ts.transpileModule(source, {compilerOptions: {module: ts.ModuleKind.CommonJS, target: ts.ScriptTarget.ES2020}}).outputText;
const defer = () => { let resolve, reject; const promise = new Promise((a, b) => { resolve = a; reject = b; }); return {promise, resolve, reject}; };
const flush = async () => { for (let i = 0; i < 40; i++) await Promise.resolve(); };
function fixture(options = {}) {
  let nextTimer = 1;
  const intervals = new Map();
  const timeouts = new Map();
  const active = new Set();
  const callbacks = new Map();
  const notices = [];
  const publishes = [];
  const creation = defer();
  const subscription = defer();
  const platformStart = defer();
  let starts = 0;
  let creations = 0;
  let receiverReady = false;
  let receivedCancel = 0;
  const launches = [];
  const services = [];
  const allowances = [];
  const released = [];
  const order = [];
  const events = {
    async createSubscriber(info) { if (options.delayCreate && ++creations === 1) await creation.promise; return {info}; },
    async subscribeToEvent(sub, cb) { if (options.delaySubscribe) await subscription.promise; active.add(sub); callbacks.set(sub, cb); },
    unsubscribe(sub, cb) { active.delete(sub); callbacks.delete(sub); cb?.(); },
    publish(name, payload, cb) { publishes.push({name, payload}); if (receiverReady && name.endsWith('.CANCEL')) receivedCancel++; cb(null); },
  };
  class InteropRefusal extends Error { constructor(code, message) { super(message); this.code = code; } }
  const dependencies = {
    '@kit.AbilityKit': {wantAgent: {getWantAgent: async () => ({}), OperationType: {START_ABILITY: 1}, WantAgentFlags: {UPDATE_PRESENT_FLAG: 1}}, wantConstant: {Flags: {FLAG_AUTH_READ_URI_PERMISSION: 1}}, contextConstant: {ProcessMode: {NEW_PROCESS_ATTACH_TO_PARENT: 1}, StartupVisibility: {STARTUP_HIDE: 0, STARTUP_SHOW: 1}}},
    '@kit.BasicServicesKit': {commonEventManager: events},
    '@kit.BackgroundTasksKit': {backgroundTaskManager: {
      requestSuspendDelay(reason, expired) { allowances.push(reason); order.push('allowance'); return {requestId: 900 + allowances.length, actualDelayTime: 180000}; },
      cancelSuspendDelay(id) { released.push(id); },
    }},
    '@kit.CoreFileKit': {fileUri: {getUriFromPath: p => 'file://' + p}},
    '@kit.NotificationKit': {notificationManager: {isNotificationEnabled: async () => true, requestEnableNotification: async () => {}, publish: async notice => { if (options.failNotice) throw Object.assign(new Error('disabled'), {code: 1}); notices.push(notice); }}},
    '@ohos.notification': {default: {SlotType: {SERVICE_INFORMATION: 1}, ContentType: {NOTIFICATION_CONTENT_BASIC_TEXT: 1}}},
    '@ohos/flutter_ohos': {},
    './StudioInterop': {PROTOCOL: 'qfli-interop/1', STUDIO_BUNDLE: 'com.azurekiln.qflistudio', InteropRefusal, validateRequest() {}, payloadZipPath: raw => raw.get('zipPath')},
  };
  const sandbox = {exports: {}, require: name => { assert.ok(name in dependencies, name); return dependencies[name]; }, console, Map, Promise,
    setInterval: fn => { const id = nextTimer++; intervals.set(id, fn); return id; }, clearInterval: id => intervals.delete(id),
    setTimeout: fn => { const id = nextTimer++; timeouts.set(id, fn); return id; }, clearTimeout: id => timeouts.delete(id)};
  vm.runInNewContext(code, sandbox, {filename: sourcePath});
  const api = sandbox.__bridgeTest;
  // Default to the phone model measured on the device: a windowless extension
  // and every hidden start are refused, so the visible start is what runs.
  const context = {async startAppServiceExtensionAbility(want) {
    // A windowless component is preferred: it never takes the foreground, so
    // Studio is never frozen and keeps its result channel.
    if (options.refuseService !== false) throw Object.assign(new Error('refused'), {code: 801});
    services.push(want); order.push('service');
  }, async startAbility(want, startOptions) {
    // A platform that refuses a hidden variant rejects before launching, so
    // nothing is started and the next variant is safe.
    // Only the hidden variants are refused on this device; the visible start is
    // the one route that works.
    if (startOptions?.startupVisibility !== undefined && options.refuseHidden !== false) {
      throw Object.assign(new Error('refused'), {code: 801});
    }
    launches.push(startOptions ?? null);
    order.push(startOptions?.startupVisibility !== undefined ? 'hidden' : 'launch');
    starts++;
    await platformStart.promise;
  }};
  function start(id = 'session0001') { return api.start(context, new Map(Object.entries({sessionId: id, sessionToken: '1234567890abcdef12345678', language: 'java', entry: 'Main.java', action: 'run', stdin: '', timeoutMs: '60000', zipPath: '/cache/a.zip'})), 'com.azurekiln.qfli.java'); }
  return {api, start, creation, subscription, platformStart, active, notices, publishes, intervals, timeouts, launches, services, allowances, released, order,
    get starts() { return starts; }, get receivedCancel() { return receivedCancel; }, ready() { receiverReady = true; },
    async tick() { for (const cb of [...intervals.values()]) cb(); await flush(); }};
}
async function main() {
  const outcomes = [];
  {
    const f = fixture({delayCreate: true}); const pending = f.start().catch(e => e); await flush();
    f.api.disposeBackgroundInterop(); f.creation.resolve(); await pending; await flush();
    assert.equal(f.active.size, 0); assert.equal(f.starts, 0);
    outcomes.push('PASS: dispose during subscriber creation releases the late object and never launches');
  }
  {
    const f = fixture({delaySubscribe: true}); const pending = f.start().catch(e => e); await flush();
    f.api.disposeBackgroundInterop(); f.subscription.resolve(); await pending; await flush();
    assert.equal(f.active.size, 0, 'late subscribe must be unsubscribed after disposal');
    outcomes.push('PASS: dispose during subscribe leaves no active subscription');
  }
  {
    const f = fixture({delayCreate: true});
    const previous = f.start('previous01').catch(e => e); await flush();
    f.api.disposeBackgroundInterop(); await flush();
    const replacement = f.start('replacement01'); await flush();
    f.platformStart.resolve(); await replacement; await flush();
    const expected = f.notices.at(-1).content.normal.text;
    f.creation.resolve(); await previous; await flush();
    assert.equal(f.notices.at(-1).content.normal.text, expected,
      'a late disposed start must not overwrite the replacement session notification');
    f.api.disposeBackgroundInterop();
    outcomes.push('PASS: disposed startup cannot overwrite replacement notification');
  }
  {
    const f = fixture(); const pending = f.start().catch(e => e); await flush(); assert.equal(f.starts, 1);
    await f.api.sendCancel(f.api.getCurrent());
    for (let i = 0; i < 12; i++) await f.tick();
    f.api.disposeBackgroundInterop();
    f.platformStart.resolve(); await pending; await flush();
    f.ready(); for (let i = 0; i < 12; i++) await f.tick();
    assert.ok(f.receivedCancel > 0, 'late receiver must receive a cancellation');
    assert.equal(f.intervals.size, 0, 'cancellation retries must be bounded');
    outcomes.push('PASS: late receiver gets cancellation and retries stop');
  }
  {
    const f = fixture(); const pending = f.start(); await flush(); f.platformStart.resolve(); await pending;
    const session = f.api.getCurrent();
    f.api.disposeBackgroundInterop(); f.ready();
    const previousCancels = f.receivedCancel;
    const visibleEvents = [];
    // A new Flutter listener must not receive the disposed session's events.
    f.api.setSink({success: value => visibleEvents.push(value)});
    f.api.receive(session, {event: 'com.azurekiln.qfli.interop.background.EVENT', bundleName: 'com.azurekiln.qfli.java',
      data: JSON.stringify({protocol: 'qfli-interop/1', sessionId: session.id, sessionToken: session.token,
        seq: 1, event: 'accepted', text: 'accepted'})});
    await flush();
    assert.ok(f.receivedCancel > previousCancels, 'late accepted must trigger another cancellation');
    assert.equal(visibleEvents.length, 0, 'disposed events must not reach a new UI listener');
    f.api.receive(session, {event: 'com.azurekiln.qfli.interop.background.EVENT', bundleName: 'com.azurekiln.qfli.java',
      data: JSON.stringify({protocol: 'qfli-interop/1', sessionId: session.id, sessionToken: session.token,
        seq: 2, event: 'error', text: 'cancelled', exitCode: 130, code: 'cancelled'})});
    await flush();
    assert.equal(f.active.size, 0); assert.equal(f.intervals.size, 0); assert.equal(f.timeouts.size, 0);
    assert.equal(visibleEvents.length, 0);
    outcomes.push('PASS: late accepted retries cancellation without UI delivery; acknowledgement releases resources');
  }
  {
    const f = fixture({failNotice: true}); const result = await f.start().catch(e => e); await flush();
    assert.equal(result.code, 'notification_failed'); assert.equal(f.starts, 0); assert.equal(f.active.size, 0);
    outcomes.push('PASS: failed initial notification prevents launch and disposes subscription');
  }
  {
    const f = fixture(); const pending = f.start(); await flush(); f.platformStart.resolve(); await pending;
    const session = f.api.getCurrent();
    const frame = {protocol: 'qfli-interop/1', sessionId: session.id, sessionToken: session.token, seq: 1, event: 'done', text: 'done', exitCode: 0};
    f.api.receive(session, {event: 'com.azurekiln.qfli.interop.background.EVENT', bundleName: 'foreign.bundle', data: JSON.stringify(frame)});
    assert.equal(session.terminal, false);
    f.api.receive(session, {event: 'com.azurekiln.qfli.interop.background.EVENT', bundleName: 'com.azurekiln.qfli.java', data: JSON.stringify({...frame, sessionToken: 'wrong'})});
    assert.equal(session.terminal, false);
    f.api.receive(session, {event: 'com.azurekiln.qfli.interop.background.EVENT', bundleName: 'com.azurekiln.qfli.java', data: JSON.stringify(frame)});
    await flush(); assert.equal(session.terminal, true); assert.equal(f.active.size, 0);
    f.api.disposeBackgroundInterop();
    outcomes.push('PASS: foreign publisher/token ignored; matching terminal closes subscriber');
  }
  for (const malformed of [{seq: 2, exitCode: 0}, {seq: 1, exitCode: null}, {seq: 1, exitCode: ''}]) {
    const f = fixture(); const pending = f.start(); await flush(); f.platformStart.resolve(); await pending;
    const session = f.api.getCurrent();
    f.api.receive(session, {event: 'com.azurekiln.qfli.interop.background.EVENT', bundleName: 'com.azurekiln.qfli.java',
      data: JSON.stringify({protocol: 'qfli-interop/1', sessionId: session.id, sessionToken: session.token,
        event: 'done', text: 'done', ...malformed})});
    await flush();
    assert.equal(f.notices.at(-1).content.normal.text, '结果不完整，请查看终端',
      'missing output or invalid exit must not be advertised as success');
    f.api.disposeBackgroundInterop();
  }
  outcomes.push('PASS: sequence gap and malformed exit cannot publish a success notification');
  {
    // A real run: program output reaches Dart in order, and the terminal frame
    // publishes a completed notification instead of leaving the ongoing one.
    const f = fixture(); const pending = f.start(); await flush(); f.platformStart.resolve(); await pending;
    const session = f.api.getCurrent();
    const visible = [];
    f.api.setSink({success: value => visible.push(value)});
    const frame = extra => ({event: 'com.azurekiln.qfli.interop.background.EVENT',
      bundleName: 'com.azurekiln.qfli.java',
      data: JSON.stringify({protocol: 'qfli-interop/1', sessionId: session.id, sessionToken: session.token, ...extra})});
    f.api.receive(session, frame({seq: '1', event: 'accepted', text: '已接收后台运行请求'}));
    f.api.receive(session, frame({seq: '2', event: 'stdout', text: 'hello from Java'}));
    f.api.receive(session, frame({seq: '3', event: 'stderr', text: 'warning: none'}));
    f.api.receive(session, frame({seq: '4', event: 'done', text: '运行完成', exitCode: 0}));
    await flush();
    assert.deepEqual(visible.map(value => `${value.get('seq')}:${value.get('event')}`),
      ['1:accepted', '2:stdout', '3:stderr', '4:done'], 'every streamed frame must reach Dart in order');
    assert.equal(visible[1].get('text'), 'hello from Java');
    assert.equal(visible[3].get('exitCode'), '0');
    const final = f.notices.at(-1);
    assert.equal(final.content.normal.text, '运行完成', 'a zero exit must be advertised as a completed run');
    assert.equal(final.isOngoing, false, 'the ongoing notification must be replaced by a terminal one');
    f.api.disposeBackgroundInterop();
    outcomes.push('PASS: streamed stdout/stderr reach Dart in order and done publishes a completed notification');
  }
  {
    // Dart gives up (its own deadline, a page disposal) without a receiver
    // frame. The ongoing notification must not survive the session.
    const f = fixture(); const pending = f.start(); await flush(); f.platformStart.resolve(); await pending;
    f.api.disposeBackgroundInterop(); await flush();
    const final = f.notices.at(-1);
    assert.equal(final.isOngoing, false, 'a disposed session must close its ongoing notification');
    // The bounded acknowledgement window keeps the subscription alive on
    // purpose so a late terminal frame can still stop the receiver.
    assert.equal(f.intervals.size, 1, 'the stop retries must still be bounded');
    for (let i = 0; i < 12; i++) await f.tick();
    assert.equal(f.intervals.size, 0, 'the stop retries must expire');
    outcomes.push('PASS: disposing an unfinished session closes its ongoing notification');
  }
  {
    // A terminal frame does not retire the session on its own: Dart sends
    // `dispose` next. If that control is lost, the route must not stay busy.
    const f = fixture(); const pending = f.start(); await flush(); f.platformStart.resolve(); await pending;
    const session = f.api.getCurrent();
    f.api.receive(session, {event: 'com.azurekiln.qfli.interop.background.EVENT',
      bundleName: 'com.azurekiln.qfli.java',
      data: JSON.stringify({protocol: 'qfli-interop/1', sessionId: session.id, sessionToken: session.token,
        seq: 1, event: 'done', text: '运行完成', exitCode: 0})});
    await flush();
    const second = await f.start('secondrun01');
    assert.ok(second, 'a finished session must not block the next run');
    assert.equal(f.starts, 2);
    f.api.disposeBackgroundInterop();
    outcomes.push('PASS: a finished session without dispose does not block the next start');
  }
  {
    // A platform that does support the field (2in1 / tablet per the survey) must
    // take it before any visible start. The single-field variant comes first, so
    // the answer distinguishes "the field is refused" from "its prerequisite is".
    const f = fixture({refuseHidden: false}); const pending = f.start(); await flush();
    f.platformStart.resolve(); await pending;
    assert.equal(f.starts, 1, 'a run launches exactly one ability');
    assert.equal(f.launches.length, 1, 'an accepted hidden variant needs no visible start');
    assert.equal(f.launches[0].startupVisibility, 0, 'startupVisibility must ask for a hidden start');
    assert.equal(f.launches[0].hideStartWindow, undefined, 'the single-field variant carries only the field');
    f.api.disposeBackgroundInterop();
    outcomes.push('PASS: a platform that accepts startupVisibility never falls back to a visible start');
  }
  {
    // This device is a phone, so every hidden route is refused. Exactly one
    // visible request must still be sent, and no variant may launch twice.
    const f = fixture(); const pending = f.start(); await flush(); f.platformStart.resolve(); await pending;
    assert.equal(f.starts, 1, 'refused hidden variants must not launch anything');
    assert.equal(f.launches.length, 1, 'only the visible variant is accepted');
    assert.equal(f.launches[0].startupVisibility, undefined);
    assert.equal(f.launches[0].hideStartWindow, true, 'the fallback still skips the splash');
    assert.equal(f.services.length, 0, 'a refused service launch is not recorded as accepted');
    f.api.disposeBackgroundInterop();
    outcomes.push('PASS: every refused hidden route collapses into one splash-free visible start');
  }
  {
    // Probing must happen once per process. Re-probing would add a launch call to
    // every run and would only repeat an answer the platform already gave.
    const f = fixture();
    const first = f.start('session0a'); await flush(); f.platformStart.resolve(); await first;
    f.api.disposeBackgroundInterop();
    const before = f.starts;
    const second = f.start('session0b'); await flush(); f.platformStart.resolve(); await second;
    assert.equal(f.starts, before + 1, 'the cached run still launches exactly once');
    assert.equal(f.launches.length, 2, 'one launch per run, no probe on the second run');
    f.api.disposeBackgroundInterop();
    outcomes.push('PASS: the accepted launch variant is probed once and then reused');
  }
  {
    // Device evidence: about three seconds after the launch moves the foreground
    // away, this process is frozen and every later common event is refused with
    // freezePid. A transient allowance keeps the process unfrozen, and it has to
    // be requested before the launch, or it is refused with 9900002.
    const f = fixture(); const pending = f.start(); await flush(); f.platformStart.resolve(); await pending;
    assert.deepEqual(f.order.slice(0, 2), ['allowance', 'launch'],
      'the allowance must be requested before the launch that takes the foreground');
    assert.equal(f.allowances.length, 1);
    const session = f.api.getCurrent();
    f.api.receive(session, {event: 'com.azurekiln.qfli.interop.background.EVENT', bundleName: 'com.azurekiln.qfli.java',
      data: JSON.stringify({protocol: 'qfli-interop/1', sessionId: session.id, sessionToken: session.token,
        seq: 1, event: 'done', text: '运行完成', exitCode: 0})});
    await flush();
    assert.deepEqual(f.released, [901], 'the terminal frame must release the allowance');
    outcomes.push('PASS: the sender holds a transient allowance from before the launch until the terminal frame');
  }
  {
    // Disposal keeps a bounded acknowledgement window, so the allowance is held
    // until that window closes and then released. It must not leak.
    const f = fixture(); const pending = f.start(); await flush(); f.platformStart.resolve(); await pending;
    f.api.disposeBackgroundInterop();
    assert.deepEqual(f.released, [], 'the allowance must survive the acknowledgement window');
    for (const cb of [...f.timeouts.values()]) cb();
    assert.deepEqual(f.released, [901], 'the acknowledgement window must release the allowance');
    outcomes.push('PASS: disposing a running session releases the sender allowance when its window closes');
  }
  {
    // A refused allowance must not abort the run: the windowless service keeps
    // Studio foreground, so no freeze happens and the frames still arrive.
    const denied = fixture({refuseService: false});
    const pending = denied.start(); await flush(); denied.platformStart.resolve(); await pending;
    assert.equal(denied.services.length, 1, 'the windowless service is tried first');
    assert.deepEqual(denied.order, ['allowance', 'service'], 'an accepted service launch needs no ability start');
    assert.equal(denied.starts, 0);
    outcomes.push('PASS: the windowless service is preferred and needs no second launch');
  }
  {
    // The new stage lines exist to make a device run readable. They must never
    // become a channel for program output, the session secret or a file path.
    const bridgeSource = fs.readFileSync(sourcePath, 'utf8');
    for (const line of bridgeSource.split('\n')) {
      if (!line.includes('trace(')) continue;
      assert.ok(!/trace\([^)]*event\.text/.test(line), `a trace line must not log output text: ${line}`);
      assert.ok(!/trace\([^)]*session\.token/.test(line), `a trace line must not log the token: ${line}`);
      assert.ok(!/trace\([^)]*zipPath/.test(line), `a trace line must not log the payload path: ${line}`);
    }
    assert.ok(bridgeSource.includes('sawFrame'), 'the first-frame line must stay in the receiver path');
    outcomes.push('PASS: diagnostic lines never carry output text, the token or the payload path');
  }
  for (const result of outcomes) console.log(result);
}
main().catch(error => { console.error(error); process.exitCode = 1; });
