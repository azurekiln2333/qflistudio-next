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
