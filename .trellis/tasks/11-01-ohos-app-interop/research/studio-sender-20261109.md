# Studio sender (route B) verification — 2026-11-09

Owner: pane `w37:pH` (B). Scope: `qfli_studio_core/lib/interop/**` and the Studio
OHOS sender `ohos/entry/src/main/ets/interop/StudioBackgroundInterop.ets`.

## Changes kept

| File | Change |
| --- | --- |
| `lib/interop/transport` | `interopWireMap()` normalizes only `seq` and `exitCode`, and only a finite, exactly integral `double`. A fractional, NaN, infinite or non-numeric value passes through so the strict decoder still rejects it. Payload text and nested maps are never touched. |
| `lib/interop/transport` | `InteropLaunch.stop` plus `InteropStop`. A transport that can prove a stop reports the receiver's own terminal outcome; the foreground route leaves it null and keeps the legacy request. |
| `lib/interop/transport` | A registered channel that answers `probe` with a `PlatformException` is now `unknown`, not `missing`. "Missing" would tell the user to install an app that is already answering. |
| `lib/interop/background_transport` | `stop()` returns the stored outcome. `_finish(receiverAcknowledged:)` is true only for a real terminal frame from `_receive`; a local timeout, a local failure and an unanswered cancel are false. |
| `lib/interop/background_transport` | `start` is bounded by `startupGrace`; a lost platform reply fails with 127 instead of hanging the run. |
| `lib/interop/runner` | A `done` text is the receiver's closing note. On the streaming background route it goes to stderr; on the aggregating foreground route it stays on stdout. Cancel uses the confirmed `stop()` when present and never invents 130. |

Removed in review: an unrequested `NUDGE` resend protocol (the Java receiver
does not subscribe to it, so it could not be verified), and the unused
`prepareRequest` / `runPrepared` API. No receiver protocol was extended.

## Verification run this round

- `flutter analyze --no-pub lib/interop <six interop/editor test files>`: no issues.
- `flutter test` on `interop_runner`, `interop_background_transport`,
  `interop_protocol`, `interop_zip`, `interop_arkts_contract`,
  `editor_background_run`, `interop_probe_decision`, `interop_entry_decision`:
  128 passed.
- `node scripts/test-ohos-background-bridge.cjs` in `qflistudio`: 9 checks pass,
  exit code 0.
- `node tool/verify_interop_background.cjs` in `qfli_java` (owner C): passes.

The background transport suite now pins both timeouts separately: a lost start
reply reports 127 (`startup reply timeout reports transport failure`), and the
independent total deadline reports 124 with `stop.confirmed == false`
(`total deadline expires without a terminal event and exits 124`).

## Failure not owned by this route

`test/editor_run_target_test.dart` fails 3 of 6 in the current working tree:

- `an installed sibling app takes the run tap` — line 47
  `expect(fixture.transport.probedLanguages, contains('java'))`, actual `[]`.
- `a missing sibling app keeps the original path` — tap cannot find the Run
  tooltip.
- `an unknown probe keeps the original path` — same finder failure.

These are stale tests, not a route-B regression:

- The test file is committed and unmodified (no `git status` entry; HEAD is
  `17fa440`). It still asserts that Run probes the sibling app first.
- HEAD's `lib/editor/editor_page.dart` calls `runner.probe(target.language)`
  five times. The working-tree `editor_page.dart` has no `.probe(` call at all:
  it resolves the target locally and reports a missing app from the start
  result instead.
- The probe removal is a pre-existing, intentional change. It was already in
  the working tree before this round, and
  `research/device-debug-20261105.md` records it as the 2026-11-05 fix:
  `打开项目即探测 → JVMX 前台闪现像闪退 | 删 initState 探测,tooltip 改查静态目标表`.
- The failing assertion reads a fake transport's `probedLanguages`, which only
  the editor fills. No change in `lib/interop` can populate it.

Do not change `editor_page.dart` to satisfy the stale test. The test belongs to
`test/` (owner D). Confirm against the D baseline (1392 pass / 9 skip / 3 fail)
whether these three are the same three.
