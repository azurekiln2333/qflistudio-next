# Offline editor analysis

## 1. Scope and trigger

Shared editor analysis is a cross-product interface. Product profiles supply a
local syntax checker; core owns snapshots, scheduling, presentation and navigation.
The checker must never execute user code, invoke annotation processors, overwrite
source files or contact a network service.

## 2. Signatures

`services/code_analysis.dart` exports `CodeAnalyzer.analyze(CodeAnalysisRequest)`.
`StudioProfile.codeAnalyzer` is optional and re-exports the contract.
`EditorController.openPath` accepts `ownerProjectName`, `ownerProjectPath` and
`ownerProjectType`; pass all three when opening another workspace root.

## 3. Contracts

Requests carry normalized absolute `projectPath`, `activeFilePath`, `language`,
active `revision`, and immutable `documents`. Each `CodeDocumentSnapshot` contains
`path`, exact unsaved UTF-16 `text` and `revision`. Uniform CRLF text remains CRLF.
The active owner's type disambiguates C++ `.h` files.

`CodeDiagnostic` carries `filePath`, half-open zero-based UTF-16 `startOffset` and
`endOffset`, `message`, `severity`, `source`, and `code`. Empty ranges represent
insertions. `CodeAnalysisResult.unavailableReason == null` means a successful
check, including an empty result. Unavailable must never be presented as clean.

Core debounces actual text changes, clears old results immediately, permits one
provider request in flight, and rejects an entire stale generation. Selection,
unchanged text and folding do not create dirty revisions or analyzer requests.
Each dispatch receives a fresh timeout after any queue wait. A timed-out provider
retains its lane until completion; repeated retries must not spawn unlimited work.

The main `qflistudio` product hides `EditorProblemsBar` when its analyzer is null;
the editor child keeps the full available space and no Problems action is shown.
A null profile has the same main-product default. Keep the controller's honest
unavailable state: hiding the optional UI must not report an unchecked file as
clean. Language products retain their existing unavailable/provider UI, and a
configured main-product analyzer retains the Problems action. Verify these cases
with `editor_problems_visibility_test.dart` alongside `editor_analysis_test.dart`.

## 4. Validation and error matrix

| Condition | Behavior |
| --- | --- |
| No provider, read-only history, or no active file | Honest unavailable state; no dispatch. |
| More than 64 snapshots or 4 Mi UTF-16 units | Unavailable with bound explanation. |
| Foreign path, negative/reversed range, blank message, captured range beyond EOF | Reject diagnostic. |
| More than 1000 valid diagnostics | Retain first 1000. |
| Text, revision, tab/root or disposal changed | Ignore stale response. |
| Provider error or timeout | Unavailable; preserve source and one-lane bound. |
| Diagnostic references unopened disk source | Open under its owner and recheck before precise selection. |

## 5. Good, base and bad cases

Good: two open Java buffers are captured together and unsaved source overlays the
provider's isolated compiler input. Base: no analyzer retains editing and displays
the unavailable reason. Bad: interpreting compiler byte offsets as UTF-16 offsets,
or reporting a failed checker as zero errors.

Wavy ranges retain original token styles, expand boundaries around surrogate
pairs, and prefer the most severe overlapping range. A separate gutter marker
covers empty source lines and folded diagnostic children without inserting text.

## 6. Required tests

Run `editor_analysis_test.dart`, `highlight_preferences_test.dart`, editor run,
terminal, offline, retained-session and highlight-worker tests. Include actual
mounted-editor CRLF line shrink, queue wait exceeding timeout, stale buffers,
disposal, Unicode, empty lines and folded navigation. Product tests must exercise
the real analyzer in `EditorPage`; a mocked checker does not prove that integration.
Default grammar tests must inspect actual tokens and source preservation. JS/TS
also register XML, CSS and GraphQL for embedded syntax.

## 7. Wrong versus correct

Wrong: call `forceRepaint()` synchronously from a source-change listener. re_editor
may still hold the old render line count and index beyond the shorter new source.
Correct: invalidate diagnostics immediately, coalesce repaint in a post-frame
callback after render reconciliation, and guard disposal. Never change vendor
rendering or pad the user's source to hide the index error.
