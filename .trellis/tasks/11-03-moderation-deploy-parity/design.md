# Design

## Boundary

The service currently builds its image through the default Compose file.
It has CNB CI but no GitHub image workflow. This task changes deployment
configuration and its operating instructions, without changing the API or SDK.

Owned changes in `azurekiln-moderation`:

- `compose.yaml`: published production image, loopback port, persistent SQLite,
  and Watchtower pinned to `nickfedor/watchtower:1.23.2`.
- `compose.build.yaml`: standalone local build with automatic updates disabled.
- `.github/workflows/`: checks for pushes and PRs, GHCR publishing for main and
  version tags after checks pass.
- `test/ext/`: Compose configuration regression checks using the official CLI.
- `README.md` and `deploy/README.md`: CI, deployment, persistence, and updates.
- `.trellis/spec/backend/deployment.md` and its index: executable deployment
  rules for later maintenance.

Owned changes in `qflistudio` are this task directory and only the moderation
portions of `docs/compliance/2026-11-上线手册.md`.

## Decisions

Watchtower must select the moderation container by all three filters: its
explicit container name, enable label, and project scope. Its own enable label
is false. Local builds have a separate default project and no watcher service.
Production has no build directive. Every published application port binds to
`127.0.0.1`. The host Nginx terminates TLS.

SQLite is the only implemented database. There is no MySQL or Redis integration,
so this task adds neither service. Preserve the database and WAL in a local
named volume. Existing deployments must select their existing volume explicitly.

GitHub checks reuse `node scripts/publish-ci.mjs verify`, including existing CNB
pipeline tests. Keep `.cnb.yml` unchanged. GHCR publishes immutable revision tags
and release tags. Main and stable releases can advance `latest`. Prereleases
must not advance it. Operators choose either registry through `MODERATION_IMAGE`.

The gateway reference Compose, workflow, and deployment spec are absent from
the local gateway checkout. Read its documented source, `cnb2api-panel`, instead.
Use official upstream documentation to confirm action versions and filters.

## Validation and operations

Use synthetic credentials and an empty temporary env file for configuration
checks. Validate production and local files with the official Compose CLI.
Check workflow syntax with actionlint, then run the service tests and lint.
No production connections, pushes, real credentials, or device commands belong
to this task. Device smoke remains pending an explicit unlock notification.

Watchtower follows a moving tag. Digest-pinned deployments require explicit
upgrades. Pause the moderation watcher before backup, migration, or rollback.
Private registries also require a protected Docker config mounted into the
watcher. Keep secrets outside both repositories.
