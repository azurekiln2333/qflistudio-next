#!/usr/bin/env node
import assert from 'node:assert/strict';
import { fork, spawn, spawnSync } from 'node:child_process';
import { createHash, randomBytes } from 'node:crypto';
import { once } from 'node:events';
import { mkdtemp, readFile, rm } from 'node:fs/promises';
import { createServer } from 'node:http';
import { createServer as createTcpServer } from 'node:net';
import { tmpdir } from 'node:os';
import { basename, dirname, join, resolve } from 'node:path';
import { fileURLToPath, pathToFileURL } from 'node:url';
import { optionsFrom, requestJson, runSmoke } from './smoke.mjs';

const here = dirname(fileURLToPath(import.meta.url));
const repo = resolve(here, '../..');
const serverRoot = join(repo, 'azurekiln-qfli-server');

function childEnvironment(extra) {
  const inherited = {};
  for (const [key, value] of Object.entries(process.env)) {
    if (/^(path|systemroot|windir|temp|tmp|appdata|localappdata|userprofile|comspec|pathext|lang|lc_all)$/i.test(key)) inherited[key] = value;
  }
  return { ...inherited, NODE_ENV: 'test', ...extra };
}

async function availablePort() {
  const server = createTcpServer();
  await new Promise((resolve, reject) => { server.once('error', reject); server.listen(0, '127.0.0.1', resolve); });
  const port = server.address().port;
  await new Promise(resolve => server.close(resolve));
  return port;
}

function track(child, name) {
  const state = { child, name, failed: false, exited: null };
  state.done = new Promise(resolve => {
    child.once('error', () => { state.failed = true; resolve(); });
    child.once('exit', (code, signal) => { state.exited = { code, signal }; resolve(); });
  });
  // Drain output, but do not print session/profile data in the test report.
  child.stdout?.resume();
  child.stderr?.resume();
  return state;
}

async function waitHealthy(base, path, state) {
  const deadline = Date.now() + 20000;
  while (Date.now() < deadline) {
    if (state.failed || state.exited) throw new Error(`${state.name} exited before readiness`);
    try {
      const response = await requestJson(`${base}${path}`, { timeoutMs: 500 });
      if (response.status === 200) return;
    } catch { /* Startup can precede listener readiness. */ }
    await new Promise(resolve => setTimeout(resolve, 100));
  }
  throw new Error(`${state.name} readiness deadline exceeded`);
}

async function stop(state) {
  if (!state || state.exited || state.failed) return;
  state.child.kill('SIGTERM');
  let timeout;
  const graceful = await Promise.race([state.done.then(() => true), new Promise(resolve => { timeout = setTimeout(() => resolve(false), 3000); })]);
  clearTimeout(timeout);
  if (!graceful) {
    state.child.kill('SIGKILL');
    await state.done;
  }
}

function checkCommittedSdk() {
  const paths = ['package.json', 'package-lock.json', 'Dockerfile', 'src/moderation-client.js', 'vendor/azurekiln-moderation-client-0.1.0.tgz'];
  const tracked = spawnSync('git', ['ls-files', '--error-unmatch', paths.at(-1)], { cwd: serverRoot, stdio: 'ignore' });
  const clean = spawnSync('git', ['diff', '--quiet', 'HEAD', '--', ...paths], { cwd: serverRoot, stdio: 'ignore' });
  if (tracked.status !== 0 || clean.status !== 0) throw new Error('Wait for the committed W2b SDK integration before local E2E');
}

export async function runLocalE2e(moderationRepo) {
  checkCommittedSdk();
  const tarball = await readFile(join(serverRoot, 'vendor/azurekiln-moderation-client-0.1.0.tgz'));
  const sdkSha256 = createHash('sha256').update(tarball).digest('hex');
  const work = await mkdtemp(join(tmpdir(), 'qfli-compliance-e2e-'));
  let moderation;
  let qfli;
  let gateway;
  try {
    const accounts = {};
    for (const name of ['unverified', 'rate', 'author', 'reader', 'offline']) {
      accounts[name] = {
        accessToken: randomBytes(24).toString('hex'),
        claims: {
          sub: `local-e2e-${name}`, preferred_username: `e2e_${name}`, name: `e2e_${name}`,
          ...(name === 'unverified' ? {} : { phone_number: '+8613800000000', phone_number_verified: true }),
        },
      };
    }
    gateway = createServer((req, res) => {
      const access = (req.headers.authorization || '').replace(/^Bearer /, '');
      const account = Object.values(accounts).find(item => item.accessToken === access);
      res.setHeader('content-type', 'application/json');
      if (req.url === '/oauth2/userinfo' && account) res.end(JSON.stringify(account.claims));
      else { res.statusCode = 401; res.end('{"error":"invalid_token"}'); }
    });
    await new Promise((resolve, reject) => { gateway.once('error', reject); gateway.listen(0, '127.0.0.1', resolve); });
    const gatewayUrl = `http://127.0.0.1:${gateway.address().port}`;
    const moderationPort = await availablePort();
    const moderationUrl = `http://127.0.0.1:${moderationPort}`;
    const appId = 'qflistudio';
    const apiKey = randomBytes(32).toString('hex');
    const adminKey = randomBytes(32).toString('hex');
    moderation = track(spawn(process.execPath, ['src/server.js'], {
      cwd: moderationRepo, stdio: ['ignore', 'pipe', 'pipe'],
      env: childEnvironment({ HOST: '127.0.0.1', PORT: String(moderationPort),
        MODERATION_DB_PATH: join(work, 'moderation.sqlite'), MODERATION_APPS_JSON: JSON.stringify([{ appId, apiKey, adminKey }]) }),
    }), 'moderation');
    await waitHealthy(moderationUrl, '/healthz', moderation);
    const qfliPort = await availablePort();
    const qfliUrl = `http://127.0.0.1:${qfliPort}`;
    qfli = track(fork(join(here, 'local-qfli.cjs'), [], {
      cwd: serverRoot, silent: true,
      env: childEnvironment({ PORT: String(qfliPort), DB_DRIVER: 'sqlite', QFLI_DATA_DIR: join(work, 'qfli'),
        QFLI_JWT_SECRET: randomBytes(32).toString('hex'), QFLI_AUDIT_SALT: randomBytes(32).toString('hex'),
        AZK_OAUTH2_BASE_URL: gatewayUrl, AZK_OAUTH2_CLIENT_ID: 'qfli_local_e2e',
        AZK_OAUTH2_CLIENT_SECRET: randomBytes(32).toString('hex'), AZK_OAUTH2_REDIRECT_URI: `${gatewayUrl}/callback`,
        MODERATION_BASE_URL: moderationUrl, MODERATION_APP_ID: appId, MODERATION_API_KEY: apiKey,
        MODERATION_ADMIN_KEY: adminKey, MODERATION_TIMEOUT_MS: '1000',
        PUBLISH_RATE_PER_MINUTE: '3', PUBLISH_RATE_PER_DAY: '20',
        COMPLIANCE_E2E_ROOT: serverRoot, COMPLIANCE_E2E_ACCOUNTS: JSON.stringify(accounts) }),
    }), 'QFLI');
    let sessionTimer;
    const sessionMessage = await Promise.race([
      once(qfli.child, 'message').then(([message]) => message),
      qfli.done.then(() => { throw new Error('QFLI exited before test sessions were ready'); }),
      new Promise((_, reject) => { sessionTimer = setTimeout(() => reject(new Error('Test session deadline exceeded')), 20000); }),
    ]).finally(() => clearTimeout(sessionTimer));
    assert.equal(sessionMessage.type, 'sessions');
    const tokens = sessionMessage.tokens;
    await waitHealthy(qfliUrl, '/api/health', qfli);
    const results = [];
    const smoke = await runSmoke(optionsFrom(['--qfli', qfliUrl, '--moderation', moderationUrl,
      '--strict', '--allow-rate', '--max-rate-requests', '7'], {
      MODERATION_APP_ID: appId, MODERATION_API_KEY: apiKey,
      SMOKE_UNVERIFIED_TOKEN: tokens.unverified, SMOKE_RATE_TOKEN: tokens.rate,
    }));
    results.push({ name: 'strict-smoke', status: smoke.ok ? 'pass' : 'fail', counts: smoke.counts,
      failures: smoke.cases.filter(item => item.status !== 'pass') });

    const auth = name => ({ authorization: `Bearer ${tokens[name]}`, 'X-Client-Platform': 'web/local-e2e' });
    const call = (path, name, body) => requestJson(`${qfliUrl}${path}`, {
      headers: auth(name), ...(body ? { method: 'POST', body } : {}), timeoutMs: 5000,
    });
    const zones = await call('/api/zones', 'author');
    assert.equal(zones.status, 200);
    const post = { type: 'discussion', zoneId: zones.json.items[0].id,
      title: 'Local integration sample', content: 'Local integration sample content', tags: [] };
    const published = await call('/api/posts', 'author', post);
    assert.equal(published.status, 200);
    assert.equal(published.json.status, 'published');
    results.push({ name: 'verified-publication-via-sdk', status: 'pass' });

    const report = await call('/api/reports', 'reader', {
      targetType: 'post', targetId: published.json.id, reason: 'Local integration test report',
    });
    assert.equal(report.status, 201);
    assert.equal(report.json.status, 'open');
    assert.equal(typeof report.json.moderationReportId, 'string');
    const reports = await requestJson(`${moderationUrl}/v1/admin/reports?status=open`, {
      headers: { 'X-App-Id': appId, authorization: `Bearer ${adminKey}` },
    });
    assert.equal(reports.status, 200);
    assert.ok(reports.json.items?.some(item => item.id === report.json.moderationReportId
      && item.targetId === published.json.id));
    results.push({ name: 'report-forwarding-via-sdk', status: 'pass' });

    const policy = await requestJson(`${moderationUrl}/v1/admin/scenes/community.post.title`, {
      method: 'PUT', headers: { 'X-App-Id': appId, authorization: `Bearer ${adminKey}` }, body: { preReview: true },
    });
    assert.equal(policy.status, 200);
    const pending = await call('/api/posts', 'author', post);
    assert.equal(pending.status, 200);
    assert.equal(pending.json.status, 'pending');
    assert.equal((await call(`/api/posts/${pending.json.id}`, 'author')).status, 200);
    assert.equal((await call(`/api/posts/${pending.json.id}`, 'reader')).status, 404);
    results.push({ name: 'remote-pre-review-and-author-only-visibility', status: 'pass' });

    const audit = await requestJson(`${moderationUrl}/v1/admin/audit?action=text.check&limit=50`, {
      headers: { 'X-App-Id': appId, authorization: `Bearer ${adminKey}` },
    });
    assert.equal(audit.status, 200);
    assert.ok(audit.json.items?.some(item => item.decision === 'pass'));
    assert.ok(audit.json.items?.some(item => item.decision === 'review'));
    results.push({ name: 'moderation-durable-decision-audit', status: 'pass' });

    await stop(moderation);
    const offline = await call('/api/posts', 'offline', post);
    assert.equal(offline.status, 503);
    assert.equal(offline.json.errorKey, 'moderation.unavailable');
    results.push({ name: 'service-down-fail-closed', status: 'pass' });
    return { ok: results.every(item => item.status === 'pass'), processes: 2, database: 'sqlite', sdkSha256, results };
  } finally {
    await stop(qfli);
    await stop(moderation);
    if (gateway) {
      gateway.closeAllConnections();
      await new Promise(resolve => gateway.close(resolve));
    }
    if (dirname(resolve(work)) !== resolve(tmpdir()) || !basename(work).startsWith('qfli-compliance-e2e-')) {
      throw new Error('Refusing cleanup outside the dedicated temporary directory');
    }
    await rm(work, { recursive: true, force: true, maxRetries: 10, retryDelay: 100 });
  }
}

export async function main(argv = process.argv.slice(2)) {
  if (argv.length !== 2 || argv[0] !== '--moderation-repo') {
    console.error('Usage: node scripts/compliance/local-e2e.mjs --moderation-repo ABSOLUTE_PATH');
    return 1;
  }
  try {
    const result = await runLocalE2e(resolve(argv[1]));
    console.log(JSON.stringify(result, null, 2));
    return result.ok ? 0 : 1;
  } catch (error) {
    console.error(JSON.stringify({ ok: false, error: error.message }));
    return 1;
  }
}

if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) process.exitCode = await main();
