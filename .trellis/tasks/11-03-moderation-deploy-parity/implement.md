# Implementation

## Plan

- [x] Read the PRD, compliance rules/contracts, and applicable repository specs.
- [x] Inspect existing deployment artifacts and the available reference files.
- [x] Write the design and this implementation plan before edits.
- [x] Add production and standalone local Compose configurations.
- [x] Add GitHub checks and gated GHCR image publishing. Preserve CNB CI.
- [x] Add regression coverage for resolved Compose configuration and isolation.
- [x] Update service deployment instructions and moderation-only runbook parts.
- [x] Validate Compose and workflow YAML with official tools and dummy settings.
- [x] Run service tests, lint, controlled-Chinese lint, and diff checks.
- [x] Record the deployment contract and update the backend spec index.
- [ ] Commit explicit owned paths with Conventional Commits and no signatures.
- [ ] Append Result with commits, checks, limitations, and operator actions.

## Validation plan

1. Run `compose config --quiet` and inspect canonical JSON for both files.
2. Exercise a second project, custom port/volume, and missing required settings.
3. Verify watcher filters and that local mode has no updater.
4. Run actionlint on the GitHub workflow and validate its publishing gate.
5. Run `npm test`, `npm run lint`, and existing CNB pipeline tests.
6. Run `python scripts/ste-lint-zh.py` on changed Markdown and `git diff --check`.

The machine has no Docker CLI or daemon on PATH. Download isolated official
validation tools to `%TEMP%` if available. Configuration parsing does not claim
container-runtime or registry-publishing verification. Do not connect to
production. Do not operate the locked device.
