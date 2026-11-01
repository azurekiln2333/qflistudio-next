# Workspace project selector correction

The user requires the top-left project selector to preserve the complete ordered
workspace tree when the chosen project is a current member. Choosing an external
project must replace the visible tree with that project's standalone tree.

The current explorer derives roots from mutable browsing plus members excluding
the primary. W(A,B) selecting B drops A; selecting C creates C+B under W. Fix the
membership calculation where it lives in FileExplorer. Member selection changes
the default creation/context target without rebuilding children or expansion.

External navigation belongs to the editor owner so project/history/run identity
also changes. Add an optional project-selection callback to EditorPage and
FileExplorer; retained host supplies an ordinary standalone open. A page without
a retained owner pushes a standalone EditorPage route and preserves the old page
for Back. Saved-workspace bare explorers without a navigation owner cannot offer
external switching. Legacy language-product unsaved browsing stays compatible.

Expected changed production paths: file_explorer.dart (stable roots and dispatch),
editor_page.dart (narrow constructor/property/route adapter), retained_editor_host
(standalone dispatch). Add actual-selector regressions and saved-workspace spec.
Preserve C controller/debug/output/terminal and unrelated page hunks; no source
formatting sweep, index edits, device mutation or parallel heavy build.

Validation: physical selector member B/A keeps roots/order/expansion/scroll and
dirty buffers; external C gives only C and correct owner; W remains unchanged
and restorable; existing standalone C reuses its session; no-host route returns
to W. Then focused legacy/workspace/retained/short-height regression and scoped
analysis in serial bounded test windows. Publish exact v4 dependency/page delta.
