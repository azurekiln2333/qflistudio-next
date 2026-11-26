# Coordinator review findings

Read-only release review found these concrete blockers on November 21:

1. Plugin .github/workflows/native.yml has no release/** push trigger. Dart checks are independent of fresh host build. Sequence host artifacts -> install from same run -> Dart checks.
2. qfli_git/tool/ci/native_contract.json is missing, although new collect/import/provenance scripts require it. Add the actual ABI/platform contract.
3. import_artifacts.py requires --commit or --run. Existing example import workflow steps pass neither. Update every caller.
4. App tool/ci/plugin_provenance.py lock_entry() uses json.loads on pubspec.lock, which is YAML. Use correct parsing with an available dependency or change the reliable provenance source. Do not assume lockfiles are JSON.
5. App publish-preview still only accepts remote.* tags, and release body says Git UI is not integrated. Add the requested git.* preview path while retaining remote.* behavior. Update release description to the implemented scope.

Continue your assigned implementation and fix these. Do not execute tests locally.
