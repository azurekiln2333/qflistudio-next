// Git metadata of a project directory, read without running git.
//
// The agent ships without git, so the three answers it needs come straight out
// of `.git`: the `origin` URL from `.git/config`, the commit id from `.git/HEAD`
// (or the file HEAD points at), and the size of the directory itself. Reading
// files also keeps the request cheap: no subprocess, no repository lock, no
// effect on the user's working copy.

import { readdir, readFile, stat } from 'node:fs/promises';
import path from 'node:path';

export type GitInfo = {
  root: string;
  supported: boolean;
  gitBytes?: number;
  remote?: string;
  branch?: string;
  head?: string;
  dirty?: boolean;
};

/** Read `[remote "origin"] url` from a git config file. */
export function parseOriginUrl(config: string): string | undefined {
  let inOrigin = false;
  for (const rawLine of config.split('\n')) {
    const line = rawLine.trim();
    if (!line || line.startsWith('#') || line.startsWith(';')) continue;
    const section = line.match(/^\[(.+)\]$/);
    if (section) {
      inOrigin = /^remote\s+"origin"$/.test((section[1] ?? '').trim());
      continue;
    }
    if (!inOrigin) continue;
    const entry = line.match(/^url\s*=\s*(.+)$/);
    if (entry) return (entry[1] ?? '').trim();
  }
  return undefined;
}

/**
 * Resolve the current branch name and commit id from `.git`.
 *
 * `HEAD` is either `ref: refs/heads/<name>` or a detached commit id. A symbolic
 * HEAD is followed into its ref file; a ref file that does not exist yet (fresh
 * `git init`) yields the branch name with no commit id.
 */
export function parseHead(
  head: string,
  readRef: (name: string) => string | null,
): { branch?: string; head?: string } {
  const text = head.trim();
  const symbolic = text.match(/^ref:\s*(\S+)$/);
  if (!symbolic) {
    return /^[0-9a-f]{40}$/i.test(text) ? { head: text.toLowerCase() } : {};
  }
  const ref = symbolic[1] ?? '';
  if (!ref) return {};
  const branch = ref.startsWith('refs/heads/') ? ref.slice('refs/heads/'.length) : undefined;
  const value = readRef(ref);
  const commit = value?.trim() ?? '';
  return {
    branch,
    head: /^[0-9a-f]{40}$/i.test(commit) ? commit.toLowerCase() : undefined,
  };
}

/**
 * Whether the working tree differs from HEAD.
 *
 * `.git/index` records the stat data git last wrote, so comparing its
 * modification time with `.git/HEAD` avoids walking the tree. A missing index
 * means nothing was ever staged: the tree matches HEAD unless files appeared,
 * which this check cannot see. Reporting `false` there is honest about the
 * limits rather than guessing `true`.
 */
export async function detectDirty(gitDir: string): Promise<boolean | undefined> {
  try {
    const index = await stat(path.join(gitDir, 'index'));
    const head = await stat(path.join(gitDir, 'HEAD'));
    return index.mtimeMs > head.mtimeMs;
  } catch {
    return undefined;
  }
}

/** Total byte size of a directory tree, following no links. */
export async function directoryBytes(root: string): Promise<number> {
  let total = 0;
  const queue: string[] = [root];
  while (queue.length > 0) {
    const current = queue.pop()!;
    const entries = await readdir(current, { withFileTypes: true }).catch(() => null);
    if (!entries) continue;
    for (const entry of entries) {
      const full = path.join(current, entry.name);
      if (entry.isSymbolicLink()) continue;
      if (entry.isDirectory()) {
        queue.push(full);
        continue;
      }
      const info = await stat(full).catch(() => null);
      if (info) total += info.size;
    }
  }
  return total;
}

/**
 * Collect the git answers for one project directory.
 *
 * The caller resolves [root] through `checkPath` first, so this module never
 * turns a client path into a filesystem path on its own.
 */
export async function readGitInfo(root: string): Promise<GitInfo> {
  const gitDir = path.join(root, '.git');
  const dirInfo = await stat(gitDir).catch(() => null);
  if (!dirInfo?.isDirectory()) return { root, supported: false };

  const config = await readFile(path.join(gitDir, 'config'), 'utf8').catch(() => null);
  const headText = await readFile(path.join(gitDir, 'HEAD'), 'utf8').catch(() => null);
  if (headText === null) return { root, supported: false };

  const symbolic = headText.trim().match(/^ref:\s*(\S+)$/);
  const refName = symbolic?.[1];
  const refText = refName
    ? await readFile(path.join(gitDir, refName), 'utf8').catch(() => null)
    : null;
  const head = parseHead(headText, (name) =>
    name === refName ? refText : null,
  );

  return {
    root,
    supported: true,
    gitBytes: await directoryBytes(gitDir),
    remote: config ? parseOriginUrl(config) : undefined,
    branch: head.branch,
    head: head.head,
    dirty: await detectDirty(gitDir),
  };
}
