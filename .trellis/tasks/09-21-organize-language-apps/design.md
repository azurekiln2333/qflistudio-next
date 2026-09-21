# Design

## Boundaries

- `StudioProfile` owns per-App capability flags and the selected local language.
- `TutorialService` owns the local JSON contract and remains the replacement point for a future API-backed source.
- `HomePage` owns the tab composition. It chooses the local tutorial/example pages only when the active profile is offline; the root profile keeps the community pages.
- Each `apps/qfli_<language>` owns only its profile, language runner, platform shell and app-level tests. Shared editor/project behavior stays in `qfli_studio_core`.

## Data Flow

```text
assets/tutorials/<language>.json
  -> TutorialService.load(language)
  -> Tutorial model
  -> LocalTutorialsTab / ExampleCodeTab
```

The example-code page projects `TutorialLesson.code` from the same typed `Tutorial` model. This avoids a second content format while leaving `TutorialService` as the future API boundary.

## Offline Contract

`StudioProfile` gets an `isOffline` capability. Offline profiles use only local tabs and do not pass through community pages. The existing root app leaves the profile unset, so it remains the online app.

## Cleanup Contract

Ignore Flutter/HarmonyOS generated output globally where possible, add explicit patterns for this repository's diagnostic exports, and remove only obvious temporary files (`s*.txt`, `rc*.txt`, `_*.txt`, `tmp*.txt`, `.dsh_*.txt`). Tool configuration directories remain untouched.
