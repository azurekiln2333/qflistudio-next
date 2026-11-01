// Loopback-only development fixture. Credentials are supplied through the
// ignored backend .env. This is not a deployable authentication substitute.
const http = require('node:http');
const path = require('node:path');
const fs = require('node:fs');
const crypto = require('node:crypto');

process.env.DB_DRIVER = 'sqlite';
process.env.QFLI_DATA_DIR = path.resolve('.artifacts/vibe-live-db');
process.env.QFLI_JWT_SECRET = 'vibe-live-fixture-session-secret-not-production';
process.env.QFLI_TERMINAL_NODES = '';
process.env.QFLI_TERMINAL_URL = 'http://127.0.0.1:3101';
const ai = require(path.resolve('azurekiln-qfli-server/src/ai-client'));
const terminal = require(path.resolve('azurekiln-qfli-server/src/terminal-client'));
const pool = require(path.resolve('azurekiln-qfli-server/src/terminal-pool'));
const db = require(path.resolve('azurekiln-qfli-server/src/db'));
const userId = `user_${'9'.repeat(32)}`;
const events = [];
const originalFetch = globalThis.fetch;
globalThis.fetch = async (...args) => {
  const response = await originalFetch(...args);
  if (String(args[0]).endsWith('/chat/completions')) {
    const data = await response.clone().json().catch(() => null);
    const message = data?.choices?.[0]?.message;
    events.push({ type: 'upstream_shape', status: response.status,
      messageKeys: message ? Object.keys(message) : [],
      contentType: typeof message?.content,
      callsType: message?.tool_calls === null ? 'null' : typeof message?.tool_calls,
      calls: Array.isArray(message?.tool_calls) ? message.tool_calls.map(call => ({
        keys: Object.keys(call), id: call.id, type: call.type,
        functionKeys: call.function ? Object.keys(call.function) : [],
        name: call.function?.name, argumentType: typeof call.function?.arguments,
      })) : undefined });
  }
  return response;
};

async function body(req) {
  const parts = [];
  let size = 0;
  for await (const chunk of req) {
    size += chunk.length;
    if (size > 600 * 1024) throw Object.assign(new Error('fixture_body_limit'), { status: 413 });
    parts.push(chunk);
  }
  return JSON.parse(Buffer.concat(parts).toString('utf8') || '{}');
}

function json(res, status, value) {
  if (res.destroyed || res.writableEnded) return;
  res.writeHead(status, { 'content-type': 'application/json' });
  res.end(JSON.stringify(value));
}

const server = http.createServer(async (req, res) => {
  const pathname = new URL(req.url, 'http://127.0.0.1').pathname;
  req.userId = userId;
  req.requestId = crypto.randomUUID();
  res.status = status => { res.statusCode = status; return res; };
  res.set = headers => { for (const [key, value] of Object.entries(headers)) res.setHeader(key, value); return res; };
  try {
    if (pathname === '/__health') return json(res, 200, { fixture: true });
    if (req.headers.authorization !== 'Bearer qfli-live-fixture') return json(res, 401, { error: 'fixture_auth_required' });
    if (pathname === '/__evidence') return json(res, 200, events);
    if (pathname === '/__shutdown' && req.method === 'POST') {
      json(res, 200, { stopping: true });
      server.close();
      server.closeIdleConnections();
      return;
    }
    if (pathname === '/api/ai/chat' && req.method === 'POST') {
      const result = await ai.chat(await body(req), { req, res });
      events.push({ type: 'model', model: result.model, tools: result.message.tool_calls?.map(call => call.function.name) || [] });
      return json(res, 200, result);
    }
    if (pathname === '/api/terminal/exec/stream' && req.method === 'POST') {
      const value = terminal.validateRequest(await body(req));
      const result = await pool.executeStream(value, req, res);
      if (result) events.push({ type: 'command', command: value.command, exitCode: result.exitCode, stdout: result.stdout, stderr: result.stderr });
      if (!res.destroyed) res.end();
      return;
    }
    if (pathname === '/api/terminal/session' && req.method === 'DELETE') {
      await pool.reset(req, res);
      return json(res, 200, { ok: true });
    }
    json(res, 404, { error: 'fixture_not_found' });
  } catch (error) {
    events.push({ type: 'error', status: error.status || 500, message: error.message });
    if (res.headersSent) {
      if (!res.destroyed) res.end(`${JSON.stringify({ type: 'error', status: error.status || 500, message: error.message })}\n`);
    } else json(res, error.status || 500, { error: error.message });
  }
});

db.ready.then(() => server.listen(0, '127.0.0.1', () => {
  const origin = `http://127.0.0.1:${server.address().port}`;
  fs.mkdirSync('.artifacts', { recursive: true });
  fs.writeFileSync('.artifacts/vibe-live-origin.json', JSON.stringify({ origin, pid: process.pid }));
  console.log(JSON.stringify({ origin, pid: process.pid, fixture: true }));
})).catch(error => { console.error(JSON.stringify({ errorType: error.name, message: error.message })); process.exitCode = 1; });
