# Remote Account Bindings

## 1. Scope / Trigger

Apply this contract to Relay account authorization, computer binding, device
revocation and upgrades from legacy pairing. QFLI grants follow
[relay-grants.md](./relay-grants.md). The Relay repository owns implementation.
Studio carries an exact five-file copy of its transport core.

## 2. Signatures

- `POST /api/v1/auth/exchange`: `{grant}`.
- `POST /api/v1/auth/token/refresh`: `{refresh_token,grant}` for QFLI tokens.
- `GET /api/v1/devices`: Relay access bearer.
- `POST /api/v1/devices/bindings`: Relay access bearer and `{pair_code}`.
- `POST /api/v1/devices/:deviceId/bindings`: the same consent for a known ID.
- `DELETE /api/v1/devices/:deviceId/bindings/:accountId`: revoke a binding.
- Client hello: `{t:'hello',role:'client',agentId,relayToken,v:1}`.

## 3. Contracts

Exchange returns `account_id`, `access_token`, `refresh_token`,
`access_expires_at` and `refresh_expires_at`. Expiry values are ISO 8601 UTC.
Access lasts 15 minutes. Refresh lasts 30 days. QFLI refresh always consumes
a new grant and verifies the same subject. The no-grant legacy refresh branch
must reject QFLI-origin tokens. Access and refresh kinds are never interchangeable.

Bind directly from the live short code. Return the resolved `device_id`.
Do not consume legacy pairing to discover an ID before attempting account bind.
Both routes share consent validation and one transactional binding path.
Lock the device row before assigning its first owner. Any historical owner,
including a revoked owner, prevents a second account becoming owner.

`ct_devices.account_managed` is monotonic. Set it on first account binding.
Upgrade it from every historical `ct_bindings` row, including revoked rows.
It must never return to zero when the last binding is revoked. A managed device
cannot authorize clients through its old legacy secret. A new binding requires
fresh desktop consent. Old OAuth device approval must not bypass this rule.

Commit binding and token revocation atomically. After commit, invalidate token,
binding and legacy-secret caches, fence pending authorization and WebSocket
joins, and close affected sockets. A cached negative binding result must also
be invalidated after a new binding. Authenticated agent metadata supplies the
computer name, platform and last-seen time. Anonymous requests cannot replace
an existing device secret or change ownership.

## 4. Validation & Error Matrix

| Condition | Required result |
| --- | --- |
| QFLI refresh without a new valid grant | Reject without issuing tokens |
| Refresh token used for HTTP access or a socket | Reject token kind |
| Expired or consumed pairing code | Reject without adding a binding |
| Account without an active binding | Deny device access |
| Account-managed device plus legacy secret | Deny legacy authorization |
| Revocation races an authorization read | The stale read cannot join or repopulate cache |
| Token revocation SQL fails | Roll back binding revocation |
| Historical revoked binding during upgrade | Keep the account-managed marker set |

## 5. Good / Base / Bad Cases

- Good: bind once, revoke, reject the old token, and close the existing socket.
- Base: an unbound computer still accepts the existing manual pairing flow.
- Bad: a revoked member uses OAuth approval or a remembered secret to rebind
  without a new desktop code.

## 6. Tests Required

Cover grant origin and token kind, code-only binding, concurrent first owners,
replayed codes, account isolation, revocation rollback, active socket closure,
pending authorization races and negative-cache invalidation. Upgrade fixtures
must include active and revoked historical bindings. Race fixtures must seed a
valid access token before waiting on the controlled database read.

Cloud CI runs Relay type checks and tests. The migration task permits local
static checks only; database, socket and integration execution stays unverified
until cloud CI runs.

## 7. Wrong vs Correct

Wrong: revoke a binding, then attempt an independent token update, and skip
connection invalidation when the second update fails.

Correct: commit the database changes as one transaction, then invalidate
authorization generations and close the affected connections.

Wrong: treat `account_managed = 0` as authoritative immediately after adding
the column to an existing database.

Correct: backfill from all historical bindings before accepting legacy clients.
