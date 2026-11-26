# Preserved remote-account source (review only)

- Created: 2026-11-26T20:20:19.353573+08:00. Source: `D:\MyNewProjects\_wt\remote-account-binding\studio` at `6d1b96d7118740f71e5dadf393cc8bd58238b6af`.
- Review base: pinned `github/main` `c5f4bc3afe9c81ba488fd3f544d43c3dac061512`.
- Contains an exact patch for 20 non-equivalent tracked paths, exact copies of 9 untracked source files, and the historical-only checker.
- Exact patch preserves checkout line endings. Review patch ignores CR-at-EOL. Neither is applied to runtime main.
- Excluded three shared paths whose normalized bytes match main: `crypto.ts`, `log.ts`, `protocol-account.ts`.
- No generated/build output, dependencies, credentials or machine configuration copied. No Git mutation/build/test/install/WSL.

## File disposition matrix

| File | Content / risk | Disposition |
| `.github/workflows/app-installers.yml` | Core pin resolution, companion staging/provenance checks; snapshot also rolls version to 5.0.5 and removes newer CI/native-Git behavior. | Port reviewed hunks only; keep 5.0.14, client-ID and current release/native-Git checks; pin a published core SHA. |
| `companion/remote_agent/README.md` | Documents authenticated attach/session discovery/pairing. | Preserve with code; correct 8-digit sample and final protocol. |
| `companion/remote_agent/relay-core.json` | Draft manifest records commit=null. | Backup only; replace with independent relay owner clean publication/provenance before release. |
| `companion/remote_agent/scripts/sync-relay.ts` | Clean/draft provenance verification with explicit dirty opt-in. | Preserve with tests; release uses require-clean. |
| `companion/remote_agent/src/agent/link.ts` | Phone-facing pairing URL and optional platform metadata. | Port additive behavior; wire platform at call sites. |
| `companion/remote_agent/src/agent/main.ts` | Pair URI/console and port-file CLI flags. | Port narrowly; parser remains strict for unknown named flags. |
| `companion/remote_agent/src/agent/sdk.ts` | Bounded desktop Claude history paging; phone stays at 30. | Preserve; verify SDK paging in cloud. |
| `companion/remote_agent/src/agent/sidecar.ts` | Authenticated attach, discovery/open/input IPC, device snapshot. | Port with core APIs/helpers after blockers; no-port-file compatibility is unauthenticated. |
| `companion/remote_agent/src/agent/tool-streams.ts` | Descriptor bind, Claude transcript and Codex read/resume/input. | Port with discovery; verify live output and provider identity in cloud. |
| `companion/remote_agent/src/relay/relay.ts` | Revocation fences/client closure/legacy secret rejection/metadata. | Apply to independently owned relay, then synchronize clean provenance. |
| `companion/remote_agent/src/shared/relay-protocol.ts` | Optional platform field. | Coordinate with independent relay owner. |
| `companion/remote_agent/start.cmd` | CLI enables console pairing. | Preserve once flag lands. |
| `companion/remote_agent/start.sh` | CLI enables console pairing. | Preserve once flag lands. |
| `companion/remote_agent/test/relay-core-sync.test.ts` | Clean/draft provenance regressions. | Preserve; cloud-only tests. |
| `lib/main.dart` | Adds RemoteAccountScope wrapper. Whole file reverts 5.0.14 and removes share intake/device sync/harness startup. | Do not apply wholesale; wait for core publication, add wrapper without dropping current initialization. |
| `lib/studio_tools_tab.dart` | Adds pairing/sign-in but restores obsolete remote card and drops current Agents redirect. | Keep current product navigation; place approved behavior in current UI surface. |
| `macos/Runner/DebugProfile.entitlements` | Downgrades current read-write/bookmark to read-only. | Do not apply; keep current permissions. |
| `macos/Runner/Release.entitlements` | Same entitlement regression. | Do not apply. |
| `pubspec.lock` | Adds QR deps atop old lock; removes newer deps. | Do not apply wholesale; core owner declares and cloud resolves. |
| `tool/ci/package_linux.sh` | Adds executable mode preservation but removes libsecret dependency. | Port only mode block; keep current dependency. |
| `untracked-source/companion/remote_agent/src/agent/desktop-discovery.ts` | Herdr/Claude/Codex session discovery. | Preserve source; pass configured Herdr and namespace provider IDs. |
| `untracked-source/companion/remote_agent/src/agent/sidecar-port-file.ts` | Port-token file and ownership cleanup. | Preserve; stale recovery, Windows ACL and deletion race need review. |
| `untracked-source/companion/remote_agent/test/desktop-discovery.test.ts` | Provider discovery fixtures. | Preserve; no tests run. |
| `untracked-source/companion/remote_agent/test/sidecar-port-file.test.ts` | Port-file parsing/ownership tests. | Preserve; does not establish ACL or crash recovery. |
| `untracked-source/companion/tools/README.md` | Packaging docs contradict JSON-token implementation. | Historical source; correct before feature release. |
| `untracked-source/companion/tools/package_companion.ps1` | Target-architecture self-contained bundle packager. | Preserve source; cloud-only, review arch/secrets. |
| `untracked-source/companion/tools/verify_companion_bundle.mjs` | Node/native addon architecture and bundle verifier. | Preserve source; clean provenance/ACL checks remain. |
| `untracked-source/companion/tools/verify_companion_bundle.test.mjs` | Verifier fixtures. | Preserve source; cloud-only execution. |
| `untracked-source/tool/ci/stage_desktop_companion.ps1` | Guarded per-platform companion staging. | Preserve source; integrate after pin publication/review. |

## Blockers before application or release

1. **Core API absent.** Pinned core, inspected core main and branch HEAD lack RemoteAccountScope/DesktopCompanionEntry. Core owner must publish a reviewed immutable commit.
2. **Relay is draft.** `relay-core.json` has `commit: null`. Independent relay owner must publish/review, synchronize five exact files and produce clean provenance.
3. Discovery ignores `--no-herdr` and custom `--herdr-path`; pass configured provider.
4. Discovery de-dupes by `kind:id`, but opening/binding uses plain IDs; namespace keys end-to-end.
5. Codex desktop output is one-shot; local sidecar has no observed forwarding of later `codex_changed`. Verify live updates in cloud.
6. Port-file uses hard-link publication; stale crash leftovers block re-publication. Windows private ACL is unverified. Legacy no-port-file socket is unauthenticated by compatibility design. Review recovery/ACL/auth policy.
7. `platform` is declared but not wired into sidecar/CLI relay creation.
8. Packaging README says `sidecar.port` and no token. Implementation uses authenticated `{port, token}` JSON. Align docs.
9. Keep current version, client-ID/native-Git/release CI, Agents navigation, share/device-sync/harness setup, macOS permissions, and libsecret. Old whole-file replacements regress these.
10. Cloud-only checks: IPC auth, stale/duplicate files, Windows ACL, provider options, Codex streaming, relay revocation/races, clean provenance, architecture and platform installer jobs. This preservation reports no tests passed.

## Historical-only checker

- Exact source: `D:\MyNewProjects\_wt\cloudterminal-import\work\qflistudio\scripts\check-remote-companion.mjs`.
- Preserved at `historical-only/cloudterminal-import/scripts/check-remote-companion.mjs`; 11847 bytes; SHA-256 `1b28850c28782d67e3bfaa29b32ac0b8c9e694947e8c0d53a079489b916703ed`.
- **Historical-only. Do not enable unchanged.** It expects legacy CloudTerminal pins, OHOS version/commit and workflow. Its no-secrets check walks directory contents instead of Git tracked paths. Adapt desired invariants to current pinned dependencies in a reviewed change.

## Patch and manifest

- Exact patch: `patches/remote-account-working-tree-exact.patch`, {len(raw)} bytes, SHA-256 `{hashlib.sha256(raw).hexdigest()}`.
- Review patch: `patches/remote-account-review.patch`, {len(review)} bytes, SHA-256 `{hashlib.sha256(review).hexdigest()}`.
- Exact untracked-source hashes and tracked-file hashes are in `preservation.json`.
- This is archival research, not application code. Do not apply either patch without separate integration review.
