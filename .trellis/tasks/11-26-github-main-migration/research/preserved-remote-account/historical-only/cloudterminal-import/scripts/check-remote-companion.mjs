#!/usr/bin/env node
// Structural checks for the CloudTerminal companion import and the Studio entry.
//
// Usage:
//   node scripts/check-remote-companion.mjs           # check this worktree
//   node scripts/check-remote-companion.mjs --list    # print every check
//
// Exit 1 means at least one invariant broke and each failure names the file it
// read. This is static inspection: it proves layout, wiring and path hygiene,
// not that an agent starts or that pairing succeeds. Runtime checks live in
// `companion/remote_agent/test` and `companion/windows_assistant/test`.
//
// No dependencies: the workflow runs this before `npm ci`, exactly like
// `scripts/check-root-ci.mjs`. Keep both dependency-free.

import { createHash } from 'node:crypto';
import { existsSync, readFileSync, readdirSync } from 'node:fs';
import { dirname, join, relative, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

const root = resolve(dirname(fileURLToPath(import.meta.url)), '..');

const checks = [];
function check(label, description, fn) {
  checks.push({ label, description, fn });
}

const failures = [];
function fail(message) {
  failures.push(message);
}

function read(rel) {
  return readFileSync(join(root, rel), 'utf8');
}

function exists(rel) {
  return existsSync(join(root, rel));
}

function walk(rel) {
  const start = join(root, rel);
  if (!existsSync(start)) return [];
  const out = [];
  const visit = (dir) => {
    for (const entry of readdirSync(dir, { withFileTypes: true })) {
      if (entry.name === 'node_modules' || entry.name === 'build' || entry.name === '.dart_tool') continue;
      const full = join(dir, entry.name);
      if (entry.isDirectory()) visit(full);
      else out.push(relative(root, full).replaceAll('\\', '/'));
    }
  };
  visit(start);
  return out.sort();
}

// ---------------------------------------------------------------------------
// Layout
// ---------------------------------------------------------------------------

const AGENT_ROOT = 'companion/remote_agent';
const ASSISTANT_ROOT = 'companion/windows_assistant';

check('host-entry', 'the Studio tools tab exposes the remote computer card', () => {
  const entry = 'lib/studio_tools_tab.dart';
  if (!exists(entry)) {
    fail(`${entry}: missing; the remote computer entry has no mount point`);
    return;
  }
  const source = read(entry);
  for (const needle of [
    'Widget buildStudioToolsTab(',
    'RemoteComputerPage.isSupported',
    'const RemoteComputerPage()',
    "title: '远程电脑'",
  ]) {
    if (!source.includes(needle)) {
      fail(`${entry}: expected \`${needle}\``);
    }
  }
  if (!read('lib/main.dart').includes('toolsTabBuilder: buildStudioToolsTab')) {
    fail('lib/main.dart: `toolsTabBuilder` is not wired to `buildStudioToolsTab`');
  }
  if (!read('lib/main.dart').includes("import 'studio_tools_tab.dart';")) {
    fail('lib/main.dart: missing the studio_tools_tab import');
  }
});

check('agent-layout', 'the Node agent keeps its entry points and launchers', () => {
  const manifest = `${AGENT_ROOT}/package.json`;
  if (!exists(manifest)) {
    fail(`${manifest}: missing`);
    return;
  }
  const pkg = JSON.parse(read(manifest));
  if (pkg.name !== 'cloudterminal-server') fail(`${manifest}: unexpected name ${pkg.name}`);
  if (!/^>=\d+\.\d+/.test(pkg.engines?.node ?? '')) fail(`${manifest}: no node engine floor`);
  for (const script of ['agent', 'check', 'test', 'e2e', 'sync-relay']) {
    if (!pkg.scripts?.[script]) fail(`${manifest}: missing script \`${script}\``);
  }
  for (const dep of ['node-pty', 'ws', '@anthropic-ai/claude-agent-sdk']) {
    if (!pkg.dependencies?.[dep]) fail(`${manifest}: missing dependency \`${dep}\``);
  }
  for (const rel of [
    `${AGENT_ROOT}/src/agent/main.ts`,
    `${AGENT_ROOT}/src/agent/sidecar.ts`,
    `${AGENT_ROOT}/src/relay/relay.ts`,
    `${AGENT_ROOT}/src/shared/protocol.ts`,
    `${AGENT_ROOT}/src/shared/pairing.ts`,
    `${AGENT_ROOT}/relay-core.json`,
    `${AGENT_ROOT}/package-lock.json`,
    `${AGENT_ROOT}/start.cmd`,
    `${AGENT_ROOT}/start.sh`,
    `${AGENT_ROOT}/README.md`,
  ]) {
    if (!exists(rel)) fail(`${rel}: missing`);
  }
});

check('assistant-layout', 'the Windows assistant keeps its runner and sidecar lookup', () => {
  if (!exists(`${ASSISTANT_ROOT}/pubspec.yaml`)) {
    fail(`${ASSISTANT_ROOT}/pubspec.yaml: missing`);
    return;
  }
  for (const rel of [
    `${ASSISTANT_ROOT}/lib/main.dart`,
    `${ASSISTANT_ROOT}/lib/engine/sidecar_client.dart`,
    `${ASSISTANT_ROOT}/test/sidecar_ipc_test.dart`,
    `${ASSISTANT_ROOT}/windows/CMakeLists.txt`,
    `${ASSISTANT_ROOT}/run.cmd`,
  ]) {
    if (!exists(rel)) fail(`${rel}: missing`);
  }
  const main = read(`${ASSISTANT_ROOT}/lib/main.dart`);
  // Resolution order: explicit override, working dir parent, executable walk.
  const order = [
    'CLOUDTERMINAL_AGENT_DIR',
    "'${Directory.current.path}$sep..$sep'",
    'Platform.resolvedExecutable',
    'CLOUDTERMINAL_NODE',
  ];
  for (const needle of order) {
    if (!main.includes(needle)) {
      fail(`${ASSISTANT_ROOT}/lib/main.dart: sidecar lookup lost \`${needle}\``);
    }
  }
  if (main.indexOf('CLOUDTERMINAL_AGENT_DIR') > main.indexOf("'${Directory.current.path}$sep..$sep'")) {
    fail(`${ASSISTANT_ROOT}/lib/main.dart: the explicit override must be checked before the cwd guess`);
  }
  if (!read(`${ASSISTANT_ROOT}/test/sidecar_ipc_test.dart`).includes("'../remote_agent'")) {
    fail(`${ASSISTANT_ROOT}/test/sidecar_ipc_test.dart: sidecar cwd is not ../remote_agent`);
  }
});

// ---------------------------------------------------------------------------
// Path hygiene: no file may point at the original source checkout
// ---------------------------------------------------------------------------

const SOURCE_MARKERS = [
  '../../server',
  'apps/cloudterminal_windows',
  'MyNewProjects/cloudterminal',
  'MyNewProjects\\cloudterminal',
];

// The migration notices must name where a file came from, so the licence stays
// traceable. Markdown may therefore mention the source app directory; it may
// still not carry a working path into that checkout.
const SOURCE_MARKERS_DOCS = SOURCE_MARKERS.filter(
  (marker) => marker !== 'apps/cloudterminal_windows',
);

check('no-source-paths', 'companion files do not reach into the CloudTerminal checkout', () => {
  const files = [
    ...walk(AGENT_ROOT).filter((f) => /\.(ts|json|md|sh|cmd)$/.test(f)),
    ...walk(ASSISTANT_ROOT).filter((f) => /\.(dart|yaml|md|cmd)$/.test(f)),
    'lib/studio_tools_tab.dart',
    'lib/main.dart',
    'pubspec.yaml',
  ];
  for (const rel of files) {
    if (rel.endsWith('package-lock.json')) continue;
    const text = read(rel);
    const markers = rel.endsWith('.md') ? SOURCE_MARKERS_DOCS : SOURCE_MARKERS;
    for (const marker of markers) {
      if (text.includes(marker)) fail(`${rel}: contains \`${marker}\``);
    }
  }
});

check('relative-pubspec', 'Dart path dependencies stay relative to the worktree', () => {
  const pubspec = read('pubspec.yaml');
  for (const match of pubspec.matchAll(/^\s*path:\s*(\S+)\s*$/gm)) {
    const value = match[1];
    // `path: ^1.9.1` is the pub `path` package constraint, not a directory.
    if (!value.includes('/') && !value.includes('\\')) continue;
    if (/^[A-Za-z]:|^\//.test(value)) {
      fail(`pubspec.yaml: absolute path dependency ${value}`);
      continue;
    }
    if (value !== '../qfli_studio_core' && !value.startsWith('../qfli_studio_core/')) {
      fail(`pubspec.yaml: path dependency ${value} leaves the paired core`);
    }
  }
  const assistant = read(`${ASSISTANT_ROOT}/pubspec.yaml`);
  if (/path:\s*[A-Za-z]:/.test(assistant)) {
    fail(`${ASSISTANT_ROOT}/pubspec.yaml: absolute path dependency`);
  }
});

// ---------------------------------------------------------------------------
// Secrets and generated files must not be tracked
// ---------------------------------------------------------------------------

const FORBIDDEN_TRACKED = [
  /^companion\/.*\/node_modules\//,
  /^companion\/.*\/(bootstrap|cloudterminal\.bootstrap)\.json$/,
  /^companion\/.*\.(jks|keystore|p12|pfx)$/,
  /^companion\/.*\/key\.properties$/,
  /^companion\/.*\/agent\.json$/,
  /^companion\/.*\/\.env$/,
];

check('no-secrets', 'agent identity, signing material and deps stay out of the tree', () => {
  for (const rel of walk('companion')) {
    for (const pattern of FORBIDDEN_TRACKED) {
      if (pattern.test(rel)) fail(`${rel}: generated or secret file is present in the worktree`);
    }
  }
  const ignore = read('.gitignore');
  for (const rule of [
    '/companion/**/node_modules/',
    '/companion/remote_agent/bootstrap.json',
    '/companion/remote_agent/cloudterminal.bootstrap.json',
  ]) {
    if (!ignore.includes(rule)) fail(`.gitignore: missing rule ${rule}`);
  }
});

check('relay-core-manifest', 'the in-process relay copy matches its recorded hashes', () => {
  const manifestPath = `${AGENT_ROOT}/relay-core.json`;
  if (!exists(manifestPath)) return;
  const manifest = JSON.parse(read(manifestPath));
  if (!/^[0-9a-f]{40}$/.test(manifest.commit ?? '')) {
    fail(`${manifestPath}: commit is not a full SHA`);
  }
  const listed = Object.keys(manifest.files ?? {}).sort();
  if (listed.length !== 5) {
    fail(`${manifestPath}: expected 5 relay-core files, found ${listed.length}`);
  }
  for (const rel of listed) {
    const full = `${AGENT_ROOT}/${rel}`;
    if (!exists(full)) {
      fail(`${full}: listed in relay-core.json but missing`);
      continue;
    }
    // sync-relay hashes LF-normalised contents, so a Windows checkout agrees.
    const digest = createHash('sha256')
      .update(read(full).replaceAll('\r\n', '\n'))
      .digest('hex');
    if (digest !== manifest.files[rel]) {
      fail(`${full}: hash ${digest} != relay-core.json ${manifest.files[rel]}`);
    }
  }
});

check('workflow', 'the companion workflow pins the paired revisions and the OHOS SDK', () => {
  const path = '.github/workflows/remote-companion.yml';
  if (!exists(path)) {
    fail(`${path}: missing`);
    return;
  }
  const text = read(path);
  for (const needle of [
    'azurekiln2333/qflistudio-core',
    'remote/cloudterminal-core',
    'remote/cloudterminal-app',
    '3.27.5-ohos-1.0.1',
    '12587c79e88aacf3172a84e536f226457d037594',
    'flutter config --no-enable-ohos',
    'npm ci',
    'flutter test',
    'flutter build windows --release',
  ]) {
    if (!text.includes(needle)) fail(`${path}: missing \`${needle}\``);
  }
  if (!/PAIRED_APP_COMMIT:\s*"[0-9a-f]{40}"/.test(text)) {
    fail(`${path}: PAIRED_APP_COMMIT is not a full SHA`);
  }
  if (!/PAIRED_CORE_COMMIT:\s*"[0-9a-f]{40}"/.test(text)) {
    fail(`${path}: PAIRED_CORE_COMMIT is not a full SHA`);
  }
  if (/ref:\s*(main|master)\s*$/m.test(text)) {
    fail(`${path}: a checkout falls back to a moving branch`);
  }
  for (const match of text.matchAll(/^\s*uses:\s*(\S+)/gm)) {
    const ref = match[1];
    if (ref.startsWith('./')) continue;
    if (!/^[A-Za-z0-9._-]+\/[A-Za-z0-9._-]+@[0-9a-f]{40}$/.test(ref)) {
      fail(`${path}: unpinned action ref ${ref}`);
    }
  }
});

// ---------------------------------------------------------------------------
// Runner
// ---------------------------------------------------------------------------

if (process.argv.includes('--list')) {
  for (const entry of checks) console.log(`${entry.label.padEnd(20)} ${entry.description}`);
  process.exit(0);
}

for (const entry of checks) {
  try {
    await entry.fn();
  } catch (error) {
    fail(`${entry.label}: threw ${error?.message ?? error}`);
  }
}

if (failures.length > 0) {
  console.error(`${failures.length} structural problem(s):`);
  for (const line of failures) console.error(`  ${line}`);
  process.exit(1);
}

console.log(`${checks.length} structural checks passed`);
