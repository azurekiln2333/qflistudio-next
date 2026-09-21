import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

import '../models/tutorial.dart';

/// JSON-backed user examples layered over bundled defaults.
class ExampleCodeStore extends ChangeNotifier {
  ExampleCodeStore({File? storageFile}) : _storageOverride = storageFile;

  final File? _storageOverride;
  File? _storage;
  final Map<String, ExampleCode> _defaults = {};
  final Map<String, ExampleCode> _custom = {};

  List<ExampleCode> get items => [
    ..._defaults.keys.map((id) => _custom[id] ?? _defaults[id]!),
    ..._custom.entries
        .where((entry) => !_defaults.containsKey(entry.key))
        .map((entry) => entry.value),
  ];

  void seed(Iterable<ExampleCode> defaults) {
    for (final example in defaults) {
      _defaults[example.id] = example;
    }
  }

  Future<void> load({Iterable<ExampleCode> defaults = const []}) async {
    seed(defaults);
    _storage = _storageOverride;
    if (_storage == null || !await _storage!.exists()) return;
    try {
      final data = jsonDecode(await _storage!.readAsString());
      if (data is! Map || data['examples'] is! List) return;
      for (final raw in data['examples'] as List) {
        if (raw is! Map) continue;
        final example = _fromJson(Map<String, dynamic>.from(raw));
        if (example != null) _custom[example.id] = example;
      }
    } on Object {
      _custom.clear();
    }
    notifyListeners();
  }

  Future<void> upsert(ExampleCode example) async {
    _custom[example.id] = example;
    notifyListeners();
    await _persist();
  }

  Future<void> reset(String id) async {
    _custom.remove(id);
    notifyListeners();
    await _persist();
  }

  Map<String, dynamic> toJson() => {
    'schemaVersion': 1,
    'examples': [for (final example in _custom.values) _toJson(example)],
  };

  String encode() => const JsonEncoder.withIndent('  ').convert(toJson());

  Future<void> importJson(String source) async {
    final decoded = jsonDecode(source);
    if (decoded is! Map || decoded['examples'] is! List) {
      throw const FormatException('示例 JSON 缺少 examples 列表');
    }
    final imported = <String, ExampleCode>{};
    for (final raw in decoded['examples'] as List) {
      if (raw is! Map) continue;
      final example = _fromJson(Map<String, dynamic>.from(raw));
      if (example == null || example.type.isEmpty) continue;
      imported[example.id] = example;
    }
    _custom
      ..clear()
      ..addAll(imported);
    notifyListeners();
    await _persist();
  }

  Future<void> _persist() async {
    final file = _storage;
    if (file == null) return;
    await file.parent.create(recursive: true);
    await file.writeAsString(encode());
  }

  static Map<String, dynamic> _toJson(ExampleCode example) => {
    'id': example.id,
    'type': example.type,
    'title': example.title,
    'summary': example.summary,
    'code': example.code,
    'output': example.output,
    if (example.sourceLessonId != null) 'sourceLessonId': example.sourceLessonId,
  };

  static ExampleCode? _fromJson(Map<String, dynamic> json) {
    final id = json['id'] as String?;
    final type = json['type'] as String?;
    final title = json['title'] as String?;
    final code = json['code'] as String?;
    if (id == null || type == null || title == null || code == null) return null;
    return ExampleCode(
      id: id,
      type: type,
      title: title,
      summary: json['summary'] as String? ?? '',
      code: code,
      output: json['output'] as String? ?? '',
      sourceLessonId: json['sourceLessonId'] as String?,
    );
  }
}
