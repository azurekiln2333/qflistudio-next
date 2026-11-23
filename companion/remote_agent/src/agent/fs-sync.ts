// Manifest and chunked reads for projects that have no git repository.
//
// The phone asks what the directory contains, compares that with what it
// already has, and then asks for the bytes of the files that changed. Nothing
// here writes to the project: the agent only reads.
//
// Two rules keep the transfer honest:
//   * the ignore table is data with a version, so both ends can tell whether
//     they are talking about the same set of files;
//   * every path is resolved through `realpath` before it is read, so a symlink
//     inside the project cannot reach a file outside it.

import { createHash } from 'node:crypto';
import { createReadStream } from 'node:fs';
import { lstat, readdir, realpath } from 'node:fs/promises';
import path from 'node:path';

/** Largest slice the agent sends in one `fs_chunk`. */
export const FS_CHUNK_BYTES = 512 * 1024;

/** Above this many entries the manifest is cut and flagged. */
export const FS_MANIFEST_MAX_ENTRIES = 20000;

/** Version of the ignore table below. Bumping it invalidates stored manifests. */
export const FS_IGNORE_VERSION = 1;

export type FsEntryKind = 'file' | 'dir';

export type FsEntry = {
  /** Posix relative path, `/` separated, no leading slash. */
  path: string;
  kind: FsEntryKind;
  /** Bytes for a file, 0 for a directory. */
  size: number;
  /** Lowercase hex sha256 of the file bytes, '' for a directory. */
  hash: string;
};

export type FsManifest = {
  root: string;
  ignoreVersion: number;
  entries: FsEntry[];
  truncated: boolean;
};

/** Directory names skipped at any depth. */
export const FS_IGNORE_DIRS: readonly string[] = [
  // dependencies
  'node_modules',
  '.venv',
  'pods',
  '.gradle',
  // build outputs
  'build',
  'dist',
  'out',
  'target',
  '.dart_tool',
  'deriveddata',
  '.next',
  // caches
  '__pycache__',
  '.cache',
  // logs
  'logs',
  // harness transcripts, named instead of globbing *.jsonl project wide
  'agent_sessions',
  'transcripts',
  // version control
  '.git',
];

/** File suffixes skipped at any depth. */
export const FS_IGNORE_SUFFIXES: readonly string[] = ['.pyc', '.log'];

/**
 * Whether a directory entry is skipped by version 1 of the table.
 *
 * Matching ignores case: Windows and macOS keep the ignore-table names with
 * their own casing (`Pods`, `DerivedData`), and a phone that kept them while
 * the computer dropped them would re-download those trees on every sync.
 */
export function isIgnoredDir(name: string): boolean {
  return FS_IGNORE_DIRS.includes(name.toLowerCase());
}

/** Whether a file entry is skipped by version 1 of the table. */
export function isIgnoredFile(name: string): boolean {
  const lower = name.toLowerCase();
  return FS_IGNORE_SUFFIXES.some((suffix) => lower.endsWith(suffix));
}

/**
 * Turn a client path into a safe relative path, or throw.
 *
 * Rejects what a path inside a project can never be: an absolute path, a `..`
 * segment, a backslash, a drive colon and control characters.
 */
export function safeRelativePath(rel: unknown): string {
  if (typeof rel !== 'string' || !rel.trim()) throw new Error('路径为空');
  const text = rel.trim();
  // eslint-disable-next-line no-control-regex
  if (/[\u0000-\u001f\u007f]/.test(text)) throw new Error('路径包含控制字符');
  if (text.includes('\\')) throw new Error('路径不能包含反斜杠');
  if (text.includes(':')) throw new Error('路径不能包含冒号');
  if (text.startsWith('/')) throw new Error('路径不能是绝对路径');
  const parts = text.split('/');
  if (parts.some((part) => part === '..')) throw new Error('路径不能包含上级引用');
  if (parts.some((part) => part === '')) throw new Error('路径不能包含空段');
  return parts.join('/');
}

/**
 * Resolve [rel] inside [root], following symlinks, and refuse anything that
 * lands outside the root afterwards.
 */
export async function resolveInside(root: string, rel: string): Promise<string> {
  const safe = safeRelativePath(rel);
  const realRoot = await realpath(root);
  const target = await realpath(path.join(realRoot, safe));
  const relative = path.relative(realRoot, target);
  if (relative === '' || relative.startsWith('..') || path.isAbsolute(relative)) {
    throw new Error(`路径不在项目目录内：${safe}`);
  }
  return target;
}

/** sha256 of a file, read as a stream so a large file is never held in memory. */
export function hashFile(file: string): Promise<string> {
  return new Promise((resolve, reject) => {
    const hash = createHash('sha256');
    const stream = createReadStream(file);
    stream.on('error', reject);
    stream.on('data', (chunk) => hash.update(chunk));
    stream.on('end', () => resolve(hash.digest('hex')));
  });
}

/**
 * Walk [root] and describe every file and directory the phone should know
 * about.
 *
 * Symlinks are skipped entirely rather than followed: the phone cannot recreate
 * one, and following it could report a file that lives outside the project.
 */
export async function buildManifest(
  root: string,
  options: { maxEntries?: number; ignoreVersion?: number } = {},
): Promise<FsManifest> {
  const maxEntries = options.maxEntries ?? FS_MANIFEST_MAX_ENTRIES;
  const ignoreVersion = options.ignoreVersion ?? FS_IGNORE_VERSION;
  const entries: FsEntry[] = [];
  let truncated = false;

  const queue: Array<{ abs: string; rel: string }> = [{ abs: root, rel: '' }];
  while (queue.length > 0) {
    const current = queue.shift()!;
    const dirents = await readdir(current.abs, { withFileTypes: true }).catch(() => null);
    if (!dirents) continue;
    dirents.sort((a, b) => a.name.localeCompare(b.name));
    for (const entry of dirents) {
      const rel = current.rel ? `${current.rel}/${entry.name}` : entry.name;
      if (entry.isSymbolicLink()) continue;
      if (entry.isDirectory()) {
        if (isIgnoredDir(entry.name)) continue;
        if (entries.length >= maxEntries) {
          truncated = true;
          return { root, ignoreVersion, entries, truncated };
        }
        entries.push({ path: rel, kind: 'dir', size: 0, hash: '' });
        queue.push({ abs: path.join(current.abs, entry.name), rel });
        continue;
      }
      if (!entry.isFile()) continue;
      if (isIgnoredFile(entry.name)) continue;
      if (entries.length >= maxEntries) {
        truncated = true;
        return { root, ignoreVersion, entries, truncated };
      }
      const abs = path.join(current.abs, entry.name);
      const info = await lstat(abs).catch(() => null);
      if (!info) continue;
      entries.push({ path: rel, kind: 'file', size: info.size, hash: await hashFile(abs) });
    }
  }
  return { root, ignoreVersion, entries, truncated };
}

export type FsChunk = {
  path: string;
  offset: number;
  base64: string;
  eof: boolean;
};

/**
 * Read one slice of a file inside [root].
 *
 * The reply carries at most [FS_CHUNK_BYTES]; a longer request is clamped, so
 * the frame stays under the relay limit whatever the client asks for.
 */
export async function readChunk(
  root: string,
  rel: string,
  offset: number,
  length?: number,
): Promise<FsChunk> {
  const safe = safeRelativePath(rel);
  if (!Number.isInteger(offset) || offset < 0) throw new Error('偏移量无效');
  const wanted = Number.isInteger(length) && (length as number) > 0
    ? Math.min(length as number, FS_CHUNK_BYTES)
    : FS_CHUNK_BYTES;

  const target = await resolveInside(root, safe);
  const info = await lstat(target).catch(() => null);
  if (!info?.isFile()) throw new Error(`不是普通文件：${safe}`);
  if (offset > info.size) throw new Error('偏移量超出文件长度');

  const bytes = await readRange(target, offset, wanted);
  return {
    path: safe,
    offset,
    base64: bytes.toString('base64'),
    eof: offset + bytes.length >= info.size,
  };
}

function readRange(file: string, offset: number, length: number): Promise<Buffer> {
  return new Promise((resolve, reject) => {
    const parts: Buffer[] = [];
    const stream = createReadStream(file, { start: offset, end: offset + length - 1 });
    stream.on('error', reject);
    stream.on('data', (chunk) => parts.push(Buffer.from(chunk)));
    stream.on('end', () => resolve(Buffer.concat(parts)));
  });
}
