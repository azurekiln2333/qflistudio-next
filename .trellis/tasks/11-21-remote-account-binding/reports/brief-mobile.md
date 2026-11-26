Active task: D:/MyNewProjects/qflistudio/.trellis/tasks/11-21-remote-account-binding

You are pi-mobile, the already-dispatched implement worker. Implement directly; do not spawn workers or stop at another plan. User authorized the existing four Pi sessions in workspace w37. Read PRD/design/implement, implement.jsonl and research/implementation-contract.md; consult research/pi-mobile.md and pi-account.md as needed. Apply main project's trellis-before-dev. Original CloudTerminal is read-only.

WRITE ALLOWLIST: D:/MyNewProjects/_wt/remote-account-binding/core
- app.dart for a narrow account scope with existing AuthStore.
- new remote_control/account/**, models, account credentials store, HTTP client/controller, devices UI, and focused tests.
- existing remote_control/remote_computer_page.dart, state/remote_controller.dart and phone pages for account connection, device listing and revoke handling.
- core pubspec if a genuinely needed platform-compatible dependency; no silent unsupported OHOS plugin.
- reports/pi-mobile.md and pi-mobile-progress.md in the main task directory.

pi-desktop owns Studio tools tab and all core desktop/** plus desktop_remote_page.dart. Do not edit Studio files or desktop files. No login gate assumptions: toolsTabBuilder has no AuthStore; global narrow Inherited account scope in app.dart can expose the real existing AuthStore. No duplicate AuthStore or rereading another auth.json. Keep login/logout identity changes fenced against stale async responses and close account sockets/clear credentials on logout/account switch. Do not affect ordinary manual remote connections unnecessarily.

Implement My Computers for existing QFLI login, refresh/list online/offline/revoked, bind with one-time code, connect using relayToken, revoke confirmation + immediate local disconnect. Keep manual pair-code/link/ID+secret flow available without account service. Keep PTY/Herdr/Claude/Codex messages/approvals unchanged. QFLI JWT goes only to QFLI official origin; relay only receives grant and its own tokens. HTTP relay origin must derive safely from selected ws/wss URL; no credential forwarding across redirect/origin change. Validate returned device IDs/types centrally.

Contracts in design.md: POST QFLI /api/relay/grants {audience:'cloudterminal-relay',scope:'relay.connect'} -> grant/expires_at/audience. Relay POST /api/v1/auth/exchange {grant}; refresh {refresh_token,grant}. GET /api/v1/devices. POST /api/v1/devices/:id/bindings {pair_code}; DELETE /api/v1/devices/:id/bindings/:accountId. account_id comes from verified grant/token; never self-assert identity. Use relay account metadata from exchange. Relay WS client hello {t:'hello',role:'client',agentId,relayToken,v:1}. Account-bound connections must not silently fall back to device secret after errors/revocation.

Separate account credentials from auth.json and qfli_remote_control.json. Prefer available secure platform storage; if unavailable use nonpersistent memory and explicit reauthorization rather than unsupported plugin/plaintext. Device selection metadata may persist without tokens. Never include token/grant/secret in toString, errors, fixtures or logs. Cached device lists must be scoped to account + relay. Handle unavailable account relay, auth expiry, revoked binding, reconnect and refresh races truthfully. Avoid replacing/refactoring entire remote controller.

Write meaningful client/controller/widget regressions, preserve old connection behavior. Local checks limited to formatting/focused static analysis/syntax/diff/document lint. No local tests/builds/services/probes/emulators/Docker/WSL/adb/hdc per prior task restriction. No production calls/credentials. No commit/push/merge/reset/restore/clean/stash/global config. Record progress and final report with exact paths/checks, acceptance evidence, unrun cloud/device checks and integration needs. Complete implementation before reporting.
