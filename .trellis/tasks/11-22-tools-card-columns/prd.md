# Tools card column preference

## Requirement

The tools browser changes its card column count with viewport width. Users need
an explicit choice of one or two columns in the spacious card view.

## Acceptance

- Show one-column and two-column choices in card view.
- Keep the selected count when resizing or switching density.
- Restore the choice after reopening the app.
- Default old settings to one column and preserve favorites and recent tools.
- Keep narrow two-column cards usable, including favorite and open actions.

## Change boundary

Implementation belongs in the integration Core at
`D:/MyNewProjects/_wt/studio-git-integration/qfli_studio_core`.
`tool_state_store.dart` owns persistence. `tools_browser.dart` owns the selector
and fixed grid count. `netrix_localizations.dart` owns five-language labels.
`tool_widgets.dart` adapts card actions for narrow cells. Existing layout tests
must reflect the explicit preference.

The standalone unused `ToolsGridSliver` retains its own layout contract. This
task does not change GitHub, cloud cache, desktop pairing, dependency overrides
or release wiring.

## Validation

Use Dart formatting, targeted static analysis, source review and diff checks.
Do not run local runtime tests, builds, services or device operations. Commit
this requirement separately in the integration Core.
