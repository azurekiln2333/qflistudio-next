import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:qfli_studio_core/services/process_supervisor.dart';
import 'package:qfli_studio_core/services/studio_profile.dart';

/// Runtime adapter for the shared scripting product.
class LuaProgramRunner implements ProgramRunner {
  const LuaProgramRunner();

  static final ProcessSupervisor _processSupervisor = ProcessSupervisor();

  static const Set<String> _sourceExtensions = {
    '.lua',
    '.js',
    '.mjs',
    '.ts',
    '.sh',
  };

  @override
  Future<ProgramRunResult?> run({
    required String projectPath,
    required String entryFile,
  }) async {
    final extension = p.extension(entryFile).toLowerCase();
    if (!_sourceExtensions.contains(extension)) return null;
    final runtime = _runtimeName(extension);
    if (!Platform.isWindows && !Platform.isLinux && !Platform.isMacOS) {
      return _notReady(p.basename(entryFile), runtime);
    }

    final command = await _commandFor(extension, entryFile);
    if (command == null) return _notReady(p.basename(entryFile), runtime);
    try {
      final process = await _processSupervisor.start(
        command.first,
        command.skip(1).toList(growable: false),
        workingDirectory: projectPath,
        runInShell: Platform.isWindows,
      );
      return ProgramRunResult(
        title: '运行 ${p.basename(entryFile)}（$runtime）',
        stdout: process.stdout
            .transform(systemEncoding.decoder)
            .transform(const LineSplitter()),
        stderr: process.stderr
            .transform(systemEncoding.decoder)
            .transform(const LineSplitter()),
        exitCode: process.exitCode,
        cancel: process.cancel,
      );
    } on ProcessException {
      return _notReady(p.basename(entryFile), runtime);
    }
  }

  Future<List<String>?> _commandFor(String extension, String entryFile) async {
    final candidates = switch (extension) {
      '.lua' => const [
        ['lua'],
        ['luajit'],
      ],
      '.js' || '.mjs' => const [
        ['node'],
        ['deno', 'run'],
      ],
      '.ts' => const [
        ['deno', 'run'],
        ['tsx'],
        ['ts-node'],
      ],
      '.sh' => Platform.isWindows
          ? const [
              ['powershell', '-NoProfile', '-ExecutionPolicy', 'Bypass', '-File'],
            ]
          : const [
              ['sh'],
              ['bash'],
            ],
      _ => const <List<String>>[],
    };
    for (final candidate in candidates) {
      final probe = await Process.run(
        Platform.isWindows ? 'where' : 'which',
        [candidate.first],
        runInShell: Platform.isWindows,
      );
      if (probe.exitCode == 0) return [...candidate, entryFile];
    }
    return null;
  }

  ProgramRunResult _notReady(String fileName, String runtime) {
    final controller = StreamController<String>();
    scheduleMicrotask(() {
      controller
        ..add('$runtime 运行时不可用：请在桌面端安装对应工具链。')
        ..add('当前仍可使用编辑、保存、格式化和项目导入导出。')
        ..close();
    });
    return ProgramRunResult(
      title: '运行 $fileName（$runtime 不可用）',
      stdout: controller.stream,
      stderr: const Stream<String>.empty(),
      exitCode: Future<int>.value(kProgramNotRunExitCode),
    );
  }

  String _runtimeName(String extension) => switch (extension) {
    '.lua' => 'Lua',
    '.js' || '.mjs' => 'JavaScript',
    '.ts' => 'TypeScript',
    '.sh' => 'Shell',
    _ => 'Script',
  };
}
