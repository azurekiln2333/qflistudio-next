import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:qfli_studio_core/services/studio_profile.dart';

import 'package:qfli_sql/sql_runner.dart';

void main() {
  group('SqlProgramRunner', () {
    test('does not claim SQL ran without an in-process SQLite engine', () async {
      final project = await Directory.systemTemp.createTemp('qfli_sql_test_');
      addTearDown(() => project.delete(recursive: true));
      final entry = File(p.join(project.path, 'main.sql'))
        ..writeAsStringSync('SELECT 1;');

      final result = await const SqlProgramRunner().run(
        projectPath: project.path,
        entryFile: entry.path,
      );

      expect(result, isNotNull);
      expect(result!.title, contains('SQLite 运行时不可用'));
      expect(await result.stdout.toList(), isEmpty);
      expect(await result.stderr.toList(), [
        UnavailableSqliteEngine.message,
      ]);
      expect(await result.exitCode, kProgramNotRunExitCode);
    });

    test('returns null for files outside the SQL backend', () async {
      final result = await const SqlProgramRunner().run(
        projectPath: r'C:\projects\demo',
        entryFile: r'C:\projects\demo\main.py',
      );

      expect(result, isNull);
    });

    test('passes the source and project database boundary to an engine', () async {
      final project = await Directory.systemTemp.createTemp('qfli_sql_test_');
      addTearDown(() => project.delete(recursive: true));
      final entry = File(p.join(project.path, 'main.SQL'))
        ..writeAsStringSync('SELECT 1 AS id;');
      final engine = _RecordingEngine();

      final result = await SqlProgramRunner(engine: engine).run(
        projectPath: project.path,
        entryFile: entry.path,
      );

      expect(engine.request, isNotNull);
      expect(engine.request!.projectPath, project.path);
      expect(engine.request!.databasePath,
          p.join(project.path, '.qfli', 'data.sqlite'));
      expect(engine.request!.source, 'SELECT 1 AS id;');
      expect(await result!.stdout.toList(), ['1 | Ada']);
      expect(await result.stderr.toList(), isEmpty);
      expect(await result.exitCode, 0);
      expect(result.title, contains('应用内 SQLite'));
    });
  });
}

class _RecordingEngine implements SqliteEngine {
  SqliteRequest? request;

  @override
  Future<SqliteExecutionResult> execute(SqliteRequest request) async {
    this.request = request;
    return const SqliteExecutionResult(
      available: true,
      stdout: ['1 | Ada'],
      stderr: [],
      exitCode: 0,
    );
  }
}
