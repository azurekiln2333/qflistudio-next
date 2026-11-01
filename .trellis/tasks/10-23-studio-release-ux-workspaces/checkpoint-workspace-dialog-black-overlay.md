# Actual workspace-settings black overlay fix

The user refocused this session on the editor workspace settings action showing only a black background. Narrow fix authority supersedes the earlier freeze for this bug's exact dependencies; the separate formatting proposal remains unapplied.

A real retained EditorPage + phone drawer + OHOS/Chinese test reproduced the old AlertDialog failure: RenderShrinkWrappingViewport does not support returning intrinsic dimensions. OHOS defaults AlertDialog to a scrollable layout whose intrinsic-height query reached the nested shrinkWrap ListView. The modal barrier had already opened.

Both the main saved-workspace dialog and language-product membership dialog now explicitly let AlertDialog own scrolling and use ordinary project children that can answer intrinsic sizing. Actions remain outside the content scroll; no selection or persistence callback changed.

New five-case regression: OHOS phone390/desktop1100, Android phone, OHOS standalone one-project save and explicit language profile membership apply. It checks actual toolbar clicks, hit-testable dialog controls, ten-project last choice with keyboard300, stored name/members, unchanged source, same editor State/workspace id and cancel returning toolbar input. Initial frame and keyboard-inset animations are advanced before physical taps.

Results: focused5 PASS; related37 PASS (workspace dialog, actions, explorer state, workspace sessions, retained editor and actual1100x175 EditorPage); narrow3-file analysis No issues found. All tracked handles terminal and released, no source drift. Reports are in v3 manifest. No main host reservation or device/native-build claim.

Exact publication: v3 supersedes only workspace_dialogs.dart, file_explorer.dart, saved-workspaces.md and adds workspace_dialog_layout_test.dart. Other14 v2 paths unchanged by raw hashes and Git blobs. Page remains byte-identical; real and C alternate indices untouched by main. C may refresh these exact candidates and integrate without another approval loop.

Separate finding sent to C: editing an existing saved workspace does not refresh the retained host's name/member snapshot until reopen because page _onWorkspaceChanged notifies onWorkspaceSaved only when id changes. Visible explorer/settings and stored document update correctly. No page or host write was made for this separate finding.
