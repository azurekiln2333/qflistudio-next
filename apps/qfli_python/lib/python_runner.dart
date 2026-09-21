import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:qfli_studio_core/services/file_encoding.dart';
import 'package:qfli_studio_core/services/studio_profile.dart';

/// 用内嵌的 MicroPython 执行项目里的 Python 代码。
///
/// 只有一个后端：**原生后端**（`libqfli_py.so`，内嵌 MicroPython + NAPI）。
/// 链路上要过 ArkTS，具体见 `native/README.md`。
///
/// 为什么没有「纯 Dart 解释器」兜底：MicroPython 是带完整编译器和字节码 VM 的
/// 真实现，语义跟 CPython 对得上；手写一个 Python 子集解释器既保证不了兼容性
/// （浮点、异常层次、生成器、f-string、迭代协议……每一项都是坑），又要长期维护。
/// 所以宁可明确报「这个构建里没有执行后端」，也不给一个「能跑一部分语法、
/// 细节上却跟真 Python 不一致」的东西——那对学习者是负价值。
///
/// 之所以是「解释」而不是「编译」：鸿蒙的普通应用被 SELinux 挡在 `exec` 之外，
/// 既调不动设备上的 python，也拉不起打包在 HAP 里的可执行文件（HNP 那条路要求
/// 应用具备生产力应用资格）。但沙箱从来不限制应用解释自己的数据，所以把源码
/// 交给进程内的 VM，是普通应用唯一走得通的路。
class PythonProgramRunner implements ProgramRunner {
  const PythonProgramRunner({this.heapKb = defaultHeapKb});

  /// MicroPython 的 GC 堆大小（KB）。
  ///
  /// 与 `native/src/qfli_py_bridge.c` 的默认值保持一致。太小的话
  /// `[i * i for i in range(100000)]` 这种教学里很常见的写法会立刻 MemoryError；
  /// 太大则「无限往列表里塞」这类错误程序要等很久才撞上内存上限。
  final int heapKb;

  /// 默认 8 MB。
  static const int defaultHeapKb = 8 * 1024;

  /// 标准输入文件名（项目根目录下，存在即生效）。
  ///
  /// 解释器是「先算完再输出」的，没有交互式 stdin 的余地，所以约定用一个文件
  /// 把输入一次性喂进去。MicroPython 的 `input()` 会按行从这个缓冲区里消费。
  static const String stdinFileName = 'input.txt';

  /// 本后端接管的源码后缀。
  static const Set<String> _sourceExtensions = {'.py'};

  /// 与 `native/ohos/QfliPyNative.ets` 里的通道名一致。
  static const MethodChannel _channel = MethodChannel('qfli_py/native');

  /// App 自己写的诊断行的前缀。
  ///
  /// 存在的理由：终端面板里同时会显示**程序自己的输出**和**App 的诊断**，
  /// 两者混在一起时，「这行中文是谁说的」会让人困惑——尤其是后端没跑起来、
  /// 一行 Python 输出都没有的时候，满屏都是 App 的提示，看起来像 Python
  /// 在说中文。加上前缀之后，凡是带 `[qfli]` 的都是 App 说的，不带的就是
  /// 程序真实的 stdout/stderr。
  static const String _appPrefix = '[qfli] ';

  /// 「程序根本没跑起来」时用的退出码，直接沿用内核的约定。
  ///
  /// 刻意**不用 1**：终端面板会把非 0 一律渲染成「（运行结束，退出码 N）」，
  /// 用 1 的话「后端没打进 HAP」看起来就成了「程序自己跑完、报错退出 1」——
  /// 这是真机上真实误导过人的一次。原因和取舍写在
  /// `qfli_studio_core/services/studio_profile.dart` 的 [kProgramNotRunExitCode]。
  static const int notRunExitCode = kProgramNotRunExitCode;

  @override
  Future<ProgramRunResult?> run({
    required String projectPath,
    required String entryFile,
  }) async {
    // 不是本语言的文件交回内核（返回 null），内核会走自己的分流逻辑。
    if (!_sourceExtensions.contains(p.extension(entryFile).toLowerCase())) {
      return null;
    }

    final entry = File(entryFile);
    if (!entry.existsSync()) return null;

    final fileName = p.basename(entryFile);

    final source = _readText(entry);
    if (source == null) {
      return _failure(fileName, '$_appPrefix无法读取 $fileName（编码或权限问题）。');
    }

    // 探测原生后端。每次运行都问一遍而不是缓存：一次通道往返对「按一下运行」
    // 这个频率完全无所谓，而缓存会引入跨运行的可变状态，得不偿失。
    final probe = await _probeNative();
    if (!probe.available) {
      return _notWired(fileName, probe.detail);
    }

    return _runNative(
      fileName: fileName,
      version: probe.version,
      source: source,
      stdin: _readStdin(projectPath),
    );
  }

  /// 走原生 .so。
  Future<ProgramRunResult> _runNative({
    required String fileName,
    required String version,
    required String source,
    required String stdin,
  }) async {
    final Object? raw;
    try {
      raw = await _channel.invokeMethod<Object?>('run', {
        'source': source,
        'stdin': stdin,
        'heapKb': heapKb,
      });
    } on MissingPluginException {
      // 设备上没打进 .so，通道根本不存在。
      return _notWired(fileName, '');
    } on PlatformException catch (error) {
      // 原生后端**存在但执行失败**：把错误显示出来，不静默换后端。
      // 悄悄退回别的执行路径会让用户看到的运行结果和设备的真实行为对不上，
      // 排查问题时会被误导。
      //
      // QFLI_PY_MODULE_MISSING 是 ArkTS 侧专门为「.so 装上了但 dlopen 失败」
      // 留的码，message 本身就是完整解释，不要再套一层「运行时出错」把它埋掉。
      final detail = error.message?.trim() ?? '';
      if (error.code == 'QFLI_PY_MODULE_MISSING' && detail.isNotEmpty) {
        return _failure(fileName, '$_appPrefix$detail');
      }
      return _failure(
        fileName,
        '$_appPrefix原生运行时出错：${detail.isEmpty ? error.code : detail}',
      );
    }

    if (raw is! Map) {
      return _failure(fileName, '$_appPrefix原生运行时返回了意外的结果。');
    }

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
        // 后面跟的是中文字符，Dart 标识符不含 CJK，花括号可以省；
        // 对比下面 _notWired 里的 '${_appPrefix}Python ...' —— 那里必须留，
        // 否则会被解析成 `_appPrefixPython` 这个变量名。
        stderr.add('$_appPrefix输出过长，已被截断。');
      }
      stdout.close();
      stderr.close();
    });

    // 标题里带上真实版本号（形如 "1.24.1 (ecfdd5d)"）：它是从 .so 里问出来的，
    // 不是写死的常量，顺手就当了一次后端身份的自证。
    final label = version.isEmpty ? '内嵌 MicroPython' : 'MicroPython $version';

    return ProgramRunResult(
      title: '运行 $fileName（$label）',
      stdout: stdout.stream,
      stderr: stderr.stream,
      exitCode: Future<int>.value(
        raw['exitCode'] is int ? raw['exitCode'] as int : 0,
      ),
    );
  }

  /// 问原生后端「你能不能跑」，并拿回不能跑的原因。
  ///
  /// 返回值刻意不是 bool：只说「不可用」没法排查。ArkTS 侧会带上 detail，
  /// 讲清楚是「没打进 HAP」还是「打进去了但加载失败」，两者的修法完全不同。
  Future<_NativeProbe> _probeNative() async {
    try {
      final raw = await _channel.invokeMethod<Object?>('available');
      if (raw is Map) {
        return _NativeProbe(
          available: raw['available'] == true,
          version: '${raw['version'] ?? ''}',
          detail: '${raw['detail'] ?? ''}',
        );
      }
      // 兼容只回 bool 的旧接线（两份 QfliPyNative.ets 副本没同步时会走到这里）。
      return _NativeProbe(available: raw == true);
    } on MissingPluginException {
      // 通道不存在 = 这个构建里没打进 .so。是常态，不是错误。
      return const _NativeProbe(available: false);
    } on PlatformException catch (error) {
      return _NativeProbe(
        available: false,
        detail: error.message ?? error.code,
      );
    }
  }

  /// 原生后端不可用。
  ///
  /// 不做「假装能跑」的降级：说清楚缺什么、怎么补，比给一个跑不了的结果好。
  ProgramRunResult _notWired(String fileName, String detail) {
    final controller = StreamController<String>();
    scheduleMicrotask(() {
      // 注意这里必须写 ${_appPrefix}：直接写 $_appPrefix 再接 ASCII 字母的话，
      // Dart 会把 `_appPrefixPython` 当成一个变量名去找。
      controller.add('${_appPrefix}Python 执行后端不可用。');
      if (detail.isNotEmpty) {
        // ArkTS 侧给的原因比我们在这里猜的准，优先用它。
        controller.add('$_appPrefix$detail');
      } else {
        controller.add('$_appPrefix这个构建里没有打进 libqfli_py.so'
            '（内嵌 MicroPython）。');
      }
      controller.add('$_appPrefix重新编译：'
          'apps/qfli_python/native/build.ps1，'
          '它会编译 .so 并拷到 ohos/entry/libs/arm64-v8a/。');
      controller.add('$_appPrefix编辑器、语法高亮、项目模板、Python 入门教程不受影响；'
          '内置 Python 解释器完成后即可在本 App 内运行这段代码。');
      controller.close();
    });
    return ProgramRunResult(
      title: '运行 $fileName（缺少 Python 执行后端）',
      stdout: controller.stream,
      stderr: const Stream<String>.empty(),
      exitCode: Future<int>.value(notRunExitCode),
    );
  }

  /// 运行前的失败，包装成一次「立刻结束」的运行结果，让终端面板用统一的方式
  /// 显示，不必为它另开一条错误通道。
  ///
  /// 退出码一律用 [notRunExitCode]：走到这里的所有分支（源码读不出来、原生调用
  /// 抛异常、返回结构不认识）都意味着**程序没有产出结果**，用 1 会跟「程序自己
  /// 退出 1」撞车。
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
      exitCode: Future<int>.value(notRunExitCode),
    );
  }

  /// 读 [stdinFileName] 作为程序的标准输入。
  ///
  /// 整段原样传下去、**不**按行切：MicroPython 的 `input()` 会自己按行消费，
  /// 而 `sys.stdin.read()` 这种整体读的写法也才成立。
  String _readStdin(String projectPath) {
    final file = File(p.join(projectPath, stdinFileName));
    if (!file.existsSync()) return '';
    return _readText(file) ?? '';
  }

  /// 按内容猜编码读文本：中文注释/字符串在 GBK 下也不会读崩。
  /// 返回 null 表示读不到（文件不存在/无权限），空文件返回空串。
  String? _readText(File file) {
    final List<int> bytes;
    try {
      bytes = file.readAsBytesSync();
    } on FileSystemException {
      return null;
    } on UnsupportedError {
      // 个别平台的 dart:io 在读取特殊文件时会抛这个，按读不到处理。
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

  /// 按行切分并去掉行尾的 `\r`（Windows 下编辑过的源码不该把回车带进输出）。
  static List<String> _splitLines(String text) {
    final lines = text.split('\n');
    if (lines.isNotEmpty && lines.last.isEmpty) lines.removeLast();
    return [
      for (final line in lines)
        line.endsWith('\r') ? line.substring(0, line.length - 1) : line,
    ];
  }
}

/// 原生后端的探测结果。
class _NativeProbe {
  const _NativeProbe({
    required this.available,
    this.version = '',
    this.detail = '',
  });

  /// 模块是否真的可用（不是「文件在不在」，是「dlopen 成没成功」）。
  final bool available;

  /// MicroPython 版本，形如 `1.24.1 (ecfdd5d)`。拿不到时为空串。
  final String version;

  /// 不可用时的原因。可用时为空串。
  final String detail;
}
