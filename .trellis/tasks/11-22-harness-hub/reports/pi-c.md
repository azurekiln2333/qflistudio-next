# Pi-C report — hub and Agents UI

Branches: core `harness/pi-c` (commits `37e8108` → `31a7d8b`), app `harness/pi-c`
(commit `c1962e6`). Worktrees: `D:/MyNewProjects/_wt/harness/pi-c/{qfli_studio_core,qflistudio}`.

## What was delivered

### Core `lib/harness/hub/`

| File | Contents |
|---|---|
| `harness_hub.dart` | `HarnessHub` (ChangeNotifier): host pool, platform filter, current host, per-host session subscriptions, merged list, provider labels, launch menu, open/launch, `closeActiveSession()` (detach only), `refresh()`, dispose. Also `HubProviderGroup`, `groupSessionsByProvider()`, `HarnessHostHint` (optional host interface carrying an install hint), `HarnessHubException`. |
| `harness_hosts.dart` | Wiring point. `HubHostContext` (auth, project store, settings, project root), `HarnessHostsFactory`, `HarnessHosts.registerDefault` / `overrideForTesting` / `build`, and `harnessHubFor(...)` used by the editor page. |

Behaviour worth knowing:

- `hostVisibleOnPlatform(kind, desktop:)`: desktop shows every kind; phone and
  web show only `remote` and `studio` (there is no PTY or local Herdr there).
- Default host: `local` on desktop, first `remote` on phone, else the first host.
  Registration order is display order (studio → local → herdr → remote, as
  documented in the report).
- Merged sessions keep the host's own order; `allSessions` is host order then
  session order. `groupsOf`/`currentGroups` group by provider, label from
  `providers()` with the id as fallback, sessions inside a group sorted by
  `updatedAt` descending.
- `openSession()` reuses the live handle for the same session, detaches the
  previous handle before switching, and coerces the current host to the
  session's host. If the host drops the active session from its list, the view
  is closed (detach only).
- Disposal cancels subscriptions, removes state listeners, detaches the open
  handle, and disposes every host once. The factory therefore owns host
  creation and must hand out fresh instances (documented in
  `harness_hosts.dart`).

### Core `lib/harness/ui/`

| File | Contents |
|---|---|
| `hub_agents_surface.dart` | `HubAgentsSurface`: host switcher row + host state/hint banner + body. Body is the studio pane by default, `HubSessionView` when an external session is selected, and a host empty state otherwise. |
| `hub_host_switcher.dart` | `HubHostSwitcher` (host chips with online dot, add-computer chip), `HubHostOnlineDot`. |
| `hub_session_list.dart` | `HubNewSessionButton` (launch menu from `providers()`), `HubSessionRow`, `HubSessionGroups`, `HubSessionListSection` (sidebar section: title, new-session menu, provider groups, empty/offline hints). |
| `hub_session_view.dart` | `HubSessionView`: header (title, status chip, cwd, stop, close), Chat/Terminal tabs from capabilities, `IndexedStack` so the terminal keeps its state, stop confirmation dialog, detach-only close. |
| `hub_chat_view.dart` | `HubChatView` (bounded transcript, `ChatMessageTile` reuse, approval/question cards, composer), `HubRequestCard`, `HubComposer`. |
| `hub_terminal_view.dart` | `HubTerminalView`: `HarnessTerminalChannel` ↔ xterm `Terminal`, chunked UTF-8 decode, bounded scrollback (5000 lines), resize forwarding, `RemoteTheme.terminalStyle`. |
| `hub_terminal_key_bar.dart` | `HubTerminalKeyBar`: Esc, Tab, sticky Ctrl, sticky Alt, arrows, paste from clipboard. |
| `hub_status.dart` | Status labels/colours, `HarnessStatusChip`, relative time. |
| `agents_entry.dart` | `openAgentsSurface()`: the redirect target for the old entry. Picks the newest local project, opens the editor with the Agents pane revealed; explains when there is no project. |

### Core pages

- `lib/pages/devices_remote_page.dart` — 设备与远程: current pairing (name, relay,
  agent id, online dot), 添加电脑 (reuses `PairScreen` in its own route, closes
  itself once pairing lands), 撤销 with confirmation (`RemoteController.unpair`),
  account row, and a note pointing at the Agents panel. Ownership follows
  `RemoteComputerPage`: an injected controller is not disposed.
- `lib/pages/settings_page.dart` — new 设备与远程 section (gated on
  `RemoteComputerPage.isSupported`).

### Editor integration (existing surface, no new route)

- `EditorPage` gets `agentPaneRequest` (int, additive) and `_revealAgentPane()`.
  `openEditorPage(..., revealAgentPane: true)` threads it through
  `RetainedEditorController` (`_EditorSession.agentPaneRequest`), so an
  already-open retained session also reveals the pane on the next request.
- `EditorPage` builds one `HarnessHub` next to `EditorAgentHost` via
  `harnessHubFor(...)`, disposes it with the page.
- `_buildAgentPane()` wraps the untouched `EditorAgentPane` in
  `HubAgentsSurface`; `compact` comes from `layoutOf(width) == narrow`.
- Sidebar: `SessionListView` gained an optional `extra` slot, used for
  `HubSessionListSection`. Studio sessions and external sessions now share one
  scrolling list; the studio empty state no longer hides the external section.
- `_selectAgentSession` closes the open external view, so the two panels never
  claim the right column at once.
- Selecting a hub session (`_openHubSession`) expands the right column (wide) or
  switches to the agent segment (narrow) before opening.

### App `qflistudio`

- `lib/studio_tools_tab.dart`: the old 远程电脑 card is now an **Agents 会话**
  card that runs `openAgentsSurface(...)`. `RemoteComputerPage` is still exported
  and unchanged; nothing in `remote_control` was removed.
- `lib/main.dart`: registers `studioAppServices = (auth, settings)` so the tools
  card can open the editor. `StudioProfile.toolsTabBuilder` only receives
  `(store, onOpenTerminal)`; changing that shared typedef would affect every
  product, so a small app-level handle was preferred.

## Layout description (no screenshots taken; no running desktop build was used)

- **Wide (≥1100)**: right column, top to bottom — host chips row (`本机 · Herdr ·
  我的电脑 ● · + 添加电脑`, then refresh, divider, new-session), optional state
  banner (`未检测到 Herdr…`, `电脑未连接…`), then the pane. Studio host shows the
  existing chat; an external host shows the session header (title + status chip +
  cwd + stop + close) and Chat/Terminal tabs. Sidebar card: studio session rows
  first, then a divider, `外部会话 · 本机`, the new-session icon, then provider
  groups (`Claude Code 2`, rows with status chip, cwd, relative time).
- **Medium (720–1100)**: the same content but as the agent segment of the
  single-pane switcher; the sidebar is persistent.
- **Narrow (<720)**: sidebar is the drawer (host chips and grouped list inside),
  agent segment shows the session view with a back arrow and the terminal key bar
  under the terminal (`Esc Tab Ctrl Alt ← ↑ ↓ → 粘贴`), Ctrl/Alt highlight while
  sticky.
- **Stop dialog**: title 结束会话, body names the session, 取消 / 结束会话 (error
  colour); confirmation is required before `handle.stop()`.
- **Settings → 设备与远程**: 已绑定电脑 (online dot, name, relay · agent id,
  撤销), 添加电脑, 账号, and a closing note about the Agents panel.

## Contract change requests

The contract file is untouched (`git status` clean for
`lib/harness/harness_host.dart`; `dart format` reformatted it twice by accident
and it was restored to the committed text both times).

1. **Optional interface, not a contract change**: `HarnessHostHint`
   (`harness_hub.dart`) carries an install/repair hint so the UI can explain
   `HarnessHostState.unsupported`. Pi-B should implement it for Herdr
   (`installHint: '未检测到 Herdr，请先安装…'`). If root prefers a contract field
   (`String? get hint`), the hub helper is a one-line change.
2. **Per-host launch cwd**: `HarnessLaunchRequest.cwd` is a single string. The
   editor passes the current project root. Remote hosts whose project lives on
   the paired computer may want a host-chosen default; today the UI has no field
   for it. Not needed for this task, noted for the merge.

## Dependencies added

None. Reused `xterm` (vendored, already a core dependency), `ChatMessageTile`,
`ComposerState`, `RemoteTheme`, `SessionListView`, `PairScreen`,
`RemoteController`/`RemoteStore`, `SettingsSection`.

## Static checks run locally

| Check | Result |
|---|---|
| `flutter pub get --offline` (core, app) | resolved from sibling paths |
| `flutter analyze --no-pub lib` (core) | 2 infos, both present at HEAD: `lib/chat/composer_card.dart:346` `curly_braces_in_flow_control_structures`, `lib/harness/harness_host.dart:6` `unnecessary_import`. Neither file is edited by this branch. |
| `flutter analyze --no-pub lib` (app) | 1 info present at HEAD (`lib/main.dart:3` `unnecessary_import`) |
| `flutter analyze --no-pub lib/harness test/harness test/support/fake_harness_host.dart` | only the contract's `unnecessary_import` info |
| `dart format` | applied to the new and edited files; the contract file is left exactly as committed |
| `flutter test` / builds / emulators / servers | **not run** (brief) |

## Tests written for cloud CI (not executed here)

- `test/harness/harness_hub_test.dart` — desktop keeps every host and defaults to
  local; phone hides local/Herdr; merged sessions carry host ids; grouping labels
  and ordering; launch menu from providers; state/hint exposure; host switching
  releases the view; same session opens once; close detaches without stop; the
  host removing the active session closes the view; launch selects the new
  session; empty hub errors honestly; refresh re-subscribes; dispose detaches and
  disposes each host once; unknown provider keeps its id as label.
- `test/harness/hub_ui_test.dart` — host switcher renders hosts, online/offline
  dots, switching, add-computer callback; session list groups by provider with
  status chips and cwd; row tap reports the session; Agents surface keeps the
  studio pane until an external host is chosen then shows the session view;
  stop requires confirmation (cancel → no stop, confirm → one stop); close
  detaches and calls back; chat composer sends prompts; approval option replies
  with the request id and choice; key bar sends Esc/Tab/arrows with sticky
  Ctrl/Alt flags; paste reads the clipboard.
- `test/support/fake_harness_host.dart` — fake host/handle/channel used by both
  suites.

## Unverified acceptance items

- AC1 (desktop launches shell/Claude/Codex/Pi), AC3 (live Herdr refresh), AC4 as
  a *desktop runtime* claim, AC6 (real phone pairing), AC7 (device keyboard), AC8
  (manual pairing still works against a real relay), AC9–AC11 (Trellis panel,
  skills, provider config) are **not** demonstrated here: they belong to Pi-A,
  Pi-B and Pi-D, and no tests, builds or devices were used locally.
- This branch alone shows a hub with **no hosts**: `HarnessHosts.registerDefault`
  is the merge point. Until it is registered the Agents panel looks exactly like
  before (studio pane only), which is the intended fallback.
- Verified only statically: the 设备与远程 page renders and pairs/unpairs via the
  existing `RemoteController`; a real pairing was not exercised.

## Housekeeping note

`flutter pub get` in the app worktree re-touched seven generated registrant
files (`linux/…`, `macos/Flutter/GeneratedPluginRegistrant.swift`, `windows/…`).
`git diff --numstat` shows **no content change** for them — they are line-ending
artifacts of pub get and were deliberately left out of the commit. Nothing else
is dirty in either worktree.

## Risks / merge notes

1. **Host wiring (must do at merge)**: register the four hosts once, e.g.

   ```dart
   HarnessHosts.registerDefault(
     (context) => [
       StudioAgentHost(...),   // Pi-D, kind: studio
       LocalHarnessHost(...),  // Pi-A, kind: local, id: 'local'
       HerdrHost(...),         // Pi-B, kind: local, id: 'herdr'
       RemoteHarnessHost(...), // Pi-B, kind: remote, one per paired computer
     ],
   );
   ```

   `HubHostContext` carries `auth`, `projectStore`, `settings`, `projectRoot`
   (typed as `Object` on purpose so this branch compiles before the other
   implementations land; root may tighten the types when merging).
2. **Shared long-lived hosts**: the editor page creates one hub per live editor
   session and the hub disposes its hosts. If Local/Herdr/Remote hosts end up
   app-level singletons, their `dispose()` must be idempotent and must not kill
   shared resources, or the factory must hand out separate instances.
3. **Remote controller reuse**: if Pi-B's `RemoteHarnessHost` wraps the same
   `RemoteController` the 设备与远程 page uses, only one owner may dispose it.
   The devices page already honours injected ownership.
4. **Pairing UI duplication**: 设备与远程 mounts `PairScreen` in its own route.
   `RemoteComputerPage` remains intact for hosts that still mount it, so the
   pairing flow exists twice at runtime but shares one implementation.
5. **Account binding**: 11-21 owns the binding API. The 设备与远程 page has the
   account row and a truthful note; the real bind/revoke call is not wired here.
6. **Mobile "list → detail"** is expressed through the editor's existing
   narrow layout: the drawer holds the list, the agent segment holds the detail
   with a back arrow. There is no separate mobile route, by design.
7. `HubNewSessionButton` keeps one provider future per host id instead of
   recreating it per frame; `refresh()` clears provider caches so a later build
   re-reads them.
## Fixes after the Pi-B review (`reports/check-b.md`)

Commit `4f59dc0` in `harness/pi-c` (core only; the app worktree is unchanged
because every finding lived in core). Findings are numbered as in `check-b.md`.

| # | Verdict | What changed |
|---|---|---|
| 1 (高) | **fixed** | Composer stop no longer calls `stop()` directly |
| 2 (中) | **fixed** (Pi-C side; root still owns the final shape) | `HarnessHostHint.installHint` is `Object?`, hints are normalised by `harnessHintText` |
| 3 (中) | **fixed** | Devices page checks `mounted` around every await; the pairing route only pops when it is the current route |
| 4 (中) | **fixed** | `HubChatView.didUpdateWidget` rebinds on a handle change |
| 5 (低-中) | **fixed** | `launch(hostId:)` switches the current host |
| 6 (低) | **fixed** | Dead `_output` field removed; the chunked decoder is closed on dispose |
| 7 (低) | **fixed** | The external-session section hides itself on the studio host |
| 8 (低) | **rejected** (with reasoning; root decision) | See below |
| 9 (备注) | **partially fixed** | `HarnessHub(ownsHosts: false)` exists; factory errors are recorded and shown |
| 10 (备注) | **partially fixed** | Tests added for findings 1, 2, 4, 5, 6, 7 and for host ownership |

### 1 (高) Composer stop boots the confirmation — fixed

`HubChatView` no longer touches the handle: it takes an `onStop` callback and
`HubSessionView` passes `_confirmStop`, so both the header button and the
composer button go through the same `hub-stop-dialog`. The button is hidden
when no callback is given, and its tooltip now says 结束会话 instead of 停止,
because that is what the contract's `stop()` does.

New test: `the composer stop button asks for confirmation too` (cancel → no
stop, dialog present). The fake handle gained a `sendGate` so the composer can
be held in its "sending" state.

### 2 (中) Install hint type — fixed on the Pi-C side

`HarnessHostHint.installHint` is now `Object?`, and `harnessHintText()` turns
a `String`, a `Map` (`message`/`detail`/`title`) or any object with a
`message` field into one line; a default `Instance of ...` yields `null` so the
UI falls back to its generic text. That makes Pi-B's structured
`HerdrInstallHint` assignable without touching the shared contract, and the
branches no longer need to agree on a type before merging.

Note on the "redundant cast" remark: the cast was not redundant. `HarnessHost`
and `HarnessHostHint` are unrelated types, so Dart does not promote between
them (`unchecked_use_of_nullable_value` proves it); the code now uses a
pattern match, which binds a non-null copy without a cast.

Root may still prefer a contract field (`String? get hint`). If so, delete
`HarnessHostHint` and `harnessHintText`; nothing else depends on them.

### 3 (中) Devices page controller leak — fixed

`_boot()` returns early after `RemoteStore.open()` when the page is already
gone, and disposes a controller created in the window before `_booting` is
cleared. `_PairRoute._onChanged` now also checks `ModalRoute.isCurrent` and
`canPop` before popping, so a repeated callback cannot pop the settings page.
`RemoteStore` has no `close()`/`dispose()` (it is a plain data holder), so
there is nothing to release on that side.

No test: `RemoteStore.open()` is a static and the injection point hides the
async window. The fix is defensive and reviewed by reading; a widget test
would need a fake store factory that the page does not accept today.

### 4 (中) Chat view follows handle changes — fixed

`didUpdateWidget` clears events, answered requests and the error, then
rebinds. `_bind()` also clears `_events` so a rebind can never leave stale
ones behind. New test: `chat view rebinds when the handle changes`.

### 5 (低-中) `launch(hostId:)` switches the host — fixed

`launch()` now mirrors `openSession()` and sets `_currentHostId` before
notifying. New test: `launching on another host switches to that host`
(checks both `currentHostId` and `currentSessions`).

### 6 (低) Terminal view cleanup — fixed

The never-assigned `_output` subscription is gone, and the chunked decoder is
kept in `_decoder`, closed on stream end and on dispose through an idempotent
`_closeDecoder()`. New test: `terminal view joins a multi-byte character split
in two chunks` emits the three UTF-8 bytes of 「你」 as `E4 BD` + `A0` and reads
the rendered buffer back.

### 7 (低) No duplicate studio sessions — fixed

`HubSessionListSection` returns `SizedBox.shrink()` when the current host is
`HarnessHostKind.studio`, because that host's sessions are already drawn by the
native `SessionListView` above it. New test: `the session list section stays
out of the studio host`.

### 8 (低) Eager subscription — rejected, please decide at integration

Not changed, for three reasons:

1. It is not a defect in this branch's code: each host decides what
   `watchSessions()` costs, and the hub is the only place that could add
   start/pause.
2. A lazy start cannot be made effective here. `EditorPage` builds the agent
   pane whenever the agent host exists (`editor_page.dart:1976`, passed through
   `_buildAgentPane` at `:3733`), not only when it is visible, so anything the
   hub waits for is requested on the first frame of every editor page anyway.
   The only real saving is not building the hosts at all — which is the
   ownership decision in finding 9, owned by root.
3. Adding an unused `start()`/`pause()` API now would be dead code on a branch
   that has no host implementations yet.

Recommended for root: register the hosts as application-level singletons built
once at startup and pass `ownsHosts: false` (now supported), instead of one
set per editor page. That removes the per-page Herdr loops entirely.

### 9 (备注) Host ownership / factory errors — partially fixed

- `HarnessHub` takes `ownsHosts` (default `true`). Passing `false` keeps
  shared hosts alive when an editor page closes; `dispose()` still removes the
  hub's own listeners and detaches its view. New test:
  `a hub that does not own its hosts leaves them running`.
- `HarnessHosts.lastBuildError` records a factory failure instead of swallowing
  it; `harnessHubFor` forwards it to `HarnessHub.hostBuildError`, and
  `HubAgentsSurface` renders a `hub-host-build-error` strip so the panel is not
  silently empty. A debug-only `debugPrint` includes the stack.

Still open for root: choose the ownership model in the integration commit and
document it next to `registerDefault`.

### 10 (备注) Test gaps — partially closed

Added: composer-stop confirmation, structured hint dispatch, `launch(hostId:)`,
host ownership, chat rebind, studio section, terminal multi-byte decode.
Not added: `DevicesRemotePage` (needs a store-open seam), `agents_entry.dart`
(needs a project-store fixture), and `openSession(hostId:)` with an explicit
host — the last is cheap and should be picked up if the suite is extended.

### Static checks after the fixes

| Check | Result |
|---|---|
| `flutter analyze --no-pub lib` (core) | same 2 pre-existing infos as before the fix (`lib/chat/composer_card.dart:346`, `lib/harness/harness_host.dart:6`); nothing new |
| `flutter analyze --no-pub lib/harness lib/pages/devices_remote_page.dart test/harness` | only the contract's `unnecessary_import` info |
| `flutter analyze --no-pub lib` (app) | unchanged, 1 pre-existing info at `lib/main.dart:3`; the app worktree has no source change in this commit |
| `flutter test` / builds | **not run** (brief); the new tests are written for cloud CI |
| `dart format` | not re-run: the repository is not formatted with the current `dart format` (a previous run rewrote the contract file), so formatting was done by hand to match surrounding code |
