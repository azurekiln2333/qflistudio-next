# Parallel clone release-path audit

Scope: read-only audit of `release/studio-git-ui-20261120` in the three assigned
worktrees. No product files changed; no tests, builds, app or services ran.

## Current cross-repo chain

1. **Plugin source → native artifacts:** `qfli_git/.github/workflows/native.yml`
   runs on pushes to `release/**`, `main`, `integration/**`, manual dispatch,
   and `native-v*` tags. `host-smoke` gates `dart-checks`, Android, OHOS and iOS
   builders. Platform jobs upload same-run artifacts named
   `qfli-git-{android,ohos,ios}-<source-sha>`. Collectors take
   `tool/ci/native_contract.json`; local importer requires full `--commit` and
   `--run`.
2. **Artifacts → plugin commit:** download the three artifacts from the same
   successful native workflow run and import them into a checkout of the exact
   source commit. The importer writes platform payloads and
   `native_libs.lock.json`; run `check_native_install.py` before committing the
   artifact update. The artifact commit is the commit Core must pin (not merely
   the source commit): it contains the native lock and payloads.
3. **Plugin artifact → Core:** `qfli_studio_core/pubspec.yaml` currently pins
   `qfli_git` to `53ad359159258706d4c242e70a2db0e1d075dabc`; its lock agrees.
   Replace both with the full artifact commit. Push Core; `core-check.yml`
   triggers on every branch push, resolves packages, analyzes, then runs the
   complete Flutter suite.
4. **Core → App:** App `CORE_REF` currently pins `123602be34ab6fa9725bb93f0d3bc27a630c7b44`.
   Change it to the verified Core commit before pushing App. App `v*` tags
   trigger `app-installers.yml`; `publish-preview` accepts
   `v5.0.5-git.*` and hard-needs `verify-flutter` and
   `git-ios-integration`, plus all installer jobs. `verify-flutter` runs the
   complete Core and App `flutter test --no-pub` suites on the OHOS Flutter
   matrix. `git-ios-integration` separately checks out the plugin SHA resolved
   by App setup, validates its native lock, and runs the existing example flow
   on the production Flutter resolved by `resolve-flutter`.

## Exact cloud artifact import and pin commands

Run in the `qfli_git` release worktree after committing/pushing the complete
API 3 source (including its native progress callback) and thread-safe mbedTLS
build configuration. Do not proceed with the current API 2 source commit.

```bash
PLUGIN_SOURCE_SHA="$(git rev-parse HEAD)"
git push origin release/studio-git-ui-20261120
# After the release-branch native.yml run starts:
gh run list --repo azurekiln2333/qflistudio-git --workflow native.yml \
  --branch release/studio-git-ui-20261120 --limit 5
PLUGIN_RUN_ID=<successful-native-workflow-run-id>
gh run watch "$PLUGIN_RUN_ID" --repo azurekiln2333/qflistudio-git --exit-status

gh run download "$PLUGIN_RUN_ID" --repo azurekiln2333/qflistudio-git \
  --name "qfli-git-android-$PLUGIN_SOURCE_SHA" \
  --dir native/build/ci/artifacts/android
gh run download "$PLUGIN_RUN_ID" --repo azurekiln2333/qflistudio-git \
  --name "qfli-git-ohos-$PLUGIN_SOURCE_SHA" \
  --dir native/build/ci/artifacts/ohos
gh run download "$PLUGIN_RUN_ID" --repo azurekiln2333/qflistudio-git \
  --name "qfli-git-ios-$PLUGIN_SOURCE_SHA" \
  --dir native/build/ci/artifacts/ios

python3 tool/import_artifacts.py \
  --repo-root . \
  --contract tool/ci/native_contract.json \
  --artifact native/build/ci/artifacts/android \
  --artifact native/build/ci/artifacts/ohos \
  --artifact native/build/ci/artifacts/ios \
  --commit "$PLUGIN_SOURCE_SHA" \
  --run "https://github.com/azurekiln2333/qflistudio-git/actions/runs/$PLUGIN_RUN_ID"
python3 tool/ci/check_native_install.py \
  --repo-root . --contract tool/ci/native_contract.json

git add android/src/main/jniLibs ohos/libs ios/Frameworks/qfli_git.xcframework \
  native_libs.lock.json
git commit -m "build: import API 3 cloud native artifacts"
git push origin release/studio-git-ui-20261120
PLUGIN_ARTIFACT_SHA="$(git rev-parse HEAD)"
```

Then set `qfli_git.git.ref` in Core `pubspec.yaml` **and** its committed
`pubspec.lock` to `$PLUGIN_ARTIFACT_SHA`, push Core, and wait for the
`core-check.yml` run to pass. Set App `CORE_REF` to that Core commit, push App,
then push the next `v5.0.5-git.*` tag. The tag run must show API 3 in all package
`BUILD_INFO.txt` files and pass both the complete OHOS-Flutter suites and the
production-Flutter iOS plugin integration gate before publication.

## Which jobs cover the new tests

- **Core tests:** `core-check.yml` runs the full `flutter test --no-pub` suite
  after `flutter pub get`. App `verify-flutter` also runs the full suite for
  both `qfli_studio_core` and `qflistudio`; tests are discovered by the runner,
  not by an explicit file list. This includes the new overlapping-clone
  service test, progress parser tests, progress widget tests and native
  progress-bridge tests once the changed files are committed. The CLI backend
  integration group is guarded by `Platform.environment['CI'] == 'true'` and
  uses disposable local Git repositories; it should execute on GitHub Actions.
- **Plugin tests:** `native.yml` `dart-checks` runs plugin format, analyze and
  the full plugin `flutter test` suite against the host library downloaded from
  that same run. The example is analyzed and its widget suite runs there. The
  `example-ios` job builds the example and executes
  `integration_test/flow_test.dart` on a simulator; it exercises one local clone,
  branch/merge/push flow, not simultaneous clones. `example-android` builds the
  APK but runs no integration tests.
- **Release tag gate:** App `publish-preview` requires the Core/App suite and
  the separate production-Flutter iOS plugin flow. That iOS flow is a single
  existing plugin example test; it does not replace the new Core unit/widget
  tests. Plugin release packaging itself depends only on Android/OHOS/iOS build
  jobs, not `dart-checks`.

## Concrete blocker

The source state is not yet aligned for cloud execution:

- The plugin checkout and Core pin/lock remain API 2 (`53ad359`); the plugin
  contract, C header and Dart binding all declare API 2. App staging and
  `publish-preview` have been changed to require API 3.
- Core's current uncommitted `_PluginGitApi` passes `onProgress` to
  `plugin.GitRepository.clone`, but the pinned plugin implementation has no
  `onProgress` parameter or progress API. Core analysis/build will fail against
  the current pin until the plugin source implements and publishes that API.
- The plugin's only current clone integration flow is single-clone; there are
  no plugin progress-specific tests in the checked-in suite. Add/commit the API
  contract and focused progress callback tests along with the implementation.
- The mbedTLS CMake/threading changes are uncommitted in the plugin worktree.
  The host/mobile cloud builds are the first validation of that configuration.
  Existing checked-in native lock artifacts are API 2; native artifact import
  and the resulting artifact commit must precede the Core pin and final App tag.

Initial `native-lock` may fail against the old lock after the contract is bumped;
that job is independent of host/platform builders, so its failure does not stop
same-run artifact upload. The release source run is not final verification until
the imported API 3 lock is checked and the resulting plugin artifact commit is
pinned through Core and App.

No code, commits, pushes, tags, tests or builds were performed for this audit.
