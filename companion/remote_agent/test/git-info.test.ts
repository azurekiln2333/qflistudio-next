import assert from 'node:assert/strict';
import { mkdir, mkdtemp, rm, writeFile } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import path from 'node:path';
import { after, before, describe, test } from 'node:test';

import {
  detectDirty,
  directoryBytes,
  parseHead,
  parseOriginUrl,
  readGitInfo,
} from '../src/agent/git-info.ts';

describe('parseOriginUrl', () => {
  test('reads the ssh url of origin', () => {
    const config = [
      '[core]',
      '\trepositoryformatversion = 0',
      '[remote "origin"]',
      '\turl = git@github.com:qfli/studio.git',
      '\tfetch = +refs/heads/*:refs/remotes/origin/*',
    ].join('\n');
    assert.equal(parseOriginUrl(config), 'git@github.com:qfli/studio.git');
  });

  test('reads an https url with a space around the equals sign', () => {
    const config = '[remote "origin"]\n  url  =  https://example.com/a/b.git\n';
    assert.equal(parseOriginUrl(config), 'https://example.com/a/b.git');
  });

  test('ignores other remotes', () => {
    const config = [
      '[remote "upstream"]',
      '\turl = https://example.com/upstream.git',
      '[remote "origin"]',
      '\turl = https://example.com/origin.git',
    ].join('\n');
    assert.equal(parseOriginUrl(config), 'https://example.com/origin.git');
  });

  test('returns undefined when the repository has no origin', () => {
    assert.equal(parseOriginUrl('[core]\n\tbare = false\n'), undefined);
  });

  test('skips comment lines', () => {
    const config = '[remote "origin"]\n# url = https://example.com/no.git\n';
    assert.equal(parseOriginUrl(config), undefined);
  });
});

describe('parseHead', () => {
  const commit = 'a'.repeat(40);

  test('follows a symbolic head to its branch', () => {
    const result = parseHead(`ref: refs/heads/main\n`, () => `${commit}\n`);
    assert.deepEqual(result, { branch: 'main', head: commit });
  });

  test('reports the branch of a fresh repository without a commit', () => {
    const result = parseHead('ref: refs/heads/master\n', () => null);
    assert.deepEqual(result, { branch: 'master', head: undefined });
  });

  test('reads a detached head', () => {
    const result = parseHead(`${commit}\n`, () => null);
    assert.deepEqual(result, { branch: undefined, head: commit });
  });

  test('keeps the branch name of a nested ref out of the report', () => {
    const result = parseHead('ref: refs/tags/v1\n', () => commit);
    assert.deepEqual(result, { branch: undefined, head: commit });
  });

  test('rejects a garbage commit id', () => {
    const result = parseHead('ref: refs/heads/main\n', () => 'not-a-hash');
    assert.deepEqual(result, { branch: 'main', head: undefined });
  });

  test('lowercases the commit id', () => {
    const result = parseHead(`${'B'.repeat(40)}\n`, () => null);
    assert.equal(result.head, 'b'.repeat(40));
  });
});

describe('readGitInfo', () => {
  let root = '';

  before(async () => {
    root = await mkdtemp(path.join(tmpdir(), 'qfli-git-info-'));
  });

  after(async () => {
    await rm(root, { recursive: true, force: true });
  });

  test('a plain directory is not supported', async () => {
    const dir = path.join(root, 'plain');
    await mkdir(dir, { recursive: true });
    const info = await readGitInfo(dir);
    assert.deepEqual(info, { root: dir, supported: false });
  });

  test('reads a repository without running git', async () => {
    const dir = path.join(root, 'repo');
    const git = path.join(dir, '.git');
    await mkdir(path.join(git, 'refs', 'heads'), { recursive: true });
    await writeFile(
      path.join(git, 'config'),
      '[remote "origin"]\n\turl = https://example.com/repo.git\n',
    );
    await writeFile(path.join(git, 'HEAD'), 'ref: refs/heads/main\n');
    await writeFile(path.join(git, 'refs', 'heads', 'main'), `${'c'.repeat(40)}\n`);
    await writeFile(path.join(git, 'index'), 'x'.repeat(2048));

    const info = await readGitInfo(dir);
    assert.equal(info.supported, true);
    assert.equal(info.remote, 'https://example.com/repo.git');
    assert.equal(info.branch, 'main');
    assert.equal(info.head, 'c'.repeat(40));
    assert.ok((info.gitBytes ?? 0) > 2048, 'gitBytes 统计 .git 目录');
  });

  test('a directory whose .git is a file is not supported', async () => {
    const dir = path.join(root, 'submodule');
    await mkdir(dir, { recursive: true });
    await writeFile(path.join(dir, '.git'), 'gitdir: ../.git/modules/sub\n');
    const info = await readGitInfo(dir);
    assert.deepEqual(info, { root: dir, supported: false });
  });

  test('a repository with no HEAD is not supported', async () => {
    const dir = path.join(root, 'headless');
    await mkdir(path.join(dir, '.git'), { recursive: true });
    const info = await readGitInfo(dir);
    assert.deepEqual(info, { root: dir, supported: false });
  });
});

describe('directoryBytes', () => {
  let root = '';

  before(async () => {
    root = await mkdtemp(path.join(tmpdir(), 'qfli-git-bytes-'));
  });

  after(async () => {
    await rm(root, { recursive: true, force: true });
  });

  test('sums nested files', async () => {
    await mkdir(path.join(root, 'a', 'b'), { recursive: true });
    await writeFile(path.join(root, 'a', 'one.bin'), Buffer.alloc(100));
    await writeFile(path.join(root, 'a', 'b', 'two.bin'), Buffer.alloc(200));
    assert.equal(await directoryBytes(root), 300);
  });

  test('a missing directory counts as zero bytes', async () => {
    assert.equal(await directoryBytes(path.join(root, 'nope')), 0);
  });
});

describe('detectDirty', () => {
  let root = '';

  before(async () => {
    root = await mkdtemp(path.join(tmpdir(), 'qfli-git-dirty-'));
  });

  after(async () => {
    await rm(root, { recursive: true, force: true });
  });

  test('a missing index reports nothing instead of guessing', async () => {
    await mkdir(root, { recursive: true });
    await writeFile(path.join(root, 'HEAD'), 'ref: refs/heads/main\n');
    assert.equal(await detectDirty(root), undefined);
  });

  test('a fresh index marks the tree dirty', async () => {
    const git = path.join(root, 'repo', '.git');
    await mkdir(git, { recursive: true });
    await writeFile(path.join(git, 'HEAD'), 'ref: refs/heads/main\n');
    await new Promise((resolve) => setTimeout(resolve, 20));
    await writeFile(path.join(git, 'index'), 'x');
    assert.equal(await detectDirty(git), true);
  });
});
