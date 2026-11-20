import assert from 'node:assert/strict';
import { readFile, rm } from 'node:fs/promises';
import path from 'node:path';
import { describe, it } from 'node:test';

import { smokeSidecar, startSidecar, temporarySidecarHome, unusedPort } from '../scripts/sidecar-smoke.ts';
import { createRelay } from '../src/relay/relay.ts';

describe('phone → relay → sidecar', () => {
  it('starts from empty config, pairs and answers phone requests', { timeout: 90_000 }, smokeSidecar);

  it('persists remote and local mode changes across restarts', { timeout: 90_000 }, async () => {
    const home = await temporarySidecarHome();
    const relay = createRelay({ relayKey: 'test-registration-key' });
    let sidecar: Awaited<ReturnType<typeof startSidecar>> | undefined;
    try {
      const server = await relay.listen(0, '127.0.0.1');
      const address = server.address();
      assert.ok(address && typeof address !== 'string');
      const url = `ws://127.0.0.1:${address.port}/ws`;
      const config = async () => JSON.parse(await readFile(path.join(home, 'config', 'agent.json'), 'utf8'));

      sidecar = await startSidecar(home, ['--port', String(await unusedPort())]);
      await sidecar.wait((frame) => frame.type === 'snapshot' && frame.relayOnline === true);
      sidecar.send({ type: 'set_relay', url, key: 'test-registration-key' });
      await sidecar.wait((frame) => frame.type === 'notice');
      assert.equal((await config()).connectionMode, 'remote');
      await sidecar.stop();

      sidecar = await startSidecar(home);
      const remote = await sidecar.wait((frame) => frame.type === 'snapshot' && frame.relayOnline === true);
      assert.equal(remote.connectionMode, 'remote');
      assert.equal(remote.relayUrl, url);
      assert.equal(relay.stats().online, 1);
      sidecar.send({ type: 'set_relay', clear: true });
      await sidecar.wait((frame) => frame.type === 'notice');
      const cleared = await config();
      assert.equal(cleared.connectionMode, 'local');
      assert.equal(cleared.relayUrl, undefined);
      assert.equal(cleared.relayKey, undefined);
      await sidecar.stop();

      sidecar = await startSidecar(home);
      const local = await sidecar.wait((frame) => frame.type === 'snapshot' && frame.relayOnline === true);
      assert.equal(local.connectionMode, 'local');
      await sidecar.wait((frame) => frame.type === 'pair_code');
    } finally {
      await sidecar?.stop();
      await relay.close();
      await rm(home, { recursive: true, force: true });
    }
  });
});
