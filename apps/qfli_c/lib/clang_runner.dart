import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:qfli_studio_core/services/app_paths.dart';
import 'package:qfli_studio_core/services/process_supervisor.dart';
import 'package:qfli_studio_core/services/studio_profile.dart';

/// Shared C/C++ backend for QFLIForge.
///
/// C and C++ use the same Clang driver boundary. The driver mode and standard
/// differ by file type, but diagnostics, source collection, output limits and
/// process ownership are shared. HarmonyOS is intentionally native-channel
/// only: a desktop executable must never be launched from an app sandbox.
class ClangProgramRunner implements ProgramRunner {
  ClangProgramRunner({ProcessSupervisor? supervisor})
    : _supervisor = supervisor ?? ProcessSupervisor();

  static const _nativeChannel = MethodChannel('qfli_forge/native');
  static const _extensions = <String>{
    '.c',
    '.cpp',
    '.cc',
    '.cxx',
    '.h',
    '.hpp',
    '.hh',
  };

  final ProcessSupervisor _supervisor;

  @override
  Future<ProgramRunResult?> run({
    required String projectPath,
    required String entryFile,
  }) async {
    final extension = p.extension(entryFile).toLowerCase();
    if (!_extensions.contains(extension)) return null;
    final type = extension == '.c' || extension == '.h' ? 'c' : 'cpp';
    if (AppPaths.isDesktop) {
      final compiler = await _findCompiler(type);
      if (compiler == null) {
        return type == 'c' ? null : _unavailable('找不到 clang++，已保留 C++ 项目但未执行。');
      }
      return _runDesktop(
        compiler: compiler,
        type: type,
        projectPath: projectPath,
        entryFile: entryFile,
      );
    }
    return _runNative(
      type: type,
      projectPath: projectPath,
      entryFile: entryFile,
    );
  }

  Future<String?> _findCompiler(String type) async {
    final configured =
        Platform.environment[type == 'c' ? 'QFLI_CLANG' : 'QFLI_CLANGXX'];
    final candidates = <String>[
      if (configured != null && configured.isNotEmpty) configured,
      type == 'c' ? 'clang' : 'clang++',
    ];
    for (final candidate in candidates) {
      try {
        final result = await Process.run(candidate, const ['--version']);
        if (result.exitCode == 0) return candidate;
      } on ProcessException {
        // Try the next configured driver.
      }
    }
    return null;
  }

  ProgramRunResult _runDesktop({
    required String compiler,
    required String type,
    required String projectPath,
    required String entryFile,
  }) {
    final stdout = StreamController<String>();
    final stderr = StreamController<String>();
    final exitCode = Completer<int>();
    var cancelled = false;
    ManagedProcess? current;
    final done = Completer<void>();

    Future<void> start() async {
      try {
        final sources = _collectSources(projectPath, type);
        final build = Directory(p.join(projectPath, '.qfli', 'build', 'forge'))
          ..createSync(recursive: true);
        final output = p.join(
          build.path,
          Platform.isWindows ? 'program.exe' : 'program',
        );
        final compile = await _supervisor.start(
          compiler,
          <String>[
            type == 'c' ? '-std=c17' : '-std=c++20',
            '-I',
            projectPath,
            ...sources,
            '-o',
            output,
          ],
          workingDirectory: projectPath,
          runInShell: Platform.isWindows,
        );
        current = compile;
        if (cancelled) {
          await compile.cancel();
          return _finish(exitCode, 130);
        }
        await Future.wait([
          _pipe(compile.stdout, stderr),
          _pipe(compile.stderr, stderr),
        ]);
        final compileCode = await compile.exitCode;
        if (compileCode != 0) return _finish(exitCode, compileCode);

        final program = await _supervisor.start(
          output,
          const [],
          workingDirectory: projectPath,
          runInShell: Platform.isWindows,
        );
        current = program;
        if (cancelled) {
          await program.cancel();
          return _finish(exitCode, 130);
        }
        final input = File(p.join(projectPath, 'input.txt'));
        if (input.existsSync()) program.stdin.write(await input.readAsString());
        await program.stdin.close();
        await Future.wait([
          _pipe(program.stdout, stdout),
          _pipe(program.stderr, stderr),
        ]);
        _finish(exitCode, await program.exitCode);
      } on ProcessException catch (error) {
        stderr.add(error.message);
        _finish(exitCode, kProgramNotRunExitCode);
      } catch (error) {
        stderr.add('$error');
        _finish(exitCode, kProgramNotRunExitCode);
      } finally {
        await stdout.close();
        await stderr.close();
        if (!done.isCompleted) done.complete();
      }
    }

    unawaited(start());
    return ProgramRunResult(
      title: '运行 ${p.basename(entryFile)}（Clang $type）',
      stdout: stdout.stream,
      stderr: stderr.stream,
      exitCode: exitCode.future,
      cancel: () async {
        cancelled = true;
        await current?.cancel();
        await done.future;
      },
    );
  }

  Future<ProgramRunResult?> _runNative({
    required String type,
    required String projectPath,
    required String entryFile,
  }) async {
    final stdout = StreamController<String>();
    final stderr = StreamController<String>();
    final result = Completer<int>();
    var fallbackToC = false;
    try {
      final raw = await _nativeChannel.invokeMethod<Object?>('run', {
        'type': type,
        'projectPath': projectPath,
        'entryFile': entryFile,
      });
      if (raw is Map && raw['available'] == true) {
        _addLines(stdout, '${raw['output'] ?? ''}');
        _addLines(stderr, '${raw['error'] ?? ''}');
        result.complete(
          raw['exitCode'] is num ? (raw['exitCode'] as num).toInt() : 0,
        );
      } else {
        fallbackToC = type == 'c';
        if (!fallbackToC) {
          _addLines(stderr, 'QFLIForge 的 HarmonyOS Clang native bridge 未安装。');
          result.complete(kProgramNotRunExitCode);
        }
      }
    } on MissingPluginException {
      fallbackToC = type == 'c';
      if (!fallbackToC) {
        _addLines(stderr, 'QFLIForge 的 HarmonyOS Clang native bridge 未安装。');
        result.complete(kProgramNotRunExitCode);
      }
    } on PlatformException catch (error) {
      _addLines(stderr, error.message ?? error.code);
      result.complete(kProgramNotRunExitCode);
    } finally {
      await stdout.close();
      await stderr.close();
    }
    if (fallbackToC) return null;
    return ProgramRunResult(
      title: '运行 ${p.basename(entryFile)}（HarmonyOS Clang $type）',
      stdout: stdout.stream,
      stderr: stderr.stream,
      exitCode: result.future,
    );
  }

  List<String> _collectSources(String projectPath, String type) {
    final extensions = type == 'c'
        ? const {'.c'}
        : const {'.cpp', '.cc', '.cxx', '.c'};
    final root = Directory(projectPath);
    final sources = <String>[];
    if (!root.existsSync()) return sources;
    for (final entity in root.listSync(recursive: true, followLinks: false)) {
      if (entity is File &&
          extensions.contains(p.extension(entity.path).toLowerCase())) {
        sources.add(entity.path);
      }
    }
    sources.sort();
    return sources;
  }

  Future<void> _pipe(
    Stream<List<int>> bytes,
    StreamController<String> target,
  ) async {
    await for (final line
        in utf8.decoder.bind(bytes).transform(const LineSplitter())) {
      if (!target.isClosed) target.add(line);
    }
  }

  void _addLines(StreamController<String> target, String text) {
    for (final line in text.split(RegExp(r'\r?\n'))) {
      if (line.isNotEmpty) target.add(line);
    }
  }

  ProgramRunResult _unavailable(String message) {
    final stderr = StreamController<String>();
    scheduleMicrotask(
      () => stderr
        ..add(message)
        ..close(),
    );
    return ProgramRunResult(
      title: 'C++ 运行后端不可用',
      stdout: const Stream<String>.empty(),
      stderr: stderr.stream,
      exitCode: Future<int>.value(kProgramNotRunExitCode),
    );
  }

  void _finish(Completer<int> completer, int code) {
    if (!completer.isCompleted) completer.complete(code);
  }
}
