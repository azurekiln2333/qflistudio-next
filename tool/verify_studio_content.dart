// Verifies the QFLIStudio+ composed content assets against their authoritative
// product sources.
//
// Unlike `tool/validate_content.dart` (which releases the shared aggregate and
// therefore enforces a per-`type` minimum), the main app groups content by
// subject (`language`): WebForge deliberately keeps executable `type: html`
// for its CSS/JavaScript subjects, and Lua/Markdown ship fewer, richer groups
// than the shared generated aggregate. This tool checks the contracts that
// matter for the main catalog:
//
// - every entry from every product-owned source file is present verbatim;
// - the shared aggregate is kept only for subjects no product ships;
// - ids are unique, required metadata exists and lessons are non-empty;
// - `provenance.json` counts match the generated documents.
//
//   dart run tool/verify_studio_content.dart
//
// Exits non-zero on any problem.

import 'dart:convert';
import 'dart:io';

import 'package:qfli_studio_core/content/content_repository.dart';
import 'package:qfli_studio_core/content/content_validator.dart';

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

/// Subjects that only the shared core aggregate ships today. Java and Python
/// products have no content assets and consume the aggregate directly.
const _sharedOnlySubjects = <String>{'java', 'python', 'typescript', 'shell'};

void main() {
  final root = Directory.current;
  final content = Directory('${root.path}/assets/content');
  final tutorialsFile = File('${content.path}/tutorials.json');
  final examplesFile = File('${content.path}/examples.json');
  final provenanceFile = File('${content.path}/provenance.json');
  for (final file in [tutorialsFile, examplesFile, provenanceFile]) {
    if (!file.existsSync()) {
      stderr.writeln(
        'Missing ${file.path}. Run `dart run tool/generate_studio_content.dart`.',
      );
      exitCode = 1;
      return;
    }
  }

  final tutorialsSource = tutorialsFile.readAsStringSync();
  final examplesSource = examplesFile.readAsStringSync();
  final catalog = ContentCatalog.fromJson(
    tutorialsSource: tutorialsSource,
    examplesSource: examplesSource,
  );
  final composedEntries = <String, Map<String, Map<String, Object?>>>{
    'tutorials': {
      for (final entry in _entriesOf(
        tutorialsSource,
        'tutorials',
        tutorialsFile.path,
      ))
        if (entry['id'] is String) entry['id'] as String: entry,
    },
    'examples': {
      for (final entry in _entriesOf(
        examplesSource,
        'examples',
        examplesFile.path,
      ))
        if (entry['id'] is String) entry['id'] as String: entry,
    },
  };
  final provenance =
      jsonDecode(provenanceFile.readAsStringSync()) as Map<String, Object?>;
  final issues = <String>[];

  for (final issue in ContentCatalogValidator.validate(catalog).issues) {
    issues.add('validation: $issue');
  }

  final tutorialSubjects = _subjectCounts(catalog.tutorials);
  final exampleSubjects = _subjectCounts(catalog.examples);
  for (final subject in _subjects) {
    if ((tutorialSubjects[subject] ?? 0) == 0) {
      issues.add('tutorials: subject "$subject" is empty');
    }
    if ((exampleSubjects[subject] ?? 0) == 0) {
      issues.add('examples: subject "$subject" is empty');
    }
  }
  for (final subject in tutorialSubjects.keys) {
    if (!_subjects.contains(subject)) {
      issues.add('tutorials: unknown subject "$subject"');
    }
  }
  for (final subject in exampleSubjects.keys) {
    if (!_subjects.contains(subject)) {
      issues.add('examples: unknown subject "$subject"');
    }
  }

  final ownedSubjects = _stringSet(provenance['ownedSubjects']);
  for (final subject in _sharedOnlySubjects) {
    if (ownedSubjects.contains(subject)) {
      issues.add(
        'provenance: "$subject" is shared-only but a product source claims it',
      );
    }
  }

  final tutorialIds = catalog.tutorials.map((entry) => entry.id).toSet();
  final exampleIds = catalog.examples.map((entry) => entry.id).toSet();
  final sources =
      (provenance['sources'] as List?)?.cast<Map<String, Object?>>() ??
      const <Map<String, Object?>>[];
  if (sources.isEmpty) issues.add('provenance: no source records');

  // First pass: every product-owned entry must be present verbatim. Also keep
  // the product id set per kind so the shared fallback check can tell
  // "replaced by the same id" from "dropped stale generated entry".
  final productIds = <String, Set<String>>{
    'tutorials': <String>{},
    'examples': <String>{},
  };
  final sourceEntries = <(Map<String, Object?>, List<Map<String, Object?>>)>[];
  for (final source in sources) {
    final kind = source['kind'];
    final role = source['role'];
    final path = source['path'];
    if (kind is! String || role is! String || path is! String) {
      issues.add('provenance: malformed source record $source');
      continue;
    }
    final file = File('${root.path}/$path');
    if (!file.existsSync()) {
      issues.add('provenance: source file $path is missing');
      continue;
    }
    final entries = _entriesOf(file.readAsStringSync(), kind, path);
    sourceEntries.add((source, entries));
    if (role != 'product-owned') continue;
    final composed = kind == 'tutorials' ? tutorialIds : exampleIds;
    for (final entry in entries) {
      final id = entry['id'];
      if (id is! String || id.isEmpty) {
        issues.add('$path: entry without an id');
        continue;
      }
      productIds[kind]!.add(id);
      if (!composed.contains(id)) {
        issues.add('$path: product entry "$id" is missing from $kind');
      }
    }
  }

  // Second pass: shared entries are kept only for subjects no product owns.
  var productEntries = 0;
  var sharedFallbackEntries = 0;
  for (final (source, entries) in sourceEntries) {
    final kind = source['kind'] as String;
    final role = source['role'] as String;
    final path = source['path'] as String;
    final composed = kind == 'tutorials' ? tutorialIds : exampleIds;
    for (final entry in entries) {
      final id = entry['id'];
      if (id is! String || id.isEmpty) continue;
      final subject = _subjectOf(entry);
      if (role == 'product-owned') {
        productEntries++;
        final actual = composedEntries[kind]?[id];
        if (actual != null && _canonicalJson(actual) != _canonicalJson(entry)) {
          issues.add('$path: product entry "$id" differs from its source');
        }
        continue;
      }
      sharedFallbackEntries++;
      final replaced = ownedSubjects.contains(subject);
      if (replaced) {
        if (productIds[kind]!.contains(id)) {
          if (!composed.contains(id)) {
            issues.add('$path: shared entry "$id" was not replaced');
          }
        } else if (composed.contains(id)) {
          issues.add(
            '$path: stale shared entry "$id" ($subject) survived even though '
            'a product owns the subject',
          );
        }
      } else if (!composed.contains(id)) {
        issues.add('$path: fallback entry "$id" ($subject) is missing');
      } else if (_canonicalJson(composedEntries[kind]![id]) !=
          _canonicalJson(entry)) {
        issues.add('$path: fallback entry "$id" differs from its source');
      }
    }
  }

  final counts = provenance['counts'];
  if (counts is! Map) {
    issues.add('provenance: missing counts');
  } else {
    final tutorialCounts = counts['tutorials'];
    final exampleCounts = counts['examples'];
    if (tutorialCounts is Map && exampleCounts is Map) {
      if (_sum(tutorialCounts) != catalog.tutorials.length) {
        issues.add(
          'provenance: tutorial count ${_sum(tutorialCounts)} != '
          '${catalog.tutorials.length}',
        );
      }
      if (_sum(exampleCounts) != catalog.examples.length) {
        issues.add(
          'provenance: example count ${_sum(exampleCounts)} != '
          '${catalog.examples.length}',
        );
      }
      if (!_mapEquals(tutorialCounts, tutorialSubjects)) {
        issues.add('provenance: tutorial subject counts do not match assets');
      }
      if (!_mapEquals(exampleCounts, exampleSubjects)) {
        issues.add('provenance: example subject counts do not match assets');
      }
      final lessonCounts = provenance['lessonCounts'];
      if (lessonCounts is Map &&
          !_mapEquals(lessonCounts, _lessonCounts(catalog.tutorials))) {
        issues.add('provenance: tutorial lesson counts do not match assets');
      }
    } else {
      issues.add('provenance: counts must contain tutorials and examples');
    }
  }

  stdout.writeln(
    'Composed catalog: ${catalog.tutorials.length} tutorials, '
    '${catalog.examples.length} examples.',
  );
  stdout.writeln('Tutorials by subject: ${jsonEncode(tutorialSubjects)}');
  stdout.writeln('Examples by subject: ${jsonEncode(exampleSubjects)}');
  stdout.writeln(
    'Tutorials by type: ${jsonEncode(_typeCounts(catalog.tutorials))}',
  );
  stdout.writeln(
    'Examples by type: ${jsonEncode(_typeCounts(catalog.examples))}',
  );
  stdout.writeln(
    'Sources: ${sources.length} files, $productEntries product-owned entries, '
    '$sharedFallbackEntries shared entries.',
  );
  stdout.writeln(
    'Owned subjects: ${(ownedSubjects.toList()..sort()).join(', ')}',
  );

  if (issues.isEmpty) {
    stdout.writeln(
      'PASS: composed assets match every product-owned source and keep only '
      'the shared fallback subjects.',
    );
    exitCode = 0;
    return;
  }
  stderr.writeln('FAIL: ${issues.length} issue(s).');
  for (final issue in issues.take(100)) {
    stderr.writeln('  - $issue');
  }
  exitCode = 1;
}

List<Map<String, Object?>> _entriesOf(String source, String kind, String path) {
  final decoded = jsonDecode(source);
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
      continue;
    }
    entries.add(value.cast<String, Object?>());
  }
  return entries;
}

String _subjectOf(Map<String, Object?> entry) {
  final language = (entry['language'] as String?)?.trim().toLowerCase() ?? '';
  if (language.isNotEmpty) return language;
  return (entry['type'] as String?)?.trim().toLowerCase() ?? '';
}

Set<String> _stringSet(Object? value) => {
  if (value is List)
    for (final item in value)
      if (item is String) item,
};

Map<String, int> _subjectCounts(List<ContentEntry> entries) {
  final counts = <String, int>{};
  for (final entry in entries) {
    final subject = entry.language.trim().isNotEmpty
        ? entry.language.trim().toLowerCase()
        : entry.type.trim().toLowerCase();
    counts[subject] = (counts[subject] ?? 0) + 1;
  }
  final keys = counts.keys.toList()..sort();
  return {for (final key in keys) key: counts[key]!};
}

Map<String, int> _lessonCounts(List<TutorialContent> entries) {
  final counts = <String, int>{};
  for (final entry in entries) {
    final subject = entry.language.trim().isNotEmpty
        ? entry.language.trim().toLowerCase()
        : entry.type.trim().toLowerCase();
    counts[subject] = (counts[subject] ?? 0) + entry.lessons.length;
  }
  final keys = counts.keys.toList()..sort();
  return {for (final key in keys) key: counts[key]!};
}

Map<String, int> _typeCounts(List<ContentEntry> entries) {
  final counts = <String, int>{};
  for (final entry in entries) {
    final type = entry.type.trim().toLowerCase();
    counts[type] = (counts[type] ?? 0) + 1;
  }
  final keys = counts.keys.toList()..sort();
  return {for (final key in keys) key: counts[key]!};
}

int _sum(Map<dynamic, dynamic> counts) =>
    counts.values.fold<int>(0, (sum, value) => sum + (value as int));

bool _mapEquals(Map<dynamic, dynamic> left, Map<String, int> right) {
  if (left.length != right.length) return false;
  for (final entry in right.entries) {
    if (left[entry.key] != entry.value) return false;
  }
  return true;
}

// Object key order is immaterial; list order and every source field are not.
String _canonicalJson(Object? value) => jsonEncode(_canonicalValue(value));

Object? _canonicalValue(Object? value) {
  if (value is List) return value.map(_canonicalValue).toList();
  if (value is Map) {
    final keys = value.keys.cast<String>().toList()..sort();
    return {for (final key in keys) key: _canonicalValue(value[key])};
  }
  return value;
}
