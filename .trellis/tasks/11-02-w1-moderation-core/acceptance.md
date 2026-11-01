# W1-core acceptance record

Date: 2026-11-02. Repository: `D:/MyNewProjects/azurekiln-moderation`. Integrated revision: `51f1f17`, including ext commit `457bfa9` and initial contract `e95e7ff`.

| Requirement | Evidence | Result |
| --- | --- | --- |
| 4.4: variants and hot-loaded word management | Real HTTP checks block inserted spaces, punctuation, symbols, zero-width characters, fullwidth ASCII, and traditional Chinese; two database connections observe the new keyword after 60 simulated seconds | Pass locally |
| 4.6: IP restrictions | IPv4/IPv6 literal and CIDR tests cover boundaries, mapped IPv6, canonicalization, tenant isolation, disable/delete, and unknown-region fail-closed behavior | Pass locally |
| 4.6: pre-review integration | Clean text enters ext's queue for the selected app/scene; blocked text never queues; real review polling and atomic audit rollback pass | Pass locally |
| 4.11: independent service and SDK | New independent repository, default private port 4310, app credentials, real SDK requests, ESM/CommonJS tarball, offline consumer npm ci, and isolated service installation | Pass locally; production deployment deferred to parent |
| 4.12: tests and commits | 45/45 tests pass, 29 JS syntax checks pass, deployment smoke syntax passes, zero dependency vulnerabilities, clean service worktree, Conventional Commits without attribution trailers | Pass for worker scope; online acceptance pending |
| Audit retention | Strict 365-day cutoff, equality preservation, durable restart, rollback on cleanup failure, ext retention anchors | Pass locally |
| Dictionary provenance | 1,178 bundled entries, fixed upstream commit, SHA-256 manifest, Apache-2.0 license, one-time tenant seeding with persistent admin deletions | Pass locally |
| Ownership | Core commit has 31 core paths; ext separately committed 19 ext paths; no shared-file edits by ext | Pass |

Commands: `npm run test:core`, `npm test`, `npm run lint`, `node --check deploy/smoke.mjs`, `npm audit --omit=dev`, `git diff --check`.

Additional independent-build evidence: a temporary copied service tree successfully ran `npm ci --omit=dev --ignore-scripts`, the migration entry point twice through startup, HTTP health, a passing real SDK call, a seeded blocked call, and the ext deployment smoke script. The copy contains no production credentials. Docker execution is unverified because no local Docker CLI is available.

Remaining operator work: provision production app secrets, select the domestic deployment destination and hostname, configure valid TLS, build/run the container on that host, and run the documented online smoke check. No production action is claimed by this local acceptance record.
