# Git UI follow-up: completed

## Delivered behavior

- Project cards read the local repository HEAD asynchronously and show the current branch. Unborn branches, linked worktrees and detached HEAD are supported. Cards refresh on Home refresh, editor return, retained-editor minimize and App resume.
- Git dialogs apply the mobile keyboard inset once. The clone form remains scrollable and mobile opening does not autofocus the URL field.
- The editor symbols bar has a fixed keyboard-dismiss button at the far right. The action hides the input method while preserving editor focus, code and selection. Its rendered target is 44 by 44 points and stays fixed while symbols scroll.

## Source and immutable release

- App: 23b81a4abf33c9cec73490ba498bae5110acd587
- Core: 0f18c3692791e66aa8cb74e71f49ea52469b7295
- qfli_git: 53ad359159258706d4c242e70a2db0e1d075dabc
- Java receiver contract: 60d97c783f29da767fafe503980812101f6aa61f
- Branch: release/studio-git-ui-20261120
- Tag: v5.0.5-git.5
- Release: https://github.com/azurekiln2333/qflistudio-next/releases/tag/v5.0.5-git.5
- Release ID: 453270763
- Published: 2026-11-21 07:11:23 Asia/Shanghai

App and Core commits were pushed to GitHub. The App workflow pins the exact Core commit. The existing .3 and .4 tags were preserved. The .4 release gate rejected two real keyboard-action regressions and no .4 release was published. The corrective Core commit addresses those regressions without weakening the selection or geometry assertions. See keyboard-fix-review.md.

## Cloud verification

- Authoritative App run 44833095726: all 18 jobs succeeded, including both complete Flutter suites, Java/companion checks, Windows assistant, production-SDK Git iOS simulator integration, eleven installer targets and publication.
- Independent Core run 44833065983: 2418 visible tests passed, 26 existing skips, zero errors, 249097 ms.
- All 24 new regression cases passed: HEAD reader 9, project cards 9, clone-dialog layout 3, keyboard dismissal 3.
- Formatting, targeted static analysis, Chinese UI-copy lint and git diff --check passed. Full Core analysis retained one existing info message.
- Duplicate branch run 44833095727 was cancelled.

## Published package inspection

The release contains 13 assets: eleven installer ZIPs, one Windows assistant ZIP, and SHA256SUMS. All twelve GitHub ZIP digests match the published manifest. The tag, workflow, release body and source pins agree.

The Android arm64 ZIP was downloaded and inspected as an archive. Its SHA256 is 29fac8992370bf74c7545a39d8ee5d351ff3e738a6c30529e91d90f0adb900f2. Outer and inner checksums pass. BUILD_INFO records the exact App/Core/plugin/native source pins. The APK contains the expected AArch64 Git library and matching CA bundle. No installer was executed.

Evidence: app-monitor-git5-verification.json, app-monitor-git5-android-verification.json, core-monitor-git5-counts.json and their raw logs/artifacts.

## Boundaries and installation

No local tests, builds, App launches, services or emulators ran. The original cloudterminal checkout was not modified. Product changes were confined to the isolated integration worktrees. Existing unrelated edits and the empty index in the primary checkout were preserved.

Android uses a temporary debug signing key generated in the cloud job. A differently signed installed build cannot be overwritten directly; back up application data before replacing it. iOS and OHOS packages require signing before installation. Windows is unsigned. macOS is ad-hoc signed and not notarized. No physical-device validation is claimed.
