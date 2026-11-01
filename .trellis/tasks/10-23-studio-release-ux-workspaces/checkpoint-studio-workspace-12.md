studio-workspace: filtered retry GREEN, EXIT=0, LIVE=0. Slot released. No rerun of the 25 (already green in ws-batch3: +26/-0).

FILTERED RETRY RESULT (cached snapshot, --no-pub --concurrency=1 --timeout 60s):
  --plain-name "workspace shrink" test/main_workspace_sessions_test.dart
  00:01 +1: All tests passed!
  EXIT=0   LIVE=0
  log: %TEMP%\ws-shrink5.log

Confirmed the diagnosis and kept the assertion strength:
- Real gesture preserved: tap on the actual orphan tab (textContaining('main.dart') scoped to TabBar, ensureVisible first), then tap on the real AppBar Run control (tooltip 运行（长按运行当前文件）). No direct controller.select, no _runProject call.
- Bound pump until the new SnackBar: loop pumps 50ms up to 140 iterations (7s) and stops as soon as 项目已从工作区移除 appears; a missing notice still fails.
- Old warning fully dismissed BEFORE Run, now explicit: after the tab switch the test waits until no 另存为 notice remains (up to 7s), then asserts findsNothing, then taps Run. This is the part that removed the last flake: selecting the orphan tab re-posts the reconcile warning, and ScaffoldMessenger queues the Run notice behind it for 4s.
- No-write assertion unchanged: dart/main.dart bytes must still be 'one\ntwo' after the Run gesture, so a save attempt fails the test.
- Tab switch wait unchanged: TabController commits only when indexIsChanging clears, so the test waits for editor.current == main.dart instead of one pump.

Root-cause note for the record: controller.select has no orphan guard, which is correct - selection must be allowed so the user can reach 另存为. The refusal belongs to _runProject, which checks _isOrphaned synchronously and posts _showSnack. Nothing in the product needs changing; ws-shrink2 was purely harness timing (one pump, plus an undismissed queued warning).

Locks: no editor_page/controller/terminal/debug/output writes; native main_workspace_actions_test.dart untouched. Nothing of mine is running; other runners may proceed.
