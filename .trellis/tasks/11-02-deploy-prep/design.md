# Deployment preparation design

## Boundary

The missing behavior is a reproducible deployment handoff and a real consumer-to-service check. Keep deployment preparation outside business routes and the SDK integration owned by W2b.

- Add `docs/compliance/2026-11-上线手册.md` with image-only deployment, isolated app credentials, trusted proxy headers, migrations, backups, rollback, and smoke commands.
- Add `scripts/compliance/` probes and tests. Health and variant checks run by default. Authenticated account probes require explicit test tokens. Rate probing additionally requires explicit permission because it consumes quota.
- Add moderation `.cnb.yml` and owned CI verification scripts. Pull requests validate only. Trusted main/tag events validate before publishing immutable image tags.
- Run the real moderation and QFLI entry points in separate local child processes, using temporary SQLite databases and a loopback identity fixture. Wait for the vendored SDK commit before this check.

No production access, remote push, real credentials, business code changes, existing nginx example edits, or SDK changes are in scope. Docker and MySQL production validation remain operator checks when unavailable locally.

## Probe contract

Accept independent QFLI and moderation base URLs through arguments or environment. Reject redirects and embedded credentials. Bound every network request. Keep TLS verification enabled. Print case names and sanitized outcomes only.

Use the bundled test marker and drug variants for moderation checks. For QFLI rate checks, submit blocked text with a dedicated verified test account to avoid creating public content. Stop on an unexpected successful publication and report failure. Treat skipped required cases as failure in strict mode.

## Evidence

Unit tests exercise request failures, unexpected publication, credential handling, and skip/strict behavior. Local integration checks cover health, variant blocking, verified publication, report forwarding, pending visibility, unverified denial, rate limits, and fail-closed behavior after the moderation process stops. CI checks cover event separation and validation-before-publish ordering.
