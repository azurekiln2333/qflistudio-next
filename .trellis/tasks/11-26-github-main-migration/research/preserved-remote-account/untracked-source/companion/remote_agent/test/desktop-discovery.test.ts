// Desktop session discovery (`src/agent/desktop-discovery.ts`).
//
// Discovery is the feature that lets the desktop page list sessions that
// already exist instead of only the streams this run happened to bind. Three
// properties matter and none of them needs a real tool:
//
//   * every row keeps its real source (pane / history / thread) and real id;
//   * `bound` is decoration from the caller's set, never a filter;
//   * one broken provider removes only its own rows and adds one failure line,
//     and an empty provider result fabricates nothing.
//
// The tool probe and the Claude history listing are injected. Herdr and Codex
// are replaced with `mock.method` on the prototype, so neither the Herdr CLI,
// the Herdr socket, nor the Codex app-server proxy is ever spawned: the prod
// constructors only assign fields.

import assert from 'node:assert/strict';
import { afterEach, beforeEach, describe, test } from 'node:test';
import { mock } from 'node:test';

import { discoverSessions, type DiscoveryOptions, type DiscoveredSession } from '../src/agent/desktop-discovery.ts';
import { CodexBridge } from '../src/agent/codex.ts';
import { HerdrBridge } from '../src/agent/herdr.ts';
import { silentLogger } from '../src/shared/log.ts';
import type { CodexProject, CodexThread } from '../src/shared/protocol.ts';
import type { ToolProbeResult } from '../src/agent/tool-probe.ts';

type Origin = DiscoveredSession['origin'];

const DEFAULT_CWD = 'C:\\work\\desktop-discovery-test';

/** A probe answer that only reports the tools a case wants to be installed. */
function probeOf(...kinds: Array<'herdr' | 'claude' | 'codex'>): () => Promise<ToolProbeResult[]> {
  const all: Array<'herdr' | 'claude' | 'codex'> = ['herdr', 'claude', 'codex'];
  return async () =>
    all.map((kind) => ({
      kind,
      installed: kinds.includes(kind),
      daemonRunning: kinds.includes(kind),
    }));
}

function historyOf(
  sessions: Array<{ sessionId: string; summary: string; cwd?: string; lastModified: number }>,
  calls?: Array<string | undefined>,
) {
  return {
    async list(cwd?: string) {
      calls?.push(cwd);
      return sessions;
    },
  };
}

type HerdrFixture = {
  workspaces?: Array<{ workspace_id: string; label?: string; pane_count?: number }>;
  /** Panes per workspace id; a missing workspace yields no panes. */
  panes?: Record<string, Array<Record<string, unknown>>>;
  failWorkspaces?: string;
  failPanes?: string;
};

type CodexFixture = {
  projects?: Array<{ id: string; name?: string }>;
  /** Threads per project id. */
  threads?: Record<string, CodexThread[]>;
  failProjects?: string;
  failThreads?: string;
};

type Harness = {
  closeCalls: number;
  herdrWorkspaceCalls: number;
  herdrPaneCalls: string[];
  codexProjectCalls: number;
  codexThreadCalls: Array<string | undefined>;
};

/** Installs prototype doubles for Herdr and Codex; returns the call counters. */
function stubProviders(herdr: HerdrFixture = {}, codex: CodexFixture = {}): Harness {
  const seen: Harness = {
    closeCalls: 0,
    herdrWorkspaceCalls: 0,
    herdrPaneCalls: [],
    codexProjectCalls: 0,
    codexThreadCalls: [],
  };

  mock.method(HerdrBridge.prototype, 'workspaces', async function (this: HerdrBridge) {
    seen.herdrWorkspaceCalls += 1;
    if (herdr.failWorkspaces) throw new Error(herdr.failWorkspaces);
    return (herdr.workspaces ?? []).map((workspace) => ({
      workspaceId: workspace.workspace_id,
      label: workspace.label ?? '',
      number: 1,
      focused: false,
      agentStatus: 'idle' as const,
      paneCount: workspace.pane_count ?? 0,
      tabCount: 1,
    }));
  });

  mock.method(HerdrBridge.prototype, 'panes', async function (this: HerdrBridge, workspaceId: unknown) {
    const id = String(workspaceId);
    seen.herdrPaneCalls.push(id);
    if (herdr.failPanes) throw new Error(herdr.failPanes);
    return (herdr.panes?.[id] ?? []).map((pane) => ({
      paneId: String(pane.pane_id),
      workspaceId: id,
      tabId: String(pane.tab_id ?? 'tab-1'),
      cwd: String(pane.cwd ?? ''),
      focused: false,
      terminalTitle: String(pane.terminal_title ?? ''),
      ...(pane.agent === undefined ? {} : { agent: String(pane.agent) }),
    }));
  });

  mock.method(CodexBridge.prototype, 'projects', async function (this: CodexBridge) {
    seen.codexProjectCalls += 1;
    if (codex.failProjects) throw new Error(codex.failProjects);
    return {
      projects: (codex.projects ?? []).map((project): CodexProject => ({
        id: project.id,
        title: project.name ?? '',
        roots: [],
      })),
    };
  });

  mock.method(CodexBridge.prototype, 'threads', async function (this: CodexBridge, projectId?: string) {
    seen.codexThreadCalls.push(projectId);
    if (codex.failThreads) throw new Error(codex.failThreads);
    return { threads: codex.threads?.[projectId ?? ''] ?? [] };
  });

  mock.method(CodexBridge.prototype, 'close', function (this: CodexBridge) {
    seen.closeCalls += 1;
  });

  return seen;
}

function options(probeKinds: Array<'herdr' | 'claude' | 'codex'>, extra: Partial<DiscoveryOptions> = {}): DiscoveryOptions {
  return {
    logger: silentLogger,
    probe: probeOf(...probeKinds),
    defaultCwd: DEFAULT_CWD,
    ...extra,
  };
}

function byId(sessions: DiscoveredSession[]): Map<string, DiscoveredSession> {
  return new Map(sessions.map((session) => [session.id, session]));
}

function codexThread(overrides: Partial<CodexThread> = {}): CodexThread {
  return {
    id: 'thr-1',
    projectId: 'proj-1',
    title: 'Refactor the parser',
    cwd: 'C:\\work\\parser',
    updatedAt: 1_700_000_000_000,
    status: 'idle',
    canAcceptDirectInput: true,
    canResume: true,
    ...overrides,
  };
}

describe('desktop discovery: real sources', () => {
  afterEach(() => {
    mock.restoreAll();
  });

  test('maps Herdr panes, Claude history and Codex threads to their own ids and origins', async () => {
    const seen = stubProviders(
      {
        workspaces: [
          { workspace_id: 'ws-1', label: 'studio' },
          { workspace_id: 'ws-2', label: 'relay' },
        ],
        panes: {
          'ws-1': [
            { pane_id: 'pane-1', terminal_title: 'build', agent: 'claude', cwd: 'C:\\work\\studio' },
            { pane_id: 'pane-2' },
          ],
          'ws-2': [{ pane_id: 'pane-3', terminal_title: 'logs', agent: 'codex' }],
        },
      },
      {
        projects: [
          { id: 'proj-1', name: 'Parser' },
          { id: 'proj-2', name: 'Relay' },
        ],
        threads: {
          'proj-1': [codexThread({ id: 'thr-1', title: 'Parser rewrite' })],
          'proj-2': [codexThread({ id: 'thr-2', projectId: 'proj-2', title: '' })],
        },
      },
    );

    const discovery = await discoverSessions(
      options(['herdr', 'claude', 'codex'], {
        claudeHistory: historyOf([
          { sessionId: 'b7c1f0e2-1111-4aaa-8bbb-0123456789ab', summary: 'Add the relay exchange', lastModified: 1_700_000_500_000 },
        ]),
      }),
      new Set<string>(),
    );

    assert.deepEqual(discovery.failures, []);
    const rows = byId(discovery.sessions);
    assert.equal(discovery.sessions.length, 6);

    const pane = rows.get('pane-1');
    assert.ok(pane, 'the real Herdr pane id is the row id');
    assert.equal(pane.kind, 'herdr');
    assert.equal(pane.origin, 'pane');
    assert.equal(pane.title, 'build', 'the terminal title wins over the id');
    assert.equal(pane.subtitle, 'studio · claude · C:\\work\\studio');
    assert.equal(pane.canOpen, true);
    assert.equal(pane.canAcceptInput, false, 'screen polling is read-only');
    assert.equal(pane.bound, false, 'an empty bound set must not hide existing sessions');

    const untitledPane = rows.get('pane-2');
    assert.ok(untitledPane);
    assert.equal(untitledPane.title, 'pane-2', 'a titleless pane falls back to its id');
    assert.equal(untitledPane.subtitle, 'studio · shell', 'no agent and no cwd leaves shell only');

    const secondWorkspacePane = rows.get('pane-3');
    assert.ok(secondWorkspacePane);
    assert.equal(secondWorkspacePane.subtitle, 'relay · codex');

    const history = rows.get('b7c1f0e2-1111-4aaa-8bbb-0123456789ab');
    assert.ok(history, 'a Claude session id is carried through unchanged');
    assert.equal(history.kind, 'claude');
    assert.equal(history.origin, 'history');
    assert.equal(history.title, 'Add the relay exchange');
    assert.equal(history.subtitle, 'Claude Code 历史记录');
    assert.equal(history.lastUsed, 1_700_000_500_000);
    assert.equal(history.canOpen, true);
    assert.equal(history.canAcceptInput, false, 'history replay is read-only');

    const thread = rows.get('thr-1');
    assert.ok(thread);
    assert.equal(thread.kind, 'codex');
    assert.equal(thread.origin, 'thread');
    assert.equal(thread.title, 'Parser rewrite');
    assert.equal(thread.subtitle, 'Codex · Parser');
    assert.equal(thread.lastUsed, 1_700_000_000_000);

    const unnamedThread = rows.get('thr-2');
    assert.ok(unnamedThread);
    // The discovery fallback is the id; the real bridge normally supplies a
    // placeholder title before this layer sees the thread.
    assert.equal(unnamedThread.title, 'thr-2');
    assert.equal(unnamedThread.subtitle, 'Codex · Relay');

    assert.deepEqual(seen.herdrPaneCalls, ['ws-1', 'ws-1', 'ws-2'], 'one pane query per workspace');
    assert.deepEqual(seen.codexThreadCalls, ['proj-1', 'proj-2'], 'one thread query per project');
    assert.equal(seen.closeCalls, 1, 'discovery closes the Codex bridge exactly once');
  });

  test('reads Claude history for the default cwd only', async () => {
    stubProviders();
    const cwds: Array<string | undefined> = [];
    await discoverSessions(
      options(['claude'], {
        claudeHistory: historyOf(
          [{ sessionId: 'sess-1', summary: 'Only one', lastModified: 1 }],
          cwds,
        ),
      }),
      new Set<string>(),
    );
    assert.deepEqual(cwds, [DEFAULT_CWD]);
  });

  test('reads configured roots once, deduplicates sessions and preserves each session cwd', async () => {
    stubProviders();
    const roots = ["C:\\work\\studio", "C:\\work\\relay", "C:\\work\\studio"];
    const calls: Array<string | undefined> = [];
    const discovery = await discoverSessions(
      options(['claude'], {
        roots,
        claudeHistory: {
          async list(cwd) {
            calls.push(cwd);
            return cwd === roots[0]
              ? [{ sessionId: "shared", summary: "Studio", cwd: "C:\\work\\studio-wt", lastModified: 2 }]
              : [{ sessionId: "relay", summary: "Relay", lastModified: 1 }];
          },
        },
      }),
      new Set<string>(),
    );

    assert.deepEqual(calls, roots.slice(0, 2));
    assert.equal(discovery.sessions.length, 2);
    assert.equal(discovery.sessions.find((session) => session.id === "shared")?.cwd, "C:\\work\\studio-wt");
    assert.equal(discovery.sessions.find((session) => session.id === "relay")?.cwd, roots[1]);
  });

  test('reports the bound ids back and decorates rows without filtering them', async () => {
    stubProviders(
      {
        workspaces: [{ workspace_id: 'ws-1', label: 'studio' }],
        panes: { 'ws-1': [{ pane_id: 'pane-1' }, { pane_id: 'pane-2' }] },
      },
      {
        projects: [{ id: 'proj-1', name: 'Parser' }],
        threads: { 'proj-1': [codexThread({ id: 'thr-1' })] },
      },
    );

    const bound = new Set(['pane-2', 'thr-1', 'not-discovered']);
    const discovery = await discoverSessions(
      options(['herdr', 'codex'], {
        claudeHistory: historyOf([]),
      }),
      bound,
    );

    const rows = byId(discovery.sessions);
    assert.equal(discovery.sessions.length, 3, 'bound entries never add or remove rows');
    assert.equal(rows.get('pane-1')?.bound, false);
    assert.equal(rows.get('pane-2')?.bound, true, 'a bound pane is still listed');
    assert.equal(rows.get('thr-1')?.bound, true);
    assert.deepEqual([...discovery.bound].sort(), ['not-discovered', 'pane-2', 'thr-1']);
    assert.deepEqual(discovery.failures, []);
  });

  test('an installed tool with no results fabricates no session and no failure', async () => {
    stubProviders(
      { workspaces: [{ workspace_id: 'ws-1', label: 'empty' }], panes: { 'ws-1': [] } },
      { projects: [], threads: {} },
    );

    const discovery = await discoverSessions(
      options(['herdr', 'claude', 'codex'], { claudeHistory: historyOf([]) }),
      new Set<string>(),
    );

    assert.deepEqual(discovery.sessions, [], 'nothing is invented for an empty machine');
    assert.deepEqual(discovery.bound, []);
    assert.deepEqual(discovery.failures, [], 'an empty result is not an error');
  });

  test('skips a tool that is not installed without reporting a failure', async () => {
    const seen = stubProviders(
      { workspaces: [{ workspace_id: 'ws-1', label: 'studio' }], panes: { 'ws-1': [{ pane_id: 'pane-1' }] } },
      { projects: [{ id: 'proj-1' }], threads: { 'proj-1': [codexThread()] } },
    );

    const discovery = await discoverSessions(
      options(['herdr'], { claudeHistory: historyOf([{ sessionId: 'sess-1', summary: 's', lastModified: 1 }]) }),
      new Set<string>(),
    );

    assert.deepEqual(discovery.sessions.map((session) => session.kind), ['herdr']);
    assert.deepEqual(discovery.failures, []);
    assert.equal(seen.codexProjectCalls, 0, 'Codex is never queried when the tool is absent');
    assert.equal(seen.closeCalls, 0);
  });

  test('Claude history is skipped when the caller supplied no loader', async () => {
    stubProviders();
    const discovery = await discoverSessions(options(['claude']), new Set<string>());
    assert.deepEqual(discovery.sessions, []);
    assert.deepEqual(discovery.failures, []);
  });
});

describe('desktop discovery: independent providers', () => {
  afterEach(() => {
    mock.restoreAll();
  });

  test('a Herdr failure keeps Claude and Codex rows and adds one failure line', async () => {
    stubProviders(
      { failWorkspaces: 'Herdr 服务未运行' },
      {
        projects: [{ id: 'proj-1', name: 'Parser' }],
        threads: { 'proj-1': [codexThread({ id: 'thr-1' })] },
      },
    );

    const discovery = await discoverSessions(
      options(['herdr', 'claude', 'codex'], {
        claudeHistory: historyOf([{ sessionId: 'sess-1', summary: 'Claude session', lastModified: 1 }]),
      }),
      new Set<string>(),
    );

    assert.deepEqual(discovery.sessions.map((session) => session.id).sort(), ['sess-1', 'thr-1']);
    assert.deepEqual(discovery.failures, [{ kind: 'herdr', message: 'Herdr 服务未运行' }]);
  });

  test('a Claude failure keeps Herdr and Codex rows and adds one failure line', async () => {
    stubProviders(
      { workspaces: [{ workspace_id: 'ws-1', label: 'studio' }], panes: { 'ws-1': [{ pane_id: 'pane-1' }] } },
      {
        projects: [{ id: 'proj-1', name: 'Parser' }],
        threads: { 'proj-1': [codexThread({ id: 'thr-1' })] },
      },
    );

    const discovery = await discoverSessions(
      options(['herdr', 'claude', 'codex'], {
        claudeHistory: {
          async list() {
            throw new Error('history directory unreadable');
          },
        },
      }),
      new Set<string>(),
    );

    assert.deepEqual(discovery.sessions.map((session) => session.id).sort(), ['pane-1', 'thr-1']);
    assert.deepEqual(discovery.failures, [{ kind: 'claude', message: 'history directory unreadable' }]);
  });

  test('a Codex failure keeps the other rows, reports once, and still closes the bridge', async () => {
    const seen = stubProviders(
      { workspaces: [{ workspace_id: 'ws-1', label: 'studio' }], panes: { 'ws-1': [{ pane_id: 'pane-1' }] } },
      { failProjects: 'Codex Desktop daemon 未运行' },
    );

    const discovery = await discoverSessions(
      options(['herdr', 'claude', 'codex'], {
        claudeHistory: historyOf([{ sessionId: 'sess-1', summary: 'Claude session', lastModified: 1 }]),
      }),
      new Set<string>(),
    );

    assert.deepEqual(discovery.sessions.map((session) => session.id).sort(), ['pane-1', 'sess-1']);
    assert.deepEqual(discovery.failures, [{ kind: 'codex', message: 'Codex Desktop daemon 未运行' }]);
    assert.equal(seen.closeCalls, 1, 'the bridge is closed even on the failure path');
  });

  test('a thread-list failure after a successful project list reports Codex only', async () => {
    stubProviders(
      { workspaces: [{ workspace_id: 'ws-1', label: 'studio' }], panes: { 'ws-1': [{ pane_id: 'pane-1' }] } },
      { projects: [{ id: 'proj-1', name: 'Parser' }], failThreads: 'thread/list rejected' },
    );

    const discovery = await discoverSessions(options(['herdr', 'codex']), new Set<string>());

    assert.deepEqual(discovery.sessions.map((session) => session.id), ['pane-1']);
    assert.deepEqual(discovery.failures, [{ kind: 'codex', message: 'thread/list rejected' }]);
  });

  test('a pane-list failure reports Herdr without keeping its partial workspace rows', async () => {
    stubProviders(
      {
        workspaces: [{ workspace_id: 'ws-1', label: 'studio' }],
        failPanes: 'pane/list timed out',
      },
      { projects: [{ id: 'proj-1', name: 'Parser' }], threads: { 'proj-1': [codexThread({ id: 'thr-1' })] } },
    );

    const discovery = await discoverSessions(options(['herdr', 'codex']), new Set<string>());

    assert.deepEqual(discovery.sessions.map((session) => session.id), ['thr-1']);
    assert.deepEqual(discovery.failures, [{ kind: 'herdr', message: 'pane/list timed out' }]);
  });
});

describe('desktop discovery: Codex read-only threads', () => {
  afterEach(() => {
    mock.restoreAll();
  });

  test('a read-only thread is listed as openable but not accepting input', async () => {
    stubProviders(
      {},
      {
        projects: [{ id: 'proj-1', name: 'Parser' }],
        threads: {
          'proj-1': [
            codexThread({ id: 'thr-live', canAcceptDirectInput: true, canResume: true }),
            codexThread({
              id: 'thr-readonly',
              canAcceptDirectInput: false,
              canResume: false,
              status: 'notLoaded',
            }),
          ],
        },
      },
    );

    const discovery = await discoverSessions(options(['codex']), new Set(['thr-readonly']));
    const rows = byId(discovery.sessions);

    const live = rows.get('thr-live');
    assert.ok(live);
    assert.equal(live.canOpen, true);
    assert.equal(live.canAcceptInput, true, 'a controllable thread accepts input');

    const readOnly = rows.get('thr-readonly');
    assert.ok(readOnly);
    // Reading a thread needs no control rights, so the desktop may still open
    // it; only input is gated. Desktop is still fixing this path, so the two
    // flags must stay separate.
    assert.equal(readOnly.canOpen, true, 'history is readable without control rights');
    assert.equal(readOnly.canAcceptInput, false, 'direct input is not available');
    assert.equal(readOnly.bound, true);
    assert.equal(readOnly.origin, 'thread');
    assert.deepEqual(discovery.failures, []);
  });
});
