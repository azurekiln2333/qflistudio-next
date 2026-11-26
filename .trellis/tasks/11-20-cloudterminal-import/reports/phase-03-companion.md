# Phase 03 — companion (Node agent, Windows assistant, host entry)

Status: **implemented**, code complete for this phase. Not "accepted": nothing was
built, started or tested, and no cloud CI has run (phase 04 owns that).

Worktrees:

- app (target, write scope): `D:/MyNewProjects/_wt/cloudterminal-import/work/qflistudio`
  (branch `remote/cloudterminal-app`, base `e018db9`).
- core (sibling dependency, read only this phase):
  `D:/MyNewProjects/_wt/cloudterminal-import/work/qfli_studio_core`.
- source (read only): `D:/MyNewProjects/_wt/cloudterminal-import/source/cloudterminal`
  (HEAD `49b2aac781858929a19307faeb808b83f8154410`).

`D:/MyNewProjects/cloudterminal` was not touched. No install, build, test, VM,
emulator, WSL, Docker, `adb`/`hdc` run happened anywhere. No runtime service was
started and no identity file was read, copied or written.

Attempt note: an earlier attempt of this phase copied both trees and wired the
entry, then ended before writing this report. This attempt re-verified every copy
against the source, fixed the gaps it found (see "Gaps fixed"), and wrote this
report.

## Deliverables

```
companion/README.md                         new — 电脑侧总览、入口、许可、身份、能力对照
companion/remote_agent/                     63 files, 12,966 lines  (source server/ = 60 files)
  src/agent/  src/relay/  src/shared/       copied verbatim
  test/  scripts/                           copied verbatim
  package.json  package-lock.json           copied verbatim (npm ci reproduces the tree)
  tsconfig.json  .gitignore  relay-core.json copied verbatim
  TUNNEL.md                                 copied, 2 path lines adapted
  README.md                                 new — run steps, sidecar protocol, identity, relay mirror, licence
  start.cmd  start.sh                       new — self-locating launchers derived from source start.cmd/start.sh
companion/windows_assistant/                41 files, 2,662 Dart lines  (source apps/cloudterminal_windows = 41 files)
  lib/  test/  windows/  pubspec.yaml  pubspec.lock  run.cmd  .metadata  .gitignore  analysis_options.yaml
lib/studio_tools_tab.dart                   new — the single host navigation entry
```

App files modified:

```
lib/main.dart      +4 lines   import 'studio_tools_tab.dart'; toolsTabBuilder: buildStudioToolsTab
.gitignore         +8 lines   companion node_modules / bootstrap / log / flutter-plugins ignores
pubspec.yaml       +5 lines   dependency_overrides.xterm -> ../qfli_studio_core/vendor/xterm
pubspec.lock      +39 lines   xterm as a relative path package + convert/equatable/quiver/zmodem
```

Nothing else in the app changed: no existing `lib/`, `test/`, `assets/`,
`android/`, `windows/`, `ios/`, `macos/`, `linux/`, `ohos/` or `web/` source was
edited. `git status --short` additionally lists seven generated plugin registrants
(`linux/`, `macos/`, `windows/`) as modified, but `git diff --stat` shows **zero**
content change for them: only file stat/line-ending metadata moved when
`flutter pub get` refreshed the worktree. They are not part of this phase's
change and must not be committed as a content edit.

## Exact paths (entry and packaging)

| What | Path |
| --- | --- |
| Host navigation entry (only one) | `lib/studio_tools_tab.dart` → `buildStudioToolsTab` |
| Host wiring | `lib/main.dart`, `StudioProfile.toolsTabBuilder: buildStudioToolsTab` |
| Card target (shared core) | `qfli_studio_core/lib/remote_control/remote_computer_page.dart` → `RemoteComputerPage` |
| Agent entry | `companion/remote_agent/src/agent/main.ts` |
| Agent sidecar mode | `node src/agent/main.ts --sidecar`, cwd `companion/remote_agent` |
| Agent deps (not tracked) | `companion/remote_agent/node_modules` (`npm ci`) |
| Agent launchers | `companion/remote_agent/start.cmd`, `companion/remote_agent/start.sh` |
| LAN relay launcher | `companion/remote_agent/scripts/tunnel-relay.ps1` |
| Windows assistant project | `companion/windows_assistant` |
| Windows assistant launcher | `companion/windows_assistant/run.cmd` |
| Windows assistant release output | `companion/windows_assistant/build/windows/x64/runner/Release` |

## What was preserved verbatim

`diff -rq` against the source trees, then a per-file diff for every file that
differed. Every file not listed below is **byte identical** to the source copy.

### `companion/remote_agent` — 4 files differ, 3 files added

| File | Change |
| --- | --- |
| `src/shared/pairing.ts` | 2 comment lines: `apps/cloudterminal_windows/lib/models/pairing_uri.dart` → `companion/windows_assistant/lib/models/pairing_uri.dart` |
| `scripts/sync-relay.ts` | 1 comment line (`server/` → `remote_agent/`) |
| `scripts/tunnel-relay.ps1` | 5 hunks, all comments/usage text and one `Write-Info` label。目录定位本来就基于 `Split-Path`，无需改动 |
| `TUNNEL.md` | 2 path lines (`server/scripts/…` → `companion/remote_agent/scripts/…`) |
| `README.md` | new |
| `start.cmd`, `start.sh` | new |

Untouched therefore: all 29 files under `src/` except the one comment above —
`src/agent/{main,core,config,sidecar,herdr,herdr-live,herdr-socket,codex,codex-rpc,claude,bootstrap,setup,…}`,
`src/relay/relay.ts`, `src/shared/{protocol,relay-protocol,protocol-account,crypto,log,…}` —
plus all 20 `test/` files, `package.json`, `package-lock.json`, `tsconfig.json`,
`relay-core.json` and `.gitignore`. Wire protocol, PTY handling, Herdr/Codex/Claude
integrations, the in-process LAN relay, the sidecar IPC contract and the relay-core
mirror manifest are therefore the source behaviour, not a re-implementation.

### `companion/windows_assistant` — 7 files differ

| File | Change |
| --- | --- |
| `lib/main.dart` | sidecar directory resolution replaced (see below) + `CLOUDTERMINAL_NODE` override |
| `lib/models/pairing_uri.dart` | 1 doc comment (`server/src/shared/pairing.ts` → `../remote_agent/…`) |
| `lib/state/assistant_controller.dart` | 1 user-facing error string: `server/` → `companion/remote_agent` |
| `test/sidecar_ipc_test.dart` | sidecar cwd `../../server` → `../remote_agent`, skip message, comment |
| `run.cmd` | banner text, `AGENT_DIR` echo, one "deps missing" hint |
| `README.md`, `LAUNCH.md` | rewritten for the new home and for the assistant-vs-Studio split |

Untouched: all five screens (`home_shell`, `overview_page`, `tools_page`,
`sessions_page`, `pairing_page`, `settings_page`), `engine/sidecar_client.dart`,
`state/assistant_controller.dart` logic, `models/tool.dart`, `theme/app_theme.dart`,
`widgets/common.dart`, the whole `windows/` runner, `pubspec.yaml`, `pubspec.lock`,
`.metadata`, `analysis_options.yaml`, `test/widget_test.dart`. The assistant UI,
state machine and sidecar protocol are the source behaviour.

### Sidecar path adaptation (the one behavioural edit)

The source resolved the agent as `<cwd>/../../server`. That only works inside the
original checkout. Replaced by, first hit wins:

1. `CLOUDTERMINAL_AGENT_DIR` — explicit override for a packaged agent.
2. `<cwd>/../remote_agent` — hit when launched from `companion/windows_assistant`
   (`run.cmd` and `flutter run` both work from the project directory).
3. Walk up from `File(Platform.resolvedExecutable).parent`, up to 8 levels,
   testing `<dir>/remote_agent` each time — this reaches
   `companion/remote_agent` from
   `companion/windows_assistant/build/windows/x64/runner/Release`
   (Release → runner → x64 → windows → build → windows_assistant → **companion**).

When nothing matches, the current directory is passed through and the sidecar
reports its own start failure. The assistant never invents a path and never falls
back to `server/` or the original repository layout. `CLOUDTERMINAL_NODE` allows a
packaged Node runtime。默认仍是 `node.exe` / `node`。

Reading the walk in code is all that was done here: the resolution was **not**
executed. No Flutter build was produced and no sidecar was started.

## Host navigation entry

`lib/studio_tools_tab.dart` is the only new UI surface, and it is one card:

- `ToolsGrid` is the same widget `FunctionsTab` renders by default, so the 终端
  card and the shared 通用 group come from the core, not from a copy.
- One `ToolSection('远程电脑')` holding one `ToolDefinition` whose `builder` pushes
  `RemoteComputerPage`.
- Gated on `RemoteComputerPage.isSupported` (`!kIsWeb`), so a browser build renders
  no card instead of a page that can only apologise.
- Offline language products never set `toolsTabBuilder`。The core then falls back
  to its default grid, so they cannot reach the entry at all. The app has exactly
  one `StudioProfile` (`lib/main.dart`, `qfliStudioKey`), and no other product is
  defined in this repository.
- `toolsTabBuilder` replaces the whole `FunctionsTab` body, which would drop the
  core's 专用 group for a *content* product. The main product is not one
  (`toolsPageBuilder == null`, `productKey == qfliStudioKey`), so nothing is lost.
  `_assertNotContentProduct()` makes that a debug tripwire with a Chinese message
  telling a future editor to add the 专用 card rather than silently losing it.

## App dependency note

The core's `dependency_overrides` do not propagate to dependents, so the app would
otherwise resolve the unpatched pub.dev `xterm`. `pubspec.yaml` therefore repeats
the override against `../qfli_studio_core/vendor/xterm`, and `pubspec.lock` records
`xterm 4.0.0` as `path: "../qfli_studio_core/vendor/xterm"`, `relative: true` — a
clean checkout resolves it with no absolute local path. The sibling core dependency
(`qfli_studio_core: path: ../qfli_studio_core`) is unchanged.

## Gaps fixed in this attempt

1. The host entry silently dropped the core's 专用 group for content products.
   Now documented and guarded by a debug assertion (behaviour unchanged for this
   product, which is not a content product).
2. `companion/README.md` had no licence/notice statement, so a reader could not
   tell what governs the copied trees. Added 许可与声明: root `LICENSE` is GPL-3.0
   and covers the repository. Upstream CloudTerminal provides no `LICENSE`/`NOTICE`
   at its root, in `server/` or in `apps/cloudterminal_windows/`, so no licence is
   invented and no relicensing is implied. Node and Dart dependency notices stay in
   `package-lock.json` and `pubspec.lock`. The MIT `LICENSE` for the xterm renderer
   stays in `qfli_studio_core/vendor/xterm`.
3. Added the "在 Studio 里的入口" table so the entry, wiring and card target are
   discoverable from the companion directory, not only from this report.

## Checks run (permitted locally)

| Check | Result |
| --- | --- |
| `dart format --output=none --set-exit-if-changed lib/studio_tools_tab.dart lib/main.dart` | 2 files, 0 changed |
| `dart analyze lib/studio_tools_tab.dart lib/main.dart` | No issues found |
| `dart analyze .` (whole app worktree, 4 analysis contexts) | No issues found, 0 companion paths in the output |
| `dart analyze lib test` in `companion/windows_assistant` (own package config) | No issues found |
| `python scripts/ste-lint-zh.py companion/README.md companion/remote_agent/README.md companion/windows_assistant/README.md companion/windows_assistant/LAUNCH.md` | 0 hard violations each, 0 baseline |
| `git diff --check` | clean (only pre-existing CRLF notices for generated registrants) |
| Trailing-whitespace scan of all new files | only `windows/runner/resources/app_icon.ico`, a binary |
| `diff -rq` copy verification, both trees | only the files tabulated above differ |

The Chinese linter is meaningful for prose only: run on the Dart file it reports
the `semicolon` rule for every `;`, exactly as phase 01 recorded for existing host
Dart code, so it was applied to authored documents.

Not run, by instruction: `npm ci`, `npm test`, `npm run check` (tsc),
`flutter build`/`flutter run`, any sidecar, relay or pairing process, and every
VM/emulator/WSL/Docker/`adb`/`hdc` path.

## What this does and does not prove

Proven: the two copies match the source tree file-for-file except the adaptations
listed. The adaptations are comments, path strings and one path-resolution
function. The app and the Windows assistant both analyze clean. The host entry
compiles against the real core and the real `ToolsGrid`/`StudioProfile` API.

Not proven: anything at runtime. No Node process started, so `npm ci`, the agent,
the sidecar IPC, the LAN relay and the pairing flow are unverified here. No Windows
build was produced, so the assistant's new directory walk is unexecuted. No device
run, so the 远程电脑 card has never been rendered. "Copies and analyzes" is not
"works".

## Known limitations / follow-ups

1. `companion/remote_agent/package.json` keeps `"name": "cloudterminal-server"`.
   Renaming it would invalidate `package-lock.json`'s root entry for no functional
   gain. The directory name is what the launchers and docs use.
2. `companion/windows_assistant` keeps `name: cloudterminal_windows` in
   `pubspec.yaml`, so the copied tests' `package:cloudterminal_windows/…` imports
   stay valid. The user-visible name is the app title `CloudTerminal 助手` and the
   window title `cloudterminal_windows` — both as in the source.
3. `companion/windows_assistant/.dart_tool/` exists in the worktree from the
   dependency resolution that made `dart analyze` possible there. It is ignored by
   the copied `.gitignore` and must not be committed.
4. `companion/windows_assistant` is a second Flutter package inside the app
   repository. It has its own `pubspec.yaml` and analysis context, so the app's
   `dart analyze .` skips it (verified) — it needs its own CI analysis entry, which
   phase 04 owns.
5. No companion CI, no test entry, no packaging script, no installer, no autostart.
   Phase 04 owns tests and pipeline entries.
6. Localisation: the companion docs are Chinese. The assistant UI strings are the
   source's Chinese and are not routed through the host `i18n` layer.
7. The `cloudterminal://pair` link format, the sidecar JSON-line protocol and the
   relay frames are unchanged on both sides, but the claim rests on source parity,
   not on an observed handshake.
