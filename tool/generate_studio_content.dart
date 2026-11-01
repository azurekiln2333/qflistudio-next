// Generates the QFLIStudio+ bundled local content catalog.
//
// The main app is a thin shell: every language product ships (or, for Java and
// Python, relies on the shared core for) its own offline curriculum. This tool
// composes those authoritative catalogs into the two documents the shared
// `ContentCatalog.fromJson` contract already understands, so the main app can
// show every product's real tutorials and examples without depending on any
// product runtime package.
//
// Policy
// - Entries are copied verbatim: ids, subject `language`, executable `type`,
//   levels, fixtures, metadata and lesson contents are never rewritten.
// - Each product-owned catalog replaces the shared core aggregate for the
//   subjects it ships. Appending the aggregate would keep stale generated
//   copies of C, Lua, Dart, Markdown and other rewritten curricula.
// - The shared aggregate is only kept for subjects no product ships assets
//   for: Java, Python, TypeScript and Shell (the Java/Python products have no
//   content assets of their own and use the aggregate directly).
// - Output ordering is deterministic (subject, then id), so regenerating from
//   the same sources produces byte-identical assets.
//
// Run from the `qflistudio` repository root:
//
//   dart run tool/generate_studio_content.dart
//
// The tool only reads sibling repositories; it never writes into them.

import 'dart:convert';
import 'dart:io';

/// Subject order used for grouping the generated catalog.
///
/// It mirrors `languageLabel` in the shared core so the catalog order matches
/// the filter chips the user sees.
const _subjects = <String>[
  'c',
  'cpp',
  'lua',
  'javascript',
  'typescript',
  'shell',
  'rust',
  'go',
  'java',
  'html',
  'css',
  'python',
  'dart',
  'sql',
  'json',
  'markdown',
];

class _SourceFile {
  const _SourceFile(this.repository, this.path);

  /// Sibling repository that owns the file, for provenance reporting.
  final String repository;
  final String path;
}

class _ContentSource {
  const _ContentSource({
    required this.product,
    required this.tutorials,
    required this.examples,
  });

  final String product;
  final List<_SourceFile> tutorials;
  final List<_SourceFile> examples;
}

/// Product-owned catalogs, in precedence order.
///
/// Keep this list aligned with each product's `contentRepositoryFactory` (or
/// with the shared aggregate when the product declares none):
/// - forge: `qfli_c/lib/forge_content_repository.dart` (staging assets)
/// - script: `qfli_lua/lib/lua_content_repository.dart` (Lua chapters)
/// - webforge: `qfli_web/lib/content/webforge_content_repository.dart`
/// - rustcore: `qfli_rust/lib/rust_content_repository.dart`
/// - goshift: `qfli_go/lib/go_content_repository.dart`
/// - dartwing: `qfli_dart/lib/dart_content_repository.dart`
/// - sqlab: `qfli_sql/lib/sql_content_repository.dart`
/// - json: `qfli_json/lib/content/json_content_repository.dart`
/// - note: `qfli_note/lib/content/note_content_repository.dart`
/// - jvmx / pyflow: no product content assets; the shared aggregate is their
///   shipped curriculum, so their types are covered by [_sharedSource].
const _productSources = <_ContentSource>[
  _ContentSource(
    product: 'forge',
    tutorials: [
      _SourceFile(
        'qfli_c',
        '../qfli_c/tool/forge_content/staging/forge_tutorials.json',
      ),
    ],
    examples: [
      _SourceFile(
        'qfli_c',
        '../qfli_c/tool/forge_content/staging/forge_examples.json',
      ),
    ],
  ),
  _ContentSource(
    product: 'script',
    tutorials: [
      _SourceFile('qfli_lua', '../qfli_lua/assets/content/lua_tutorials.json'),
    ],
    examples: [
      _SourceFile('qfli_lua', '../qfli_lua/assets/content/lua_examples.json'),
    ],
  ),
  _ContentSource(
    product: 'webforge',
    tutorials: [
      _SourceFile('qfli_web', '../qfli_web/assets/content/tutorials.json'),
    ],
    examples: [
      _SourceFile('qfli_web', '../qfli_web/assets/content/examples.json'),
    ],
  ),
  _ContentSource(
    product: 'rustcore',
    tutorials: [
      _SourceFile(
        'qfli_rust',
        '../qfli_rust/assets/content_rust/tutorials.json',
      ),
    ],
    examples: [
      _SourceFile(
        'qfli_rust',
        '../qfli_rust/assets/content_rust/examples.json',
      ),
    ],
  ),
  _ContentSource(
    product: 'goshift',
    tutorials: [
      _SourceFile('qfli_go', '../qfli_go/assets/curriculum/tutorials.json'),
    ],
    examples: [
      _SourceFile('qfli_go', '../qfli_go/assets/curriculum/examples.json'),
    ],
  ),
  _ContentSource(
    product: 'dartwing',
    tutorials: [
      _SourceFile(
        'qfli_dart',
        '../qfli_dart/assets/content/dart_tutorials.json',
      ),
    ],
    examples: [
      _SourceFile(
        'qfli_dart',
        '../qfli_dart/assets/content/dart_examples.json',
      ),
    ],
  ),
  _ContentSource(
    product: 'sqlab',
    tutorials: [
      _SourceFile('qfli_sql', '../qfli_sql/assets/content/sql_tutorials.json'),
    ],
    examples: [
      _SourceFile('qfli_sql', '../qfli_sql/assets/content/sql_examples.json'),
    ],
  ),
  _ContentSource(
    product: 'json',
    tutorials: [
      _SourceFile('qfli_json', '../qfli_json/assets/content/tutorials.json'),
    ],
    examples: [
      _SourceFile('qfli_json', '../qfli_json/assets/content/examples.json'),
    ],
  ),
  _ContentSource(
    product: 'note',
    tutorials: [
      _SourceFile(
        'qfli_note',
        '../qfli_note/assets/content/note_tutorials.json',
      ),
    ],
    examples: [
      _SourceFile(
        'qfli_note',
        '../qfli_note/assets/content/note_examples_blocks.json',
      ),
      _SourceFile(
        'qfli_note',
        '../qfli_note/assets/content/note_examples_documents.json',
      ),
      _SourceFile(
        'qfli_note',
        '../qfli_note/assets/content/note_examples_gfm.json',
      ),
      _SourceFile(
        'qfli_note',
        '../qfli_note/assets/content/note_examples_inline.json',
      ),
      _SourceFile(
        'qfli_note',
        '../qfli_note/assets/content/note_examples_languages.json',
      ),
      _SourceFile(
        'qfli_note',
        '../qfli_note/assets/content/note_examples_links.json',
      ),
      _SourceFile(
        'qfli_note',
        '../qfli_note/assets/content/note_examples_math.json',
      ),
      _SourceFile(
        'qfli_note',
        '../qfli_note/assets/content/note_examples_tables.json',
      ),
    ],
  ),
];

/// Shared aggregate used by products without their own content assets and as
/// the fill-in for ids no product owns.
const _sharedSource = _ContentSource(
  product: 'qflistudio-shared',
  tutorials: [
    _SourceFile(
      'qfli_studio_core',
      '../qfli_studio_core/assets/content/tutorials.json',
    ),
  ],
  examples: [
    _SourceFile(
      'qfli_studio_core',
      '../qfli_studio_core/assets/content/examples.json',
    ),
  ],
);

const _outputDirectory = 'assets/content';
const _generatedFrom = 'tool/generate_studio_content.dart';

Future<void> main(List<String> arguments) async {
  final root = Directory.current;
  if (!_isStudioRoot(root)) {
    stderr.writeln(
      'Run this tool from the qflistudio repository root '
      '(directory containing pubspec.yaml with `name: qflistudio`).',
    );
    exitCode = 2;
    return;
  }

  final tutorials = _ComposedCatalog('tutorials');
  final examples = _ComposedCatalog('examples');
  final provenanceSources = <Map<String, Object?>>[];

  for (final source in _productSources) {
    provenanceSources.addAll(
      await _absorb(source, tutorials: tutorials, examples: examples),
    );
  }
  // Subjects with a product-owned catalog replace the shared aggregate.
  final ownedSubjects = <String>{
    for (final entry in tutorials.entries) _subjectOf(entry),
    for (final entry in examples.entries) _subjectOf(entry),
  };
  final sharedRecords = await _absorb(
    _sharedSource,
    tutorials: tutorials,
    examples: examples,
    shared: true,
    ownedSubjects: ownedSubjects,
  );
  provenanceSources.addAll(sharedRecords);

  final tutorialEntries = tutorials.sortedEntries();
  final exampleEntries = examples.sortedEntries();

  final output = Directory('${root.path}/$_outputDirectory')
    ..createSync(recursive: true);
  final tutorialFile = File('${output.path}/tutorials.json');
  final exampleFile = File('${output.path}/examples.json');
  const encoder = JsonEncoder.withIndent('  ');

  tutorialFile.writeAsStringSync(
    '${jsonEncode({'schemaVersion': 1, 'kind': 'tutorials', 'generatedFrom': _generatedFrom, 'entries': tutorialEntries})}\n',
  );
  exampleFile.writeAsStringSync(
    '${jsonEncode({'schemaVersion': 1, 'kind': 'examples', 'generatedFrom': _generatedFrom, 'entries': exampleEntries})}\n',
  );

  final counts = {
    'tutorials': _counts(tutorialEntries),
    'examples': _counts(exampleEntries),
  };
  final lessonCounts = _lessonCounts(tutorialEntries);
  File('${output.path}/provenance.json').writeAsStringSync(
    '${encoder.convert({
      'schemaVersion': 1,
      'generator': _generatedFrom,
      'policy': 'Each product-owned catalog replaces the shared core aggregate '
          'for the subjects it ships; the shared aggregate is only kept for '
          'subjects no product ships content assets for.',
      'ownedSubjects': ownedSubjects.toList()..sort(_compareSubjects),
      'sources': provenanceSources,
      'outputs': [_outputRecord(tutorialFile, tutorialEntries.length), _outputRecord(exampleFile, exampleEntries.length)],
      'counts': counts,
      'lessonCounts': lessonCounts,
    })}\n',
  );

  stdout.writeln(
    'Composed ${tutorialEntries.length} tutorials and '
    '${exampleEntries.length} examples from '
    '${provenanceSources.length} source files.',
  );
  stdout.writeln('  tutorials by subject: ${jsonEncode(counts['tutorials'])}');
  stdout.writeln('  examples by subject: ${jsonEncode(counts['examples'])}');
  stdout.writeln('  tutorial lessons by subject: ${jsonEncode(lessonCounts)}');
  stdout.writeln(
    'Wrote ${tutorialFile.path}, ${exampleFile.path} and '
    'provenance.json.',
  );
}

bool _isStudioRoot(Directory root) {
  final pubspec = File('${root.path}/pubspec.yaml');
  if (!pubspec.existsSync()) return false;
  return RegExp(
    r'^name:\s*qflistudio\s*$',
    multiLine: true,
  ).hasMatch(pubspec.readAsStringSync());
}

Future<List<Map<String, Object?>>> _absorb(
  _ContentSource source, {
  required _ComposedCatalog tutorials,
  required _ComposedCatalog examples,
  bool shared = false,
  Set<String> ownedSubjects = const <String>{},
}) async {
  final records = <Map<String, Object?>>[];
  for (final (kind, files, catalog)
      in <(String, List<_SourceFile>, _ComposedCatalog)>[
        ('tutorials', source.tutorials, tutorials),
        ('examples', source.examples, examples),
      ]) {
    for (final file in files) {
      final record = await _absorbFile(
        source: source,
        kind: kind,
        file: file,
        catalog: catalog,
        shared: shared,
        ownedSubjects: ownedSubjects,
      );
      records.add(record);
    }
  }
  return records;
}

Future<Map<String, Object?>> _absorbFile({
  required _ContentSource source,
  required String kind,
  required _SourceFile file,
  required _ComposedCatalog catalog,
  required bool shared,
  required Set<String> ownedSubjects,
}) async {
  final absolute = File('${Directory.current.path}/${_normalize(file.path)}');
  if (!absolute.existsSync()) {
    stderr.writeln('Missing source: ${absolute.path}');
    exitCode = 1;
    throw StateError('Missing source ${absolute.path}');
  }
  final bytes = await absolute.readAsBytes();
  final entries = _entriesOf(
    utf8.decode(bytes),
    kind: kind,
    path: absolute.path,
  );
  var added = 0;
  var superseded = 0;
  var duplicateIds = 0;
  final skippedSubjects = <String, int>{};
  final seen = <String>{};
  for (final entry in entries) {
    final id = _id(entry, path: absolute.path, kind: kind);
    if (!seen.add(id)) duplicateIds++;
    final subject = _subjectOf(entry);
    if (shared && ownedSubjects.contains(subject)) {
      skippedSubjects[subject] = (skippedSubjects[subject] ?? 0) + 1;
      continue;
    }
    final existing = catalog.originOf(id);
    if (existing != null) {
      // A higher-precedence source already owns this id.
      superseded++;
      continue;
    }
    catalog.add(id, entry, '${source.product}:${file.repository}/${file.path}');
    added++;
  }
  final sortedSkipped = skippedSubjects.keys.toList()..sort(_compareSubjects);
  return {
    'product': source.product,
    'repository': file.repository,
    'kind': kind,
    'path': file.path,
    'role': shared ? 'shared-fallback' : 'product-owned',
    'bytes': bytes.length,
    'fingerprint': _fingerprint(bytes),
    'entries': entries.length,
    'added': added,
    'supersededByHigherPrecedenceSource': superseded,
    if (shared)
      'skippedByOwnedSubject': {
        for (final subject in sortedSkipped) subject: skippedSubjects[subject],
      },
    if (duplicateIds > 0) 'duplicateIdsInSource': duplicateIds,
  };
}

List<Map<String, Object?>> _entriesOf(
  String source, {
  required String kind,
  required String path,
}) {
  final Object? decoded;
  try {
    decoded = jsonDecode(source);
  } on FormatException catch (error) {
    stderr.writeln('Invalid JSON in $path: ${error.message}');
    exitCode = 1;
    throw StateError('Invalid JSON in $path');
  }
  final List<Object?> raw;
  if (decoded is List) {
    raw = decoded;
  } else if (decoded is Map) {
    final map = decoded.cast<String, Object?>();
    final key = kind == 'tutorials' ? 'tutorials' : 'examples';
    if (map[key] is List) {
      raw = map[key] as List<Object?>;
    } else if (map['entries'] is List) {
      raw = map['entries'] as List<Object?>;
    } else if (kind == 'tutorials' && map['chapters'] is List) {
      raw = [map];
    } else if (kind == 'examples' && map['code'] is String) {
      raw = [map];
    } else {
      raw = const [];
    }
  } else {
    raw = const [];
  }
  final entries = <Map<String, Object?>>[];
  for (var index = 0; index < raw.length; index++) {
    final value = raw[index];
    if (value is! Map) {
      stderr.writeln('$path: $kind[$index] is not an object');
      exitCode = 1;
      throw StateError('$path: $kind[$index] is not an object');
    }
    entries.add(value.cast<String, Object?>());
  }
  return entries;
}

String _id(
  Map<String, Object?> entry, {
  required String path,
  required String kind,
}) {
  final id = entry['id'];
  if (id is! String || id.trim().isEmpty) {
    stderr.writeln('$path: $kind entry without a string id');
    exitCode = 1;
    throw StateError('$path: $kind entry without a string id');
  }
  return id.trim();
}

String _normalize(String path) => path.replaceAll('\\', '/');

String _fingerprint(List<int> bytes) {
  // FNV-1a 32-bit: stable across SDK versions and good enough to detect
  // accidental source drift in the generated provenance record.
  var hash = 0x811c9dc5;
  for (final byte in bytes) {
    hash = (hash ^ byte) & 0xffffffff;
    hash = (hash * 0x01000193) & 0xffffffff;
  }
  return hash.toRadixString(16).padLeft(8, '0');
}

Map<String, Object?> _outputRecord(File file, int entries) {
  final bytes = file.readAsBytesSync();
  return {
    'path': _normalize(file.path.substring(Directory.current.path.length + 1)),
    'bytes': bytes.length,
    'fingerprint': _fingerprint(bytes),
    'entries': entries,
  };
}

Map<String, int> _counts(List<Map<String, Object?>> entries) {
  final result = <String, int>{};
  for (final entry in entries) {
    final subject = _subjectOf(entry);
    result[subject] = (result[subject] ?? 0) + 1;
  }
  final sortedKeys = result.keys.toList()..sort(_compareSubjects);
  return {for (final key in sortedKeys) key: result[key]!};
}

Map<String, int> _lessonCounts(List<Map<String, Object?>> entries) {
  final result = <String, int>{};
  for (final entry in entries) {
    final subject = _subjectOf(entry);
    result[subject] = (result[subject] ?? 0) + _lessonCount(entry);
  }
  final sortedKeys = result.keys.toList()..sort(_compareSubjects);
  return {for (final key in sortedKeys) key: result[key]!};
}

int _lessonCount(Map<String, Object?> entry) {
  final lessons = entry['lessons'];
  if (lessons is List) return lessons.length;
  var count = 0;
  final chapters = entry['chapters'];
  if (chapters is List) {
    for (final chapter in chapters) {
      if (chapter is Map && chapter['lessons'] is List) {
        count += (chapter['lessons'] as List).length;
      }
    }
  }
  return count;
}

String _subjectOf(Map<String, Object?> entry) {
  final language = (entry['language'] as String?)?.trim().toLowerCase() ?? '';
  if (language.isNotEmpty) return language;
  return (entry['type'] as String?)?.trim().toLowerCase() ?? '';
}

int _compareSubjects(String a, String b) {
  final left = _subjects.indexOf(a);
  final right = _subjects.indexOf(b);
  if (left != right) {
    if (left < 0) return 1;
    if (right < 0) return -1;
    return left.compareTo(right);
  }
  return a.compareTo(b);
}

class _ComposedCatalog {
  _ComposedCatalog(this.kind);

  final String kind;
  final Map<String, Map<String, Object?>> _entries = {};
  final Map<String, String> _origins = {};

  void add(String id, Map<String, Object?> entry, String origin) {
    _entries[id] = entry;
    _origins[id] = origin;
  }

  String? originOf(String id) => _origins[id];

  Iterable<Map<String, Object?>> get entries => _entries.values;

  List<Map<String, Object?>> sortedEntries() {
    final ids = _entries.keys.toList()
      ..sort((a, b) {
        final bySubject = _compareSubjects(
          _subjectOf(_entries[a]!),
          _subjectOf(_entries[b]!),
        );
        return bySubject != 0 ? bySubject : a.compareTo(b);
      });
    return [for (final id in ids) _entries[id]!];
  }
}
