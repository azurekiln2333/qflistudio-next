# Vibe Coding End-to-End Acceptance

## 1. Scope / Trigger

Apply this contract when adding a Vibe Coding acceptance scenario, changing the
report schema, touching the debug credential flow, or claiming that a real-model
flow works. It covers `qfli_studio_core/tool/vibe_e2e*.dart`,
`qfli_studio_core/test/vibe_e2e_harness_test.dart` and
`qflistudio/tool/verify_vibe_e2e.dart`.

Status: `Draft`. The harness skeleton, the report schema and the redaction rules
are active. Live scenario runs wait for the injectable debug upstream adapter and
the search tools from the `ai-protocols-websearch` task.

## 2. Signatures

```dart
class VibeE2eCredentials {
  static VibeE2eCredentials? fromEnvironment([Map<String, String>? environment]);
  Map<String, Object> redacted({required String protocol});
}

class VibeE2eScenario {
  final String key;            // static_site | python_fix_loop | web_search
  final String prompt;
  final VibeE2eExecution execution;   // terminal | files
  final bool requiresSearchTools;
}

class VibeE2eReport {
  final Map<String, Object?> environment;   // redacted only
  final List<VibeE2eScenarioResult> scenarios;
  VibeE2eStatus get status;                 // passed | failed | skipped
}
```

Commands:

```
cd qfli_studio_core && dart run tool/vibe_e2e.dart [--scenario <key>] [--out <path>]
cd qflistudio && dart run tool/verify_vibe_e2e.dart [--dry-run] [--report <path>] [--env-file <path>]
```

## 3. Contracts

- Credentials come from `QFLI_DEBUG_BASE_URL`, `QFLI_DEBUG_API_KEY` and
  `QFLI_DEBUG_MODEL`. The harness reads `Platform.environment` only. It never
  opens `C:\Users\lichengyu\.qfli-debug.env` itself.
- `--env-file` belongs to the operator script. It parses `KEY=VALUE` lines into
  the child process environment. Nothing is echoed back to the shell.
- The report stores `baseHost`, `model`, `protocol`, `keyPresent` and
  `keyLength`. It never stores the key, an authorization header or a prompt
  snippet outside `scenario.assistantReply`.
- A scenario passes only when every assertion holds on a real tool result.
  Missing variables, a missing adapter or a timeout produce `skipped` or
  `failed`, never `passed`.
- The report status is `failed` when any scenario failed. The operator script
  recomputes that status from the scenario rows, so a stale header cannot hide
  a failure.
- Reports default to `<scratch>/.artifacts/vibe-e2e/report-<timestamp>.json`
  outside every Git root. Never commit a report.
- `web_search` requires the published search tools. `vibeE2eHasSearchTools`
  reads the tool specs; absence means skip.

## 4. Validation & Error Matrix

| Condition | Required behavior |
| --- | --- |
| any `QFLI_DEBUG_*` variable missing or blank | every scenario `skipped`, exit 0, report written |
| debug adapter absent (`--transport` unset) | scenario `skipped`, `skipReason` names the missing interface |
| search tools absent | `web_search` skipped, other scenarios still run |
| scenario assertion false | scenario `failed`, report status `failed`, exit 1 |
| scenario exceeds its budget | `cancel()` runs, `timeout: true`, assertion `within_timeout` false |
| report leaks a key-like string | `vibeE2eReportProblems` returns a problem and the harness test fails |
| report schema differs | `VibeE2eReportReader` throws `FormatException` |

## 5. Good / Base / Bad Cases

- Good: operator exports the three variables, runs the harness, and the report
  shows `python_fix_loop` with `exit 1` then `exit 0` plus the real marker.
- Base: no variables exported; the report is `skipped` and says which names
  are missing.
- Bad: hardcoding a model or endpoint in the harness, printing the key length
  next to the key, or marking a scenario `passed` because the controller reached
  `succeeded` without the tool evidence.

## 6. Tests Required

- `flutter test --no-pub test/vibe_e2e_harness_test.dart` — credentials,
  redaction, report round-trip, schema rejection, assertion registry, scenario
  assertions.
- `dart run tool/verify_vibe_e2e.dart --dry-run` — environment report only.
- `dart run tool/verify_vibe_e2e.dart --report <file>` — table rendering and
  exit code from a recorded report.
- A live run needs the credential file outside the repo. Record the command and
  the report path in the task `implement.md` Result section, never the key.

## 7. Wrong vs Correct

### Wrong

```dart
final key = File(r'C:\Users\liche\...\.qfli-debug.env').readAsStringSync();
stdout.writeln('using key $key');
```

### Correct

```dart
final credentials = VibeE2eCredentials.fromEnvironment();
if (credentials == null) return const <VibeE2eScenarioResult>[/* skipped */];
stdout.writeln(credentials.redacted(protocol: 'backend_default'));
```
