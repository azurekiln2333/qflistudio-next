import 'dart:io';

/// git 命令结果。
typedef GitResult = ({String stdout, String stderr, int exitCode});

/// 本地 git CLI 封装（`git -C <project> ...`，桌面端）。
/// 移动端没有 git 二进制：云端项目请使用服务器 git（CloudSyncService.git）。
abstract final class GitService {
  static bool get isSupported =>
      Platform.isWindows || Platform.isMacOS || Platform.isLinux;

  static Future<bool> _exists() async {
    try {
      final probe = Platform.isWindows ? 'where' : 'which';
      final result = await Process.run(probe, ['git']);
      return result.exitCode == 0;
    } on ProcessException {
      return false;
    }
  }

  static Future<GitResult> run(String projectPath, List<String> args) async {
    if (!isSupported) {
      return (stdout: '', stderr: '当前平台不支持本地 git', exitCode: 1);
    }
    if (!await _exists()) {
      return (stdout: '', stderr: '未找到 git，请先安装并加入 PATH', exitCode: 1);
    }
    try {
      final result = await Process.run(
        'git',
        args,
        workingDirectory: projectPath,
        runInShell: Platform.isWindows,
        stdoutEncoding: const SystemEncoding(),
        stderrEncoding: const SystemEncoding(),
      );
      return (
        stdout: result.stdout as String,
        stderr: result.stderr as String,
        exitCode: result.exitCode,
      );
    } on ProcessException catch (e) {
      return (stdout: '', stderr: 'git 执行失败：${e.message}', exitCode: 1);
    }
  }

  static Future<GitResult> init(String dir) => run(dir, ['init']);

  static Future<GitResult> status(String dir) =>
      run(dir, ['status', '--porcelain']);

  static Future<GitResult> log(String dir) => run(dir, ['log', '--oneline', '-20']);

  static Future<GitResult> diff(String dir) => run(dir, ['diff', '--stat', 'HEAD']);

  static Future<GitResult> push(String dir) => run(dir, ['push', '-u', 'origin', 'HEAD']);

  static Future<GitResult> pull(String dir) => run(dir, ['pull', '--rebase']);

  static Future<GitResult> setRemote(String dir, String url) async {
    await run(dir, ['remote', 'remove', 'origin']);
    return run(dir, ['remote', 'add', 'origin', url]);
  }

  static Future<GitResult> commit(String dir, String message) async {
    await run(dir, ['add', '-A']);
    return run(dir, ['commit', '-m', message]);
  }
}
