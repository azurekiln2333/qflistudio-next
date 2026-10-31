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
| `tool/vibe_e2e.dart` | `qfli_studio_core` | Drive `VibeCodingController` headless, write a JSON report |
| `tool/verify_vibe_e2e.dart` | `qflistudio` | Check the environment, run the driver, print a report table |

The driver is not a second agent. It sends one prompt per scenario and records
what the controller actually did: which files it wrote, which commands it ran,
and which exit codes came back.

## Credentials

The three variables come from the process environment. The harness never opens
the credential file itself.

```
QFLI_DEBUG_BASE_URL   debug upstream, for example https://<host>/v1
QFLI_DEBUG_API_KEY    key, value never printed
QFLI_DEBUG_MODEL      model id
```

The file `C:\Users\lichengyu\.qfli-debug.env` outside every repository may hold
these values. Pass it explicitly when needed:

```
dart run tool/verify_vibe_e2e.dart --env-file C:\Users\lichengyu\.qfli-debug.env
```

The operator script parses `KEY=VALUE` lines into the child process only. The
values are not echoed and not written back to disk. Do not copy that file into a
repository, do not paste its contents into a terminal transcript, and do not put
it in a commit message.

The report stores the upstream host, the model name, whether a key was present
and its length. A length is not a secret. Never add the value to make debugging
easier.

## Running it

First, a dry run that touches no network:

```
cd qflistudio
dart run tool/verify_vibe_e2e.dart --dry-run
```

Then a full run, once the interfaces below are published:

```
cd qflistudio
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

Two interfaces are not published yet, so the harness records a skip instead of a
pass.

1. `ApiConfig.baseUrl` is a compile-time constant. A debug upstream needs an
   injectable endpoint from the protocol adapter task.
2. `web_search` and `web_fetch` belong to the same task. Until the specs appear
   in `vibeToolSpecs()`, the search scenario skips.

The driver also depends on `qfli_studio_core`, which imports Flutter. A plain
`dart run` cannot load `dart:ui`, so a real scenario run uses the Flutter test
runner or an SDK-side adapter. Keep the skip reason accurate rather than
working around it.

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
