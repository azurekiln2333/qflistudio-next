/// C 运行时的对外接口。
///
/// 一次运行 = 预处理 → 词法 → 语法 → 解释执行，全程在应用进程内完成，
/// 不写可执行文件、不起子进程。默认放到独立 isolate 里跑，避免用户写出的
/// 死循环把界面卡住。
library;

import 'dart:async';
import 'dart:isolate';

import 'c_ast.dart';
import 'c_builtins.dart';
import 'c_interpreter.dart';
import 'c_lexer.dart';
import 'c_parser.dart';
import 'c_preprocessor.dart';

/// 一次运行中出现的错误，已经翻译回「用户源码的哪个文件哪一行」。
class CProgramError {
  const CProgramError({
    required this.kind,
    required this.message,
    required this.file,
    required this.line,
    this.column,
  });

  /// 预处理 / 词法 / 语法 / 运行时。
  final String kind;

  /// 面向用户的中文说明。
  final String message;

  /// 出错文件（`main.c`、`utils.h` 或 `<stdio.h>`）。
  final String file;

  /// 1 基行号。
  final int line;

  final int? column;

  String get location => column == null ? '$file:$line' : '$file:$line:$column';

  @override
  String toString() => '$kind错误：$message（$location）';
}

/// 一次运行的完整结果。
class CRunResult {
  const CRunResult({
    required this.exitCode,
    required this.output,
    required this.error,
    required this.steps,
    required this.durationMs,
    this.warnings = const [],
  });

  final int exitCode;
  final String output;
  final CProgramError? error;
  final int steps;
  final int durationMs;

  /// 不是错误、但用户需要知道的说明。
  ///
  /// 目前只有一个来源：程序读了标准输入而项目里没有 `input.txt`。
  /// 这种情况不会有报错——程序会拿着 0 值继续算下去，给出一个**看起来正常
  /// 但其实错误**的结果。把它做成中性的说明而不是错误，是因为程序本身可能
  /// 没错（比如「读到 EOF 就结束」的循环），需要解释的是环境。
  final List<String> warnings;

  bool get success => error == null;

  /// 输出按行切分，方便终端逐行显示。
  List<String> get lines {
    if (output.isEmpty) return const [];
    final parts = output.split('\n');
    // 末尾换行会切出一个空串，去掉它。
    if (parts.isNotEmpty && parts.last.isEmpty) parts.removeLast();
    return parts;
  }
}

/// 一次运行的结果（默认参数）。
CRunResult _result({
  required int exitCode,
  required String output,
  required int steps,
  required int durationMs,
  CProgramError? error,
  List<String> warnings = const [],
}) => CRunResult(
  exitCode: exitCode,
  output: output,
  error: error,
  steps: steps,
  durationMs: durationMs,
  warnings: warnings,
);

/// 运行一段 C 源码。
///
/// [files] 是项目内其它文件（键为相对路径，`/` 分隔），供 `#include "x.h"` 使用。
/// [timeLimit] 是墙钟时间上限，[maxSteps] 是步数兜底上限——两个都超才会中止，
/// 且会说明是哪一个先触发的。
Future<CRunResult> runCSource({
  required String source,
  String fileName = 'main.c',
  Map<String, String> files = const {},
  List<String> stdinLines = const [],
  List<String> arguments = const [],
  int maxSteps = kDefaultMaxSteps,
  Duration timeLimit = kDefaultTimeLimit,
  bool useIsolate = true,
}) async {
  final input = <String, Object?>{
    'source': source,
    'fileName': fileName,
    'files': files,
    'stdinLines': stdinLines,
    'arguments': arguments,
    'maxSteps': maxSteps,
    'timeLimitMs': timeLimit.inMilliseconds,
  };

  Map<String, Object?> raw;
  if (useIsolate) {
    try {
      raw = await Isolate.run(() => executeC(input));
    } catch (_) {
      // 平台不支持 isolate（例如 Web）时退回同步执行。
      raw = executeC(input);
    }
  } else {
    raw = executeC(input);
  }
  return _fromRaw(raw);
}

/// 一次可流式读取输出的运行。
class CRunSession {
  CRunSession._(this._stdoutController, this._stderrController, this._resultFuture);

  final StreamController<String> _stdoutController;
  final StreamController<String> _stderrController;
  final Future<CRunResult> _resultFuture;

  /// 标准输出，按行推送。
  Stream<String> get stdout => _stdoutController.stream;

  /// 错误输出：目前承载运行时错误与诊断信息。
  Stream<String> get stderr => _stderrController.stream;

  /// 最终结果（含退出码与错误）。
  Future<CRunResult> get result => _resultFuture;

  /// 退出码，输出流全部结束后才会完成。
  Future<int> get exitCode async => (await _resultFuture).exitCode;
}

/// 启动一次运行，输出边算边推。
///
/// 解释执行本身是同步的，所以这里先把结果算完，再按行推流——对教学规模的
/// 程序来说，用户感知到的仍然是「点运行、输出出现」。
CRunSession startCSource({
  required String source,
  String fileName = 'main.c',
  Map<String, String> files = const {},
  List<String> stdinLines = const [],
  List<String> arguments = const [],
  int maxSteps = kDefaultMaxSteps,
  Duration timeLimit = kDefaultTimeLimit,
}) {
  final stdoutController = StreamController<String>();
  final stderrController = StreamController<String>();

  final resultFuture = runCSource(
    source: source,
    fileName: fileName,
    files: files,
    stdinLines: stdinLines,
    arguments: arguments,
    maxSteps: maxSteps,
    timeLimit: timeLimit,
  ).then((result) {
    for (final line in result.lines) {
      stdoutController.add(line);
    }
    final error = result.error;
    if (error != null) {
      stderrController.add('${error.kind}错误：${error.message}');
      stderrController.add('  位置：${error.location}');
    }
    // 提示排在错误后面：先把「出什么事了」说清楚，再解释可能的原因。
    for (final warning in result.warnings) {
      stderrController.add(warning);
    }
    stdoutController.close();
    stderrController.close();
    return result;
  }).catchError((Object error) {
    stderrController.add('内部错误：$error');
    stdoutController.close();
    stderrController.close();
    return _result(
      exitCode: -1,
      output: '',
      steps: 0,
      durationMs: 0,
      error: CProgramError(
        kind: '内部',
        message: '$error',
        file: fileName,
        line: 1,
      ),
    );
  });

  return CRunSession._(stdoutController, stderrController, resultFuture);
}

/// 在 isolate 里执行的入口：参数与返回值都必须可跨 isolate 传递。
Map<String, Object?> executeC(Map<String, Object?> input) {
  final source = input['source'] as String? ?? '';
  final fileName = input['fileName'] as String? ?? 'main.c';
  final files = <String, String>{
    for (final entry in (input['files'] as Map? ?? const {}).entries)
      '${entry.key}': '${entry.value}',
  };
  final stdinLines = <String>[
    for (final line in (input['stdinLines'] as List? ?? const [])) '$line',
  ];
  final arguments = <String>[
    for (final argument in (input['arguments'] as List? ?? const [])) '$argument',
  ];
  final maxSteps = input['maxSteps'] as int? ?? kDefaultMaxSteps;
  final timeLimit = Duration(
    milliseconds: input['timeLimitMs'] as int? ?? kDefaultTimeLimit.inMilliseconds,
  );

  final stopwatch = Stopwatch()..start();
  files[fileName] = source;

  // 项目里其它 .c 文件当作独立的翻译单元一起编译，这样 `main.c` 才能调用
  // `utils.c` 里的函数——不需要真的做链接，函数表本来就是共享的。
  final entryPoints = <String>[
    fileName,
    ...files.keys.where(
      (key) =>
          key != fileName &&
          key.toLowerCase().endsWith('.c') &&
          !key.startsWith('<'),
    ),
  ];

  final items = <CTopLevelItem>[];
  for (final entry in entryPoints) {
    final compiled = _compileUnit(entry, files, stopwatch);
    final failure = compiled.error;
    if (failure != null) return failure;
    items.addAll(compiled.unit!.items);
  }
  final unit = CTranslationUnit(items);

  final interpreter = CInterpreter(maxSteps: maxSteps, timeLimit: timeLimit);
  registerBuiltins(interpreter);
  interpreter.stdinLines = stdinLines;

  try {
    final exitCode = interpreter.execute(unit, arguments: arguments);
    stopwatch.stop();
    return <String, Object?>{
      'exitCode': exitCode,
      'output': interpreter.output,
      'warnings': _stdinWarnings(interpreter, stdinLines),
      'steps': interpreter.stepCount,
      'durationMs': stopwatch.elapsedMilliseconds,
      'error': null,
    };
  } on CTimeoutException catch (error) {
    stopwatch.stop();
    return <String, Object?>{
      'exitCode': 124,
      'output': interpreter.output,
      'warnings': _stdinWarnings(interpreter, stdinLines),
      'steps': interpreter.stepCount,
      'durationMs': stopwatch.elapsedMilliseconds,
      'error': <String, Object?>{
        'kind': '运行时',
        'message': _withStdinHint(error.message, interpreter),
        'file': fileName,
        'line': 1,
        'column': null,
      },
    };
  } on CRuntimeException catch (error) {
    stopwatch.stop();
    final origin = error.line == null
        ? CSourceLocation(fileName, 1)
        : _originsOf[entryPoints.first]?.originOf(error.line!) ??
              CSourceLocation(fileName, 1);
    return <String, Object?>{
      'exitCode': 1,
      'output': interpreter.output,
      'warnings': _stdinWarnings(interpreter, stdinLines),
      'steps': interpreter.stepCount,
      'durationMs': stopwatch.elapsedMilliseconds,
      'error': <String, Object?>{
        'kind': '运行时',
        'message': error.message,
        'file': origin.file,
        'line': origin.line,
        'column': null,
      },
    };
  } catch (error) {
    stopwatch.stop();
    return <String, Object?>{
      'exitCode': 1,
      'output': interpreter.output,
      'warnings': _stdinWarnings(interpreter, stdinLines),
      'steps': interpreter.stepCount,
      'durationMs': stopwatch.elapsedMilliseconds,
      'error': <String, Object?>{
        'kind': '运行时',
        'message': '$error',
        'file': fileName,
        'line': 1,
        'column': null,
      },
    };
  }
}

/// 预处理 + 词法 + 语法一个文件。失败时返回已经翻译好位置的错误。
({CTranslationUnit? unit, Map<String, Object?>? error}) _compileUnit(
  String fileName,
  Map<String, String> files,
  Stopwatch stopwatch,
) {
  CPreprocessedSource preprocessed;
  try {
    preprocessed = preprocess(
      CPreprocessInput(entryPath: fileName, files: files),
    );
  } on CPreprocessException catch (error) {
    return (
      unit: null,
      error: _errorResult(
        kind: '预处理',
        message: error.message,
        file: error.file,
        line: error.line,
        stopwatch: stopwatch,
      ),
    );
  } catch (error) {
    return (
      unit: null,
      error: _errorResult(
        kind: '预处理',
        message: '$error',
        file: fileName,
        line: 1,
        stopwatch: stopwatch,
      ),
    );
  }
  _originsOf[fileName] = preprocessed;

  List<CToken> tokens;
  try {
    tokens = CLexer(preprocessed.text).tokenize();
  } on CLexException catch (error) {
    final origin = preprocessed.originOf(error.line);
    return (
      unit: null,
      error: _errorResult(
        kind: '词法',
        message: error.message,
        file: origin.file,
        line: origin.line,
        column: error.column + 1,
        stopwatch: stopwatch,
      ),
    );
  } catch (error) {
    return (
      unit: null,
      error: _errorResult(
        kind: '词法',
        message: '$error',
        file: fileName,
        line: 1,
        stopwatch: stopwatch,
      ),
    );
  }

  try {
    return (
      unit: parseTranslationUnit(tokens, source: preprocessed),
      error: null,
    );
  } on CParseException catch (error) {
    final origin = preprocessed.originOf(error.line);
    return (
      unit: null,
      error: _errorResult(
        kind: '语法',
        message: error.message,
        file: origin.file,
        line: origin.line,
        column: error.column + 1,
        stopwatch: stopwatch,
      ),
    );
  } catch (error) {
    return (
      unit: null,
      error: _errorResult(
        kind: '语法',
        message: '$error',
        file: fileName,
        line: 1,
        stopwatch: stopwatch,
      ),
    );
  }
}

/// 各翻译单元的行号映射，运行时错误需要靠它翻译回原始文件。
final Map<String, CPreprocessedSource> _originsOf = {};

Map<String, Object?> _errorResult({
  required String kind,
  required String message,
  required String file,
  required int line,
  required Stopwatch stopwatch,
  int? column,
}) {
  stopwatch.stop();
  return <String, Object?>{
    'exitCode': 1,
    'output': '',
    'steps': 0,
    'durationMs': stopwatch.elapsedMilliseconds,
    'error': <String, Object?>{
      'kind': kind,
      'message': message,
      'file': file,
      'line': line,
      'column': column,
    },
  };
}

CRunResult _fromRaw(Map<String, Object?> raw) {
  final errorMap = raw['error'] as Map?;
  return CRunResult(
    exitCode: raw['exitCode'] as int? ?? 0,
    output: raw['output'] as String? ?? '',
    steps: raw['steps'] as int? ?? 0,
    durationMs: raw['durationMs'] as int? ?? 0,
    warnings: <String>[
      for (final warning in (raw['warnings'] as List? ?? const [])) '$warning',
    ],
    error: errorMap == null
        ? null
        : CProgramError(
            kind: errorMap['kind'] as String? ?? '运行时',
            message: errorMap['message'] as String? ?? '',
            file: errorMap['file'] as String? ?? 'main.c',
            line: errorMap['line'] as int? ?? 1,
            column: errorMap['column'] as int?,
          ),
  );
}

/// 程序读了标准输入、但一个字都没给出来时的说明。
///
/// 只在「项目里根本没有 input.txt」时才提示：这种情况下程序会拿着 0 值继续
/// 算下去，给一个看起来正常的结果，用户完全看不出哪里错了。反过来，如果用户
/// 自己放了 input.txt、程序读完了继续读，那是「读到 EOF 就停」的正常写法，
/// 再提示就是噪音了。
const String kStdinMissingHint =
    '提示：程序读了标准输入，但项目根目录没有 input.txt，读到的是空输入。';

/// 这次运行该不该提示「缺输入」。
///
/// 只在「一个字都没给」时才提示。用户自己放了 input.txt、程序读完继续读，
/// 那是「读到 EOF 就停」的正常写法，再提示就是噪音。
List<String> _stdinWarnings(
  CInterpreter interpreter,
  List<String> stdinLines,
) {
  if (stdinLines.isNotEmpty) return const [];
  if (interpreter.stdinStarvedReads == 0) return const [];
  return const [kStdinMissingHint];
}

/// 跑飞了的时候，把「其实是没有输入」这个更可能的原因说清楚。
///
/// 「疑似死循环」和「没给输入」的表现几乎一样（都在原地空转），但后者是
/// 新手最常踩的坑，报错只提死循环会把人带偏。
String _withStdinHint(String message, CInterpreter interpreter) {
  if (interpreter.stdinStarvedReads == 0) return message;
  return '$message\n'
      '注意：程序有 ${interpreter.stdinStarvedReads} 次读标准输入读到了空，'
      '很可能是缺输入导致的空转，而不是真的死循环。'
      '在项目根目录放一个 input.txt 写入程序需要的输入再试。';
}
