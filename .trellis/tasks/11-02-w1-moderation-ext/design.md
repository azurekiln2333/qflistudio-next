# W1-ext design

Contract: `D:/MyNewProjects/azurekiln-moderation/README.md` at `e95e7ff`.

The service currently has the contract only. W1-ext supplies image checks,
manual review, reports, the Node SDK, and deployment artifacts. Core builds
authentication, context, text/IP checks, audit storage, and root tooling.

## Boundary

Edit only `src/{image,review,reports}/`, `packages/client/`, `test/ext/`,
`deploy/`, `Dockerfile`, `compose.yaml`, and `.dockerignore` in the service.
This task directory holds planning and results. Ask core to edit shared files.
Do not change QFLI or gateway application code or configure production secrets.

## Data and interfaces

- Each module exports synchronous `initialize(ctx)` and
  `registerRoutes(v1Router, ctx)`. Module-local migrations use `ctx.migrate`.
- Review initializes synchronous `ctx.review.requiresReview` and `enqueue`.
  Policies persist by app and scene. Resolution is final and idempotent.
- Queries always constrain `app_id`. Public review responses omit payload,
  user identifiers, IP, and administrator identifiers.
- Image providers run outside SQLite transactions. Missing, failed, invalid,
  or undecided provider results enter manual review. Never fetch image URLs.
- Each mutation and its audit write share a synchronous transaction. Audits
  exclude raw payloads, report reasons, provider errors, and secrets.
- Reports preserve ordered handling events. Terminal states cannot reopen.
- Cleanup uses the shared 365-day cutoff. Review/report updates refresh the
  retention anchor. Child report events cascade when the report expires.
- Result queries deliver review decisions. No outbound callback is added.

## SDK and deployment

Use one dependency-free CommonJS implementation and a small ESM export wrapper.
Bound fetch plus JSON parsing with an AbortController deadline. Reject invalid
decisions. Fail closed with the exact contracted error. Fail-open configuration
still produces `review`, never `pass`. Preserve HTTP failure codes.

Verify the packed npm artifact through both module formats in an isolated
consumer directory. Document tarball vendoring for self-contained builds.
Docker uses Node 24, a persistent SQLite volume, an unprivileged account, and
an HTTP health probe. Bind the host listener to loopback behind trusted TLS.

## Validation and rollback

Use Node's test runner with real SQLite and HTTP requests. Cover isolation,
admin gates, policy changes, provider fallback, idempotence, terminal conflicts,
audit rollback, retention, SDK deadlines, HTTP errors, malformed responses, and
tarball installation. Run core's integrated tests once its entry point exists.
Rollback uses a new revert commit by the coordinator. Do not rewrite history.
