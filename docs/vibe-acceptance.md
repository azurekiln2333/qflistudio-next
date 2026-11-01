# Vibe Coding acceptance

This page explains how to prove that Vibe Coding really works. It covers the
harness, the report, and the rules that keep the debug credential out of every
repository.

The interface it checks is described in `.trellis/spec/frontend/vibe-e2e.md`.
Protocol and interop contracts live next to it in the same directory.

## What the harness is

Two small programs, one per repository.

| Path | Repository | Job |
| --- | --- | --- |
| `tool/vibe_e2e.dart` | `qfli_studio_core` | CLI driver, shares the runner |
| `tool/vibe_e2e_runner.dart` | `qfli_studio_core` | Runtime, transport-backed stub, report assembly |
| `tool/vibe_e2e_transport.dart` | `qfli_studio_core` | Direct debug-upstream client over `AiService` |
| `test/vibe_live_e2e_test.dart` | `qfli_studio_core` | Live host under `flutter test`; skips without `QFLI_DEBUG_*` |
| `tool/verify_vibe_e2e.dart` | `qflistudio` | Check the environment, run the live host, print a report table |

The driver is not a second agent. It sends one prompt per scenario and records
what the controller actually did: which files it wrote, which commands it ran,
and which exit codes came back.

`qfli_studio_core` imports Flutter, so `dart run` cannot load it. The live host
is `flutter test test/vibe_live_e2e_test.dart`; the CLI stays for a future SDK
side adapter and shares the same runner.

## Credentials

The three variables come from the process environment. The harness never opens
the credential file itself.

```
QFLI_DEBUG_BASE_URL=<debug upstream>/v1
QFLI_DEBUG_API_KEY=<key, value never printed>
QFLI_DEBUG_MODEL=<model id>
```

The file `C:\Users\lichengyu\.qfli-debug.env` outside every repository may hold
these values. Pass it explicitly when needed:

```
dart run tool/verify_vibe_e2e.dart --env-file C:\Users\lichengyu\.qfli-debug.env
```

From `qflistudio` that command parses the file into the child environment and
runs the live host. From `qfli_studio_core` the same variables can be exported
before `flutter test`.

The report stores the upstream host, the model name, the protocol, whether a key
was present and its length. A length is not a secret. Never add the value to make
debugging easier.

The operator script parses `KEY=VALUE` lines into the child process only. The
values are not echoed and not written back to disk. Do not copy that file into a
repository, do not paste its contents into a terminal transcript, and do not put
it in a commit message.

## Running it

First, a dry run that touches no network:

```
cd qflistudio
dart run tool/verify_vibe_e2e.dart --dry-run
```

Then a live run, once the interfaces below are published:

```
cd qfli_studio_core
flutter test --no-pub test/vibe_live_e2e_test.dart
```

The whole file skips when any `QFLI_DEBUG_*` variable is missing. When the
variables are present, the report lands in `<scratch>/.artifacts/vibe-e2e/` and
the test fails if every scenario skips, so an unreachable upstream never looks
like a pass.

Or from `qflistudio`, which checks the environment first and forwards to the
same host:

```
dart run tool/verify_vibe_e2e.dart --env-file <path>
```

Read a recorded report without running anything:

```
dart run tool/verify_vibe_e2e.dart --report <path>
```

Exit codes: `0` for pass or skip, `1` when any scenario failed, `2` for a usage
or path error.

## Scenarios

| Key | Question it answers |
| --- | --- |
| `static_site` | Does one sentence really produce `index.html`, a stylesheet and a script? |
| `python_fix_loop` | Does the agent see a real failure, fix it, and rerun until it passes? |
| `web_search` | Does retrieval return real links that the answer cites? |

A scenario passes only when its assertions hold on real tool results. A skipped
scenario always carries `skipReason`. A green report can therefore never hide an
unrun scenario.

## Why a run may be skipped today

One interface is not published yet, so the harness records a skip instead of a
pass.

1. `web_search` and `web_fetch` belong to the protocol task. Until they appear in
   `vibeToolSpecs()`, the search scenario skips.

The controller still calls `ApiClient.aiChat` without an endpoint, so the live
host uses its own narrow stub that refuses the relay route. If B later adds an
endpoint parameter to the controller, the stub accepts only `AiEndpoint.direct`.

## Reports

Reports land in `<scratch>/.artifacts/vibe-e2e/report-<timestamp>.json`, outside
every Git root, because they contain prompts and source snippets. The schema is
versioned (`"schema": 1`). Treat a report as evidence, not as source.

## OHOS build gate

OHOS comes first. Before claiming a flow works, run:

```
cd qflistudio
dart run tool/verify_ohos_products.dart
tool/build_hap.sh qflistudio
tool/build_hap.sh qfli_java
```

`tool/build_hap.sh` needs Git Bash and hvigor. A missing toolchain is reported as
blocked, never as passed. The expected artifact is
`<app>/ohos/entry/build/default/outputs/default/entry-default-unsigned.hap`.

## Keeping it honest

- Do not weaken an assertion to make the report green.
- Do not record a pass from a cached artifact or a previous run's file.
- When a scenario fails for an outside reason, write the cause in the task
  `implement.md`, not in the harness.
