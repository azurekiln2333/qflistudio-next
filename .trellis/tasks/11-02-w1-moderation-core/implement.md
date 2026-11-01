# W1-core implementation

1. Read the assigned requirements, task contracts, workflow, and applicable specs.
2. Write design.md and implement.md. Activate the existing task.
3. Initialize azurekiln-moderation on main. Write README API and ownership contracts. Commit only README. Print the required CONTRACT READY line.
4. Implement shared infrastructure, app authentication, namespaced migrations, audits, normalization, keyword management, and IP rules.
5. Import a licensed dictionary and record its immutable provenance.
6. Test core behavior with SQLite and HTTP. Integrate the ext module contract without editing ext files.
7. Run scope review, syntax/lint checks, security audit, and the combined test suite. Commit explicit core paths.
8. Append Result with commits, test evidence, open items, and user actions. Print the terminal report.

## Validation commands

- `npm run lint`
- `npm run test:core`
- `npm test`
- `npm audit --omit=dev`
- `git diff --check`
- `python D:/MyNewProjects/qflistudio/scripts/ste-lint-zh.py --disable long-sentence,semicolon README.md`

Do not use prohibited git commands or stage unowned files. Keep commit messages in TEMP. Preserve ext changes and the current branch. Production deployment and credentials remain with the assigned deploy worker and user.

## Result

W1-core is complete. The new repository is on main with a clean worktree. The README-only contract commit preceded implementation. The terminal printed exactly `CONTRACT READY e95e7ff`. W1-ext and the coordinating Claude received the contract and SDK handoff through the user-authorized worker channel.

### Commits

- `e95e7ff docs(api): define moderation service contracts` (W1-core).
- `51f1f17 feat(core): implement app-isolated moderation service` (W1-core; 31 explicitly owned paths).
- Integration reference: `457bfa9 feat(moderation): add review, image, reports, SDK and deployment` (W1-ext; 19 ext-owned paths, committed by ext).
- Task records are committed separately in qflistudio with an explicit task-directory path list.

### Delivered

- App/API/admin authentication, strict tenant boundaries, common validation and error envelopes.
- Text normalization, 11 categories, keyword CRUD, immediate local invalidation, and 60-second cross-process refresh.
- 1,178 seed entries imported from an immutable Apache-2.0 upstream revision plus local phrases. Source hashes and the complete license are bundled.
- IPv4/IPv6/CIDR and optional locally resolved region deny rules. Unknown required region resolution fails closed.
- Namespaced checksummed migrations, synchronous transactions, durable moderation audits, and fixed 365-day cleanup.
- Real integration with ext image/review/reports modules and the dependency-free ESM/CommonJS SDK.
- Service-local executable specs, deployment contract, and app-scoped admin APIs in README.

### Validation

- `npm run test:core`: 17/17 pass.
- `npm test`: 45/45 pass; includes core, real ext integration, deployment CLI checks, SDK behavior, durable report history, and offline packed-consumer installation.
- `npm run lint`: 29 JavaScript files pass syntax checks. `node --check deploy/smoke.mjs`: pass.
- `npm audit --omit=dev`: zero vulnerabilities.
- `git diff --check`: pass. Both service commits contain only their owner's files. No prohibited git commands, signatures, secrets, database files, build output, or oversized files were committed.
- Isolated copy: `npm ci --omit=dev --ignore-scripts`, migration CLI, startup, HTTP health, real SDK check, bundled seed blocking, and `deploy/smoke.mjs` all pass.
- English README/spec/data documentation passes the Chinese mechanical checker with English sentence/semicolon checks disabled. The initial unmodified checker reported those English constructs; no Chinese prose was rewritten.

### Fixes and knowledge capture

Windows file-lock failures came from deleting a temporary SQLite database before its reopened connection closed. Tests now close every live instance before deleting files. The service spec records this rule. Tests also cover explicit-null PATCH rejection, malformed path encoding, unsupported JSON charset, audit rollback, and CRLF/LF migration checksum equivalence.

### Open items and user actions

- No W1-core implementation blocker remains.
- Docker build/run was not executed because Docker is unavailable locally. Ext supplied container artifacts and validated the official base-image tag. Production deployment and online acceptance belong to the parent's next phase; this work does not claim an online deployment.
- The operator/user must provision production app API/admin secrets and the deployment destination/TLS materials. Seed dictionaries need app-admin review before production. Region restrictions need a local resolver only if that optional feature is enabled.
- SDK handoff: `D:/AppData/Local/Temp/azurekiln-moderation-sdk/azurekiln-moderation-client-0.1.0.tgz`, 4,329 bytes, SHA-256 `e63df6cf97b73fb67dcf33d41b0a5b1c42ea20f1c1908374ef3a337c9fcaaab5`. The artifact hash was independently verified and sent to the coordinator for consumer vendoring.
- Keep this task directory in place for parent acceptance. Do not switch branches or archive the explicitly requested main branch as part of this worker handoff.
