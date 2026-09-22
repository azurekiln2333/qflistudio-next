import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;

import 'app_paths.dart';
import 'local_web_server.dart';
import 'process_supervisor.dart';
import 'studio_profile.dart';

/// 运行结果：输出行由终端面板显示。
///
/// 两种输出来源二选一：
/// - [process]：外部进程（桌面端 python/javac/gcc 等），由终端接管其管道。
/// - [stdout] / [stderr] / [exitCode]：应用内运行时（语言 App 注入的
///   [ProgramRunner]），例如 C 版把解释器的输出按行推过来。
class RunResult {
  const RunResult({
    required this.title,
    this.process,
    this.managedProcess,
    this.webServer,
    this.hint,
    this.stdout,
    this.stderr,
    this.exitCode,
  });

  final String title;
  final Process? process;
  final ManagedProcess? managedProcess;
  final LocalWebServer? webServer;

  /// 无法本机运行时的说明（例如移动端无编译器，引导走在线终端）。
  final String? hint;

  /// 应用内运行时的按行输出流。
  final Stream<String>? stdout;
  final Stream<String>? stderr;
  final Future<int>? exitCode;
}

/// 「运行」按钮逻辑：按文件/项目类型分流。
abstract final class RunnerService {
  static final ProcessSupervisor _processSupervisor = ProcessSupervisor();
  static const MethodChannel _ohosChannel =
      MethodChannel('qflistudio/platform');

  /// 判断项目根目录下的主入口文件。
  ///
  /// 语言档位声明的 [StudioProfile.entryFileNames] 优先，保证 C 版一定会先
  /// 命中 `main.c` 而不是同目录下别的语言入口。
  static String? findEntry(String projectPath) {
    final profile = StudioProfile.current;
    final candidates = <String>[
      ...?profile?.entryFileNames,
      ..._defaultEntryNames,
    ];
    for (final name in candidates) {
      final f = File(p.join(projectPath, name));
      if (f.existsSync()) return f.path;
    }
    return null;
  }

  static const List<String> _defaultEntryNames = [
    'index.html',
    'main.py',
    'main.dart',
    'Main.java',
    'main.cpp',
    'main.c',
    'src/index.html',
    'src/main.py',
    'src/main.dart',
    'src/Main.java',
    'src/main.cpp',
    'src/main.c',
    'src/main.lua',
    'src/main.js',
    'src/main.ts',
    'src/main.kt',
    'src/main.go',
    'src/main.rs',
    'src/main.cs',
    'src/main.php',
    'src/main.rb',
  ];

  /// 运行当前项目。失败抛出的异常由调用方转为提示。
  static Future<RunResult?> runProject({
    required String projectPath,
    required String entryFile,
  }) async {
    // 语言 App 注入的本地运行时优先：它接管后就不再走桌面端工具链或在线终端。
    final custom = StudioProfile.current?.runner;
    if (custom != null) {
      final result = await custom.run(
        projectPath: projectPath,
        entryFile: entryFile,
      );
      if (result != null) {
        return RunResult(
          title: result.title,
          stdout: result.stdout,
          stderr: result.stderr,
          exitCode: result.exitCode,
        );
      }
    }

    final ext = p.extension(entryFile).toLowerCase();
    switch (ext) {
      case '.html':
      case '.htm':
        final server = await LocalWebServer.start(projectPath);
        await _openUrl(server.url);
        return RunResult(title: server.url, webServer: server);
      case '.py':
      case '.dart':
      case '.java':
      case '.c':
      case '.cpp':
        if (AppPaths.isDesktop) {
          final result = await _runDesktop(projectPath, entryFile, ext);
          if (result != null) return result;
          return RunResult(
            title: '运行',
            hint: '未找到工具链（python/dart/javac/gcc），请安装后在桌面端运行，'
                '或在「终端」中使用在线终端执行。',
          );
        }
        return RunResult(
          title: '运行',
          hint: '移动端无法本地运行 $ext 程序（系统无编译器/解释器）。'
              '请在编辑器中打开「在线终端」，由服务器编译执行并回显输出。',
        );
      default:
        return RunResult(
          title: '运行',
          hint: '无法识别可运行的入口文件（index.html/main.py/main.c 等）。',
        );
    }
  }

  static Future<RunResult?> _runDesktop(
    String projectPath,
    String entryFile,
    String ext,
  ) async {
    List<String> command;
    switch (ext) {
      case '.py':
        command = ['python', entryFile];
      case '.dart':
        command = ['dart', 'run', entryFile];
      case '.java':
        command = ['java', entryFile];
      case '.c':
      case '.cpp':
        command = ['gcc', entryFile, '-o', 'a.out'];
      default:
        return null;
    }
    try {
      final which = Platform.isWindows ? 'where' : 'which';
      final probe = await Process.run(which, [command.first]);
      if (probe.exitCode != 0) return null;
      final process = await _processSupervisor.start(
        command.first,
        command.sublist(1),
        workingDirectory: projectPath,
        runInShell: Platform.isWindows,
      );
      return RunResult(
        title: command.join(' '),
        managedProcess: process,
      );
    } on ProcessException {
      return null;
    }
  }

  /// ohos/android 上通过原生通道打开浏览器；桌面端直接起进程。
  static Future<void> _openUrl(String url) async {
    if (AppPaths.isDesktop) {
      await UrlOpener.open(url);
      return;
    }
    try {
      await _ohosChannel.invokeMethod('openUrl', {'url': url});
    } on MissingPluginException {
      // 通道不可用时忽略（预览服务器仍在运行，可手动复制 URL）。
    } on PlatformException {
      // 打开失败时忽略。
    }
  }
}
