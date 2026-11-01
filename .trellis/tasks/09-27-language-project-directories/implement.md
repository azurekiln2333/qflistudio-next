# Implementation

1. Read existing store/path/config/archive/recovery flows and frontend specs (completed).
2. Add shared language grouping and conflict-safe directory allocation (completed).
3. Make configuration metadata authoritative in project load/create/add-existing and archive import (completed).
4. Align create dialog preview, project selection path labels, recycle metadata and conflicting restore destinations (completed).
5. Completed: frontend project-storage specification and README updated, all 10 touched Dart files passed targeted analysis with no issues, tracked-file whitespace check passed, and create/example/archive/reload/add-existing/recycle flows reviewed. No runtime tests run or build performed.

## Compatibility

Existing local project paths and external folders remain unchanged. Valid project configuration metadata overrides cached registry name/language/type. Cloud projects retain their existing ID-based storage and name rules; this task changes local project storage only.
