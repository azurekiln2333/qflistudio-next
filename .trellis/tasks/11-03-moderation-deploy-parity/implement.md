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
- [x] Commit explicit owned paths with Conventional Commits and no signatures.
- [x] Append Result with commits, checks, limitations, and operator actions.

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

## Result

Completed on 2026-11-03. Deployment parity is prepared and verified locally.
No production deployment, image push, or device operation was performed.

### Commits

- `azurekiln-moderation` `34334ca` —
  `ci(moderation): align image updates with gateway deployment`
- `qflistudio` `e62efa1` —
  `docs(compliance): align moderation rollout with image updates`

The task-completion documentation commit contains this Result and final metadata.
The final terminal report lists that commit too.

### Delivered behavior

- Production `compose.yaml` pulls a published image and binds only loopback.
  Watchtower is pinned to `nickfedor/watchtower:1.23.2`. Its label filter, project
  scope, and exact moderation container name must all match. It excludes itself.
- Standalone `compose.build.yaml` builds locally, has a separate default project
  and volume, disables the update label, and contains no watcher.
- GitHub checks every push and PR. Main and version-tag pushes publish GHCR
  images only after checks pass. Action references use verified full SHAs.
  PR checks do not log in to a registry. CNB `.cnb.yml` is unchanged.
- README and deployment instructions cover both registries, update modes,
  private registry credentials, and reuse of the existing SQLite volume.
- The rollout handbook changes only moderation instructions. Its backup and
  rollback examples stop the moderation watcher, preserve existing settings,
  and retain a rollback image before cleanup can remove it.
- The backend deployment spec records executable contracts and regression gates.
  The service has no MySQL or Redis driver, so neither database was added.

### Tests and checks

Official Compose `5.7.0` and actionlint `1.7.12` were downloaded to the task's
temporary tool directory. Upstream release checksums were verified before use.
No Docker daemon or production connection was required for parsing.

```powershell
$env:MODERATION_COMPOSE_BIN = Join-Path $env:TEMP 'moderation-deploy-parity-tools/docker-compose-windows-x86_64.exe'
node scripts/publish-ci.mjs verify
```

Working directory: `D:/MyNewProjects/azurekiln-moderation`.

- `npm ci`: passed, 0 reported vulnerabilities.
- `npm run lint`: passed, 32 JavaScript files.
- `npm test`: **50 passed, 0 failed, 0 skipped**.
  Includes 5 real Compose parser regression tests, core/ext HTTP and database
  tests, SDK module formats, and offline tarball installation.
- `node --test scripts/publish-ci.test.mjs`: **7 passed, 0 failed**.
- `actionlint .github/workflows/build-and-push.yml`: passed.
- Compose config/JSON checks: passed for production, local builds, two project
  scopes, custom loopback ports, existing volumes, and missing-setting errors.
- Workflow YAML and permissions checks: passed. Six event/ref cases confirm the
  publish gate excludes PRs and non-main branch pushes.
- Document example validation: 26 Bash blocks and 5 Python blocks passed syntax
  checks. The private-registry override and two-env-file configuration passed
  official Compose parsing with synthetic credentials.
- The actual image-env update example preserved the existing project and volume
  in a temporary fixture. The actual rollback example passed for both legacy
  fixed-volume syntax and current interpolated-volume syntax, **2/2**.
- `python scripts/ste-lint-zh.py <task design.md> <task implement.md>`: passed,
  0 findings. The Chinese rollout guide has 0 new findings. Its unchanged QFLI
  subject-salt row already had 1 synonym finding in HEAD. Checking with
  `--baseline 1` passed without editing that unrelated row.
- `git diff --check` and staged-path review: passed in both repositories.

Validation log:
`D:/AppData/Local/Temp/moderation-deploy-parity-tools/service-validation.log`.
Document/workflow fixture checker:
`D:/AppData/Local/Temp/moderation-deploy-parity-tools/validate-docs.py`.

### Remaining verification

- Docker Engine is unavailable locally. Container builds, daemon execution,
  live Watchtower updates, and Nginx runtime checks remain for the deployment
  host. Compose parsing is not a container-runtime acceptance result.
- GitHub/CNB jobs and GHCR publishing were not triggered because this task
  explicitly prohibits pushes. No production secrets were created or read.
- The gateway reference deployment files are absent from its local checkout.
  Its documented source, `cnb2api-panel`, was read without modifications.
- Device smoke still awaits an explicit `设备已解锁` notification. No device
  connection, installation, launch, or screenshot operation ran in this task.

### User and operator actions

- Create or select the GitHub/CNB repositories and push the committed code.
  Enable GitHub Actions and allow the image job to publish GHCR packages.
- Select the tested registry image. Choose a moving tag for automatic updates,
  or a digest/revision tag with Watchtower stopped for manual upgrades.
- Supply operator-only app credentials and any private-registry read credential.
  Private images require the documented Watchtower credential directory mount.
- Inspect and preserve the existing SQLite volume before recreating containers.
  Run backup, migration, health, authenticated smoke, and Nginx checks on the
  disclosed domestic host. Resume the watcher after acceptance passes.
- Send `设备已解锁` when ready. Device smoke takes priority on that notification.
