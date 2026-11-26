# Non-executing project cleanup plan

## Current status preamble — cleanup remains on HOLD

This bounded update records the lead-provided migration status. It does not rerun verification. The older inventory, exact paths and provenance below remain historical evidence; statements that all gates were open describe plan preparation, not the current publication state.

- Reviewed source and portable Trellis progress were published through `3ffde9d495f129ed8362e23d739178b69b1ceb09` and later fixes.
- At `76e1f80`, source/target comparison verified exact raw-byte equality for **1,700 tracked files**. **129 preservation files** passed the reported byte/hash checks. These results apply to that recorded revision and scope, not automatically to later commits, ignored/private files or guest data.
- Candidate `da74782075d4bb31f92546c18031c340df1adb21` passed App installers run `45908020703`: 18 successful jobs and one tag-only publication skip. The target was fast-forwarded to this commit. The final evidence-only commit still requires a fresh pull, byte comparison and Herdr handover acknowledgement; the lead owns those steps. See `migration-handover.md` and `cloud-acceptance.md` for the later acceptance record.
- Guest-data status for all three registered source-owned VHDs is **UNKNOWN — RETAIN**. The tracked-file and preservation checks do not inspect or preserve guest-only contents.
- Retain private recovery storage, including `D:/MyNewProjects/_migration-backup/qflistudio-20261126/publication-hold/`, the linked worktrees, the old source root and its shared `D:/MyNewProjects/qflistudio/.git`. The earlier inventory recorded 34 worktrees including the primary; their shared metadata dependency is not resolved by target parity.
- **No cleanup has been performed. No cleanup is authorized.** Keep every exact candidate and provenance record below. Any later cleanup still needs owner classification, verified recovery and separate exact-path approval.

Only this document is updated. No task status, other file or target checkout is changed by this assignment. No Git mutation command, build, test, dependency operation or WSL operation is performed.

## Historical status and authority at plan preparation

**HOLD at preparation — source/target parity was then pending. No cleanup was authorized.**

- Task: `.trellis/tasks/11-26-github-main-migration`.
- Plan prepared on 2026-11-26 by Herdr pane `w65:p5` for lead `w65:p1`.
- Only authorized write for this assignment: this file, `research/cleanup-plan.md`.
- Source: `D:/MyNewProjects/qflistudio`.
- Target: `E:/MyNewProjects/QFLIProjects/qflistudio-next`.
- This plan neither deletes nor authorizes deletion. It contains no removal commands.
- No staging, commits, synchronization, worktree removal, WSL startup, mounting, export, unregister, registry edits or target edits were performed by this auditor.
- All builds, tests, analyzers, lint and dependency operations remain cloud-only. Cleanup must not trigger dependency restoration, IDE Sync or a local validation run.

## Historical evidence and limits

The 19:46 UTC+08:00 source snapshot was `c11a5a78573220495c5b575cac43bc25b932e230`, tree `619c1c0f8c90da88ff644b0d798496fc9d7c710b`. This is a local preservation commit, not proof of publication, cloud success or target equality. A subsequent scoped status read found 77 deleted, 2 modified and 10 untracked paths. At that snapshot, the source was not a completed clean migration. See the current preamble for later publication and bounded parity results.

The historical Git metadata inventory listed 34 source-repository worktrees including the primary checkout. Their common Git directory is **`D:/MyNewProjects/qflistudio/.git`**. Deleting the old primary checkout would therefore destroy shared repository metadata used by its linked worktrees.

References:

- `research/branches.md` and `branches.json`: branch/worktree inventory and dirty-content dispositions. Their observations are snapshots; recheck before any later retirement.
- `research/target-cleanup.md` and `target-cleanup.json`: target baseline, registry-backed WSL locations, VHD lengths and preservation constraints. The target baseline is not final acceptance evidence.
- `research/cloud-ci.md` and `cloud-ci.json`: cloud verification evidence owned by the CI reviewer. This plan does not independently certify those results.

No guest filesystem contents, credentials, global cache contents or unrelated disks were inspected for this plan. Directory/file metadata and source Git metadata only were refreshed. Do not infer that an ignored path, a clean worktree or an ancestral branch contains no unique untracked/guest-only data.

## Gate sequence — final closure remains pending

The current preamble records publication and bounded verification progress. The original gate requirements below remain applicable; they are not a claim that no gate work has occurred. Earlier parity evidence does not close latest-revision cloud acceptance, final pull/handover, guest-data recovery or exact-path cleanup approval.

### G1. Finish publication and source/target comparison

Lead must record the final authoritative GitHub `main` commit and tree. Verify that reviewed source, portable Trellis tasks/research/specs/journals/support scripts, required unique branch work and split-server disposition are preserved. Retain recovery refs and a private recovery snapshot outside both source trees.

Then compare GitHub, source and target commit/tree identities, tracked file content and clean statuses. Confirm the target has only its GitHub remote and the coordinated `../qflistudio-core` contract. Record permitted cloud validation results for the paired app/core revision and the target Herdr handover acknowledgement. **None of these gates is closed merely by writing or committing this plan.**

A Git commit/tree match covers tracked content only. It does not preserve ignored files, worktree-local changes, private machine configuration or files inside a VHD.

### G2. Account for local-only data and owners

For each proposed exact path, the owner must classify tracked, modified, untracked, ignored and private material. Review unique source/progress rather than copying whole obsolete worktree files over newer source. Preserve required private material outside GitHub with restricted access; do not read or print credentials into reports.

Confirm no agent, IDE, terminal, service or runtime still uses the path. Resolve canonical paths and reparse points before any future action. A symlink/junction to a shared cache is out of scope; do not follow it for deletion. Zero tracked files is necessary for a cache candidate but is not sufficient evidence that its contents are disposable.

### G3. Verify recovery without local builds or WSL startup

Recovery must include ref/object preservation and file-level records for unique local source/progress. Record backup location and metadata/hash verification without secrets. Keep the recovery copy outside every path proposed for retirement. Preserve required native artifact provenance separately from downloaded payloads.

For guest data, use the stricter guest-only gate below. No startup, mount, export or unregister is authorized by this task. A future recovery procedure that requires those operations needs separate explicit authorization before it is planned for execution.

### G4. Obtain exact-path approval

The lead/user must approve a finite list of exact paths and state what was preserved, what may be discarded and who owns the decision. Do not treat this document, ignore rules, Git ancestry or a general migration approval as removal permission. No wildcard, blanket clean, destructive reset, worktree force removal, registry deletion or distribution unregister belongs to this plan.

### G5. Later separately authorized cleanup and confirmation

Only after G1–G4 may the owner propose a separate cleanup execution. Recheck each approved path's identity, ownership, tracked status, activity and recovery record immediately beforehand. Stop on new or unclassified content. Any later report must distinguish proposed candidates from actually removed paths. This auditor performs none of those operations here.

## A. Narrow old-source cache/output review list

Each following exact path existed and had zero tracked files in the current source index at plan preparation. **All are deferred candidates, not approved removals.** Contents and allocated sizes were not inventoried.

| Exact path | Intended classification | Additional gate |
| --- | --- | --- |
| `D:/MyNewProjects/qflistudio/build/` | Old app build output | Preserve any unique logs/evidence and verify artifact provenance first |
| `D:/MyNewProjects/qflistudio/.dart_tool/` | Project-local Dart intermediates | Confirm no unique source/diagnostic material and no shared-directory link |
| `D:/MyNewProjects/qflistudio/.hvigor/` | Project-local hvigor output | Confirm project ownership and inactivity |
| `D:/MyNewProjects/qflistudio/android/.gradle/` | Project-local Gradle state | Do not expand scope to user/global Gradle caches |
| `D:/MyNewProjects/qflistudio/ohos/.hvigor/` | OHOS project intermediates | Confirm project ownership and inactivity |
| `D:/MyNewProjects/qflistudio/ohos/oh_modules/` | Project-local OHOS dependencies | Confirm no unpreserved local patch; later dependency work remains cloud-only |
| `D:/MyNewProjects/qflistudio/ohos/node_modules/` | Project-local Node dependencies | Confirm no unpreserved local patch and no shared-directory link |
| `D:/MyNewProjects/qflistudio/ohos/entry/build/` | Old OHOS build output | Preserve required signed/unsigned artifact evidence privately or through verified cloud provenance |

`D:/MyNewProjects/qflistudio/ohos/entry/libs/` also exists with zero tracked files, but is **not an ordinary cache candidate**. It may hold native runtime payloads. Retain until the owner verifies their cloud artifact source, version and hashes and preserves any unique source or license/provenance record.

Keep `.idea/` and `pubspec_overrides.yaml` until the owner has preserved any required preferences/integration context privately. Do not publish machine-specific overrides. This is not permission to delete them.

## B. Staging, reports and historical backups

The following six exact staging children are historical review paths, not a blanket generated-copy or deletion list. `__pycache__/`, `_app_index_validation/` and `_index_validation/` were generated-output review candidates. The `b/`, `c/` and `d/` directories are frozen historical B/C/D snapshots, mapped to requirement commits by the original task's `reports/commit-ledger.md`. Preserve that distinction when reviewing them after G1–G3:

- `D:/MyNewProjects/qflistudio/.trellis/tasks/11-21-github-repo-clone/reports/staging/__pycache__/`
- `D:/MyNewProjects/qflistudio/.trellis/tasks/11-21-github-repo-clone/reports/staging/_app_index_validation/`
- `D:/MyNewProjects/qflistudio/.trellis/tasks/11-21-github-repo-clone/reports/staging/_index_validation/`
- `D:/MyNewProjects/qflistudio/.trellis/tasks/11-21-github-repo-clone/reports/staging/b/`
- `D:/MyNewProjects/qflistudio/.trellis/tasks/11-21-github-repo-clone/reports/staging/c/`
- `D:/MyNewProjects/qflistudio/.trellis/tasks/11-21-github-repo-clone/reports/staging/d/`

Six recovered helper scripts are preserved as original source bytes under `research/preserved-staging-tools/`, with their manifest and README. They are source, not generated bundles, and are not the six directories listed above. The four root helper scripts and final verification summary remain in the original task. Private staging originals remain retained. Helper recovery does not establish that every B/C/D snapshot or other staging file is disposable.

Do not remove the parent staging directory or wholesale-delete B/C/D snapshots. **`reports/staging/final-verification.json` is tracked** and remains preservation evidence. Keep reviewed briefs, dispatch/support source, recovery summaries, native manifests/licenses, layout JSON, task records and journals. Ignoring screenshots or raw transcripts does not prove they have no private recovery/evidentiary value.

Retain these exact old-source directories pending recovery and unique-content review:

- `D:/MyNewProjects/qflistudio/.artifacts/repository-split-backup-20260929-071812/`
- `D:/MyNewProjects/qflistudio/.artifacts/repository-split-staging/`
- `D:/MyNewProjects/qflistudio/.artifacts/repository-split-baseline/`
- `D:/MyNewProjects/qflistudio/.artifacts/spec-index-baseline/`
- `D:/MyNewProjects/qflistudio/.artifacts/vibe-live-db/`

Do not delete or recursively clean `D:/MyNewProjects/qflistudio/.artifacts/` as a unit. It contains persistent registered disks, backups, diagnostic material and potentially private configuration. No secret contents were read; `.artifacts/terminal-runtime-test/business.env` was identified by name only and must remain private.

Retain these runtime archive files until their owner establishes recovery value and cloud provenance:

| Exact path | Previously observed file length (bytes) |
| --- | ---: |
| `D:/MyNewProjects/qflistudio/.artifacts/terminal-ubuntu-root.tar.xz` | 117,884,936 |
| `D:/MyNewProjects/qflistudio/.artifacts/terminal-runtime-test/al3-rootfs.tar` | 182,662,144 |
| `D:/MyNewProjects/qflistudio/.artifacts/terminal-runtime-test/sandbox-v1.tar` | 339,993,088 |
| `D:/MyNewProjects/qflistudio/.artifacts/terminal-runtime-test/sandbox-v2.tar` | 2,546,997,760 |
| `D:/MyNewProjects/qflistudio/.artifacts/terminal-runtime-test/terminal-legacy-source.tar` | 133,120 |

These are retained inputs/backups, not an approved space-reclamation list.

## C. Registered VHDs are persistent guest storage, not caches

The earlier registry/listing audit found the following three WSL2 distributions registered beneath the old source directory. They were Stopped at that earlier inventory; no claim about continued stopped state is inferred without a later allowed listing. Exact file lengths were refreshed for this plan and remained unchanged.

Registry root: `HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Lxss`.

| Distribution | Registry subkey | Exact registered disk | File length (bytes) |
| --- | --- | --- | ---: |
| `qfli-terminal-test` | `{41edc189-b7fb-411a-bfc0-205fbb9be0f7}` | `D:/MyNewProjects/qflistudio/.artifacts/terminal-runtime-test/ubuntu/ext4.vhdx` | 19,723,714,560 |
| `qfli-terminal-al3-clean` | `{7dbc0ce5-4ed2-4963-a126-327b8724161b}` | `D:/MyNewProjects/qflistudio/.artifacts/terminal-runtime-test/al3-clean/ext4.vhdx` | 13,742,637,056 |
| `qfli-terminal-al3-test` | `{bacb944f-b4e4-4670-9ecc-faf0997b892c}` | `D:/MyNewProjects/qflistudio/.artifacts/terminal-runtime-test/al3/ext4.vhdx` | 7,114,588,160 |

Total logical file length: **40,580,939,776 bytes (37.7939453125 GiB)**. This is neither measured allocated space nor guaranteed reclaimable capacity.

**Retain all three disks, their registered directories and their registrations.** Do not delete, move, rename, mount, compact, start or unregister them under this plan. In particular, deleting the old repository directory would also delete their storage. Even a byte-identical new Git clone does not preserve them.

### Guest-only data gate

Before any separately proposed future retirement, the distribution/runtime owner must account for data that may exist only inside each guest:

- Unpushed Git repositories, uncommitted source, user projects and local patches.
- Databases, migrations, uploads, runtime state and queues.
- Container images, volumes and files not represented in the host checkout.
- Toolchain/runtime customization, service configuration and required license/provenance material.
- SSH keys, signing material, accounts and credentials, handled privately rather than published or printed.

No guest contents were inspected, so none may be classified as disposable. The owner must record one of: verified private recovery of required data, explicit informed disposition of identified data, or continued retention. Unknown guest contents mean continued retention.

A future authorized recovery design must specify consistency/quiescence, private storage location outside retirement paths, registry-to-disk mapping and a verification/restore strategy. An arbitrary host copy while a guest could be active is not proof of a consistent backup. Export/start/restore/mount operations are **not authorized now**; do not perform them as a preparatory step.

Two other registered distributions are outside this app cleanup scope and must remain untouched:

- `Ubuntu`: registered BasePath `D:/WindowsExt/Subsystem/Ubuntu/Ubuntu_2204.1.7.0_x64`; its VHD location was unresolved in the earlier direct-location audit. Do not search unrelated disks or treat it as empty/disposable.
- `qfli-java-build`: `D:/MyNewProjects/qfli_java/build/wsl/qfli-java-build/ext4.vhdx`, previously observed length 84,817,215,488 bytes. Another repository owns it.

## D. Old repository and linked-worktree retirement gates

### Old primary checkout

**Retain `D:/MyNewProjects/qflistudio/` in full for now.** In addition to G1–G4, primary-root retirement requires:

1. Final source/target parity and GitHub publication evidence, not just the local preservation commit.
2. Every linked worktree's final owner/disposition and all unique source/progress preserved.
3. All recovery refs/objects and necessary reflog-only/unreferenced recovery material accounted for in a recoverable repository copy. No pruning or history rewriting is proposed.
4. The shared `.git` dependency resolved by a separately approved Git-aware retirement/migration plan. Retaining the primary root is the default while linked worktrees depend on it.
5. A separate, explicit resolution for the three registered VHDs and guest-only data. No parent-directory removal while their registered BasePaths remain inside it.
6. Private machine state, local-only documents, ignored data and old recovery snapshots accounted for without publishing secrets.
7. Confirmation that no Herdr agent, IDE, shell, service, build/runtime configuration or external path dependency still references this old checkout.

The old embedded `azurekiln-qfli-server` tracked deletions are a repository split issue, not cleanup. Lead must preserve the independent server history and reconcile any newer app-embedded edits using `research/branches.md`; this plan does not approve restoring, discarding or deleting that source.

### Exact registered linked-worktree review list

These are **review targets only**, not a removal list. They were read from source Git metadata; their directories were not traversed by this auditor. Do not delete common parent directories such as `D:/MyNewProjects/_wt/` or `_scratch/` because sibling products/repositories may share them.

| Exact worktree path | Required additional review |
| --- | --- |
| `D:/MyNewProjects/_scratch/ci-sim/qflistudio` | Detached HEAD and dirty Android configuration/wrapper inputs; preserve before retirement |
| `D:/MyNewProjects/_wt/app-installers/qflistudio` | Recheck owner, refs and ignored/untracked data despite earlier clean status |
| `D:/MyNewProjects/_wt/app-installers-compat/qflistudio` | Detached HEAD recovery and current owner/local-only data |
| `D:/MyNewProjects/_wt/cloudterminal-import/work/qflistudio` | Preserve/reconcile unique `scripts/check-remote-companion.mjs` and dirty state |
| `D:/MyNewProjects/_wt/github-client-id-20261124/qflistudio` | Confirm unique client-ID CI/spec fix is integrated or explicitly retained |
| `D:/MyNewProjects/_wt/harness/integration/qflistudio` | Recheck dirty generated-looking deltas and local-only data |
| `D:/MyNewProjects/_wt/harness/pi-a/qflistudio` | Recheck owner, refs and local-only data |
| `D:/MyNewProjects/_wt/harness/pi-b/qflistudio` | Recheck owner, refs and local-only data |
| `D:/MyNewProjects/_wt/harness/pi-c/qflistudio` | Record patch-equivalence disposition and dirty state before retirement |
| `D:/MyNewProjects/_wt/harness/pi-d/qflistudio` | Recheck dirty state and local-only data |
| `D:/MyNewProjects/_wt/large-screen-workbench/qflistudio` | Recheck dirty state and owner acknowledgement |
| `D:/MyNewProjects/_wt/merge/qflistudio` | Recheck owner, refs and local-only data |
| `D:/MyNewProjects/_wt/mobile/int/qflistudio` | Recheck dirty state and local-only data |
| `D:/MyNewProjects/_wt/mobile/pi-a/qflistudio` | Recheck dirty state and local-only data |
| `D:/MyNewProjects/_wt/mobile/pi-b/qflistudio` | Recheck owner, refs and local-only data |
| `D:/MyNewProjects/_wt/mobile/pi-c/qflistudio` | Recheck owner, refs and local-only data |
| `D:/MyNewProjects/_wt/mobile/pi-d/qflistudio` | Recheck owner, refs and local-only data |
| `D:/MyNewProjects/_wt/ohos-guard/qflistudio` | Recheck owner, refs and local-only data |
| `D:/MyNewProjects/_wt/release-v5.0.5/qflistudio` | Preserve release/recovery provenance and local-only data |
| `D:/MyNewProjects/_wt/remote-account-binding/studio` | Dirty feature source: 32 paths in branch audit; final coherent integration/owner disposition required |
| `D:/MyNewProjects/_wt/round5/int/qflistudio` | Recheck owner, refs and local-only data |
| `D:/MyNewProjects/_wt/round5/pi1/qflistudio` | Recheck dirty state and local-only data |
| `D:/MyNewProjects/_wt/round5/pi2/qflistudio` | Recheck dirty state and local-only data |
| `D:/MyNewProjects/_wt/round5/pi3/qflistudio` | Recheck owner, refs and local-only data |
| `D:/MyNewProjects/_wt/round5/pi4/qflistudio` | Recheck dirty state and local-only data |
| `D:/MyNewProjects/_wt/studio-git-integration/qflistudio` | Preserve release/recovery provenance and local-only data |
| `D:/MyNewProjects/_wt/sync/qflistudio` | Recheck owner, refs and local-only data |
| `D:/MyNewProjects/_wt/ui-a/qflistudio` | Recheck dirty state and local-only data |
| `D:/MyNewProjects/_wt/ui-b/qflistudio` | Recheck dirty state and local-only data |
| `D:/MyNewProjects/_wt/ui-c/qflistudio` | Recheck dirty state and local-only data |
| `D:/MyNewProjects/_wt/ui-d/qflistudio` | Preserve/classify `pubspec.lock` delta as well as generated-looking deltas |
| `D:/MyNewProjects/_wt/ui-int/qflistudio` | Recheck dirty state and local-only data |
| `D:/MyNewProjects/_wt/wsui/app/qflistudio` | Recheck owner, refs and local-only data |

For each row, future approval requires a fresh status/name inventory including ignored local-only data, recorded commit/ref disposition, recoverable unique deltas, no active users, no nested owned data and owner sign-off. Do not force-remove a dirty worktree or delete its directory by hand. Even after those gates, a separate approved Git-aware operation is required; no worktree commands are executed here.

## E. Explicit exclusions

- No changes or cleanup in `E:/MyNewProjects/QFLIProjects/qflistudio-next` under this assignment.
- No sibling product roots, shared worktree parent roots or other repository data.
- No user/global Pub, npm, Gradle, Cargo, Flutter, HarmonyOS or other SDK caches; no cache purge commands. Only the eight exact project-local candidates in section A are eligible for later review.
- No global Docker/container storage, WSL directories outside the exact inventory, Ubuntu data, Java distribution data or registry keys.
- No signing keys, credentials, machine identities or private database contents in GitHub/reports.
- No blanket `.artifacts/`, `.trellis/`, old repository, `_wt/`, `_scratch/` or whole-disk cleanup.
- No retention claim based solely on ignore rules; no deletion used to obtain a clean Git status.

## Lead handoff

Current decision: **retain all cleanup candidates, private hold, worktrees, shared `.git` and all three guest-data-UNKNOWN VHDs**. Publication and the `76e1f80` tracked-byte/preservation checks are recorded in the current preamble. Latest-candidate cloud acceptance, final target pull/parity and handover remain pending. Lead owns those steps and any future exact-path cleanup approval. **No cleanup has been performed.** This file is planning evidence only and must not be presented as cleanup completion or authorization.
