# W1-core design

The repository does not exist yet. Build an independent Node.js 24 ESM service with Express, SQLite migrations, and a Node SDK owned by W1-ext.

## Boundary

- Core owns README, root package files, src/app.js, src/server.js, src/auth.js, src/db.js, src/errors.js, src/validation.js, src/audit.js, src/text/, src/ip/, migrations/, data/, scripts/, and test/core/.
- Ext owns src/image/, src/review/, src/reports/, packages/client/, deploy/, and test/ext/. Ext owns Dockerfile and compose files if placed at the root. Core alone edits shared root package files and README. Ext documents deployment in deploy/README.md.
- No changes to QFLI, the gateway, production infrastructure, other task directories, or existing QFLI shared specifications. New service-local specs remain core-owned.

## Contracts and flow

Freeze the external API and internal extension interface in the first README commit. Authenticate appId plus separate API/admin keys before routing. Never accept tenant identity from request bodies. Validate input at the HTTP boundary. Normalize both text and keywords with NFKC, OpenCC, case folding, and separator removal. Match app-local keywords. Write every successful moderation result to SQLite before returning it. Check IP/CIDR rules locally, with an optional local region resolver. Missing region resolution must fail closed when region rules exist.

Core supplies a database context, namespaced migrations, audit writer, validation helpers, and retention hooks. Review initialization supplies the scene policy and synchronous queue function used by text moderation. All mutations and their audit events share a transaction. Cache invalidation is immediate locally and refreshes within 60 seconds across processes.

Keep data in one mounted SQLite database. Retain decisions, reviews, and reports for at least 365 days. Keep app credentials out of the database and repository. Bundle a licensed, attributed open source seed dictionary. No remote moderation or geolocation service is added.

## Verification

Use Node's test runner and real HTTP requests against ephemeral listeners. Test auth roles, tenant isolation, text variants, CRUD and reload, IPv4/IPv6 CIDR boundaries, migrations/restart, audits, and the 365-day boundary. Run full core and ext integration tests before the final implementation commit.
