# OHOS runtime download guide

The user explicitly narrowed this task to the entry and download UI. Do not
extend compiler/run receivers or promise new cross-app execution support.
Implementation, four-Pi delegation, commit, push, tag and CI are authorized.

## Interface

Core worktree: D:/MyNewProjects/_wt/large-screen-workbench/qfli_studio_core
App worktree: D:/MyNewProjects/_wt/large-screen-workbench/qflistudio

`lib/interop/ohos_runtime_catalog.dart` exports immutable `OhosRuntimeApp`
with `id`, `name`, `languageLabel`, `languages` (Set<String>), `bundleName`,
`iconAsset` and `Uri get storeUri`. Export `const ohosRuntimeApps` in user order:
Java, C/C++, Go, Dart, Python, SQL, Web, Rust, Studio.

`lib/interop/ohos_runtime_guide.dart` exports:
`Future<void> showOhosRuntimeGuide(BuildContext context, {String? language})`
and `OhosRuntimeGuide({String? language, Future<void> Function(Uri)? openStore})`.
The function pushes one normal MaterialPageRoute. The page uses the root's
theme and localization. Phone layout is a list, large screens a responsive
grid. Current language's app is first and highlighted without hiding others.
Studio is the multi-language editor, not a compiler dependency. Use supplied
icons, descriptive language labels, 44px actions, short install guidance.
Default openStore uses existing qflistudio/platform openUrl with the exact
provided HTTPS URL. Unlike RunnerService.openUrl, do not swallow errors:
show an error with retry/copy link. Do not probe installation or auto-launch.

`TerminalPane` gains optional `String? projectLanguage`. Show an install-tool
icon/menu action only when isOhosPlatform and the selected session is local.
`EditorPage` passes widget.project.language. Existing terminal execution,
sessions, input, scroll, controller identity and non-OHOS UI stay intact.
No first-open modal, no extra banner occupying the terminal output viewport.

## Assets and links

Copy only these nine source PNGs from D:/QFLIStudio. Preserve originals.
Resize to 256px maximum dimension if possible. Store below
Core assets/product_icons/ and declare that directory in Core pubspec.yaml.
Use package-qualified Image.asset with package qfli_studio_core.

| id | source PNG | bundleName |
|---|---|---|
| java | QFLIJVMX.png | com.azurekiln.qfli.java |
| cpp | QFLIForge.png | com.azurekiln.qfli.cpp |
| go | QFLIGoShift.png | com.azurekiln.qfli.go |
| dart | QFLIDartWing.png | com.azurekiln.qfli.dart |
| python | QFLIPyFlow.png | com.azurekiln.qfli.pyflow |
| sql | QFLISQLab.png | com.azurekiln.qfli.sql |
| web | QFLIWebForge.png | com.azurekiln.qfli.web |
| rust | QFLIRustCore.png | com.azurekiln.qfli.rust |
| studio | QFLIStudio+.png | com.azurekiln.qflistudio |

Every storeUri is exactly:
https://appgallery.huawei.com/app/detail?id=<bundleName>&channelId=SHARE&source=appshare
Use existing StudioProductCatalog names, not inferred product-key bundle IDs.
Catalog iconAsset names are assets/product_icons/<id>.png.

## Verification

All checks and builds run only in GitHub Actions. Local source reads, edits,
asset preparation and Git operations are allowed. Retain existing tests.
Cover nine unique links/assets, language preference, navigation, download URL,
open failure/copy/retry, narrow layout/text scale and terminal state retention.
No local emulator, test, build or behavior probe. Real AppGallery navigation
and installation need a device; compilation does not prove either.


## Latest user override

All checks, including format/static analysis/lint, tests and builds, MUST run
in GitHub Actions. Local reads, edits and Git operations only. User authorizes
merging the verified feature branch into main, followed by a release tag and CI/CD.
This instruction overrides any earlier allowance for local static checks.
