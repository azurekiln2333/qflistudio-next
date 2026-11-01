# Studio release UX and saved workspaces

## Goal
Deliver the complete user-requested main-app release behavior while preserving independent language products. The user explicitly authorized writing Trellis artifacts and dispatching the four existing Pi agents for implementation.

## Requirements and acceptance
1. Tutorials use all sibling products' shipped local curricula, grouped by subject. C and C++ are distinct filters. Hide tutorial publishing and its top-right plus. Header is left aligned; search uses Home's project-search appearance.
2. Examples use all sibling products' real local examples and open their source/details; the main product must not filter itself into an empty or unreadable catalog. Preserve source metadata, fixtures, difficulty and subject distinctions.
3. Expand tools with useful working local tools, reusing existing components. Existing language products' tools and injected runtimes remain intact.
4. Daily-task check-in immediately replaces its button with visible indeterminate progress, prevents duplicate requests, and transitions to success or a retryable error.
5. Points/redemption tabs remain responsive: independent loads must not block each other, tab switches must not recreate heavy content or restart requests; cache and refresh remain correct per account. Do not claim device timing without measurement.
6. Hide Home cloud-project scope/create entries and automatic cloud fetching for the main app. Preserve underlying cloud data.
7. Home has a saved-workspaces tab. A workspace is explicitly saved from the editor into the application data directory's workspaces folder and can be reopened by name.
8. Opening a standalone project must not implicitly reopen an attached workspace. Saved workspace identity, membership and editor session are separate from project history.
9. Opening a saved workspace validates each member; missing/deleted projects are identified and skipped with clear feedback. A missing primary root must not discard remaining valid roots; all missing members produces an actionable empty state. Do not delete source projects when modifying/deleting workspace metadata.
10. Editor workspace action opens a usable management/save interface, including when there is only one available project. Preserve owner-aware tabs, run targets, dirty buffers and root boundaries.
11. Hide the unavailable local-code-checker surface when the main product has no analyzer. Keep real analyzers/diagnostics working for language products; never report unavailable analysis as zero errors.
12. Use the four existing Pi panes in the qflistudio Herdr workspace and verify changes end to end.

## Scope constraints
Existing dirty edits in main/core and ongoing language product work must be preserved. No commits, pushes, device installation, server deployment or language content regeneration are required for this task. Do not mutate language sibling repositories. Bundling main-app copies from their current authoritative assets is permitted. Real feature checks and focused automated verification are authorized by the user's request to ensure normal operation; no live-account reward claims.

## Evidence
Main app is a thin shell using sibling ../qfli_studio_core. Home routes the networked main tutorial tab to PostListPage; main examples pass qflistudio as a language, causing an empty selection. FileExplorer currently persists workspaceRoots under the primary project's history. PointsPage waits on history, items and orders sequentially.
