import assert from 'node:assert/strict';
import { execFileSync } from 'node:child_process';
import { mkdtemp, mkdir, readFile, rm, writeFile } from 'node:fs/promises';
import { basename, dirname, join, resolve } from 'node:path';
import { tmpdir } from 'node:os';
import test from 'node:test';

const runbook = await readFile(new URL('../../docs/compliance/2026-11-上线手册.md', import.meta.url), 'utf8');
const scripts = [...runbook.matchAll(/python3 - <<'PY'\r?\n([\s\S]*?)\r?\nPY/g)].map(match => match[1]);
assert.equal(scripts.length, 4, 'credential issuance, merge, image pin, and rollback are executable Python blocks');
const python = process.platform === 'win32' ? 'python' : 'python3';
const readText = async path => (await readFile(path, 'utf8')).replace(/\r\n/g, '\n');

async function fixture(t) {
  const root = await mkdtemp(join(tmpdir(), 'qfli-runbook-test-'));
  t.after(async () => {
    assert.equal(dirname(resolve(root)), resolve(tmpdir()));
    assert.ok(basename(root).startsWith('qfli-runbook-test-'));
    await rm(root, { recursive: true, force: true, maxRetries: 5, retryDelay: 100 });
  });
  const etc = join(root, 'etc');
  const qfli = join(root, 'qfli');
  const backup = join(root, 'backup');
  const moderation = join(root, 'moderation');
  await Promise.all([etc, qfli, backup, moderation].map(path => mkdir(path)));
  function execute(index, extra = {}) {
    let source = scripts[index];
    for (const [from, to] of [
      ["Path('/etc/azurekiln')", `Path(${JSON.stringify(etc)})`],
      ["Path('/etc/azurekiln/qfli-moderation.env')", `Path(${JSON.stringify(join(etc, 'qfli-moderation.env'))})`],
      ["Path('/etc/azurekiln/moderation.image.env')", `Path(${JSON.stringify(join(etc, 'moderation.image.env'))})`],
      ["Path('/opt/azurekiln-moderation/compose.rollback.yaml')", `Path(${JSON.stringify(join(moderation, 'compose.rollback.yaml'))})`],
    ]) source = source.replaceAll(from, to);
    assert.doesNotMatch(source, /Path\('\/(?:etc|opt)\//, 'fixture must not access server paths');
    return execFileSync(python, ['-c', source], {
      env: { ...process.env, QFLI_DIR: qfli, BACKUP: backup, QFLI_ROLLBACK_DB: '', ...extra },
      encoding: 'utf8', stdio: ['ignore', 'pipe', 'pipe'], timeout: 5000,
    });
  }
  return { root, etc, qfli, backup, moderation, execute };
}

test('runbook issues unique app credentials without printing or overwriting them', async t => {
  const f = await fixture(t);
  assert.equal(f.execute(0), '');
  const original = await readFile(join(f.etc, 'moderation.env'), 'utf8');
  const apps = JSON.parse(original.match(/^MODERATION_APPS_JSON='(.+)'$/m)[1]);
  assert.deepEqual(apps.map(app => app.appId), ['qflistudio', 'gateway']);
  const keys = apps.flatMap(app => [app.apiKey, app.adminKey]);
  assert.equal(new Set(keys).size, 4);
  for (const key of keys) assert.match(key, /^[a-f0-9]{64}$/);
  assert.match(await readFile(join(f.etc, 'qfli-moderation.env'), 'utf8'), new RegExp(`MODERATION_API_KEY=${apps[0].apiKey}`));
  assert.match(await readFile(join(f.etc, 'gateway-moderation.env'), 'utf8'), new RegExp(`MODERATION_API_KEY=${apps[1].apiKey}`));
  assert.throws(() => f.execute(0), /Credential files already exist/);
  assert.equal(await readFile(join(f.etc, 'moderation.env'), 'utf8'), original);
});

test('runbook environment merge preserves existing settings and is repeatable', async t => {
  const f = await fixture(t);
  f.execute(0);
  await writeFile(join(f.qfli, '.env'), '# keep comment\nMYSQL_PASSWORD=local-test-only\nMODERATION_API_KEY=old\n');
  assert.equal(f.execute(1), '');
  const first = await readText(join(f.qfli, '.env'));
  assert.match(first, /MYSQL_PASSWORD=local-test-only/);
  assert.ok(first.startsWith('# keep comment\n'));
  assert.equal((first.match(/^MODERATION_API_KEY=/gm) || []).length, 1);
  assert.doesNotMatch(first, /MODERATION_API_KEY=old/);
  f.execute(1);
  assert.equal(await readText(join(f.qfli, '.env')), first);
});

test('runbook pins the exact tested QFLI digest without losing credentials', async t => {
  const f = await fixture(t);
  await writeFile(join(f.qfli, '.env'), 'MYSQL_PASSWORD=local-test-only\nQFLI_SERVER_IMAGE=old\n');
  const digest = `docker.cnb.cool/azurekiln/qflistudio-next/qfli-server@sha256:${'a'.repeat(64)}`;
  assert.equal(f.execute(2, { QFLI_SERVER_IMAGE: digest }), '');
  const value = await readText(join(f.qfli, '.env'));
  assert.match(value, /MYSQL_PASSWORD=local-test-only/);
  assert.ok(value.endsWith(`QFLI_SERVER_IMAGE=${digest}\n`));
  assert.equal((value.match(/^QFLI_SERVER_IMAGE=/gm) || []).length, 1);
});

test('rollback restores matching credentials, old image IDs, new database, and a separate volume', async t => {
  const f = await fixture(t);
  for (const [name, value] of Object.entries({
    '.env': 'MYSQL_DATABASE=qfli\nMYSQL_PASSWORD=backed-up-test\nQFLI_SERVER_IMAGE=new\n',
    'qfli.image-id': 'sha256:old-qfli\n',
    'moderation.image-id': 'sha256:old-moderation\n',
    'moderation.env': 'MODERATION_APPS_JSON=protected-local-test\n',
    'moderation.image.env': 'MODERATION_IMAGE=stale-tag\n',
    'moderation.compose.yaml': 'volumes:\n  moderation-data:\n    name: azurekiln-moderation-data\n',
  })) await writeFile(join(f.backup, name), value);
  assert.equal(f.execute(3, { QFLI_ROLLBACK_DB: 'qfli_restored', ROLLBACK_VOLUME: 'dedicated-restore-volume' }), '');
  assert.equal(await readText(join(f.qfli, '.env')),
    'MYSQL_PASSWORD=backed-up-test\nQFLI_SERVER_IMAGE=sha256:old-qfli\nMYSQL_DATABASE=qfli_restored\n');
  assert.equal(await readText(join(f.etc, 'moderation.image.env')), 'MODERATION_IMAGE=sha256:old-moderation\n');
  assert.match(await readFile(join(f.moderation, 'compose.rollback.yaml'), 'utf8'), /name: dedicated-restore-volume/);
});
