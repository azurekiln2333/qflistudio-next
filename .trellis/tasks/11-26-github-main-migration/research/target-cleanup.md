# Target portability and project-owned cleanup audit

## Scope and authority

- Task: `.trellis/tasks/11-26-github-main-migration` (`in_progress`).
- Audit date: 2026-11-26. Repository evidence sampled 18:04–18:14 UTC+08:00.
- Auditor: Herdr pane `w65:p5`, model `gpt-6.1-sol` (confirmed from `PI_MODEL`). Lead: `w65:p1`.
- Source: `D:/MyNewProjects/qflistudio`.
- Target: `E:/MyNewProjects/QFLIProjects/qflistudio-next`.
- Initial assignment was read-only. Subsequent authorization permits only this report and `target-cleanup.json` in this task. No target edits, coordination with `w6D`, task creation, staging, commits, merges, synchronization, cleanup, package operations or project validation were performed by this auditor.
- Coordination used Herdr. WSL commands were limited to `wsl --list --verbose`. Registry/file metadata reads did not start or mount a distribution. No credential contents were read.

## Finding summary

| Check | Observed result |
| --- | --- |
| Target GitHub-only remote | Pass: only `origin`, fetch/push `https://github.com/azurekiln2333/qflistudio-next.git` |
| Target clean status | Pass at audit cutoff: `git status --porcelain=v1 -uall` returned no entries |
| Target current commit | `main` at `7104c64ef545ca006533140794729c2f2f40795f` |
| Target commit/tree equals source | Fail at baseline; neither commit nor tree matches |
| Target path dependencies | Blocked: three core paths use absent `../qfli_studio_core`; actual sibling name is `qflistudio-core` |
| App submodules/LFS | No index gitlinks, no `.gitmodules`, no LFS-tracked files or `filter=lfs` rule observed |
| Portable Trellis support | Incomplete in target; workflow, scripts, journals and skills are absent and ignored |
| Cloning instructions | Old sibling names and local validation instructions remain; no reproducible current clone recipe |
| WSL | Five registered WSL2 distributions, all Stopped; three VHDs belong to the audited source path |
| Cleanup readiness | Not approved for execution; preservation, owner review and final cloud/source/target comparison remain gates |

## Repository evidence

### Target baseline

- Branch/upstream: `main` / `origin/main`.
- HEAD: `7104c64ef545ca006533140794729c2f2f40795f`.
- HEAD tree: `076bea13ff5c3a971e88d5560729d960998f4a36`.
- Commit date/subject: 2026-11-24, `ci: pin cloud-verified core workbench release`.
- One local branch and one registered worktree were listed for this target.
- No target `build/`, `.dart_tool/`, `.flutter-plugins-dependencies`, `pubspec_overrides.yaml`, `android/.gradle/`, `ohos/node_modules/`, `ohos/oh_modules/` or `ohos/.hvigor/` existed during the audit. Keep this source-only state.

### Source baseline

- Branch: `main`.
- HEAD: `fd5041973d954031abeaaadd6ed1d3e7f70f9994`.
- HEAD tree: `16b7ba992f3ff1d9e13b618e7c3ffa282e26bb5b`.
- Commit date/subject: 2026-11-22, `docs(task): record tools column preference implementation`.
- Status at 18:13 UTC+08:00: 8,863 entries with `-uall`: 25 modified, 77 deleted, 8,761 untracked. This expands untracked directories and must not be equated with the earlier compact SessionStart count.
- Of these, 8,755 entries are under `.trellis/tasks/`; 7,490 entries are under `.trellis/tasks/11-21-github-repo-clone/reports/staging/`.
- The 77 tracked deletions are the old embedded `azurekiln-qfli-server` tree. They are not disposable build output. Its split-repository disposition belongs to the lead's preservation audit.
- Configured remotes: `cnb`, `gitcode`, `gitee`, `github`, `gitlab`; therefore source is not GitHub-only at baseline.
- Cached source `github/main`: `c5f4bc3afe9c81ba488fd3f544d43c3dac061512`. Target HEAD is its ancestor, two commits behind: `83f4b14` and `c5f4bc3`.
- Cached source local-main divergence: 2 ahead / 117 behind `github/main`. No fetch or live GitHub query was made by this auditor. These are local-ref facts, not a claim about the current server.
- Linked source worktrees were inventoried through Git metadata only; their directories were not traversed. No worktree removal is authorized by this report.

## Sibling path migration

The approved new contract is `../qflistudio-core`. Core and app/CI owners will migrate together. The package identifier remains `qfli_studio_core`; directory renaming is not permission to rename Dart imports or the package.

Evidence in target:

- `pubspec.yaml:18,28,33`: core, patched `re_editor`, patched `xterm` use `../qfli_studio_core...`.
- `pubspec.lock:452,467,607`: the same old core paths remain.
- `Test-Path` returned false for all three old paths. `../qflistudio-core` exists.
- Only immediate sibling directory names were listed. Their repositories or contents were not audited.

| Old directory contract | Observed/new directory name |
| --- | --- |
| `qflistudio` | `qflistudio-next` |
| `qfli_studio_core` | `qflistudio-core` |
| `qfli_c` | `qflistudio-cpp` |
| `qfli_dart`, `qfli_go`, `qfli_java`, `qfli_json`, `qfli_lua` | `qflistudio-dart`, `qflistudio-go`, `qflistudio-java`, `qflistudio-json`, `qflistudio-lua` |
| `qfli_note`, `qfli_python`, `qfli_rust`, `qfli_sql`, `qfli_web` | `qflistudio-note`, `qflistudio-python`, `qflistudio-rust`, `qflistudio-sql`, `qflistudio-web` |
| Git plugin repository | `qflistudio-git` |

Migration impact extends beyond the manifest:

1. Update the three relative manifest paths and the corresponding lockfile descriptions without local dependency resolution. Resolve and validate the coordinated revision in cloud CI.
2. Update `.github/actions/app-setup/action.yml` core checkout path, core revision lookup and patch arguments. Update `.github/workflows/app-installers.yml` matrix directories, core/Java sibling paths and path-sensitive log normalization. Keeping the app CI checkout alias `qflistudio/` is possible if done consistently; it need not match the repository name.
3. Review actual filesystem paths in `tool/generate_content_catalog.dart`, `tool/generate_studio_content.dart`, `tool/new_language_app.dart`, `tool/validate_content.dart`, `tool/verify_ohos_products.dart`, `tool/verify_runtime_matrix.dart`, `tool/verify_studio_content.dart`, `tool/verify_vibe_e2e.dart` and `tool/build_studio_hap.sh`. Preserve package identifiers and historical evidence rather than performing a blind text replacement.
4. Source ignored `pubspec_overrides.yaml` points to `D:/MyNewProjects/_wt/integration/qfli_studio_core`; source `pubspec.lock:363,370` contains matching absolute paths. Do not copy these machine-bound overrides to the target or commit them as the new contract.
5. `qfli_git` in the target lockfile is a pinned Git dependency, not a local sibling dependency: repository `azurekiln2333/qflistudio-git`, resolved ref `697291a27818612ae9dc53d83d4f99fa5887908e`. Do not add a sibling requirement for ordinary app consumers without an intentional dependency change.

## Submodules, LFS and cloning documentation

For both audited app indexes, `git ls-files --stage` returned no mode-160000 gitlinks; `git lfs ls-files` returned no files. Target `.gitmodules` is absent. `.gitattributes` contains only the Trellis journal merge rule and no LFS filter. The app therefore has no observed recursive-submodule/LFS checkout requirement at this baseline.

This does not establish the requirements of sibling repositories. `.trellis/spec/frontend/repository-layout.md:33` mentions a Python MicroPython submodule; that belongs to the Python owner and was not traversed here.

Required documentation changes for the lead:

- Replace README's old 13-repository layout with exact GitHub repository-to-directory mapping, including `qflistudio-cpp` and optional Git-plugin/native work.
- State the minimum app checkout: `qflistudio-next/` beside the reviewed `qflistudio-core/` revision. Optional language repositories are needed for cross-product content generation, not automatically for reading app source.
- Provide explicit clone destinations and paired app/core commits. Document each sibling's own submodule/LFS requirements after that owner's review; do not recommend blind recursive initialization for this app.
- Describe the pinned Git plugin and native cloud artifact provenance. Do not download runtime/installer payloads to the target as a checkout step.
- State that cloning does not run Flutter, package resolution, toolchain setup, builds or validation. README's current `flutter pub get`, local run/analyze/test and DevEco Sync examples must be marked inapplicable to this workspace or replaced with cloud-only guidance.
- Repair the portability gap: target `AGENTS.md` refers to `.trellis/workflow.md`, `.trellis/scripts/`, `.trellis/workspace/` and `.agents/skills/`, but none exists in target. Target `.gitignore:84,91,94,95` excludes these locations. Preserve reviewed portable journals/workflow/spec/task support while retaining exclusions for `.trellis/.runtime`, `.developer`, credentials and machine configuration.

## WSL inventory and exact VHD metadata

All five names below were returned by `wsl --list --verbose` as **Stopped, version 2**. Registry root: `HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Lxss`. No startup, mount, export, shutdown, unregister or disk compaction was run.

| Distribution | Registry subkey | Registry BasePath | Registered VHD filename | File length (bytes) |
| --- | --- | --- | --- | ---: |
| `Ubuntu` (default) | `{044a4968-7a56-42d5-a25a-c213da943493}` | `D:\WindowsExt\Subsystem\Ubuntu\Ubuntu_2204.1.7.0_x64` | Not specified | Unknown |
| `qfli-terminal-test` | `{41edc189-b7fb-411a-bfc0-205fbb9be0f7}` | `D:\MyNewProjects\qflistudio\.artifacts\terminal-runtime-test\ubuntu` | `ext4.vhdx` | 19,723,714,560 |
| `qfli-terminal-al3-clean` | `{7dbc0ce5-4ed2-4963-a126-327b8724161b}` | `D:\MyNewProjects\qflistudio\.artifacts\terminal-runtime-test\al3-clean` | `ext4.vhdx` | 13,742,637,056 |
| `qfli-terminal-al3-test` | `{bacb944f-b4e4-4670-9ecc-faf0997b892c}` | `D:\MyNewProjects\qflistudio\.artifacts\terminal-runtime-test\al3` | `ext4.vhdx` | 7,114,588,160 |
| `qfli-java-build` | `{f334d531-8048-482f-9ef2-41193fb63cb3}` | `D:\MyNewProjects\qfli_java\build\wsl\qfli-java-build` | `ext4.vhdx` | 84,817,215,488 |

Exact observed VHD paths and UTC last-write times:

- `D:\MyNewProjects\qflistudio\.artifacts\terminal-runtime-test\ubuntu\ext4.vhdx` — `2026-11-03T19:22:43.6384004Z`.
- `D:\MyNewProjects\qflistudio\.artifacts\terminal-runtime-test\al3-clean\ext4.vhdx` — `2026-11-02T08:43:10.6521993Z`.
- `D:\MyNewProjects\qflistudio\.artifacts\terminal-runtime-test\al3\ext4.vhdx` — `2026-11-02T08:43:10.6621961Z`.
- `D:\MyNewProjects\qfli_java\build\wsl\qfli-java-build\ext4.vhdx` — `2026-10-28T06:32:53.0749263Z`.

The three app-source VHD files total **40,580,939,776 bytes = 37.7939453125 GiB**. This is file length, not measured allocated disk space or guaranteed reclaimable capacity. Their internal contents were not examined.

Ubuntu's registered BasePath exists but its immediate directory listing is empty. The exact candidate `D:\WindowsExt\Subsystem\Ubuntu\Ubuntu_2204.1.7.0_x64\ext4.vhdx` does not exist. This does not prove the distribution has no data elsewhere; no search outside the registry location was performed. Leave Ubuntu unchanged. `qfli-java-build` belongs to another source repository and is outside this cleanup scope.

## Project-specific cleanup proposal — deferred, not executed

### Gate 1: preserve before considering removal

Lead must verify reviewed source and portable Trellis progress on GitHub, retain a recovery snapshot outside both checkouts, complete branch/worktree dispositions, verify cloud evidence, and compare final GitHub/source/target commits, trees, tracked content and clean statuses. No deletion should be used to force a clean working tree.

Preserve raw secrets/machine identities privately; do not publish them. Names/metadata only were inspected for artifact directories. In particular, `.artifacts/terminal-runtime-test/business.env` exists; its contents were not read and it is not a publication candidate.

### Gate 2: narrow cache/output candidates

The following exact existing source paths had zero tracked files at audit time. After Gate 1 and owner review, they are candidates for separately approved removal, not execution instructions:

- `D:/MyNewProjects/qflistudio/build/`
- `D:/MyNewProjects/qflistudio/.dart_tool/`
- `D:/MyNewProjects/qflistudio/.hvigor/`
- `D:/MyNewProjects/qflistudio/android/.gradle/`
- `D:/MyNewProjects/qflistudio/ohos/.hvigor/`
- `D:/MyNewProjects/qflistudio/ohos/oh_modules/`
- `D:/MyNewProjects/qflistudio/ohos/node_modules/`
- `D:/MyNewProjects/qflistudio/ohos/entry/build/`

`D:/MyNewProjects/qflistudio/ohos/entry/libs/` also has zero tracked files, but may contain needed native runtime payloads. Retain until its cloud artifact source, version and hashes are verified; an ignore rule does not prove reproducibility. Keep `.idea/` and ignored machine overrides until the owner decides whether preferences/recovery context are needed.

### Gate 3: staging copies are not all disposable evidence

The following exact children have no tracked files and may contain generated staging copies. The source/progress auditor must first compare and preserve unique source or research:

- `D:/MyNewProjects/qflistudio/.trellis/tasks/11-21-github-repo-clone/reports/staging/__pycache__/`
- `D:/MyNewProjects/qflistudio/.trellis/tasks/11-21-github-repo-clone/reports/staging/_app_index_validation/`
- `D:/MyNewProjects/qflistudio/.trellis/tasks/11-21-github-repo-clone/reports/staging/_index_validation/`
- `D:/MyNewProjects/qflistudio/.trellis/tasks/11-21-github-repo-clone/reports/staging/b/`
- `D:/MyNewProjects/qflistudio/.trellis/tasks/11-21-github-repo-clone/reports/staging/c/`
- `D:/MyNewProjects/qflistudio/.trellis/tasks/11-21-github-repo-clone/reports/staging/d/`

Do not delete or blanket-ignore their parent: `reports/staging/final-verification.json` is tracked. Preserve substantive briefs, manifests, final reports, task records and reviewed journals. Staging sizes/content equivalence were not measured by this auditor.

### Gate 4: retain old backups and WSL data

- Do not remove all `.artifacts/`. It mixes VHDs, root filesystems, old backups, source patches, diagnostic evidence and potential private data.
- Retain `.artifacts/repository-split-backup-20260929-071812/`, `repository-split-staging/`, `repository-split-baseline/`, `spec-index-baseline/`, `vibe-live-db/` and evidence until unique-content and recovery reviews are complete.
- Keep all three registered app-source VHD directories intact. GitHub source preservation does not preserve files inside these disks. A future retirement requires explicit separate owner approval, a private recovery/export plan and content disposition. This task excludes WSL unregister and physical VHD deletion.
- Retain rootfs/archive candidates until their owning runtime's cloud provenance is established: `.artifacts/terminal-ubuntu-root.tar.xz` (117,884,936 bytes), `.artifacts/terminal-runtime-test/al3-rootfs.tar` (182,662,144), `sandbox-v1.tar` (339,993,088), `sandbox-v2.tar` (2,546,997,760), `terminal-legacy-source.tar` (133,120).
- No deletion of linked worktrees, other repositories, Ubuntu, `qfli-java-build`, user/global SDK caches, registry keys or unrelated disks is proposed.
- Target requires no cleanup at baseline. Keep it free of local build/test/dependency outputs.

## Target cloud-only policy for the lead to publish

This task's approved rule supersedes conflicting old tasks, specs, README commands and future inherited agent instructions for this target:

1. Target is a source/progress checkout. Permit text edits, metadata/hash inspection, reviewed Git synchronization and Herdr coordination only within assigned scope.
2. Do not run local Flutter/Dart builds, run/debug sessions, tests, analyzers, code generation, verification/lint scripts, `pub get`, `pub upgrade`, npm/pnpm/yarn installs, `npm ci`, ohpm/hvigor, Gradle, CMake/Ninja, native compiler jobs or dependency/toolchain setup. `--no-pub` does not make local tests or analysis permissible.
3. Do not start WSL, containers, emulators, simulators, local test servers or device validation. Do not download or unpack installer/native-runtime artifacts into target.
4. Do not use old helper scripts to bypass the rule. All project build/test/analyze/dependency work belongs to approved cloud workflows with the coordinated app/core revision and artifact provenance recorded.
5. Do not silently enable editor auto-pub-get, IDE Sync or background validation. If a future change needs any prohibited action, escalate to the lead for explicit revised authorization instead.
6. Publish this policy in portable `AGENTS.md` and the repository-layout/workflow/task documentation. Reading this report does not itself install or enforce the rule in the unchanged target.

## Limits and follow-up

This is a baseline audit, not proof of completed migration. No GitHub server freshness, cloud job success, final branch consolidation, sibling contents, filesystem allocation or VHD internals were verified here. The lead owns coordinated path/CI changes, final synchronization, final hash/status comparison and the `w6D` handover. Re-run the allowed Git/metadata comparison after those changes; do not reuse these baseline hashes as final acceptance evidence.
