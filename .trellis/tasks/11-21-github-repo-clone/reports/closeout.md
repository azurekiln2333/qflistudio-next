# Implementation closeout — November 22, 2026

All R1–R8 product changes are committed in the integration Core and App roots.
The requirement mapping and exact hashes are in [commit-ledger.md](./commit-ledger.md).
Both implementation worktrees and indices are clean. No changes were pushed or
released. The planning-root App dependency and remote-account-binding worktrees
remain outside these commits.

## Delivered behavior

- GitHub OAuth device flow is the default option. PAT is also available. The UI
  paginates accessible repositories and submits selected repositories as separate
  clone tasks. New destinations are under the configured `projects/gitProjects/`.
- Home deletes cloud projects directly, with permanent-delete confirmation,
  scoped registry persistence and stale-response protection.
- File-tree selections and Home projects export ZIP files for native sharing.
  Cloud exports use a complete leased snapshot rather than mutable editor data.
- Scoped persistent caches live under configured `projects/cloudProjects/`.
  Cards expose cache phase, progress, time, file count, size and update/clear
  actions. Clearing protects open editors and unsent local changes.

## Verification actually completed

Root statically analyzed the actual cumulative Git index before each Core
requirement commit. App R1/R4 indices passed App library analysis and staged
configuration syntax checks. There were no errors or warnings. Existing
informational lints are listed in the ledger. Root also checked Linux shell
syntax and every staged diff. Worker Java/ArkTS syntax results and native source
review remain documented in `pi-d.md`. Native compilation was not performed.

`staging/final-verification.json` verifies every B/C/D frozen-copy hash, final
source equality, committed content and both clean roots. It also records each
successful static-analysis tree. No runtime test, build, local service, device
operation, actual clone, cloud delete or native share was used for validation.

## Remaining acceptance and release inputs

1. Provide a registered GitHub OAuth App with Device Flow enabled and pass its
   public `QFLI_GITHUB_CLIENT_ID` to release builds. No client secret is required.
2. Run the existing cloud CI test/build matrix against the matching Core/App
   revisions. Existing workflows discover the added regression sources.
3. Validate native vault access and receiver reads on supported devices. Confirm
   Windows ATL and SDK 10.0.19041+ prerequisites in release images.
4. Validate OAuth polling/cancel, repository pagination, clone failures, cloud
   delete/restart races, interrupted cache updates and share lifetime in CI.

OHOS GitHub login remains unavailable because the selected secure-storage plugin
has no OHOS backend. Linux file sharing offers Save ZIP. Retained share archives
have no automatic expiry policy. These are disclosed capability limits.

Runtime acceptance has not been claimed. The task remains `in_progress` pending
the external CI/device gates above.
