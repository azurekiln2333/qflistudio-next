# Implementation

1. Dispatch Core UI, Core pipeline, plugin and cloud release audit to Pi.
2. Review progress forwarding, simultaneous clone and cancel isolation.
3. Format and analyze locally. Run runtime checks in GitHub only.
4. Push plugin source and build native payloads. Publish and pin verified payloads in Core.
5. Push Core, pin it in App and push a new App tag.
6. Verify cloud checks and release files. Record evidence and archive the Trellis task.

## Approved 5.0.6 integration

1. Dispatch four existing Herdr Pi panes with disjoint ownership: App version, workflow publication, branch audit, current CI/artifact audit.
2. Fetch GitHub refs and inspect all named topic histories. Preserve original dirty main checkout.
3. Review version 5.0.6+5000006 and workflow publication changes. Preserve API 3 and exact verified Core/plugin pins.
4. Wait for any outstanding prerequisite cloud gates. Integrate the release history into main without force push or tag replacement.
5. Push main and the immutable v5.0.6 tag to GitHub. Track all cloud gates and installer publication.
6. Verify package provenance and signing. Delete each named remote topic ref only after its complete history is reachable from GitHub main.
7. Record final release evidence, archive task and journal the session. All runtime tests and builds remain cloud-only.
