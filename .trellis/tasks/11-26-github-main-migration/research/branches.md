# Branch and linked-worktree migration audit

- Snapshot: 2026-11-26T18:53:57.347448+08:00. Auditor: `w65:p2`, `gpt-6.1-sol`.
- Baseline pinned to `github/main` = `c5f4bc3afe9c81ba488fd3f544d43c3dac061512`. No fetch.
- 72 refs: 3 unique, 2 patch-equivalent, 60 ancestor, 1 unrelated, 6 equal.
- 34 worktrees: 18 dirty; 1190 dirty path entries in this snapshot.
- Only this report and `branches.json` were written. No Git mutations, local builds/tests/analyzers/installations, WSL startup, or credential reads.
- Counts and staged/untracked classifications changed while the lead updated ignore rules and prepared preservation. Earlier main exposed over 8,800 dirty entries, including generated staging; the later policy exposes fewer paths. This is not proof of deletion. JSON contains every nonignored dirty path in the final snapshot.

## Concrete recommendation

1. Preserve exact uncommitted source and portable progress from main and every dirty worktree before integration. Lead owns backups. Do not use blanket add, checkout, reset, clean, or whole-file copies from old worktrees.
2. Use pinned/current GitHub main as the integration baseline. Preserve local `main` progress commits `05da08a` then `fd50419`; local main is 117 behind and 2 ahead. Its only path also changed upstream is `.trellis/spec/frontend/index.md`, which needs an additive resolution. Twenty-five other local progress paths are absent upstream.
3. Integrate unique `1052f3b` after reconciling installer workflow changes. It adds the public GitHub client ID environment value and passes it to Windows/Linux/macOS/iOS/Android/OHOS builds. Baseline workflow contains zero `QFLI_GITHUB_CLIENT_ID` occurrences. It also adds 44 spec lines. Do not replace the workflow with its older branch snapshot.
4. Port selected unique dirty remote-account behavior on top of current source, not its obsolete full files. It has 32 dirty files, of which 29 differ from baseline; 9 are new. Review discovery, sidecar, relay/tool streams, entitlements and companion packaging/CI as a coherent feature. Next review is pending. Preserve cloudterminal `scripts/check-remote-companion.mjs` (11,847 bytes) separately.
5. Review main OHOS background bridge/Huawei login changes, Android build configuration, new test/script source, docs, native Gradle wrappers and all portable Trellis progress. Reconcile with newer upstream files instead of overwriting them. Main and scratch share wrapper bytes; scratch Android configuration must be compared, not assumed unique. Do not resolve dependencies locally.
6. Do not merge `split/qfli-server` into app main with unrelated histories. Lead verified independent server main `d919a91` owns the split history. Document this before retaining the 77 embedded-server deletions; the split tree equals local old embedded tree, but GitHub app main has four newer embedded edits.
7. Do not merge ancestor refs, duplicate harness patch, pre-strip metadata history, or pre-artifact backup indiscriminately. Pre-artifact backup includes generated bundles and a 58 MB kernel_blob.bin; review portable progress only. Retain backup refs until preservation is independently verified.
8. Lead should publish reviewed content, run all required validation only in cloud CI, then synchronize the independent E-drive clone and compare final commit, tree and clean status before handover. This audit does not establish cloud test success or final source/target equivalence.

## Ref classification

### Unique / patch-equivalent / unrelated

| Ref | Tip | Baseline-only / ref-only commits | Disposition |
|---|---|---:|---|
| `refs/backup/pre-artifact-strip` | `d4e4df21165b` | 203 / 1 | 1 unique mixed progress/artifact commit; never merge wholesale |
| `refs/backup/pre-strip-trailers` | `60fffca07d7c` | 240 / 27 | 27 patch-equivalent commits; metadata-only rewritten history |
| `refs/heads/fix/github-client-id-20261124` | `1052f3b191f1` | 9 / 1 | 1 unique CI/spec fix; integrate selectively |
| `refs/heads/harness/pi-c` | `c1962e6b7988` | 53 / 1 | 1 patch-equivalent commit; duplicate of 8eafd65 |
| `refs/heads/main` | `fd5041973d95` | 117 / 2 | 2 unique progress commits; preserve |
| `refs/heads/split/qfli-server` | `f4d5bb7007f9` | 307 / 28 | Unrelated 28-commit split; independent server ownership |

### Already equal or ancestral

- equal, heads: `wsui/app-release`.
- equal, remotes: `cnb/HEAD`, `cnb/main`, `github/HEAD`, `github/main`.
- equal, tags: `v5.0.14`.
- ancestor, heads: `ci/app-installers`, `feat/large-screen-workbench`, `fix/ohos-platform-check`, `harness/integration`, `harness/pi-a`, `harness/pi-b`, `harness/pi-d`, `merge/app`, `mobile/integration`, `mobile/pi-a`, `mobile/pi-b`, `mobile/pi-c`, `mobile/pi-d`, `r5/integration`, `r5/pi1`, `r5/pi2`, `r5/pi3`, `r5/pi4`, `release/studio-git-ui-20261120`, `release/v5.0.5-preview.1`, `remote/cloudterminal-app`, `remote/remote-account-binding-studio`, `sync/progress`, `ui/integration`, `ui/pi-a`, `ui/pi-b`, `ui/pi-c`, `ui/pi-d`.
- ancestor, remotes: `gitcode/HEAD`, `gitcode/main`, `gitee/HEAD`, `gitee/main`, `github/ci/agents-tabs`, `github/ci/large-screen-workbench`, `github/ci/mobile-files`, `github/ci/mobile-final`, `github/feat/large-screen-workbench`, `gitlab/HEAD`, `gitlab/main`.
- ancestor, tags: `v5.0.1`, `v5.0.10`, `v5.0.11`, `v5.0.12`, `v5.0.13`, `v5.0.2`, `v5.0.3`, `v5.0.4`, `v5.0.5-git.1`, `v5.0.5-git.2`, `v5.0.5-git.3`, `v5.0.5-git.4`, `v5.0.5-git.5`, `v5.0.5-git.6`, `v5.0.5-git.7`, `v5.0.5-remote.1`, `v5.0.5-remote.2`, `v5.0.6`, `v5.0.7`, `v5.0.8`, `v5.0.9`.
- Both detached worktree HEADs (`c0ebf625`, `e018db96`) are ancestors too.

## Remote heads: no fetch, no prompts

Calls used credential helpers disabled, terminal prompts disabled, SSH batch mode with no private key/agent, 22-second outer timeout and HTTP low-speed limit. Every remote returned exactly one `main` branch; no errors were observed.

| Remote | Exit | HEAD/main | Relation to pinned baseline | Error detail |
|---|---:|---|---|---|
| cnb | 0 | `c5f4bc3afe9c81ba488fd3f544d43c3dac061512` | equal | none |
| gitcode | 0 | `b7272bc3a81482a9f84be08b2273d0b603ec9870` | ancestor, 75 commits behind | none |
| gitee | 0 | `b7272bc3a81482a9f84be08b2273d0b603ec9870` | ancestor, 75 commits behind | none |
| gitlab | 0 | `b7272bc3a81482a9f84be08b2273d0b603ec9870` | ancestor, 75 commits behind | none |

## Every linked worktree

Paths below are relative to `D:/MyNewProjects/`. `G` means generated plugin registrant/CMake files; JSON includes exact paths and normalized content comparison. A zero unique path count does not imply identical file content.

| Worktree | HEAD | Dirty tracked + new | Content requiring preservation/review |
|---|---|---:|---|
| `qflistudio` | `fd5041973d95` | 979 + 57 | Main source + portable Trellis progress; 77 embedded server deletions. See grouped paths below. |
| `_scratch/ci-sim/qflistudio` | `c0ebf625f51f` | 9 + 3 | 7 G; `android/.gitignore`, `android/app/build.gradle.kts`, `android/gradle/wrapper/gradle-wrapper.jar`, `android/gradlew`, `android/gradlew.bat` |
| `_wt/app-installers/qflistudio` | `4f8d97d1e040` | 0 + 0 | Clean; HEAD already ancestral/equal except client-ID unique branch. |
| `_wt/app-installers-compat/qflistudio` | `e018db960491` | 0 + 0 | Clean; HEAD already ancestral/equal except client-ID unique branch. |
| `_wt/cloudterminal-import/work/qflistudio` | `ea1da19950c5` | 7 + 1 | 7 G; `scripts/check-remote-companion.mjs` |
| `_wt/github-client-id-20261124/qflistudio` | `1052f3b191f1` | 0 + 0 | Clean; HEAD already ancestral/equal except client-ID unique branch. |
| `_wt/harness/integration/qflistudio` | `898af24c01b2` | 7 + 0 | 7 G; same old HEAD modulo EOL, or already baseline content; no unique behavior found. |
| `_wt/harness/pi-a/qflistudio` | `d31ad298afaf` | 0 + 0 | Clean; HEAD already ancestral/equal except client-ID unique branch. |
| `_wt/harness/pi-b/qflistudio` | `d31ad298afaf` | 0 + 0 | Clean; HEAD already ancestral/equal except client-ID unique branch. |
| `_wt/harness/pi-c/qflistudio` | `c1962e6b7988` | 7 + 0 | 7 G; same old HEAD modulo EOL, or already baseline content; no unique behavior found. |
| `_wt/harness/pi-d/qflistudio` | `d31ad298afaf` | 7 + 0 | 7 G; same old HEAD modulo EOL, or already baseline content; no unique behavior found. |
| `_wt/large-screen-workbench/qflistudio` | `7104c64ef545` | 10 + 0 | 10 G; same old HEAD modulo EOL, or already baseline content; no unique behavior found. |
| `_wt/merge/qflistudio` | `4a40543aa26c` | 0 + 0 | Clean; HEAD already ancestral/equal except client-ID unique branch. |
| `_wt/mobile/int/qflistudio` | `0830e392fcf5` | 7 + 0 | 7 G; same old HEAD modulo EOL, or already baseline content; no unique behavior found. |
| `_wt/mobile/pi-a/qflistudio` | `d05e3e7b7636` | 7 + 0 | 7 G; same old HEAD modulo EOL, or already baseline content; no unique behavior found. |
| `_wt/mobile/pi-b/qflistudio` | `bc84cf4e8ff8` | 0 + 0 | Clean; HEAD already ancestral/equal except client-ID unique branch. |
| `_wt/mobile/pi-c/qflistudio` | `898af24c01b2` | 0 + 0 | Clean; HEAD already ancestral/equal except client-ID unique branch. |
| `_wt/mobile/pi-d/qflistudio` | `8977b12d878e` | 0 + 0 | Clean; HEAD already ancestral/equal except client-ID unique branch. |
| `_wt/ohos-guard/qflistudio` | `c88ade2e5076` | 0 + 0 | Clean; HEAD already ancestral/equal except client-ID unique branch. |
| `_wt/release-v5.0.5/qflistudio` | `6d1b96d71187` | 0 + 0 | Clean; HEAD already ancestral/equal except client-ID unique branch. |
| `_wt/remote-account-binding/studio` | `6d1b96d71187` | 23 + 9 | 32 source files: 29 differ from baseline, 3 already baseline; see exact list below. |
| `_wt/round5/int/qflistudio` | `b7272bc3a814` | 0 + 0 | Clean; HEAD already ancestral/equal except client-ID unique branch. |
| `_wt/round5/pi1/qflistudio` | `d39dcac51033` | 7 + 0 | 7 G; same old HEAD modulo EOL, or already baseline content; no unique behavior found. |
| `_wt/round5/pi2/qflistudio` | `d39dcac51033` | 7 + 0 | 7 G; same old HEAD modulo EOL, or already baseline content; no unique behavior found. |
| `_wt/round5/pi3/qflistudio` | `d39dcac51033` | 0 + 0 | Clean; HEAD already ancestral/equal except client-ID unique branch. |
| `_wt/round5/pi4/qflistudio` | `d39dcac51033` | 7 + 0 | 7 G; same old HEAD modulo EOL, or already baseline content; no unique behavior found. |
| `_wt/studio-git-integration/qflistudio` | `d31ad298afaf` | 0 + 0 | Clean; HEAD already ancestral/equal except client-ID unique branch. |
| `_wt/sync/qflistudio` | `d39dcac51033` | 0 + 0 | Clean; HEAD already ancestral/equal except client-ID unique branch. |
| `_wt/ui-a/qflistudio` | `d26cffcf282c` | 7 + 0 | 7 G; same old HEAD modulo EOL, or already baseline content; no unique behavior found. |
| `_wt/ui-b/qflistudio` | `ffe4f7168547` | 7 + 0 | 7 G; same old HEAD modulo EOL, or already baseline content; no unique behavior found. |
| `_wt/ui-c/qflistudio` | `d26cffcf282c` | 7 + 0 | 7 G; same old HEAD modulo EOL, or already baseline content; no unique behavior found. |
| `_wt/ui-d/qflistudio` | `d26cffcf282c` | 8 + 0 | 7 G; `pubspec.lock` |
| `_wt/ui-int/qflistudio` | `d26cffcf282c` | 7 + 0 | 7 G; same old HEAD modulo EOL, or already baseline content; no unique behavior found. |
| `_wt/wsui/app/qflistudio` | `c5f4bc3afe9c` | 0 + 0 | Clean; HEAD already ancestral/equal except client-ID unique branch. |

### Main portable progress groups

- `.agents/skills/trellis-before-dev`: 1 dirty paths.
- `.agents/skills/trellis-brainstorm`: 1 dirty paths.
- `.agents/skills/trellis-break-loop`: 1 dirty paths.
- `.agents/skills/trellis-channel`: 6 dirty paths.
- `.agents/skills/trellis-check`: 1 dirty paths.
- `.agents/skills/trellis-meta`: 24 dirty paths.
- `.agents/skills/trellis-session-insight`: 3 dirty paths.
- `.agents/skills/trellis-spec-bootstrap`: 5 dirty paths.
- `.agents/skills/trellis-update-spec`: 1 dirty paths.
- `.trellis/.gitignore`: 1 dirty paths.
- `.trellis/.version`: 1 dirty paths.
- `.trellis/agents/check.md`: 1 dirty paths.
- `.trellis/agents/implement.md`: 1 dirty paths.
- `.trellis/config.yaml`: 1 dirty paths.
- `.trellis/scripts/__init__.py`: 1 dirty paths.
- `.trellis/scripts/add_session.py`: 1 dirty paths.
- `.trellis/scripts/common`: 21 dirty paths.
- `.trellis/scripts/get_context.py`: 1 dirty paths.
- `.trellis/scripts/get_developer.py`: 1 dirty paths.
- `.trellis/scripts/hooks`: 1 dirty paths.
- `.trellis/scripts/init_developer.py`: 1 dirty paths.
- `.trellis/scripts/task.py`: 1 dirty paths.
- `.trellis/spec/backend`: 12 dirty paths.
- `.trellis/spec/frontend`: 23 dirty paths.
- `.trellis/spec/guides`: 3 dirty paths.
- `.trellis/tasks/00-bootstrap-guidelines`: 2 dirty paths.
- `.trellis/tasks/11-01-ohos-app-interop`: 22 dirty paths.
- `.trellis/tasks/11-02-compliance-2026-11`: 1 dirty paths.
- `.trellis/tasks/11-02-fix-test-suites`: 1 dirty paths.
- `.trellis/tasks/11-02-w3a-client-shell-login`: 1 dirty paths.
- `.trellis/tasks/11-12-agents-workbench`: 67 dirty paths.
- `.trellis/tasks/11-15-agent-chat-usability`: 20 dirty paths.
- `.trellis/tasks/11-16-home-fab-tabs-search`: 6 dirty paths.
- `.trellis/tasks/11-16-home-tutorial-tools-ui`: 13 dirty paths.
- `.trellis/tasks/11-16-tools-netrix-batch2`: 6 dirty paths.
- `.trellis/tasks/11-16-tools-netrix-framework`: 6 dirty paths.
- `.trellis/tasks/11-16-tutorial-samples-merge`: 6 dirty paths.
- `.trellis/tasks/11-18-app-installer-ci`: 16 dirty paths.
- `.trellis/tasks/11-19-agent-thinking-stream`: 6 dirty paths.
- `.trellis/tasks/11-19-editor-sora-interactions`: 4 dirty paths.
- `.trellis/tasks/11-19-membership-token-plans`: 4 dirty paths.
- `.trellis/tasks/11-20-cloudterminal-import`: 76 dirty paths.
- `.trellis/tasks/11-21-github-repo-clone`: 9 dirty paths.
- `.trellis/tasks/11-21-remote-account-binding`: 30 dirty paths.
- `.trellis/tasks/11-22-agent-context-safeguards`: 9 dirty paths.
- `.trellis/tasks/11-22-harness-hub`: 35 dirty paths.
- `.trellis/tasks/11-23-device-sync`: 6 dirty paths.
- `.trellis/tasks/11-23-external-folders`: 6 dirty paths.
- `.trellis/tasks/11-23-home-agents-tab`: 9 dirty paths.
- `.trellis/tasks/11-23-mobile-files-agents`: 116 dirty paths.
- `.trellis/tasks/11-23-share-target`: 6 dirty paths.
- `.trellis/tasks/11-24-large-screen-workbench`: 31 dirty paths.
- `.trellis/tasks/11-24-ohos-runtime-guide`: 7 dirty paths.
- `.trellis/tasks/11-25-workbench-ui-cleanup`: 6 dirty paths.
- `.trellis/tasks/11-26-github-main-migration`: 10 dirty paths.
- `.trellis/tasks/archive`: 277 dirty paths.
- `.trellis/workflow.md`: 1 dirty paths.
- `.trellis/workspace/index.md`: 1 dirty paths.
- `.trellis/workspace/lichengyu`: 2 dirty paths.
- `AGENTS.md`: 1 dirty paths.

### Main nonprogress source groups

- `.cnb.yml`: 1 dirty paths.
- `.gitignore`: 1 dirty paths.
- `QFLIStudio+算法公示内容.docx`: 1 dirty paths.
- `android/.gitignore`: 1 dirty paths.
- `android/app`: 1 dirty paths.
- `android/gradle`: 1 dirty paths.
- `android/gradlew`: 1 dirty paths.
- `android/gradlew.bat`: 1 dirty paths.
- `azurekiln-qfli-server/.cnb.yml`: 1 dirty paths.
- `azurekiln-qfli-server/.dockerignore`: 1 dirty paths.
- `azurekiln-qfli-server/.env.example`: 1 dirty paths.
- `azurekiln-qfli-server/.gitignore`: 1 dirty paths.
- `azurekiln-qfli-server/Dockerfile`: 1 dirty paths.
- `azurekiln-qfli-server/README.md`: 1 dirty paths.
- `azurekiln-qfli-server/deployment`: 1 dirty paths.
- `azurekiln-qfli-server/docker-compose.build.yaml`: 1 dirty paths.
- `azurekiln-qfli-server/docker-compose.yaml`: 1 dirty paths.
- `azurekiln-qfli-server/gateway-extension`: 2 dirty paths.
- `azurekiln-qfli-server/package-lock.json`: 1 dirty paths.
- `azurekiln-qfli-server/package.json`: 1 dirty paths.
- `azurekiln-qfli-server/scripts`: 3 dirty paths.
- `azurekiln-qfli-server/src`: 41 dirty paths.
- `azurekiln-qfli-server/test`: 19 dirty paths.
- `azurekiln-qfli-server/vendor`: 1 dirty paths.
- `docs/compliance`: 1 dirty paths.
- `docs/login-ios-files-investigation-20261123.md`: 1 dirty paths.
- `docs/previews`: 3 dirty paths.
- `lib/main.dart`: 1 dirty paths.
- `ohos/build-profile.json5`: 1 dirty paths.
- `ohos/entry`: 5 dirty paths.
- `pubspec.lock`: 1 dirty paths.
- `scripts/test-ohos-background-bridge.cjs`: 1 dirty paths.
- `scripts/test-ohos-huawei-login.cjs`: 1 dirty paths.
- `test/harness_remote_host_test.dart`: 1 dirty paths.
- `tool/agent_workbench_device.md`: 1 dirty paths.
- `公示内容模板 (2).docx`: 1 dirty paths.

### Remote-account dirty paths

Branch HEAD `6d1b96d` is already ancestral, but these changes are not committed. Three shared files already equal baseline after CRLF normalization: `crypto.ts`, `log.ts`, `protocol-account.ts`. Their other older-file differences must not be copied back.

- `.github/workflows/app-installers.yml`: different; port behavior selectively.
- `companion/remote_agent/README.md`: different; port behavior selectively.
- `companion/remote_agent/relay-core.json`: different; port behavior selectively.
- `companion/remote_agent/scripts/sync-relay.ts`: different; port behavior selectively.
- `companion/remote_agent/src/agent/link.ts`: different; port behavior selectively.
- `companion/remote_agent/src/agent/main.ts`: different; port behavior selectively.
- `companion/remote_agent/src/agent/sdk.ts`: different; port behavior selectively.
- `companion/remote_agent/src/agent/sidecar.ts`: different; port behavior selectively.
- `companion/remote_agent/src/agent/tool-streams.ts`: different; port behavior selectively.
- `companion/remote_agent/src/relay/relay.ts`: different; port behavior selectively.
- `companion/remote_agent/src/shared/crypto.ts`: already baseline; no port.
- `companion/remote_agent/src/shared/log.ts`: already baseline; no port.
- `companion/remote_agent/src/shared/protocol-account.ts`: already baseline; no port.
- `companion/remote_agent/src/shared/relay-protocol.ts`: different; port behavior selectively.
- `companion/remote_agent/start.cmd`: different; port behavior selectively.
- `companion/remote_agent/start.sh`: different; port behavior selectively.
- `companion/remote_agent/test/relay-core-sync.test.ts`: different; port behavior selectively.
- `lib/main.dart`: different; port behavior selectively.
- `lib/studio_tools_tab.dart`: different; port behavior selectively.
- `macos/Runner/DebugProfile.entitlements`: different; port behavior selectively.
- `macos/Runner/Release.entitlements`: different; port behavior selectively.
- `pubspec.lock`: different; port behavior selectively.
- `tool/ci/package_linux.sh`: different; port behavior selectively.
- `companion/remote_agent/src/agent/desktop-discovery.ts`: new; preserve and review.
- `companion/remote_agent/src/agent/sidecar-port-file.ts`: new; preserve and review.
- `companion/remote_agent/test/desktop-discovery.test.ts`: new; preserve and review.
- `companion/remote_agent/test/sidecar-port-file.test.ts`: new; preserve and review.
- `companion/tools/README.md`: new; preserve and review.
- `companion/tools/package_companion.ps1`: new; preserve and review.
- `companion/tools/verify_companion_bundle.mjs`: new; preserve and review.
- `companion/tools/verify_companion_bundle.test.mjs`: new; preserve and review.
- `tool/ci/stage_desktop_companion.ps1`: new; preserve and review.

## Important evidence / blockers

- Dirty file preservation is the main loss risk; ancestor branches do not cover their worktrees.
- Main progress commits are absent from GitHub and must survive integration.
- Main source is dirty; a direct pull/merge in place can overwrite or conflict with source and progress. No merge was attempted.
- The remote-account branch and main client-ID branch both touch installer CI. Integration order and feature-level resolution matter.
- `refs/backup/pre-artifact-strip` has 240 changed files, 191,985 insertions and 103 deletions. It contains progress plus generated assets/builds. Unique patch classification does not mean the whole commit is publishable.
- Git patch equivalence ignores commit metadata and does not prove every old tree is equal to current baseline.
- Generated registrant-only dirtiness in older worktrees is old HEAD/EOL content. Large-screen registrants already equal baseline. `ui/pi-d` also has a distinct old `pubspec.lock`; review dependency intent, do not bulk-copy.
- E-drive path is an independent repository, not a linked D-drive worktree: common dir `.git`, clean `main` at `7104c64ef545` (2 baseline commits behind), remote name `origin`. Remote URLs/credentials were not read.
- No credential files were opened. No status enumeration of ignored caches or private runtime directories was performed.
- Lead reports independent server GitHub main `d919a91` contains split tip. This is attributed evidence, not independently repeated here.

## Unique committed diff evidence

### `05da08ac71a0` docs(task): record GitHub and cloud feature integration

21 files changed, 1788 insertions(+)

- `A	.trellis/spec/frontend/cloud-project-cache.md`
- `M	.trellis/spec/frontend/index.md`
- `A	.trellis/tasks/11-21-github-repo-clone/check.jsonl`
- `A	.trellis/tasks/11-21-github-repo-clone/design.md`
- `A	.trellis/tasks/11-21-github-repo-clone/implement.jsonl`
- `A	.trellis/tasks/11-21-github-repo-clone/implement.md`
- `A	.trellis/tasks/11-21-github-repo-clone/prd.md`
- `A	.trellis/tasks/11-21-github-repo-clone/reports/closeout.md`
- `A	.trellis/tasks/11-21-github-repo-clone/reports/commit-ledger.md`
- `A	.trellis/tasks/11-21-github-repo-clone/reports/contracts-a.md`
- `A	.trellis/tasks/11-21-github-repo-clone/reports/contracts-b.md`
- `A	.trellis/tasks/11-21-github-repo-clone/reports/contracts-c.md`
- `A	.trellis/tasks/11-21-github-repo-clone/reports/contracts-d.md`
- `A	.trellis/tasks/11-21-github-repo-clone/reports/native-a.md`
- `A	.trellis/tasks/11-21-github-repo-clone/reports/pi-a-core.md`
- `A	.trellis/tasks/11-21-github-repo-clone/reports/pi-a.md`
- `A	.trellis/tasks/11-21-github-repo-clone/reports/pi-b.md`
- `A	.trellis/tasks/11-21-github-repo-clone/reports/pi-c.md`
- `A	.trellis/tasks/11-21-github-repo-clone/reports/pi-d.md`
- `A	.trellis/tasks/11-21-github-repo-clone/reports/staging/final-verification.json`
- `A	.trellis/tasks/11-21-github-repo-clone/task.json`

### `fd5041973d95` docs(task): record tools column preference implementation

5 files changed, 100 insertions(+)

- `A	.trellis/tasks/11-22-tools-card-columns/check.jsonl`
- `A	.trellis/tasks/11-22-tools-card-columns/closeout.md`
- `A	.trellis/tasks/11-22-tools-card-columns/implement.jsonl`
- `A	.trellis/tasks/11-22-tools-card-columns/prd.md`
- `A	.trellis/tasks/11-22-tools-card-columns/task.json`

### `1052f3b191f1` fix(ci): inject GitHub client ID into installer builds

2 files changed, 60 insertions(+), 7 deletions(-)

- `M	.github/workflows/app-installers.yml`
- `M	.trellis/spec/frontend/repository-layout.md`

### `d4e4df21165b` chore(task): record the active Trellis tasks

240 files changed, 191985 insertions(+), 103 deletions(-)

Mixed task-progress additions and generated bundle/staging snapshots. Full changed-path evidence is in JSON; do not merge wholesale.

## Reproduction (read-only)

- `git for-each-ref` for heads/remotes/tags/backup refs.
- `git merge-base --is-ancestor <tip> <pinned-base>` and `git rev-list --left-right --count <base>...<tip>`.
- `git cherry <base> <tip>` for nonancestral patch equivalence.
- `git worktree list --porcelain` and non-locking `git status --porcelain=v1 -z --untracked-files=all` in all 34 worktrees.
- Scoped `git diff/show/ls-tree/rev-parse` plus LF-normalized ordinary source comparisons; no index refresh.
- Noninteractive `git ls-remote --symref <remote> HEAD refs/heads/*` only.

Complete machine-readable evidence is in `branches.json`.

## Follow-up: remote-account dirty-content integration review

Reviewed against worktree HEAD `6d1b96d7118740f71e5dadf393cc8bd58238b6af` and pinned app `github/main` `c5f4bc3afe9c81ba488fd3f544d43c3dac061512`. This was source inspection only. No application, commit, build, test, analyzer or dependency resolution was run. Lead owns exact-file backups.

### Decision

Preserve all 32 exact dirty files in the lead's backup. Integrate selected behavior, not old file snapshots. Twenty-nine files differ from current app main: 20 existing files and 9 new files. Three shared files already match main after CRLF normalization and need no port.

**Do not release this worktree wholesale.** App/core API dependencies are unpublished at the pinned core revision. The relay copy has draft provenance. The UI and entitlement snapshots would revert newer product behavior. Desktop packaging and security need the cloud checks listed below.

### File-by-file disposition

Paths in this table are relative to `_wt/remote-account-binding/studio`.

| File | Unique behavior / risk | Safe disposition |
|---|---|---|
| `.github/workflows/app-installers.yml` | Resolves a shared core SHA once, adds macOS companion verification, relay-provenance gates, portable-bundle regressions and desktop companion staging. Also contains old `APP_VERSION=5.0.5`, mutable `CORE_REF=remote/remote-account-binding-core`, old release rules and lacks newer native-Git/build changes. Dirty versus current is +116/-389 lines, not a safe replacement. | Port only dependency-resolution, verification and staging hunks into current CI. Keep current release/version/native-runtime contracts and client-ID fix. Pin the owner's published core SHA. |
| `companion/remote_agent/README.md` | Documents JSON attach handshake, session discovery/opening and console pairing. | Preserve with implementation. Fix example `ABCD-1234`: actual pair codes are eight digits. Do not publish live tokens. |
| `companion/remote_agent/relay-core.json` | Records `commit: null`, old `base_commit`, per-file hashes and working-tree digest. This is explicitly a draft, not a published source revision. | Preserve backup. Replace with clean independently published relay provenance before a release. Never invent a commit for these bytes. |
| `companion/remote_agent/scripts/sync-relay.ts` | Separates clean/draft provenance, checks all mirrored hashes, can check a local manifest without a sibling checkout, requires explicit dirty acceptance. | Preserve as a coherent tooling change with its tests. Release path must use `--require-clean`. |
| `companion/remote_agent/src/agent/link.ts` | Separates connection URL from phone-facing pairing URL; adds optional platform metadata. | Port additive fields/getters/hello change. Wire platform at real call sites if the device-list feature is required. |
| `companion/remote_agent/src/agent/main.ts` | Accepts attach-file/console flags, prints shared-encoder pairing links using the issuing relay's phone-facing URL. | Port these hunks. Do not treat `allowPositionals` as accepting unknown named flags: parser remains `strict: true`. |
| `companion/remote_agent/src/agent/sdk.ts` | Desktop Claude history paging: 100 items/page, at most 100 pages; phone remains limited to 30. | Port helper and shared mapping. Verify pagination against the pinned SDK in cloud. |
| `companion/remote_agent/src/agent/sidecar.ts` | Authenticated attach-file mode, no pre-auth snapshots/events, 5-second deadline, discovery/open/input requests, runtime/device snapshot and truthful unknown paired-client count. | Preserve coherent port with new helpers and matching core-side client. Fix/review caveats below before calling feature complete. |
| `companion/remote_agent/src/agent/tool-streams.ts` | Binds pre-resolved descriptors only after provider success; reads SDK history, reads/resumes Codex by control capability, sends input through Codex bridge. | Port with discovery, SDK, sidecar and cloud coverage. Recheck stream updates and cross-provider ID handling. |
| `companion/remote_agent/src/relay/relay.ts` | Revocation fences around asynchronous auth; closes account/device/legacy clients; blocks legacy-secret bypass for account-managed devices; exposes authenticated name/platform metadata. | Preserve behavior in the independently owned relay first, then synchronize its five mirrored files and clean manifest. Do not edit just the copied file. |
| `companion/remote_agent/src/shared/crypto.ts` | No normalized-content change versus HEAD or main. | No integration needed. |
| `companion/remote_agent/src/shared/log.ts` | No normalized-content change versus HEAD or main. | No integration needed. |
| `companion/remote_agent/src/shared/protocol-account.ts` | No normalized-content change versus HEAD or main. | No integration needed. |
| `companion/remote_agent/src/shared/relay-protocol.ts` | Optional `AgentHello.platform`. | Synchronize with relay owner and manifest. Keep old-client compatibility. |
| `companion/remote_agent/start.cmd` | Adds `--console-pairing`. | Preserve after CLI flag support lands. Do not change source-launcher install behavior during this audit. |
| `companion/remote_agent/start.sh` | Adds `--console-pairing`. | Same as Windows launcher. |
| `companion/remote_agent/test/relay-core-sync.test.ts` | Covers clean/draft metadata, digest binding and source-not-HEAD detection. | Preserve source. Execute only in cloud. |
| `lib/main.dart` | Only new intent is `RemoteAccountScope` around the existing app. Whole dirty file reverts 5.0.14 to 5.0.5, removes share intake, `deviceSyncEnabled`, harness registration and `studioAppServices`. Dirty versus current is +5/-120 lines. | Keep current main. Add only a compatible account-scope wrapper after core owner publishes the API. Preserve navigator, startup/share and harness wiring. |
| `lib/studio_tools_tab.dart` | Adds local-pairing entry and account sign-in hook, but resurrects standalone remote-computer navigation and removes the agreed editor Agents redirect. | Keep current Agents route and services. Place pairing/account behavior in the current settings/device surface under product-owner agreement. Do not restore obsolete card layout. |
| `macos/Runner/DebugProfile.entitlements` | Old dirty version has user-selected read-only; current main has read-write plus app-scoped bookmarks. | Keep current main. Do not downgrade access/bookmarks. Read-write already covers reading an attach file selected by the user. |
| `macos/Runner/Release.entitlements` | Same downgrade risk. | Keep current main and sandbox. |
| `pubspec.lock` | Adds `qr` 3.0.2 and `qr_flutter` 4.1.0 against old base; dirty versus current also removes 73 lines of newer dependencies. | Preserve dependency intent only. Core owner must publish matching dependency declarations; update the lock only through approved cloud resolution. Never copy old lock wholesale. |
| `tool/ci/package_linux.sh` | Preserves executable modes under bundled companion. Old snapshot also removes current `libsecret-1-0` dependency. | Port only eight-line executable-mode block. Keep current package dependencies. |
| `companion/remote_agent/src/agent/desktop-discovery.ts` (new) | Lists real Herdr panes, Claude history across configured roots and paged Codex projects/threads. Separates open/read-only/input capability and reports per-provider failures. | Preserve with sidecar/stream support. Fix provider options/identity caveats below. |
| `companion/remote_agent/src/agent/sidecar-port-file.ts` (new) | Publishes via private temporary file + hard link without replacing destination; deletes only a matching regular-file port/token document. | Preserve. Add stale-file recovery and Windows ACL/cloud validation before promising reliable/private attach behavior. |
| `companion/remote_agent/test/desktop-discovery.test.ts` (new) | Fixtures cover real-source mapping, roots/deduplication, empty results, independent failure and read-only Codex rows. | Preserve tests. They have not been run here. |
| `companion/remote_agent/test/sidecar-port-file.test.ts` (new) | Parsing, owner-only deletion intent, changed-owner retention, existing destination and symlink refusal. | Preserve tests. They do not establish Windows ACLs, crash recovery or race-free deletion. |
| `companion/tools/README.md` (new) | Packaging/architecture rationale, but its macOS section still says `sidecar.port`, port-only and never a token. This contradicts actual JSON/token implementation. | Preserve backup; correct documentation to `sidecar.json` with authenticated first frame before adoption. |
| `companion/tools/package_companion.ps1` (new) | Target Node download/checksum, target-runtime production dependencies, manifest/token contract, platform launchers, binary verifier and machine-state exclusions. | Preserve as cloud-only packaging source. Review architecture/toolchain, ACLs, stale-file lifecycle and recursive secret exclusion. Do not execute locally. |
| `companion/tools/verify_companion_bundle.mjs` (new) | Inspects PE/ELF/Mach-O headers, Node/native-addon architecture, required files, launchers, credential-path exclusions and attach contract. | Preserve with tests. It verifies manifest presence, not clean relay provenance or actual Windows ACLs. Current fat Mach-O handling reads first slice only. |
| `companion/tools/verify_companion_bundle.test.mjs` (new) | Header/architecture, attach-contract, provenance-file presence and forbidden-state regression fixtures. | Preserve; cloud-only execution. |
| `tool/ci/stage_desktop_companion.ps1` (new) | Guards staging inside `build`, stages installed Windows/Linux companion and a separate ad-hoc-signed macOS app. | Preserve. Integrate into current jobs only after packager review and required core/relay publications. |

### Factual integration blockers and static review findings

1. **Core API dependency is not in the pinned release.** Core object `476a30acee21dc486ee2849dd8064a7be665e4d5` exists locally. Its tree has neither `lib/remote_control/account/account_scope.dart` nor `lib/remote_control/desktop/desktop_companion_entry.dart` (`git cat-file -e` failed for both). These APIs exist only in the inspected sibling working tree. Additional read-only checks found them absent from local core `main` at `573d1b6e` and the remote-account branch HEAD `72c0b095` too. An app-only port of the imports will not compile against the current pin. Independent core owner must review/publish first. Do not reset the pin to an old/moving integration branch.
2. **Relay source provenance is draft.** Manifest has `commit: null` and base `841cc86e`. The proposed tag CI intentionally rejects it with `--require-clean`. Publish reviewed relay source through its owner, synchronize the exact five files, then record immutable provenance. This is distinct from the independently owned qfli-server split.
3. **Bulk-file UI and entitlement copies would lose accepted features.** Keep current version, editor Agents redirect, share inbox, device sync, harness registration, macOS bookmarks/read-write, libsecret dependency and newer native-Git/installer CI. Port narrowly around them.
4. **Discovery ignores configured Herdr controls.** `desktop-discovery.ts:83` constructs a new default `HerdrBridge`, while sidecar's core honors `--no-herdr` and `--herdr-path`. Discovery can enumerate Herdr despite the disabled flag or fail to use a configured binary. Pass the configured provider/options into discovery before treating it as equivalent to the existing core contract.
5. **Session identity needs a consistency check.** Discovery deduplicates by `kind:id`, but bound IDs, `open_session` lookup (`sidecar.ts:446`) and ToolStreams' connected map (`tool-streams.ts:121`) use plain ID. Provider-ID collisions can select/mark the wrong source. Thread open and later input also rely on cached capabilities; CodexBridge rechecks control on send, which must be retained.
6. **Codex output is currently a one-shot snapshot.** The port renders `read/resume` turns and echoes submitted input. Inspected sidecar has no `core.addEmitter`/`core.setEmitter` to forward later `codex_changed` into sidecar clients. Existing core sends those events to relay links. Do not promise desktop live Codex streaming until a cloud regression proves the refresh/forwarding path. Also distinguish resumable-but-not-yet-directly-controllable threads from permanently read-only ones if the UX requires resuming them.
7. **Attach security/lifecycle is partial.** Token gating applies only with `--port-file`; legacy socket mode remains unauthenticated for compatibility. File creation requests POSIX 0600/0700 but has no explicit Windows ACL implementation; private Windows permissions are unverified. Hard-link publication refuses an existing stale JSON file, and sidecar logs and continues, so SIGKILL/power-loss leftovers can prevent later publication. Recovery must not overwrite a live owner's document. Ownership cleanup does a separate check then `rmSync`, so its race claim needs review.
8. **Metadata is not fully wired.** `link.ts` accepts `platform`, but inspected CLI/sidecar `new RelayLink` calls do not pass it. Sidecar's snapshot platform does not populate relay hello metadata. Add real platform at call sites if required; do not infer that the device platform feature is complete.
9. **Docs/test coverage do not prove delivery.** Packaging README's port-only text contradicts implementation. Verifier checks required provenance-file presence but not clean source revision. Some security/IPC behavior is in the import-time sidecar rather than the two new helper tests. No test result is claimed from this audit.

### Safe content integration order

1. Finish exact-file backups and immutable reference ledger.
2. Consolidate reviewed current app main plus the two unique progress commits and public GitHub client-ID CI fix. Preserve current product/UI/native-runtime contracts.
3. Obtain independent core and relay owners' published, reviewed commits. Keep server ownership/removal separate.
4. Port Node-agent pairing/history/discovery/attach/stream changes as a coherent feature, fixing or explicitly tracking findings above. Leave newer `core.ts`/`protocol.ts` device information, Git metadata and filesystem-sync additions intact.
5. Add reviewed packaging tools, narrowly port Linux executable modes and current-workflow staging/verification. Do not roll back versions, tags, native-Git setup or release provenance.
6. Add account/local-pairing UI only against the new core API and current product navigation. Keep current entitlement and lockfile baselines; cloud-only resolution/checks.
7. Run cloud type-check/unit/IPC/auth/revocation/provenance tests, native architecture checks and installed companion smoke tests on Windows/Linux/macOS. Preserve current six-platform installer/test requirements. Validate unauthenticated-socket rejection, stale attach files, duplicate instances, Windows ACLs, `--no-herdr`, custom Herdr path and live Codex update behavior.
8. Publish only after actual cloud evidence. Then synchronize E-drive main, compare commit/tree/tracked content/clean status and hand over through herdr.

### Cloudterminal checker preservation

Preserve `D:/MyNewProjects/_wt/cloudterminal-import/work/qflistudio/scripts/check-remote-companion.mjs` exactly in lead's backup. Its source is unique (11,847 bytes, LF-normalized SHA-256 `1b28850c28782d67e3bfaa29b32ac0b8c9e694947e8c0d53a079489b916703ed` recorded in JSON). Do not turn it on unchanged: it requires historical `remote/cloudterminal-core` / `remote/cloudterminal-app` pins, old OHOS version/commit, an older dedicated workflow and clean-only relay manifest shape. Its no-secrets check walks local directories rather than Git's tracked set. Preserve provenance, then adapt intentional invariants to current CI in a separate reviewed change.

No source content was applied. No commits or Git changes were made by this worker.
