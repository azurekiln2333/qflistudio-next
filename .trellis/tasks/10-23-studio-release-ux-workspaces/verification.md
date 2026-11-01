# Verification ledger

Task remains in progress. Evidence is scoped to current host code; no device,
backend, live account, commit or publication gate is implied.

| Requirement | Authoritative implementation | Evidence and outstanding check |
| --- | --- | --- |
| All local tutorials/examples, separate C/C++, metadata preserved | main StudioContentRepository + composition generator/verifier, core adapter/pages | Official generator reproduced identical current bytes; complete-row verifier passed 2180 groups/2415 lessons/2613 examples across27 sources. Actual Flutter asset bundle build and binary manifest inspection passed with all3 catalog registrations and matching bytes/hashes. Main repository3, production Home3 and core content checks passed earlier. Current filters9 passed in first21. Final remaining6 report below binds content/assets to the stable inputs. |
| Hide tutorial publish/plus; left title and Home search | main Home local routing, LocalTutorialsTab header/search | Existing header/theme/content tests and production main Home tutorial/example route passed. Main uses bundled local pages with no online publish/plus controls. Current content filters9 passed, including both new null-profile main/legacy-language widget regressions. |
| More working tools, preserve child builders | offline_text_tools, tool pages and additive commonTools registry | 9 new tools/18 total, 48 focused tests passed; scoped analysis clean. |
| Immediate check-in progress and safe transitions | TasksPage + TaskActivityService | Current four-file REVIEW5 suite 29/29 PASS, exit 0 (`--no-pub --concurrency=1 --timeout 60s`): immediate progress, retry/unknown-result transitions, account/day isolation, token-bound confirmation, persistence failure and delayed GET preserving successful check-in/auth balance. All eight source/test files analyze clean; scoped diff check passed. |
| Responsive points/redeem tabs | PointsFeed per-section loads/cache, retained tab lists | Same current 29-case suite proves independent loads, retained scroll/no tab refetch, per-account/day cache, stale-account/balance guards, forced-refresh deduplication, post-mutation generations superseding blocked requests and running tails, and redemption persistence recovery. All eight source/test files analyze clean. No device frame-timing or backend performance claim. |
| Hide Home cloud; show saved Workspaces | main-specific Home scopes/create/fetch guards + SavedWorkspacesTab | Production main Home/cloud/workspace test passed with English locale after fixing popup label overflow. Four scopes include Workspaces; cloud cards/menu stay hidden and registry data is retained. |
| Explicit save in editor; data/workspaces | WorkspaceStore + explorer management dialog | Store21 and actions4 in the current first21 batch passed. Actions use the real toolbar/dialog/save/update and Home card dispatch, assert workspace JSON under data/workspaces, same-id membership updates and unchanged source bytes. The later current composed regression58 also passed, including main sessions6, retained9 and animation3 with mounted EditorPage sessions, promotion/reuse and dirty-buffer preservation. |
| Independent standalone/workspace sessions | retained host + EditorPage main history gate | Current composed regression58 passed, including all main sessions6, retained9, animation3 and owner-run23; standalone promotion/reuse, missing-primary identity, dirty orphan Run refusal and unchanged-source assertions remain. |
| Missing/deleted members including retained primary | store resolve, Home missing-member dialogs, page reconciliation, explorer fallback | Store21, actions4, current composed main sessions6/explorer4 and earlier Home card2 passed. Explorer covers fallback, expansion restoration, removed-root isolation and 1100x175 at 1x/2x. Current owner-run23 and history11 passed, including owner capture, physical confinement and concurrent document/session writes. C debugger-specific suite remains C-owned. |
| Workspace action reacts with one project | explorer toolbar always main-enabled + management dialog | Current actions4 passed: one-project toolbar opens the real dialog, primary is selected/disabled, save promotes the explorer, later member update reuses the document, and missing-member Home actions preserve sources. |
| Hide absent main analyzer; preserve child analyzers | EditorProblemsBar main-product/provider condition | 19 analyzer/visibility tests passed earlier. Current composed main Output1 passed again with no unavailable-checker text and editor still mounted; real EditorPage1100x175 plus Output request1 also passed. Child legacy workspace4/explorer12 passed earlier, with child Home8 and current retained/owner-run regressions preserving explicit language profiles. |
| Four existing Pi agents, Trellis artifacts | w2E:p4/p6/p5/p7 and this task/channel | All four dispatched. Tools provider502 handed off to native agent; no unauthorized product repo mutation. |

## Final source audit — October 23, 2026

The final read-only review checked all 12 original PRD requirements against the
current implementation and accepted scoped evidence. No additional concrete
original-main-scope implementation gap was found. The later final-check reports
below establish scoped analysis, generator/verifier and asset-bundle results;
core formatting remains unresolved under the explicit source freeze.

| PRD | Current source and evidence inspected |
| --- | --- |
| 1 | Home routes the main product to bundled LocalTutorialsTab through the shared lazy repository. Local content groups tutorials by normalized teaching subject; C and CPP use distinct exact filters. Headers are left aligned and search uses Home's filled, borderless style. The local route has no publishing controls; current content filters9 and earlier production Home/header checks passed. |
| 2 | The main adapter and examples tab keep all subjects instead of filtering by qflistudio. Example tiles open editable source/details with real store/import wiring. Difficulty, subject/type and fixtures survive the legacy UI projection; source metadata remains in the verbatim bundled rows and parsed repository. The exact two-field Java synchronization is recorded in research/content-refresh-20261023.json; the later official generator reproduced identical bytes and the complete-row verifier and actual bundle inspection passed. |
| 3 | All nine additional tools have concrete registered builders, bringing common tools to18. Product sections, inline toolsTabBuilder precedence, toolsPageBuilder and injected runtime entry points remain intact. The accepted tools48 scope covers their logic, registration and routes. |
| 4 | Check-in sets its duplicate guard before awaiting, replaces the button slot with an indeterminate bar, clears progress in finally and preserves retry or refresh-confirmation feedback. Accepted points29 covers immediate progress, success/failure, uncertain-result confirmation and account/day isolation. |
| 5 | PointsFeed starts independent sections concurrently, keeps per-section loading/error/cache state, guards account/token/generation and balance changes, and deduplicates refresh tails. Retained tab bodies preserve their scroll state. Accepted points29 covers these contracts; no device frame-timing claim is made. |
| 6 | Main Home omits cloud scope/create entries, filters cloud cards and returns before remote cloud catalog loading; ProjectStore data remains retained. Earlier production Home coverage and the current Home navigation cases passed. |
| 7 | Main Home exposes SavedWorkspacesTab. The editor dialog explicitly saves named metadata through WorkspaceStore under AppPaths.storageDirectory()/workspaces, and Home resolves/reopens it. Store21 and current actions4/main sessions6 passed. |
| 8 | Retained workspace identity is separated from standalone identity; promotion keeps mounted buffers while a later standalone open receives its own session. Main standalone restore/write paths ignore cross-root legacy documents. Current main sessions6, retained9, animation3 and history11 passed. |
| 9 | Workspace resolution checks registry membership and directory existence, skips/report missing members and selects a surviving primary. Home provides partial-missing confirmation and an actionable all-missing state. Removal only deletes workspace metadata; ordered store writes cannot recreate deleted records. Store21, current actions4/main sessions6/explorer4 and owner-run23/history11 cover the relevant contracts. |
| 10 | The explorer toolbar always exposes workspace management, including a single project; the dialog fixes the primary selection and updates the same saved document. Owner-aware documents/run targets, orphan refusal and physical root confinement remain in the current page/host/explorer paths. Current actions4 and regression58 cover these behaviors, including the actual short-height editor. |
| 11 | EditorProblemsBar hides the main surface only when no analyzer provider exists. Available language analyzers retain their UI, and status rendering gives unavailable reasons precedence over clean-code results. Accepted analyzer19 and current main Output1 passed. |
| 12 | Task design, briefs, handoffs and verification record use of the four existing Pi panes w2E:p4/p5/p6/p7. Main integration is covered by the accepted first21/regression58 batches; the Pi tools provider failure was explicitly handed to the native worker. No language product regeneration, live reward claim or device action forms part of this acceptance. |

The actual first21 and regression58 reports/logs were re-read: each records
PASS, Flutter exit0, empty stderr and no source drift. All10 files recorded by
the first batch and all15 recorded by the regression batch were rehashed and
still match current bytes. The current editor page remains
`6d4e56d1f5cc6e95f4bba48bfda8582df676bbfc25d8bb93f6bc7b46c18c4b89`.
The audit ran no tests, Dart/Flutter, analyzer, build or formatter. Its scope is
the original main release and shared compatibility contracts; C debugger
acceptance, all-product publication and device/runtime gates remain separate.

## Current test sequencing

Main235/240 was explicitly RELEASED at global264 with zero live Dart/dartvm/
flutter_tester processes. C/user steering then assigned SQL224 -> Go236 ->
Rust205 -> C211, followed by queued Web219 and other owners. Those historical
reservations are not a current main reservation. The later bounded windows
and their exact authority and terminal releases are recorded below.

The later named Dart341 terminal handoff explicitly released to Note/main. Main
accepted in global346 after confirming Note's primary was a plain PowerShell
prompt with no agent, no Note acceptance and no competing host process. The one
bounded invocation completed in11.763356 seconds: actions4 + content filters9 +
Home navigation8 =21/21 PASS, Flutter PID56184 exit0, no deadline termination,
no before/after source drift. All observed Flutter descendants were terminal;
automatic release to `web-offline-1022` was delivered as global347. No main host
reservation remains. Exact report/logs:
`.artifacts/main-first-gate-20261023T080848Z-a061190b/process-handle-report.json`.
The report binds the tests and seven core source files to core HEAD e025805,
with composed page SHA-256
`6d4e56d1f5cc6e95f4bba48bfda8582df676bbfc25d8bb93f6bc7b46c18c4b89`.
This batch compiles the current page/API. The subsequent regression batch below
supplies the retained/owner-run/history and mounted real-EditorPage evidence.

Those integration checks subsequently completed in the single bounded main350
window:58/58 PASS = retained9 + animation3 + owner-run23 + history11 + main
sessions6 + main Output1 + explorer4 + actual short-height page1. Root PID44584
exited0; elapsed39.385992s, no deadline termination/errors/source drift. All
observed child handles were terminal and automatic RELEASE351 to Web was
delivered. Exact report/logs:
`.artifacts/main-regressions-gate-20261023T081857Z-a34dd2ea/process-handle-report.json`.
The page hash remains the recorded `6d4e56...18c4b89` checkpoint; all17 frozen C
dependency raw hashes were separately rechecked after the run. Channel352's LIVE
text used an older sampling snapshot after the automatic terminal release;
global353 explicitly corrected it. No live main handle or reservation remains.
This establishes the current worktree behavior, not C's alternate candidate-index
or device/runtime publication gate.

Accepted scoped evidence at the tested checkpoints: main Home3 + repository3; explorer4; workspace/session/
card/Output/actual-shortheight/legacy26; points29; tools48; store21. The 26-case
batch initially passed25 and failed the newly added orphan Run harness timing.
The final filtered case passed after waiting for tab animation and dismissal of
an already queued recovery SnackBar; actual tab/Run gestures and no-write
assertions remain. No page/controller change was made for that harness fix.

Still required: resolve13 core formatter findings without violating the current
source freeze. Scoped analysis, official generator/full-row verifier and actual
main asset-bundle packaging inspection subsequently passed as recorded below.
Do not repeat accepted unrelated suites merely to combine totals.

C owns editor_page.dart, editor_controller.dart, debugger/output modules and
terminal integration. Main has no remaining planned page edits and has not
written editor_page.dart since p6 stopped at local02:05:38. C global229 was the
accepted compile-stable API checkpoint for those integration tests. C260 resumed
narrow terminal/debugger source fixes afterwards; the current composed page
was revalidated by the later regression58 batch. Main workspace/history/
retained-host hunks must be preserved.
Published core remains e025805; current dirty core is not a final published checkpoint; earlier OHOS proofs remain bound to their original bytes.

## Final gate attempt and source freeze

The bounded global355 final window stopped at the second command. Main6
formatting passed; core41 read-only formatting reported13 files that would
change and exited1. No source bytes changed. All17 raw hashes still match the
v2 C authorization manifest. Seven formatter findings are frozen dependencies:
file_explorer.dart, retained_editor_host.dart, saved_workspace.dart,
workspace_dialogs.dart, main_workspace_sessions_test.dart,
main_workspace_explorer_test.dart and main_output_no_analyzer_test.dart.
The other six are local_content_adapter.dart, saved_workspaces_tab.dart,
main_saved_workspaces_tab_test.dart, main_editor_short_height_test.dart,
local_content_filters_test.dart and editor_run_test.dart.

The source freeze takes precedence over formatting edits. The EOF-only
authorization is not an authorization to format those files. Main applied no
additional source changes and did not write either Git index. Analysis,
generator/verifier and bundle checks did not start in this attempt; their
independent results must be recorded separately without treating format as
passed.

Driver PID2460 and all observed descendants were terminal. The runner completed
in1.846795 seconds and automatically delivered RELEASE356 to Web; global357
published the formatting finding. There is no retained main host slot.
Reports/logs:
`.artifacts/main-final-gate-20261023T083451Z-6af2ff9c/`.

Global354 explicitly reconfirmed the corrected explorer/session EOF blobs from
`c-publication-dependency-authorization-20261023-v2.json`. C may refresh only
those two alternate-index blobs and recheck cached whitespace. This does not
claim C candidate-index, commit, device or publication acceptance.

## Remaining six final checks

The global358 bounded window ran only the six checks after the original
formatting failure. It validated the prior report and identical current hashes
before launch. Its result explicitly states `remaining-six-gates-only` and
`full_final_pass: false`; it preserves the unresolved core formatting failure.

| Gate | Exact command PID | Result |
| --- | --- | --- |
| Cached Flutter analysis, main6 | 31052 | PASS, no issues |
| Cached Flutter analysis, core41 | 57996 | PASS, no issues |
| Official main content generator | 44048 | PASS, identical3 asset files |
| Official complete-row verifier | 2328 | PASS, all27 authoritative inputs |
| Isolated Windows-target Flutter asset bundle | 30664 | PASS |
| Actual binary manifest and packaged catalog inspection | 50484 | PASS |

The bundle registers tutorials.json, examples.json and provenance.json in
AssetManifest.bin (SHA256
`2cbcdc8e57ebe800d684a613379098eeb286d56255036f0f4d522b80f8ec0e81`).
It contains2180 tutorial groups/2415 lessons/2613 examples across16 subjects,
including distinct C and CPP. All packaged bytes match current source assets.
No executable, native package, installation or device runtime proof is claimed.

Driver PID47120 exited0. All observed handles were terminal, no deadline cleanup
was needed, elapsed23.934308 seconds, and automatic RELEASE359 to Web was
delivered. All source/input/asset/frozen17/control hashes remained unchanged;
the composed page checkpoint remains `6d4e56...18c4b89`. No main reservation or
remaining planned page edits exist. Exact raw logs, hashes and process reports:
`.artifacts/main-final-remaining-gate-20261023T084155Z-85594cfa/`.

The task and goal remain in progress solely for the unresolved formatting gate;
no formatting source mutation is authorized by the EOF-only C amendment.

An independent final read-only audit confirmed all six command exits0, empty
stderr/drift lists, all17 current raw hashes, unchanged page, both exact EOF
hashes/Git blobs, and the real binary manifest's three registrations with
packaged byte equality. It found no additional concrete issue. It retained the
13-file format failure and the asset-only proof limitation; no further Dart,
Flutter, test, formatter, build, source or index action was run for that audit.

## Unapplied formatter proposal

The next goal turn made concrete progress without releasing the source freeze.
The global361 bounded window read exactly13 original files using the official
formatter's `--output=show --summary=none`; captured output became isolated
candidate files. A subsequent read-only check of all13 candidates passed with
zero changes under the same Dart3.11 language configuration.

The unified990-line/37433-byte patch SHA256 is
`ae7490cba8d1c5274181d4937b7dfb6e328d0784aa6059a06e57bb8bd73b7440`.
The candidate manifest records exact old/new raw SHA256, Git blobs, byte counts
and frozen membership. Seven candidate paths belong to frozen17; no page,
controller, debugger, output-panel or terminal source is included. Every original
source, all27 inputs, assets, frozen17 and page/config bytes remained unchanged.

The proposal is explicitly unapplied and does not supersede C's v2 authorization.
A narrow user question asks whether to release only these13 formatting writes
and refresh the seven dependency hashes, or retain the freeze. No answer is not
authorization. No dependent source writes may proceed while that question is
pending. Both quality-guideline files are placeholders; the actual formatting
gate comes from implement.md step4 and remains unresolved in current sources.

Root58916 and all observed children were terminal;5.72396 seconds, no deadline
cleanup/errors/drift, automatic RELEASE362. No slot is held. Proposal, full raw
reports and exact manifest:
`.artifacts/main-format-candidate-gate-20261023T090109Z-24093411/`.

The unapplied patch additionally passed `git apply --check --whitespace=error`
against the current core worktree, exit0/empty output. Its exact scope is13
files,344 insertions/321 deletions. Current source hashes and frozen17 still
match; the read-only validation artifact also records current page and real
index hashes. Global363 publishes the proposal and explicitly retains v2
authority. Source application awaits the narrow user release question.

The independent candidate audit passed: exact13 patch/manifest paths, exact
seven-file frozen intersection, old/new hashes and byte counts, unchanged v2
and page, all14 formatter commands exit0/empty stderr, zero reported drift.
Applying every unified hunk in memory reproduced each exact candidate and Git
blob without writing sources. No additional issue was found. The proposal
remains unapplied and `full_final_pass` remains false.

## Source-freeze blocked audit

The next automatic goal continuation received no source-freeze release, no
answer to the pending narrow question and no channel event after363. Current13
originals, frozen17, page and exact patch hashes still match. Every recorded
gate process is terminal; the fresh heavy-process inventory is empty. This is
not a live-process wait and no main slot is reserved.

The same condition now spans three consecutive goal turns: initial format13
failure plus remaining6 validation, concrete unapplied canonical proposal plus
independent review, and this unchanged-state revalidation. The preceding goal
turn made progress; this turn has no remaining authorized implementation or
verification action that can resolve the gate. Independent review confirmed
the impasse. Source application requires the explicit narrow freeze release;
automatic continuation and silence do not provide it.

The blocked audit is recorded in `blocked-audit-20261023.json`. The original
goal is not complete; its source freeze, exact v2 authorization, prepared patch
and full requirement scope remain preserved while goal blocking is requested.

## Actual workspace-settings black overlay repair

The user refocused this session on the editor workspace settings action showing only a black background. Narrow fix authority supersedes the earlier freeze for this bug's exact dependencies; the separate formatting proposal remains unapplied.

A real retained EditorPage + phone drawer + OHOS/Chinese test reproduced the old AlertDialog failure: RenderShrinkWrappingViewport does not support returning intrinsic dimensions. OHOS defaults AlertDialog to a scrollable layout whose intrinsic-height query reached the nested shrinkWrap ListView. The modal barrier had already opened.

Both the main saved-workspace dialog and language-product membership dialog now explicitly let AlertDialog own scrolling and use ordinary project children that can answer intrinsic sizing. Actions remain outside the content scroll; no selection or persistence callback changed.

New five-case regression: OHOS phone390/desktop1100, Android phone, OHOS standalone one-project save and explicit language profile membership apply. It checks actual toolbar clicks, hit-testable dialog controls, ten-project last choice with keyboard300, stored name/members, unchanged source, same editor State/workspace id and cancel returning toolbar input. Initial frame and keyboard-inset animations are advanced before physical taps.

Results: focused5 PASS; related37 PASS (workspace dialog, actions, explorer state, workspace sessions, retained editor and actual1100x175 EditorPage); narrow3-file analysis No issues found. All tracked handles terminal and released, no source drift. Reports are in v3 manifest. No main host reservation or device/native-build claim.

Exact publication: v3 supersedes only workspace_dialogs.dart, file_explorer.dart, saved-workspaces.md and adds workspace_dialog_layout_test.dart. Other14 v2 paths unchanged by raw hashes and Git blobs. Page remains byte-identical; real and C alternate indices untouched by main. C may refresh these exact candidates and integrate without another approval loop.

Separate finding sent to C: editing an existing saved workspace does not refresh the retained host's name/member snapshot until reopen because page _onWorkspaceChanged notifies onWorkspaceSaved only when id changes. Visible explorer/settings and stored document update correctly. No page or host write was made for this separate finding.

## Actual project-selector correction

The user requires member selection to preserve a workspace's complete tree and external selection to replace it with the external project's standalone tree. Actual popup clicks against the old source reproduced W(A,B) selecting B dropping A, and external C not changing the editor's project identity. Proof: `.artifacts/main-project-switch-gate-20261023T151117Z-a533f62d/`. The preceding attempt failed in a hidden-tree fixture and is not treated as selector evidence.

The explorer now derives saved roots from stable primary/member configuration rather than current browsing. Member selection updates only browsing and the default creation root, retaining loaded children and expansion/scroll. External main/saved selection dispatches through an optional owner callback. The retained host opens/resumes an ordinary standalone session; a page without an owner pushes a standalone EditorPage route so Back restores the original page. Bare saved-workspace explorers without an owner disable external choices. Legacy language-product unsaved browsing remains compatible.

The page delta is limited to optional callback constructor/property and the FileExplorer navigation adapter; independent review verified the exact-baseline diff preserves C-owned integration. The regression physically opens the initially collapsed tree and uses the real popup. It checks nonzero scroll, root order/expansion, unchanged dirty buffer/controller/page, B default creation path, C ownership/session reuse, unchanged saved membership/source, no-host Back and standalone-to-standalone switching. Temporary fixture cleanup explicitly drains project-history writes.

Validation: focused3 PASS; related40 PASS across seven test files including actual1100x175, settings dialog, saved explorer/sessions, retained editor and legacy explorer; scoped4 analysis No issues found. No swallowed layout exceptions. The three final reports are recorded by exact SHA256 in `c-publication-dependency-authorization-20261023-v4.json`; every observed heavy handle is terminal and the bounded slot was automatically released. No native build, device install or device runtime proof is claimed.

Publication v4 freezes exact19 dependencies and a separate three-hunk page adapter. It replaces explorer, retained host and saved-workspace spec, adds the switch regression, and verifies other15 v3 raw hashes and Git blobs unchanged. Page and dependency patches plus exact frozen copies are reviewable. Real index remains29299AB25BF221D7B41EBD1341019D2D2E7521ECE9B478AD731EB71AD2F90B1C; main mutated neither index and did not commit/push. C may integrate the exact batch without another main approval. Page lock released; no further main page writes planned. Separate broad formatter proposal and same-id host metadata follow-up remain outside this batch.

Independent publication audit completed CLEAN: all19 current/frozen raw hashes, bytes and normalized Git blobs, other15 complete prior entries, exact page baseline/current/frozen and3 insertion hunks, unchanged real index, and all three terminal PASS reports/source bindings matched. Both isolated patches also passed reverse application checks with whitespace errors enabled. This is current-worktree/frozen proof and does not establish behavior for a future C candidate index or later composed page.

## C421 narrow Home publication dependency

C published the exact v4 closure plus composed page as36697b0/treef6913564b966. At C's explicit request, main prepared artifacts-only minimal Home workspace plumbing and exact saved_workspaces_tab.dart. Base Home blob38163e47 is unchanged by C's checkpoint. The candidate has exactly six hunks: imports, workspace enum, explicit capability-controlled scopes, tab label/body and exhaustive scope case. Main cloud policy/filter/fetch/menu/catalog and other WIP remain excluded. The final Home mapping subsumes JSON's overlapping capability hunk; its other three separately authorized capability paths remain prerequisites.

Artifact manifest `.artifacts/home-named-workspace-dependency-20261024/manifest.json` SHA25694317EBCDBDFD6419F151DCEF33B74CFFE5E3EE346BA37A03BC23D8B5C1C0745 freezes exact candidate Home and tab raw hashes/Git blobs and both minimal/combined patches. The combined patch passed read-only whitespace-enabled application check against artifact baseline, exit0. Fourteen guarded source files, current shared Home WIP, page and real index remained identical throughout; no source/index/page or device mutation and no Dart/Flutter/heavy run occurred. Independent source review found no blockers. The smaller candidate is unexecuted; JSON435 actual-profile worktree PASS is not promoted to candidate proof. C retains sole publication, page lock and the separate same-id metadata follow-up.

Independent artifact audit completed CLEAN: exact hashes/blobs, six allowed Home hunks, exact tab addition and preparation guards matched. Later C446 source edits were reported separately. C then integrated exact Home/tab in2f9039a3/treef d21ffcdc7ac9c834e0b788b21178e9f80768a519; main read-only Git objects confirm both dependency blobs match the frozen manifest. C reports69core+actualJSON1 PASS and12Dart analysis clean for its composed same-id/capability batch; main did not rerun those checks or independently verify the in-progress four-remote push. Lua474 next slot preserved; no main reservation or further source/page work.
