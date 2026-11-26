// Attach-file ownership: the sidecar must delete its own published
// `{port, token}` document on shutdown, and must delete nothing else.
//
// The risk this covers is concrete: `--port-file` is a caller-supplied path in a
// directory that persists across runs. Leaving the file behind makes the next
// launch attach to a dead port — or, if the port was reused, to an unrelated
// listener — while an unconditional delete could destroy a *live* companion's
// handshake. These cases are pure filesystem behaviour, so they need no server,
// no relay and no tool CLIs.

import assert from 'node:assert/strict';
import { mkdtempSync, rmSync, symlinkSync, writeFileSync, readFileSync, existsSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { after, describe, it } from 'node:test';

import {
  createPortFile,
  isOwnedPortFile,
  parsePortFile,
  removePortFileIfOwned,
} from '../src/agent/sidecar-port-file.ts';

const scratch = mkdtempSync(join(tmpdir(), 'qfli-portfile-'));
after(() => rmSync(scratch, { recursive: true, force: true }));

let counter = 0;
function tempFile(contents: string): string {
  counter += 1;
  const file = join(scratch, `sidecar-${counter}.json`);
  writeFileSync(file, contents, { encoding: 'utf8', mode: 0o600 });
  return file;
}

const PORT = 51234;
const TOKEN = 'attach-token-value';
const DOCUMENT = `${JSON.stringify({ port: PORT, token: TOKEN })}\n`;

describe('parsePortFile', () => {
  it('reads a well-formed document', () => {
    assert.deepEqual(parsePortFile(DOCUMENT), { port: PORT, token: TOKEN });
  });

  it('rejects a document without a token: a port is not an identity', () => {
    assert.equal(parsePortFile(`{"port":${PORT}}`), undefined);
    assert.equal(parsePortFile(`{"port":${PORT},"token":""}`), undefined);
  });

  it('rejects out-of-range ports and malformed JSON', () => {
    assert.equal(parsePortFile('{"port":0,"token":"t"}'), undefined);
    assert.equal(parsePortFile('{"port":70000,"token":"t"}'), undefined);
    assert.equal(parsePortFile('not json'), undefined);
  });
});

describe('removePortFileIfOwned', () => {
  it('removes the file this process published', () => {
    const file = tempFile(DOCUMENT);
    assert.equal(isOwnedPortFile(file, PORT, TOKEN), true);

    assert.equal(removePortFileIfOwned({ path: file, port: PORT, token: TOKEN }), true);
    assert.equal(existsSync(file), false);
  });

  it('keeps a file another companion replaced, so a live instance keeps working', () => {
    const file = tempFile(`${JSON.stringify({ port: 51999, token: 'other-instance-token' })}\n`);

    assert.equal(removePortFileIfOwned({ path: file, port: PORT, token: TOKEN }), false);
    assert.equal(existsSync(file), true);
    // The foreign document is untouched, not rewritten.
    assert.match(readFileSync(file, 'utf8'), /other-instance-token/);
  });

  it('keeps a file whose port matches but token differs', () => {
    const file = tempFile(`${JSON.stringify({ port: PORT, token: 'different-token' })}\n`);
    assert.equal(removePortFileIfOwned({ path: file, port: PORT, token: TOKEN }), false);
    assert.equal(existsSync(file), true);
  });

  it('does nothing when this process published no file', () => {
    assert.equal(removePortFileIfOwned(undefined), false);
  });

  it('tolerates a file that is already gone', () => {
    const file = join(scratch, 'never-written.json');
    assert.equal(removePortFileIfOwned({ path: file, port: PORT, token: TOKEN }), false);
  });

  it('refuses to follow a symlink, so a planted link cannot redirect the delete', () => {
    const target = tempFile(DOCUMENT);
    const link = join(scratch, 'link.json');
    try {
      symlinkSync(target, link);
    } catch {
      // Windows without developer mode cannot create symlinks; the case is
      // covered by the lstat guard on platforms that can.
      return;
    }

    assert.equal(removePortFileIfOwned({ path: link, port: PORT, token: TOKEN }), false);
    assert.equal(existsSync(target), true);
  });
});

describe('createPortFile', () => {
  it('publishes a private document and refuses to replace an existing file', async () => {
    const file = join(scratch, 'published.json');
    const ownership = await createPortFile(file, PORT, TOKEN);
    assert.deepEqual(JSON.parse(readFileSync(file, 'utf8')), { port: PORT, token: TOKEN });
    assert.equal(ownership.path, file);

    await assert.rejects(createPortFile(file, 51999, 'other-token'));
    assert.deepEqual(JSON.parse(readFileSync(file, 'utf8')), { port: PORT, token: TOKEN });
  });

  it('refuses a symlink destination without changing its target', async () => {
    const target = tempFile('keep this file');
    const link = join(scratch, 'published-link.json');
    try {
      symlinkSync(target, link);
    } catch {
      return;
    }

    await assert.rejects(createPortFile(link, PORT, TOKEN));
    assert.equal(readFileSync(target, 'utf8'), 'keep this file');
  });
});
