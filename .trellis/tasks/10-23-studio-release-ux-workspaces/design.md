# Design

## Boundaries
Shared UI fixes live in ../qfli_studio_core. Main-only content composition belongs in qflistudio with a ContentRepository injected through qfliStudioProfile. Use existing package aggregate content only where it actually equals the language product's source; copy/package product-owned assets for missing/divergent sources with reproducible provenance. Never import entire product runtimes to obtain text assets.

Saved workspaces own explicit IDs, names, ordered project references and editor session metadata under AppPaths.storageDirectory()/workspaces. Standalone ProjectHistory stays single-project. Workspace opening re-resolves members against the current project registry and filesystem, reports missing members and selects a surviving primary. The retained editor host keys project and workspace sessions separately. Membership and session writes must remain ordered and must not persist source buffers.

Points loads are per-section, cached per account, guarded against stale responses and duplicate fetches. Preserve populated content during refresh and retain tab state. Check-in progress is scoped to the actual request and cleared in finally. Common tools use the existing grid/card system and local deterministic operations.

## Ownership
- Pi content (w2E:p4): main content bundling/injection; core local_content_pages.dart and content catalog adapters as needed. Does not edit home_page.dart.
- Pi workspace (w2E:p6): core home_page.dart, file_explorer.dart, editor_page.dart, retained_editor_host.dart, project_history.dart and new workspace models/store/widgets. Home routing must use LocalTutorialsTab for main qflistudio and offline products, preserve injected repository, and use safe nullable-profile language fallback.
- Pi tools (w2E:p5): quick_tools_page.dart, tools_grid.dart, offline_tool_pages.dart, offline_tools.dart and new local tool modules.
- Pi points (w2E:p7): tasks_page.dart, points_page.dart and scoped activity/API changes only if needed.
- Root: diagnostics visibility in dedicated analysis UI module, integration, spec updates and acceptance evidence. Coordinate before editing another owner's file.

## Compatibility
Use main-product conditions for release-only visibility changes. Product codeAnalyzer providers, product tools builders and contentRepositoryFactory continue to work. Existing project histories remain readable without silently restoring workspace membership in standalone main-app opens. Preserve current unstaged debugging/process/content-generator work.
