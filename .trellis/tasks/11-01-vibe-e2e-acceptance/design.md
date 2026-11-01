# Design

## Boundary

Pi-D owns acceptance evidence only. The harness never reimplements the agent,
the backend or the tool loop. It drives the public surface that A and B publish,
records what really happened, and turns that into a report.

| Layer | Owner | Pi-D touch |
| --- | --- | --- |
| `qfli_studio_core/lib/vibe_coding/**` | A | none |
| `qfli_studio_core/lib/services/ai_service.dart`, AI methods in `api_client.dart` | B | none |
| `qfli_studio_core/lib/interop/**`, OHOS `ets/`, `module.json5` | C | none |
| `qfli_studio_core/test/vibe_e2e_*.dart`, `qflistudio/tool/vibe_*.dart`, `.trellis/spec/**`, `docs/**` | D | all edits |

## Harness shape

Two repositories, two jobs.

1. `qfli_studio_core/tool/vibe_e2e.dart` — headless driver. Builds the project
   fixture in a temp directory, constructs `VibeCodingController` against an
   injectable `ApiClient`, sends one scenario prompt, waits for a terminal
   phase, and writes a JSON report. No Flutter widget tree.
2. `qflistudio/tool/verify_vibe_e2e.dart` — operator entry. Checks the
   environment, runs the driver with `dart run`, reads the report and prints a
   pass/fail table. It never sees the credential value.

The driver must stay runnable while `ai_service.dart` is in flux. Two reasons:

- `ApiClient` takes an optional `transport`, so the harness substitutes the
  transport instead of patching the client.
- The report schema carries a `protocol` field that B fills per request
  (`chat_completions`, `responses`, `messages`). Until B's adapter lands the
  field stays `backend_default`, and R1 scenarios still run against
  `/api/ai/chat`.

## Credential flow

```
qfli_studio_core tool/vibe_e2e.dart
  reads QFLI_DEBUG_* from Platform.environment
  -> builds an HTTP client with a fixed debug base URL  (B's adapter, when ready)
  -> the value never leaves the process
  -> the report stores only { keyPresent: true, keyLength, baseHost }

qflistudio tool/verify_vibe_e2e.dart
  runs the driver in a child process
  -> inherits the parent environment, never prints it
```

Rules:

- The key never enters an argument, a file, a report, an exception message or a
  commit. The harness redacts by never printing: the only key-derived numbers
  are length and presence.
- Absent variables: the driver writes a report with `"status": "skipped"` per
  scenario, exits 0, and the operator script prints how to export the three
  variables. `.qfli-debug.env` is outside every repository; the operator
  script accepts `--env-file <path>` and refuses paths inside a Git root only
  if the file is tracked (see below), which keeps the repo clean.

`--env-file` parsing lives in the operator script. It reads `KEY=VALUE` lines,
drops `export `, ignores `#`, and sets the child-process environment only.
Nothing is written back to the shell or to disk.

## Scenarios

| Key | Prompt shape | Assertions |
| --- | --- | --- |
| `static_site` | 做一个待办事项小网站 | `write_file` produced `index.html`, plus a style and a script file. `run_command` exit code recorded, not invented. |
| `python_fix_loop` | run `verify.py`, read the failing module, fix, rerun | first `run_command` exit code non-zero, last exit code 0, `edit_file` present |
| `web_search` | question that needs current facts | `web_search` / `web_fetch` tool call present and citing a URL. Skipped while B's tool is absent. |

Scenario assertions read `controller.messages`, exactly what the user sees.
A scenario passes only if its assertions hold on real tool results.

## Report schema

```jsonc
{
  "schema": 1,
  "generatedAt": "2026-11-01T00:00:00Z",
  "tool": { "driver": "qfli_studio_core/tool/vibe_e2e.dart", "revision": "..." },
  "environment": {
    "baseHost": "newapi.azurekiln.cn",
    "model": "deepseek-v4.1-flash",
    "protocol": "backend_default",
    "keyPresent": true,
    "keyLength": 48
  },
  "scenarios": [
    {
      "key": "python_fix_loop",
      "status": "passed",
      "phase": "succeeded",
      "durationMs": 41230,
      "lastError": null,
      "assistantReply": "…",
      "tools": [
        { "name": "run_command", "status": "error", "exitCode": 1, "output": "AssertionError…" }
      ],
      "assertions": [ { "name": "first_run_failed", "ok": true, "detail": "exit 1" } ]
    }
  ]
}
```

`status` is one of `passed`, `failed`, `skipped`. `output` is the real tail
(≤ 4 KiB per entry). The report lands in
`<scratch>/.artifacts/vibe-e2e/report-<timestamp>.json`, outside every
repository by default, because it contains prompts and source snippets.

## OHOS build gate

Order matters: OHOS is the priority platform, so the cheapest check runs first.

1. `tool/verify_ohos_products.dart` — bundle names, AppScope, plugin manifests.
2. `tool/build_hap.sh <app>` — needs Git Bash plus hvigor. Missing toolchain is
   reported as `blocked`, never as `passed`.
3. HAP artifact listing (`entry-default-unsigned.hap`) with byte size.

`qflistudio` and `qfli_java` are the required pair. Other apps are optional
matrix rows.

## Spec drafts

`.trellis/spec/frontend/` gains four files, each marked `Draft` until the owner
publishes the interface:

- `vibe-skills.md` — skill layout and prompt assembly (A)
- `ai-protocols.md` — three endpoint adapters, one request/response shape (B)
- `interop.md` — Studio to `qfli_*` launch, compile, run contract (C)
- `vibe-e2e.md` — this harness, its schema and its redaction rules (D)

A draft states what is frozen and what is provisional. The index marks them
`Draft` so nobody codes against a guess.

## Risks

- `ApiConfig.baseUrl` is a compile-time constant. Until B exposes an injectable
  endpoint, the harness can only reach the real backend, not the debug
  upstream. The driver therefore treats "no adapter" as a skip, not a pass.
- The terminal relay (`/api/terminal/exec/stream`) requires the production
  login token. `run_command` assertions depend on the operator's own session.
  The report records `terminal: { available: bool }` so a missing relay is
  visible, not silently green.
- Long runs: a scenario budget of 6 minutes with `cancel()` in `finally`. A
  timeout is `failed` with `timeout` detail.
