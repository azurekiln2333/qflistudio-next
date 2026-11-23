import assert from 'node:assert/strict';
import { createHash } from 'node:crypto';
import { mkdir, mkdtemp, rm, symlink, writeFile } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import path from 'node:path';
import { after, before, describe, test } from 'node:test';

import {
  FS_CHUNK_BYTES,
  buildManifest,
  hashFile,
  isIgnoredDir,
  isIgnoredFile,
  readChunk,
  resolveInside,
  safeRelativePath,
} from '../src/agent/fs-sync.ts';

const sha256 = (text: string) => createHash('sha256').update(text).digest('hex');

describe('safeRelativePath', () => {
  test('keeps a nested posix path', () => {
    assert.equal(safeRelativePath('src/app/main.dart'), 'src/app/main.dart');
  });

  test('trims surrounding space', () => {
    assert.equal(safeRelativePath('  a/b.txt  '), 'a/b.txt');
  });

  for (const bad of ['', '   ', '/etc/passwd', 'a/../b', '../x', 'a\\b', 'C:/x', 'a//b']) {
    test(`rejects ${JSON.stringify(bad)}`, () => {
      assert.throws(() => safeRelativePath(bad));
    });
  }

  test('rejects a control character', () => {
    assert.throws(() => safeRelativePath('a/\u0000b'));
  });

  test('rejects a non-string', () => {
    assert.throws(() => safeRelativePath(42 as unknown as string));
  });
});

describe('ignore table', () => {
  test('drops dependency and build directories', () => {
    for (const name of ['node_modules', '.venv', 'Pods', '.gradle', 'build', 'dist', 'out', 'target', '.dart_tool', 'DerivedData', '.next']) {
      assert.equal(isIgnoredDir(name), true, name);
    }
  });

  test('drops caches, logs and transcripts', () => {
    for (const name of ['__pycache__', '.cache', 'logs', 'agent_sessions', 'transcripts', '.git']) {
      assert.equal(isIgnoredDir(name), true, name);
    }
  });

  test('keeps ordinary source directories', () => {
    for (const name of ['src', 'lib', 'test', 'assets']) {
      assert.equal(isIgnoredDir(name), false, name);
    }
  });

  test('drops compiled python and log files', () => {
    assert.equal(isIgnoredFile('a.pyc'), true);
    assert.equal(isIgnoredFile('server.log'), true);
  });

  test('does not drop jsonl transcripts project wide', () => {
    assert.equal(isIgnoredFile('notes.jsonl'), false);
  });
});

describe('buildManifest', () => {
  let root = '';

  before(async () => {
    root = await mkdtemp(path.join(tmpdir(), 'qfli-fs-manifest-'));
    await mkdir(path.join(root, 'lib'), { recursive: true });
    await writeFile(path.join(root, 'README.md'), '# hello');
    await writeFile(path.join(root, 'lib', 'main.dart'), 'void main() {}');
    await mkdir(path.join(root, 'node_modules', 'left-pad'), { recursive: true });
    await writeFile(path.join(root, 'node_modules', 'left-pad', 'index.js'), 'x');
    await mkdir(path.join(root, 'build'), { recursive: true });
    await writeFile(path.join(root, 'build', 'out.bin'), 'x');
    await mkdir(path.join(root, '.git'), { recursive: true });
    await writeFile(path.join(root, '.git', 'HEAD'), 'ref: refs/heads/main\n');
    await writeFile(path.join(root, 'server.log'), 'noise');
    await writeFile(path.join(root, 'notes.jsonl'), '{}');
  });

  after(async () => {
    await rm(root, { recursive: true, force: true });
  });

  test('lists project files with sizes and hashes', async () => {
    const manifest = await buildManifest(root);
    const paths = manifest.entries.map((entry) => entry.path).sort();
    assert.deepEqual(paths, ['README.md', 'lib', 'lib/main.dart', 'notes.jsonl']);
    const readme = manifest.entries.find((entry) => entry.path === 'README.md');
    assert.equal(readme?.kind, 'file');
    assert.equal(readme?.size, 7);
    assert.equal(readme?.hash, sha256('# hello'));
  });

  test('skips an ignored file suffix', async () => {
    const manifest = await buildManifest(root);
    assert.equal(
      manifest.entries.some((entry) => entry.path === 'server.log'),
      false,
    );
  });

  test('reports the ignore version', async () => {
    const manifest = await buildManifest(root);
    assert.equal(manifest.ignoreVersion, 1);
    assert.equal(manifest.truncated, false);
    assert.equal(manifest.root, root);
  });

  test('marks directories with an empty hash', async () => {
    const manifest = await buildManifest(root);
    const dir = manifest.entries.find((entry) => entry.path === 'lib');
    assert.equal(dir?.kind, 'dir');
    assert.equal(dir?.size, 0);
    assert.equal(dir?.hash, '');
  });

  test('never enters an ignored directory', async () => {
    const manifest = await buildManifest(root);
    const paths = manifest.entries.map((entry) => entry.path);
    assert.equal(paths.some((p) => p.startsWith('node_modules')), false);
    assert.equal(paths.some((p) => p.startsWith('build')), false);
    assert.equal(paths.some((p) => p.startsWith('.git')), false);
  });

  test('cuts the walk at the entry cap and flags it', async () => {
    const manifest = await buildManifest(root, { maxEntries: 2 });
    assert.equal(manifest.entries.length, 2);
    assert.equal(manifest.truncated, true);
  });

  test('skips a symlink instead of following it', async () => {
    const dir = await mkdtemp(path.join(tmpdir(), 'qfli-fs-link-'));
    try {
      await writeFile(path.join(dir, 'real.txt'), 'real');
      await symlink(path.join(dir, 'real.txt'), path.join(dir, 'link.txt'));
      const manifest = await buildManifest(dir);
      assert.deepEqual(manifest.entries.map((e) => e.path), ['real.txt']);
    } finally {
      await rm(dir, { recursive: true, force: true });
    }
  });
});

describe('resolveInside', () => {
  let root = '';

  before(async () => {
    root = await mkdtemp(path.join(tmpdir(), 'qfli-fs-resolve-'));
    await writeFile(path.join(root, 'inside.txt'), 'ok');
  });

  after(async () => {
    await rm(root, { recursive: true, force: true });
  });

  test('resolves a file inside the root', async () => {
    const resolved = await resolveInside(root, 'inside.txt');
    assert.equal(path.basename(resolved), 'inside.txt');
  });

  test('refuses a symlink that points outside the root', async () => {
    const outside = await mkdtemp(path.join(tmpdir(), 'qfli-fs-outside-'));
    try {
      await writeFile(path.join(outside, 'secret.txt'), 'secret');
      await symlink(path.join(outside, 'secret.txt'), path.join(root, 'escape.txt'));
      await assert.rejects(() => resolveInside(root, 'escape.txt'));
    } finally {
      await rm(outside, { recursive: true, force: true });
    }
  });

  test('refuses the root itself', async () => {
    await assert.rejects(() => resolveInside(root, '.'));
  });
});

describe('readChunk', () => {
  let root = '';
  const body = 'abcdefghij';

  before(async () => {
    root = await mkdtemp(path.join(tmpdir(), 'qfli-fs-chunk-'));
    await writeFile(path.join(root, 'data.txt'), body);
    await mkdir(path.join(root, 'folder'), { recursive: true });
  });

  after(async () => {
    await rm(root, { recursive: true, force: true });
  });

  test('reads a slice and marks the end', async () => {
    const chunk = await readChunk(root, 'data.txt', 0, 4);
    assert.equal(chunk.offset, 0);
    assert.equal(Buffer.from(chunk.base64, 'base64').toString(), 'abcd');
    assert.equal(chunk.eof, false);
  });

  test('marks eof on the last slice', async () => {
    const chunk = await readChunk(root, 'data.txt', 6, 4);
    assert.equal(Buffer.from(chunk.base64, 'base64').toString(), 'ghij');
    assert.equal(chunk.eof, true);
  });

  test('a missing length reads the whole file', async () => {
    const chunk = await readChunk(root, 'data.txt', 0);
    assert.equal(Buffer.from(chunk.base64, 'base64').toString(), body);
    assert.equal(chunk.eof, true);
  });

  test('clamps a request above the chunk size', async () => {
    const chunk = await readChunk(root, 'data.txt', 0, FS_CHUNK_BYTES * 4);
    assert.equal(Buffer.from(chunk.base64, 'base64').length, body.length);
  });

  test('rejects a negative offset', async () => {
    await assert.rejects(() => readChunk(root, 'data.txt', -1));
  });

  test('rejects an offset past the end', async () => {
    await assert.rejects(() => readChunk(root, 'data.txt', 99));
  });

  test('rejects a directory', async () => {
    await assert.rejects(() => readChunk(root, 'folder', 0));
  });

  test('rejects a path that escapes the root', async () => {
    await assert.rejects(() => readChunk(root, '../data.txt', 0));
  });
});

describe('hashFile', () => {
  let root = '';

  before(async () => {
    root = await mkdtemp(path.join(tmpdir(), 'qfli-fs-hash-'));
  });

  after(async () => {
    await rm(root, { recursive: true, force: true });
  });

  test('hashes the bytes, not the name', async () => {
    const file = path.join(root, 'a.bin');
    await writeFile(file, 'abc');
    assert.equal(await hashFile(file), sha256('abc'));
  });
});
