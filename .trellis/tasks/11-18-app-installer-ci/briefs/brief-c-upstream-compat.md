# Brief C: upstream Flutter compatibility probe

Rules (non-negotiable, read first):
- Never run git reset, checkout, restore, stash, clean, switch, rebase, commit or push, in any repo.
- Never touch D:/MyNewProjects/qflistudio or D:/MyNewProjects/qfli_studio_core (the user's main trees with uncommitted work).
- Work only in D:/MyNewProjects/_wt/app-installers-compat/{qflistudio,qfli_studio_core} and D:/MyNewProjects/_scratch/flutter-upstream.
- Never run `flutter config` with any flag. It writes global settings shared with the user's OHOS Flutter install at D:/ProgramFiles/flutter_ohos.
- Do not put the upstream Flutter on the global PATH. Call it by absolute path only.
- Write the report only to D:/MyNewProjects/qflistudio/.trellis/tasks/11-18-app-installer-ci/research/upstream-compat.md

Goal: find out whether the qflistudio app compiles with the latest official Flutter stable. The app is developed against the Flutter OHOS fork 3.27.5-ohos-1.0.1 (Dart 3.11.5). CI will build every non-OHOS package with official latest stable.

Steps:
1. Resolve latest stable: read current_release.stable from https://storage.googleapis.com/flutter_infra_release/releases/releases_windows.json and map the hash to its version (expected 3.50.0, Dart 3.14.0).
2. `git clone --depth 1 --branch <version> https://github.com/flutter/flutter.git D:/MyNewProjects/_scratch/flutter-upstream` (skip if it already exists at that tag). Then run `D:/MyNewProjects/_scratch/flutter-upstream/bin/flutter --version` once to download the Dart SDK.
3. In D:/MyNewProjects/_wt/app-installers-compat/qflistudio (its sibling ../qfli_studio_core already exists; there is no pubspec_overrides.yaml there, keep it that way), with F=D:/MyNewProjects/_scratch/flutter-upstream/bin/flutter:
   - `$F pub get`
   - `$F analyze` (record error / warning / info counts and every error line)
   - `$F build windows --release` (record the result and every compile error with file:line)
   - Also run `$F analyze` inside ../qfli_studio_core after `$F pub get` there.
4. If the Windows build succeeds, check the exe exists under build/windows/x64/runner/Release/ and report its size.
5. Report in upstream-compat.md: Flutter version + framework commit + Dart version, every command with exit code, analyze counts, full list of errors (not warnings) with file:line and message, the build outcome, and how pubspec.lock changed (`git diff --stat pubspec.lock` is read-only and allowed). Keep it factual and concise.

When done, reply in the terminal with a summary of at most 25 lines.
