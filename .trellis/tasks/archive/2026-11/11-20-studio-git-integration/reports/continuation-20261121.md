# Release continuation evidence

## Plugin

- Source: `d002bd3e9febb478758b75b6670a24ba8a3c610c`.
- Producing run: `44802440226`. Host smoke, Dart/real FFI, Android native,
  OHOS native and iOS native passed.
- Downloaded Android artifact `14661633290`, OHOS `14661124536`,
  iOS `14662326118`. Archives are stored under `reports/native-d002bd3/`.
- All manifests carry API 2, 28 exports, the exact source and contract hash.
- Imported all three artifacts in one invocation. Static native installation
  check passed for 10 locked files and CA
  `427c064216761a1e72a8b30f0d954d08cb6e4435a82091fb865afd20c8497285`.
- Windows checkout converted the CA to CRLF while its blob was already correct.
  Added LF attributes for fingerprinted CA/contract/lock/framework metadata.
  Restored local LF bytes; verified CA and plist bytes equal existing Git blobs.
- Android example failed because the init script added project repositories
  under Flutter's `FAIL_ON_PROJECT_REPOS`. Removed those additions in `c20d36f`.
  Keep Maven Central in plugin management only. No dependency versions changed.
- Artifact commit `e30e88fcba6cd31d452598cbd6111f3f2acae41e` pushed.
  Cloud run `44804687527` validates strict lock and platform examples again.
- Superseded source run was canceled on push; do not claim its iOS integration
  test passed. The final artifact run owns that gate.

## Core

Interim source run `44802380198` at `b2ee111` passed static analysis and executed
the complete suite. Six new tests failed: three eager synchronous-throw
assertions, two incorrect fake gate lifecycles, and one duplicate text finder.
Pi B owns the backend fixture fixes. Pi C owns the scoped finder and actual
editor owner/dirty-buffer navigation tests. Product code remains frozen.
The local manifest and lock now pin plugin artifact commit `e30e88f`.

## App

Pi D added actual installer payload/provenance gates and two Python regression
files. Root review found and requested fixes for 39-character fixture commits,
optional YAML parser consistency, and a Python 3.10 incompatibility. Shared
setup now pins Python 3.13. Workflow syntax parsed 68 Bash blocks; three
non-Bash steps were explicitly skipped by the syntax checker.

## Boundaries

No local tests, builds, app launches or device tools ran. Native verification
on this machine reads files, hashes, metadata and declared contracts only.
Only the three isolated integration worktrees contain product changes.
The original cloudterminal workspace has not been written.

## 04:05 CST continuation

Core run `44805454280` was canceled after the complete suite stopped making
progress. Its downloaded JSON stream records 2666 test starts and 2665 finishes,
with no error events. The remaining test was `Git opens for the active foreign
owner, not the primary`. The new fixture awaited fake-zone workspace writes
without pumping their continuations. Root changed unmount cleanup to bounded
pumps with real-I/O delays, and the dirty-guard wait to the same pattern. Final
outer cleanup has a five-second bound. Pi C independently reviewed the diff and
found no remaining deadlock. Static Dart analysis and diff checks passed.
Commit `a8973c97c8ce89f3d6edff0ad51a9f853a3552f9` is pushed; cloud run
`44807763080` repeats the complete suite.

App run `44805595969` completed all installer targets except OHOS. Its strict
ARM64 HAP inspection detected simulator `x86_64` libraries supplied by the plugin
HAR. Pi D added entry-module release-only `nativeLib.filter.excludes` with
`**/x86_64/**`. Root verified the local Hvigor schema/packaging implementation,
kept simulator debug support and the strict payload checker, and committed
`cbce35c`. The workflow calls `flutter build hap --release` explicitly.

App commit `f47151c779e59ab856c3506a2c15af9674796e09` includes that fix, correct
mobile-only native inspection wording, and candidate Core pin `a8973c9`. It is
pushed. Run `44807880481` builds all candidates again while Core runs separately.
No preview tag exists yet; plugin iOS simulator integration remains pending.

Four existing Pi panes received concrete follow-up tasks. The model endpoint
returned repeated CPU-overload 503 responses. Root took over the fixture fix
without creating replacement Pi sessions. No local tests or builds ran.

## Final candidate and publication gate

Core `75bd34211b05e3d5dea88585b5bfbd3ea4a65e8a` passed run `44809141095`: 2394
visible tests passed; 26 pre-existing tests were skipped. The duplicate outer
settle call was the last fixture error. The bounded unmount drain remains.

App `d94bd455400ff6dcc88affd80663cb541bbb8120` passed run `44809493852`,
including all verification jobs and eleven installer targets. OHOS's release
filter is proven. Its payload checker now uses the actual OpenHarmony NDK's
`llvm-nm` rather than the command-line-tools root.

Plugin iOS example launch on the old Flutter 3.41.9 stalled on two separate
runners after Xcode build succeeded. No integration result was emitted. Do not
claim these attempts passed. App `e9e337c` adds an unskippable
`git-ios-integration` job using the App's actual upstream SDK and the exact
resolved plugin artifact commit in a separate checkout. It verifies the native
lock and executes the unchanged example integration test, with a 12-minute
bound, verbose launch logs, and always-uploaded Runner diagnostics. Publishing
now depends on this runtime gate. Pi D implemented the job; Root corrected an
EOF/read newline defect before commit. All 76 Bash run blocks parse.

Candidate tag `v5.0.5-git.1` points to `e9e337c3938f5683d7efa1fb6356215cb2ea3b86`.
Only the GitHub remote received it. Tagged run `44818320621` is authoritative;
the duplicate branch run was canceled to free cloud runners. No release exists
yet. The tag is a candidate trigger, not a claim of readiness. Publication must
wait for the complete tagged workflow. Preserve the tag if a later fix is needed.

## Corrected mobile fixture and candidate .2

Tagged run `44818320621` completed Core with 2394 visible passes, 26 existing
skips and zero errors. Windows, Linux, macOS, IPA, OHOS and assistant jobs passed.
Android failed resolving Kotlin dependencies because Maven Central returned HTTP
429. An early single-job rerun was rejected while the workflow was active.

The production-SDK iOS runtime gate launched the simulator app successfully.
Setup completed, then the clone assertion failed because the fixture supplied a
bare directory to the URL validator. Lines 12706-12715 in `tag-git1-ios.log`
record the exact failure. Pi A independently found the same defect from source.
The old SDK's earlier stalled launches remain unproven; this result does not
retroactively establish those attempts passed.

Pi A changed only the disposable fixture's clone/push addresses to file URLs and
added bounded phase markers. All 19 assertions remain. Root added a fixture spec,
verified the native lock and confirmed no native/library/payload source changed.
Plugin `53ad359159258706d4c242e70a2db0e1d075dabc` is pushed. Its locked native
source remains `d002bd3`; no binary substitution occurred. Core
`79bfe0191878179caf370cfb154f23cc51918619` pins that plugin commit. App
`6473c165b94367151655f7ebd5a9cf25ff219da5` pins Core and preserves JAVA_REF.

Candidate `v5.0.5-git.2` was pushed to GitHub only. Final tagged run is
`44820763009`; duplicate branch run `44820732156` was canceled. Standalone Core
run is `44820635209`, plugin run is `44820553378`. No release is published yet.
Keep `.1` intact. Final publication still requires all original gates and the
production-SDK iOS runtime gate. No local tests or builds ran.

Read-only source preservation check at 05:21 CST found no difference in the
original cloudterminal HEAD, index, status or recorded file hashes. Three `.1`
package archives were inspected as files only: Windows x64, iOS and OHOS pins
and inner SHA256SUMS matched. These are audit evidence, not `.2` release assets.

## Published result

Final tagged run `44820763009` completed successfully: all 18 required jobs are
green, including the unchanged 19-assertion plugin flow on Flutter 3.50.0's iOS
simulator. Its log records initialization, clone, conflicting merge, merge
commit, push and remote verification, then `All tests passed`. Both the tagged
Core suite and standalone Core `44820635209` report 2394 visible passes, 26
existing skips and zero errors. All eleven installer targets and the packaged
Windows assistant passed their required checks.

GitHub prerelease `v5.0.5-git.2` was published at 05:43:01 UTC+08. Release ID
is `453206976`. Its thirteen uploaded assets contain eleven target ZIPs, one
assistant ZIP and SHA256SUMS. Every ZIP's digest from GitHub matches that
manifest. Root downloaded the actual released Windows ZIP and verified its
digest, expected installer and exact App/Core/plugin pins again. Four candidate
package archives also passed file-only provenance and checksum inspection; all
three mobile payloads contained their native Git binary and exact CA.

The immutable tag peels to App `6473c165b94367151655f7ebd5a9cf25ff219da5`. Core
is `79bfe0191878179caf370cfb154f23cc51918619`, plugin is
`53ad359159258706d4c242e70a2db0e1d075dabc`, and locked native source stays
`d002bd3e9febb478758b75b6670a24ba8a3c610c`. All three isolated worktrees are
clean and their GitHub branches match. Candidate `.1` and the prior remote
preview were preserved. No CNB tag was pushed.

Source preservation was checked again at 05:46 UTC+08: no original cloudterminal
HEAD, index, status or recorded file hash changed. No local test, build or App
launch ran. Hardware, live-account/provider and older iOS SDK compatibility
acceptance remain separate from this successful production-SDK release. The
older plugin SDK diagnostic job is not claimed as successful.

Installation steps are in `reports/install-git-preview.md`. Release evidence is
in `reports/release-verification.json`, `tag2-final-run.json`,
`tag-git2-core-counts.json`, `tag-git2-ios.log` and `tag-git2-publish.log`.

Task archive completed. Root omitted `--no-commit` on that command. The archive
helper staged the month directory, then failed before committing because the
old task path had been untracked. Root restored only those 199 added index
entries with explicit pathspecs. No working file was removed and the original
checkout HEAD stayed `e018db9`. Its index is empty again. See
`reports/archive-index-recovery.json`. Release commits and GitHub assets were
unaffected. Preserve the local binary evidence as untracked files.
