# OHOS cross-app toolchain interop

## Goal

A project made in qflistudio can be compiled and run by the matching sibling app (`qfli_c`, `qfli_java`, `qfli_go`, ...) using that app's local toolchain, on OHOS first.

## Requirements

- R1: Research and record in `research/` what OHOS allows: Want-based `startAbility` or `startAbilityForResult` across bundles, `uris` and `skills` in `module.json5`, `querySchemes`, per-app sandbox isolation, shared directory options (file URI grant, `fileShare`, picker, `distributedFiles`). Cite docs or observed behavior.
- R2: Design a protocol `qfli-interop/1`. The request carries language, entry file, project payload (files by URI grant, or a zipped copy), action (`compile`, `run`) and stdin. The response carries exit code, stdout, stderr and artifact refs. Define version and error codes.
- R3: Implement the Studio side in `qfli_studio_core/lib/interop/` (Dart API plus ArkTS bridge) and a receiver in the shared core so every `qfli_*` app answers. First language: Java. Then C and Python if the mechanism holds.
- R4: Studio UI: a run action on a project whose language has an installed sibling app. A missing app shows an install hint. Progress and cancel work.
- R5: Security: allowlist caller bundle names, validate payload size and paths, no arbitrary file reads.
- R6: If OHOS blocks the direct file path, state the limit and implement the closest working path (payload copy). Record the limit in `design.md`.

## Acceptance

- [ ] Research notes and `design.md` reviewed by the root session before implementation.
- [ ] Protocol encode/decode tests, path-validation tests.
- [ ] Observed evidence on an OHOS device or emulator, or a precise statement of what could not be run.
- [ ] Vibe `run_command` can route compile and run through interop (interface agreed with A through the root session).

## Background route amendment — 2026-11-05

The user approved implementation of a separate OHOS-first background route.
The existing foreground route must remain independently available and unchanged.
Java is the first receiver. Other languages and platforms are outside this increment.

- B1: Add a separate editor action for background execution. Keep the existing Run action and foreground receiver.
- B2: Receive real compilation/program output without using reverse UIAbility launches. Show progress in the Studio terminal and notification drawer.
- B3: Bound the entire background job by the granted transient-task budget. Stop the native process on cancellation or deadline and release owned resources.
- B4: Authenticate the caller and event publisher. Preserve URI authorization and payload limits.
- B5: Do not silently switch to the foreground route when the background route fails.
- B6: Verify absence of a visible receiver window on OHOS hardware before calling the experience seamless. A successful build alone does not establish this.

Acceptance for this increment:

- [ ] Existing foreground implementation remains unchanged, except additive exports/registration that do not alter execution.
- [ ] Background action uses separate native channels, receiver ability, event names and session state.
- [ ] Success, compiler error, timeout, cancellation and missing receiver have truthful outcomes.
- [ ] Fresh Studio and Java HAPs build; focused Dart regression tests pass.
- [ ] Hardware evidence covers notification visibility, result delivery, cancellation and any startup flicker. If hardware is unavailable, record this acceptance as pending.
