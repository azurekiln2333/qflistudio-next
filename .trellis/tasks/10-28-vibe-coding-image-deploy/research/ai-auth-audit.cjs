// Completion audit: actual AI router and authentication, disposable SQLite.
// No real credentials or upstream traffic are needed for rejected requests.
const assert = require('node:assert/strict');
const fs = require('node:fs');
const http = require('node:http');
const path = require('node:path');
const { createRequire } = require('node:module');

const workspace = path.resolve(__dirname, '../../../..');
assert.ok(fs.existsSync(path.join(workspace, 'azurekiln-qfli-server/package.json')));
const artifacts = path.join(workspace, '.artifacts');
fs.mkdirSync(artifacts, { recursive: true });
const data = fs.mkdtempSync(path.join(artifacts, 'ai-auth-audit-'));
process.env.DB_DRIVER = 'sqlite';
process.env.QFLI_DATA_DIR = data;
process.env.NODE_ENV = 'test';
process.env.QFLI_JWT_SECRET = 'qfli-ai-auth-audit-fixture-secret-2026';
process.env.QFLI_AI_BASE_URL = 'http://127.0.0.1:1';
process.env.QFLI_AI_API_KEY = 'audit-fixture-only';
process.env.QFLI_AI_MODEL = 'deepseek-v4.1-flash';

const fromServer = createRequire(path.join(workspace, 'azurekiln-qfli-server/package.json'));
const express = fromServer('express');
const db = fromServer('./src/db');
const { signToken } = fromServer('./src/util');
const router = fromServer('./src/routes/ai');
let upstreamCalls = 0;
globalThis.fetch = async () => {
  upstreamCalls += 1;
  throw new Error('audit_must_not_reach_upstream');
};

for (const layer of router.stack) {
  for (const handler of layer.route ? layer.route.stack : [layer]) {
    const original = handler.handle;
    if (original.length === 4) continue;
    handler.handle = (req, res, next) => {
      try { Promise.resolve(original(req, res, next)).catch(next); }
      catch (error) { next(error); }
    };
  }
}

function post(port, authorization) {
  return new Promise((resolve, reject) => {
    const request = http.request({
      hostname: '127.0.0.1', port, path: '/api/ai/chat', method: 'POST',
      headers: { 'content-type': 'application/json',
        ...(authorization ? { authorization } : {}) },
      signal: AbortSignal.timeout(5000),
    }, response => {
      response.resume();
      response.on('end', () => resolve(response.statusCode));
      response.on('error', reject);
    });
    request.on('error', reject);
    request.end(JSON.stringify({ messages: [{ role: 'user', content: 'fixture' }] }));
  });
}

async function main() {
  let server;
  try {
    await db.ready;
    const app = express();
    app.use(express.json());
    app.use('/api/ai', router);
    app.use((error, _req, res, _next) => {
      res.status(error.status || 500).json({ error: error.message });
    });
    server = await new Promise(resolve => {
      const value = app.listen(0, '127.0.0.1', () => resolve(value));
    });
    const signedWithoutSession = signToken({
      uid: `user_${'a'.repeat(32)}`, sid: 'unregistered-audit-session',
    });
    const statuses = [];
    for (const header of [undefined, 'Bearer invalid', `Bearer ${signedWithoutSession}`]) {
      statuses.push(await post(server.address().port, header));
    }
    assert.deepEqual(statuses, [401, 401, 401]);
    assert.equal(upstreamCalls, 0);
    console.log(JSON.stringify({
      checkedAt: new Date().toISOString(), realAuthMiddleware: true,
      cases: ['missing bearer', 'invalid JWT', 'signed JWT without persisted session'],
      statuses, upstreamCalls, passed: true,
    }));
  } finally {
    if (server) await new Promise((resolve, reject) => server.close(error => error ? reject(error) : resolve()));
    await db.close();
    assert.equal(path.dirname(path.resolve(data)), path.resolve(artifacts));
    assert.ok(path.basename(data).startsWith('ai-auth-audit-'));
    fs.rmSync(data, { recursive: true, force: true });
  }
}

main().catch(error => {
  console.error(JSON.stringify({ errorType: error.name, message: error.message }));
  process.exitCode = 1;
});
