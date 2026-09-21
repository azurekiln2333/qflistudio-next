import 'dart:convert';
import 'dart:io';

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
  static Future<SqlExecutionResult> execute({
    required String source,
    String? projectPath,
  }) async {
    if (!Platform.isWindows && !Platform.isLinux && !Platform.isMacOS) {
      return const SqlExecutionResult(
        available: false,
        exitCode: 127,
        output: '',
        error: 'SQLite command-line runtime is unavailable on this platform.',
      );
    }
    final probe = await Process.run(
      Platform.isWindows ? 'where' : 'which',
      ['sqlite3'],
      runInShell: Platform.isWindows,
    );
    if (probe.exitCode != 0) {
      return const SqlExecutionResult(
        available: false,
        exitCode: 127,
        output: '',
        error: 'sqlite3 was not found on the desktop.',
      );
    }
    final database = projectPath == null || projectPath.isEmpty
        ? ':memory:'
        : p.join(projectPath, '.qfli', 'data.sqlite');
    try {
      final process = await Process.start(
        'sqlite3',
        ['-header', '-column', database],
        workingDirectory: projectPath,
        runInShell: Platform.isWindows,
      );
      process.stdin.write(source);
      await process.stdin.close();
      final stdout = await process.stdout
          .transform(utf8.decoder)
          .join();
      final stderr = await process.stderr
          .transform(utf8.decoder)
          .join();
      final exitCode = await process.exitCode;
      return SqlExecutionResult(
        available: true,
        exitCode: exitCode,
        output: stdout,
        error: stderr.isEmpty ? null : stderr,
      );
    } on ProcessException catch (error) {
      return SqlExecutionResult(
        available: false,
        exitCode: 127,
        output: '',
        error: error.message,
      );
    }
  }
}
