# Gateway Authentication

## 1. Scope

`azurekiln-qfli-server/` implements QFLI identity mapping and business data. The Flutter client is in `packages/qfli_studio_core/`. The OAuth2 gateway owns credentials, profile fields, roles, and external identities. Huawei second-factor completion is a native OAuth handoff, including when an unmatched identity first goes through the skip flow.

## 2. Signatures

- `users(id, gateway_user_id UNIQUE)` is the complete active identity table. Local IDs are `user_` plus 32 random hexadecimal characters, stored as `VARCHAR(37) CHARACTER SET ascii COLLATE ascii_bin` in MySQL and `TEXT` in SQLite. All user references use the same string type. A null gateway ID is allowed only for historical accounts pending an explicit administrator link.
- `user_state(user_id, points, checkin_streak, last_checkin_date, created_at)` holds QFLI business state.
- `auth_sessions(id, user_id, credentials, access_expires_at, expires_at)` stores encrypted gateway tokens. QFLI JWTs identify `{uid, sid, exp}`.
- `POST /api/auth/login`, `/huawei`, `/huawei/complete`, `/register`, `/email-code`; `GET /api/auth/captcha`.
- `gateway.completeHuawei(pending, code)` calls gateway `POST /api/v1/auth/oauth/oidc/complete` with JSON `{code}` and the server-held `X-Oidc-Pending` credential.
- `npm run link-user -- <localId> <gatewaySub>` explicitly binds an unbound historical account.

## 3. Contracts

Login input is `{username,password,emailCode?,totpCode?,captchaId?,captchaCode?}`. Huawei input is `{authorizationCode}`; second-factor completion is `{challengeId,code}`. Successful login returns `{token,user}` with string `user.id` and string `user.gatewayUserId`. JWT `uid` validation uses the shared `isUserId` helper.

Huawei quick login can also return `{bindingRequired:true,bindingId,phoneAvailable}` without creating a gateway or QFLI account. A Huawei verified phone matching a verified gateway phone is linked and signed in directly when the gateway's phone autolink setting is enabled. Otherwise `/api/auth/huawei/bind` verifies the existing account through the normal password, MFA and CAPTCHA flow before linking its gateway subject; `/api/auth/huawei/skip` explicitly creates a new account and completes login. Both use a short-lived, single-use server-side pending identity; never replay the Huawei authorization code or accept a client-supplied identity or phone. QFLI and gateway pending state are process-local, so multi-instance deployment requires shared pending storage.

`user.avatarUrl` maps from gateway `picture`. The client must parse, persist, and preserve this field when copying user state. Personal avatars use persistent per-account disk caches keyed by URL. Do not refresh profile on page entry or evict avatar images on return from account pages. Pull-to-refresh updates profile and rechecks the local avatar cache; an unchanged URL with a cached file must not download again. During loading/failure, display the colored background with the nickname initial, retaining the previous decoded photo while a replacement loads. Post lists, post details, and comments intentionally hide author avatars.

`publicUser`, `/me/tasks`, and `/me/checkin` return `growth: {experience, level, levelExperience, requiredExperience}`. `growth.js` derives lifetime experience from `SUM(checkins.points)`; every 100 experience advances one level starting at level 1. Duplicate check-ins do not add experience; spending current points does not lower experience. This uses the existing check-in ledger and requires no schema migration. The App persists growth with its cached user and updates it directly from task/check-in responses without refetching the avatar.

Gateway endpoints are derived only from `AZK_OAUTH2_BASE_URL` and fixed paths in `src/gateway.js`; individual endpoint environment overrides are not supported. `AZK_OAUTH2_CLIENT_ID`, `AZK_OAUTH2_CLIENT_SECRET`, and a registered redirect URI belong on the backend. Default user scopes are `openid profile email phone roles offline_access`.

`AZK_PROVIDER` is an optional application prefix, trimmed and lowercased. Third-party provider keys use `<prefix>_<channel>`: `qfli` becomes `qfli_huawei`. The resulting key must match the gateway's 2-128 character `[a-z0-9][a-z0-9_-]*` format. Empty prefixes omit the provider parameter; password login does not use it. Only password and Huawei login are implemented; WeChat/QQ suffixes are naming conventions for future integrations, not enabled login methods.

The existing gateway's JSON `POST /oauth2/authorize` returns a `redirect` URL, not an access token. QFLI extracts and validates its code, callback address, and random state, then exchanges the code at `/oauth2/token` with the same redirect URI and S256 verifier. Huawei's code is sent to the gateway quick-login endpoint as `code`; it is never used directly as a gateway token-endpoint code.

Huawei MFA completion also returns the OAuth handoff directly as JSON: `{authorization_code, state, redirect_uri, redirect, ...}`. The `redirect` contains the gateway code and original state. `completeHuawei` passes this response through the shared `authorizationCode` validator, exchanges the code using the original pending PKCE verifier and configuration, then fetches userinfo. The gateway does not create a browser session for this handoff; do not expect a session cookie or make a second `GET /oauth2/authorize`. The existing `AZK_OAUTH2_*` configuration remains authoritative.

Registration requires `{username,email,emailCode,password,nickname?}` and optional CAPTCHA fields. Send registration email codes using `/api/email-verification/send` with `purpose=register`; require successful SMTP delivery. Forward `emailCode` as `email_code` and `nickname` as `name` to `/oauth2/register`.

The gateway extension in `gateway-extension/` supports bearer-authenticated `PUT /oauth2/profile` for `name` and `description`, and client-authenticated public author lookups requiring client permission `qfli_public_profile`. Public responses exclude email, phone, and roles. Models are initialized during gateway bootstrap: obtain them using `getModels()` inside requests, rather than capturing undefined model instances when registering routes.

## 4. Validation And Errors

| Condition | Response |
| --- | --- |
| Missing gateway configuration | 503 with the missing environment key |
| Missing or invalid gateway sub/state/code | 502; do not create a local identity |
| MFA response missing redirect or containing wrong callback/state/code | 502 with `gateway.redirect_missing` or `gateway.redirect_invalid`; do not exchange a token |
| MFA code rejected by the gateway | Preserve its status and `errorKey`; do not exchange a token |
| Invalid local session or revoked gateway identity | 401; client clears the session |
| Email/TOTP required | 428 with `factor`; Huawei also includes `challengeId` |
| CAPTCHA required/invalid | Preserve `errorKey=captcha.*`; refresh the consumed image |
| Email delivery failure | Error response; do not claim email was sent |
| Gateway unavailable | 502; client retains its local cache |

Express 4 route promises must be forwarded to `next(err)`; `src/server.js` wraps all registered route and middleware handlers before mounting them.

## 5. Cases

- Good: both login methods resolve to the same gateway sub and therefore the same local ID.
- Base: a new gateway identity creates one random string ID mapping and one business-state row; an existing mapping keeps its ID.
- Bad: a historical local username happens to match a gateway username. This is insufficient proof of ownership; no automatic binding is allowed.
- Good MFA: a valid completion JSON produces token exchange and userinfo, without Cookie or an authorize-page request.
- Base MFA: the pending login's verifier, callback and state are reused after successful verification.
- Bad MFA: a successful HTTP response carries a missing code or different state/callback. Reject it before token exchange.

SQLite migration creates a consistent backup using `VACUUM INTO`, moves historical business state, rebuilds only `users` while retaining IDs, and validates foreign keys before committing. MySQL migration retains a historical archive before DDL and supports continuing an interrupted migration. Do not run source imports against real databases while performing syntax checks.

The subsequent string-ID migration saves `qfli_user_id_migration(old_id,new_id)`, updates all user references, and invalidates integer-ID sessions. SQLite rebuilds user-ID columns inside a backed-up transaction. MySQL persists foreign-key metadata and progress before its nontransactional DDL, converts column types before creating any new referencing tables, updates rows in a transaction, and restores constraints. Both drivers rename existing cloud/terminal directories using the saved mapping; conflicting target directories stop startup without overwriting files. Stop old instances and back up the database/data directory before deployment.

All remaining business entity IDs also use random strings generated by `entity-id.js`: `proj_`, `post_`, `comment_`, `zone_`, and `audit_`, each followed by 32 hex characters. Their MySQL primary and referencing columns use `VARCHAR(48) CHARACTER SET ascii COLLATE ascii_bin`. Counts and timestamps stay numeric. `entity-id-migration.js` retains `qfli_entity_id_migration(entity_type,old_id,new_id)`, converts IDs and references before creating new tables, and renames cloud project directories. Cloud listing includes nullable `legacyId` so the App can update saved cloud associations while retaining existing local caches. No route or App model may convert a business ID with `Number`, `int.parse`, or `as num`.

## 6. Verification Points

Native password forms call `/api/auth/login/requirements` before collecting challenges. The gateway's `check_verification` branch validates credentials and registered OAuth parameters with account throttling, returns factor and CAPTCHA requirements, and sends a login email code when required. It must not issue sessions, authorization codes, CAPTCHA grace cookies, or MFA pending tokens. The final authorization request still validates every required factor and CAPTCHA. Credential edits invalidate the App's collected verification state.

QFLI request logging uses AsyncLocalStorage for a generated request ID and current stage. Error responses include the ID. Gateway logs record endpoint origin/path, status, duration and safe error codes only; never log query strings, bodies, cookies or credentials. Preserve configuration-unavailable HTTP 503. Huawei code exchange, token exchange, userinfo and local session creation are distinct stages.

When tests are requested, cover stable IDs across both login methods; concurrent first login; malformed sub; wrong PKCE/state; missing configuration; SMTP failures; registration code consumption; MFA/CAPTCHA retries; gateway revocation; refresh-token rotation; preservation of old post/cloud IDs; migration retry and foreign-key integrity. Use isolated databases and gateway credentials.

`node --test test/huawei-binding.test.js` must cover the cookie-free Huawei MFA handoff: assert the pending header and submitted code, original S256 challenge/verifier pairing, redirect URI and client ID, bearer userinfo request, and absence of any authorize-page request. Reject missing redirects/codes and mismatched origins, paths or state before token exchange; preserve rejected MFA errors. An invalid Huawei authorization-code probe checks only the initial upstream exchange, not MFA completion. Earlier fixes to Huawei's upstream URL did not update this later handoff; keep producer and consumer response fixtures aligned when the gateway changes.

Single-process deployment is currently required: pending login/MFA state and refresh locks are in process memory. Multiple instances need shared pending state and database-backed rotation locks.

## 7. Wrong And Correct

Wrong: store profile/admin flags in `users`, link by username, accept claims sent by the App, or treat a Huawei code as a gateway code.

Correct: use `userinfo.sub` for the unique mapping, obtain profile and roles from validated gateway tokens, explicitly link historical IDs, and keep each authorization-code exchange at its issuing service.

Wrong MFA: discard the completion JSON and open the authorize page with a nonexistent gateway session cookie. Correct MFA: validate `result.redirect` against pending callback/state, then exchange its code with the pending verifier.
