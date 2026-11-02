# Client and consolidated acceptance execution

- [x] Read assignment, shared rules/contracts, and relevant project specifications.
- [x] Define report ownership and the read-only business-code boundary.
- [x] Snapshot revisions, dirty paths, source hashes, tools, and commit histories.
- [x] Run four projects' full tests and full analyze/lint with explicit timeouts.
- [x] Audit Conventional Commit subjects and attribution lines since Nov 2.
- [x] Trace client Huawei restrictions and exercise their existing widget tests.
- [x] Count Home-to-agreement taps in independent task-local widget tests.
- [x] Trace withdrawal and erasure behavior, including unavailable native support.
- [x] Verify AI reply/file labels, custom endpoint restrictions, and Bing removal.
- [x] Record physical-device item 10 as unverified with three-state replay steps.
- [x] Write client.md with methods, raw excerpts, verdicts, and evidence paths.
- [x] Consolidate twelve items from server.md, moderation.md, and client.md.
- [x] Run Chinese lint, evidence integrity, source-boundary, and diff checks.
- [x] Commit only the two reports and isolated client task files.
- [x] Append Result and print commits, tests, gaps, and required user actions.

Evidence stays under an isolated system temporary directory. Never read or emit
production credentials. Do not operate the locked device. Do not modify or commit
other workers' changes, task metadata, either sibling repository, or server.md.

## Execution evidence

- Evidence root:
  `D:/AppData/Local/Temp/qfli-client-acceptance-20261103-p7-xvt69sg9`.
- Node 24.15.0, Flutter 3.27.5-ohos-1.0.1, Dart 3.11.5.
- Main gate snapshots: core `6ac1442`, studio/server `20382e2`, moderation
  `6d6754c`. Supplement snapshot: studio/server `1a1d8df`. The intervening
  release-report commit did not change the hashed business sources.
- Core full tests: 1363 passed, 9 skipped. Full analyze: exit 1, 951 findings
  (448 errors, 31 warnings, 472 info). Build checkpoints account for 863,
  vendor for 77, tool for 11. No exclusion was added.
- Studio default tests: 8 passed. Root script tests: 28 passed. The separately
  discovered `tool/preview_test.dart` failed compilation at line 45 (`int` ID
  supplied to a `String` field). Full analyze: 2 errors, 2 info, exit 1.
- Server full tests: 153 passed, 1 MySQL skip. `npm run lint` failed because
  the manifest has no lint script. Separate syntax checking passed 60 files.
- Moderation service/SDK tests: 45 passed. CI tests: 7 passed. Lint passed
  31 JavaScript files. Every repository command had an outer timeout and none
  timed out. Flutter commands ran sequentially.
- Independent Home/Profile/Settings widgets: 4 passed at 360x800 and 600x1000.
  Both agreement destinations take 3 taps, with scrolling allowed. The empty
  user-agreement URL still displays the unpublished state. Native reading was
  captured through a host fixture, not claimed as physical-device evidence.
- Initial acceptance-fixture failures were fixed only in owned test files:
  reset the platform override inside the test, settle lazy-list scrolling,
  use `HttpOverrides.current`, and close the owned client before timer checks.
  Their earlier logs remain in the temporary evidence directory.
- The AI characterization widget passed by reproducing a compliance defect.
  With the real main profile, OHOS platform, and `allowCustomAiEndpoint=false`,
  the real AiPanel sent `POST /v1/chat/completions` to the test's loopback address.
  Its visible header said official forwarding. The reply had the AI label.
  No external AI endpoint, production token, or production credential was used.
- Existing compliance tests: 33 passed. Supported comment formats receive
  file headers. JSON/CSV/TXT/unknown formats remain unmarked. Withdrawal clears
  AuthStore data but the native host returns false and other personal caches
  are not removed by that branch. These limits are recorded, not fixed.
- Global source scan covered 339 core, 86 studio/native/script, 60 server and
  33 moderation files. Every `bing|web_search` match was inspected. No built-in
  Bing request was found. Legacy tool names, a retired QFLI API method, comments,
  negative tests and unrelated English substrings remain.
- Full commit bodies across `--all` refs since 2026-11-02T00:00:00+08:00:
  core 12, studio 66, server path subset 24, moderation 5. Zero Conventional
  Commit or attribution violations. The server audit runs from the parent Git
  root to avoid accidentally filtering a doubled relative path.
- Consolidation uses server's latest 86/86 regression and 69/69 pseudonym retest,
  plus moderation's 22-case independent acceptance. Earlier failures remain
  historical evidence. Production deployment, real gateway erasure, historical
  production identities and MySQL remain outside the proven local results.
- Release worker supplied final 5.0.1/5000001 signed HAP. Independent SHA256
  matched `788fe80a0dcea38d089a4e94212aa94d0b36a912930b5cc809dc2232616c1511`.
  Existing verification log contains `verify-app success`. This is artifact
  evidence, not an installation, AGC submission or device-smoke result.
- Locked device `192.168.68.207` was never connected to, queried or operated.
  Three-state replay instructions are in client.md and the consolidated record.
- Owned Dart probes analyze cleanly. Python AST checks pass. Chinese text lint
  and whitespace checks pass. `evidence-summary.json` preserves command results,
  source/audit snapshot counts and SHA256 values for the temporary raw evidence.

## Result

Status: acceptance execution and consolidation complete. Product acceptance is
not green. Business code, other acceptance reports and the locked device stayed
untouched. Only client-owned documents, probes and evidence index were committed.

### Commit

- `9fc31a6 docs(compliance): record client acceptance and consolidate results`.
  This contains client.md, the twelve-item consolidated record, the isolated
  plans, bounded runners, independent widget probes and evidence-summary.json.
- This Result is recorded in a separate documentation commit. Its actual hash
  is available from `git log -1 -- .trellis/tasks/11-02-acceptance/client/implement.md`
  and is printed with the main delivery hash in the terminal completion paragraph.

### Commands and outcomes

Run the Python entry points from the qflistudio Git root. Every repository gate
is bounded in the runner. The evidence index records individual commands,
timeouts, exit codes, durations and 38 raw-evidence file hashes.

```powershell
python -X utf8 -u .trellis/tasks/11-02-acceptance/client/bounded_checks.py
python -X utf8 -u .trellis/tasks/11-02-acceptance/client/supplemental_checks.py --evidence <evidenceRoot>
```

| Project or probe | Command | Actual result |
|---|---|---|
| core | `flutter test --no-pub --reporter expanded --timeout 2m` | 1363 pass, 9 skip |
| core | `flutter analyze --no-pub` | exit 1, 951 findings |
| studio | `flutter test --no-pub --reporter expanded --timeout 2m` | 8 pass |
| studio | `flutter test --no-pub tool/preview_test.dart --reporter expanded --timeout 1m` | exit 1, compilation failure |
| studio | `flutter analyze --no-pub` | exit 1, 2 errors and 2 info |
| studio scripts | `node --test --test-timeout=60000 "scripts/*.test.mjs" "scripts/compliance/*.test.mjs"` | 28 pass |
| server | `node --test --test-timeout=60000 "test/*.test.js"` | 153 pass, 1 MySQL skip |
| server | `npm run lint` | exit 1, missing script |
| server syntax | `node --check <each JS/CJS/MJS source>` | 60 files pass |
| moderation | `npm test` | 45 service/SDK tests pass |
| moderation CI | `node --test --test-timeout=60000 scripts/publish-ci.test.mjs` | 7 pass |
| moderation | `npm run lint` | 31 files pass |
| navigation widget | `flutter test --no-pub .trellis/tasks/11-02-acceptance/client/navigation_click_test.dart --reporter expanded --timeout 1m` | 4 pass, 3 taps each |
| AI transport widget | `flutter test --no-pub .trellis/tasks/11-02-acceptance/client/ai_transport_probe_test.dart --reporter expanded --timeout 1m` | 1 characterization pass, defect reproduced |
| compliance widgets/headers | auth_login_entry, settings_compliance and ai_file_header tests | 33 pass |
| owned probes | `dart analyze <the two owned Dart files>` | no issues |
| owned Python | standard-library AST parse of both runners | pass |
| owned text | `python -X utf8 scripts/ste-lint-zh.py <two reports and two plans>` | zero findings |
| source and evidence | before/after hashes, raw SHA256 index, explicit path review, `git diff --cached --check` | pass |

All executed gates finished within their outer timeouts. Full repository gates
are intentionally reported as failed where their raw command failed. Default
test successes do not include the preview failure or conditional skips.

### Remaining limits

- Item 3 client passes within widget coverage. Real Huawei authorization and
  the final HAP's actual device behavior still need independent physical checks.
- Item 8's entry/click budget passes but user-agreement content is unavailable.
  Withdrawal signs out and shows the system-settings fallback. Complete removal
  of personal caches and actual hosted withdrawal were not established.
- Item 9 fails because the legacy AiPanel transport still uses saved custom
  endpoints despite the official-only profile. JSON/CSV/TXT/unknown files lack
  file labels. The global Bing scan and AI reply label checks pass.
- Item 10 is unverified and explicitly needs Mate 60 portrait, Mate X5 folded
  and Mate X5 unfolded evidence. The report contains replay steps. No device
  command, installation, launch or screenshot was performed.
- Item 12 fails on the preview compilation, full analyze results and missing
  server lint command. Conditional skips, production deployment, real gateway
  erasure, historical production raw identities, long-term registration records
  and MySQL remain unverified. Implementation owners must handle the code gaps.
- The signed 5.0.1/5000001 artifact exists and its hash matches the release
  record. Remediating the new client gaps requires another build and retest
  before this artifact can be treated as accepted.

### User-only actions

- Publish the AGC-hosted user agreement and supply its HTTPS URL.
- Confirm the hosted privacy declaration, then submit the accepted AGC version.
- Unlock the device and explicitly notify the later physical-test task.
- Grant `qfli_account_erase` to the gateway client.
- Inject an independent random `QFLI_MODERATION_SUBJECT_SALT` of at least 16
  characters. Do not put its value in any acceptance evidence.
- Provide production/registry access, moderation remote repository, domestic
  hostname and certificate, separate app credentials, egress controls, a
  maintenance window, backups and dedicated acceptance accounts. Push and actual
  deployment remain outside this worker's authorized actions.

The consolidated record keeps separate deployment, physical-device and user
action lists. The completion paragraph reports both documentation commits and
the remaining product failures without presenting local evidence as deployment.
