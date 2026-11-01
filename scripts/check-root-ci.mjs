#!/usr/bin/env node
// Validates the root .cnb.yml contract without external dependencies.
//
// Invariants:
//  - three images build from explicit nested contexts, never from the repo root;
//  - pull-request pipelines validate only (no docker service, login or push);
//  - trusted main pushes publish commit tags plus floating `latest`;
//  - stable semver tags move `latest`, prereleases stay on their own tags;
//  - no credential material is committed in the pipeline.
import { existsSync, readFileSync } from 'node:fs';
import { dirname, join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

const root = resolve(dirname(fileURLToPath(import.meta.url)), '..');
const yamlPath = join(root, '.cnb.yml');
const failures = [];

function check(ok, message) {
  if (!ok) failures.push(message);
}

check(existsSync(yamlPath), '.cnb.yml exists at the repository root');
if (!existsSync(yamlPath)) {
  console.error(failures.join('\n'));
  process.exit(1);
}

const text = readFileSync(yamlPath, 'utf8');

function section(startMarker, endMarker) {
  const start = text.indexOf(startMarker);
  if (start < 0) return '';
  const end = endMarker == null ? text.length : text.indexOf(endMarker, start);
  return end < 0 ? text.slice(start) : text.slice(start, end);
}

const contexts = [
  ['azurekiln-qfli-server', 'SERVER_IMAGE'],
  ['azurekiln-qfli-terminal', 'EXECUTOR_IMAGE'],
  ['azurekiln-qfli-terminal/sandbox', 'SANDBOX_IMAGE'],
];

check(/^main:\s*$/m.test(text), 'top-level main pipeline exists');
check(/^  push:\s*$/m.test(text), 'main push pipeline exists');
check(/^  pull_request:\s*$/m.test(text), 'pull request pipeline exists');
check(/^"v\*":\s*$/m.test(text), 'tag pipeline exists');
check(/^  tag_push:\s*$/m.test(text), 'tag push pipeline exists');

for (const [dir] of contexts) {
  check(existsSync(join(root, dir)), `service context exists: ${dir}`);
  const dockerfile = join(root, dir, 'Dockerfile');
  check(existsSync(dockerfile), `Dockerfile exists: ${dir}/Dockerfile`);
}

const verifyJob = section('- name: verify-services', '- name: publish-images');
const publishJob = section('- name: publish-images', '  pull_request:');
const tagJob = section('"v*":');
const expectedBuilds = new Map([
  [
    'main push publish job',
    [
      'docker build --pull -f azurekiln-qfli-server/Dockerfile -t "$SERVER_IMAGE:$REVISION" azurekiln-qfli-server',
      'docker build --pull -f azurekiln-qfli-terminal/Dockerfile -t "$EXECUTOR_IMAGE:$REVISION" azurekiln-qfli-terminal',
      'docker build --pull -f azurekiln-qfli-terminal/sandbox/Dockerfile -t "$SANDBOX_IMAGE:3" azurekiln-qfli-terminal/sandbox',
    ],
  ],
  [
    'tag publish job',
    [
      'docker build --pull -f azurekiln-qfli-server/Dockerfile -t "$SERVER_IMAGE:$TAG" azurekiln-qfli-server',
      'docker build --pull -f azurekiln-qfli-terminal/Dockerfile -t "$EXECUTOR_IMAGE:$TAG" azurekiln-qfli-terminal',
      'docker build --pull -f azurekiln-qfli-terminal/sandbox/Dockerfile -t "$SANDBOX_IMAGE:3" azurekiln-qfli-terminal/sandbox',
      'docker build --pull -f azurekiln-qfli-terminal/sandbox/Dockerfile -t "$SANDBOX_IMAGE:$TAG-sandbox" azurekiln-qfli-terminal/sandbox',
    ],
  ],
]);
for (const [label, job] of [
  ['main push publish job', publishJob],
  ['tag publish job', tagJob],
]) {
  const jobFlat = job
    .replace(/\\\r?\n\s*/g, ' ')
    .replace(/[ \t]+/g, ' ')
    .trim();
  check(job.length > 0, `${label} exists`);
  for (const command of expectedBuilds.get(label) ?? []) {
    check(
      jobFlat.includes(command),
      `${label} builds the nested context: ${command}`,
    );
  }
  check(
    !/docker build [^\n]* -t "[^"]+" \.(?:\s|$)/.test(jobFlat),
    `${label} never uses the repository root as build context`,
  );
}

check(verifyJob.length > 0, 'main push has a verification job');
for (const command of [
  'npm ci',
  'node scripts/check-deployment.mjs',
  'node --test test/*.test.js',
  'npm test',
  'node scripts/check-root-ci.mjs',
  'node --test scripts/check-root-ci.test.mjs',
]) {
  check(verifyJob.includes(command), `verification runs: ${command}`);
}

check(publishJob.includes('services:'), 'publish job requests the docker service');
check(/services:\s*\n\s*- docker/.test(publishJob), 'publish job declares `- docker`');
check(
  publishJob.includes('if [ -n "${CNB_REGISTRY_PASSWORD:-}" ]'),
  'registry login is conditional on the trusted pipeline secret',
);
for (const image of ['SERVER_IMAGE', 'EXECUTOR_IMAGE', 'SANDBOX_IMAGE']) {
  check(
    publishJob.includes(`docker push "$${image}:`),
    `publish job pushes ${image}`,
  );
  check(
    publishJob.includes(`$${image}:latest`),
    `main push publishes ${image}:latest`,
  );
}
check(
  publishJob.includes('$SANDBOX_IMAGE:3'),
  'main push publishes the stable sandbox toolchain tag :3',
);

const pullRequestJob = section('  pull_request:', '\n"v*":');
check(pullRequestJob.length > 0, 'pull request job is present');
check(
  !pullRequestJob.includes('docker login'),
  'pull request job never logs in to the registry',
);
check(
  !pullRequestJob.includes('docker push'),
  'pull request job never pushes images',
);
check(
  !pullRequestJob.includes('docker build'),
  'pull request job never builds images',
);
check(
  !pullRequestJob.includes('CNB_REGISTRY_PASSWORD'),
  'pull request job never reads registry credentials',
);
check(
  !/services:\s*\n\s*- docker/.test(pullRequestJob),
  'pull request job has no docker service',
);

check(tagJob.length > 0, 'tag job is present');
check(
  tagJob.includes('STABLE=0'),
  'tag pipeline defaults to a prerelease-safe mode',
);
check(
  tagJob.includes('grep -Eq'),
  'tag pipeline validates a semver release tag',
);
check(
  tagJob.includes('case "$VERSION" in') && tagJob.includes('*-*)'),
  'tag pipeline detects prerelease versions',
);

const caseStart = tagJob.indexOf('case "$VERSION" in');
const firstBranchEnd = tagJob.indexOf(';;', caseStart);
const prereleaseBranch =
  caseStart < 0 || firstBranchEnd < 0
    ? ''
    : tagJob.slice(caseStart, firstBranchEnd);
check(prereleaseBranch.length > 0, 'prerelease branch is present');
check(
  !prereleaseBranch.includes('latest'),
  'prerelease branch never moves `latest`',
);
check(
  !prereleaseBranch.includes('SANDBOX_IMAGE:3'),
  'prerelease branch never replaces the stable sandbox :3 tag',
);
check(
  tagJob.includes('$SANDBOX_IMAGE:$TAG-sandbox'),
  'prerelease sandbox image gets its own isolated tag',
);

const esacIndex = tagJob.indexOf('esac', firstBranchEnd);
const stableBranch =
  firstBranchEnd < 0 || esacIndex < 0
    ? ''
    : tagJob.slice(firstBranchEnd, esacIndex);
check(
  stableBranch.length > 0,
  'stable branch exists after the prerelease case',
);
check(
  tagJob.includes('if [ "$STABLE" = 1 ]'),
  'stable publishing is gated explicitly',
);
check(
  tagJob.includes('$SANDBOX_IMAGE:3'),
  'stable tags publish the sandbox :3 tag',
);

check(!/BEGIN [A-Z ]*PRIVATE KEY/.test(text), 'no private key material');
check(!/\bAKIA[0-9A-Z]{16}\b/.test(text), 'no AWS access key id');
check(!/\bghp_[A-Za-z0-9]{20,}\b/.test(text), 'no GitHub token');
check(!/\bsk-[A-Za-z0-9]{20,}\b/.test(text), 'no API secret key');

if (failures.length > 0) {
  console.error('root CI config check failed:');
  for (const failure of failures) console.error(`- ${failure}`);
  process.exit(1);
}

console.log(
  'root CI config ok: 3 nested contexts, PR validate-only, ' +
    'main commit+latest, stable-only latest moves',
);
