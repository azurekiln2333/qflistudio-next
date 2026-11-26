# Unapplied formatter-only proposal

The original user-requested functionality has current scoped verification. The sole open planned check is core formatting. These candidates were produced by the cached official Dart formatter with `--output=show --summary=none` reading the13 original files. A subsequent read-only formatter check of all13 isolated candidates passed with zero changes. No original source, page, index or current authorization was modified.

The source freeze remains in force: the C coordination instruction says **"Do not touch other source/page."** Seven proposed files belong to the exact frozen17 candidate dependency batch. Applying this proposal therefore requires an explicit narrow release for these13 files and a new exact authorization for the seven changed C dependencies. Page/controller/debug/output/terminal sources are outside this proposal.

Patch: `main-format-unapplied.patch` (SHA256 `ae7490cba8d1c5274181d4937b7dfb6e328d0784aa6059a06e57bb8bd73b7440`,37433 bytes,990 lines). Exact per-file raw SHA256, Git blobs and byte counts: `format-proposal-manifest.json`. These files sit beside this document.

| Core file | In current frozen17 | Current raw Git blob | Proposed raw Git blob |
| --- | --- | --- | --- |
| `lib/content/local_content_adapter.dart` | no | `61cdc1970ac7b97ecbc4d352755e6c802958e7b3` | `bd1dca86a5b3ed772418fab84beee8218c52b3db` |
| `lib/editor/file_explorer.dart` | yes | `b4b0f7532f104169458d06698a9bf85893fdf7bf` | `f10f5ed10e619db665811415a762810005679a1c` |
| `lib/editor/retained_editor_host.dart` | yes | `588516c9891243b0eca264d8a419eef889c82888` | `63cb4ad595efab4be073c1587f94a1c4b9f5855f` |
| `lib/workspace/saved_workspace.dart` | yes | `258ce49bb1308a02447ff5ee7b49d807fbb0c822` | `a4dd38727282e6a9bf66b3855fad6b13f01b6fbd` |
| `lib/workspace/workspace_dialogs.dart` | yes | `673de9049f7e67f456de84c02473b1dbd9c45751` | `c173ec922e86f33a1a8841277386736f532f03a3` |
| `lib/workspace/saved_workspaces_tab.dart` | no | `bc87afdf211d2af490c367538efb63a274607d82` | `e59febf6de147ec09402a87267d096d1b039b3e8` |
| `test/main_workspace_sessions_test.dart` | yes | `bdd4c32e2f078e673f1fedf670af20fcd1d291b3` | `363ef5fe218d434fa8ece725224f9e9bd77e4bb4` |
| `test/main_workspace_explorer_test.dart` | yes | `7dd24af5f3421c79ef0efe1d46cd373877fecae5` | `3f6f48109d316700dcaa33e74fdfe975fef38655` |
| `test/main_saved_workspaces_tab_test.dart` | no | `608857c7cfce77b0096d84fffcc1cfd7c6045165` | `efd2644cfd5af0f80d95ab12ba622b0fc8ee612d` |
| `test/main_output_no_analyzer_test.dart` | yes | `0f9e7c838828f20109d60c19990d2e03618ee663` | `0b08745c71df1d99c22810ca3179c81b6f2d8f2a` |
| `test/main_editor_short_height_test.dart` | no | `7e1c16a9a558e9d49d5ee04db1c5e253b283dd9e` | `5f41fdf439835b0143c574c8461835874f0d9ea9` |
| `test/local_content_filters_test.dart` | no | `d3705e495ddb2d1c2b4c631c7c7dc47bb8d9f5a5` | `f6e94f3fc4bb1a12da5592114ee72e7384e0c124` |
| `test/editor_run_test.dart` | no | `c094a36fac757950d2aed3b1c30b0a542a4cb7da` | `f576486202929428c63235c63f5f2686c539ad9c` |

The old/new bytes match after removing whitespace and comma bytes, and no new Unicode replacement characters were introduced. This supplemental byte comparison is not an independent parser or runtime proof; the authoritative transformation is the official formatter. Original main6/core41 analysis and current21+58 behavior checks remain separately documented.

If approved, apply only these exact13 candidate byte versions after rechecking their old hashes, refresh only the seven changed dependencies in a superseding C manifest, and rerun the final scoped formatting/analysis/content/bundle checks serially. Until then, keep every source and frozen17 v2 version unchanged.

The proposal run completed in5.72396 seconds; root58916 and all observed descendants were terminal, no deadline cleanup/errors/source drift, automatic RELEASE global362. No host slot is held.
