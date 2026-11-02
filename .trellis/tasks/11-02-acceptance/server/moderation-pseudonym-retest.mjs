import { spawn, spawnSync } from 'node:child_process';
import { createHash, createHmac, randomBytes } from 'node:crypto';
import { createServer } from 'node:http';
import { createServer as createTcpServer } from 'node:net';
import { DatabaseSync } from 'node:sqlite';
import { mkdtemp, readFile, readdir, writeFile } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { dirname, join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

const scriptPath = fileURLToPath(import.meta.url);
const repo = resolve(process.argv[2] || join(dirname(scriptPath), '../../../..'));
const moderationRepo = resolve(process.argv[3] || join(dirname(repo), 'azurekiln-moderation'));
const serverRoot = join(repo, 'azurekiln-qfli-server');
const evidenceRoot = await mkdtemp(join(tmpdir(), 'qfli-server-pseudonym-20261103-p7-'));
const startedAt = new Date().toISOString();
const secrets = new Set();
const checks = [], records = [], gatewayEvents = [], processes = [], children = [];
const tokens = {}, ids = {}, expected = {};
const secret = () => { const value = randomBytes(32).toString('hex'); secrets.add(value); return value; };
const salt = secret(), apiKey = secret(), adminKey = secret(), clientSecret = secret();
const appId = 'qflistudio';
const erased = new Set(), codes = new Map();
const accounts = Object.fromEntries(['admin', 'keeper', 'erase', 'reporter'].map(name => [name, {
  accessToken: secret(), claims: {
    sub: `acceptance-p7-pseudonym-${name}`, preferred_username: `accept_p7_${name}`,
    name: `Acceptance ${name}`, phone_number: '+8613800000000', phone_number_verified: true,
    ...(name === 'admin' ? { isAdmin: true, role: 'admin' } : {}),
  },
}]));
let gateway, qfli, moderation, qdb, mdb, env, qfliUrl, moderationUrl;

function redact(value, key = '') {
  if (/^(authorization|password|token|access_token|refresh_token|client_secret|code|code_verifier)$/i.test(key)) return '[REDACTED]';
  if (typeof value === 'string') {
    for (const item of secrets) value = value.split(item).join('[REDACTED]');
    return value;
  }
  if (Array.isArray(value)) return value.map(item => redact(item));
  if (value && typeof value === 'object') return Object.fromEntries(Object.entries(value).map(([k, v]) => [k, redact(v, k)]));
  return value;
}
async function save(name, value) {
  await writeFile(join(evidenceRoot, name), JSON.stringify(redact(value), null, 2));
}
function check(id, pass, actual) {
  checks.push({ id, result: pass ? 'pass' : 'fail', actual: redact(actual) });
  process.stdout.write(JSON.stringify({ id, result: pass ? 'pass' : 'fail' }) + '\n');
}
function requireValue(value, label) {
  if (!value) throw new Error(label);
  return value;
}
function git(cwd, args) {
  const result = spawnSync('git', args, { cwd, encoding: 'utf8' });
  if (result.status !== 0) throw new Error(`git ${args[0]} failed`);
  return result.stdout.trim();
}
async function sourceHashes(root) {
  const hashes = {};
  async function walk(folder) {
    for (const entry of await readdir(folder, { withFileTypes: true })) {
      const path = join(folder, entry.name);
      if (entry.isDirectory()) await walk(path);
      else hashes[path.slice(root.length + 1).replaceAll('\\', '/')] = createHash('sha256').update(await readFile(path)).digest('hex');
    }
  }
  await walk(join(root, 'src'));
  for (const file of ['package.json', 'package-lock.json']) {
    hashes[file] = createHash('sha256').update(await readFile(join(root, file))).digest('hex');
  }
  return hashes;
}
function isolatedEnvironment(extra) {
  const inherited = Object.fromEntries(Object.entries(process.env).filter(([key]) =>
    /^(path|systemroot|windir|temp|tmp|appdata|localappdata|userprofile|comspec|pathext|lang|lc_all)$/i.test(key)));
  return { ...inherited, NODE_ENV: 'production', ...extra };
}
async function port() {
  const server = createTcpServer();
  await new Promise((resolveReady, reject) => { server.once('error', reject); server.listen(0, '127.0.0.1', resolveReady); });
  const value = server.address().port;
  await new Promise(done => server.close(done));
  return value;
}
function launch(name, cwd, childEnv) {
  const child = spawn(process.execPath, ['src/server.js'], { cwd, env: childEnv, stdio: ['ignore', 'pipe', 'pipe'] });
  const state = { child, name, exited: false };
  children.push(state);
  processes.push({ name, event: 'spawn', pid: child.pid, nodeEnv: childEnv.NODE_ENV });
  state.done = new Promise(done => {
    child.once('error', error => { state.exited = true; processes.push({ name, error: error.message }); done(); });
    child.once('exit', (code, signal) => { state.exited = true; processes.push({ name, event: 'exit', code, signal }); done(); });
  });
  for (const [stream, kind] of [[child.stdout, 'stdout'], [child.stderr, 'stderr']]) {
    stream.on('data', data => processes.push({ name, kind, text: data.toString() }));
  }
  return state;
}
async function stop(state) {
  if (!state || state.exited) return;
  state.child.kill('SIGTERM');
  let timer;
  await Promise.race([state.done, new Promise(done => { timer = setTimeout(done, 3000); })]).finally(() => clearTimeout(timer));
  if (!state.exited) { state.child.kill('SIGKILL'); await state.done; }
}
async function healthy(base, path, state) {
  for (let attempt = 0; attempt < 100; attempt++) {
    if (state.exited) throw new Error(`${state.name} exited before readiness`);
    try {
      if ((await fetch(base + path, { signal: AbortSignal.timeout(300) })).status === 200) return;
    } catch { /* Readiness only; request results are recorded separately. */ }
    await new Promise(done => setTimeout(done, 100));
  }
  throw new Error(`${state.name} did not become ready`);
}
async function call(id, base, path, method = 'GET', body, headers = {}) {
  const response = await fetch(base + path, {
    method, headers: { ...headers, ...(body === undefined ? {} : { 'content-type': 'application/json' }) },
    body: body === undefined ? undefined : JSON.stringify(body), redirect: 'manual', signal: AbortSignal.timeout(8000),
  });
  const text = await response.text();
  let json;
  try { json = JSON.parse(text); } catch { json = null; }
  if (json?.token) secrets.add(json.token);
  records.push(redact({ id, request: { method, path, headers, ...(body === undefined ? {} : { body }) },
    response: { status: response.status, body: json ?? text } }));
  return { status: response.status, json, text };
}
const q = (id, path, who, method = 'GET', body, extra = {}) => call(id, qfliUrl, path, method, body, {
  'X-Client-Platform': 'harmonyos-app/acceptance', 'X-Real-IP': '198.51.100.37', 'X-Real-Port': '45678',
  ...(who ? { authorization: `Bearer ${tokens[who]}` } : {}), ...extra,
});
const m = (id, path, method = 'GET', body) => call(id, moderationUrl, path, method, body, {
  'X-App-Id': appId, authorization: `Bearer ${adminKey}`,
});
function snapshot(database) {
  return Object.fromEntries(database.prepare("SELECT name FROM sqlite_schema WHERE type='table' ORDER BY name").all().map(({ name }) =>
    [name, database.prepare(`SELECT * FROM "${name.replaceAll('"', '""')}"`).all()]));
}
function scan(value) {
  const serialized = JSON.stringify(value);
  return [...Object.values(ids), ...Object.values(accounts).map(account => account.claims.sub)].filter(id => serialized.includes(id));
}
async function inspectModeration(stage) {
  const tables = snapshot(mdb);
  const matches = [];
  for (const [table, rows] of Object.entries(tables)) {
    rows.forEach((row, rowIndex) => {
      for (const [column, value] of Object.entries(row)) {
        for (const rawId of scan(value)) matches.push({ table, rowIndex, column, rawId });
      }
    });
  }
  const files = [];
  for (const suffix of ['', '-wal', '-shm']) {
    const path = join(evidenceRoot, 'moderation.sqlite' + suffix);
    try {
      const bytes = await readFile(path);
      const rawIds = [...Object.values(ids), ...Object.values(accounts).map(account => account.claims.sub)];
      files.push({ file: 'moderation.sqlite' + suffix, bytes: bytes.length,
        matches: rawIds.filter(id => bytes.includes(Buffer.from(id)) || bytes.includes(Buffer.from(id, 'utf16le'))) });
    } catch (error) {
      if (suffix && error.code === 'ENOENT') files.push({ file: 'moderation.sqlite' + suffix, absent: true, matches: [] });
      else throw error;
    }
  }
  const summary = { tables: Object.fromEntries(Object.entries(tables).map(([name, rows]) => [name, rows.length])), matches, files };
  await save(`moderation-${stage}.json`, { ...summary, rows: tables });
  check(`7p.${stage}.database-no-raw-identifiers`, matches.length === 0, summary);
  check(`7p.${stage}.database-files-no-raw-identifiers`, files.every(file => file.matches.length === 0), files);
  const audit = [];
  for (let offset = 0; ; offset += 100) {
    const result = await m(`7p.${stage}.audit-page-${offset}`, `/v1/admin/audit?limit=100&offset=${offset}`);
    requireValue(result.status === 200 && Array.isArray(result.json?.items), 'Audit query failed');
    audit.push(...result.json.items);
    if (audit.length >= result.json.total) break;
  }
  check(`7p.${stage}.audit-api-no-raw-identifiers`, audit.length > 0 && scan(audit).length === 0, { count: audit.length, matches: scan(audit) });
  return tables;
}
async function restart(mode, value) {
  await stop(qfli);
  const childEnv = { ...env };
  if (value === undefined) delete childEnv.QFLI_MODERATION_SUBJECT_SALT;
  else childEnv.QFLI_MODERATION_SUBJECT_SALT = value;
  qfli = launch(`qfli-${mode}`, serverRoot, childEnv);
  await healthy(qfliUrl, '/api/health', qfli);
}
const initial = {
  startedAt, node: process.version, evidenceRoot,
  qfliRevision: git(repo, ['rev-parse', 'HEAD']), moderationRevision: git(moderationRepo, ['rev-parse', 'HEAD']),
  qfliStatus: git(repo, ['status', '--short', '--', 'azurekiln-qfli-server']),
  moderationStatus: git(moderationRepo, ['status', '--short']),
  qfliSources: await sourceHashes(serverRoot), moderationSources: await sourceHashes(moderationRepo),
  harnessSha256: createHash('sha256').update(await readFile(scriptPath)).digest('hex'),
  sdkSha256: createHash('sha256').update(await readFile(join(serverRoot, 'vendor/azurekiln-moderation-client-0.1.0.tgz'))).digest('hex'),
  configuration: { nodeEnv: 'production', hmac: 'HMAC-SHA256', keyLength: salt.length, liveGateway: false },
};
await save('manifest.json', initial);
process.stdout.write(`EVIDENCE ${evidenceRoot}\n`);

try {
  gateway = createServer(async (req, res) => {
    try {
      const chunks = [];
      for await (const chunk of req) chunks.push(chunk);
      const text = Buffer.concat(chunks).toString();
      let body;
      try { body = JSON.parse(text); } catch { body = Object.fromEntries(new URLSearchParams(text)); }
      const account = Object.values(accounts).find(item => req.headers.authorization === `Bearer ${item.accessToken}`);
      let status = 200, data;
      if (req.url === '/oauth2/authorize') {
        const selected = Object.values(accounts).find(item => item.claims.preferred_username === body.username);
        if (!selected || erased.has(selected.claims.sub)) { status = 401; data = { error: 'invalid_credentials' }; }
        else {
          const code = secret(); codes.set(code, selected);
          const redirect = new URL(body.redirect_uri);
          redirect.searchParams.set('code', code); redirect.searchParams.set('state', body.state);
          data = { redirect: redirect.href };
        }
      } else if (req.url === '/oauth2/token') {
        const selected = codes.get(body.code); codes.delete(body.code);
        if (selected) data = { access_token: selected.accessToken, expires_in: 3600, token_type: 'Bearer' };
        else { status = 400; data = { error: 'invalid_grant' }; }
      } else if (req.url === '/oauth2/userinfo') {
        if (account && !erased.has(account.claims.sub)) data = account.claims;
        else { status = 401; data = { error: 'invalid_token' }; }
      } else if (req.url === '/oauth2/profile' && req.method === 'PUT' && account && !erased.has(account.claims.sub)) {
        Object.assign(account.claims, body); data = { ok: true };
      } else if (req.url.startsWith('/oauth2/public-profile/')) {
        const subject = decodeURIComponent(req.url.slice('/oauth2/public-profile/'.length));
        const selected = Object.values(accounts).find(item => item.claims.sub === subject);
        if (selected && !erased.has(subject)) data = selected.claims;
        else { status = 404; data = { error: 'user_not_found' }; }
      } else if (req.url === '/oauth2/account/erase') {
        const basicValid = req.headers.authorization === 'Basic ' + Buffer.from(`qfli_acceptance:${clientSecret}`).toString('base64');
        if (!basicValid) { status = 401; data = { error: 'invalid_client' }; }
        else if (!Object.values(accounts).some(item => item.claims.sub === body.user_id)) { status = 404; data = { error: 'user_not_found' }; }
        else { erased.add(body.user_id); data = { user_id: body.user_id, status: 'deleted', tokens_revoked: true, deleted_at: new Date().toISOString() }; }
      } else { status = 404; data = { error: 'fixture_route_missing' }; }
      gatewayEvents.push(redact({ method: req.method, path: req.url, status,
        ...(['/oauth2/profile', '/oauth2/account/erase'].includes(req.url) ? { body, response: data } : {}) }));
      res.writeHead(status, { 'content-type': 'application/json' }); res.end(JSON.stringify(data));
    } catch (error) {
      gatewayEvents.push({ error: error.message }); res.writeHead(500); res.end('{}');
    }
  });
  await new Promise((ready, reject) => { gateway.once('error', reject); gateway.listen(0, '127.0.0.1', ready); });
  const gatewayUrl = `http://127.0.0.1:${gateway.address().port}`;
  const moderationPort = await port(); moderationUrl = `http://127.0.0.1:${moderationPort}`;
  moderation = launch('moderation', moderationRepo, isolatedEnvironment({ HOST: '127.0.0.1', PORT: String(moderationPort),
    MODERATION_DB_PATH: join(evidenceRoot, 'moderation.sqlite'), MODERATION_APPS_JSON: JSON.stringify([{ appId, apiKey, adminKey }]) }));
  await healthy(moderationUrl, '/healthz', moderation);
  const qfliPort = await port(); qfliUrl = `http://127.0.0.1:${qfliPort}`;
  env = isolatedEnvironment({ PORT: String(qfliPort), DB_DRIVER: 'sqlite', QFLI_DATA_DIR: join(evidenceRoot, 'qfli'),
    QFLI_JWT_SECRET: secret(), QFLI_AUDIT_SALT: secret(), QFLI_MODERATION_SUBJECT_SALT: salt,
    AZK_OAUTH2_BASE_URL: gatewayUrl, AZK_OAUTH2_CLIENT_ID: 'qfli_acceptance', AZK_OAUTH2_CLIENT_SECRET: clientSecret,
    AZK_OAUTH2_REDIRECT_URI: gatewayUrl + '/callback', MODERATION_BASE_URL: moderationUrl,
    MODERATION_APP_ID: appId, MODERATION_API_KEY: apiKey, MODERATION_ADMIN_KEY: adminKey, MODERATION_TIMEOUT_MS: '1000',
    PUBLISH_RATE_PER_MINUTE: '100', PUBLISH_RATE_PER_DAY: '1000', COMMENT_RATE_PER_MINUTE: '100', COMMENT_RATE_PER_DAY: '1000' });
  qfli = launch('qfli-configured', serverRoot, env);
  await healthy(qfliUrl, '/api/health', qfli);
  qdb = new DatabaseSync(join(evidenceRoot, 'qfli/qfli.db'), { readOnly: true });
  mdb = new DatabaseSync(join(evidenceRoot, 'moderation.sqlite'), { readOnly: true });
  qdb.exec('PRAGMA busy_timeout=5000'); mdb.exec('PRAGMA busy_timeout=5000');
  for (const [name, account] of Object.entries(accounts)) {
    const login = await q(`7p.login.${name}`, '/api/auth/login', null, 'POST', { username: account.claims.preferred_username, password: 'Acceptance-only-password' });
    check(`7p.login.${name}`, login.status === 200 && /^user_[0-9a-f]{32}$/.test(login.json?.user?.id), { status: login.status, user: login.json?.user });
    tokens[name] = requireValue(login.json?.token, 'Real login failed');
    ids[name] = login.json.user.id;
    expected[name] = 'psn_' + createHmac('sha256', salt).update(ids[name]).digest('hex');
  }
  const localUsers = qdb.prepare('SELECT id,gateway_user_id FROM users').all();
  check('7p.all-qfli-identities-covered', localUsers.length === Object.keys(ids).length && localUsers.every(row =>
    Object.entries(ids).some(([name, id]) => row.id === id && row.gateway_user_id === accounts[name].claims.sub)), localUsers);
  records.push({ id: '7p.identities', ids, localUsers, gatewaySubjects: Object.fromEntries(Object.entries(accounts).map(([name, account]) => [name, account.claims.sub])), expected });
  const zones = await q('7p.zones', '/api/zones', 'keeper');
  const zoneId = requireValue(zones.json?.items?.[0]?.id, 'No seeded zone');
  const postBody = (title, content = 'Acceptance ordinary technical discussion body') => ({ type: 'discussion', zoneId, title, content, tags: ['acceptance'] });
  const keeperPost = await q('7p.seed-post', '/api/posts', 'keeper', 'POST', postBody('Acceptance persistent discussion'));
  const postId = requireValue(keeperPost.json?.id, 'Seed post failed');
  const authorPost = await q('7p.post', '/api/posts', 'erase', 'POST', postBody('Acceptance author discussion'));
  check('7p.post', authorPost.status === 200 && authorPost.json?.status === 'published', authorPost);
  const comment = await q('7p.comment', `/api/posts/${postId}/comments`, 'erase', 'POST', { content: 'Acceptance ordinary author comment' });
  check('7p.comment', comment.status === 200 && comment.json?.comment?.status === 'published', comment);
  const commentId = requireValue(comment.json?.comment?.id, 'Comment creation failed');
  const profile = await q('7p.profile', '/api/users/me', 'erase', 'PATCH', { nickname: 'Acceptance profile', bio: 'Acceptance ordinary profile text' });
  check('7p.profile', profile.status === 200, { status: profile.status });
  const reports = [];
  for (const [who, targetType, targetId] of [['erase', 'post', postId], ['erase', 'comment', commentId], ['erase', 'user', ids.keeper], ['reporter', 'user', ids.erase]]) {
    const result = await q(`7p.report.${who}.${targetType}`, '/api/reports', who, 'POST', { targetType, targetId, reason: 'Acceptance report identity retention' });
    const row = result.json?.moderationReportId ? mdb.prepare('SELECT * FROM reports WHERE id=?').get(result.json.moderationReportId) : null;
    const expectedTarget = targetType === 'user' ? 'psn_' + createHmac('sha256', salt).update(targetId).digest('hex') : targetId;
    reports.push({ who, targetType, targetId, localId: result.json?.id, moderationId: result.json?.moderationReportId });
    check(`7p.report.${who}.${targetType}`, result.status === 201 && row?.reporter_id === expected[who] && row?.target_id === expectedTarget, { status: result.status, row });
  }
  await m('7p.keyword', '/v1/admin/keywords', 'POST', { word: 'acceptancebadwordpseven', category: 'custom' });
  const beforeBlocked = { posts: qdb.prepare('SELECT COUNT(*) n FROM posts').get().n, comments: qdb.prepare('SELECT COUNT(*) n FROM comments').get().n };
  const blockedPost = await q('7p.blocked-post', '/api/posts', 'erase', 'POST', postBody('acceptancebadwordpseven'));
  const blockedComment = await q('7p.blocked-comment', `/api/posts/${postId}/comments`, 'erase', 'POST', { content: 'acceptancebadwordpseven' });
  const blockedProfile = await q('7p.blocked-profile', '/api/users/me', 'erase', 'PATCH', { nickname: 'acceptancebadwordpseven' });
  for (const [kind, result] of [['post', blockedPost], ['comment', blockedComment], ['profile', blockedProfile]]) {
    check(`7p.blocked-${kind}`, result.status === 422 && result.json?.errorKey === 'moderation.blocked', { status: result.status, body: result.json });
  }
  await m('7p.ip-rule', '/v1/admin/ip-rules', 'POST', { type: 'ip', value: '203.0.113.37', reason: 'Acceptance blocked source' });
  const blockedIp = await q('7p.ip-block', '/api/posts', 'erase', 'POST', postBody('Acceptance blocked source'), { 'X-Real-IP': '203.0.113.37' });
  check('7p.ip-block', blockedIp.status === 403 && blockedIp.json?.errorKey === 'moderation.ip_blocked', { status: blockedIp.status, body: blockedIp.json });
  check('7p.blocks-no-content-written', beforeBlocked.posts === qdb.prepare('SELECT COUNT(*) n FROM posts').get().n && beforeBlocked.comments === qdb.prepare('SELECT COUNT(*) n FROM comments').get().n, beforeBlocked);
  for (const scene of ['community.post.title', 'community.comment']) await m('7p.review-policy.' + scene, '/v1/admin/scenes/' + scene, 'PUT', { preReview: true });
  const pendingPost = await q('7p.pending-post', '/api/posts', 'erase', 'POST', postBody('Acceptance queued discussion'));
  const pendingComment = await q('7p.pending-comment', `/api/posts/${postId}/comments`, 'erase', 'POST', { content: 'Acceptance queued comment' });
  check('7p.pending-post', pendingPost.status === 200 && pendingPost.json?.status === 'pending', pendingPost.json);
  check('7p.pending-comment', pendingComment.status === 200 && pendingComment.json?.comment?.status === 'pending', pendingComment.json);
  const before = await inspectModeration('before-erase');
  const ownAudits = before.audit_events.filter(row => row.actor_id === expected.erase);
  for (const scene of ['community.post', 'community.post.title', 'community.post.content', 'community.post.tag', 'community.comment', 'profile.nickname', 'profile.bio']) {
    check('7p.hmac-scene.' + scene, ownAudits.some(row => ['text.check', 'ip.check'].includes(row.action) && JSON.parse(row.data).scene === scene), { expectedActor: expected.erase, scene });
  }
  check('7p.hmac-block-audits', ownAudits.filter(row => row.decision === 'block' && row.action === 'text.check').length === 3 && ownAudits.some(row => row.decision === 'block' && row.action === 'ip.check'), ownAudits.filter(row => row.decision === 'block'));
  check('7p.hmac-queue', before.review_items.length === 2 && before.review_items.every(row => row.user_id === expected.erase), before.review_items);
  const actorIds = before.audit_events.filter(row => row.actor_id !== null).map(row => row.actor_id);
  check('7p.only-known-pseudonymous-actors', actorIds.length > 0 && actorIds.every(id => Object.values(expected).includes(id)), [...new Set(actorIds)]);
  for (const name of ['erase', 'reporter']) {
    const erasedResult = await q('7p.erase.' + name, '/api/users/me/deactivate', name, 'POST', { confirm: 'DEACTIVATE' });
    const oldSession = await q('7p.old-session.' + name, '/api/users/me', name);
    check('7p.erase.' + name, erasedResult.status === 200 && erasedResult.json?.status === 'deactivated' && oldSession.status === 401 && !qdb.prepare('SELECT 1 FROM users WHERE id=?').get(ids[name]), { response: erasedResult.json, oldSessionStatus: oldSession.status });
    const after = await inspectModeration('after-' + name);
    check('7p.' + name + '.moderation-records-preserved', JSON.stringify(after) === JSON.stringify(before), { auditRows: after.audit_events.length, reports: after.reports.length, reviews: after.review_items.length });
  }
  for (const report of reports) {
    const remote = await m(`7p.report-after-erase.${report.who}.${report.targetType}`, '/v1/admin/reports/' + report.moderationId);
    check(`7p.report-after-erase.${report.who}.${report.targetType}`, remote.status === 200 && scan(remote.json).length === 0 && remote.json?.reporterId === expected[report.who], remote.json);
  }
  async function failureCase(mode, key) {
    await restart(mode, key);
    const tablesBefore = snapshot(mdb);
    const countsBefore = { posts: qdb.prepare('SELECT COUNT(*) n FROM posts').get().n, comments: qdb.prepare('SELECT COUNT(*) n FROM comments').get().n };
    const profileCallsBefore = gatewayEvents.filter(event => event.path === '/oauth2/profile').length;
    const cases = [
      ['post', '/api/posts', 'POST', postBody('Acceptance refused publication')],
      ['comment', `/api/posts/${postId}/comments`, 'POST', { content: 'Acceptance refused comment' }],
      ['nickname', '/api/users/me', 'PATCH', { nickname: 'Acceptance refused nickname' }],
      ['bio', '/api/users/me', 'PATCH', { bio: 'Acceptance refused biography' }],
    ];
    for (const [kind, path, method, body] of cases) {
      const result = await q(`7p.${mode}.${kind}`, path, 'keeper', method, body);
      check(`7p.${mode}.${kind}`, result.status === 503 && result.json?.errorKey === 'moderation.unavailable' && result.json?.error === '审核服务暂不可用', { status: result.status, body: result.json });
    }
    const report = await q(`7p.${mode}.report`, '/api/reports', 'keeper', 'POST', { targetType: 'user', targetId: ids.admin, reason: 'Acceptance queued report' });
    const local = report.json?.id ? qdb.prepare('SELECT id,forwarded,moderation_report_id FROM reports WHERE id=?').get(report.json.id) : null;
    check(`7p.${mode}.report-queued-locally`, report.status === 201 && report.json?.status === 'queued' && local?.forwarded === 0 && local?.moderation_report_id === null, { response: report.json, local });
    check(`7p.${mode}.no-content-or-profile-written`, countsBefore.posts === qdb.prepare('SELECT COUNT(*) n FROM posts').get().n && countsBefore.comments === qdb.prepare('SELECT COUNT(*) n FROM comments').get().n && profileCallsBefore === gatewayEvents.filter(event => event.path === '/oauth2/profile').length, countsBefore);
    check(`7p.${mode}.no-moderation-records-added`, JSON.stringify(tablesBefore) === JSON.stringify(snapshot(mdb)), { auditCount: tablesBefore.audit_events.length });
    check(`7p.${mode}.configuration-warning`, processes.some(event => event.name === 'qfli-' + mode && event.text?.includes('moderation.subject_salt_missing')), { event: 'moderation.subject_salt_missing' });
  }
  await failureCase('missing-key', undefined);
  await failureCase('short-key', 'short');
  await restart('recovered-key', salt);
  const recovered = await q('7p.recovered-key', '/api/posts', 'keeper', 'POST', postBody('Acceptance recovered publication'));
  check('7p.recovered-key', recovered.status === 200 && Boolean(recovered.json?.id), { status: recovered.status, body: recovered.json });
  await inspectModeration('final');
  await save('qfli-final.json', {
    users: qdb.prepare('SELECT id,gateway_user_id FROM users').all(),
    reports: qdb.prepare('SELECT * FROM reports').all(),
    audit: qdb.prepare('SELECT id,user_id,action,target,detail FROM audit_logs').all(),
  });
  check('harness.completed', true, { reports: reports.length, productionStarts: children.filter(child => child.name.startsWith('qfli-')).length });
} catch (error) {
  records.push({ id: 'harness.error', message: error.message, stack: error.stack });
  check('harness.completed', false, error.message);
} finally {
  qdb?.close(); mdb?.close();
  for (const child of children) await stop(child);
  if (gateway) { gateway.closeAllConnections(); await new Promise(done => gateway.close(done)); }
  const sourceChanges = {};
  for (const [name, root, prior] of [['qfli', serverRoot, initial.qfliSources], ['moderation', moderationRepo, initial.moderationSources]]) {
    const after = await sourceHashes(root);
    sourceChanges[name] = Object.keys({ ...prior, ...after }).filter(path => prior[path] !== after[path]);
  }
  check('harness.sources-unchanged', Object.values(sourceChanges).every(paths => paths.length === 0), sourceChanges);
  check('harness.children-stopped', children.every(child => child.exited), children.map(child => ({ name: child.name, pid: child.child.pid, exited: child.exited })));
  const summary = { startedAt, finishedAt: new Date().toISOString(), evidenceRoot,
    qfliRevision: initial.qfliRevision, moderationRevision: initial.moderationRevision,
    checks: checks.length, passed: checks.filter(item => item.result === 'pass').length,
    failed: checks.filter(item => item.result === 'fail'), sourceChanges,
    childPids: children.map(child => ({ name: child.name, pid: child.child.pid, stopped: child.exited })) };
  await save('http-and-db.json', records); await save('checks.json', checks);
  await save('gateway.json', gatewayEvents); await save('processes.json', processes); await save('summary.json', summary);
  process.stdout.write(JSON.stringify(summary, null, 2) + '\n');
  process.exitCode = summary.failed.length ? 1 : 0;
}
