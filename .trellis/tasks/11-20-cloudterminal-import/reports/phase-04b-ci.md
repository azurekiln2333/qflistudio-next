# Phase 04b — cloud CI for the migrated module and the companions

Status: **implemented** (workflow definitions and their static checks written).
**No cloud CI has run**, no test, build, VM, emulator, Docker container, device or
remote session was started locally. "Implemented" here means the pipeline
definitions exist, the pairing they enforce is written down, and every
invariant that can be checked without a runner has been checked.

Worktrees:

- core (target): `D:/MyNewProjects/_wt/cloudterminal-import/work/qfli_studio_core`
  (branch `remote/cloudterminal-core`).
- app (target): `D:/MyNewProjects/_wt/cloudterminal-import/work/qflistudio`
  (branch `remote/cloudterminal-app`).
- source (read only): `D:/MyNewProjects/_wt/cloudterminal-import/source/cloudterminal`
  (HEAD `49b2aac781858929a19307faeb808b83f8154410`).

`D:/MyNewProjects/cloudterminal` was not touched.

## Plan (written before the edits)

1. Core: keep `.github/workflows/remote-control.yml` (written by an earlier
   attempt of this phase) and change its pairing from a bare pinned SHA to
   "explicit paired ref + reviewed baseline must be an ancestor". Reason: a
   hard-pinned SHA is stale by definition on the commit that adds the workflow,
   and a pipeline whose first run is red by bookkeeping teaches nothing.
2. App: add `.github/workflows/remote-companion.yml` with four jobs —
   structure/pairing, Node agent, Studio host, Windows assistant (Linux tests +
   Windows build).
3. App: add `tool/ci/setup_flutter.sh`, byte-identical to the core copy, so both
   repositories install the same SDK from the same tag and verify the same
   commit.
4. Extend `scripts/check-remote-companion.mjs` (also from the earlier attempt)
   so the workflow itself is inspected: paired refs, pinned SDK constants,
   pinned action SHAs, no `main` fallback, and the commands the report claims.
5. Validate statically: YAML parse (PyYAML), the two structural check scripts,
   Chinese lint, `git diff --check`.

(Results, unrun jobs and setup requirements are appended below after execution.)