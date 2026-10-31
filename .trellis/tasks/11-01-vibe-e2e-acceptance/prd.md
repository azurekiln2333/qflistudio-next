# Vibe e2e acceptance, specs and OHOS build

## Goal

Prove the whole flow with the real upstream, keep specs current, and keep OHOS builds green.

## Requirements

- R1: A Dart e2e harness (`tool/vibe_e2e.dart`) drives `VibeCodingController` headless against the debug upstream using env creds. Scenarios: static todo site, small Python fix loop, web search question. Output a JSON report with tool calls and real command exit codes.
- R2: Skip cleanly when env vars are absent. Never print the key.
- R3: Update `.trellis/spec/frontend/` with contracts: skills layout, API protocol adapter, interop protocol, e2e. Mark index rows Active.
- R4: Run `flutter analyze` and `flutter test --no-pub` in `qfli_studio_core` and `qflistudio`. Run `tool/verify_ohos_products.dart` and an OHOS HAP build via `tool/build_hap.sh` for at least `qflistudio` and `qfli_java` when the toolchain exists.
- R5: Update `docs/` and READMEs for the new capabilities.
- R6: Start the live scenarios after A and B publish their interfaces. Until then prepare the harness skeleton and spec drafts.

## Acceptance

- [ ] E2E report shows each scenario with real outputs.
- [ ] Analyze and tests pass, or each failure is listed with its cause.
- [ ] Specs and docs committed in standard format.
