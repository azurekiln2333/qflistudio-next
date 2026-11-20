// Runs against both the source checkout and the packaged production runtime.
// Each run uses an empty home/cwd and never starts a paid tool session.
import assert from 'node:assert/strict';
import { spawn } from 'node:child_process';
import { once } from 'node:events';
import { mkdtemp, mkdir, rm } from 'node:fs/promises';
import { connect, createServer, type Socket } from 'node:net';
import { tmpdir } from 'node:os';
import path from 'node:path';
import { createInterface } from 'node:readline';
import { fileURLToPath } from 'node:url';
import { WebSocket } from 'ws';

type Frame = Record<string, unknown>;
const entry = fileURLToPath(new URL('../src/agent/main.ts', import.meta.url));

export async function temporarySidecarHome(): Promise<string> {
  const home = await mkdtemp(path.join(tmpdir(), 'qfli-sidecar-'));
  await mkdir(path.join(home, 'cwd'));
  return home;
}

export async function unusedPort(): Promise<number> {
  const server = createServer();
  await new Promise<void>((resolve, reject) => {
    server.once('error', reject);
    server.listen(0, '127.0.0.1', resolve);
  });
  const address = server.address();
  assert.ok(address && typeof address !== 'string');
  await new Promise<void>((resolve, reject) => server.close((error) => error ? reject(error) : resolve()));
  return address.port;
}

export async function waitForFrame(
  frames: Frame[], predicate: (frame: Frame) => boolean,
  failure: () => string | undefined = () => undefined,
): Promise<Frame> {
  const deadline = Date.now() + 25_000;
  while (Date.now() < deadline) {
    const frame = frames.find(predicate);
    if (frame) return frame;
    const error = failure();
    if (error) throw new Error(error);
    await new Promise((resolve) => setTimeout(resolve, 25));
  }
  throw new Error(`Timed out waiting for a frame (${frames.map((frame) => frame.type ?? frame.t).join(', ')})`);
}

export async function startSidecar(home: string, args: string[] = []) {
  const env: NodeJS.ProcessEnv = { ...process.env, CLOUDTERMINAL_HOME: path.join(home, 'config') };
  delete env.CLOUDTERMINAL_RELAY;
  delete env.CLOUDTERMINAL_RELAY_KEY;
  delete env.CLOUDTERMINAL_BOOTSTRAP;
  const child = spawn(process.execPath, [entry, '--sidecar', '--no-herdr', ...args], {
    cwd: path.join(home, 'cwd'), env, shell: false, stdio: ['ignore', 'pipe', 'pipe'],
  });
  const frames: Frame[] = [];
  let stderr = '';
  let processError: string | undefined;
  let socket: Socket | undefined;
  child.stderr.setEncoding('utf8');
  child.stderr.on('data', (text: string) => { stderr = (stderr + text).slice(-8000); });
  child.on('error', (error) => { processError = error.message; });
  const output = createInterface({ input: child.stdout });
  output.on('line', (line) => {
    try { frames.push(JSON.parse(line) as Frame); } catch { /* diagnostics */ }
  });
  const failure = () => processError ??
    (child.exitCode !== null || child.signalCode !== null ? `Sidecar exited: ${stderr}` : undefined);
  async function stop() {
    socket?.destroy();
    output.close();
    if (child.exitCode === null && child.signalCode === null) {
      const exited = once(child, 'exit');
      child.kill();
      const force = setTimeout(() => child.kill('SIGKILL'), 5000);
      try { await exited; } finally { clearTimeout(force); }
    }
  }
  try {
    const ready = await waitForFrame(frames, (frame) => frame.type === 'listening', failure);
    assert.equal(typeof ready.port, 'number');
    socket = connect(Number(ready.port), '127.0.0.1');
    socket.on('error', (error) => { processError = error.message; });
    const input = createInterface({ input: socket });
    input.on('line', (line) => {
      try { frames.push(JSON.parse(line) as Frame); } catch { /* diagnostics */ }
    });
    await once(socket, 'connect');
    return {
      wait: (predicate: (frame: Frame) => boolean) => waitForFrame(frames, predicate, failure),
      send: (frame: Frame) => socket!.write(`${JSON.stringify(frame)}\n`),
      stop,
    };
  } catch (error) {
    await stop();
    throw error;
  }
}

async function phoneSocket(url: string) {
  const socket = new WebSocket(url);
  const frames: Frame[] = [];
  let failure: string | undefined;
  socket.on('error', (error) => { failure = error.message; });
  socket.on('close', () => { failure ??= 'Phone socket closed'; });
  socket.on('message', (data) => frames.push(JSON.parse(data.toString()) as Frame));
  try { await once(socket, 'open'); } catch (error) { socket.terminate(); throw error; }
  return {
    send: (frame: Frame) => socket.send(JSON.stringify(frame)),
    wait: (predicate: (frame: Frame) => boolean) => waitForFrame(frames, predicate, () => failure),
    close: () => socket.terminate(),
  };
}

export async function verifyPhoneRoundTrip(sidecar: Awaited<ReturnType<typeof startSidecar>>, cwd: string) {
  const snapshot = await sidecar.wait((frame) => frame.type === 'snapshot' && frame.relayOnline === true);
  assert.equal(snapshot.connectionMode, 'local');
  const pairCode = await sidecar.wait((frame) => frame.type === 'pair_code');
  const uri = new URL(String(pairCode.uri));
  const advertisedRelay = new URL(uri.searchParams.get('relay') ?? '');
  assert.equal(advertisedRelay.toString(), snapshot.relayUrl);
  assert.ok(!['localhost', '127.0.0.1', '0.0.0.0', '[::1]'].includes(advertisedRelay.hostname),
    'A phone must receive a LAN address, not loopback');
  // Validate the advertised address but connect over loopback, so a runner
  // firewall cannot turn this protocol regression into a network test.
  advertisedRelay.hostname = '127.0.0.1';
  const pair = await phoneSocket(advertisedRelay.toString());
  let credentials: Frame;
  try {
    pair.send({ t: 'hello', role: 'pair', code: uri.searchParams.get('code'), v: 1 });
    credentials = await pair.wait((frame) => frame.t === 'paired');
  } finally { pair.close(); }
  const phone = await phoneSocket(advertisedRelay.toString());
  try {
    phone.send({ t: 'hello', role: 'client', agentId: credentials.agentId, secret: credentials.secret, v: 1 });
    const hello = await phone.wait((frame) => frame.t === 'hello_ok');
    assert.equal(hello.online, true);
    phone.send({ t: 'msg', data: { type: 'info', id: 'fresh-install-info' } });
    const info = await phone.wait((frame) => frame.t === 'msg' &&
      (frame.data as Frame | undefined)?.id === 'fresh-install-info');
    assert.equal((info.data as Frame).kind, 'info');
    assert.equal((info.data as Frame).defaultCwd, cwd);
    phone.send({ t: 'msg', data: { type: 'list_sessions', id: 'fresh-install-sessions' } });
    const sessions = await phone.wait((frame) => frame.t === 'msg' &&
      (frame.data as Frame | undefined)?.id === 'fresh-install-sessions');
    assert.equal((sessions.data as Frame).kind, 'sessions');
    assert.deepEqual((sessions.data as Frame).sessions, []);
  } finally { phone.close(); }
}

export async function smokeSidecar(): Promise<void> {
  const home = await temporarySidecarHome();
  try {
    const sidecar = await startSidecar(home, ['--port', String(await unusedPort())]);
    try { await verifyPhoneRoundTrip(sidecar, path.join(home, 'cwd')); }
    finally { await sidecar.stop(); }
  } finally { await rm(home, { recursive: true, force: true }); }
}

if (process.argv[1] && path.resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  await smokeSidecar();
  process.stdout.write('Sidecar smoke passed: fresh LAN start, pairing, phone info and session replies.\n');
}
