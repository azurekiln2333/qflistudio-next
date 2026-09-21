import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:qfli_c_runtime/qfli_c_runtime.dart';
import 'package:qfli_studio_core/services/file_encoding.dart';
import 'package:qfli_studio_core/services/studio_profile.dart';

/// 用应用内的 C 运行时执行项目里的 C 代码。
///
/// 两个后端，按顺序尝试：
///
/// 1. **原生后端**（`libqfli_c.so` / picoc）——设备上打了这个 .so 才走得到，
///    链路上要过 ArkTS 和 NAPI，具体见 `native/README.md`。
/// 2. **Dart 解释器**（默认）——纯 Dart，不需要 NDK、不需要按 ABI 出多个 .so，
///    在所有平台上都能跑。这是本 App 实际交付的路径。
///
/// 之所以是「解释」而不是「编译」：鸿蒙的普通应用被 SELinux 挡在 `exec` 之外，
/// 既调不动设备上的 gcc，也拉不起打包在 HAP 里的可执行文件（HNP 那条路要求
/// 应用具备生产力应用资格）。但沙箱从来不限制应用解释自己的数据，所以把 C
/// 源码放在当前进程里跑，是普通应用唯一走得通的路。
class CProgramRunner implements ProgramRunner {
  const CProgramRunner({
    this.maxSteps = kDefaultMaxSteps,
    this.timeLimit = defaultTimeLimit,
  });

  /// 单次运行的步数兜底上限。
  ///
  /// 这是与设备速度无关的确定性上界，不是主要的防死循环手段——同一个步数在
  /// 紧凑循环和递归调用上差 20 倍时间（实测约 2800 万步/秒 vs 120 万步/秒），
  /// 只看步数必然误杀其中一类。
  final int maxSteps;

  /// 单次运行的墙钟时间上限。这才是真正拦住死循环的那个。
  final Duration timeLimit;

  /// 默认的时间上限。
  ///
  /// 取值考虑：手机上解释器比桌面慢 3~5 倍，10 秒约合桌面上 2~3 秒的计算量
  /// ——百万级循环只要 0.1 秒，`fib(25)` 约 2 秒，常见作业题都跑得完。
  ///
  /// 再往上放宽就要配「输出实时推送」了：现在是「跑完才出结果」，程序超过
  /// 十秒没动静，用户会以为卡住了。两件事是绑在一起的。
  static const Duration defaultTimeLimit = Duration(seconds: 10);

  /// 标准输入文件名（项目根目录下，存在即生效）。
  ///
  /// 解释器是「先算完再输出」的，没有交互式 stdin 的余地，所以约定用一个文件
  /// 把输入一次性喂进去——在线评测系统也是这个套路。
  static const String stdinFileName = 'input.txt';

  /// 参与本次运行的源码后缀。
  static const Set<String> _sourceExtensions = {'.c', '.h'};

  @override
  Future<ProgramRunResult?> run({
    required String projectPath,
    required String entryFile,
  }) async {
    // 不接管的类型交回内核的默认逻辑（返回 null）。
    if (p.extension(entryFile).toLowerCase() != '.c') return null;

    final entry = File(entryFile);
    if (!entry.existsSync()) return null;

    final fileName = _relative(entryFile, projectPath);
    final sources = _collectSources(projectPath);
    if (sources.isEmpty) return null;

    final stdin = _readStdin(projectPath);

    // 1) 原生后端优先（没打进 .so 时直接跳过）。
    final native = await _runNative(
      entryFile: entryFile,
      sources: sources,
      projectPath: projectPath,
      stdin: stdin,
    );
    if (native != null) return native;

    // 2) 退回 Dart 解释器。
    final source = _readSource(entry);
    if (source == null) {
      return _failure(fileName, '无法读取 $fileName（编码或权限问题）。');
    }

    // 项目内所有 .c / .h 一起送进去：`#include "utils.h"` 靠 files 解析，
    // 多个 .c 各自当独立翻译单元编译后共享函数表——等价于「没有链接器的链接」。
    final files = <String, String>{};
    for (final file in sources) {
      final relative = _relative(file, projectPath);
      if (relative == fileName) continue;
      final text = _readSource(File(file));
      if (text != null) files[relative] = text;
    }

    final session = startCSource(
      source: source,
      fileName: fileName,
      files: files,
      stdinLines: stdin,
      maxSteps: maxSteps,
      timeLimit: timeLimit,
    );

    return ProgramRunResult(
      title: '运行 $fileName（应用内 C 解释器）',
      stdout: session.stdout,
      stderr: session.stderr,
      exitCode: session.exitCode,
    );
  }

  /// 走原生 .so。通道不存在（没打进 .so）时返回 null，让调用方退回解释器。
  Future<ProgramRunResult?> _runNative({
    required String entryFile,
    required List<String> sources,
    required String projectPath,
    required List<String> stdin,
  }) async {
    if (!await _hasNativeBackend()) return null;

    // picoc 只吃翻译单元：头文件是靠 `#include` 拉进来的，
    // 单独喂给它会被当成一个没有 main 的源文件。入口排在第一个，
    // 因为它通常就是含 main() 的那个。
    final units = <String>[
      entryFile,
      ...sources.where(
        (file) =>
            file != entryFile && p.extension(file).toLowerCase() == '.c',
      ),
    ];

    final Object? raw;
    try {
      raw = await _channel.invokeMethod<Object?>('run', {
        'files': units,
        'workDir': projectPath,
        'stdin': stdin.isEmpty ? '' : '${stdin.join('\n')}\n',
        'stackSize': _nativeStackSize,
      });
    } on MissingPluginException {
      return null;
    } on PlatformException catch (error) {
      return _failure(
        p.basename(entryFile),
        '原生运行时出错：${error.message ?? error.code}',
      );
    }

    if (raw is! Map) return null;
    final output = '${raw['output'] ?? ''}';
    final error = raw['error'];
    final truncated = raw['truncated'] == true;

    final stdout = StreamController<String>();
    final stderr = StreamController<String>();
    scheduleMicrotask(() {
      for (final line in _splitLines(output)) {
        stdout.add(line);
      }
      if (error != null && '$error'.trim().isNotEmpty) {
        for (final line in _splitLines('$error')) {
          stderr.add(line);
        }
      }
      if (truncated) {
        stderr.add('输出过长，已被截断。');
      }
      stdout.close();
      stderr.close();
    });

    return ProgramRunResult(
      title: '运行 ${p.basename(entryFile)}（原生 picoc 运行时）',
      stdout: stdout.stream,
      stderr: stderr.stream,
      exitCode: Future<int>.value(
        raw['exitCode'] is int ? raw['exitCode'] as int : 0,
      ),
    );
  }

  static const MethodChannel _channel = MethodChannel('qfli_c/native');

  /// picoc 的栈大小，与 `native/src/qfli_c_bridge.c` 的默认值一致。
  static const int _nativeStackSize = 256 * 1024;

  /// 探测原生后端。
  ///
  /// 每次都问一遍而不是缓存：一次通道往返对「按一下运行」这个频率来说
  /// 完全无所谓，而缓存会引入跨运行的可变状态，得不偿失。
  Future<bool> _hasNativeBackend() async {
    try {
      return await _channel.invokeMethod<bool>('available') == true;
    } on MissingPluginException {
      // 设备上没打进 .so，通道根本不存在——这是常态，不是错误。
      return false;
    } on PlatformException {
      return false;
    }
  }

  /// 运行前的失败（连源码都读不到），包装成一次「立刻结束」的运行结果，
  /// 让终端面板用统一的方式显示，不必为它另开一条错误通道。
  ///
  /// 退出码用 [kProgramNotRunExitCode]（127）而不是 1：终端面板把非 0 渲染成
  /// 「（运行结束，退出码 N）」，用 1 会被读成「程序跑完报错退出」，其实没跑。
  ProgramRunResult _failure(String fileName, String message) {
    final controller = StreamController<String>();
    scheduleMicrotask(() {
      controller.add(message);
      controller.close();
    });
    return ProgramRunResult(
      title: '运行 $fileName',
      stdout: const Stream<String>.empty(),
      stderr: controller.stream,
      exitCode: Future<int>.value(kProgramNotRunExitCode),
    );
  }

  /// 项目内所有 C 源码的绝对路径。
  List<String> _collectSources(String projectPath) {
    final root = Directory(projectPath);
    if (!root.existsSync()) return const [];
    final found = <String>[];
    for (final entity in root.listSync(recursive: true, followLinks: false)) {
      if (entity is! File) continue;
      if (_sourceExtensions.contains(p.extension(entity.path).toLowerCase())) {
        found.add(entity.path);
      }
    }
    // 顺序稳定，便于测试与排查。
    found.sort();
    return found;
  }

  /// 按内容猜编码读文本：中文注释/字符串在 GBK 下也不会读崩。
  String? _readSource(File file) {
    final List<int> bytes;
    try {
      bytes = file.readAsBytesSync();
    } on FileSystemException {
      return null;
    }
    if (bytes.isEmpty) return '';
    try {
      return TextCodec.byName(TextCodec.detect(bytes)).decode(bytes);
    } on FormatException {
      // 编码猜错时退回宽松 UTF-8（不会抛），尽量把源码跑起来而不是直接报错。
      return TextCodec.utf8.decode(bytes);
    }
  }

  /// 读 [stdinFileName] 作为程序的标准输入，按行切分。
  List<String> _readStdin(String projectPath) {
    final file = File(p.join(projectPath, stdinFileName));
    if (!file.existsSync()) return const [];
    final text = _readSource(file);
    if (text == null || text.isEmpty) return const [];
    return _splitLines(text);
  }

  /// 按行切分并去掉行尾的 `\r`（Windows 下编辑过的输入不该把回车带进字符串比较）。
  static List<String> _splitLines(String text) {
    final lines = text.split('\n');
    if (lines.isNotEmpty && lines.last.isEmpty) lines.removeLast();
    return [
      for (final line in lines)
        line.endsWith('\r') ? line.substring(0, line.length - 1) : line,
    ];
  }

  /// 相对项目根的路径，统一用 `/`（解释器按 POSIX 风格解析 `#include`）。
  String _relative(String path, String from) =>
      p.relative(path, from: from).replaceAll(r'\', '/');
}
