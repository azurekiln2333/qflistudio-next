# QFLI Relay Grants

## 1. Scope / Trigger

Apply this contract when QFLI authorizes a remote-computer relay connection.
The implementation lives in `azurekiln-qfli-server/src/relay-grants.js` and
`src/routes/relay.js`. QFLI validates its own session. Relay receives an opaque
single-use grant and never receives the QFLI JWT or gateway credentials.

## 2. Signatures

- `POST /api/relay/grants`: QFLI bearer session plus the existing realname gate.
- `POST /api/relay/introspect`: server-to-server HTTP Basic authentication.
- `mintGrant({userId,sessionId,gatewayUserId,issuer,name})`.
- `introspectGrant(grant)`: one atomic consumption, returning claims or `null`.
- `relay_grants(grant_hash,user_id,session_id,issuer,audience,scope,name,expires_at,used_at,created_at)`.

MySQL uses ASCII binary `VARCHAR(64)` for the SHA-256 hash and session ID, and
`VARCHAR(37)` for the local user ID. Timestamp columns contain epoch milliseconds.
Both user and session foreign keys cascade on deletion. SQLite uses matching
TEXT identity columns and INTEGER timestamps.

Run this additive migration after the existing user-ID and entity-ID migration
pipeline. Preserve `migrateMysqlEntityIds` and `db.entityIdsMigrated`. Do not
replace that pipeline with unconditional user-column DDL.

## 3. Contracts

Mint request:

```json
{"audience":"cloudterminal-relay","scope":"relay.connect"}
```

Mint response:

```json
{"grant":"qrg_<43 base64url characters>","expires_at":"<ISO 8601 UTC>","audience":"cloudterminal-relay"}
```

Generate 32 random bytes. Store only the SHA-256 hash. Expire the grant after
60 seconds. The response is the only place that exposes the grant.

Introspection request is `{"grant":"qrg_..."}`. `token` is a compatibility
alias. Valid first consumption returns:

```json
{"active":true,"iss":"<QFLI origin>","sub":"<gateway subject>","aud":["cloudterminal-relay"],"scope":"relay.connect","exp":1234567890,"name":"<display name>"}
```

`exp` contains Unix seconds. Mint derives `sub` only from the validated live
session and `users.gateway_user_id`. Body-supplied identity has no authority.
Introspection rechecks the user and session after claiming the grant.

Environment keys:

| Key | Contract |
| --- | --- |
| `QFLI_RELAY_CLIENT_ID` | Required Basic username |
| `QFLI_RELAY_CLIENT_SECRET` | Required server-side secret |
| `QFLI_RELAY_ISSUER` | Issuer URL, normalized to its origin |
| `PUBLIC_BASE_URL` | Issuer fallback when the explicit key is absent |
| `QFLI_RELAY_GRANT_RATE_LIMIT` | Per-user mint count per minute, default 10 |
| `QFLI_RELAY_INTROSPECT_RATE_LIMIT` | Per-client introspection count per minute, default 120 |

Introspection consumers must never cache an `active:true` response. Every
exchange and QFLI-origin refresh requires a new grant.

## 4. Validation & Error Matrix

| Condition | Required result |
| --- | --- |
| Missing or expired QFLI session | 401 |
| Unverified phone under the existing gate | 403 `realname.required` |
| Wrong audience or scope | 400 `relay.audience_invalid` or `relay.scope_invalid` |
| Missing relay configuration | 503 |
| Missing or wrong Basic credentials | 401 `relay.client_auth_failed`, Basic challenge |
| Invalid, expired, consumed or logged-out grant | 200 `{"active":false}` |
| Rate limit exceeded | 429 `relay.rate_limited` |
| Logout wins a mint FK race | Roll back, recheck session, return 401 `auth.session_expired` |

Claim with one conditional update inside the transaction:

```sql
UPDATE relay_grants SET used_at = ?
WHERE grant_hash = ? AND used_at IS NULL AND expires_at > ?
```

Only `changes === 1` may continue. Recheck `auth_sessions` and `users` in the
same transaction. Cleanup runs outside it to avoid opposite lock order against
session deletion and cascading grant cleanup. Do not convert unrelated FK
failures into successful authorization.

## 5. Good / Base / Bad Cases

- Good: two concurrent introspections yield one active result and one inactive
  result.
- Base: a valid verified session mints a grant and consumes it once.
- Bad: a successful introspection is cached and the grant can be exchanged twice.
- Bad: a pending grant remains usable after logout or deactivation.

## 6. Tests Required

`test/relay-grants.test.js` must assert the 60-second TTL, hash-only storage,
body identity rejection, exact claims, replay rejection, concurrent consumption,
logout/deactivation invalidation, Basic failures, missing configuration,
rate limiting and the MySQL logout/FK race. Capture logs and assert that neither
the grant nor Basic secret appears.

Run `npm run lint` and `npm test` in the dedicated verification workflow.
The task restriction permits local syntax/static checks only. Tests, database
migrations and service checks remain unverified until cloud CI executes them.

## 7. Wrong vs Correct

Wrong: use the request body account ID, store the grant plaintext, or accept a
cached successful introspection.

Correct: derive the subject from the live session, persist the grant hash,
atomically claim it and recheck the session before returning claims.

Wrong: create new foreign keys before the existing identity migrations finish.

Correct: preserve the migration pipeline and append the relay-grant migration
after the referenced identity columns reach their final types.
