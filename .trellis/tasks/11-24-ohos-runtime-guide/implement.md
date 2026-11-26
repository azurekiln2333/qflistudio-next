# Implementation ownership

All files below are relative to the isolated Core worktree.

- Pi A w37:pC: only lib/interop/ohos_runtime_guide.dart. UI + opening errors.
- Pi B w37:p14: only lib/interop/ohos_runtime_catalog.dart, assets/product_icons/,
  and the one new asset declaration in pubspec.yaml. Do not change dependencies.
- Pi C w37:pG: only lib/editor/terminal_pane.dart and the new projectLanguage
  argument in EditorPage's TerminalPane construction. No runtime changes.
- Pi D w37:pJ: only test/ohos_runtime_guide_test.dart. Read actual APIs from
  design.md and delivered files. Do not fabricate imports or controller APIs.
- Parent: integration, cloud checks, existing CI failures, release
  version/tag selection, push/CI, final evidence and documentation.

Workers do not commit, push or tag. Never modify the original dirty checkout,
the new-api workspace or other workers' files. Report changed paths and checks.

Check final scripts/version requirements before publishing. User has explicitly
authorized a tag and CI/CD after the work and checks finish.


## Latest user override

All checks, including format/static analysis/lint, tests and builds, MUST run
in GitHub Actions. Local reads, edits and Git operations only. User authorizes
merging the verified feature branch into main, followed by a release tag and CI/CD.
This instruction overrides any earlier allowance for local static checks.
