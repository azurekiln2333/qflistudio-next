import assert from 'node:assert/strict';
import { createServer } from 'node:http';
import test from 'node:test';
import { BLOCK_MARKER, optionsFrom, requestJson, runSmoke } from './smoke.mjs';

function options(extra = {}) {
  return { ...optionsFrom(['--qfli', 'http://127.0.0.1:3000', '--moderation', 'http://127.0.0.1:4310'], {
    MODERATION_APP_ID: 'qflistudio', MODERATION_API_KEY: 'test-key',
    SMOKE_UNVERIFIED_TOKEN: 'unverified', SMOKE_RATE_TOKEN: 'verified', SMOKE_ZONE_ID: 'zone_test',
  }), ...extra };
}

function fixture({ textDecision = 'block', publish = [], onRequest = () => {} } = {}) {
  let posts = 0;
  const fetchImpl = async (url, config) => {
    onRequest(url, config);
    assert.equal(config.redirect, 'error');
    assert.ok(config.signal instanceof AbortSignal);
    const path = new URL(url).pathname;
    let status = 200;
    let body;
    if (path === '/api/health') body = { ok: true };
    else if (path === '/healthz') body = { status: 'ok' };
    else if (path === '/v1/text/check') body = { decision: textDecision };
    else if (config.method === 'POST' && path === '/api/posts') {
      const input = JSON.parse(config.body);
      assert.equal(input.title, BLOCK_MARKER);
      assert.equal(input.content, BLOCK_MARKER);
      assert.equal(config.headers.authorization, 'Bearer verified');
      const reply = publish[posts++] || [429, { errorKey: 'rate.limited', retryAfter: 10 }];
      [status, body] = reply;
    } else { status = 403; body = { errorKey: 'realname.required' }; }
    return Response.json(body, { status });
  };
  return { fetchImpl, posts: () => posts };
}

test('strict smoke covers both services, text variants, five gates, and bounded rate', async () => {
  const mock = fixture({ publish: [[422, { errorKey: 'moderation.blocked' }]] });
  const result = await runSmoke(options({ strict: true, allowRate: true }), mock);
  assert.equal(result.ok, true);
  assert.deepEqual(result.counts, { pass: 14, fail: 0, skip: 0 });
  assert.equal(mock.posts(), 2);
});

test('default smoke skips quota consumption, and strict mode rejects that skip', async () => {
  const mock = fixture();
  assert.equal((await runSmoke(options(), mock)).ok, true);
  assert.equal(mock.posts(), 0);
  const result = await runSmoke(options({ strict: true }), mock);
  assert.equal(result.ok, false);
  assert.equal(result.counts.skip, 1);
});

test('failed marker preflight prevents all publication requests', async () => {
  const mock = fixture({ textDecision: 'pass' });
  const result = await runSmoke(options({ allowRate: true }), mock);
  assert.equal(result.ok, false);
  assert.equal(mock.posts(), 0);
  assert.match(result.cases.at(-1).detail, /preflight/);
});

test('unexpected publication stops quota probing immediately', async () => {
  const mock = fixture({ publish: [[200, { id: 'test-post', status: 'published' }]] });
  const result = await runSmoke(options({ allowRate: true }), mock);
  assert.equal(result.ok, false);
  assert.equal(mock.posts(), 1);
  assert.match(result.cases.at(-1).detail, /HTTP 200/);
});

test('rate probe enforces its budget and retryAfter contract', async () => {
  const mock = fixture({ publish: Array.from({ length: 3 }, () => [422, { errorKey: 'moderation.blocked' }]) });
  const result = await runSmoke(options({ allowRate: true, maxRateRequests: 2 }), mock);
  assert.equal(mock.posts(), 2);
  assert.equal(result.ok, false);
  const invalid = fixture({ publish: [[429, { errorKey: 'rate.limited', retryAfter: 0 }]] });
  assert.equal((await runSmoke(options({ allowRate: true }), invalid)).ok, false);
});

test('credentials are confined to their intended origins and never reported', async () => {
  const reported = [];
  const seen = [];
  const mock = fixture({ onRequest(url, config) { seen.push([new URL(url), config.headers]); } });
  await runSmoke(options({ allowRate: true }), { ...mock, report: item => reported.push(item) });
  for (const [url, headers] of seen) {
    if (url.port === '4310' && url.pathname !== '/healthz') assert.equal(headers.authorization, 'Bearer test-key');
    if (url.port === '3000') assert.notEqual(headers.authorization, 'Bearer test-key');
  }
  assert.doesNotMatch(JSON.stringify(reported), /test-key|Bearer|unverified/);
});

test('realname probes reject query and uppercase path bypasses and HTTP 401 substitutes', async () => {
  for (const broken of ['query', 'uppercase', 'unauthorized']) {
    const mock = fixture();
    const fetchImpl = (url, config) => {
      if (config.headers.authorization === 'Bearer unverified') {
        const path = new URL(url);
        if (broken === 'query' && path.search) return Promise.resolve(Response.json({}, { status: 200 }));
        if (broken === 'uppercase' && path.pathname === path.pathname.toUpperCase()) return Promise.resolve(Response.json({}, { status: 200 }));
        if (broken === 'unauthorized') return Promise.resolve(Response.json({ errorKey: 'realname.required' }, { status: 401 }));
      }
      return mock.fetchImpl(url, config);
    };
    const result = await runSmoke(options(), { fetchImpl });
    assert.equal(result.ok, false);
    assert.equal(result.cases.filter(item => item.name.startsWith('realname.') && item.status === 'fail').length, 5);
  }
});

test('validates URLs and arguments without echoing credential inputs', () => {
  for (const url of ['ftp://example.cn', 'https://secret:password@example.cn', 'https://example.cn/?token=x']) {
    assert.throws(() => optionsFrom(['--qfli', url], {}), /Base URLs/);
  }
  assert.throws(() => optionsFrom(['--qfli'], {}), /Missing value/);
  assert.throws(() => optionsFrom(['--qfli', 'https://example.cn', '--max-rate-requests', '1000'], {}), /integer/);
  assert.throws(() => optionsFrom(['--secret-argument'], {}), /Unknown argument/);
  assert.equal(optionsFrom(['--qfli', 'https://example.cn/mount/'], {}).qfli, 'https://example.cn/mount');
});

async function localServer(t, handler) {
  const server = createServer(handler);
  await new Promise(resolve => server.listen(0, '127.0.0.1', resolve));
  t.after(() => { server.closeAllConnections(); return new Promise(resolve => server.close(resolve)); });
  return `http://127.0.0.1:${server.address().port}`;
}

test('real HTTP redirects never forward bearer credentials to another endpoint', async t => {
  let leaked = false;
  const base = await localServer(t, (req, res) => {
    if (req.url === '/destination') { leaked = true; res.end('{}'); }
    else { res.writeHead(302, { location: '/destination' }); res.end(); }
  });
  await assert.rejects(requestJson(base, { headers: { authorization: 'Bearer private-test' } }), /Request failed/);
  assert.equal(leaked, false);
});

test('deadline includes reading a stalled JSON response body', async t => {
  const base = await localServer(t, (_req, res) => { res.writeHead(200, { 'content-type': 'application/json' }); res.write('{'); });
  const start = Date.now();
  await assert.rejects(requestJson(base, { timeoutMs: 100 }), /incomplete/);
  assert.ok(Date.now() - start < 3000);
});

test('upstream exception messages and bodies cannot enter smoke output', async () => {
  const result = await runSmoke(options(), { fetchImpl: async () => { throw new Error('Bearer test-key raw-secret'); } });
  assert.equal(result.ok, false);
  assert.doesNotMatch(JSON.stringify(result), /test-key|raw-secret/);
});
