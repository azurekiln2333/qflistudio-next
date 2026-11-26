# Desktop Companion and Remote Accounts

## 1. Scope / Trigger

Apply this contract to Studio desktop pairing, Agent history and phone account
connections. Core owns the reusable pages and controllers. Studio owns the
real AuthStore scope, sign-in navigation and installed companion packaging.

## 2. Signatures

- `RemoteAccountScope`: pass the current application AuthStore.
- `RemoteAccountController.credentialsFor({accountId,relayUrl})`: return a
  complete refreshed credential snapshot or `null`.
- `DesktopCompanionChannel`: `frames`, `send`, `closed`, `close`.
- Sidecar request: `{type:'open_session',id,kind,origin,canAcceptInput}`.
- Sidecar output: `{type:'stream_event',kind,sessionId,eventKind,text,seq}`.
- Attach first frame: `{type:'auth',token}`.

## 3. Contracts

QFLI JWT goes only to QFLI. Relay receives a grant or its own tokens.
Derive the account HTTP origin from the selected WebSocket endpoint. Reject
userinfo, queries and fragments. Disable redirect following on credentialed
requests. Store Relay tokens separately from auth and manual pairing files.
Without a supported secure backend, keep tokens in memory and show that
authorization expires when the app exits.

Fence asynchronous operations by QFLI identity, generation and selected Relay.
Identity comparison alone does not distinguish A-to-B-to-A. Persisted
credentials also belong to a QFLI identity. Serialize backend reads, writes
and clears. A stale operation cannot overwrite or clear a newer session.
Disconnect the previous account immediately on an identity change. Concurrent
callers must await the same refresh and receive matching token and expiry data.
Bind from the short code directly, then connect using the returned device ID.

Desktop discovery and opening must use the same provider. Pass the discovered
view to the stream binding instead of looking it up in an unrelated source.
Codex history uses `turn.items`; Claude SDK history uses its history loader;
Herdr panes use the pane poller. Report read-only capability truthfully.
Roll back a failed stream binding so opening it again retries. Show provider
errors in the open view. Do not create synthetic sessions or output.

Reuse the existing QR renderer and pairing URI. Show a missing-companion state
after discovery completes. Keep child ownership above page navigation, and
follow [process-lifecycle.md](./process-lifecycle.md). Cancel a child when
readiness or socket connection fails. Stop or reuse an old child before
reconnecting. Stop/dispose must fence and await pending startup.

macOS keeps the Studio sandbox. Package a separate companion app. Read the
user-selected `sidecar.json` through the file picker with
`com.apple.security.files.user-selected.read-only`. Connect only to loopback
and authenticate using the random per-run attach token. Unauthenticated
clients receive neither snapshots nor broadcasts.

The installer stages the target Node architecture and native addons. Use the
target Node for npm lifecycle subprocesses, verify archive hashes on reuse,
ship `relay-core.json`, and check native binary architecture. The verifier CLI
guard uses `fileURLToPath(import.meta.url)` on Windows.

## 4. Validation & Error Matrix

| Condition | Required result |
| --- | --- |
| Account or Relay changes during refresh | Discard the stale result |
| A-to-B-to-A while a request is pending | Reject the first A generation |
| Access refresh has multiple waiters | All receive the same fresh snapshot |
| Companion is absent | Show installation or attachment guidance |
| Socket startup fails after child readiness | Cancel the owned child |
| Provider open fails | Show error and allow retry |
| Attach token is absent or incorrect | Disclose no pairing or session data |
| Unsupported secure backend | Keep tokens in memory and explain session lifetime |

## 5. Good / Base / Bad Cases

- Good: open a discovered Codex thread using the same Codex provider and show
  its real history.
- Base: account service is unavailable but manual pairing stays reachable.
- Bad: consume a pairing code to find a device ID, then consume it again to bind.
- Bad: a stale save clears credentials installed by a newer account.

## 6. Tests Required

Core CI covers controller refresh, identity/Relay races, slow backend reads and
writes, missing companion, retry and startup cancellation. Companion CI covers
discovery-to-open for each provider, event field names and unauthenticated
broadcast rejection. Packaging CI covers Windows, Linux and macOS paths and
target architecture. Importing the verifier must register tests without exiting.

Keep cloud test execution and real phone/desktop pairing separate from local
static analysis in the task report. Unexecuted checks remain unverified.

## 7. Wrong vs Correct

Wrong: send a refreshed access token with the previous expiry metadata.

Correct: return one complete credential snapshot from the shared refresh.

Wrong: return early because a failed provider open left an ID in the binding map.

Correct: remove the failed binding and let a retry open through its provider.
