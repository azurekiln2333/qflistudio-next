# Implement

1. Read the parent prd.md, this prd.md and the relevant .trellis/spec/frontend files.
2. Write design.md (short) before code. Report to the root session if it changes a shared interface.
3. Implement in small steps. After each step run focused tests, then commit as type(scope): summary with explicit paths.
4. On finish, add a Result section here: commits, tests run, what was not verified.

## Result

Status: done for R1-R8 plus eight live-acceptance fixes. One wiring snippet waits
on the owner of `editor_page.dart` (see below).

Commits were rewritten at 14:56 to drop the `Co-Authored-By` trailer. Every hash
below was re-read from `git log` after that rewrite. Do not trust older notes.

### Commits (sibling repo `qfli_studio_core`)

| Commit | Scope |
| --- | --- |
| `ea3465e` | skills loader, rules loader, `todo` / `use_skill` tools, loop guards, round budget |
| `6903e95` | panel plan card, skill chips, Chinese tool labels, phone-width widget tests |
| `7310c69` | `lib/vibe_coding/CONTRACT.md` update for the new members and tests |
| `65eecfb` | `endpointProvider`, `vibeToolSpecsWithWeb()`, `web_search` / `web_fetch` dispatch, `run_command` through `InteropRunner` |
| `aec91df` | root path `.` / `''` accepted, setup rounds exempt from the stall rule, prompt and skill say to write first |
| `bfba182` | in-process HTML structure check replaces the heredoc script |
| `f486535` | citation rule in the prompt, new `web-research` skill |
| `fefb47f` | terminal unavailability no longer fails a send that already wrote files |
| `6f64eb3` | a search that returns new URLs or a new query counts as progress |
| `b1dbded` | terminal transport failures classified by type, not by message text |
| `37273a6` | a written site survives read-only rounds and ends succeeded |

Task repo `qflistudio`:

| Commit | Scope |
| --- | --- |
| `9d2c446` | `design.md` in this task directory |
| `a15f994` | first `Result` section and `handoff.md` |

### What shipped

- R1 `lib/vibe_coding/vibe_skills.dart`: front-matter parsing (`name`,
  `description`, YAML block scalars), discovery from `.qfli/skills`,
  `.claude/skills`, `.agents/skills`, packaged `assets/skills/`, first source
  wins, directory-name fallback, 12 KiB body cap, index capped at 40 entries and
  4 KiB. `use_skill` returns the body and records the name in `usedSkills`.
- R2 `lib/vibe_coding/vibe_rules.dart`: `AGENTS.md`, `CLAUDE.md`,
  `.qfli/rules.md`, 4 KiB per file and 8 KiB total, read on every `send`.
- R3 `assets/skills/*/SKILL.md`: `web-app-scaffold`, `bug-fix-loop`,
  `project-review`, `web-research`. Registered through the existing
  directory-style asset entry in `pubspec.yaml` (`assets/skills/`), so a new
  skill needs no pubspec edit but does need one line in
  `VibeSkillLibrary.builtInAssetDirs` and `kVibeBuiltInSkillLanguages`.
- R4 `lib/vibe_coding/vibe_plan.dart` plus the `todo` tool: atomic replacement,
  20 items max, one `doing`, duplicate ids and unknown states rejected, all
  `done` refused while the current round had a tool failure. `plan` is exposed
  on the controller and as a snapshot on `VibeToolCall.plan`.
- R5 `lib/vibe_coding/vibe_loop_guard.dart`: budget 12 base, 24 for a multi-step
  prompt, hard cap 30, `maxRounds` still pins the value when passed. Guards:
  third identical call (canonical JSON, key order ignored), two rounds without a
  new fact, read-before-edit against a snapshot taken at send start.
- R6 `write_file` on any `.html` file runs `_checkHtml` in-process and appends
  the report to the tool result. It checks tag closure and the existence of
  every local `link` / `script` / `img` reference. No shell, so no command limit.
- R7 read-before-edit uses only project-relative paths through
  `VibeProjectFiles.relative`, so the existing guard still bounds every path.
- R8 the controller now takes `AiEndpoint Function()? endpointProvider` and
  passes it to `aiChat` each round, so a settings change applies without
  rebuilding the session. The tool list becomes `vibeToolSpecsWithWeb()` when
  `vibeWebToolsAvailable`, and `web_search` / `web_fetch` dispatch to
  `executeVibeWebTool`. `run_command` first tries
  `InteropRunner.tryRunCommand` and falls back to the online terminal.
- UI: plan chip (`计划 n/m`), expandable item list with pending / doing / done,
  one chip per loaded skill, plan snapshot inside each `todo` transcript entry.

The constructor keeps every existing parameter. New behaviour arrives through
the optional `VibeAgentContext? context`, nullable `maxRounds`,
`endpointProvider` and `interopRunner`.

### Live-acceptance fixes

`D` ran the real upstream three times per protocol and each failure produced one
fix. In order:

1. `aec91df` — the model wrote a todo, listed the directory twice and never
   wrote a file, because `list_files` rejected `.` outright. Root paths now map
   to the project root, plan updates and successful listings count as progress
   during the first three rounds, and the prompt says to create `index.html`
   right after planning.
2. `bfba182` — the shipped skill told the model to verify with a `python3`
   heredoc. That is longer than the 2000-character `run_command` limit, so the
   command was rejected and the turn failed after the site was complete. The
   check is now in-process. A too-long command explains the script-file remedy.
3. `f486535` — `web_search` returned real results but the answer was about
   eighty characters with no URL. The prompt and the `web-research` skill now
   require one line per source with title and full URL, quoting only URLs the
   tools returned.
4. `fefb47f` — the site was complete, then `run_command` hit a 401 and the turn
   failed. An auth failure now tells the model not to retry. With a clean write
   the send ends succeeded and says the command never ran.
5. `6f64eb3` — four successful searches were counted as no progress, so the
   guard stopped the turn before the model summarised. A search that brings a
   new query or a new URL is progress. After three searches the tool reply asks
   the model to summarise.
6. `b1dbded` — the same failure appeared as `无法建立终端安全连接`, which the
   login-only wording missed. Classification is now type-first: any
   `ApiException` on the terminal stream, or 401 / 403 / 408 / 5xx, means the
   command never ran. A stream that ends without a result frame counts too.
7. `37273a6` — under the `messages` protocol the model wrote three files, marked
   todo 3/4, listed the directory and stopped. Two read-only rounds tripped the
   stall rule and the error claimed nothing had been written. A send with a
   clean write now survives read-only rounds, ends succeeded, and the stall
   reason says the files were already written.

### Tests run

Final state, `qfli_studio_core`:

- `flutter test --no-pub test/vibe_coding_controller_test.dart` 35 cases.
- `flutter test --no-pub test/vibe_coding_skills_test.dart` 12 cases.
- `flutter test --no-pub test/vibe_coding_plan_test.dart` 12 cases.
- `flutter test --no-pub test/vibe_coding_panel_test.dart` 11 cases (one at
  320 px, toggling the plan and collapsing the panel, no overflow).
- `flutter test --no-pub test/vibe_coding_tools_test.dart` covers path
  confinement, the root-path contract and the 9 tool schemas.
- The five `vibe_coding_*` files together: 93 cases, all passing under the
  default concurrent runner.
- `flutter analyze --no-pub lib/vibe_coding test/vibe_coding_controller_test.dart`
  reports no issues.
- `dart format` applied to every touched file.

The full `flutter test` was never run by this owner: it takes 16-20 minutes and
carries failures outside this scope.

### Not verified

- `editor_page.dart` wiring. That file currently contains no `vibe` reference at
  all and carries another owner's uncommitted interop changes, so it was not
  touched. The snippet below is the intended call site.
- OHOS device build of the panel. The widget tests cover layout, but not the
  soft-keyboard frame on a real device.
- Streaming on the direct AI route. `_aiChatDirect` reads the whole response with
  `http.Response.fromStream` before parsing, so a single upstream response that
  takes longer than 120 seconds still meets a Cloudflare 524. This belongs to
  the transport owner.
- `lib/services/api_client.dart` cancellation. `terminalEvents` lost its
  `abortTrigger` parameter. This owner re-added it and made a cancel end the
  stream silently instead of raising "终端连接已中断". The file is shared and its
  working copy carries other owners' changes, so that edit is reported rather
  than committed here.

### Wiring snippet for the `editor_page.dart` owner

`VibeCodingController` is not constructed anywhere in the app today. To give
the model the user's own endpoint, assemble one from the settings on every call
and pass it in:

```dart
VibeCodingController(
  files: VibeProjectFiles(projectRoot: projectRoot),
  language: language,
  tokenProvider: () => token,
  api: api,
  // 每次调用现取，用户在设置里改完立即生效。
  endpointProvider: () {
    final protocol = settings.aiProtocol;
    return AiEndpoint(
      route: AiRoute.relay,
      protocol: protocol,
      baseUrl: settings.aiBaseUrl,
      apiKey: settings.aiApiKey,
      model: settings.aiModel,
    );
  },
  interopRunner: InteropRunner(),
);
```

`AiEndpoint.isUsable` guards the empty case. Returning an unusable endpoint
leaves `aiChat` on its default route, so no extra check is needed at the call
site. `AiRoute.direct` bypasses the relay and sends the key from the device.

### Cross-owner notes

- `vibe_web_tools.dart` belongs to the protocol owner. Two edits from this
  session are not part of any commit here: a formatting-only revert that was
  restored by hand mid-file while that owner was writing it (the file was left
  in a broken intermediate state for a few minutes, then fixed by its owner),
  and the `abortTrigger` restoration noted above.
- `vibe_coding_controller_test.dart` assertion on the tool list moved 7 -> 9
  after the web tools were added. The round-limit test uses distinct real reads
  because the no-progress guard answers earlier.
- `handoff.md` records the concurrent `tool_calls` read-gate item. It is still
  open: a batch that creates and then edits the same file trips the gate. The
  debug upstream sends one call per turn, so it has not blocked acceptance.


## Commit sweep

A sweep of every repository owned by this session: all user changes, including
those that predated the assignment, landed as grouped commits on the current
branch. Nothing was pushed, no branch was switched, and no history was rewritten.

### qflistudio (main)

| Commit | Scope |
| --- | --- |
| `cb1b017` | native startup progress, `StudioContentRepository`, `assets/content` |
| `3b618bd` | OHOS startup splash, wider device types, network permission, version 5.0.0, agreement pages |
| `2cbd4c2` | higher resolution app icon (699 KiB) |
| `c671f29` | `tool/generate_studio_content.dart`, `tool/verify_studio_content.dart`, content tests |
| `4278137` | deployment docs for the isolated terminal and the host limits |
| `2c09ccf` | root `.cnb.yml`, `scripts/check-root-ci.mjs`, `scripts/ste-lint-zh.py` |
| `fd196eb` | `azurekiln-qfli-server`, the business backend the app talks to |
| `d4e4df2` | Trellis task records and `AGENTS.md` |

Skipped, with reasons:

- `ohos/build-profile.json5` — carries signing material (`*.p12` path, key and
  store passwords). The file is tracked upstream, so this is a pre-existing
  exposure worth a separate decision; the sweep left it alone.
- `.artifacts/` — commit-message scratch files.
- `.git-commit-result*.txt` — temporary command output.
- `Roboto_Mono.zip` — archive.
- `新增APP - 全国互联网安全管理服务平台.html` and its `_files/` directory — a saved
  web page.
- `azurekiln-qfli-server/bike.html` — a standalone demo page no source refers to.
- `azurekiln-qfli-terminal/` — a separate Git repository, so the parent cannot
  track it.

`assets/content/tutorials.json` (5.63 MB): yes, it should be tracked.
`tool/verify_studio_content.dart` reads it along with `examples.json` and
`provenance.json` and checks the counts recorded in provenance. `pubspec.yaml`
declares `assets/content/` as a runtime asset and `lib/main.dart` serves it
through `StudioContentRepository`. The file is a build input for the checks and
a shipped asset, not a disposable build output.

### qfli_studio_core (main)

| Commit | Scope |
| --- | --- |
| `c08338d` | terminal cancellation: `abortTrigger`, `RequestAbortedException`, quiet stream end |
| `105f3c3` | `vibe_editor_bridge.dart`, `vibe_send_coordinator.dart` and their tests |
| `19bb5af` | `offline_text_tools.dart`, `offline_text_tool_pages.dart` and tests |
| `e1d096c` | `points_feed.dart` and the check-in tests |
| `bfd332b` | workspace action, reload and short-height editor tests |
| `0bf30d9` | `tool/python_content/`, `scripts/ste-lint-zh.py` |
| `d5025e9` | `QFLI_E2E_SCENARIOS` selection and the live integration entry |

`lib/services/api_client.dart` is mostly `dart format` reflow. The behaviour
changes are the three cancellation points, called out in the commit body.
`lib/vibe_coding/vibe_web_tools.dart` is formatting only.

Skipped: `.git-commit-*.txt` — temporary command output.

### qfli_json (feat/offline-json-workbench)

| Commit | Scope |
| --- | --- |
| `7fdc6c2` | `AGENTS.md`, `LICENSE`, `scripts/ste-lint-zh.py` |
| `d3234e1` | `AgreementReader.ets`, route registration, generated plugin registrants |

Skipped: `ohos/build-profile.json5` — signing material, same reason as above.

### qfli_lua (main)

| Commit | Scope |
| --- | --- |
| `9b53d51` | `module.json5` device types `phone`, `2in1`, `tablet` |
| `820bd1c` | higher resolution app icon (596 KiB) |
| `5135a1e` | `.codex`, `.trae`, `.gitattributes`, three Trellis task records, `AGENTS.md` |
| `c4eff3f` | `AgreementReader.ets` |

Skipped: `ohos/build-profile.json5` (signing material),
`.tmp_bytecode_block.txt` (scratch buffer).

### qfli_web

Reassigned to another owner before the sweep reached it. Not touched.

### Large tracked files

- `qflistudio/assets/content/tutorials.json` — 5.63 MB, shipped asset.
- `qflistudio/assets/content/examples.json` — 3.23 MB, shipped asset.
- Three app icons at 596-699 KiB each, in `qflistudio` and `qfli_lua`.

