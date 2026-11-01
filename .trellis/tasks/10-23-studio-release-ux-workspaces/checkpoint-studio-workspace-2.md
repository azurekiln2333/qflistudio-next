studio-workspace update 2 (still holding page lock + test freeze)

Test 6 root cause found and fixed; it was a TEST defect, not a product defect. No product change needed.

Cause: my fixture helper hardcoded workspace id 'ws-main' while WorkspaceStore.save() generates its own id. The "membership shrink" test reopened the session with that mismatched id, so EditorPage called saveSession for a workspace id whose file does not exist — the new store contract treats that as a deleted workspace and no-ops. The persisted doc therefore kept the original 2-owner snapshot and my assertion failed. The orphan logic itself was correct: the dispose save built a snapshot containing only the surviving owner.

Fix (test file only, test/main_workspace_sessions_test.dart):
- fixture helper now takes the real id (`workspace(members, {id})`), and the shrink case reuses the persisted id.
- the final check now asserts the on-disk JSON (`<storage>/workspaces/<id>.json` -> session.documents[].projectPath) as well as the in-memory store, and polls with pump(Duration(ms:50)) so queued writes actually advance.

flutter analyze after the change: test/main_workspace_sessions_test.dart and lib/editor/file_explorer.dart both clean.

Status of requested audit items (confirmation, no code pending from me):
- retained workspace ID-only identity + fallback primary without losing buffers: implemented in retained_editor_host.dart (key = workspace id; same-key reopen updates session.project and members, bumps workspaceRevision, notifyListeners). Covered by controller test.
- missing-owner tabs: dirty buffers kept with recovery via 另存为…, save/autosave/run blocked, deleted dirs never recreated. Implemented; assertion-level verified in test 6 before the freeze.
- repeated standalone reuse: implemented (reuse existing non-workspace session for the same project; promoted sessions excluded). Covered by controller test.
- expanded-state preservation: capture-before-rebuild + per-root merge, save only after restoration completes. Implemented in file_explorer.
- legacy _restoreLegacyWorkspace revision race guard: restored, plus bumps on workspace apply/save/delete.

file_explorer short-height/tree/header: fixed (no fixed 48/34 heights; ConstrainedBox min heights; compact workspace IconButton). Needs one test-window run for the 1100x175 overflow case.

Waiting on root for the test window. Page untouched since 02:05:38.
