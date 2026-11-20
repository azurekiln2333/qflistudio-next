// Real end-to-end smoke test: starts the agent with --local-relay (real Agent
// SDK, real `claude`), pairs with the one-time code printed in its banner,
// runs a prompt that needs a Bash permission, approves it from "the phone"
// and waits for the result. Uses a few cents of Claude usage.
//
//   npm run e2e
//   npm run e2e -- --prompt "..." --port 8799
//   npm run e2e -- --demo --timeout 60  (scripted provider; no paid usage)

import { spawn } from 'node:child_process';
import { mkdtemp, rm, writeFile } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import path from 'node:path';
import { parseArgs } from 'node:util';
import { WebSocket } from 'ws';
import type { AgentMessage, ClientMessage, RelayFrame } from '../src/shared/protocol.ts';

type Frame = Exclude<RelayFrame, { t: 'msg' }> | { t: 'msg'; data: AgentMessage };

const { values } = parseArgs({
  options: {
    port: { type: 'string', default: '8799' },
    prompt: {
      type: 'string',
      default: 'Run the shell command `node --version` with your shell tool, then tell me the version in one short sentence.',
    },
    timeout: { type: 'string', default: '180' },
    demo: { type: 'boolean', default: false },
  },
});

const home = await mkdtemp(path.join(tmpdir(), 'ct-e2e-home-'));
const work = await mkdtemp(path.join(tmpdir(), 'ct-e2e-work-'));
await writeFile(path.join(work, 'README.md'), '# e2e\n');
const url = `ws://127.0.0.1:${values.port}/ws`;

const agent = spawn(
  process.execPath,
  values.demo
    ? [path.join(import.meta.dirname, 'demo-agent.ts'), '--fast', '--port', values.port!, '--root', work]
    : [path.join(import.meta.dirname, '../src/agent/main.ts'), '--local-relay', '--port', values.port!, '--root', work, '--cwd', work, '--name', 'e2e'],
  { env: { ...process.env, CLOUDTERMINAL_HOME: home }, stdio: ['ignore', 'pipe', 'pipe'] },
);

let finishing = false;
const sockets = new Set<WebSocket>();
const deadline = setTimeout(() => finish('timed out'), Number(values.timeout) * 1000);

function finish(error?: string): void {
  if (finishing) return;
  finishing = true;
  clearTimeout(deadline);
  if (error) {
    console.error(`\n✗ E2E FAILED: ${error}`);
  } else {
    console.log('\n✓ E2E PASSED');
  }
  for (const socket of sockets) socket.terminate();
  void (async () => {
    if (agent.exitCode === null && agent.signalCode === null) {
      await new Promise<void>((resolve) => {
        const force = setTimeout(() => {
          agent.kill('SIGKILL');
          resolve();
        }, 5000);
        agent.once('close', () => {
          clearTimeout(force);
          resolve();
        });
        agent.kill();
      });
    }
    await Promise.all([
      rm(home, { recursive: true, force: true, maxRetries: 5, retryDelay: 200 }),
      rm(work, { recursive: true, force: true, maxRetries: 5, retryDelay: 200 }),
    ]);
  })().then(
    () => process.exit(error ? 1 : 0),
    (cleanupError: unknown) => {
      console.error('E2E cleanup failed:', cleanupError);
      process.exit(1);
    },
  );
}

agent.stderr.on('data', (d) => process.stderr.write(`[agent] ${d}`));
agent.once('error', (error) => finish(`agent could not start: ${error.message}`));
agent.once('exit', (code, signal) => {
  if (!finishing) finish(`agent exited before completion (code=${code}, signal=${signal})`);
});
const ready = new Promise<string>((resolve) => {
  let buf = '';
  agent.stdout.on('data', (d: Buffer) => {
    const text = d.toString();
    buf += text;
    const m = /(?:配对码：\s+|pairCode=)([A-Z0-9]{4}-[A-Z0-9]{4})/.exec(buf);
    if (m) resolve(m[1]!);
  });
});

function once(ws: WebSocket, pred: (f: Frame) => boolean): Promise<Frame> {
  return new Promise((resolve) => {
    const h = (raw: Buffer) => {
      const f = JSON.parse(raw.toString()) as Frame;
      if (pred(f)) {
        ws.off('message', h);
        resolve(f);
      }
    };
    ws.on('message', h);
  });
}

async function connect(): Promise<WebSocket> {
  const ws = new WebSocket(url);
  sockets.add(ws);
  ws.on('error', (error) => finish(`websocket error: ${error.message}`));
  await new Promise<void>((resolve) => ws.once('open', resolve));
  return ws;
}

async function run(): Promise<void> {
  const code = await ready;
  console.log(`→ pairing (${values.demo ? 'scripted provider' : 'live Claude'})`);
  const pairWs = await connect();
  const pairing = once(pairWs, () => true);
  pairWs.send(JSON.stringify({ t: 'hello', role: 'pair', code }));
  const paired = await pairing;
  if (paired.t !== 'paired') throw new Error(`pairing failed: ${paired.t}`);
  console.log(`→ paired with agent ${paired.agentId}`);

  const ws = await connect();
  const hello = once(ws, (f) => f.t === 'hello_ok' || f.t === 'error');
  ws.send(JSON.stringify({ t: 'hello', role: 'client', agentId: paired.agentId, secret: paired.secret }));
  const connected = await hello;
  if (connected.t !== 'hello_ok' || connected.online !== true) throw new Error('agent is not online');
  const send = (data: ClientMessage) => ws.send(JSON.stringify({ t: 'msg', data }));
  const request = async (data: ClientMessage & { id: string }): Promise<AgentMessage> => {
    const response = once(ws, (f) => f.t === 'msg' && 'id' in f.data && f.data.id === data.id);
    send(data);
    const frame = await response;
    if (frame.t !== 'msg') throw new Error('expected an agent response');
    if (frame.data.kind === 'error') throw new Error(frame.data.message);
    return frame.data;
  };

  const info = await request({ id: 'info', type: 'info' });
  if (info.kind !== 'info' || info.defaultCwd !== work) throw new Error('agent info has the wrong workspace');

  // Subscribe before sending the prompt so even the fast demo cannot outrun
  // the listener. The real provider uses the same permission handling below.
  const created = await request({ id: 'create', type: 'create_session', cwd: work, mode: 'default' });
  if (created.kind !== 'session_created') throw new Error('session creation failed');
  const sessionId = created.session.id;
  let sawPermission = false;
  let sawQuestion = false;
  let sawQuestionAnswer = false;
  let sawToolResult = false;
  let deltas = 0;
  const answerMarker = 'CI_E2E_ANSWER';
  ws.on('message', (raw) => {
    if (finishing) return;
    const frame = JSON.parse(raw.toString()) as Frame;
    if (frame.t === 'error') return finish(frame.message);
    if (frame.t !== 'msg') return;
    const data = frame.data;
    if (data.kind === 'delta' && data.sessionId === sessionId) {
      deltas++;
      return;
    }
    const events = (data.kind === 'events' || data.kind === 'event') && data.sessionId === sessionId
      ? data.kind === 'events' ? data.events : [data.event]
      : [];
    for (const event of events) {
      console.log(`  #${event.seq} ${event.kind}`);
      if (event.kind === 'permission_request') {
        sawPermission = true;
        const answers: Record<string, string> = {};
        for (const question of event.questions ?? []) answers[question.question] = answerMarker;
        if (Object.keys(answers).length > 0) sawQuestion = true;
        send({ id: `perm-${event.requestId}`, type: 'permission', sessionId, requestId: event.requestId, decision: 'allow', answers });
      }
      if (event.kind === 'assistant' && event.text.includes(answerMarker)) sawQuestionAnswer = true;
      if (event.kind === 'tool_result') {
        if (event.isError) return finish('tool result was an error');
        sawToolResult = true;
      }
      if (event.kind === 'result') {
        if (event.isError) return finish('result was an error');
        if (!sawPermission) return finish('no permission request reached the client');
        if (!sawToolResult) return finish('no tool result seen');
        if (deltas === 0) return finish('no streamed deltas seen');
        if (values.demo && (!sawQuestion || !sawQuestionAnswer)) return finish('question answer did not complete the round trip');
        console.log(`→ verified result, ${deltas} deltas and permission responses`);
        return finish();
      }
      if (event.kind === 'error') return finish(event.text);
    }
    if (data.kind === 'error') finish(data.message);
  });
  const subscribed = await request({ id: 'sub', type: 'subscribe', sessionId });
  if (subscribed.kind !== 'events') throw new Error('subscription failed');
  send({ id: 'prompt', type: 'send', sessionId, text: values.prompt! });
}

void run().catch((error: unknown) => finish(error instanceof Error ? error.message : String(error)));
