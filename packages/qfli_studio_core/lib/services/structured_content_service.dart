import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;

class JsonAnalysis {
  const JsonAnalysis({
    required this.valid,
    required this.formatted,
    this.value,
    this.error,
  });

  final bool valid;
  final String formatted;
  final Object? value;
  final String? error;
}

abstract final class JsonDocumentService {
  static JsonAnalysis analyze(String source) {
    try {
      final value = jsonDecode(source);
      final formatted = const JsonEncoder.withIndent('  ').convert(value);
      return JsonAnalysis(valid: true, formatted: formatted, value: value);
    } on FormatException catch (error) {
      return JsonAnalysis(
        valid: false,
        formatted: source,
        error: error.message,
      );
    }
  }

  static String nodeLabel(Object? value) => switch (value) {
    null => 'null',
    Map _ => 'object',
    List _ => 'array',
    String _ => 'string',
    num _ => 'number',
    bool _ => 'boolean',
    _ => 'value',
  };
}

class SqlExecutionResult {
  const SqlExecutionResult({
    required this.available,
    required this.exitCode,
    required this.output,
    this.error,
  });

  final bool available;
  final int exitCode;
  final String output;
  final String? error;
}

abstract final class SqlQueryService {
  static const MethodChannel _channel = MethodChannel('qfli_sql/native');

  static Future<SqlExecutionResult> execute({
    required String source,
    String? projectPath,
  }) async {
    final database = projectPath == null || projectPath.isEmpty
        ? ':memory:'
        : p.join(projectPath, '.qfli', 'data.sqlite');
    try {
      final raw = await _channel.invokeMethod<Object?>('execute', {
        'source': source,
        'databasePath': database,
      });
      if (raw is! Map) {
        return const SqlExecutionResult(
          available: false,
          exitCode: 127,
          output: '',
          error: 'SQLite 原生桥返回了无效响应。',
        );
      }
      final available = raw['available'] == true;
      final output = '${raw['output'] ?? ''}';
      final error = raw['error'] == null ? null : '${raw['error']}';
      final exitCode = raw['exitCode'] is num
          ? (raw['exitCode'] as num).toInt()
          : (available ? 0 : 127);
      return SqlExecutionResult(
        available: available,
        exitCode: available ? exitCode : 127,
        output: output,
        error: error,
      );
    } on MissingPluginException {
      return SqlExecutionResult(
        available: false,
        exitCode: 127,
        output: '',
        error: 'SQLite 原生桥未安装；当前构建不能执行 SQL。',
      );
    } on PlatformException catch (error) {
      return SqlExecutionResult(
        available: false,
        exitCode: 127,
        output: '',
        error: 'SQLite 原生桥调用失败：${error.message ?? error.code}',
      );
    }
  }
}
