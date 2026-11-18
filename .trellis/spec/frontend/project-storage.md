# Local Project Storage

## Directory Contract

- `AppPaths.projectsRoot` resolves the selectable projects container.
- `ProjectTemplate.directoryName` is `<stable source type>Projects`, including `cProjects`, `cppProjects`, `javaProjects`, `pythonProjects` and `emptyProjects`.
- `AppPaths.languageProjectsRoot` groups projects below the selected container, without nesting a matching language directory twice.
- `AppPaths.availableProjectPath` uses the display name for the first directory, then `<name>_<millisecondsSinceEpoch>` for conflicts, with a counter if that timestamp also conflicts. Any filesystem node, including a dangling link, occupies its path.
- `AppPaths.createProjectDirectory` synchronously reserves the directory before awaited file writes. All app-local creators, examples and archive import use this owner.
- Existing registered and externally selected projects retain their absolute paths. No automatic folder migration occurs, because editor and history references contain those paths.

## Metadata Contract

- `.qfli/project.json` owns `name`, `language` and `type`; the registry caches fields and owns identity, path, favorites and activity timestamps.
- Loading and refreshing read valid configuration fields even when the registry already has values. Missing/malformed fields fall back to cached metadata.
- Adding an existing folder preserves its configured display name. Directory basename is only a fallback; timestamp suffixes never overwrite a valid configuration name.
- Strict metadata writes are required for creation and archive restore; failures cannot be reported as successful creation. Existing external read-only folders retain best-effort writes.
- Archive export reads current configuration metadata. Import selects a language directory, permits duplicate display names and restores that name to configuration.
- Project recycle sidecars retain configured name, language and type independently of the ZIP root/directory basename. Restoration registers the config name and defaults to a distinct path when the original destination is occupied.

## Validation

Review create/example/import/refresh/add-existing/recycle flows and run targeted Dart analysis. Do not add or run tests unless requested. Cloud storage and cloud project identities are a separate contract.
