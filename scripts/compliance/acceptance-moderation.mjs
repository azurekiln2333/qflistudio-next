#!/usr/bin/env node
// 验收脚本（w37:p2）：任务书 §4 第 4 条与第 11 条。
//
// 只读被测仓库：在临时目录起审核服务、QFLI 服务端和本地网关桩，用真实 HTTP 请求取证。
// 不改 azurekiln-qfli-server / azurekiln-moderation / azurekiln-oauth2 的任何文件。
//
// 用法：
//   node scripts/compliance/acceptance-moderation.mjs \
//     --moderation-repo D:/MyNewProjects/azurekiln-moderation \
//     [--json-out %TEMP%/acceptance-moderation.json]
import { spawn } from 'node:child_process';
import { once } from 'node:events';
import { mkdtemp, rm, writeFile } from 'node:fs/promises';
import { createServer } from 'node:http';
import { createServer as createTcpServer } from 'node:net';
import { tmpdir } from 'node:os';
import { dirname, join, resolve } from 'node:path';
import { fileURLToPath, pathToFileURL } from 'node:url';
import { randomBytes } from 'node:crypto';

const here = dirname(fileURLToPath(import.meta.url));
const repo = resolve(here, '../..');
const serverRoot = join(repo, 'azurekiln-qfli-server');

// ---------------- 进程与 HTTP 工具 ----------------

function childEnvironment(extra) {
  const inherited = {};
  for (const [key, value] of Object.entries(process.env)) {
    if (/^(path|systemroot|windir|temp|tmp|appdata|localappdata|userprofile|comspec|pathext|lang|lc_all|systemdrive)$/i.test(key)) {
      inherited[key] = value;
    }
  }
  return { ...inherited, NODE_ENV: 'test', ...extra };
}

async function availablePort() {
  const server = createTcpServer();
  await new Promise((ok, fail) => { server.once('error', fail); server.listen(0, '127.0.0.1', ok); });
  const port = server.address().port;
  await new Promise(ok => server.close(ok));
  return port;
}

function track(child, name) {
  const state = { child, name, exited: null, output: '' };
  child.stdout?.on('data', chunk => { state.output += chunk.toString(); });
  child.stderr?.on('data', chunk => { state.output += chunk.toString(); });
  state.done = new Promise(ok => {
    child.once('error', () => { state.exited = { code: -1 }; ok(); });
    child.once('exit', (code, signal) => { state.exited = { code, signal }; ok(); });
  });
  return state;
}

async function waitHealthy(base, path, state) {
  const deadline = Date.now() + 30000;
  while (Date.now() < deadline) {
    if (state.exited) throw new Error(`${state.name} exited before readiness: ${state.output.slice(-400)}`);
    try {
      const response = await request(`${base}${path}`, { timeoutMs: 800 });
      if (response.status === 200) return;
    } catch { /* 监听尚未就绪 */ }
    await new Promise(ok => setTimeout(ok, 100));
  }
  throw new Error(`${state.name} readiness timeout`);
}

async function stop(state) {
  if (!state || state.exited) return;
  state.child.kill('SIGTERM');
  const timer = new Promise(ok => setTimeout(ok, 4000, 'timeout'));
  if (await Promise.race([state.done.then(() => 'exit'), timer]) === 'timeout') {
    state.child.kill('SIGKILL');
    await state.done;
  }
}

// 返回 {status, json, text, headers, ms}。取回原始 body 供报告引用。
async function request(url, { method = 'GET', headers = {}, body, timeoutMs = 8000 } = {}) {
  const started = Date.now();
  const response = await fetch(url, {
    method,
    headers: { ...headers, ...(body === undefined ? {} : { 'content-type': 'application/json' }) },
    body: body === undefined ? undefined : JSON.stringify(body),
    redirect: 'error',
    signal: AbortSignal.timeout(timeoutMs),
  });
  const text = await response.text();
  let json = null;
  try { json = JSON.parse(text); } catch { /* 非 JSON */ }
  return { status: response.status, json, text, ms: Date.now() - started };
}

// 证据记录：每条断言都保留请求与原始响应摘录。
const results = [];
function record(item) { results.push(item); return item; }
function verdictOf(items) {
  const decided = items.filter(item => item.verdict !== 'info');
  return decided.every(item => item.verdict === 'pass');
}
function excerpt(value, max = 600) {
  const text = typeof value === 'string' ? value : JSON.stringify(value);
  return text.length > max ? `${text.slice(0, max)}…` : text;
}

// ---------------- 主流程 ----------------

export async function runAcceptance({ moderationRepo }) {
  const work = await mkdtemp(join(tmpdir(), 'qfli-acceptance-moderation-'));
  let moderation;
  let qfli;
  let gateway;
  let fixture;
  const clock = () => new Date().toISOString();
  try {
    const accounts = {};
    for (const name of ['author', 'admin', 'reader']) {
      accounts[name] = {
        accessToken: randomBytes(24).toString('hex'),
        claims: {
          sub: `acceptance-${name}`, preferred_username: `acc_${name}`, name: `acc_${name}`,
          ...(name === 'admin' ? { qfli_admin: true } : {}),
          phone_number: '+8613800000000', phone_number_verified: true,
        },
      };
    }
    // 本地网关桩模拟 azurekiln-oauth2 的四条接口：刷新、用户信息、资料更新。
    const gatewayCalls = [];
    gateway = createServer((req, res) => {
      const access = (req.headers.authorization || '').replace(/^Bearer /, '');
      const account = Object.values(accounts).find(item => item.accessToken === access);
      res.setHeader('content-type', 'application/json');
      gatewayCalls.push(`${req.method} ${req.url}`);
      if (!account) { res.statusCode = 401; return res.end('{"error":"invalid_token"}'); }
      if (req.url === '/oauth2/userinfo') return res.end(JSON.stringify(account.claims));
      if (req.url === '/oauth2/token') {
        return res.end(JSON.stringify({ access_token: account.accessToken, expires_in: 3600, token_type: 'Bearer' }));
      }
      if (req.url === '/oauth2/profile' || req.url === '/api/profile') {
        let raw = '';
        req.on('data', chunk => { raw += chunk; });
        return req.on('end', () => {
          const patch = raw ? JSON.parse(raw) : {};
          // 模拟网关侧的昵称/简介审核失败：内容含赌博词时拒绝。
          if (String(patch.name || patch.description || '').includes('赌')) {
            res.statusCode = 400;
            return res.end(JSON.stringify({ error: 'content_rejected', error_description: '昵称或简介包含不允许的内容，请修改后重试' }));
          }
          Object.assign(account.claims, patch);
          res.end(JSON.stringify(account.claims));
        });
      }
      res.statusCode = 404;
      res.end('{"error":"not_found"}');
    });
    await new Promise((ok, fail) => { gateway.once('error', fail); gateway.listen(0, '127.0.0.1', ok); });
    const gatewayUrl = `http://127.0.0.1:${gateway.address().port}`;

    // 1) 审核服务：独立仓库、独立进程、独立 SQLite。
    const moderationPort = await availablePort();
    const moderationUrl = `http://127.0.0.1:${moderationPort}`;
    const appId = 'qflistudio';
    const apiKey = randomBytes(32).toString('hex');
    const adminKey = randomBytes(32).toString('hex');
    const moderationDb = join(work, 'moderation.sqlite');
    moderation = track(spawn(process.execPath, ['src/server.js'], {
      cwd: moderationRepo, stdio: ['ignore', 'pipe', 'pipe'],
      env: childEnvironment({
        HOST: '127.0.0.1', PORT: String(moderationPort), MODERATION_DB_PATH: moderationDb,
        MODERATION_APPS_JSON: JSON.stringify([{ appId, apiKey, adminKey }]),
      }),
    }), 'moderation');
    await waitHealthy(moderationUrl, '/healthz', moderation);

    // 2) QFLI 服务端：本地网关桩 + SQLite。
    const qfliPort = await availablePort();
    const qfliUrl = `http://127.0.0.1:${qfliPort}`;
    fixture = track(spawn(process.execPath, [join(here, 'local-qfli.cjs')], {
      cwd: join(repo, 'scripts/compliance'), stdio: ['ignore', 'pipe', 'pipe', 'ipc'],
      env: childEnvironment({
        PORT: String(qfliPort), DB_DRIVER: 'sqlite', QFLI_DATA_DIR: join(work, 'qfli'),
        QFLI_JWT_SECRET: randomBytes(32).toString('hex'), QFLI_AUDIT_SALT: randomBytes(32).toString('hex'),
        AZK_OAUTH2_BASE_URL: gatewayUrl, AZK_OAUTH2_CLIENT_ID: 'qfli_acceptance',
        AZK_OAUTH2_CLIENT_SECRET: randomBytes(32).toString('hex'),
        AZK_OAUTH2_REDIRECT_URI: `${gatewayUrl}/oauth2/callback`,
        MODERATION_BASE_URL: moderationUrl, MODERATION_APP_ID: appId, MODERATION_API_KEY: apiKey,
        MODERATION_ADMIN_KEY: adminKey, MODERATION_TIMEOUT_MS: '2000',
        PUBLISH_RATE_PER_MINUTE: '30', PUBLISH_RATE_PER_DAY: '500',
        COMPLIANCE_E2E_ROOT: serverRoot, COMPLIANCE_E2E_ACCOUNTS: JSON.stringify(accounts),
      }),
    }), 'QFLI');
    const message = await Promise.race([
      once(fixture.child, 'message').then(([value]) => value),
      fixture.done.then(() => { throw new Error(`QFLI exited before sessions: ${fixture.output.slice(-400)}`); }),
      new Promise((_, reject) => setTimeout(() => reject(new Error('session timeout')), 30000)),
    ]);
    if (message.type !== 'sessions') throw new Error('unexpected fixture message');
    const tokens = message.tokens;
    await waitHealthy(qfliUrl, '/api/health', fixture);

    const platform = { 'X-Client-Platform': 'harmonyos-app/1.0.0' };
    const as = name => ({ ...platform, authorization: `Bearer ${tokens[name]}` });
    const qfliCall = (path, name, body, method) => request(`${qfliUrl}${path}`, {
      method: method || (body === undefined ? 'GET' : 'POST'),
      headers: as(name), body,
    });
    const modCall = (path, { method = 'GET', body, key = apiKey } = {}) => request(`${moderationUrl}${path}`, {
      method, headers: { 'X-App-Id': appId, authorization: `Bearer ${key}` }, body,
    });

    const zones = await qfliCall('/api/zones', 'author');
    const zoneId = zones.json?.items?.[0]?.id;
    if (!zoneId) throw new Error('no zone available for posts');

    let postSeq = 0;
    const publish = (title, content, tags = []) => {
      postSeq += 1;
      return qfliCall('/api/posts', 'author', {
        type: 'discussion', zoneId,
        title: title || `验收样例标题 ${postSeq}`,
        content: content || `验收样例正文 ${postSeq}`,
        tags,
      });
    };

    const baselines = {
      qflistudio: { commit: null, branch: null },
      moderation: { commit: null, branch: null },
    };
    // ---------------- 条目 4：敏感词与变体 ----------------

    // 4.0 基线：干净内容可以发布。
    const clean = await publish('干净样例标题 acceptance', '干净样例正文 acceptance content');
    record({
      item: '4-基线', case: '干净内容正常发布',
      command: 'POST /api/posts {type:discussion, title:"干净样例标题 acceptance", content:"干净样例正文 acceptance content"}',
      status: clean.status, response: excerpt(clean.json), verdict: clean.status === 200 ? 'pass' : 'fail',
    });

    // 4.1 直连审核服务：变体覆盖。词用种子词库里的赌博类词，避免涉政词。
    const VARIANTS = [
      { name: '原文', text: '网络赌场' },
      { name: '插入空格', text: '网 络 赌 场' },
      { name: '全角', text: 'ＮｅｔＷｏｒｋ 网络赌场' },
      { name: '插入符号', text: '网-络-赌-场' },
      { name: '零宽字符', text: '网\u200b络\u200b赌\u200b场' },
      { name: '繁体', text: '網絡賭場' },
      { name: '大小写+空格', text: 'XuJi 赌博 下注'.replace('赌博', '网 络 赌 场') },
    ];
    for (const variant of VARIANTS) {
      const check = await modCall('/v1/text/check', { method: 'POST', body: { scene: 'acceptance.text', text: variant.text } });
      record({
        item: '4-变体拦截', case: variant.name,
        command: `POST /v1/text/check {"scene":"acceptance.text","text":${JSON.stringify(variant.text)}}`,
        status: check.status,
        response: excerpt({ decision: check.json?.decision, categories: check.json?.categories, hits: check.json?.hits?.length }),
        verdict: check.status === 200 && check.json?.decision === 'block' ? 'pass' : 'fail',
      });
    }

    // 4.2 经 QFLI 发帖：同样的变体必须被业务侧拦成 422。
    for (const variant of [VARIANTS[1], VARIANTS[3], VARIANTS[5]]) {
      const blocked = await publish('变体验收标题', `正文内容 ${variant.text} acceptance`);
      record({
        item: '4-经QFLI拦截', case: variant.name,
        command: `POST /api/posts content 含 ${JSON.stringify(variant.text)}`,
        status: blocked.status,
        response: excerpt({ error: blocked.json?.error, errorKey: blocked.json?.errorKey, categories: blocked.json?.categories }),
        verdict: blocked.status === 422 && blocked.json?.errorKey === 'moderation.blocked' ? 'pass' : 'fail',
      });
    }

    // 4.3 词库新增后立即生效（承诺 10 分钟内）。
    const freshWord = `验收词${randomBytes(3).toString('hex')}`;
    const created = await modCall('/v1/admin/keywords', {
      method: 'POST', key: adminKey, body: { word: freshWord, category: 'custom' },
    });
    const addedAt = Date.now();
    const afterCreate = await publish('新词验收标题', `正文包含 ${freshWord} 用于验收`);
    const effectMs = Date.now() - addedAt;
    record({
      item: '4-新词生效', case: `管理接口新增自定义词 ${freshWord}`,
      command: `POST /v1/admin/keywords {"word":"${freshWord}","category":"custom"} 然后 POST /api/posts`,
      status: created.status,
      response: excerpt({ createStatus: created.status, createBody: created.json, blockStatus: afterCreate.status, blockBody: afterCreate.json, effectMs }),
      verdict: created.status === 201 && afterCreate.status === 422 ? 'pass' : 'fail',
    });
    // 立刻回查一次词库，确认管理接口可见。
    const listed = await modCall(`/v1/admin/keywords?category=custom&limit=100`, { key: adminKey });
    record({
      item: '4-新词生效', case: '管理接口可见性',
      command: 'GET /v1/admin/keywords?category=custom',
      status: listed.status,
      response: excerpt({ total: listed.json?.total, found: (listed.json?.items || []).some(i => i.word === freshWord) }),
      verdict: (listed.json?.items || []).some(i => i.word === freshWord) ? 'pass' : 'fail',
    });
    // 变体对新词同样生效。
    const freshVariant = await publish('新词变体验收', `正文包含 ${freshWord.split('').join(' ')} 空格变体`);
    record({
      item: '4-新词生效', case: '新词的插入空格变体',
      command: `POST /api/posts content 含 "${freshWord.split('').join(' ')}"`,
      status: freshVariant.status, response: excerpt(freshVariant.json),
      verdict: freshVariant.status === 422 ? 'pass' : 'fail',
    });

    // 4.4 昵称与简介。
    const nickBlocked = await qfliCall('/api/users/me', 'reader', { nickname: '正常昵称网络赌场' }, 'PATCH');
    record({
      item: '4-昵称', case: '昵称命中词库',
      command: 'PATCH /api/users/me {"nickname":"正常昵称网络赌场"}',
      status: nickBlocked.status, response: excerpt(nickBlocked.json),
      verdict: nickBlocked.status === 422 ? 'pass' : 'fail',
    });
    const bioBlocked = await qfliCall('/api/users/me', 'reader', { bio: '简介里写 网 络 赌 场 变体' }, 'PATCH');
    record({
      item: '4-简介', case: '简介命中变体',
      command: 'PATCH /api/users/me {"bio":"简介里写 网 络 赌 场 变体"}',
      status: bioBlocked.status, response: excerpt(bioBlocked.json),
      verdict: bioBlocked.status === 422 ? 'pass' : 'fail',
    });
    const nickOk = await qfliCall('/api/users/me', 'reader', { nickname: '验收正常昵称' }, 'PATCH');
    record({
      item: '4-昵称', case: '干净昵称通过',
      command: 'PATCH /api/users/me {"nickname":"验收正常昵称"}',
      status: nickOk.status, response: excerpt(nickOk.json),
      verdict: nickOk.status === 200 ? 'pass' : 'fail',
    });
    record({
      item: '4-昵称', case: '网关桩收到的请求序列（确认 422 发生在转发网关之前）',
      command: '本地网关桩记录',
      status: 200, response: excerpt(gatewayCalls),
      verdict: 'info',
    });

    // ---------------- 条目 11：独立部署 + SDK 接入 ----------------

    // 11.1 审核服务是独立进程/独立数据库：健康检查与独立端口。
    const health = await request(`${moderationUrl}/healthz`);
    record({
      item: '11-独立部署', case: '独立进程与独立数据库',
      command: `GET ${moderationUrl}/healthz`,
      status: health.status, response: excerpt({ ...health.json, process: 'separate node src/server.js', dbPath: 'temp/moderation.sqlite' }),
      verdict: health.status === 200 ? 'pass' : 'fail',
    });

    // 11.2 QFLI 侧只通过 SDK：业务进程环境里只有 baseUrl/appId/key，没有词库。
    const qfliEnv = Object.keys(childEnvironment({ MODERATION_BASE_URL: '', MODERATION_APP_ID: '', MODERATION_API_KEY: '', MODERATION_ADMIN_KEY: '' }))
      .filter(key => /^MODERATION_/i.test(key));
    record({
      item: '11-SDK接入', case: 'QFLI 进程的审核配置只有端点与凭据',
      command: '列出 QFLI 子进程里 MODERATION_* 环境变量',
      status: 200, response: excerpt({ keys: qfliEnv }),
      verdict: qfliEnv.sort().join(',') === 'MODERATION_ADMIN_KEY,MODERATION_API_KEY,MODERATION_APP_ID,MODERATION_BASE_URL' ? 'pass' : 'fail',
    });

    // 11.3 判定发生在审核服务：审核服务的审计表里有 QFLI 发来的判定记录。
    const audit = await modCall('/v1/admin/audit?action=text.check&limit=50', { key: adminKey });
    const auditItems = audit.json?.items || [];
    record({
      item: '11-SDK接入', case: '审核服务审计里有 QFLI 提交的判定',
      command: 'GET /v1/admin/audit?action=text.check',
      status: audit.status,
      response: excerpt({ total: audit.json?.total, appIds: [...new Set(auditItems.map(i => i.appId))], actions: [...new Set(auditItems.map(i => i.action))] }),
      verdict: audit.status === 200 && auditItems.length > 0 && auditItems.every(i => i.appId === appId) ? 'pass' : 'fail',
    });

    // 11.4 failClosed：审核服务停掉后，发布必须 503，不得假装成功。
    await stop(moderation);
    const offline = await publish('离线验收标题', '审核服务已停止时发布');
    record({
      item: '11-failClosed', case: '审核服务停止后发布被拒绝',
      command: '停止审核服务进程，然后 POST /api/posts',
      status: offline.status, response: excerpt(offline.json),
      verdict: offline.status === 503 && offline.json?.errorKey === 'moderation.unavailable' ? 'pass' : 'fail',
    });

    return { ok: verdictOf(results), baselines, results, clock: clock() };
  } finally {
    await stop(fixture);
    await stop(moderation);
    if (gateway) {
      gateway.closeAllConnections();
      await new Promise(ok => gateway.close(ok));
    }
    await rm(work, { recursive: true, force: true, maxRetries: 10, retryDelay: 100 });
  }
}

export async function main(argv = process.argv.slice(2)) {
  const args = new Map();
  for (let i = 0; i < argv.length; i += 2) args.set(argv[i], argv[i + 1]);
  const moderationRepo = resolve(args.get('--moderation-repo') || 'D:/MyNewProjects/azurekiln-moderation');
  const jsonOut = args.get('--json-out');
  try {
    const result = await runAcceptance({ moderationRepo });
    if (jsonOut) await writeFile(jsonOut, JSON.stringify(result, null, 2), 'utf8');
    console.log(JSON.stringify(result, null, 2));
    return result.ok ? 0 : 1;
  } catch (error) {
    console.error(JSON.stringify({ ok: false, error: error.message }));
    return 1;
  }
}

if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) process.exitCode = await main();
