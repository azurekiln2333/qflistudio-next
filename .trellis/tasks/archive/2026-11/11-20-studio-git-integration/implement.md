# Execution plan

The user requested completed Trellis planning followed directly by Pi work.
Existing authorization covers implementation and later reviewed GitHub release.
Do not insert another approval round.

## Ownership

| Worker | Writable ownership | Required report |
| --- | --- | --- |
| Pi A | Plugin lib/, native/, tests and example integration fixtures, API spec | reports/pi-a-plugin.md; early pi-a-api.md |
| Pi B | Core lib/git/, lib/services/git_service.dart, backend tests and spec | reports/pi-b-backend.md |
| Pi C | Core Git UI/controller, Home clone entry/coordinator, editor owner/dirty guards, UI/navigation tests | reports/pi-c-ui.md |
| Pi D | App/core/plugin manifests and lockfiles, .github/, tool/ci/, plugin artifact tooling and release specs | reports/pi-d-cloud.md |

Use isolated sibling worktrees from research/baselines.md. Do not stage, commit,
push or tag while workers share Git indexes. Root reviews and commits explicit
paths. Each worker writes its own report. Do not spawn additional workers or
change global model settings. Read specs before implementation.

## Order

1. Pi A publishes the additional API/symbol list and implements plugin operations.
2. Pi B creates the frozen contract immediately, then adapters and fixtures.
3. Pi C consumes design.md immediately and implements real UI/navigation.
4. Pi D prepares cloud checks and dependency wiring. Do not invent final SHAs.
5. Root reconciles reports and reviews the complete cross-layer diff.
6. Push plugin source to GitHub and run native, Dart and mobile cloud jobs.
7. Import matching artifacts with export/provenance checks, then pin plugin in core.
8. Push core and run targeted Git tests plus the complete core suite in cloud.
9. Pin core in app, push app, and tag a fresh Git preview to GitHub only.
10. Observe all required jobs and inspect native/CA/provenance in installers.
11. Deliver download evidence and distinguish cloud CI from user device acceptance.

Scheduling update (2026-11-21): run the Core source suite against an interim
plugin source commit while native platform builds run. This finds independent
Core failures sooner. Final release still requires importing all matching native
artifacts, pinning the plugin artifact commit, and rerunning the Core cloud gate
before pinning Core in the App. The interim pin is not a release pin.

Candidate validation update (2026-11-21): after the final native artifact pin,
App branch builds may validate a candidate Core revision in parallel with its
standalone complete suite. This avoids serializing independent installer builds.
The tagged App workflow repeats the complete pinned Core suite and all installer
gates before publishing. No failing or pending candidate is a release.

Final scheduling update (2026-11-21 05:17 CST): Core's full suite and the App's
complete installer matrix passed at `75bd342` / `d94bd45`. The plugin's older
Flutter iOS launch remains stalled. The App workflow now adds an unskippable
runtime integration gate using its production Flutter SDK and exact plugin
artifact commit. A candidate tag may trigger that full release workflow while
the branch check runs. Publication still requires every check, including this
runtime gate. Preserve a failed candidate tag; use a new tag for later fixes.

## Validation

Local allowed: reading, format, static analysis with available dependencies,
syntax parsing, git diff --check and Chinese documentation lint. Do not run local
tests, builds, emulators, VMs, WSL, containers, services, adb or hdc. Defer anything
requiring native building/execution to cloud CI.

```text
python scripts/ste-lint-zh.py .trellis/tasks/11-20-studio-git-integration/prd.md
python .trellis/scripts/task.py validate .trellis/tasks/11-20-studio-git-integration
git -C <owned-isolated-worktree> diff --check
```

Cloud only: native C smoke/fixtures, plugin Dart and FFI tests, Android example,
iOS simulator integration, OHOS cross-build/export checks, targeted backend/UI/
navigation tests, complete core suite and installer/assistant matrix. Write tests
and jobs but never execute tests locally. No disabled or continue-on-error gate.

Real Git scenarios use disposable CI repositories: unborn commit, per-file stage
and unstage including deletion, combined status, Unicode/rename, binary/large
diff, bounded history, safe branch switch, remote configuration, fetch/push and
deliberate merge conflicts. Authenticated HTTPS push requires a disposable remote
and scoped CI credential. Never push test fixtures to user repositories. Missing
fixtures are explicit validation gaps; mocks do not prove transport support.

UI scenarios: enabled mobile entry, desktop/cloud preservation, foreign active
owner, stale async completion, dirty buffer refusal, clone collision/failure,
cancel/dispose, credential redaction, narrow layout and keyboard-inset dialogs.

Release gates require new native libraries in APK/HAP/IPA payloads, packaged CA,
recorded dependency commits, and successful required cloud jobs. Code-only changes,
old artifacts and placeholder UI do not establish completion.

## Risks and follow-up

Fixture correction (2026-11-21): Pi A identified and Root confirmed that the
mobile integration fixture passes a bare local clone path to an API that
requires a URL. Correct only the fixture to use `Uri.directory(...).toString()`
for clone and its disposable bare remote. Keep assertions and production URL
validation intact. Add bounded phase diagnostics, commit the corrected fixture,
then repin Plugin/Core/App. Native C sources and locked artifacts remain the
same. Preserve candidate `.1`; use `.2` for the corrected cloud release.

Native rebuilds are the critical path. Pi A/D report exact source/API versions.
Preserve prior preview and existing worktrees. Agent session-branch automation is
a separate follow-up. User physical-device acceptance remains separate from CI.
