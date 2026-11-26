# App migration handover

## Published work and ownership

Source: `D:/MyNewProjects/qflistudio`.
Target: `E:/MyNewProjects/QFLIProjects/qflistudio-next`.
GitHub: `azurekiln2333/qflistudio-next`.
Source lead: Herdr `w65:p1`. Receiving Codex: `w6D:p1`.

The reviewed migration is on GitHub `main`. Commit `3ffde9d` preserves source,
portable Trellis support, tasks, journals, specs and reviewed historical work.
Later commits fix a comment false positive in the cloud import check, the
preserved App test's UTF-8 decoder, and its premature input assertion.
No local build, test, analyzer, dependency install or WSL startup was performed.

`migration-pre-publication` and artifact recovery refs stay private. The new
published history descends directly from public baseline `c5f4bc3`, not the
unreviewed preservation commits. Never push all refs or mirror this repository.
The branch/worktree dispositions are recorded in `integration-decisions.md` and
`branches.md/json`. Topic branches and dirty linked worktrees were retained.

## Cloud acceptance

Tested code commit: `da74782075d4bb31f92546c18031c340df1adb21`.
Git tree: `b3ae9e49db42b79c10502044cc09e3485bccbe44`.
App installers run: `45908020703`, attempt 1, push event, conclusion success.
There are 19 jobs: 18 successful and one tag-only release publication skipped.
Windows, Linux, macOS, iOS, Android and OHOS installer jobs pass. App/Core,
companion, assistant, Java and Git iOS verification gates pass.
See `cloud-acceptance.md/json` for artifact metadata and evidence limitations.

The earlier runs `45897093931`, `45897522770` and `45905107524` are failure
history, not acceptance. Their diagnosed issues and subsequent fixes are retained.
The final bookkeeping commit changes only progress/spec documentation. The lead
will also dispatch the full installer workflow on that exact final commit and
report its run ID through Herdr without creating a recursive evidence commit.

Core remains `476a30acee21dc486ee2849dd8064a7be665e4d5`; plugin remains
`697291a27818612ae9dc53d83d4f99fa5887908e`. The Core verification runner exposes
a legacy `qfli_studio_core` symlink to the canonical `qflistudio-core` checkout.
This is required by the pinned Core's test fixture lookup. Source and assertions
are unchanged. Core owns the permanent portability fix and final migration pin.

The Git owner's new immutable native release/hydration contract is not published.
Keep current ABI/provenance checks. Do not substitute `native-v0.1.1` or describe
the new native producer migration as finished. Installers are CI validation
packages with the recorded unsigned/test/ad-hoc signing states. Production
signing, store publication and physical-device acceptance are not claimed.

## Clone and preservation checks

The target has only GitHub `origin`. Both checkouts were clean at `76e1f80`,
with equal commit/tree and all 1,700 tracked files equal by actual bytes after
aligning Git checkout line endings. The target has since fast-forwarded to
`da74782`; final evidence files must be pulled before the closing comparison.

The three preservation directories contain 129 files and 1,869,144 bytes per
checkout. Actual source/target byte hashes match, including 122 manifest payloads
and seven metadata files. Terminal: 107 files, 104 manifest payloads, 40 original
source/patch/YAML files. Remote account: 14 files, 12 payloads. Staging tools:
eight files, six source payloads. All 129 files have effective `-text` attributes.
The final comparison must repeat tracked-content and clean-status checks after
the last pull. Git parity covers tracked files, not private/ignored/guest data.

Remote-account work is preserved, not enabled. Its README records missing Core
APIs, relay provenance and behavior-porting blockers. Do not apply its older
whole-file patch over current App code. The server split remains in its own
repository; do not merge its unrelated root into the App.

## Receiver closeout

After the source lead reports final SHA, tree, cloud run and byte comparison,
the receiving Codex should acknowledge through Herdr and own subsequent task
bookkeeping. Read `AGENTS.md` and this task before assigning the four target Pi.
Keep `gpt-6.1-sol` as preferred model, monitor turn limits, compact/restart with
bounded context when needed, and preserve file ownership between agents.

Do not run local builds, tests, analysis, package resolution or installs. Do not
download native/installer artifacts or start WSL. Disable IDE automatic setup
and validation. The repo-local policy travels with every clone; the shared parent
policy is owned by SQL and must not be edited concurrently.

## Old-directory cleanup

No files, caches, worktrees or WSL distributions have been deleted by this task.
Follow `cleanup-plan.md` in order: publication/parity, owner review of exact
paths, private recovery, then the separately authorized cleanup operation.

Retain the old root because `.git` serves linked worktrees and `.artifacts`
contains three registered WSL backing disks. Their logical lengths total
40,580,939,776 bytes (37.79 GiB); guest-only contents are unknown. Retain private
recovery under `D:/MyNewProjects/_migration-backup/qflistudio-20261126`.
Never blanket-delete the old root, `.artifacts`, staging trees or shared caches.
The reviewed cache candidates and exact VHD paths are listed in the cleanup plan.
