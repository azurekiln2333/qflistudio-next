# Main app local content inventory and provenance

Owner: studio-content. Task: `.trellis/tasks/10-23-studio-release-ux-workspaces`.

## Composition policy

The main QFLIStudio+ app ships one composed catalog under its own
`assets/content/` directory:

- Each product-owned catalog **replaces** the shared core aggregate for the
  subjects (`language`) it ships. Appending the aggregate would keep stale
  generated copies of C, Lua, Dart, Markdown and other rewritten curricula.
- The shared core aggregate is kept only for subjects no product ships assets
  for: **Java (280/280), Python (120/120), TypeScript (100/100), Shell
  (100/100)**. The Java and Python products have no content assets of their own
  and consume the aggregate directly.
- Entries are copied verbatim: ids, subject `language`, executable `type`,
  levels, concepts, fixtures, source/license/updatedAt metadata and lesson
  contents are not rewritten.
- WebForge keeps its teaching `language` (`html`/`css`/`javascript`) separate
  from its runnable `type: html`.
- Generation is deterministic: output is sorted by subject then id, and the
  source fingerprints are recorded. Re-running produces byte-identical files.

## Authoritative sources

| Product | Source files (relative to qflistudio) | Tutorials | Examples |
| --- | --- | ---: | ---: |
| forge (C/C++) | `../qfli_c/tool/forge_content/staging/forge_tutorials.json`, `forge_examples.json` | 200 | 200 |
| script (Lua) | `../qfli_lua/assets/content/lua_tutorials.json`, `lua_examples.json` | 23 groups / 240 lessons | 240 |
| webforge (HTML/CSS/JS) | `../qfli_web/assets/content/tutorials.json`, `examples.json` | 481 | 481 |
| rustcore | `../qfli_rust/assets/content_rust/tutorials.json`, `examples.json` | 166 | 166 |
| goshift | `../qfli_go/assets/curriculum/tutorials.json`, `examples.json` | 120 | 120 |
| dartwing | `../qfli_dart/assets/content/dart_tutorials.json`, `dart_examples.json` | 120 | 120 |
| sqlab | `../qfli_sql/assets/content/sql_tutorials.json`, `sql_examples.json` | 126 | 126 |
| json | `../qfli_json/assets/content/tutorials.json`, `examples.json` | 340 | 340 |
| note (Markdown) | `../qfli_note/assets/content/note_tutorials.json` + 8 `note_examples_*.json` | 4 groups / 22 lessons | 220 |
| shared fallback | `../qfli_studio_core/assets/content/tutorials.json`, `examples.json` | Java 280, Python 120, TS 100, Shell 100 | same |

Product-owned sources contribute 3593 entries; the shared fallback contributes
exactly 600 tutorials and 600 examples (Java + Python + TypeScript + Shell).

## Generated outputs

| File | Entries | Bytes | SHA-256 |
| --- | ---: | ---: | --- |
| `assets/content/tutorials.json` | 2180 | 5,898,810 | `6BF853F54EC794257CC5412E60DC36D8CD07CBABF008A64379FDCEF2B85E5B0A` |
| `assets/content/examples.json` | 2613 | 3,389,464 | `83460B5A0D6509E9A16D2AD20B53DD0834473AC9432D6B284FEC97247AE865F6` |
| `assets/content/provenance.json` | 27 source records | 11,509 | `1A0312D45A60CE68A4F762DF61E8DC239403F87003C1A577B25F4F08FB66C2C2` |

Per-subject counts (tutorial groups / lessons / examples):

| Subject | Tutorials | Lessons | Examples |
| --- | ---: | ---: | ---: |
| c | 100 | 100 | 100 |
| cpp | 100 | 100 | 100 |
| lua | 23 | 240 | 240 |
| javascript | 161 | 161 | 161 |
| typescript | 100 | 100 | 100 |
| shell | 100 | 100 | 100 |
| rust | 166 | 166 | 166 |
| go | 120 | 120 | 120 |
| java | 280 | 280 | 280 |
| html | 160 | 160 | 160 |
| css | 160 | 160 | 160 |
| python | 120 | 120 | 120 |
| dart | 120 | 120 | 120 |
| sql | 126 | 126 | 126 |
| json | 340 | 340 | 340 |
| markdown | 4 | 22 | 220 |
| **total** | **2180** | **2415** | **2613** |

Metadata/fixture preservation in the generated documents:

- All 4793 entries have explicit `id`, `language`, `type`, `locale`, `level`,
  `title`, `summary`, `source`, `license` and `updatedAt`.
- 3 tutorial groups, 77 lessons and 775 examples keep non-empty `inputFixtures`
  (C/C++, Lua, Go, Rust, Python, SQL, JSON, TypeScript, Shell).
- `sourceLessonId`, `concepts`, `templateType`, `checkMarker` and `topic`
  fields are copied untouched.

## Reproduction and checks

```powershell
# From D:\MyNewProjects\qflistudio
dart run tool/generate_studio_content.dart
dart run tool/verify_studio_content.dart
flutter test test/studio_content_repository_test.dart -j 1
```

Observed:

- `generate_studio_content.dart` → `Composed 2180 tutorials and 2613 examples
  from 27 source files.`
- `verify_studio_content.dart` → `PASS: composed assets match every
  product-owned source and keep only the shared fallback subjects.` It re-reads
  every source file, compares every complete row with canonical recursive JSON
  equality (including nested metadata, fixtures and list order), and asserts
  shared entries are either kept (fallback subjects) or intentionally replaced.
- `flutter test test/studio_content_repository_test.dart -j 1` → 3/3 passed.
  Covers the composed catalog, distinct C/C++ subjects, the qflistudio tutorial
  tab (all subjects, `2415`-lesson result label), and the qflistudio examples
  tab loading instead of the missing-catalog error.
- Re-running the generator produced identical SHA-256 hashes.
- October 23 integration recheck found four newer Web rows (HTML160/JS053,
  tutorial/example pairs). Main copies were regenerated from all 27 sources;
  the complete-row verifier passed again. A later integration recheck found 76 newer Go rows; the main-only generator refreshed those copies and the complete-row verifier passed.
- The latest source-only refresh synchronized two authoritative Java exercise
  fields (`java-tutorial-107` prompt and `java-tutorial-161` answer). Exact
  serialized-value replacements preserved every other field, row and byte of
  examples. All27 input files were stable before/after; independent complete-row
  comparison and subject/id ordering checks passed. Four provenance fields were
  updated. Hashes above describe this refresh. The later official Dart generator
  reproduced identical bytes; complete-row verification and actual Flutter
  asset-bundle build/binary-manifest inspection passed. Refresh evidence is in
  `research/content-refresh-20261023.json`; final raw reports/logs are in
  `.artifacts/main-final-remaining-gate-20261023T084155Z-85594cfa/`.
- Core content regressions:
  `flutter test test/local_content_filters_test.dart -j 1` (7 passed),
  `test/local_content_lazy_catalog_test.dart -j 1` (2 passed),
  `test/main_tab_header_theme_test.dart -j 1` (5 passed),
  `test/home_content_repository_test.dart -j 1` (2 passed).

## Main-app filter fixes (the two regressions)

- `qfli_studio_core/lib/content/local_content_adapter.dart`:
  `productKey == 'qflistudio'` now returns `ContentFilter()` (all
  types/subjects) instead of filtering by the product id. Child products keep
  `ContentFilter.forProduct(productKey)`; a null profile with normalized language
  `qflistudio` also loads all subjects, while other null-profile languages retain
  the legacy single-language filter. Both new widget cases passed in the current
  first21 batch (content filters9).
- `qfli_studio_core/lib/pages/local_content_pages.dart`
  `ExampleCodeTab._loadExamples`: `productKey == 'qflistudio'` returns the whole
  bundled + saved example catalog. The null-profile `qflistudio` language uses
  the same rule; child products and other null-profile languages keep their
  previous post-filter.

## UI changes in `local_content_pages.dart`

- Tutorial list groups multi-subject catalogs under a subject header
  (`LanguageBadge` + label), so C and C++ are visibly distinct. Single-language
  products keep the previous flat chapter list.
- Tutorial/examples AppBars set `centerTitle: false` (explicit left header).
- Content search uses the Home project-search appearance: filled
  `surfaceContainerHighest`, 12px radius, no border, dense hint and a plain
  close button. The `content-query` key and all filter/reset behavior are
  unchanged.
- The publishing/write plus lives only in community `PostListPage`; routing the
  main product to `LocalTutorialsTab` removes it (workspace owner's
  `home_page.dart` route uses `isMainStudioRelease`).

## Main app wiring

- `qflistudio/lib/content/studio_content_repository.dart`: loads the main
  app's own `assets/content/tutorials.json` + `examples.json` (plain key first,
  then `packages/qflistudio/...`), parses through the shared
  `ContentCatalog.fromJson` on a worker isolate, and caches the catalog.
- `qflistudio/lib/main.dart`: injects
  `contentRepositoryFactory: () => StudioContentRepository()`.
- `qflistudio/pubspec.yaml`: declares `assets/content/`.

No language product package or runtime is imported. Sibling repositories are
read-only inputs; their assets were not regenerated or modified.

## Limitations / follow-ups

- The main catalog intentionally does not satisfy the shared aggregate's
  per-`type` release minimum (`tool/validate_content.dart`): WebForge's CSS/JS
  entries keep `type: html`, and Lua/Markdown ship richer groups instead of the
  shared generated 100-per-type filler. `tool/verify_studio_content.dart`
  validates per subject and against the authoritative sources instead.
- Sources are the27 working-tree inputs hashed by the accepted final report.
  Later input changes require main regeneration and verification against the
  new snapshot. The current inspection proves the isolated Flutter asset
  directory and manifest registration; it does not prove a native package,
  installation, executable or device runtime.
