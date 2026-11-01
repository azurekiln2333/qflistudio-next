# Design

Project templates define stable source-language folder names. `AppPaths` owns grouping, conflict resolution and synchronous directory allocation before any awaited template writes, so concurrent UI operations cannot select the same directory within the app.

Use `<selected-root>/<type>Projects/<name>`; if selected-root already is the appropriate language directory, use it directly. Detect all existing filesystem node types, including links, when resolving a conflict. Configuration names are unaffected by timestamp suffixes.

`ProjectConfig` provides typed metadata projection and strict writing for newly created/restored projects. Existing external directories retain best-effort metadata writing for read-only compatibility. Missing or malformed fields fall back to existing registry metadata or the actual directory name.

Archive import uses archive metadata to select a language directory, allocates a unique target and restores the original display name to configuration. Recycle backups retain display name, language and type alongside the original absolute path. Existing registered folders remain in place to preserve editor/history references.
