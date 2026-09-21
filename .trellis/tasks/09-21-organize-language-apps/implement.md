# Implementation Plan

1. Add the task artifacts and narrow workspace cleanup rules; remove only confirmed temporary diagnostics; validate `git status`; commit as `chore(workspace): organize generated and temporary files`.
2. Extend the shared profile/tutorial contract and replace offline navigation pages with local tutorial and example-code widgets; add focused tests; commit as `feat(core): add offline tutorial and example pages`.
3. Add C++ and Lua app shells, profiles, runners with honest unavailable-runtime results, local tutorial JSON, platform metadata copied from the existing app pattern, and app tests; register both in the workspace; commit as `feat(apps): add cpp and lua language apps`.
4. Update README/docs and verify JSON, analyzer, shared tests, target app tests, and workspace cleanliness; commit as `docs(apps): document offline language app layout`.

## Validation

- `dart format` on changed Dart files.
- `flutter analyze --no-pub`.
- `flutter test --no-pub` in `packages/qfli_studio_core`, `apps/qfli_c`, `apps/qfli_cpp`, `apps/qfli_python`, `apps/qfli_java`, `apps/qfli_lua`, and `apps/qfli_web`.
- A script-level JSON parse check for all tutorial assets.
- `git diff --check` and `git status --short --untracked-files=all`.
