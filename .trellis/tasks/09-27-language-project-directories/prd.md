# Language Project Directories And Display Names

## Requirements

- New local projects are grouped by source language: `cProjects`, `cppProjects`, `javaProjects`, and equivalent directories for every supported template.
- Duplicate display names are allowed. The first `demo` directory retains its name; subsequent conflicts use `demo_<timestamp>`, with an additional counter if necessary.
- `.qfli/project.json` owns display name, language and type. Registry entries cache metadata and retain identity, path, favorites and timestamps.
- Creating a project, importing an example and importing a project archive use the same path allocation rules.
- Adding an existing folder, reloading and refreshing use its configuration name rather than overwriting it with the directory basename.
- Project recycle records retain the display name independently of the directory basename.
- Preserve existing absolute paths and external imported directories. Do not move live projects or alter cloud identities/storage in this task.

## Evidence

Perform static Dart analysis and review creation/import/refresh flows. No tests requested; do not add or run tests.
