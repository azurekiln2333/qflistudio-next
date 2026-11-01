// Regression tests for scripts/check-root-ci.mjs.
//
// Each case copies the real .cnb.yml into a temporary repository fixture,
// mutates one publish-boundary rule, and asserts the checker rejects it.
// A checker that silently accepts a broken pipeline fails this test.
import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';
import { copyFileSync, mkdirSync, mkdtempSync, readFileSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { dirname, join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import test from 'node:test';

const repo = resolve(dirname(fileURLToPath(import.meta.url)), '..');
const pipeline = readFileSync(join(repo, '.cnb.yml'), 'utf8');
const checkerSource = join(repo, 'scripts', 'check-root-ci.mjs');

function createFixture() {
  const root = mkdtempSync(join(tmpdir(), 'qfli-root-ci-'));
  for (const dir of [
    'azurekiln-qfli-server',
    'azurekiln-qfli-terminal',
    'azurekiln-qfli-terminal/sandbox',
  ]) {
    mkdirSync(join(root, dir), { recursive: true });
    writeFileSync(join(root, dir, 'Dockerfile'), 'FROM scratch\n');
  }
  mkdirSync(join(root, 'scripts'), { recursive: true });
  copyFileSync(checkerSource, join(root, 'scripts', 'check-root-ci.mjs'));
  writeFileSync(join(root, '.cnb.yml'), pipeline);
  return root;
}

function runChecker(root) {
  return spawnSync(process.execPath, [join(root, 'scripts', 'check-root-ci.mjs')], {
    encoding: 'utf8',
  });
}

function assertAccepted(yamlText) {
  const root = createFixture();
  writeFileSync(join(root, '.cnb.yml'), yamlText);
  const result = runChecker(root);
  assert.equal(result.status, 0, `${result.stderr}${result.stdout}`);
}

function assertRejected(name, mutate, expectedFragment) {
  const root = createFixture();
  writeFileSync(join(root, '.cnb.yml'), mutate(pipeline));
  const result = runChecker(root);
  assert.notEqual(result.status, 0, `${name} was accepted`);
  assert.match(result.stderr, new RegExp(expectedFragment), name);
}

const mainPushSandbox = [
  '            docker build --pull -f azurekiln-qfli-terminal/sandbox/Dockerfile \\',
  '              -t "$SANDBOX_IMAGE:3" azurekiln-qfli-terminal/sandbox',
].join('\n');
const prStages = '      docker: *node-runtime\n      stages:\n';

test('accepts the repository root pipeline', () => {
  assertAccepted(pipeline);
});

test('rejects a main push that drops one nested build', () => {
  assertRejected(
    'dropped sandbox build',
    (text) => text.replace(mainPushSandbox, 'true'),
    'main push publish job builds the nested context',
  );
});

test('rejects a service build from the repository root', () => {
  assertRejected(
    'root build context',
    (text) =>
      text.replace(
        '              -t "$SERVER_IMAGE:$REVISION" azurekiln-qfli-server',
        '              -t "$SERVER_IMAGE:$REVISION" .',
      ),
    'main push publish job builds the nested context',
  );
});

test('rejects a swapped build context', () => {
  assertRejected(
    'swapped context',
    (text) =>
      text.replace(
        '              -t "$SERVER_IMAGE:$REVISION" azurekiln-qfli-server',
        '              -t "$SERVER_IMAGE:$REVISION" azurekiln-qfli-terminal',
      ),
    'main push publish job builds the nested context',
  );
});

test('rejects a pull request pipeline that pushes images', () => {
  assertRejected(
    'pr push',
    (text) =>
      text.replace(
        prStages,
        `${prStages}        - name: bad\n          script: |\n            docker push "$X:y"\n`,
      ),
    'never pushes images',
  );
});

test('rejects a pull request pipeline that reads registry credentials', () => {
  assertRejected(
    'pr credentials',
    (text) =>
      text.replace(
        prStages,
        `${prStages}        - name: bad\n          script: |\n            test -n "\${CNB_REGISTRY_PASSWORD:-}"\n`,
      ),
    'never reads registry credentials',
  );
});

test('rejects a pull request pipeline with the docker service', () => {
  assertRejected(
    'pr docker service',
    (text) =>
      text.replace(
        prStages,
        '      docker: *node-runtime\n      services:\n        - docker\n      stages:\n',
      ),
    'has no docker service',
  );
});

test('rejects a prerelease that moves the floating latest tag', () => {
  assertRejected(
    'prerelease latest',
    (text) =>
      text.replace(
        '              *-*) echo "prerelease $VERSION, floating tags stay unchanged" ;;',
        '              *-*) docker push "$SERVER_IMAGE:latest" ;;',
      ),
    'never moves `latest`',
  );
});

test('rejects a prerelease that replaces the stable sandbox tag', () => {
  assertRejected(
    'prerelease sandbox 3',
    (text) =>
      text.replace(
        '              *-*) echo "prerelease $VERSION, floating tags stay unchanged" ;;',
        '              *-*) docker push "$SANDBOX_IMAGE:3" ;;',
      ),
    'never replaces the stable sandbox :3 tag',
  );
});

test('rejects a prerelease without an isolated sandbox tag', () => {
  assertRejected(
    'prerelease sandbox tag',
    (text) => text.replace('$SANDBOX_IMAGE:$TAG-sandbox', '$SANDBOX_IMAGE:$TAG'),
    'TAG-sandbox',
  );
});

test('rejects a tag pipeline without a semver guard', () => {
  assertRejected(
    'missing semver guard',
    (text) => text.replace("            printf '%s' \"$VERSION\" | grep -Eq \\\n", '            true \\\n'),
    'validates a semver release tag',
  );
});

test('rejects committed credential material', () => {
  assertRejected(
    'leaked key',
    (text) => `${text}\n# sk-abcdefghijklmnopqrstuvwxyz123456\n`,
    'no API secret key',
  );
});