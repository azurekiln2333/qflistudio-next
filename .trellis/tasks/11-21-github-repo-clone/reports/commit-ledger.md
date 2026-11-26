# Requirement commit ledger

Core: `D:/MyNewProjects/_wt/studio-git-integration/qfli_studio_core`.
App: `D:/MyNewProjects/_wt/studio-git-integration/qflistudio`.

Root alone stages and commits. Worker cumulative copies are review inputs.
They never replace the working source. Each commit contains one requirement.
Cross-repository requirements use a matching requirement number in each root.

| Requirement | Repository | Commit | Result |
| --- | --- | --- | --- |
| R2 clone directories | Core | `16a6a474da0d014f6c36a3a91430273feed0d337` | New clones use `projects/gitProjects/`. Existing paths remain. |
| R1 GitHub | Core | `7b3b4fd75ad9c6164d747513e6d108d9d5b7c1aa` | OAuth/PAT, secure token lifecycle, pagination and repository picker. |
| R7 scoped cache | Core | `4cb5618f8620c88e07745e05670ba926ed0e6984` | Persistent scoped workspace and complete snapshot foundation. |
| R3 cloud deletion | Core | `8d57ebb0ad3d65430ce4246eca0c15a2984133ad` | Home remote deletion, durable tombstones and stale-refresh fences. |
| R4 selection sharing | Core | `ff92a0b8a7cfe55f43fbf9b786651450f04a2be8` | File-tree ZIP selection, Android transport and save fallback. |
| R5 local project sharing | Core | `5754fbb4de3d18b53b75e2de914a92732d4e088e` | Home local project ZIP sharing. |
| R6 cloud sharing | Core | `db127e8ad24926ffe35a2600b62cf47f2af2b094` | Complete immutable snapshot sharing with session fences. |
| R8 cache status/actions | Core | `96f459590bac95a876b5efc786db6ee7186b542c` | Cache progress, metadata, update and guarded local clearing. |
| R1 GitHub integration | App | `b1c983243522a37cda14fa7257539a615d9cf812` | Secure-storage registration/configuration and Apple browser authorization. |
| R4 native sharing | App | `d31ad298afaf38652805b56195c2fa30492b27c9` | Apple/OHOS/Windows file sharing and explicit Linux save fallback. |

R2 checks: two Dart files passed formatting and targeted static analysis.
`git diff --check` passed. Regression sources were added but not run.

All eight requirements are committed. Core has eight requirement commits. App
has two matching integration commits. R7 precedes R3/R6/R8 because their scoped
session and snapshot behavior uses that foundation. Both implementation roots
were clean after the final commits on November 22, 2026.

## Final static verification

Each actual Core index for R1/R7/R3/R4/R5/R6/R8 passed full-library and changed
regression-source analysis, exit 0. The only diagnostic is the pre-existing
`composer_card.dart:313` informational braces lint. R2's two-file check is above.
Both App index stages passed `dart analyze lib`, exit 0, with only the existing
`main.dart:3` informational unnecessary import. Six staged YAML/XML/plist files
parsed successfully. Linux packaging shell syntax passed `bash -n`.

Every requirement stage passed `git diff --cached --check`. Frozen bundles B/C/D
contain 76 copies across 43 owned final paths. All copy SHA-256 values match.
All final working bytes match the frozen copies, and committed HEAD content
matches after Git line-ending normalization. Final evidence is in
`staging/final-verification.json`. Per-stage logs remain under
`staging/_index_validation/` and `staging/_app_index_validation/`.

## Validation boundary

Local validation is limited to formatting, static analysis, syntax and document
checks. No runtime tests, builds, services, devices or real cloud mutations run.
No push, deployment or release has been performed.

OAuth requires a registered device-flow application and `QFLI_GITHUB_CLIENT_ID`.
OHOS secure GitHub credential storage remains unsupported by the selected plugin.
Linux uses Save ZIP when native file sharing is unavailable.
Native compilation and receiver behavior require cloud/device validation.
Windows secure storage also requires the documented Visual Studio ATL component.
that deployment-image prerequisite has not been verified. Android's resolved
plugin and Flutter configuration both use API 24 minimum.

The planning-root App still resolves its older integration checkout.
The feature is implemented in the two roots above, not released to that App.
The earlier remote-account-binding worktrees remain separate.
The task stays `in_progress` for the external runtime/build acceptance gates.
