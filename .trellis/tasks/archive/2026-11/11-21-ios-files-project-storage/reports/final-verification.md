# iOS project storage release verification

New managed projects on iOS use Documents/projects. The registry, settings, and authentication stay in Application Support. Existing private projects stay at their previous relative locations. Project lookup resolves old absolute paths against the current container. Android and HarmonyOS use their prior directory selection.

Pi in Herdr pane w37:pG added the iOS build check for both Files sharing flags.

- App: 07d8082abaf9d1aabd3f91058ff1430d2097f0c4
- Core: 123602be34ab6fa9725bb93f0d3bc27a630c7b44
- GitHub tag: v5.0.5-git.6
- App run 44851658777: 18 jobs succeeded, including publication.
- Core run 44851600940: independent analysis and complete test suite succeeded.
- Release 453366073: published on 2026-11-21 at 09:52:53 Asia/Shanghai.

Verified all 12 ZIP digests against the published SHA256SUMS. Downloaded and inspected the released iOS ZIP as data. Its inner IPA contains QFLIStudioN with bundle ID com.azurekiln.qflistudio and both Files sharing flags set to true. See ios-release-verification.json and app-monitor-git6-verification.json.

Local checks were limited to source analysis, formatting, plist inspection, and archive inspection. Cloud checks do not verify Files visibility or an upgrade on a physical iPhone. The IPA requires signing before installation.
