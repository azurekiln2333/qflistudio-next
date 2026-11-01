# W1-ext implementation

## Plan

- [x] Read requirements, repository contract, ownership, and available specs.
- [x] Write design and execution plan before implementation.
- [x] Activate this task without changing branches.
- [x] Implement review policies, queue, resolution, and retention.
- [x] Implement image provider handling and manual fallback.
- [x] Implement reports and handling history.
- [x] Implement and document the ESM/CommonJS SDK.
- [x] Add deployment artifacts and operating instructions.
- [x] Test module boundaries, state transitions, retention, and SDK failures.
- [x] Test the packed SDK in an isolated consumer.
- [x] Run integrated tests and syntax checks with core.
- [x] Review only owned paths and commit with explicit paths.
- [x] Append Result with commits, tests, gaps, and user actions.

## Validation commands

Run in `D:/MyNewProjects/azurekiln-moderation`:

```powershell
node --test test/ext/*.test.js
node --test packages/client/test/*.test.cjs
npm test
npm run lint
npm pack --workspace packages/client --pack-destination $env:TEMP
```

Docker validation depends on an available Docker engine. Record any runtime
validation gap rather than claiming a successful container build or deployment.

## Coordination

Core owns root README/package files. Requested workspace registration and root
test/lint inclusion through `w37:p6`. No shared-file edits are planned.

Core supplied workspace scripts and refreshed the lockfile. Core also clarified
exact terminal-report idempotence and SDK 5xx error wrapping in README. The
implementation matches those clarifications. Ext changed no core-owned paths.

## Verification

- `npm test`: 45/45 pass, no skips or failures.
- `npm run lint`: 29 JavaScript files pass syntax checks.
- `node --check deploy/smoke.mjs`: pass.
- Offline tarball install and `npm ci`: pass through both ESM and CommonJS.
- Real migration CLI, repeat migrations, and deployment smoke CLI: pass.
- Compose YAML: parses with PyYAML. Official pinned Docker image tag exists.
- Docker build/runtime: not run because Docker is not installed locally.
- `acceptance.md` maps tests to this worker's acceptance scope.

## Code-spec capture

`deploy/extension-contracts.md` captures seven maintenance-contract sections.
It records synchronous transaction boundaries, immutable migrations, retention
anchors, exact terminal idempotence, and SDK error assertions. The target repo
spec tree belongs outside ext ownership, so no shared spec index was changed.

## Result

Implementation complete. Service commit:
`457bfa9 feat(moderation): add review, image, reports, SDK and deployment`.
The commit contains only 19 README-owned ext paths. Shared root files remain
with core. No history rewriting, branch changes, push, or broad staging was used.

Validation:

- `npm test`: 45/45 pass, including 14 extension/deployment tests and 14 SDK
  tests. Core contributes the remaining 17 tests.
- `npm run lint`: 29 JavaScript files pass.
- `node --check deploy/smoke.mjs`: pass.
- `git diff --cached --check` for the implementation paths: pass before commit.
- `npm pack --workspace packages/client --pack-destination
  $env:TEMP/azurekiln-moderation-sdk --json`: pass. The isolated consumer test
  installs that package offline, reruns `npm ci`, and loads ESM and CommonJS.
- PyYAML parses Compose, and the official Docker registry confirms the pinned
  Node image tag. Docker build/runtime was not run because Docker is absent.

SDK handoff:
`D:/AppData/Local/Temp/azurekiln-moderation-sdk/azurekiln-moderation-client-0.1.0.tgz`
(4329 bytes). SHA256:
`e63df6cf97b73fb67dcf33d41b0a5b1c42ea20f1c1908374ef3a337c9fcaaab5`.
Core received the path and hash through `w37:p6`. Consumer workers must vendor
the package and update their own lockfiles within their ownership boundaries.

Remaining work: no implementation acceptance gaps. Docker runtime validation,
production deployment, and combined application acceptance belong to the later
parent phase documented in its PRD. The shipped image provider is intentionally
unconfigured, so images enter manual review until a trusted provider is injected.
No production deployment is claimed by this task.

User actions: none for this implementation phase. During deployment, the
operator must supply production app secrets, host configuration, and valid TLS
material. No secrets were committed. No AGC or release submission is needed
for this worker's deliverables.
