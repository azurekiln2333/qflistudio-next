import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:qfli_studio_core/services/studio_profile.dart';

/// 一次待交给 SQLite 后端执行的项目查询。
///
/// [databasePath] 是未来原生 SQLite 后端应打开的项目数据库位置。运行器只
/// 定义边界，不自行创建文件，也不把外部 sqlite3 命令当作移动端实现。
class SqliteRequest {
  const SqliteRequest({
    required this.projectPath,
    required this.source,
  });

  final String projectPath;
  final String source;

  String get databasePath => p.join(projectPath, '.qfli', 'data.sqlite');
}

/// SQLite 执行后端的最小边界。
///
/// 原生实现接入后应在当前进程内打开 [SqliteRequest.databasePath]，执行
/// [SqliteRequest.source]，并把查询输出与 SQLite 错误分别返回。不能通过
/// 启动外部 sqlite3 进程来满足这个接口。
abstract interface class SqliteEngine {
  Future<SqliteExecutionResult> execute(SqliteRequest request);
}

class SqliteExecutionResult {
  const SqliteExecutionResult({
    required this.available,
    required this.stdout,
    required this.stderr,
    required this.exitCode,
  });

  final bool available;
  final Iterable<String> stdout;
  final Iterable<String> stderr;
  final int exitCode;
}

/// Default until an in-process SQLite implementation is bundled.
///
/// Returning an unavailable result is intentional: SQL must not look successful
/// while the app has no SQLite engine to execute it.
class UnavailableSqliteEngine implements SqliteEngine {
  const UnavailableSqliteEngine();

  static const message = 'SQLite 运行时不可用：当前 App 未捆绑进程内 SQLite 引擎。';

  @override
  Future<SqliteExecutionResult> execute(SqliteRequest request) async {
    return const SqliteExecutionResult(
      available: false,
      stdout: <String>[],
      stderr: <String>[message],
      exitCode: kProgramNotRunExitCode,
    );
  }
}

/// SQL 版 App 的运行后端。
class SqlProgramRunner implements ProgramRunner {
  const SqlProgramRunner({
    this.engine = const UnavailableSqliteEngine(),
  });

  /// The engine is injectable so the native SQLite boundary can be tested
  /// without starting an external process.
  final SqliteEngine engine;

  /// 本后端接管的源码后缀。
  static const Set<String> _sourceExtensions = {'.sql'};

  @override
  Future<ProgramRunResult?> run({
    required String projectPath,
    required String entryFile,
  }) async {
    if (!_sourceExtensions.contains(p.extension(entryFile).toLowerCase())) {
      return null;
    }

    final String source;
    try {
      source = await File(entryFile).readAsString();
    } on FileSystemException catch (error) {
      return _failure(p.basename(entryFile), '无法读取 SQL 文件：${error.message}');
    }

    final request = SqliteRequest(
      projectPath: projectPath,
      source: source,
    );
    final result = await engine.execute(request);
    final available = result.available;
    return ProgramRunResult(
      title: available
          ? '运行 ${p.basename(entryFile)}（应用内 SQLite）'
          : '运行 ${p.basename(entryFile)}（SQLite 运行时不可用）',
      stdout: Stream<String>.fromIterable(result.stdout),
      stderr: Stream<String>.fromIterable(result.stderr),
      exitCode: Future<int>.value(
        available ? result.exitCode : kProgramNotRunExitCode,
      ),
    );
  }

  ProgramRunResult _failure(String fileName, String message) {
    return ProgramRunResult(
      title: '运行 $fileName',
      stdout: const Stream<String>.empty(),
      stderr: Stream<String>.value(message),
      exitCode: Future<int>.value(kProgramNotRunExitCode),
    );
  }
}
