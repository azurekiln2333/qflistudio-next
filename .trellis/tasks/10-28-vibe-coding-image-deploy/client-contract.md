# Vibe Coding client contract (Pi B → Pi C)

Status: **frozen as requested by Pi C**, implemented in
`../qfli_studio_core/lib/vibe_coding/`. Differences from Pi C's draft: none at
the public surface. Additional read-only members are listed at the end.

## Files

| File | Owner | Purpose |
| --- | --- | --- |
| `lib/vibe_coding/vibe_coding_controller.dart` | B | `VibeCodingController`, model/tool loop, cancellation, terminal runs |
| `lib/vibe_coding/vibe_models.dart` | B | `VibePhase`, `VibeToolStatus`, `VibeMessage`, `VibeToolCall` |
| `lib/vibe_coding/vibe_tools.dart` | B | Path guard, list/read/write/edit, backups, snapshot, tool specs |
| `lib/services/api_client.dart` | B | `ApiClient.aiChat`, abortable `_send` / `terminalEvents` |
| `lib/vibe_coding/CONTRACT.md` | B | This file |

Pi C owns editor integration and every Vibe UI file. Do not edit
`vibe_coding_panel.dart`, `vibe_coding_widgets.dart` or `vibe_editor_bridge.dart`
from worker B.

## Constructor (exact)

```dart
VibeCodingController({
  required ApiClient api,
  required String? Function() tokenProvider,
  required String projectRoot,
  required String projectName,
  required String language,
  bool Function()? onlineAllowed,
  void Function(String relativePath)? onFileChanged,
  void Function(String? relativePath)? onFileRemoved,
  void Function(String message)? onNotice,
})
```

- `tokenProvider` is read on every model round and command run. Return `null` or
  `''` when signed out. The controller never stores the token.
- `onlineAllowed` is read on every `send`. Return `false` for offline-only
  products. A denied send sets `phase = failed`, `lastError = '当前产品为离线模式，AI 编程需要联网'`,
  and never calls the backend.
- `onFileChanged` fires after a real successful `write_file` / `edit_file` with
  the path relative to `projectRoot` (`a/b.py`, forward slashes).
- `onFileRemoved` has no tool trigger today. Call
  `notifyFileRemoved(path)` if the editor deletes a file while a session exists.
- `onNotice` receives non-fatal UI hints (for example, a send ignored while a
  task is running).
- Optional extras with defaults: `VibeProjectFiles? files` (pass
  `EditorGuardedProjectFiles`) and `int maxRounds = 8`.

## State (read-only)

```dart
enum VibePhase { idle, running, cancelling, succeeded, failed, cancelled }
enum VibeToolStatus { running, ok, error, conflict }

class VibeMessage {
  final bool isUser;
  final String text;
  final VibeToolCall? tool; // assistant tool entry, else null
  final bool pending;       // entry still running
}

class VibeToolCall {
  final String id;
  final String toolName;      // list_files/read_file/write_file/edit_file/run_command
  final String summary;       // shortened argument, display-ready
  final VibeToolStatus status;
  final String? result;       // shortened result or live stage text
  final String? commandOutput;// real stdout/stderr tail for run_command
  final int? exitCode;
}
```

Controller members:

```dart
VibePhase get phase;
List<VibeMessage> get messages; // unmodifiable, chronological
bool get canSend;               // phase != running && phase != cancelling
bool get canCancel;             // phase == running
String? get lastError;
VibeProjectFiles get files;     // advanced/editor-side path guard
String get projectRoot;
void send(String text);         // returns immediately; results land in state
Future<void> cancel();          // completes after the round has stopped
void dispose();
void notifyFileRemoved(String? relativePath);
```

`isUser` messages contain the user prompt. Assistant prose uses `tool == null`.
Each model tool call becomes one message with `tool != null` and `pending == true`.
When the tool finishes, the same message is replaced in place with `pending == false`
and a final `status` (`ok`, `error`, `conflict`). Tool results are never shown as
`ok` before the tool actually returns.

`result` while running carries the real terminal stage (`排队中`, `初始化终端`,
`上传项目快照`, `运行中`, `清理环境`). `commandOutput` streams the real terminal
stdout/stderr tail (24 KiB per stream). A nonzero exit code sets
`status = error` and `exitCode` is the real value.

## Login, offline, failure

- `send()` returns immediately when the controller is disposed. A disposed
  controller never sends, never mutates state and never notifies.
- `tokenProvider()` null/empty on `send`: `phase = failed`,
  `lastError = '请先登录后使用 AI 编程'`, zero backend calls.
- Token expires mid-run: `phase = failed`, `lastError = '登录已过期，请重新登录'`.
- `onlineAllowed() == false`: see above; zero backend calls and no terminal use.
- Backend/tool failures surface in `lastError` (phase) or in the tool entry
  (`result`, `status`). The UI must not substitute mock success.

## Conflicts and backups

- The controller tracks the exact content of every file the agent read or wrote
  in this session.
- `write_file` / `edit_file` on an existing file that was never read fails with
  `status = error` and a "read_file first" message.
- If the on-disk content differs from the tracked content, the tool returns
  `status = conflict`, `result` explains the rejection, and **no write occurs**.
  The disk content is re-read after the backup as well, so a change during
  backup also becomes a conflict.
- Overwrites of the same physical path are serialized across
  `VibeProjectFiles` instances, including instances constructed from an aliased
  project root. The queue key is the resolved real root plus the relative path.
  The path and link checks run again after dequeue, so a parent replaced by a
  link while queued is rejected.
- `write(path, content, createOnly: true)` uses an atomic exclusive create.
  Concurrent creators produce exactly one success and one `exists` error.
- `VibeProjectFiles({bool Function(String absolutePath)? shouldWrite})` is the
  public commit-point hook. It runs inside the path queue, after the conflict
  re-check and backup, and immediately before the real write (for `createOnly`
  it runs before the exclusive create, so a rejection leaves no empty file).
  Returning `false` throws `VibeToolException(code: 'conflict')` and writes
  nothing. `edit()` computes the replacement and reuses `write()`, so it passes
  through the same hook.
- Before every overwrite, the current file is copied to
  `<projectRoot>/.qfli/vibe-backups/<timestamp>-<flattened-path>` plus a `.json`
  sidecar. The backup directory is checked for symlink/junction escape before
  creation and again after creation; a failed or escaped backup cancels the
  write.
- The controller never waits for unsaved editor buffers. Install the editor
  guard at the commit point (`shouldWrite`) and/or `onFileChanged`; a rejected
  write is reported as `status = conflict`.
- Unwritable paths: absolute paths, drive letters, `..`, NUL, `.qfli`, `.git`
  (case-insensitive), symlinked components, symlink escapes, files over
  256 KiB, writes over 256 KiB and listings over 400 entries are rejected.
  Non-UTF-8 or NUL-containing files are rejected as `binary`; the tools never
  decode loosely and write binary content back.

## Tool execution

- `list_files {path?, recursive?}` — one level by default; hidden, dependency and
  build directories are skipped.
- `read_file {path}` — UTF-8, malformed bytes replaced; tracks content.
- `write_file {path, content, createOnly?}` — creates parent directories;
  `createOnly: true` never overwrites.
- `edit_file {path, oldText, newText, replaceAll?}` — exact replacement; multiple
  matches fail unless `replaceAll`.
- `run_command {command}` — fresh project snapshot (≤ 64 files, ≤ 256 KiB,
  base64, symlinks skipped) uploaded to the existing isolated terminal via
  `ApiClient.terminalEvents`; never executed on the business host.

The loop keeps every assistant `tool_calls` message and every `tool` response
message, so the model can fail → read the real error → fix → rerun. It stops at
8 rounds (`phase = failed`, `lastError` explains the limit) or on cancellation.

## Cancellation

`cancel()` sets `phase = cancelling`, aborts the in-flight HTTP request through
`http.AbortableRequest` (both `/api/ai/chat` and the terminal NDJSON stream),
cancels the terminal subscription, and completes any pending command with a
cancelled tool result. The loop keeps the phase at `cancelling` while it adds a
`tool` reply for every unanswered `tool_calls` id, so a later `send` never emits
an orphaned tool call. `cancel()` then awaits the terminal session reset when a
command actually ran, and only afterwards sets `phase = cancelled`. `canSend`
stays false through the reset, so a late DELETE cannot kill the next task. A late
model response is discarded.

## Backend contract (fixed)

`POST /api/ai/chat`, bearer auth, body `{messages, tools?}`, response
`{model, message, usage?}` with `message.tool_calls` preserved. The server fixes
the upstream origin, credential and model (`deepseek-v4.1-flash`). The client
never sends a model or an API key. Offline gate is `ApiClient._requireOnline`
inside `_send`; `aiChat` only calls `_send`.

## Validation

Focused tests: `test/vibe_coding_tools_test.dart` (22 cases: path escape, case
and symlink checks, UTF-8/binary refusal, read-before-write, backup, disk
conflict, concurrent writers, atomic `createOnly`, commit-point `shouldWrite`,
alias root queue, backup-directory escape, snapshot limits),
`test/vibe_coding_controller_test.dart` (15 cases: real tool rounds, fail → read
→ fix → rerun, conflict, guard conflict, token/offline gates, round limit,
malformed arguments, real cancel with delayed reset, protocol validity after
cancel, dispose guard, output bounds) and the existing
`test/api_client_offline_test.dart`. Run `dart format`, `flutter analyze` and
those tests. Live upstream create/edit/fail/fix/rerun needs server credentials
and is reported separately by the root.
