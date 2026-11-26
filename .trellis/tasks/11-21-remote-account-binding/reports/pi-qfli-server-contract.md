# QFLI relay grant contract (pi-qfli-server)

Status: implementation contract for pi-relay. No secret values in this file.

## Configuration (QFLI server only)

| Name | Required | Meaning |
| --- | --- | --- |
| `QFLI_RELAY_CLIENT_ID` | yes | Relay server-to-server Basic username. |
| `QFLI_RELAY_CLIENT_SECRET` | yes | Relay server-to-server Basic password. Never sent to clients or logged. |
| `QFLI_RELAY_ISSUER` | recommended | Stable QFLI service origin put in `iss`. Falls back to `PUBLIC_BASE_URL`; if both are empty the relay endpoints fail closed with 503. |
| `QFLI_RELAY_GRANT_RATE_LIMIT` | no | Grants per user per minute, default `10`. |
| `QFLI_RELAY_INTROSPECT_RATE_LIMIT` | no | Introspection calls per relay client per minute, default `120`. |

Fixed server constants: audience `cloudterminal-relay`, scope `relay.connect`, grant TTL 60 seconds. The request cannot widen either value.

## POST /api/relay/grants

- Auth: `Authorization: Bearer <QFLI JWT>`; the existing `authRequired` verifies the live `auth_sessions` row and gateway profile.
- Gate: existing verified-phone/realname gate; unverified users get 403 `realname.required`.
- Body: `{"audience":"cloudterminal-relay","scope":"relay.connect"}`.
- Success 200: `{"grant":"qrg_<43 base64url chars>","expires_at":"2026-11-21T12:00:00.000Z","audience":"cloudterminal-relay"}`.
- `expires_at` is ISO 8601 UTC. The grant is opaque, 60-second, single-use, and shown only once.
- Subject is taken only from the verified `users.gateway_user_id` of the live session. Any `sub`, `account_id`, `gateway_user_id`, or username in the body is ignored.
- Wrong/missing audience or scope: 400 `relay.audience_invalid` / `relay.scope_invalid`, no grant issued.
- Missing relay configuration: 503. Rate limit: 429 with `retryAfter`.

## POST /api/relay/introspect

- Auth: HTTP Basic with `QFLI_RELAY_CLIENT_ID` / `QFLI_RELAY_CLIENT_SECRET`. Missing/wrong credentials: 401 with `WWW-Authenticate: Basic realm="qfli-relay"`. Missing server configuration: 503.
- Body: JSON `{"grant":"..."}`. `token` is also accepted as a compatibility alias.
- Valid and newly consumed: 200
  ```json
  {"active":true,"iss":"https://qfli.example","sub":"gateway-sub","aud":["cloudterminal-relay"],"scope":"relay.connect","exp":1763726400,"name":"Display Name"}
  ```
- `exp` is UNIX seconds. `iss` is the configured stable QFLI origin. `sub` is the verified gateway subject, never the QFLI local `user_...` id.
- Invalid, expired, already used, logged-out, deactivated, or otherwise unavailable grant: 200 `{"active":false}` with no extra detail.
- Consumption is an atomic conditional update (`used_at IS NULL` + unexpired) inside a transaction, so concurrent introspections yield exactly one `active:true`.
- Consumption rechecks the live `auth_sessions` row and `users` row. Logout or deactivation therefore makes pending grants inactive.
- Only `sha256(grant)` is stored. The grant plaintext is never persisted or logged.
- Lazy cleanup removes expired grants and used grants older than one hour.

## Relay expectations

- Relay must send `grant` to `/api/relay/introspect` with the configured Basic credentials, verify `active`, `iss`, `sub`, `aud`, `scope`, and `exp`, then issue its own access/refresh tokens. It must not accept the QFLI JWT as a relay token.
- Relay must never cache or reuse an `active:true` introspection result. The grant is single-use: every exchange/refresh needs a newly minted grant, and replaying the same grant must fail even inside the 60-second TTL. Do not derive a cache window from the QFLI TTL.
- Relay must treat `active:false` as a terminal failure and must not retry the same grant.
