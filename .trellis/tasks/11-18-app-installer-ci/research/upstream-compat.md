# Upstream Flutter compatibility gate

## Scope

The installer workflow compiles the ten official targets with one upstream stable Flutter version. OHOS stays on the pinned OHOS fork.

## Local-build policy

No Flutter command ran on the developer machine. This includes `flutter pub get`, `flutter analyze`, and every `flutter build` command.

## Cloud probe

The first GitHub Actions run on `ci/app-installers` is the compatibility probe. `resolve-flutter` resolves one official stable version and commit. The Windows, Linux, macOS, iOS and Android jobs consume those outputs. The OHOS job uses `3.27.5-ohos-1.0.1` separately.

Status before push: **pending cloud run**.

Append the run URL, resolved Flutter version, framework commit, each build conclusion, and the first compiler error if a job fails. Do not mark this gate passed from a local build.

## Known facts

Upstream stable `3.50.0` provides Dart `3.14.0`, which satisfies the application `^3.11.5` SDK constraint.

The arm64 host artifacts required by Windows and Linux are available in upstream release storage. The OHOS fork does not provide those desktop artifacts.

The shared setup action no longer calls `flutter config --no-enable-ohos`. Upstream Flutter has no such option. The fix is commit `075fe05` on `ci/app-installers`.
