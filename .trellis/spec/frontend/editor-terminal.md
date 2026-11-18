# Editor Terminal

## 1. Scope / Trigger

Editor runs and local/online terminal UI are owned by `TerminalPane` and
`EditorPage`. Do not add another route to open the editor's online terminal.

## 2. Signatures

- `TerminalPane(auth, workingDirectory, onlineEnabled)` owns terminal sessions.
- `showOnline({initialize:true})` selects the online tab and optionally initializes it with `:`.
- `runOnlineProject(projectPath, entryFile)` copies bounded project files and runs them.
- `beginPreparation(title)` / `finishPreparation()` expose startup before runner futures resolve.
- `ApiClient.terminalEvents(token, command, {files})` yields typed `TerminalEvent` values.

## 3. Contracts

- Open/expand the panel and await its first frame before saving/probing/running.
- Retain a hidden pane with `Offstage`; explicit close removes it. Disposal closes
  the online HTTP client and attempts session reset using a separately owned client.
- At widths of 720 logical pixels or more, place the sidebar beside a right
  column containing the editor and every bottom panel. The sidebar spans the
  body height, including the space beside the terminal, Problems, output,
  debugger, debug console, ports, and AI. Below 720, keep the drawer route.
  Use the same keyed right column across width and focus-mode changes so the
  editor and retained terminal keep their state. Existing panel height limits
  and keyboard handling still apply within that column.
- Save a captured list of open files before project execution. Keep local/native
  runners first unless the user selected online. A local unavailable result (127)
  or a missing-toolchain hint may fall back to supported online execution.
- `OnlineProgram` maps entries to the cloud sandbox toolchains: Python, JS,
  TypeScript (Node 24 transform-types), Lua, Java, C, C++, Shell (bash), Go,
  Rust, Dart, PHP and Ruby (toolchains version 3). Kotlin and C# have no cloud
  runtime; report them as unsupported instead of submitting. Builds run offline
  (`GOTOOLCHAIN=local GOPROXY=off`, `cargo --offline`) and must not override the
  sandbox `GOFLAGS`/`CARGO_BUILD_JOBS` budgets.
- Project snapshots contain at most 64 regular files, 256 KiB combined decoded
  data, and are collected without following symlinks. Skip hidden files and
  dependency/build directories; reject oversized projects instead of truncating.
- NDJSON decoding belongs in `ApiClient`: 2 MiB total wire data, 700 KiB per line,
  known event types/stages, a single terminal result, and error frames become
  `ApiException`. Output chunks are rendered once; result output is not replayed.
- Preserve partial stdout/stderr lines across events and bound terminal history.
  UI displays actual queue and initialization stages, never a fabricated percentage.

## 4. Validation & Error Matrix

| Condition | Behavior |
| --- | --- |
| User not logged in | Show login requirement in terminal; do not allocate |
| Repeat Run while preparing | Ignore duplicate; keep existing work |
| Hide panel / switch to AI | Retain terminal client and output |
| Close editor/terminal | Cancel request and attempt ephemeral session reset |
| Queue/capacity error | Show server message; no infinite automatic retry |
| Invalid/missing final event | Fail and close the pane-owned request client |
| Unsupported/oversized project | Diagnose before server submission |

## 5. Good / Base / Bad Cases

- Good: first Run shows startup before a native channel or cloud initialization.
- Base: opening the App does not create any sandbox.
- Bad: a final stream result contains full output and the UI prints it again.
- Bad: conditional terminal construction destroys a running client when AI opens.

## 6. Tests Required

Use targeted Dart analysis for routine changes. Device rendering, real server
queue progress and disconnect cleanup require target-environment evidence.
Do not add/run tests without the user's request, per editor-paging guidance.

## 7. Wrong vs Correct

Wrong: push `OnlineTerminalPage` from the editor and wait for a runner before
mounting its output surface.

Correct: expand retained `TerminalPane`, display preparation, and stream typed
server stages and output into its online session.
