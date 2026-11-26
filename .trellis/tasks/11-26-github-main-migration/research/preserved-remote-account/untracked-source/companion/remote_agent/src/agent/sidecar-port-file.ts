// Ownership rules for the sidecar's published attach file.
//
// Why this is its own module: `sidecar.ts` starts a server at import time and
// cannot be unit-tested, while the *deletion* rule is the risky part — it runs
// against a caller-supplied path (`--port-file`) on every shutdown.
//
// A stale attach file is worse than none: the next launch would read an old port
// and token, connect to a dead socket, and — because the port may since have been
// reused — could even reach an unrelated listener. So the file is removed on exit,
// but only when all three conditions hold:
//
//   1. this process wrote it (`ownership` is set);
//   2. it still contains *our* port and token — if another companion replaced it,
//      that instance is live and must keep its record;
//   3. it is a regular file, not a symlink, at exactly the resolved path.

import { randomUUID } from 'node:crypto';
import { link, mkdir, open, unlink } from 'node:fs/promises';
import { lstatSync, readFileSync, rmSync } from 'node:fs';
import path from 'node:path';

/** The document the companion publishes for a desktop app to attach with. */
export type PortFileDocument = {
  port: number;
  token: string;
};

/** What this process published, if anything. */
export type PortFileOwnership = {
  /** Absolute path that was written. */
  path: string;
  port: number;
  token: string;
};

/** Publishes a complete port file without following or replacing a destination. */
export async function createPortFile(target: string, port: number, token: string): Promise<PortFileOwnership> {
  const resolved = path.resolve(target);
  const temporary = `${resolved}.${process.pid}.${randomUUID()}.tmp`;
  await mkdir(path.dirname(resolved), { recursive: true, mode: 0o700 });
  const handle = await open(temporary, 'wx', 0o600);
  try {
    await handle.writeFile(`${JSON.stringify({ port, token })}\n`, 'utf8');
    await handle.chmod(0o600).catch(() => {});
    await handle.sync();
    await link(temporary, resolved);
    return { path: resolved, port, token };
  } finally {
    await handle.close();
    await unlink(temporary).catch(() => {});
  }
}

/** Parses a published document; returns undefined for anything malformed. */
export function parsePortFile(raw: string): PortFileDocument | undefined {
  let parsed: unknown;
  try {
    parsed = JSON.parse(raw) as unknown;
  } catch {
    return undefined;
  }
  if (!parsed || typeof parsed !== 'object') return undefined;
  const value = parsed as Record<string, unknown>;
  const port = value.port;
  const token = value.token;
  if (typeof port !== 'number' || !Number.isInteger(port) || port < 1 || port > 65535) return undefined;
  if (typeof token !== 'string' || token.length === 0) return undefined;
  return { port, token };
}

/**
 * Whether [target] still holds exactly this process's port and token.
 *
 * Symlinks are rejected: following one would let a planted link make the
 * shutdown delete a file outside the path the launcher chose.
 */
export function isOwnedPortFile(target: string, port: number, token: string): boolean {
  try {
    const stat = lstatSync(target);
    if (!stat.isFile() || stat.isSymbolicLink()) return false;
    const document = parsePortFile(readFileSync(target, 'utf8'));
    if (!document) return false;
    // A plain comparison is correct here: this is a local ownership check, not a
    // credential verification. The constant-time compare lives in sidecar.ts,
    // where an untrusted peer supplies the value.
    return document.port === port && document.token === token;
  } catch {
    return false;
  }
}

/**
 * Removes the published file if it is still ours.
 *
 * Never throws: shutdown must proceed even when the file is already gone, was
 * replaced by another instance, or the directory became read-only. Returns true
 * only when a file was actually deleted.
 */
export function removePortFileIfOwned(ownership: PortFileOwnership | undefined): boolean {
  if (!ownership) return false;
  if (!isOwnedPortFile(ownership.path, ownership.port, ownership.token)) return false;
  try {
    rmSync(ownership.path, { force: true });
    return true;
  } catch {
    return false;
  }
}
