# Coordinator integration contract

All workers use this contract unless the coordinator records a justified revision.

## QFLI grants

- POST /api/relay/grants, QFLI bearer only, JSON {audience:"cloudterminal-relay",scope:"relay.connect"}.
- Response {grant:string,expires_at:ISO8601 string,audience:"cloudterminal-relay"}.
- POST /api/relay/introspect, server-to-server HTTP Basic, JSON {grant:string}.
- Valid response {active:true,iss:QFLI issuer,sub:gateway subject,aud:["cloudterminal-relay"],scope:"relay.connect",exp:UNIX seconds,name:display name}.
- Invalid/consumed/expired grant response {active:false}. Bad/missing Basic credentials fail authentication.
- QFLI grant tokens never become relay access tokens or vice versa.

## Relay tokens and devices

- POST /api/v1/auth/exchange JSON {grant:string}.
- POST /api/v1/auth/token/refresh JSON {refresh_token:string,grant:string} for QFLI-origin tokens.
- Response {account_id:string,access_token:string,refresh_token:string,access_expires_at:ISO8601 string,refresh_expires_at:ISO8601 string}.
- Preserve existing equivalent wire shape if already public, and explicitly record any adapter in both producer and consumer reports.
- Account-level token can list devices. Device connections require current active binding in addition to a valid access token.
- GET /api/v1/devices retains the existing relay response envelope and snake_case fields; phone model decodes centrally from this server contract.
- POST /api/v1/devices/:deviceId/bindings JSON {pair_code:string} consumes actual agent consent.
- POST /api/v1/devices/bindings JSON {pair_code:string} resolves the live agent ID and consumes the code exactly once. The response includes device_id. This is the account UI entry for existing relay+code pairing links.
- Account binding must never consume the legacy pairing code first to learn the device ID. Both binding routes share one consent and transactional binding implementation.
- DELETE /api/v1/devices/:deviceId/bindings/:accountId authenticates caller separately from URL accountId.
- WebSocket client hello {t:"hello",role:"client",agentId,relayToken,v:1}.

## Local integration layout

- Studio worktree: D:/MyNewProjects/_wt/remote-account-binding/studio.
- Core worktree: D:/MyNewProjects/_wt/remote-account-binding/core.
- Junction D:/MyNewProjects/_wt/remote-account-binding/qfli_studio_core points to core for existing relative pubspec paths.
- Do not write absolute local dependency paths into tracked manifests.
- Root owns relay-core synchronization after pi-relay completes. Copies must reflect the actual source diff, with truthful revision metadata.
- Root owns final installer/core-ref integration and full cross-repo verification.
- Pi workers only write their named scopes and reports.

## Validation restriction

Inherited migration restriction still applies: local formatting, targeted analysis, syntax, documentation lint and diff checks only. Write cloud-runnable unit/integration tests but do not run local tests, services, temporary probes, builds or device tools. Unexecuted checks remain unverified.
