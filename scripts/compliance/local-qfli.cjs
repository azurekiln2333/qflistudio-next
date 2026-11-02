// Local integration fixture only. The real server starts after temporary sessions exist.
const path = require('node:path');

(async () => {
  if (process.env.NODE_ENV !== 'test' || !process.env.COMPLIANCE_E2E_ROOT || !process.send) {
    throw new Error('This fixture requires the local-e2e parent');
  }
  const serverRoot = process.env.COMPLIANCE_E2E_ROOT;
  const db = require(path.join(serverRoot, 'src/db.js'));
  const identity = require(path.join(serverRoot, 'src/identity.js'));
  const { signToken } = require(path.join(serverRoot, 'src/util.js'));
  const sdk = require(require.resolve('@azurekiln/moderation-client', { paths: [serverRoot] }));
  if (typeof sdk.ModerationClient !== 'function') throw new Error('Vendored SDK missing');
  await db.ready;
  const accounts = JSON.parse(process.env.COMPLIANCE_E2E_ACCOUNTS);
  const tokens = {};
  for (const [name, account] of Object.entries(accounts)) {
    const session = await identity.createSession({ access_token: account.accessToken, expires_in: 3600 }, account.claims);
    tokens[name] = signToken({ uid: session.user.id, sid: session.id });
  }
  process.send({ type: 'sessions', tokens });
  require(path.join(serverRoot, 'src/server.js'));
})().catch(() => {
  process.stderr.write('Local QFLI fixture startup failed\n');
  process.exit(1);
});
