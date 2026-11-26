# Phase 03 plan — companion and host entry

Read first: `prd.md` R7/R10, `design.md` "Companion ownership" and "Additional
compatibility details", `reports/phase-01-foundation.md`,
`reports/phase-02-ui.md`, source `.trellis/spec/backend/sidecar-protocol.md`,
app `.trellis/spec/frontend/repository-layout.md`.

Target worktree for this phase: `D:/MyNewProjects/_wt/cloudterminal-import/work/qflistudio`
(app). The core worktree is read-only for this phase except where a report note
is needed; the module entry already exists from phase 02.

Path convention: `phases.json` prefixes paths with the worktree label
(`core/...`, `app/...`). So `app/companion/remote_agent` means
`<app worktree>/companion/remote_agent`.

## Steps

1. Copy `<source>/server` to `<app>/companion/remote_agent` (src, test,
   scripts, package manifests, lockfile, relay-core manifest, TUNNEL.md).
   Exclude nothing tracked: the source tree has no `node_modules`, build output
   or log. Keep `.gitignore`, `relay-core.json` (external relay provenance) and
   `package-lock.json`.
2. Copy `<source>/apps/cloudterminal_windows` to
   `<app>/companion/windows_assistant` (lib, test, windows runner, pubspec,
   lockfile, run.cmd, LAUNCH.md, .metadata). Rewrite the sidecar lookup so it
   points at `../remote_agent` and never at the old repository layout.
3. Add launchers under `remote_agent` (`start.cmd`, `start.sh`) derived from the
   source root launchers, self-locating by script directory.
4. Add `companion/README.md` and `remote_agent/README.md` with run steps,
   identity rules (`~/.cloudterminal` / `CLOUDTERMINAL_HOME` untouched, never
   auto-copied), relay provenance and the capability map.
5. Add one host navigation entry: `lib/studio_tools_tab.dart` in the app,
   wired through `StudioProfile.toolsTabBuilder` in `lib/main.dart`. Gate on
   `RemoteComputerPage.isSupported`; offline language products do not set the
   builder, so they are unchanged.
6. Add companion ignores to the app `.gitignore` (node_modules, sidecar
   bootstrap/identity files).
7. Permitted local checks only: `dart format`/`dart analyze` on the two app
   files, Chinese lint on authored docs, `git diff --check`. No npm/flutter
   build, no test, no sidecar start.

## Explicit non-goals

- No live agent, relay, pairing or sidecar process is started.
- No `~/.cloudterminal` identity is read, copied or written.
- No public relay server merge; `src/relay/*` stays a mirror per
  `relay-core.json`.
- No companion CI here (phase 04 owns tests and pipeline entries).
