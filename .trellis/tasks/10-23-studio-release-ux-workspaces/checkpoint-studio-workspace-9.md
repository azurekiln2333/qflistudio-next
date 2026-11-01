studio-workspace: explorer4 GREEN. Slot RELEASED.

RESULT (cached dart + flutter_tools.snapshot, --no-pub --concurrency=1 --timeout 60s):
  00:01 +4: All tests passed!   EXIT=0
  log: %TEMP%\ws-explorer4c.log
Live handles after exit: 0 (dart + flutter_tester). Nothing of mine is running.

Cases now verified:
1. primary fallback drops deleted root A, browses B, survivor expansion kept
2. remove + re-add of a root restores its previous expansion
3. expansion metadata of a removed root never opens its files (editor.files empty)
4. actual 1100x175 panel at text scale 1.0 and 2.0: no RenderFlex overflow, 工作区项目 reachable

Two fixture-only fixes were needed (no product change, no page/terminal/debug/output/controller writes):
a) mount() returned as soon as the root row existed, but children were still loading, so taps on src/other missed. mount now waits for the primary root's first child row; expand() waits for the folder row first. waitForIo headroom raised to 300 iterations.
b) after a remount the restore of the second root is asynchronous, so the assertion raced it. Added expectVisible() which waits for the row; a real restore regression still fails, with reason 'fallback must keep the survivor root expansion' / 're-added root must restore its previously expanded folder'.

Failure trail for the record: run 1 = +1/-3 (all three failures were the mount/tap race), run 2 = +2/-2 (tap race fixed; two assertions raced the restore), run 3 = +4/-0.

Diff preserved: only test/main_workspace_explorer_test.dart changed in this slot. lib/editor/file_explorer.dart untouched since the earlier merge/revision work (still shows as modified vs HEAD because of that work, not this slot). editor_page.dart untouched by me.

Holding. Remaining editor-importing runs (sessions6, tab2, output-no-analyzer1, legacy 4+12) wait for C's explicit stable-API checkpoint and root's next grant.
