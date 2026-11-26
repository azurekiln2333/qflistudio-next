# pi-qfli-server progress

## 2026-11-21

- Read task PRD/design/implement, gateway-auth spec, implementation contract, coordinator contract, and pi-account research.
- Confirmed scope: QFLI server only; relay exchange/refresh/device work belongs to pi-relay.
- Published the endpoint/config contract for pi-relay at `reports/pi-qfli-server-contract.md`.
- Implemented migration, grant module, routes, realname gating, revocation invalidation, tests, docs.
- Added `.github/workflows/verify.yml`: validation-only, `remote/**` push + pull_request + workflow_dispatch, read-only permissions, SHA-pinned actions, `npm ci` then `npm run lint` then `npm test`.
- YAML syntax checked locally with PyYAML; workflow not dispatched, tests/builds not run locally.
- Addressed review: `active:true` is never cacheable; MySQL SELECT→INSERT/logout FK race maps to 401; cleanup moved outside mint/introspect transactions to preserve parent→child lock order.
- Restored/retained the original MySQL migration pipeline unchanged:
  - `migrateMysqlUserIds` remains;
  - `migrateMysqlEntityIds` and `db.entityIdsMigrated` remain single and in original order;
  - no unconditional `ALTER TABLE users.id` was added.
- Ran static checks: all changed/new JS `node --check` OK, `npm run lint` passed, `git diff --check` clean.
- Wrote final report at `reports/pi-qfli-server.md`.

## Final re-check (no code changes)

- Performed a final read-only pass against the settled worktree. No source, test, or doc change was needed; the implementation matches `reports/pi-qfli-server.md`.
- `node --check` on the 8 changed/new JS files: all OK, exit 0.
- `npm run lint`: passed, `检查了 68 个 JavaScript 文件与 package.json`, exit 0.
- `git diff --check`: clean, exit 0.
- `.github/workflows/verify.yml` YAML parse: `name=Verify`, triggers `push` / `pull_request` / `workflow_dispatch`, `permissions: contents: read`, job `verify`.
- Worktree still limited to: `M .env.example`, `M README.md`, `M package.json`, `M src/client-context.js`, `M src/db.js`, `M src/deactivate.js`, `M src/server.js`, plus untracked `.github/workflows/verify.yml`, `src/relay-grant-migration.js`, `src/relay-grants.js`, `src/routes/relay.js`, `test/relay-grants.test.js`.
- Report updated with the re-checked results. Nothing committed or pushed.

## Validation rules

- No local tests, services, builds, probes, Docker/WSL/emulators/adb/hdc.
- Allowed locally: `node --check`, `npm run lint` (static syntax/import check), `git diff --check`, documentation lint.
- Cloud CI must run `npm test` / `node --test`.
- `test/relay-grants.test.js` and the MySQL FK-race regression are **not locally executed**; first run must be cloud CI.
- Final status: implementation and static verification complete; waiting on root review and the first cloud `npm test` run.

## Cross-repo test fixture correction

- A reviewer ran the forbidden local `npm test`. Two `test/qfli-grant.test.ts` cases failed because they asserted the absolute `gateway.calls`, which is cumulative across the file.
- Fixed the fixture only in the relay worktree: added a per-case call-delta helper and a single-use stub reply, then updated the replay/terminal/malformed assertions. No product source changed.
- Did not run tests, check, build, service, probe, or cloud CI. The correction is documented in `reports/pi-qfli-server.md`.

## Frozen-contract final check

- Verified grants endpoint, realname gate, session/user binding, single-use introspection, and logout/deactivation invalidation against source. No contract deviation found.
- Recorded the reviewer's prohibited local test run and full result in `reports/pi-qfli-server.md`: relay worktree 189 total / 157 pass / 7 fail / 25 skipped, with 5 fake-db failures and the 2 cumulative-`gateway.calls` fixture failures. The latter fixture was corrected without product changes.
- Final allowed checks: 8 JS `node --check` OK, `npm run lint` passed (68 JS files + package.json), `git diff --check` clean.
- No test, check, build, service, probe, or cloud CI was run for this final pass. Final status: frozen and waiting on cloud CI plus real MySQL migration verification.

## Desktop discovery test

- Added only `studio/companion/remote_agent/test/desktop-discovery.test.ts` in the desktop worktree.
- Uses `node:test` `mock.method` on `HerdrBridge`/`CodexBridge` prototypes plus `probe` and `claudeHistory` injection. Covers source mapping, `bound` decoration, empty results, independent provider failures, and Codex read-only `canOpen:true`/`canAcceptInput:false`.
- `node --check` passed. The test was not executed and `npm run check` was not run.
