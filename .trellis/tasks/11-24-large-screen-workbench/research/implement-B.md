# Implement B: Windows native folder drop and Core intake

The user approved the final plan with 继续. IMPLEMENT now, no planning gate.
Task: D:/MyNewProjects/qflistudio/.trellis/tasks/11-24-large-screen-workbench
App root: D:/MyNewProjects/_wt/large-screen-workbench/qflistudio
Core root: D:/MyNewProjects/_wt/large-screen-workbench/qfli_studio_core
WRITE ONLY:
- App windows/runner/{folder_drop.h,folder_drop.cpp,flutter_window.h,flutter_window.cpp,main.cpp,CMakeLists.txt}
- Core lib/services/desktop_folder_drop.dart
- Core test/desktop_folder_drop_test.dart
Read design.md and actual runner first. No unrelated scans. First patch within 6 reads.

Native OLE IDropTarget, CF_HDROP directories, Unicode/long paths. Register actual
Flutter child HWND; balance registration/revocation and OleInitialize lifecycle
alongside existing RoInitialize STA. No copied files, no shell command string,
no rejecting UNC merely for being UNC. OLE effect COPY is intake semantics,
never delete/move originals. Reject ordinary files visibly, retain valid folders
when a mixed batch occurs. Native receiver queues until Dart is ready.
Dedicated MethodChannel qflistudio/folder_drop:
- Dart -> takePending returns List<Map> and marks Dart ready.
- native -> incoming with {id: String, paths: List<String>}.
Use monotonically unique per-process ids. Queue bounded input safely; always
release STGMEDIUM/COM. No new Flutter dependency and no generated registrants.

Core DesktopFolderDrop service API:
constructor DesktopFolderDrop({required ProjectStore store, required Future<void> Function(Project) onOpen, required void Function(String) onError, MethodChannel? channel});
Future<void> start(); void dispose();
decode, serialize batches, normalize/dedupe, find an existing project by path,
else await store.addExisting(path), then onOpen. addExisting does NOT open editor.
Catch registration exceptions; preserve current project and source directory.
Deduplicate repeat batches and same path. On shutdown stop delivering callbacks.
Parent starts service on Windows only and injects callback. Do not edit app.dart.
Add cloud-only tests using fake channel/store or temp directories in runAsync
for repeated drops, malformed payloads, start backlog, errors and dispose.
Do not run tests/probes/builds locally. Format/analyze allowed. Do not commit,
push, create worktrees or edit other paths. Report actual APIs and changed files.
