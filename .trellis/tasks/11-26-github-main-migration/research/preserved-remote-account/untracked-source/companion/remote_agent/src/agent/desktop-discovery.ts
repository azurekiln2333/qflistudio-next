// Session discovery for the desktop companion page.
//
// Reported problem this file fixes: the sidecar only exposed `bindings`, i.e.
// the streams *this run* bound or created. An empty binding list therefore meant
// "nothing bound yet", and the desktop page showed an empty machine even when
// Herdr workspaces, Claude Code sessions and Codex threads existed.
//
// Discovery asks the agent's existing protocol — the same requests the phone
// uses — instead of adding a second enumerator:
//
//   herdr_workspaces  + herdr_panes  → Herdr panes (screen-polled)
//   list_history                     → Claude Code history for the default cwd
//   codex_projects    + codex_threads→ Codex threads (when the CLI is available)
//
// `bindings` is still consumed, but only to mark entries as already open here.
// Nothing is fabricated: an unavailable tool contributes no entries, and an
// empty result is reported as empty so the page can offer creating a session.

import { HerdrBridge } from './herdr.ts';
import { CodexBridge } from './codex.ts';
import { probeTools, type ToolProbeResult } from './tool-probe.ts';
import type { Logger } from '../shared/log.ts';

/** One row shown in the desktop page's session list. */
export type DiscoveredSession = {
  kind: 'herdr' | 'claude' | 'codex';
  id: string;
  title: string;
  subtitle?: string;
  /** `pane` (polled screen) | `history` (one-shot transcript) | `thread`. */
  origin: 'pane' | 'history' | 'thread';
  /** Working directory required by the provider when opening history. */
  cwd?: string;
  lastUsed?: number;
  bound: boolean;
  /** False when the entry is listed but cannot be opened on this machine. */
  canOpen: boolean;
  /** True when input can actually be delivered through the chosen provider. */
  canAcceptInput: boolean;
};

export type Discovery = {
  sessions: DiscoveredSession[];
  /** Ids this run already holds a stream for. */
  bound: string[];
  /** Kinds whose discovery failed, with the reason, for the page's notice. */
  failures: { kind: string; message: string }[];
};

export type DiscoveryOptions = {
  logger: Logger;
  /** Only used to skip Herdr/Codex when the CLI is absent. */
  probe?: () => Promise<ToolProbeResult[]>;
  claudeHistory?: { list(cwd?: string): Promise<{ sessionId: string; summary: string; cwd?: string; lastModified: number }[]> };
  defaultCwd: string;
  /** Configured project roots. Defaults to the default cwd for old callers. */
  roots?: string[];
};

/** Guard against an endless cursor loop from a misbehaving app-server. */
const MAX_PAGES = 20;

/**
 * Lists every session the companion can actually see.
 *
 * Each source is independent: one failing tool (Herdr daemon stopped, Codex not
 * installed) removes only its own rows and adds one failure line.
 */
export async function discoverSessions(
  opts: DiscoveryOptions,
  bound: ReadonlySet<string>,
): Promise<Discovery> {
  const sessions: DiscoveredSession[] = [];
  const failures: { kind: string; message: string }[] = [];
  // Dedupe by kind + id: the same pane or thread reached through two sources
  // (overlapping roots, a project and its history page) is still one session.
  const seen = new Set<string>();
  const tools = opts.probe ? await opts.probe() : await probeTools({});
  const has = (kind: string) => tools.some((tool) => tool.kind === kind && tool.installed);

  if (has('herdr')) {
    try {
      const herdr = new HerdrBridge({ logger: opts.logger });
      for (const workspace of await herdr.workspaces()) {
        for (const pane of await herdr.panes(workspace.workspaceId)) {
          if (seen.has(`herdr:${pane.paneId}`)) continue;
          seen.add(`herdr:${pane.paneId}`);
          sessions.push({
            kind: 'herdr',
            id: pane.paneId,
            title: pane.terminalTitle || pane.paneId,
            subtitle: `${workspace.label} · ${pane.agent || 'shell'}${pane.cwd ? ` · ${pane.cwd}` : ''}`,
            origin: 'pane',
            bound: bound.has(pane.paneId),
            canOpen: true,
            // Screen polling is read-only by construction.
            canAcceptInput: false,
          });
        }
      }
    } catch (err) {
      failures.push({ kind: 'herdr', message: err instanceof Error ? err.message : String(err) });
    }
  }

  if (has('claude') && opts.claudeHistory) {
    const roots = opts.roots?.length ? opts.roots : [opts.defaultCwd];
    const queried = new Set<string>();
    const errors: unknown[] = [];
    for (const root of roots) {
      if (queried.has(root)) continue;
      queried.add(root);
      try {
        const items = await opts.claudeHistory.list(root);
        for (const item of items) {
          // A session can appear twice when roots overlap or include worktrees.
          if (seen.has(`claude:${item.sessionId}`)) continue;
          seen.add(`claude:${item.sessionId}`);
          sessions.push({
            kind: 'claude',
            id: item.sessionId,
            title: item.summary || item.sessionId,
            subtitle: 'Claude Code 历史记录',
            origin: 'history',
            cwd: item.cwd || root,
            lastUsed: item.lastModified,
            bound: bound.has(item.sessionId),
            canOpen: true,
            // Transcript replay only: the history loader is read-only.
            canAcceptInput: false,
          });
        }
      } catch (err) {
        errors.push(err);
      }
    }
    if (errors.length) {
      const first = errors[0];
      failures.push({ kind: 'claude', message: first instanceof Error ? first.message : String(first) });
    }
  }

  if (has('codex')) {
    // Codex threads come from the agent's own app-server history API; the
    // bridge is closed immediately after listing so discovery never holds a
    // child process open.
    const codex = new CodexBridge();
    try {
      // Follow `nextCursor` on both listings: a machine with many projects or
      // threads would otherwise show only the first page and look empty.
      const projects: { id: string; title: string }[] = [];
      let projectCursor: string | undefined;
      for (let pageNo = 0; pageNo < MAX_PAGES; pageNo += 1) {
        const page = await codex.projects(projectCursor);
        for (const project of page.projects ?? []) projects.push(project);
        projectCursor = page.nextCursor;
        if (!projectCursor) break;
      }
      for (const project of projects) {
        let threadCursor: string | undefined;
        for (let pageNo = 0; pageNo < MAX_PAGES; pageNo += 1) {
          const page = await codex.threads(project.id, threadCursor);
          for (const thread of page.threads ?? []) {
            if (seen.has(`codex:${thread.id}`)) continue;
            seen.add(`codex:${thread.id}`);
            sessions.push({
              kind: 'codex',
              id: thread.id,
              title: thread.title || thread.id,
              subtitle: `Codex · ${project.title}`,
              origin: 'thread',
              lastUsed: thread.updatedAt,
              bound: bound.has(thread.id),
              // Every thread the app-server can read is openable: `read()` needs
              // no control rights. Input alone depends on `canAcceptDirectInput`.
              canOpen: true,
              canAcceptInput: thread.canAcceptDirectInput === true,
            });
          }
          threadCursor = page.nextCursor;
          if (!threadCursor) break;
        }
      }
    } catch (err) {
      failures.push({ kind: 'codex', message: err instanceof Error ? err.message : String(err) });
    } finally {
      codex.close();
    }
  }

  return { sessions, bound: [...bound], failures };
}
