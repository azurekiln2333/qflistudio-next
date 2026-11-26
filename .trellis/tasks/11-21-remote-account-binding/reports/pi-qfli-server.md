# pi-qfli-server final report

## Scope

QFLI server only. Worktree: `D:/MyNewProjects/_wt/remote-account-binding/qfli-server`.
Relay exchange/refresh/device/revocation work remains pi-relay. No production data, env values, credentials, databases, services, tests, or builds were accessed or run locally.

## Result

Implemented the QFLI side of the remote-account binding contract:

- 60-second opaque relay grant, prefix `qrg_`, 32 random bytes base64url.
- SHA-256 hash-only persistence. Grant plaintext appears only in the mint response and is never logged.
- `POST /api/relay/grants` with QFLI bearer auth, existing live-session/gateway-profile verification, and existing verified-phone/realname gate.
- Fixed server constants `audience=cloudterminal-relay`, `scope=relay.connect`; request cannot widen them.
- Subject only from verified `users.gateway_user_id`; body `sub`/`account_id`/name cannot influence it.
- `POST /api/relay/introspect` with server-to-server HTTP Basic credentials.
- Atomic single-use consumption via conditional `UPDATE ... WHERE used_at IS NULL AND expires_at > ?`; concurrent replay yields exactly one `active:true`.
- Consumption rechecks the live `auth_sessions` row and `users` row; logout/deactivation/session expiry makes pending grants inactive.
- Mint rechecks the session before INSERT and maps a MySQL FK race (logout between SELECT and INSERT) back to 401 `auth.session_expired` after rollback/recheck, instead of 500.
- Cleanup runs outside the mint/introspect transaction to avoid opposite lock ordering with logout's parent-session cascade.
- Lazy cleanup removes expired grants and used grants older than one hour.
- Per-user mint rate limit and per-relay-client introspection rate limit, bounded in-memory maps.
- Automatic idempotent SQLite/MySQL migration: SQLite creates `relay_grants` after the user-ID migration; MySQL creates it after the base `ddl.slice(1)` and the existing user-ID/entity-ID migration. The pre-existing migration pipeline and its `db.entityIdsMigrated` assignment are untouched.
- Explicit deactivation cleanup for `relay_grants`, plus `auth_sessions` FK cascade on logout.
- Config documentation and `.env.example` entries; no secret values.

## Exact changed paths

Worktree:

- `src/relay-grants.js` (new)
- `src/relay-grant-migration.js` (new)
- `src/routes/relay.js` (new)
- `test/relay-grants.test.js` (new)
- `src/db.js` (only import + two migration calls)
- `src/server.js` (mount relay routes and include router in promise wrapper)
- `src/client-context.js` (add `/api/relay/grants` to the existing realname-gated prefixes)
- `src/deactivate.js` (delete pending grants for the deactivated user)
- `.env.example`
- `README.md`
- `package.json` (`test`: `node --test`)
- `.github/workflows/verify.yml` (new validation-only workflow)

Task reports:

- `reports/pi-qfli-server-contract.md`
- `reports/pi-qfli-server-progress.md`
- `reports/pi-qfli-server.md` (this file)

## HTTP contract implemented

### POST /api/relay/grants

Request:

```json
{"audience":"cloudterminal-relay","scope":"relay.connect"}
```

Success:

```json
{"grant":"qrg_<43 base64url chars>","expires_at":"2026-11-21T12:00:00.000Z","audience":"cloudterminal-relay"}
```

- `expires_at` is ISO 8601 UTC.
- Grant TTL is 60 seconds from mint.
- Unauthenticated: 401.
- Unverified phone/realname: 403 `realname.required`.
- Wrong audience/scope: 400 `relay.audience_invalid` / `relay.scope_invalid`.
- Missing relay config: 503.
- Rate limit: 429 `relay.rate_limited`, `retryAfter: 60`.

### POST /api/relay/introspect

Request:

```json
{"grant":"qrg_..."}
```

`token` is accepted as a compatibility alias.

Valid, first consumption:

```json
{"active":true,"iss":"https://qfli.example","sub":"gateway-sub","aud":["cloudterminal-relay"],"scope":"relay.connect","exp":1763726400,"name":"Display Name"}
```

- `exp` is UNIX seconds.
- Invalid/expired/used/logged-out/deactivated grant: 200 `{"active":false}` with no extra detail.
- Missing/wrong Basic credentials: 401 `relay.client_auth_failed` with `WWW-Authenticate: Basic realm="qfli-relay"`.
- Missing config: 503.
- Rate limit: 429 `relay.rate_limited`.

## CI workflow added

`.github/workflows/verify.yml` is a dedicated validation-only workflow:

- triggers on pushes to `remote/**`, all pull requests, and `workflow_dispatch`;
- `permissions: contents: read`;
- SHA-pinned `actions/checkout` and `actions/setup-node` at the same versions used by the Studio workflow;
- Node `24.15.0`, matching the repository Dockerfile, `.cnb.yml`, and `.gitlab-ci.yml`;
- `npm ci`, then `npm run lint`, then `npm test`;
- no image build, no registry login, no push, and no dependency on `build-and-push.yml`.

YAML was syntax-checked locally with PyYAML; the workflow itself was not dispatched.

## Tests added (not executed by this worker)

`test/relay-grants.test.js` uses real Express, real SQLite, real QFLI JWT/session, and a stubbed gateway userinfo/account-erase HTTP layer. Coverage:

- anonymous mint rejected;
- unverified-phone mint rejected;
- wrong audience/scope rejected and no row written;
- grant shape, 60-second ISO expiry, hash-only storage;
- body-supplied identity ignored, `sub` comes from `gateway_user_id`;
- valid introspection exact claims and UNIX `exp`;
- replay inactive;
- 8 concurrent introspections: exactly one active;
- expired grant inactive;
- logout (session deleted) inactive;
- deactivation (real `deactivateUser`) inactive;
- wrong Basic 401 + `WWW-Authenticate`;
- missing configuration 503;
- grant/secret never appear in captured logs;
- mint rate limit 429;
- MySQL FK race after SELECT/before INSERT maps to 401 `auth.session_expired`.

CI command: `npm test` (runs `node --test`).

### Out-of-scope local test run (recorded, not repeated)

A reviewer ran `npm test` locally despite the task's prohibition. This worker did not run it and did not use its result as a substitute for cloud CI. The run is recorded here so the report does not falsely imply that no test process ever started.

Full result reported for the relay worktree suite:

- 189 tests total.
- 157 passed.
- 7 failed.
- 25 skipped by design (the MySQL `db-*` suites without a MySQL server).
- A separate single-file run of `test/relay-binding-security.test.ts` had 23 passing tests.

The 7 failures break down as:

- 5 fake-database/SQL-shape mismatches in the relay worker's own tests. The relay worker reported them fixed by static reading; they were not rerun.
- 2 `test/qfli-grant.test.ts` mock cases: "never caches an active result" and "treats active:false as terminal". Both asserted the absolute `gateway.calls`, which is cumulative for the file, so earlier QFLI calls made the expected `1` wrong. The mock was not double-calling. The fixture and assertions were corrected in the relay test file only; no product source changed.

The QFLI worktree's own `test/relay-grants.test.js` was not part of that reported run and remains unexecuted. Cloud CI is still the first authoritative run for it.

## Static checks actually run locally

Re-run against the final worktree state on the current branch:

In `D:/MyNewProjects/_wt/remote-account-binding/qfli-server`:

- `node --check` on all changed/new JS files: all 8 OK:
  - `src/relay-grants.js` OK
  - `src/relay-grant-migration.js` OK
  - `src/routes/relay.js` OK
  - `src/server.js` OK
  - `src/db.js` OK
  - `src/deactivate.js` OK
  - `src/client-context.js` OK
  - `test/relay-grants.test.js` OK
- `npm run lint`: passed (`检查了 68 个 JavaScript 文件与 package.json`, exit 0).
- `git diff --check`: clean (exit 0).
- `.github/workflows/verify.yml` YAML syntax parse: OK (`name=Verify`; triggers `push`, `pull_request`, `workflow_dispatch`; `permissions: contents: read`; job `verify`).

No source or test changes were made in the QFLI worktree during this final re-check. The working tree still contains only the paths listed above.

This worker did not run tests, server startup, SQLite/MySQL probes, migrations against any database, HTTP requests, builds, Docker/WSL/emulators/adb/hdc, or any GitHub Actions workflow dispatch. A reviewer's prohibited local test run is recorded in "Tests added" above; it was not repeated.

## Frozen-contract conformance check

Checked against the frozen endpoint/config contract, without changing code:

| Contract item | Implementation evidence | Verdict |
| --- | --- | --- |
| `POST /api/relay/grants` requires a QFLI session and the realname gate | `src/routes/relay.js:10` uses `authRequired` and `realnameRequired`; `/api/relay/grants` is in `GATED_PREFIXES` at `src/client-context.js:69-72`, which resolves through the existing `hasVerifiedPhone` path | pass |
| Mint only accepts the fixed audience and scope | `AUDIENCE` and `SCOPE` are constants (`src/relay-grants.js:8-9`); `audienceAndScope()` rejects any other value with 400 (`:79-86`) | pass |
| Grant is opaque, 60 seconds, hash-only | `qrg_` + 32 random bytes base64url (`:180`), `TTL_MS = 60 * 1000` (`:10`), `expires_at = now + TTL_MS` (`:183`), only SHA-256 stored (`:181,199-201`) | pass |
| Subject comes from the verified gateway identity, never the body | `mintGrant` takes `gatewayUserId` from the authenticated session and stores it; introspection returns `sub: row.gateway_user_id` (`:251`) | pass |
| Grant is bound to a live `users` + `auth_sessions` pair | Mint rechecks both tables and session expiry before INSERT (`:189-195`); insert stores `user_id`/`session_id` (`:199-201`); FK failure after a concurrent logout is rechecked and mapped to 401 (`:203-207`) | pass |
| Introspection uses server-to-server Basic only | `parseBasic()` and `timingSafeEqual` (`:54-77`); route returns 401 + `WWW-Authenticate: Basic realm="qfli-relay"` for bad credentials (`src/routes/relay.js:33-36`) | pass |
| Introspection is single-use and atomic | Conditional `UPDATE ... WHERE used_at IS NULL AND expires_at > ?`; only `changes === 1` proceeds (`:227-229`) | pass |
| Introspection revalidates the live session before answering | Join on `auth_sessions` and `users`; checks session owner, session expiry, grant expiry, stored audience and scope (`:232-244`) | pass |
| Invalid, expired, replayed, logged-out, deactivated grants answer `active:false` | `introspectGrant()` returns `null`, route answers `{active:false}` with 200 (`src/routes/relay.js:46`) | pass |
| Logout invalidates pending grants | Logout deletes `auth_sessions` (`src/routes/auth.js:220-221`); `relay_grants.session_id` has `ON DELETE CASCADE`, and introspection's join/update also fails once the session row is gone | pass |
| Deactivation invalidates pending grants | `src/deactivate.js:101-108` deletes `relay_grants` for the user before deleting `auth_sessions`; the FK cascade covers the rest | pass |
| Logs never contain the grant or client secret | `logMint` logs only audience/expiry (`src/relay-grants.js:260-262`); `logIntrospect` logs only `active` (`:264-266`); test asserts no `qrg_` or secret in captured logs | pass (test not executed locally) |

No contract deviation was found. The only known fixture issue was the relay test's cumulative `gateway.calls` assertion, corrected without touching product code.

## Security and compatibility notes

- QFLI JWT is never accepted by relay and never sent to relay by this code.
- Gateway access/refresh tokens are never exposed.
- The grant table stores no plaintext grant, no QFLI JWT, no gateway credentials.
- Existing auth/phone rules are not weakened. `authRequired` still verifies the live session and gateway profile; the realname gate is the existing `hasVerifiedPhone` path.
- Relay tables are added after `users` and `auth_sessions`, matching their post-migration column types (`VARCHAR(37)` / `VARCHAR(64)`). The existing `migrateMysqlEntityIds` call and `db.entityIdsMigrated` assignment remain intact and singular.
- No change to existing terminal/Herdr/Claude/Codex session protocols.
- Rollback: stop QFLI service, confirm no pending grants, `DROP TABLE relay_grants`. Account binding stops working; manual pairing is unaffected.

## Unresolved cross-repo work

- pi-relay must call `/api/relay/introspect` with the configured Basic credentials, verify all claims, and never cache/reuse `active:true`. Every exchange/refresh requires a newly minted grant.
- pi-relay must implement `/api/v1/auth/exchange`, refresh-with-grant, device registration, owner initialization, token-kind checks, and revocation/WS close.
- Root must configure `QFLI_RELAY_CLIENT_ID`, `QFLI_RELAY_CLIENT_SECRET`, and `QFLI_RELAY_ISSUER` in deployment and keep them server-side.
- Real MySQL migration and cloud CI remain unverified locally; cloud CI must run `npm test` and a MySQL migration check.
- Final status: QFLI implementation is frozen and its static checks pass. The only local test execution was the reviewer's prohibited run recorded above; no test was rerun. Waiting on cloud CI and the MySQL migration check.

## Appendix: cross-repo consistency review

Read-only review of the four worktrees under `D:/MyNewProjects/_wt/remote-account-binding/` (`qfli-server`, `relay-server`, `core`, `studio`). No test, service, build, or probe was run.

Files reviewed:

- QFLI: `src/routes/relay.js`, `src/relay-grants.js`, `src/relay-grant-migration.js`.
- Relay: `src/oauth/qfli-grant.ts`, `src/relay/api.ts`, `.env.example`, `src/db/{accounts,tokens,bindings,schema.sql}.ts`.
- Core: `lib/remote_control/account/{account_api,account_models,remote_account_controller,relay_credentials,relay_endpoint}.dart`, `lib/remote_control/state/remote_controller.dart`.

### Field names

| Concern | QFLI | Relay | Core | Verdict |
| --- | --- | --- | --- | --- |
| Mint request | reads `audience`, `scope` (`relay-grants.js:79-86`) | — | sends `audience`, `scope` (`account_api.dart:142-143`) | match |
| Mint response | `grant`, `expires_at` (ISO), `audience` (`relay-grants.js:211-215`) | — | reads `grant`, `audience`, `expires_at` (`account_models.dart:219-232`) | match |
| Introspect request | reads `grant`, alias `token` (`relay-grants.js:135-138`) | sends `{grant}` (`qfli-grant.ts:173`) | — | match |
| Introspect response | `active`, `iss`, `sub`, `aud: [..]`, `scope`, `exp` (UNIX s), `name` (`relay-grants.js:248-256`) | reads all seven, `aud` as string or array (`qfli-grant.ts:99-153`) | — | match |
| Exchange response | — | `account_id`, `display_name?`, `access_token`, `refresh_token`, `token_type`, `access_expires_at`, `refresh_expires_at` (`api.ts:371-384`) | reads `account_id`, `access_token`, `refresh_token`, `access_expires_at`, `refresh_expires_at` (`account_api.dart:379-400`) | match |

`display_name` and `token_type` are unused by the client on purpose.

### Paths

- QFLI: `/api/relay/grants`, `/api/relay/introspect` (`relay.js:10,31`).
- Relay introspect client: `${baseUrl}/api/relay/introspect` (`qfli-grant.ts:118`).
- Relay account API: `/api/v1/auth/exchange`, `/api/v1/auth/token/refresh`, `/api/v1/devices`, `/api/v1/devices/bindings`, `/api/v1/devices/:id/bindings(/:accountId)` (`api.ts:957-1044`).
- Core: same five relay paths (`account_api.dart:212,233,258,295-296,325`) and `$_baseUrl/api/relay/grants` (`account_api.dart:138`).
- Verdict: no path mismatch. Core derives the relay HTTP origin from the WebSocket URL (`relay_endpoint.dart:46-62`). `/api/v1/...` is addressed on the user-picked relay host.

### Issuer / audience / scope

- QFLI issuer: `QFLI_RELAY_ISSUER`, else `PUBLIC_BASE_URL`, reduced to `.origin` (`relay-grants.js:37-45`).
- Relay issuer: `QFLI_RELAY_ISSUER`, else the origin of `QFLI_RELAY_BASE_URL` (`qfli-grant.ts:272-275`). Compared after trailing-slash normalisation (`qfli-grant.ts:95-97,130-131`).
- Both sides normalise to an origin. A trailing slash or a path cannot cause a false mismatch.
- Operational requirement: the relay's `QFLI_RELAY_BASE_URL` and `QFLI_RELAY_ISSUER` must resolve to the same origin as QFLI's `PUBLIC_BASE_URL` or `QFLI_RELAY_ISSUER`.
- Example values differ. Relay uses `https://qfli.example` (`.env.example:48,54`). QFLI uses `https://qfli.suanxiwanjie.cn`. Examples may differ, so this is a deployment checklist item and not a code defect.
- Audience `cloudterminal-relay` and scope `relay.connect` are identical constants on all three sides (`relay-grants.js:8-9`, `.env.example:55-56` + `qfli-grant.ts:231-232`, `account_models.dart:242,245`).
- Relay checks `aud.includes(expected)` and `scope === expected` (`qfli-grant.ts:134-141`). QFLI introspection revalidates the stored `audience` and `scope` before answering `active:true` (`relay-grants.js:241-242`).
- Verdict: consistent.

### Expiry

- Grant TTL is 60 s (`relay-grants.js:10`). Mint answers ISO `expires_at`. Introspection answers UNIX `exp` (`relay-grants.js:213,254`).
- Relay treats a grant whose `exp` has passed as `rejected`, even when QFLI said active (`qfli-grant.ts:144-148`).
- Core parses ISO or UNIX in `parseAccountTime` and rejects a grant with a different audience (`account_models.dart:224-225,231`).
- Relay token lifetimes: access 15 min and refresh 30 days (`main.ts`, `.env.example:61-62`). Core compares access with a 30 s skew (`account_api.dart:53-58`).
- Verdict: consistent. Units differ by design, and every consumer accepts the documented form. QFLI answers ISO on mint and UNIX on introspect. Relay answers ISO on token pairs.

### Basic auth

- Relay sends `Basic base64(clientId:clientSecret)` from `QFLI_RELAY_CLIENT_ID` and `QFLI_RELAY_CLIENT_SECRET` (`qfli-grant.ts:119,171`).
- QFLI accepts exactly one `Basic` scheme. It splits on the first `:`, tolerates URI-encoded credentials, and compares both halves with `timingSafeEqual` (`relay-grants.js:54-77`).
- Failure answers 401 with `WWW-Authenticate: Basic realm="qfli-relay"` (`relay.js:34-36`). Relay maps 401 and 403 to `unavailable`, which is retryable (`qfli-grant.ts:181-186`).
- Verdict: consistent. No secret or grant reaches a log line. QFLI logs only audience, expiry, and active. Relay logs only status and reason.

### Fresh grant on refresh

- Core always mints a new grant before refreshing and sends `{refresh_token, grant}` (`remote_account_controller.dart:602-640`, `account_api.dart:232-237`).
- Relay requires a grant for `origin=qfli` tokens, rejects a gateway token presented with a grant (`origin_mismatch` → 401 `invalid_grant`), rejects a QFLI token presented without one (401 `grant_required`), and revokes the freshly minted refresh if the grant `sub` differs (`api.ts:542-604`).
- Verdict: consistent, and the relay side is stricter than the client (defence in depth).

### Defects found

**No confirmed defect in the QFLI ↔ relay ↔ core contract.** The field names, paths, issuer/audience/scope handling, expiry units, Basic auth, and refresh-with-fresh-grant behaviour agree in every direction reviewed.

Observations that are not contract defects, recorded so they are not re-discovered:

1. `relay-server/.env.example:45` says "All three are required together" while five variables are listed. Only `QFLI_RELAY_BASE_URL`, `QFLI_RELAY_CLIENT_ID`, and `QFLI_RELAY_CLIENT_SECRET` are required (`qfli-grant.ts:248-259`). This is wording only and has no behaviour impact.
2. QFLI `configuration()` re-reads the process environment on every call. The feature fails closed when a variable is missing. A rotated client secret needs a restart. Deployment note only, not a contract defect.
3. The `studio` worktree holds no relay-grant client code, so no inconsistency was possible there. The account flow lives in `core`.

No report outside this file was modified by the QFLI review. The only source-tree change outside QFLI is the relay test fixture correction described below; the desktop test file named in the separate assignment is also new. See the respective sections.

### Relay test fixture correction

A reviewer ran the forbidden local `npm test`. It reported two failures in the relay's `test/qfli-grant.test.ts`: the "never caches an active result" case and the "treats active:false as terminal" case.

Both asserted the absolute value of `gateway.calls`. That counter is cumulative for the whole file, so any earlier QFLI call made the expected `1` wrong. The mock was not double-calling. The assertion compared against process start instead of the start of the case.

Fixed in the test fixture only, with no product source change:

- `test/qfli-grant.test.ts:195-202` adds `callsDuring()`, which snapshots `gateway.calls` before the action and asserts the delta.
- `test/qfli-grant.test.ts:207-208` asserts exactly one QFLI call for one exchange.
- `test/qfli-grant.test.ts:223-237` asserts one call for the first consumption and one more for the replay, both as deltas.
- `test/qfli-grant.test.ts:239-246` asserts one call for the terminal `active:false` case as a delta.
- `test/qfli-grant.test.ts:248-254` asserts zero calls for a malformed grant as a delta.

This correction was not executed locally. No test, check, build, service, database probe, or cloud CI was run. The relay worktree contains other pre-existing modifications from its own worker. This review touched only the untracked `test/qfli-grant.test.ts`.

### Desktop discovery test file

A separate assignment added one file to the desktop worktree, with no product and no other test change:

- `studio/companion/remote_agent/test/desktop-discovery.test.ts` (new, 487 lines).

It covers `src/agent/desktop-discovery.ts` without starting any tool process:

- `node:test` `mock.method` replaces `HerdrBridge.prototype.workspaces/panes`, `CodexBridge.prototype.projects/threads/close`, and injects the probe plus the Claude history loader. The production constructors only assign fields, so no CLI, socket, or app-server proxy starts.
- Real source mapping: Herdr panes keep `pane_id` and build `label · agent · cwd` subtitles; Claude history keeps `sessionId`, summary, and `lastModified`; Codex threads keep `id`, title, and `updatedAt`.
- `bound` is decoration only: bound rows are still listed, and the returned `bound` array echoes the caller's ids, including ids with no row.
- An installed tool that returns nothing yields no session and no failure. A tool that is absent is never queried.
- One failing provider removes only its own rows and adds exactly one `{kind,message}` entry. That covers workspace-list, pane-list, history, project-list, and thread-list failures. The Codex bridge is closed on both success and failure paths.
- Codex read-only threads assert `canOpen: true` and `canAcceptInput: false`, while a controllable thread asserts both true. This is the behaviour the desktop worker is still fixing, so the two flags are pinned separately.

Only `node --check` was run on this file (exit 0). The test was not executed, and `npm run check` was not run, per the assignment's restriction.
