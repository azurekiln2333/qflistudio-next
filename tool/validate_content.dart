import 'dart:convert';
import 'dart:io';

import 'package:qfli_studio_core/content/content_repository.dart';
import 'package:qfli_studio_core/content/content_validator.dart';

Future<void> main() async {
  final root = Directory.current.path;
  final tutorials = await File(
    '$root/../qfli_studio_core/assets/content/tutorials.json',
  ).readAsString();
  final examples = await File(
    '$root/../qfli_studio_core/assets/content/examples.json',
  ).readAsString();
  final catalog = ContentCatalog.fromJson(
    tutorialsSource: tutorials,
    examplesSource: examples,
  );
  final result = ContentCatalogValidator.validateForRelease(catalog);
  if (!result.isValid) {
    stderr.writeln('FAIL: content catalog has ${result.issues.length} issues.');
    for (final issue in result.issues.take(100)) stderr.writeln('  - $issue');
    exitCode = 1;
    return;
  }
  final counts = <String, Map<String, int>>{};
  for (final type in ContentProductTypes.all) {
    counts[type] = {
      'tutorials': catalog.tutorials.where((item) => item.type == type).length,
      'examples': catalog.examples.where((item) => item.type == type).length,
    };
  }
  stdout.writeln(
    'PASS: ${catalog.tutorials.length} tutorials, '
    '${catalog.examples.length} examples; counts=${jsonEncode(counts)}',
  );
}
