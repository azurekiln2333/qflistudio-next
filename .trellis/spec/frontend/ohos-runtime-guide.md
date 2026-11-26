# OHOS runtime download guide

## 1. Scope / Trigger

Apply to the OHOS local-terminal download entry, its guide page and product
icons. These are download links. Receiver implementation remains owned by
the separate interop task. Store navigation and installation need devices.

## 2. Signatures

- `OhosRuntimeApp(id, name, languageLabel, languages, bundleName, iconAsset)`
  is immutable. `storeUri` returns the supplied AppGallery HTTPS link.
- `ohosRuntimeApps` contains Java, C/C++, Go, Dart, Python, SQL, Web, Rust,
  then Studio, in that order.
- `showOhosRuntimeGuide(BuildContext, {String? language})` pushes one route.
- `OhosRuntimeGuide({String? language, Future<void> Function(Uri)? openStore})`
  allows an injected opener for cloud tests.
- `TerminalPane.projectLanguage` carries the editor's project language.

## 3. Contracts

Show the terminal toolbar and overflow actions only for OHOS local sessions.
Return to the same terminal state, session, draft and controllers. The action
does not start a compiler, probe installation, or download automatically.

The current language's tool is first and highlighted. Unknown and null
languages preserve catalog order. Studio is never a compiler recommendation.
Use one column below 720 logical pixels and a grid above it. Card actions have
at least 44 logical pixels of height. The toolbar entry uses standard density
so the 44px constraints do not shrink to 40px.

Icons use `assets/product_icons/<id>.png` and package `qfli_studio_core`.
Product names come from `StudioProductCatalog`. Bundle names are explicit:
product keys do not map mechanically to store bundle names.

The default opener invokes `qflistudio/platform`, method `openUrl`, with
`{'url': app.storeUri.toString()}`. Keep all supplied query parameters.
Propagate platform errors into a scrollable failure dialog with copy and
retry. Release the in-flight guard before offering retry.

## 4. Validation & Error Matrix

| Condition | Expected result |
| --- | --- |
| Non-OHOS or online session | No download-guide entry |
| Known language, including C/C++ aliases | Matching tool first |
| Unknown/null language | Original order and no recommendation |
| AppGallery launch error | Visible error, exact link, copy and retry |
| 320px width with 2x text | Single scrollable column, usable actions |
| Return from guide | Same terminal, sessions and unfinished input |

## 5. Good / Base / Bad Cases

Base: opening a local OHOS terminal shows a download icon.
Good: a Python project opens the guide with PyFlow first and retains its
unfinished command after returning.
Bad: claiming every listed tool already compiles or runs through Studio.

## 6. Required cloud checks

Run all formatting, analysis, tests and builds in GitHub Actions. Locally,
read/edit source and apply formatting patches produced by Actions only.

`ohos_runtime_guide_test.dart` checks all nine explicit bundle IDs, exact URLs,
packaged asset bytes, language ordering, injected opening, failure/copy/retry
and narrow large-text layouts. `terminal_pane_test.dart` checks platform and
session gating, the 44px target and retained draft/session identity.

Use real localization delegates. For lazy grids, ensure the actual action is
visible before tapping, even if its finder already matches a cached widget.
Compare both row and column positions when asserting grid order.

## 7. Wrong vs Correct

Wrong: use `RunnerService.openUrl`, which absorbs platform launch errors.
Correct: invoke the existing platform channel and show errors to the user.

Wrong: derive bundle IDs from branded product keys or recommend Studio when
there is no language match.
Correct: retain the explicit catalog mapping and leave unknown languages
unrecommended.
