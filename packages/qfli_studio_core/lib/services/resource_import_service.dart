import 'dart:io';

import 'package:path/path.dart' as p;

import 'picker_service.dart';

typedef ResourceConflictResolver = Future<bool> Function(String name);

class ResourceImportResult {
  const ResourceImportResult({
    required this.imported,
    required this.skipped,
    required this.errors,
  });

  final int imported;
  final int skipped;
  final List<String> errors;
}

/// Copies files selected by the platform picker into a project directory.
abstract final class ResourceImportService {
  static Future<ResourceImportResult> importDocuments({
    required List<PickedDocument> documents,
    required String destinationDirectory,
    required ResourceConflictResolver resolveConflict,
  }) async {
    await Directory(destinationDirectory).create(recursive: true);
    var imported = 0;
    var skipped = 0;
    final errors = <String>[];
    for (var index = 0; index < documents.length; index++) {
      final document = documents[index];
      final name = _safeName(document, index);
      final destination = File(p.join(destinationDirectory, name));
      try {
        if (destination.existsSync()) {
          if (!await resolveConflict(name)) {
            skipped++;
            continue;
          }
        }
        final bytes = await _read(document);
        await destination.writeAsBytes(bytes, flush: true);
        imported++;
      } on Object catch (error) {
        errors.add('$name: $error');
      }
    }
    return ResourceImportResult(
      imported: imported,
      skipped: skipped,
      errors: errors,
    );
  }

  static Future<List<int>> _read(PickedDocument document) async {
    final path = document.path;
    if (path != null && path.isNotEmpty) return File(path).readAsBytes();
    final uri = document.uri;
    if (uri != null && uri.isNotEmpty) return PickerService.readUri(uri);
    throw const FileSystemException('系统未返回可读资源');
  }

  static String _safeName(PickedDocument document, int index) {
    final source = document.name ??
        (document.path == null ? '' : p.basename(document.path!));
    final name = p.basename(source).trim();
    if (name.isEmpty || name == '.' || name == '..' || _illegalName.hasMatch(name)) {
      return 'resource_${index + 1}';
    }
    return name;
  }

  static final _illegalName = RegExp(r'[\\/:*?"<>|]');
}
