import 'shell_backend.dart';

/// Web (and any platform without `dart:io`) cannot spawn processes, so this
/// backend reports the limitation and points at the sandbox shell instead.
ShellBackend createLocalShell({String? workingDirectory}) =>
    _UnsupportedShellBackend(workingDirectory);

/// No `dart:io`, so there is no way to start a process at all.
bool localShellAvailable() => false;

class _UnsupportedShellBackend extends BaseShellBackend {
  _UnsupportedShellBackend([this.workingDirectory]) {
    cwd = workingDirectory ?? '/';
  }

  final String? workingDirectory;

  @override
  String get shellLabel => '不可用';

  @override
  String get prompt => '\$';

  @override
  String get helpText => '''
当前平台无法启动本地进程（当前运行环境限制）。
请在桌面端运行 QFLI 终端。''';

  String resolvePath(String path) =>
      path.startsWith('/') ? path : '$cwd/${path.replaceAll(r'\', '/')}';

  @override
  Future<bool> changeDirectory(String target) async {
    emitLine('当前平台不支持目录操作，请使用沙盒终端。', OutputKind.stderr);
    return true;
  }

  @override
  Future<void> runExternal(String command) async {
    emitLine(
      '当前平台不支持执行系统命令（Web 环境限制），请改用「沙盒终端」。',
      OutputKind.stderr,
    );
  }
}
