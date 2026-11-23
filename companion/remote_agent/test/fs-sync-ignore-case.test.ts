// The ignore table must match regardless of case.
//
// Both ends keep the same table, but the phone lowercases nothing: if the
// computer treated `pods/` as a source directory while the phone ignored
// `Pods/`, every sync would re-download or re-delete the same tree. Windows and
// macOS spell these names with capitals, so the comparison cannot be exact.

import assert from 'node:assert/strict';
import { mkdtemp, mkdir, rm, writeFile } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import path from 'node:path';
import { after, before, describe, test } from 'node:test';

import {
  buildManifest,
  isIgnoredDir,
  isIgnoredFile,
} from '../src/agent/fs-sync.ts';

describe('ignore table case', () => {
  test('a directory is skipped whatever its casing', () => {
    for (const name of ['Pods', 'pods', 'PODS', 'DerivedData', 'deriveddata']) {
      assert.equal(isIgnoredDir(name), true, name);
    }
  });

  test('a suffix is skipped whatever its casing', () => {
    assert.equal(isIgnoredFile('a.PYC'), true);
    assert.equal(isIgnoredFile('server.LOG'), true);
  });

  test('a name that only looks similar is kept', () => {
    for (const name of ['podspec', 'building', 'outbox']) {
      assert.equal(isIgnoredDir(name), false, name);
    }
  });
});

describe('buildManifest case', () => {
  let root: string;

  before(async () => {
    root = await mkdtemp(path.join(tmpdir(), 'qfli-fs-case-'));
  });

  after(async () => {
    await rm(root, { recursive: true, force: true });
  });

  test('never enters a dependency directory spelled with capitals', async () => {
    await mkdir(path.join(root, 'Pods', 'Thing'), { recursive: true });
    await writeFile(path.join(root, 'Pods', 'Thing', 'a.m'), 'x');
    await mkdir(path.join(root, 'lib'), { recursive: true });
    await writeFile(path.join(root, 'lib', 'a.dart'), 'y');

    const manifest = await buildManifest(root);
    const paths = manifest.entries.map((entry) => entry.path);

    assert.deepEqual(paths, ['lib', 'lib/a.dart']);
  });
});
