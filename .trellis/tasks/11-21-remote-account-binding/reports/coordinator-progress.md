# Coordinator implementation progress

## Active work

All four existing Pi agents are working in Herdr workspace `w37`.
The coordinator owns final workflow integration and relay-core synchronization.
The source repositories and existing dirty worktrees remain untouched.

## Integration changes

- Studio installer workflow accepts `remote/**` pushes.
- `resolve-flutter` resolves the requested Core ref once to a commit SHA.
- All eight app-setup consumers use that SHA.
- Preview artifact provenance compares the same resolved SHA.
- Companion verification covers Linux, Windows and macOS.
- Release tags require committed relay-core provenance.
- Non-release validation may explicitly accept a draft relay-core snapshot.
- A new Relay `verify.yml` checks types and tests without publishing images.
- Core now reuses the assistant's `qr_flutter 4.1.0` and `qr 3.0.2`.
- Core and Studio lockfiles passed offline resolution with `--enforce-lockfile`.

The integration Core default currently names `remote/remote-account-binding-core`.
It must be replaced with the final Core commit before release.
The branch is local and has not been pushed.

## Relay source provenance

`sync-relay.ts` retains the five-file content hash gate.
A clean snapshot records its actual source commit.
A draft requires `--allow-dirty`.
It records `commit:null`, the base commit and a deterministic snapshot digest.
The digest hashes sorted JSON pairs of paths and LF-normalized content hashes.
The source-aware check also compares the recorded source revision.
Release checks reject draft snapshots.

Regression tests cover changed source, explicit draft opt-in, file tampering,
path-order stability, mutually exclusive provenance and the release gate.
These tests have been written but have not run locally.
The final relay files have not yet been synchronized.

## Review feedback sent to workers

- QFLI: never cache a successful single-use grant introspection.
- QFLI: handle a MySQL logout race without returning a foreign-key 500.
- Desktop: fix literal wildcard copying before packaging Node.
- Desktop: validate recursive-delete paths and reused-download checksums.
- Desktop: verify the external loopback sidecar identity.
- Desktop: include relay-core.json and target-architecture native addons.
- Relay: use a dedicated JSON grant checker without a success cache.
- Mobile: keep refreshed token expiry metadata with the refreshed token.
- Mobile: fence asynchronous changes with both identity generation and relay.
- Mobile: preserve device state through cache serialization.
- Desktop: use the existing QR renderer instead of a new encoder.
- Desktop: fix installed macOS paths and sandbox attachment discovery.

## Completed local checks

- Node syntax checks passed for the modified sync script and regression tests.
- Targeted TypeScript analysis passed for both modified files.
- Studio workflow YAML parsing passed.
- Relay verification workflow YAML parsing passed.
- Diff whitespace checks passed for the files reviewed so far.
- PRD, design and implementation plan passed Chinese document lint.

No local tests, services, temporary probes, builds or device tools have run.
No commits, pushes, deployments or releases have occurred.
Cloud CI and real-device acceptance remain unverified.
