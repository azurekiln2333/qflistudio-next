# QFLISQLab native SQLite bridge

This directory embeds the official SQLite 3.50.0 amalgamation. The app uses a
project-local database at `.qfli/data.sqlite`; no MySQL server or desktop
`sqlite3` executable is required.

The bridge exposes only two NAPI functions:

- `execute(source, databasePath)` returns `available`, `exitCode`, `output`,
  `error`, and `truncated`.
- `version()` returns SQLite's own `sqlite3_libversion()` value.

Build the shared library with the HarmonyOS NDK using
`native/CMakeLists.txt`, place the resulting `libqfli_sql.so` under
`ohos/entry/libs/<abi>/`, and register the ArkTS channel in the entry ability.
The Dart side intentionally stays unavailable until that library and channel
are installed; a missing bridge must never look like a successful query.

Source: https://www.sqlite.org/
Version: 3.50.0
License: public domain, as declared by the upstream SQLite source.
