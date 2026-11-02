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
- [ ] Commit only the two reports and isolated client task files.
- [ ] Append Result and print commits, tests, gaps, and required user actions.

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
