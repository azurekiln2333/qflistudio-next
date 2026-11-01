# W1-ext acceptance record

Date: 2026-11-02. Runtime: Node 24.15.0, npm 11.14.1, Windows.
Repository: `D:/MyNewProjects/azurekiln-moderation`.

| Requirement | Evidence | Result |
| --- | --- | --- |
| Section 4.5: report submission, handling, query | Real HTTP tests cover required fields, app/admin isolation, ordered events, final outcomes, idempotence, conflicts, and restart persistence | Pass for W1 report scope |
| Section 4.6: pre-review | Policy change queues clean text immediately, defaults remain disabled, tenants have independent policies, public polling omits private payload, pass/block resolutions are final | Pass for W1 pre-review scope |
| Section 4.11: independent service and SDK | Core createApp runs all three extensions, SDK talks to real service, packed package installs through offline npm ci without sibling paths | Local integration pass |
| Section 4.12: tests and commit | npm test passes 45 tests, npm run lint checks 29 JS files, smoke CLI syntax passes, commit uses explicit owned paths and Conventional Commits | Pass for implementation phase |
| Image provider fallback | No provider, thrown error, invalid result, or provider review creates a durable review item, scene policy overrides pass only | Pass |
| Audit and retention | Failed audits roll back all extension writes, strict cutoff preserves exact 365-day boundary, refreshed records and report history survive cleanup | Pass |
| SDK unavailable behavior | Transport, body timeout, invalid JSON/result, and 5xx checks withhold publication, 4xx codes remain intact, redirects fail | Pass |
| Deployment command paths | Migration CLI runs twice and persists all namespaces, smoke CLI verifies health and authentication without printing credentials | Pass locally |
| Container runtime and production deployment | Compose YAML parses, official pinned Node image tag exists, Docker is absent locally, deployment is assigned to a later parent phase | Pending deployment phase |

Commands:

```powershell
npm test
npm run lint
node --check deploy/smoke.mjs
npm pack --workspace packages/client --pack-destination $env:TEMP/azurekiln-moderation-sdk --json
```

The initial full test process loaded an old core cleanup hook and stalled on
Windows database removal. Core fixed the hook. The stale process tree was
stopped, and the current full suite passed. No core files were edited by ext.

SDK artifact:
`D:/AppData/Local/Temp/azurekiln-moderation-sdk/azurekiln-moderation-client-0.1.0.tgz`
(4329 bytes). SHA256:
`e63df6cf97b73fb67dcf33d41b0a5b1c42ea20f1c1908374ef3a337c9fcaaab5`.

No production deployment is claimed. The parent PRD assigns deployment and
combined application acceptance to subsequent work. Consumer workers must
vendor the tarball and update their own manifests and lockfiles. Operators
must supply the production environment and secrets during that phase.
