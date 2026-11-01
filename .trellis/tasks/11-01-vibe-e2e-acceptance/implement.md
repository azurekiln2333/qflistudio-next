# Implement

1. Read the parent prd.md, this prd.md and the relevant .trellis/spec/frontend files.
2. Write design.md (short) before code. Report to the root session if it changes a shared interface.
3. Implement in small steps. After each step run focused tests, then commit as type(scope): summary with explicit paths.
4. On finish, add a Result section here: commits, tests run, what was not verified.

## Result

Pi-D. Harness skeleton, spec drafts, docs, OHOS build gate.

### Commits

`qfli_studio_core` (`feat/vibe-e2e-acceptance`, merged without commit into
`main`; A, B and C had landed three commits on `main` in the meantime, so a
rebase or a merge commit was the only way to reach `main` without a push):

- `5d3e4bc` feat(vibe): add headless e2e acceptance harness skeleton
- `6d98570` docs(core): note the acceptance driver in the shared package README

`qflistudio` (`main`, normally committed):

- `7e89839` feat(vibe): add operator entry for vibe e2e acceptance
- `e742e54` docs(spec): record skills, protocol, interop and e2e contracts
- `75b32c7` docs(vibe): document the acceptance harness and its credential rules
- `0a57073` docs(spec): align the interop contract with the published code
- `b63da55` docs(spec): align the skills contract with the published loaders

`.trellis/spec/**` is ignored by `.gitignore` (the repository keeps those files
tracked), so the four spec files were added with an explicit `git add -f`. The
`be2c5bb` commit only carries the index edit for that reason.

### What was built

- `qfli_studio_core/tool/vibe_e2e.dart` — headless driver for
  `VibeCodingController`. Reads `QFLI_DEBUG_*` from the process environment,
  runs one prompt per scenario, records the real tool calls and exit codes, and
  writes a JSON report.
- `qfli_studio_core/tool/vibe_e2e_report.dart` — schema 1 report model,
  credential redaction, writer and reader.
- `qfli_studio_core/tool/vibe_e2e_scenarios.dart` — `static_site`,
  `python_fix_loop`, `web_search` plus the assertion helpers and the
  redaction guard.
- `qfli_studio_core/test/vibe_e2e_harness_test.dart` — 17 offline cases.
- `qflistudio/tool/verify_vibe_e2e.dart` — operator entry: environment check,
  `--dry-run`, `--env-file`, `--report` table, exit codes.
- `.trellis/spec/frontend/`: `vibe-e2e.md` (Active), `ai-protocols.md`,
  `interop.md`, `vibe-skills.md` (Draft), index rows and a Draft convention.
- `docs/vibe-acceptance.md` plus README entries in both repositories.

### Tests run

| Command | Result |
| --- | --- |
| `dart run tool/vibe_e2e.dart` (no env) | every scenario skipped with the missing-variable reason, report written |
| `flutter test --no-pub test/vibe_e2e_harness_test.dart` | 17/17 passed |
| `flutter test --no-pub --concurrency=1 test/vibe_coding_controller_test.dart test/vibe_coding_tools_test.dart test/vibe_coding_panel_test.dart test/vibe_e2e_harness_test.dart` (core) | 69/69 passed |
| `flutter test --no-pub` (core, full) | 6 failures, all in code owned by A and B: `vibe_coding_controller_test.dart` ×4 (round limit, repeated call, cancel/reset), `ai_settings_dialog_test.dart` ×2 (layout timeouts at 320 and 360 px) |
| `flutter analyze --no-pub lib` (core) | clean at the end |
| `flutter analyze --no-pub lib` (qflistudio) | clean |
| `flutter test --no-pub` (qflistudio) | `studio_home_release_test.dart` fails (lazy tutorial route timeout) and `test/vibe_coding_tools_test.dart` is an empty stray file owned by A; `studio_content_repository_test.dart` has two duplicate class definitions but passes in isolation |
| `dart run tool/verify_ohos_products.dart` | fails: 7 bundle names disagree with the product table (`com.azurekiln.qfli.java` vs `com.azurekiln.qfli.jvmx`, …). `qflistudio` and `qfli_python` pass. A and C own those manifests; this is a real blocker for the OHOS release naming, not a harness problem |
| `tool/build_hap.sh qflistudio` | BUILD SUCCESSFUL, `entry-default-unsigned.hap` 172,251,157 B, 08:12 |
| `tool/build_hap.sh qfli_java` | BUILD SUCCESSFUL, `entry-default-unsigned.hap` 227,501,232 B, 08:12. An earlier attempt at 07:41 failed while A was mid-edit inside `vibe_coding_controller.dart` / `vibe_skills.dart`, then passed after A landed |
| `dart run tool/verify_vibe_e2e.dart --dry-run` | environment table; the key is reported as a length only |

### Not verified

- **Live scenarios never ran.** R1's real outputs are still missing. Two blockers,
  both outside my ownership:
  1. `ApiClient.aiChat` still posts to `/api/ai/chat` and never calls
     `AiService.encodeRequest`. `AiService` exposes the protocol codecs, but no
     injectable debug endpoint reaches `VibeCodingController`. `ApiConfig.baseUrl`
     is a compile-time constant, so the harness records `skipped` with that
     reason. Needed from B: an endpoint/credential injection point or an
     `ApiClient` transport that speaks the debug upstream directly.
  2. `dart run` cannot load `qfli_studio_core`, which imports `dart:ui`. The
     driver needs either an SDK-side adapter or a run through the Flutter test
     runner. Until then `tool/vibe_e2e.dart` is runnable only under
     `flutter test`-style hosts.
- `web_search` / `web_fetch` are not in `vibeToolSpecs()` yet, so the search
  scenario skips; `vibeE2eHasSearchTools` is already wired.
- No OHOS hardware run. The interop `run` path (C) was not exercised on device.
- `qfli_java` and `qflistudio` HAPs are unsigned; signing config is unchanged.

### Cross-owner requests

- **B (`ai-protocols-websearch`)**: publish the callable debug endpoint (base
  URL + key + model + protocol) that `VibeCodingController` can use, and add
  `web_search` / `web_fetch` to `vibeToolSpecs()`. Then rerun
  `dart run tool/verify_vibe_e2e.dart --env-file <outside-repo path>`.
- **A (`vibe-agent-skills`)**: `test/vibe_coding_tools_test.dart` in
  `qflistudio/test/` is a 0-byte stray file that fails collection; the real copy
  lives in `qfli_studio_core/test/`. Delete the stray.
- **C (`ohos-app-interop`) + A**: `tool/verify_ohos_products.dart` fails on 7
  bundle names. Either the manifests or the product table must move before an
  OHOS release claim.

## Result 2 — live host moved under `flutter test`

Committed in `qfli_studio_core` as `8349ed6` (code) and `b3e43d2` (README), and
in `qflistudio` as `edfda67` (operator script, README, docs).

### What changed

- `tool/vibe_e2e_runner.dart` — the scenario runner and report assembly, shared
  by both hosts. It also holds a narrow `ApiClient` stand-in that only
  implements `aiChat` and refuses a relay endpoint.
- `tool/vibe_e2e_transport.dart` — direct debug-upstream client built on
  `AiService.encodeRequest`, `decodeReply` and `headers`, so the three protocols
  share one code path. Every error string is redacted before it can reach a
  report.
- `tool/vibe_e2e.dart` — CLI kept for a future SDK-side adapter.
- `test/vibe_live_e2e_test.dart` — live host. The whole file skips unless all
  three `QFLI_DEBUG_*` variables are present. With variables present it fails
  when every scenario skips, so an unreachable upstream cannot look like a pass.
  It also asserts the report on disk does not contain the key.
- `test/vibe_e2e_runner_test.dart` — offline checks of the runtime, the skip
  semantics and the redacted environment summary.
- `qflistudio/tool/verify_vibe_e2e.dart` now forwards to
  `flutter test --no-pub test/vibe_live_e2e_test.dart` with the parsed `--env-file`
  values in the child environment.

### Not verified yet — blocked on the shared package compiling

At 08:47 local time `flutter analyze --no-pub lib` in `qfli_studio_core` failed
with one error owned by B:

```
lib/vibe_coding/vibe_coding_controller.dart:824:13 - The named parameter
'abortTrigger' isn't defined - undefined_named_parameter
```

`ApiClient.terminalEvents` (uncommitted working tree, 08:37) lost the
`abortTrigger` parameter that the controller passes. `test/vibe_live_e2e_test.dart`
and `test/vibe_e2e_runner_test.dart` therefore cannot load yet. Both analyze
clean on their own; the failure is a single missing named parameter in B's file.
Re-run as soon as B restores it:

```
(cd qfli_studio_core && flutter test --no-pub test/vibe_e2e_runner_test.dart)
(cd qflistudio && dart run tool/verify_vibe_e2e.dart --env-file <outside-repo path>)
```

`test/vibe_live_integration_test.dart` (untracked, written 2026-10-28 06:22, the
`QFLI_VIBE_LIVE_ORIGIN` loopback variant) was left untouched.

## Result 3 — bundleName drift: 7 of 12 disagree (read-only investigation)

`dart run tool/verify_ohos_products.dart` fails on rustcore, goshift, jvmx,
webforge, forge, dartwing and sqlab. pyflow and the main app agree.

### Dates

| Side | Written | Commit |
| --- | --- | --- |
| Product table `tool/verify_ohos_products.dart` | 2026-09-22 17:29 | `3c2a405` |
| Pre-split manifests (`apps/qfli_*/ohos/AppScope/app.json5`) | 2026-09-22 04:44 | `cefe73f` |
| Split into sibling repositories | 2026-09-29 08:36 | `13c63a1` |
| Current drift | 2026-10-15 to 2026-10-17 | per-App `fix(ohos)` commits |

Not introduced today. The split happened 33 days ago:

- `qfli_c` — both `ohos` and Android became `com.azurekiln.qfli.forge` in
  `fae9550` (2026-09-22), the same short name the table expects.
- `qfli_java` — `ohos` and Android became `com.azurekiln.qfli.jvmx` in
  `bf1d66f` (2026-09-22), matching the table.
- The pre-split monorepo (`13c63a1^`) already had the `*.jvmx`, `*.forge`,
  `*.dartwing` short names in both `ohos` and Android.

### Which side is stale

**The `ohos` manifests are the stale side; the product table still holds the
intended names.** Evidence:

1. In every sibling repository the Android `applicationId` still uses the short
   product name (`com.azurekiln.qfli.jvmx`, `*.forge`, `*.dartwing`, `*.goshift`,
   `*.rustcore`, `*.webforge`, `*.sqlab`), while `ohos` uses the truncated one
   (`*.java`, `*.cpp`, `*.dart`, `*.go`, `*.rust`, `*.web`, `*.sql`). One product
   naming two bundle ids on two platforms is the drift, not the table.
2. The `ohos` values changed later, inside per-App `fix(ohos)` commits on
   2026-10-15 to 2026-10-17, for example `395f62f` in `qfli_java` which states it
   "preserve[s] the current bundle … and signing configuration". Those commits
   locked in the truncated name that was already in the tree.
3. The signed HAPs built on 2026-11-01 08:12 carry the truncated names
   (`com.azurekiln.qfli.java`), and `qfli_java/ohos/build-profile.json5` still
   references `D:/Keystore/Profile/jvmxRelease.p7b`, so the release keystore and
   the `ohos` bundle id already disagree inside that repository.

### Consequence for the release

Renaming the `ohos` manifests to the table's names changes the HarmonyOS bundle
id of seven apps. That invalidates their current signing material and any
AppGallery record keyed by bundle name. The decision belongs to the owners of
those manifests (A and C), not to this task. Until then the gate correctly
stays red.

One smaller inconsistency found on the way: `lib/interop/interop_targets.dart`
(C) now maps `java` to `com.azurekiln.qfli.java` and `python` to
`com.azurekiln.qfli.pyflow`. For Java that follows the manifest, which is the
stale side above, while `qfli_python` is the single product whose two platforms
agree. Interop launches by that table, so the Java entry will keep working only
while the manifest keeps the truncated name.
