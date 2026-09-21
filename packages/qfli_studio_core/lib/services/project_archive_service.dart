import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import '../models/project.dart';
import 'project_config.dart';

class ProjectArchiveException implements Exception {
  const ProjectArchiveException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Portable single-file project archive. Binary files are kept as Base64.
abstract final class ProjectArchiveService {
  static const schemaVersion = 1;

  static Future<String> exportProject(Project project) async {
    final root = Directory(project.path);
    if (!root.existsSync()) {
      throw const ProjectArchiveException('项目目录不存在');
    }
    final files = <Map<String, dynamic>>[];
    await for (final entity in root.list(recursive: true, followLinks: false)) {
      if (entity is! File) continue;
      final relative = _normalize(p.relative(entity.path, from: root.path));
      if (_isTransient(relative)) continue;
      final bytes = await entity.readAsBytes();
      final text = _tryUtf8(bytes);
      files.add({
        'path': relative,
        if (text != null) ...{
          'encoding': 'utf8',
          'content': text,
        } else ...{
          'encoding': 'base64',
          'bytesBase64': base64Encode(bytes),
        },
      });
    }
    files.sort((a, b) => (a['path'] as String).compareTo(b['path'] as String));
    final data = {
      'schemaVersion': schemaVersion,
      'project': project.toJson(),
      'name': project.name,
      'language': project.language,
      'type': project.type,
      'files': files,
    };
    return const JsonEncoder.withIndent('  ').convert(data);
  }

  static Future<void> restoreProject({
    required String source,
    required String targetDirectory,
    bool replaceExisting = false,
  }) async {
    final data = _decode(source);
    final files = data['files'];
    if (files is! List) {
      throw const ProjectArchiveException('归档缺少 files 列表');
    }
    final root = Directory(targetDirectory);
    await root.create(recursive: true);
    final paths = <String>{};
    for (final raw in files) {
      if (raw is! Map) {
        throw const ProjectArchiveException('归档文件项格式不正确');
      }
      final item = Map<String, dynamic>.from(raw);
      final relative = _validateRelative(item['path']);
      if (!paths.add(relative)) {
        throw ProjectArchiveException('归档包含重复路径：$relative');
      }
      final target = File(p.joinAll([root.path, ...relative.split('/')]));
      if (!p.isWithin(root.path, target.path) &&
          p.normalize(root.path) != p.normalize(target.path)) {
        throw const ProjectArchiveException('归档路径越界');
      }
      if (target.existsSync() && !replaceExisting) {
        throw ProjectArchiveException('目标文件已存在：$relative');
      }
      final encoding = item['encoding'];
      final bytes = switch (encoding) {
        'utf8' when item['content'] is String => utf8.encode(item['content'] as String),
        'base64' when item['bytesBase64'] is String => _decodeBase64(item['bytesBase64'] as String),
        _ => throw ProjectArchiveException('文件编码无效：$relative'),
      };
      await target.parent.create(recursive: true);
      await target.writeAsBytes(bytes, flush: true);
    }
    final project = data['project'];
    final metadata = project is Map ? Map<String, dynamic>.from(project) : <String, dynamic>{};
    await ProjectConfig.write(
      projectRoot: root.path,
      name: data['name'] as String? ?? p.basename(root.path),
      language: data['language'] as String? ?? metadata['language'] as String? ?? '',
      type: data['type'] as String? ?? metadata['type'] as String? ?? '',
    );
  }

  static Map<String, dynamic> _decode(String source) {
    try {
      final value = jsonDecode(source);
      if (value is! Map) throw const FormatException();
      return Map<String, dynamic>.from(value);
    } on Object {
      throw const ProjectArchiveException('项目归档不是合法 JSON');
    }
  }

  static String _validateRelative(Object? value) {
    if (value is! String || value.trim().isEmpty) {
      throw const ProjectArchiveException('归档包含空路径');
    }
    final relative = _normalize(value);
    if (p.isAbsolute(relative) || relative == '.' || relative.startsWith('../') || relative.contains('/../')) {
      throw ProjectArchiveException('归档路径越界：$value');
    }
    return relative;
  }

  static String _normalize(String value) => value.replaceAll(r'\', '/');

  static List<int> _decodeBase64(String value) {
    try {
      return base64Decode(value);
    } on FormatException {
      throw const ProjectArchiveException('归档包含无效 Base64 数据');
    }
  }

  static String? _tryUtf8(List<int> bytes) {
    if (bytes.contains(0)) return null;
    try {
      final text = utf8.decode(bytes);
      return text;
    } on FormatException {
      return null;
    }
  }

  static bool _isTransient(String path) {
    final parts = path.split('/');
    return parts.any((part) =>
        part == '.dart_tool' || part == 'build' || part == '.idea' || part == '.git');
  }
}
