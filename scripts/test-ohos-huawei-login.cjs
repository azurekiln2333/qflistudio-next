const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const assert = require('node:assert/strict');
const test = require('node:test');

// Execute the real ability with platform doubles. Override HUAWEI_ENTRY_SOURCE
// to prove the suite rejects an earlier EntryAbility.ets without the wiring.
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
  throw new Error('TypeScript not found. Set TYPESCRIPT_PATH or DEVECO_STUDIO_HOME.');
}

const ts = loadTypeScript();
const sourcePath = process.env.HUAWEI_ENTRY_SOURCE ||
  path.join(__dirname, '../ohos/entry/src/main/ets/entryability/EntryAbility.ets');
const code = ts.transpileModule(fs.readFileSync(sourcePath, 'utf8'), {
  fileName: 'EntryAbility.ts',
  compilerOptions: {module: ts.ModuleKind.CommonJS, target: ts.ScriptTarget.ES2020},
}).outputText;
const viewType = 'qflistudio/huawei_quick_login';
const channelName = 'qflistudio/huawei_account';

function fixture(options = {}) {
  const messenger = {};
  const channels = new Map();
  const factories = new Map();
  const requests = [];
  const controllerContexts = [];
  class FlutterAbility {
    constructor() { this.context = {name: 'ability-context'}; }
    configureFlutterEngine() {}
  }
  class MethodChannel {
    constructor(binaryMessenger, name) {
      assert.equal(binaryMessenger, messenger);
      channels.set(name, this);
    }
    setMethodCallHandler(handler) { this.handler = handler; }
  }
  class HuaweiQuickLoginViewFactory {
    constructor(binaryMessenger) { this.messenger = binaryMessenger; }
  }
  const dependencies = {
    '@ohos/flutter_ohos': {FlutterAbility, MethodChannel},
    '@kit.AccountKit': {
      authentication: {
        HuaweiIDProvider: class {
          createAuthorizationWithHuaweiIDRequest() {
            if (options.providerError) throw options.providerError;
            return {forceAuthorization: true};
          }
        },
        AuthenticationController: class {
          constructor(context) { controllerContexts.push(context); }
          executeRequest(request) {
            requests.push(request);
            if (options.syncError) throw options.syncError;
            return options.error ? Promise.reject(options.error) : Promise.resolve(options.response || {});
          }
        },
      },
    },
    '@kit.ShareKit': {},
    '@kit.AbilityKit': {},
    '@kit.ArkUI': {},
    '../plugins/GeneratedPluginRegistrant': {GeneratedPluginRegistrant: {registerWith() {}}},
    '../interop/StudioInterop': {configureInteropChannels() {}},
    '../interop/StudioBackgroundInterop': {configureBackgroundInteropChannels() {}, disposeBackgroundInterop() {}},
    '../interop/AgreementBridge': {},
    '../components/HuaweiQuickLoginPlatformView': {
      HUAWEI_QUICK_LOGIN_VIEW_TYPE: viewType, HuaweiQuickLoginViewFactory,
    },
  };
  const sandbox = {
    exports: {}, Map, Promise,
    require(name) {
      assert.ok(Object.hasOwn(dependencies, name), `Unexpected dependency: ${name}`);
      return dependencies[name];
    },
  };
  vm.runInNewContext(code, sandbox, {filename: sourcePath});
  const ability = new sandbox.exports.default();
  ability.configureFlutterEngine({
    dartExecutor: {getBinaryMessenger: () => messenger},
    getPlatformViewsController: () => ({getRegistry: () => ({
      registerViewFactory(type, factory) {
        assert.equal(factories.has(type), false, 'a view type must be registered once');
        factories.set(type, factory);
        return true;
      },
    })}),
  });
  async function invoke(method) {
    const channel = channels.get(channelName);
    assert.ok(channel?.handler, 'the Huawei account channel must have a handler');
    const replies = [];
    channel.handler.onMethodCall({method}, {
      success: value => replies.push({kind: 'success', value}),
      error: (code, message, details) => replies.push({kind: 'error', code, message, details}),
      notImplemented: () => replies.push({kind: 'notImplemented'}),
    });
    // The real handler returns void; drain its executeRequest promise chain.
    for (let i = 0; i < 8; i++) await Promise.resolve();
    assert.equal(replies.length, 1, `${method} must complete exactly once`);
    return replies[0];
  }
  return {ability, messenger, factories, requests, controllerContexts, HuaweiQuickLoginViewFactory, invoke};
}

test('engine startup registers the Huawei button using the engine messenger', () => {
  const f = fixture();
  const factory = f.factories.get(viewType);
  assert.ok(factory instanceof f.HuaweiQuickLoginViewFactory, 'Huawei view factory was not registered');
  assert.equal(factory.messenger, f.messenger);
});

test('anonymous phone request is silent and returns the masked phone', async () => {
  const f = fixture({response: {data: {extraInfo: {quickLoginAnonymousPhone: '138****8888'}}}});
  assert.deepEqual(await f.invoke('getAnonymousPhone'), {kind: 'success', value: '138****8888'});
  assert.equal(f.requests.length, 1);
  assert.deepEqual(Array.from(f.requests[0].scopes), ['quickLoginAnonymousPhone']);
  assert.deepEqual(Array.from(f.requests[0].permissions), []);
  assert.equal(f.requests[0].forceAuthorization, false);
  assert.equal(f.controllerContexts[0], f.ability.context);
});

test('absent or malformed anonymous phone produces an empty value', async () => {
  for (const response of [{}, {data: {}}, {data: {extraInfo: {}}},
    {data: {extraInfo: {quickLoginAnonymousPhone: 123}}}]) {
    const f = fixture({response});
    assert.deepEqual(await f.invoke('getAnonymousPhone'), {kind: 'success', value: ''});
  }
});

test('anonymous phone rejection completes the channel with the Account Kit error', async () => {
  const f = fixture({error: {code: 1001502005, message: 'Network error'}});
  assert.deepEqual(await f.invoke('getAnonymousPhone'), {
    kind: 'error', code: 'HUAWEI_LOGIN_FAILED', message: '1001502005: Network error', details: null,
  });
});

test('synchronous Account Kit failures complete the channel', async () => {
  for (const key of ['providerError', 'syncError']) {
    const f = fixture({[key]: {code: 1001502003, message: 'Invalid parameter'}});
    assert.deepEqual(await f.invoke('getAnonymousPhone'), {
      kind: 'error', code: 'HUAWEI_LOGIN_ERROR', message: '1001502003: Invalid parameter', details: null,
    });
  }
});

test('existing login still requests openid and returns the authorization code', async () => {
  const f = fixture({response: {data: {authorizationCode: 'test-authorization-code'}}});
  assert.deepEqual(await f.invoke('login'), {kind: 'success', value: 'test-authorization-code'});
  assert.deepEqual(Array.from(f.requests[0].scopes), ['openid']);
  assert.deepEqual(Array.from(f.requests[0].permissions), []);
  assert.equal(f.requests[0].forceAuthorization, true);
});

test('existing login rejects an empty authorization code', async () => {
  const f = fixture({response: {data: {authorizationCode: ''}}});
  const reply = await f.invoke('login');
  assert.equal(reply.kind, 'error');
  assert.equal(reply.code, 'HUAWEI_LOGIN_EMPTY');
});

test('unknown Huawei methods remain unimplemented', async () => {
  const f = fixture();
  assert.deepEqual(await f.invoke('unknownMethod'), {kind: 'notImplemented'});
  assert.equal(f.requests.length, 0);
});
