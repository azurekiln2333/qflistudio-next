/// C 解释器：在应用进程内直接执行 AST。
///
/// 不生成机器码、不落盘可执行文件、不 fork 子进程——因此在鸿蒙的普通应用
/// 沙箱里也能跑（系统禁止应用 exec 任意 ELF，但从不限制应用自己解释自己的
/// 数据）。
library;

import 'dart:convert';
import 'dart:typed_data';

import 'c_ast.dart';
import 'c_memory.dart';
import 'c_types.dart';
import 'c_value.dart';

/// 运行时错误（含未定义行为检测）。
class CRuntimeException implements Exception {
  CRuntimeException(this.message, {this.line});

  final String message;
  final int? line;

  @override
  String toString() => '运行时错误：$message';
}

/// 运行被中止：跑得太久。步数上限和墙钟上限共用这个基类，调用方一次捕获即可。
class CTimeoutException extends CRuntimeException {
  CTimeoutException(super.message);
}

/// 步数超过兜底上限。
///
/// 这是兜底而不是主要手段：同一个步数在紧凑循环和递归调用上差 20 倍时间
/// （实测约 2800 万步/秒 vs 120 万步/秒，函数调用要新建作用域），
/// 只看步数必然误杀其中一类。真正的控制在 [CTimeLimitException]。
class CStepLimitException extends CTimeoutException {
  CStepLimitException(int steps)
    : super('执行步数超过 $steps 步，已中止（可能是死循环）');
}

/// 运行时间超过上限。
class CTimeLimitException extends CTimeoutException {
  CTimeLimitException(Duration limit, int steps)
    : super(
        '运行超过 ${limit.inSeconds} 秒还没结束，已中止（可能是死循环，'
        '也可能只是算得慢；已执行 $steps 步）',
      );
}

/// 默认的墙钟时间上限。
///
/// 取值考虑：手机上的解释器比桌面慢 3~5 倍，10 秒在手机上约合桌面上的 2~3 秒
/// 计算量——足够跑完常见作业题（百万级循环约 0.1 秒，fib(28) 约 3 秒），
/// 又不至于让用户对着没有输出的界面干等太久。
const Duration kDefaultTimeLimit = Duration(seconds: 10);

/// 默认的步数兜底上限。
///
/// 按最快的情况（2800 万步/秒）算，2 亿步约合 7 秒，不会抢在时间上限前面触发；
/// 它的价值是给出一个确定性的、与设备速度无关的上界。
const int kDefaultMaxSteps = 200000000;

/// 每执行多少步检查一次墙钟时间。
///
/// `Stopwatch.elapsed` 不便宜，逐步检查会把解释器拖慢一大截；按 65536 步一次，
/// 在最快的情况下约合每 2 毫秒一次，精度足够。
const int _kTimeCheckInterval = 1 << 16;

/// 一个函数：要么是用户定义的，要么是内置的标准库实现。
class CFunction {
  CFunction({
    required this.name,
    required this.type,
    this.parameterNames = const [],
    this.body,
    this.builtin,
    this.line = 0,
  });

  final String name;
  final CFunctionType type;
  final List<String> parameterNames;
  final CCompound? body;
  final CValue Function(CInterpreter interpreter, List<CValue> arguments)?
  builtin;
  final int line;

  bool get isBuiltin => builtin != null;
}

/// 解释器。一次 [CInterpreter] 实例对应一次程序运行。
class CInterpreter {
  CInterpreter({
    this.maxSteps = kDefaultMaxSteps,
    this.timeLimit = kDefaultTimeLimit,
    this.outputSink,
  });

  /// 步数兜底上限，超出即中止。
  final int maxSteps;

  /// 墙钟时间上限，超出即中止。这是主要的「防死循环」手段。
  final Duration timeLimit;

  /// 每产生一行输出就回调一次，便于实时刷新终端。
  final void Function(String text)? outputSink;

  final CMemory mem = CMemory();
  final List<CFunction> functions = [];
  final Map<String, CFunction> _byName = {};

  /// 全局对象：名字 → 左值。
  final Map<String, CValue> globals = {};

  final List<Map<String, CValue>> _scopes = [];
  final Map<String, CValue> _stringLiterals = {};

  final StringBuffer _output = StringBuffer();
  int _steps = 0;
  int _exitCode = 0;
  bool _exited = false;

  /// 距离下次检查墙钟时间还剩多少步。
  int _stepsUntilTimeCheck = _kTimeCheckInterval;

  /// 程序尝试读标准输入、但输入已经耗尽的次数。
  ///
  /// 用来区分「真的死循环」和「因为没有输入而空转」——后者会表现成前者，
  /// 报「疑似死循环」会把用户带偏。
  int stdinStarvedReads = 0;

  /// 命令行参数（`main(int argc, char **argv)`）。
  List<String> programArguments = const [];

  /// 标准输入：按行提供，供 `getchar` / `scanf` 消费。移动端没有真正的
  /// 终端输入，由调用方（终端面板的输入框）注入。
  List<String> stdinLines = const [];

  int _stdinLineIndex = 0;
  int _stdinCharIndex = 0;
  final List<int> _stdinPushback = [];

  final Stopwatch _stopwatch = Stopwatch()..start();

  /// 已运行微秒数，供 `clock()` 使用。
  int get elapsedMicroseconds => _stopwatch.elapsedMicroseconds;

  int _randomState = 1;

  /// 与 C 的 `rand()` 同为线性同余，结果可复现。
  int nextRandom() {
    _randomState = (_randomState * 1103515245 + 12345) & 0x7FFFFFFF;
    return _randomState;
  }

  void seedRandom(int seed) => _randomState = seed & 0x7FFFFFFF;

  /// 读一个字符；输入耗尽返回 -1（EOF）。
  ///
  /// 输入按行给出，但对外是一个连续的字符流：行尾补 `'\n'`，这样 `getchar`
  /// 和 `scanf` 看到的行为和真正的 stdin 一致。
  int readStdinChar() {
    if (_stdinPushback.isNotEmpty) return _stdinPushback.removeLast();
    while (_stdinLineIndex < stdinLines.length) {
      final line = stdinLines[_stdinLineIndex];
      if (_stdinCharIndex < line.length) {
        return line.codeUnitAt(_stdinCharIndex++);
      }
      _stdinLineIndex++;
      _stdinCharIndex = 0;
      return 10; // '\n'
    }
    return -1;
  }

  /// 把一个字符退回输入流（`scanf` 需要「多读一个字符判断数字是否结束」）。
  ///
  /// 只回退，不重排，所以多次回退会以后进先出的顺序读出。
  void unreadStdinChar(int code) {
    if (code >= 0) _stdinPushback.add(code);
  }

  /// 读一整行（不含换行）；没有更多输入返回 null。
  ///
  /// 与 [readStdinChar] 共用同一个游标，所以 `getchar` 读剩下的半行
  /// 不会被 `fgets` 重复读一遍。
  String? readStdinLine() {
    final buffer = StringBuffer();
    var sawAnything = false;
    while (true) {
      final code = readStdinChar();
      if (code < 0) break;
      sawAnything = true;
      if (code == 10) break;
      if (code == 13) continue; // 吃掉 CR，避免 Windows 换行进到字符串里
      buffer.writeCharCode(code);
    }
    return sawAnything ? buffer.toString() : null;
  }

  String get output => _output.toString();

  int get exitCode => _exitCode;

  /// 已执行的步数，用于诊断「跑了多少」。
  int get stepCount => _steps;

  // ---- 输出 ----

  void write(String text) {
    if (text.isEmpty) return;
    _output.write(text);
    outputSink?.call(text);
  }

  void writeLine(String text) => write('$text\n');

  // ---- 注册 ----

  int registerFunction(CFunction function) {
    final existing = _byName[function.name];
    if (existing != null) {
      // 重复声明（头文件原型 + 实际定义）：
      // - 内置实现优先保留本体，但采用新声明的签名，保证 `double sqrt(double)`
      //   的返回类型不被头文件里的旧声明带偏；
      // - 先见原型后见定义时，用带函数体的那个替换掉空壳；
      // - 其余情况保留先到的那个。
      if (existing.isBuiltin && !function.isBuiltin) {
        final merged = CFunction(
          name: existing.name,
          type: function.type,
          parameterNames: function.parameterNames,
          body: function.body,
          builtin: existing.builtin,
          line: function.line,
        );
        final index = functions.indexOf(existing);
        functions[index] = merged;
        _byName[function.name] = merged;
        return index;
      }
      if (!existing.isBuiltin &&
          !function.isBuiltin &&
          existing.body == null &&
          function.body != null) {
        final index = functions.indexOf(existing);
        functions[index] = function;
        _byName[function.name] = function;
        return index;
      }
      return functions.indexOf(existing);
    }
    final index = functions.length;
    functions.add(function);
    _byName[function.name] = function;
    return index;
  }

  CFunction? lookupFunction(String name) => _byName[name];

  int functionAddress(CFunction function) =>
      CSpace.codeBase + functions.indexOf(function);

  CFunction? functionAtAddress(int address) {
    if (!CSpace.isCode(address)) return null;
    final index = CSpace.offsetOf(address);
    if (index < 0 || index >= functions.length) return null;
    return functions[index];
  }

  // ---- 作用域 ----

  void _pushScope() => _scopes.add(<String, CValue>{});

  void _popScope() => _scopes.removeLast();

  void _declare(String name, CValue value) => _scopes.last[name] = value;

  CValue? _lookup(String name) {
    for (var i = _scopes.length - 1; i >= 0; i--) {
      final found = _scopes[i][name];
      if (found != null) return found;
    }
    return globals[name];
  }

  // ---- 步数 / 时间控制 ----

  /// 解释器主循环每执行一步都要过这里。
  ///
  /// 两个上限各管一件事：步数是与设备速度无关的确定性兜底，时间才是真正
  /// 拦住死循环的那个（同一个步数在紧凑循环和递归调用上差 20 倍时间）。
  void _step() {
    _steps++;
    if (_steps > maxSteps) throw CStepLimitException(maxSteps);
    if (--_stepsUntilTimeCheck > 0) return;
    _stepsUntilTimeCheck = _kTimeCheckInterval;
    if (_stopwatch.elapsed > timeLimit) {
      throw CTimeLimitException(timeLimit, _steps);
    }
  }

  // ---- 程序入口 ----

  /// 执行整个翻译单元，返回 `main` 的返回值。
  int execute(CTranslationUnit unit, {List<String> arguments = const []}) {
    programArguments = arguments;
    _declareTopLevel(unit);
    _initializeGlobals(unit);

    final main = _byName['main'];
    if (main == null) {
      throw CRuntimeException('没有找到 main 函数');
    }

    final args = <CValue>[];
    if (main.type.parameters.isNotEmpty) {
      final argvAddress = _buildArgv(arguments);
      args.add(CValue(CTypes.intType, 0, immediate: arguments.length + 1));
      args.add(CValue(CTypes.charPointer, 0, immediate: argvAddress));
    }

    try {
      final result = _callFunction(main, args);
      if (_exited) return _exitCode;
      if (result.type is CIntegerType) {
        return _readScalar(result) as int;
      }
      return 0;
    } on _ExitSignal catch (signal) {
      return signal.code;
    }
  }

  /// 构造 `char **argv`，返回其地址。
  int _buildArgv(List<String> arguments) {
    final all = ['program', ...arguments];
    final pointerArray = mem.allocateGlobals(all.length * 8 + 8, 8);
    for (var i = 0; i < all.length; i++) {
      final stringAddress = _internString(all[i]);
      mem.writeInt(pointerArray + i * 8, 8, stringAddress);
    }
    mem.writeInt(pointerArray + all.length * 8, 8, 0);
    return pointerArray;
  }

  void _declareTopLevel(CTranslationUnit unit) {
    for (final item in unit.items) {
      switch (item) {
        case CFunctionDefinition(
          :final name,
          :final type,
          :final parameterNames,
          :final body,
          :final line,
        ):
          registerFunction(
            CFunction(
              name: name,
              type: type,
              parameterNames: parameterNames,
              body: body,
              line: line,
            ),
          );
        case CTopLevelDeclaration(:final declaration):
          if (declaration.isTypedef) continue;
          for (final declarator in declaration.declarators) {
            if (declarator.type is CFunctionType) {
              // 函数原型：只登记签名。
              registerFunction(
                CFunction(
                  name: declarator.name,
                  type: declarator.type as CFunctionType,
                  line: declarator.line,
                ),
              );
            }
          }
        }
    }
  }

  void _initializeGlobals(CTranslationUnit unit) {
    _pushScope();
    for (final item in unit.items) {
      if (item is! CTopLevelDeclaration) continue;
      final declaration = item.declaration;
      if (declaration.isTypedef) continue;
      for (final declarator in declaration.declarators) {
        if (declarator.type is CFunctionType) continue;
        final address = mem.allocateGlobals(
          declarator.type.size,
          declarator.type.align,
        );
        final lvalue = CValue(declarator.type, address, isLValue: true);
        globals[declarator.name] = lvalue;
        if (declarator.initializer != null) {
          _applyInitializer(lvalue, declarator.initializer!);
        }
      }
    }
    _popScope();
  }

  // ---- 语句 ----

  void _execStmt(CStmt stmt) {
    _step();
    switch (stmt) {
      case CCompound(:final items):
        _pushScope();
        try {
          _execBlock(items);
        } finally {
          _popScope();
        }
      case CDeclarationStatement(:final declaration):
        _execDeclaration(declaration);
      case CExprStatement(:final expr):
        _eval(expr);
      case CIf(:final condition, :final thenBranch, :final elseBranch):
        if (_truthy(_eval(condition))) {
          _execStmt(thenBranch);
        } else if (elseBranch != null) {
          _execStmt(elseBranch);
        }
      case CWhile(:final condition, :final body, :final doWhile):
        if (doWhile) {
          while (true) {
            try {
              _execStmt(body);
            } on _BreakSignal {
              break;
            } on _ContinueSignal {
              // 继续判断条件。
            }
            final mark = mem.markTemps();
            final keep = _truthy(_eval(condition));
            mem.releaseTemps(mark);
            if (!keep) break;
          }
        } else {
          while (true) {
            final mark = mem.markTemps();
            final keep = _truthy(_eval(condition));
            mem.releaseTemps(mark);
            if (!keep) break;
            try {
              _execStmt(body);
            } on _BreakSignal {
              break;
            } on _ContinueSignal {
              continue;
            }
          }
        }
      case CFor(:final init, :final condition, :final step, :final body):
        if (init != null) _execStmt(init);
        while (true) {
          if (condition != null) {
            final mark = mem.markTemps();
            final keep = _truthy(_eval(condition));
            mem.releaseTemps(mark);
            if (!keep) break;
          }
          try {
            _execStmt(body);
          } on _BreakSignal {
            break;
          } on _ContinueSignal {
            // 落到步进表达式。
          }
          if (step != null) {
            final mark = mem.markTemps();
            _eval(step);
            mem.releaseTemps(mark);
          }
        }
      case CSwitch(:final condition, :final body):
        _execSwitch(condition, body);
      case CCaseLabel():
        // 由 _execSwitch 处理。
        break;
      case CBreak():
        throw _BreakSignal();
      case CContinue():
        throw _ContinueSignal();
      case CReturn(:final value):
        throw _ReturnSignal(value == null ? null : _eval(value));
      case CGoto(:final label):
        throw _GotoSignal(label);
      case CLabeled(:final statement):
        _execStmt(statement);
      case CEmpty():
        break;
    }
  }

  /// 执行一组语句，并在本层拦截指向本层标签的 goto。
  void _execBlock(List<CStmt> items) {
    final labels = <String, int>{};
    for (var i = 0; i < items.length; i++) {
      final item = items[i];
      if (item is CLabeled) labels[item.label] = i;
    }

    var index = 0;
    while (index < items.length) {
      final item = items[index];
      if (item is CLabeled) {
        _step();
        try {
          _execStmt(item.statement);
        } on _GotoSignal catch (signal) {
          final target = labels[signal.label];
          if (target == null) rethrow;
          index = target;
          continue;
        }
        index++;
        continue;
      }
      if (item is CCaseLabel) {
        index++;
        continue;
      }
      try {
        _execStmt(item);
      } on _GotoSignal catch (signal) {
        final target = labels[signal.label];
        if (target == null) rethrow;
        index = target;
        continue;
      }
      index++;
    }
  }

  void _execSwitch(CExpr condition, CStmt body) {
    final value = _readScalar(_eval(condition)) as int;

    // 把 switch 体摊平成「语句 + case 标记」序列。
    final statements = <CStmt>[];
    final caseIndex = <int, int>{}; // case 值 → 语句下标
    var defaultIndex = -1;

    void flatten(CStmt stmt) {
      if (stmt is CCompound) {
        for (final item in stmt.items) {
          flatten(item);
        }
        return;
      }
      if (stmt is CCaseLabel) {
        if (stmt.value == null) {
          defaultIndex = statements.length;
        } else {
          caseIndex[stmt.value!] = statements.length;
        }
        return;
      }
      statements.add(stmt);
    }

    flatten(body);

    var start = caseIndex[value];
    start ??= defaultIndex;
    if (start < 0) return;

    var index = start;
    while (index < statements.length) {
      try {
        _execStmt(statements[index]);
      } on _BreakSignal {
        return;
      } on _GotoSignal {
        rethrow;
      }
      index++;
    }
  }

  // ---- 声明 ----

  void _execDeclaration(CDeclaration declaration) {
    if (declaration.isTypedef) return;
    for (final declarator in declaration.declarators) {
      if (declarator.type is CFunctionType) continue;

      var type = _resolveArrayLength(declarator.type, declarator.initializer);
      final address = mem.allocateStack(type.size, type.align);
      final lvalue = CValue(type, address, isLValue: true);
      _declare(declarator.name, lvalue);
      if (declarator.initializer != null) {
        _applyInitializer(lvalue, declarator.initializer!);
      }
    }
  }

  /// 未定长数组按初始化器推导长度：`int a[] = {1,2,3}`、`char s[] = "abc"`。
  CType _resolveArrayLength(CType type, CInitializer? initializer) {
    if (type is! CArrayType || type.length >= 0 || initializer == null) {
      return type;
    }
    if (initializer is CListInitializer) {
      return CArrayType(type.element, initializer.items.length);
    }
    if (initializer is CExprInitializer && initializer.expr is CStringLiteral) {
      final literal = initializer.expr as CStringLiteral;
      return CArrayType(type.element, utf8.encode(literal.value).length + 1);
    }
    return type;
  }

  void _applyInitializer(CValue target, CInitializer initializer) {
    switch (initializer) {
      case CExprInitializer(:final expr):
        // `char s[8] = "abc";` 走字节拷贝，而不是当成标量赋值。
        if (target.type is CArrayType && expr is CStringLiteral) {
          writeCString(
            target.address,
            expr.value,
            capacity: (target.type as CArrayType).length,
          );
          return;
        }
        final value = _eval(expr);
        _store(target, _convert(value, target.type));
      case CListInitializer(:final items):
        var type = target.type;
        if (type is CArrayType) {
          var element = type.element;
          if (element is CArrayType && element.length < 0) {
            element = CArrayType(element.element, items.length);
            type = CArrayType(element, type.length);
          }
          for (var i = 0; i < items.length; i++) {
            final elementAddress = target.address + i * element.size;
            _applyInitializer(
              CValue(element, elementAddress, isLValue: true),
              items[i],
            );
          }
        } else if (type is CRecordType) {
          final fields = type.fields;
          for (var i = 0; i < items.length && i < fields.length; i++) {
            final field = fields[i];
            final fieldAddress = target.address + type.offsetOf(field.name);
            _applyInitializer(
              CValue(field.type, fieldAddress, isLValue: true),
              items[i],
            );
          }
        } else if (items.isNotEmpty) {
          _applyInitializer(target, items.first);
        }
    }
  }

  // ---- 表达式 ----

  CValue _eval(CExpr expr) {
    _step();
    switch (expr) {
      case CIntLiteral(:final value, :final literalType):
        return CValue(literalType, 0, immediate: value);
      case CFloatLiteral(:final value, :final literalType):
        return CValue(literalType, 0, immediate: value);
      case CStringLiteral(:final value, :final arrayType):
        return CValue(
          arrayType,
          _internString(value),
          isLValue: true,
        );
      case CIdentifier():
        return _evalIdentifier(expr);
      case CUnary():
        return _evalUnary(expr);
      case CBinary():
        return _evalBinary(expr);
      case CAssign():
        return _evalAssign(expr);
      case CConditional(
        :final condition,
        :final thenExpr,
        :final elseExpr,
      ):
        return _truthy(_eval(condition)) ? _eval(thenExpr) : _eval(elseExpr);
      case CCall():
        return _evalCall(expr);
      case CIndex(:final array, :final index):
        return _evalIndex(array, index);
      case CMember(:final object, :final name, :final arrow):
        return _evalMember(object, name, arrow);
      case CCast(:final targetType, :final operand):
        return _convert(_eval(operand), targetType);
      case CSizeof(:final operandType, :final operand):
        if (operandType != null) {
          return CValue(
            CTypes.unsignedLong,
            0,
            immediate: operandType.size,
          );
        }
        final type = _typeOfExpr(operand!);
        return CValue(CTypes.unsignedLong, 0, immediate: type.size);
      case CComma(:final items):
        CValue last = CValue(CTypes.voidType, 0, immediate: 0);
        for (final item in items) {
          last = _eval(item);
        }
        return last;
    }
  }

  CValue _evalIdentifier(CIdentifier expr) {
    final found = _lookup(expr.name);
    if (found != null) return found;
    final function = _byName[expr.name];
    if (function != null) {
      final address = functionAddress(function);
      return CValue(CPointerType(function.type), 0, immediate: address);
    }
    throw CRuntimeException('未定义的标识符 "${expr.name}"', line: expr.line);
  }

  CValue _evalUnary(CUnary expr) {
    final op = expr.op;

    if (op == '&') {
      final operand = _eval(expr.operand);
      if (!operand.isLValue) {
        throw CRuntimeException('对非左值取地址', line: expr.line);
      }
      return CValue(CPointerType(operand.type), 0, immediate: operand.address);
    }

    if (op == '*') {
      final operand = _rvalue(_eval(expr.operand));
      if (operand.type is! CPointerType) {
        throw CRuntimeException(
          '对非指针类型 ${operand.type} 解引用',
          line: expr.line,
        );
      }
      final pointee = (operand.type as CPointerType).to;
      final address = _pointerValue(operand);
      if (address == 0) {
        throw CRuntimeException('空指针解引用', line: expr.line);
      }
      return CValue(pointee, address, isLValue: true);
    }

    if (op == '++' || op == '--') {
      final operand = _eval(expr.operand);
      if (!operand.isLValue) {
        throw CRuntimeException('$op 需要左值', line: expr.line);
      }
      final before = _rvalue(operand);
      final one = CValue(CTypes.intType, 0, immediate: 1);
      final after = op == '++'
          ? _binaryArithmetic('+', before, one)
          : _binaryArithmetic('-', before, one);
      _store(operand, _convert(after, operand.type));
      return expr.postfix ? before : _rvalue(operand);
    }

    final operand = _rvalue(_eval(expr.operand));
    switch (op) {
      case '+':
        return _promoteNumeric(operand);
      case '-':
        final numeric = _promoteNumeric(operand);
        return numeric.immediate is double
            ? CValue(numeric.type, 0, immediate: -(numeric.immediate! as double))
            : CValue(numeric.type, 0, immediate: -numeric.asInt);
      case '~':
        final numeric = _promoteNumeric(operand);
        return CValue(numeric.type, 0, immediate: ~numeric.asInt);
      case '!':
        return CValue(CTypes.intType, 0, immediate: _truthy(operand) ? 0 : 1);
      default:
        throw CRuntimeException('不支持的一元运算符 $op', line: expr.line);
    }
  }

  CValue _evalBinary(CBinary expr) {
    final op = expr.op;

    if (op == '&&') {
      if (!_truthy(_eval(expr.left))) {
        return CValue(CTypes.intType, 0, immediate: 0);
      }
      return CValue(
        CTypes.intType,
        0,
        immediate: _truthy(_eval(expr.right)) ? 1 : 0,
      );
    }
    if (op == '||') {
      if (_truthy(_eval(expr.left))) {
        return CValue(CTypes.intType, 0, immediate: 1);
      }
      return CValue(
        CTypes.intType,
        0,
        immediate: _truthy(_eval(expr.right)) ? 1 : 0,
      );
    }

    final left = _rvalue(_eval(expr.left));
    final right = _rvalue(_eval(expr.right));

    switch (op) {
      case '+':
      case '-':
      case '*':
      case '/':
      case '%':
        return _binaryArithmetic(op, left, right);
      case '<<':
      case '>>':
        final shift = _promoteNumeric(right).asInt;
        final numeric = _promoteNumeric(left);
        final value = numeric.immediate is double
            ? (numeric.immediate! as double).toInt()
            : numeric.asInt;
        if (shift < 0 || shift > 64) {
          throw CRuntimeException('移位位数 $shift 非法', line: expr.line);
        }
        return CValue(
          numeric.type,
          0,
          immediate: op == '<<' ? value << shift : value >> shift,
        );
      case '&':
      case '|':
      case '^':
        return _binaryBitwise(op, left, right);
      default:
        return _compare(op, left, right, expr.line);
    }
  }

  CValue _binaryArithmetic(String op, CValue left, CValue right) {
    // 指针算术。
    if (left.type is CPointerType || right.type is CPointerType) {
      return _pointerArithmetic(op, left, right);
    }

    final type = _commonArithmeticType(left.type, right.type);
    if (type is CFloatType) {
      final a = _toDouble(left);
      final b = _toDouble(right);
      final result = switch (op) {
        '+' => a + b,
        '-' => a - b,
        '*' => a * b,
        '/' => a / b,
        _ => throw CRuntimeException('浮点数不支持 $op'),
      };
      return CValue(type, 0, immediate: result);
    }

    final integerType = type as CIntegerType;
    final a = _readScalar(_convert(left, integerType)) as int;
    final b = _readScalar(_convert(right, integerType)) as int;
    int result;
    switch (op) {
      case '+':
        result = a + b;
      case '-':
        result = a - b;
      case '*':
        result = a * b;
      case '/':
        if (b == 0) throw CRuntimeException('整数除以零');
        if (integerType.isSigned) {
          result = a ~/ b;
        } else {
          result = _unsignedDivide(a, b, integerType.bits);
        }
      case '%':
        if (b == 0) throw CRuntimeException('整数取模零');
        if (integerType.isSigned) {
          result = a % b;
        } else {
          result = _unsignedModulo(a, b, integerType.bits);
        }
      default:
        throw CRuntimeException('不支持的算术运算符 $op');
    }
    return CValue(integerType, 0, immediate: _wrap(result, integerType));
  }

  CValue _binaryBitwise(String op, CValue left, CValue right) {
    final type = _commonArithmeticType(left.type, right.type) as CIntegerType;
    final a = _readScalar(_convert(left, type)) as int;
    final b = _readScalar(_convert(right, type)) as int;
    final result = switch (op) {
      '&' => a & b,
      '|' => a | b,
      _ => a ^ b,
    };
    return CValue(type, 0, immediate: _wrap(result, type));
  }

  CValue _pointerArithmetic(String op, CValue left, CValue right) {
    final leftIsPointer = left.type is CPointerType;
    final rightIsPointer = right.type is CPointerType;

    if (leftIsPointer && rightIsPointer) {
      if (op != '-') {
        throw CRuntimeException('两个指针不支持 $op 运算');
      }
      final elementSize = (left.type as CPointerType).to.size;
      final delta = _pointerValue(left) - _pointerValue(right);
      if (elementSize <= 0) return CValue(CTypes.longType, 0, immediate: delta);
      return CValue(CTypes.longType, 0, immediate: delta ~/ elementSize);
    }

    final pointer = leftIsPointer ? left : right;
    final indexValue = leftIsPointer ? right : left;
    final elementType = (pointer.type as CPointerType).to;
    final count = _readScalar(_convert(indexValue, CTypes.longType)) as int;
    final delta = count * elementType.size;
    final base = _pointerValue(pointer);
    final address = op == '-' ? base - delta : base + delta;
    // 结果是指针「值」而不是对象地址，必须带 immediate，否则会被当成
    // 内存里存的指针再读一次。
    return CValue(pointer.type, 0, immediate: address);
  }

  CValue _compare(String op, CValue left, CValue right, int line) {
    // 指针比较。
    if (left.type is CPointerType || right.type is CPointerType) {
      final a = _pointerValue(left);
      final b = _pointerValue(right);
      return CValue(
        CTypes.intType,
        0,
        immediate: _applyComparison(op, a, b) ? 1 : 0,
      );
    }

    final type = _commonArithmeticType(left.type, right.type);
    if (type is CFloatType) {
      final a = _toDouble(left);
      final b = _toDouble(right);
      return CValue(
        CTypes.intType,
        0,
        immediate: _applyComparison(op, a, b) ? 1 : 0,
      );
    }
    final a = _readScalar(_convert(left, type)) as int;
    final b = _readScalar(_convert(right, type)) as int;
    return CValue(
      CTypes.intType,
      0,
      immediate: _applyComparison(op, a, b) ? 1 : 0,
    );
  }

  static bool _applyComparison(String op, num a, num b) => switch (op) {
    '==' => a == b,
    '!=' => a != b,
    '<' => a < b,
    '>' => a > b,
    '<=' => a <= b,
    '>=' => a >= b,
    _ => throw CRuntimeException('不支持的比较运算符 $op'),
  };

  CValue _evalAssign(CAssign expr) {
    final target = _eval(expr.target);
    if (!target.isLValue) {
      throw CRuntimeException('赋值目标不是左值', line: expr.line);
    }

    if (expr.op == '=') {
      final value = _eval(expr.value);
      final converted = _convert(value, target.type);
      _store(target, converted);
      return _rvalue(target);
    }

    final current = _rvalue(target);
    final right = _rvalue(_eval(expr.value));
    final op = expr.op.substring(0, expr.op.length - 1);
    final CValue result;
    switch (op) {
      case '+':
      case '-':
      case '*':
      case '/':
      case '%':
        result = _binaryArithmetic(op, current, right);
      case '&':
      case '|':
      case '^':
        result = _binaryBitwise(op, current, right);
      case '<<':
      case '>>':
        final shift = _promoteNumeric(right).asInt;
        final numeric = _promoteNumeric(current);
        result = CValue(
          numeric.type,
          0,
          immediate: op == '<<' ? numeric.asInt << shift : numeric.asInt >> shift,
        );
      default:
        throw CRuntimeException('不支持的复合赋值 ${expr.op}', line: expr.line);
    }
    final converted = _convert(result, target.type);
    _store(target, converted);
    return _rvalue(target);
  }

  CValue _evalIndex(CExpr arrayExpr, CExpr indexExpr) {
    final base = _rvalue(_eval(arrayExpr));
    final index = _readScalar(_convert(_rvalue(_eval(indexExpr)), CTypes.longType)) as int;

    CType elementType;
    int baseAddress;
    if (base.type is CArrayType) {
      elementType = (base.type as CArrayType).element;
      baseAddress = base.address;
    } else if (base.type is CPointerType) {
      elementType = (base.type as CPointerType).to;
      baseAddress = _pointerValue(base);
    } else {
      throw CRuntimeException('对非数组类型 ${base.type} 使用下标');
    }

    return CValue(
      elementType,
      baseAddress + index * elementType.size,
      isLValue: true,
    );
  }

  CValue _evalMember(CExpr objectExpr, String name, bool arrow) {
    final object = arrow ? _rvalue(_eval(objectExpr)) : _eval(objectExpr);
    CType recordType;
    int baseAddress;
    if (arrow) {
      if (object.type is! CPointerType) {
        throw CRuntimeException('-> 左侧必须是指针，实际是 ${object.type}');
      }
      recordType = (object.type as CPointerType).to;
      baseAddress = _pointerValue(object);
      if (baseAddress == 0) throw CRuntimeException('空指针访问成员 $name');
    } else {
      recordType = object.type;
      baseAddress = object.address;
    }

    if (recordType is! CRecordType) {
      throw CRuntimeException('${arrow ? '->' : '.'} 左侧不是结构体/联合体');
    }
    final field = recordType.field(name);
    if (field == null) {
      throw CRuntimeException('${recordType.tag} 没有成员 "$name"');
    }
    return CValue(
      field.type,
      baseAddress + recordType.offsetOf(name),
      isLValue: true,
    );
  }

  CValue _evalCall(CCall expr) {
    CFunction? target;
    if (expr.callee is CIdentifier) {
      target = _byName[(expr.callee as CIdentifier).name];
    }
    if (target == null) {
      final callee = _rvalue(_eval(expr.callee));
      final address = callee.type is CPointerType
          ? _pointerValue(callee)
          : callee.address;
      target = functionAtAddress(address);
      if (target == null) {
        throw CRuntimeException('调用了不是函数的值', line: expr.line);
      }
    }

    final rawArguments = <CValue>[];
    for (final argument in expr.arguments) {
      rawArguments.add(_rvalue(_eval(argument)));
    }

    // 有原型：按参数类型转换；变参部分做默认实参提升。
    final parameters = target.type.parameters;
    final arguments = <CValue>[];
    for (var i = 0; i < rawArguments.length; i++) {
      if (i < parameters.length) {
        arguments.add(_convert(rawArguments[i], parameters[i]));
      } else {
        arguments.add(_defaultArgumentPromotion(rawArguments[i]));
      }
    }

    return _callFunction(target, arguments);
  }

  CValue _callFunction(CFunction function, List<CValue> arguments) {
    if (function.isBuiltin) {
      return function.builtin!(this, arguments);
    }

    final body = function.body;
    if (body == null) {
      throw CRuntimeException('函数 "${function.name}" 只有声明没有定义');
    }

    final stackMark = mem.markStack();
    final tempMark = mem.markTemps();
    _pushScope();

    CValue? returned;
    var hasReturn = false;

    try {
      for (var i = 0; i < function.parameterNames.length; i++) {
        final name = function.parameterNames[i];
        if (name.isEmpty) continue;
        final parameterType = i < function.type.parameters.length
            ? function.type.parameters[i]
            : CTypes.intType;
        final address = mem.allocateStack(
          parameterType.size,
          parameterType.align,
        );
        final slot = CValue(parameterType, address, isLValue: true);
        if (i < arguments.length) {
          _store(slot, _convert(arguments[i], parameterType));
        }
        _declare(name, slot);
      }
      _execStmt(body);
    } on _ReturnSignal catch (signal) {
      returned = signal.value;
      hasReturn = true;
    } finally {
      _popScope();
      mem.releaseStack(stackMark);
      mem.releaseTemps(tempMark);
    }

    final returnType = function.type.returnType;
    if (returnType is CVoidType) {
      return CValue(CTypes.voidType, 0, immediate: 0);
    }
    if (!hasReturn || returned == null) {
      return CValue(returnType, 0, immediate: 0);
    }
    return _copyOut(returned, returnType);
  }

  /// 把返回值复制到调用者的临时区（被调用者的栈已经回滚）。
  CValue _copyOut(CValue value, CType returnType) {
    if (returnType is CRecordType || returnType is CArrayType) {
      final address = mem.allocateTemp(returnType.size, returnType.align);
      if (value.isImmediate) {
        return CValue(returnType, address, isLValue: true);
      }
      mem.copy(value.address, address, returnType.size);
      return CValue(returnType, address, isLValue: true);
    }
    final converted = _convert(value, returnType);
    if (converted.isImmediate) return converted;
    // 标量可能还指着被回滚的区域，落到临时区。
    final size = returnType.size == 0 ? 8 : returnType.size;
    final address = mem.allocateTemp(size, returnType.align);
    mem.copy(converted.address, address, size);
    return CValue(returnType, address, isLValue: false);
  }

  /// 默认实参提升：float → double，小整数 → int。
  CValue _defaultArgumentPromotion(CValue value) {
    if (value.type is CFloatType) {
      if ((value.type as CFloatType).size == 4) {
        return CValue(
          CTypes.doubleType,
          0,
          immediate: _toDouble(value),
        );
      }
      return value;
    }
    if (value.type is CIntegerType) {
      final promoted = _promoteInteger(value.type as CIntegerType);
      return _convert(value, promoted);
    }
    return value;
  }

  // ---- 类型与转换 ----

  CValue _rvalue(CValue value) {
    if (value.isImmediate) return value;
    if (value.type is CArrayType) {
      // 数组退化为指向首元素的指针：地址即指针值。
      return CValue(
        CPointerType((value.type as CArrayType).element),
        0,
        immediate: value.address,
      );
    }
    if (value.type is CRecordType) return value;
    if (value.type is CVoidType) return value;
    return CValue(value.type, value.address, immediate: _readMemory(value));
  }

  Object _readMemory(CValue value) {
    final type = value.type;
    if (type is CFloatType) {
      return type.size == 4 ? mem.readFloat(value.address) : mem.readDouble(value.address);
    }
    if (type is CIntegerType) {
      return mem.readInt(value.address, type.size, signed: type.isSigned);
    }
    if (type is CPointerType) {
      return mem.readInt(value.address, 8);
    }
    if (type is CEnumType) {
      return mem.readInt(value.address, 4, signed: true);
    }
    return mem.readInt(value.address, 8);
  }

  /// 取标量值：整数返回 int，浮点返回 double。
  Object _readScalar(CValue value) {
    if (value.isImmediate) return value.immediate!;
    final type = value.type;
    if (type is CFloatType) return _readMemory(value);
    if (type is CPointerType) return _pointerValue(value);
    if (type is CIntegerType) {
      return mem.readInt(value.address, type.size, signed: type.isSigned);
    }
    if (type is CEnumType) return mem.readInt(value.address, 4, signed: true);
    if (type is CRecordType) return value.address;
    return mem.readInt(value.address, 8);
  }

  int _pointerValue(CValue value) {
    if (value.isImmediate) return value.immediate as int;
    if (CSpace.isCode(value.address)) return value.address;
    if (value.type is CPointerType) return mem.readInt(value.address, 8);
    return value.address;
  }

  bool _truthy(CValue value) {
    final scalar = _readScalar(_rvalue(value));
    if (scalar is double) return scalar != 0;
    return (scalar as int) != 0;
  }

  CValue _convert(CValue value, CType target) {
    if (target is CVoidType) return value;
    final source = value.type;

    if (target is CPointerType) {
      if (source is CPointerType) {
        return CValue(target, 0, immediate: _pointerValue(value));
      }
      if (source is CArrayType) {
        return CValue(target, 0, immediate: value.address);
      }
      if (source is CIntegerType) {
        final raw = _readScalar(_rvalue(value)) as int;
        return CValue(target, 0, immediate: raw);
      }
      if (source is CFunctionType) {
        return CValue(target, 0, immediate: value.address);
      }
      if (source is CEnumType) {
        return CValue(target, 0, immediate: _readScalar(_rvalue(value)) as int);
      }
      return CValue(target, 0, immediate: value.address);
    }

    if (target is CIntegerType) {
      final scalar = _readScalar(_rvalue(value));
      int raw;
      if (scalar is double) {
        if (scalar.isNaN || scalar.isInfinite) {
          raw = 0;
        } else {
          raw = scalar.truncate();
        }
      } else {
        raw = scalar as int;
      }
      return CValue(target, 0, immediate: _wrap(raw, target));
    }

    if (target is CFloatType) {
      final scalar = _readScalar(_rvalue(value));
      final double result = scalar is double ? scalar : (scalar as int).toDouble();
      return CValue(target, 0, immediate: result);
    }

    if (target is CEnumType) {
      final scalar = _readScalar(_rvalue(value)) as int;
      return CValue(target, 0, immediate: scalar);
    }

    if (target is CRecordType) {
      if (value.isImmediate) return value;
      final address = mem.allocateTemp(target.size, target.align);
      mem.copy(value.address, address, target.size);
      return CValue(target, address, isLValue: true);
    }

    return value;
  }

  static int _wrap(int value, CIntegerType type) {
    if (type.bits >= 64) return value;
    final mask = (1 << type.bits) - 1;
    var result = value & mask;
    if (type.isSigned && (result & (1 << (type.bits - 1))) != 0) {
      result -= 1 << type.bits;
    }
    return result;
  }

  static int _unsignedDivide(int a, int b, int bits) {
    final ua = _toUnsignedBig(a, bits);
    final ub = _toUnsignedBig(b, bits);
    return _fromUnsignedBig(ua ~/ ub, bits);
  }

  static int _unsignedModulo(int a, int b, int bits) {
    final ua = _toUnsignedBig(a, bits);
    final ub = _toUnsignedBig(b, bits);
    return _fromUnsignedBig(ua % ub, bits);
  }

  static BigInt _toUnsignedBig(int value, int bits) {
    if (value >= 0) return BigInt.from(value);
    return BigInt.from(value) + (BigInt.one << bits);
  }

  static int _fromUnsignedBig(BigInt value, int bits) {
    final signBit = BigInt.one << (bits - 1);
    if (value >= signBit) {
      return (value - (BigInt.one << bits)).toInt();
    }
    return value.toInt();
  }

  void _store(CValue target, CValue value) {
    final type = target.type;
    if (type is CRecordType) {
      if (value.isImmediate) {
        throw CRuntimeException('无法把纯值存入结构体');
      }
      mem.copy(value.address, target.address, type.size);
      return;
    }
    if (type is CArrayType) {
      throw CRuntimeException('数组不能整体赋值');
    }
    if (value.isImmediate) {
      final immediate = value.immediate!;
      if (type is CFloatType) {
        final d = immediate is double ? immediate : (immediate as int).toDouble();
        if (type.size == 4) {
          mem.writeFloat(target.address, d);
        } else {
          mem.writeDouble(target.address, d);
        }
        return;
      }
      final raw = immediate is double ? immediate.truncate() : immediate as int;
      final size = type.size == 0 ? 8 : type.size;
      mem.writeInt(target.address, size, raw);
      return;
    }

    // 从内存取值：可能跨区域，统一走字节复制。
    final size = type.size == 0 ? 8 : type.size;
    mem.copy(value.address, target.address, size);
  }

  CType _commonArithmeticType(CType left, CType right) {
    if (left is CFloatType || right is CFloatType) {
      if (left is CFloatType && right is CFloatType) {
        return left.size >= right.size ? left : right;
      }
      return left is CFloatType ? left : right;
    }
    final a = _promoteInteger(_asInteger(left));
    final b = _promoteInteger(_asInteger(right));
    if (a == b) return a;
    if (a.bits == b.bits) return a.isSigned ? b : a;
    final wider = a.bits > b.bits ? a : b;
    return wider;
  }

  static CIntegerType _asInteger(CType type) {
    if (type is CIntegerType) return type;
    if (type is CEnumType) return CTypes.intType;
    if (type is CPointerType) return CTypes.unsignedLong;
    return CTypes.intType;
  }

  static CIntegerType _promoteInteger(CIntegerType type) {
    if (type.bits < 32) return CTypes.intType;
    return type;
  }

  /// 整数提升 / 浮点保持，返回一个「纯值」形态的 CValue。
  CValue _promoteNumeric(CValue value) {
    final type = value.type;
    if (type is CFloatType) {
      return CValue(type, 0, immediate: _toDouble(value));
    }
    final integer = _promoteInteger(_asInteger(type));
    return CValue(
      integer,
      0,
      immediate: _readScalar(_convert(value, integer)) as int,
    );
  }

  double _toDouble(CValue value) {
    final scalar = _readScalar(_rvalue(value));
    return scalar is double ? scalar : (scalar as int).toDouble();
  }

  // ---- 静态类型推导（供 sizeof 使用） ----

  CType _typeOfExpr(CExpr expr) {
    switch (expr) {
      case CIntLiteral(:final literalType):
        return literalType;
      case CFloatLiteral(:final literalType):
        return literalType;
      case CStringLiteral(:final arrayType):
        return arrayType;
      case CIdentifier(:final name):
        final found = _lookup(name);
        if (found != null) return found.type;
        final function = _byName[name];
        if (function != null) return CPointerType(function.type);
        return CTypes.intType;
      case CUnary(:final op, :final operand):
        if (op == '&') return CPointerType(_typeOfExpr(operand));
        if (op == '*') {
          final type = _typeOfExpr(operand);
          if (type is CPointerType) return type.to;
          if (type is CArrayType) return type.element;
          return CTypes.intType;
        }
        if (op == '!' || op == '++' || op == '--') return _typeOfExpr(operand);
        return _promoteInteger(_asInteger(_typeOfExpr(operand)));
      case CBinary(:final op, :final left, :final right):
        if (const {'==', '!=', '<', '>', '<=', '>=', '&&', '||'}.contains(op)) {
          return CTypes.intType;
        }
        return _commonArithmeticType(_typeOfExpr(left), _typeOfExpr(right));
      case CAssign(:final target):
        return _typeOfExpr(target);
      case CConditional(:final thenExpr, :final elseExpr):
        return _commonArithmeticType(
          _typeOfExpr(thenExpr),
          _typeOfExpr(elseExpr),
        );
      case CCall(:final callee):
        if (callee is CIdentifier) {
          final function = _byName[callee.name];
          if (function != null) return function.type.returnType;
        }
        final type = _typeOfExpr(callee);
        if (type is CPointerType && type.to is CFunctionType) {
          return (type.to as CFunctionType).returnType;
        }
        return CTypes.intType;
      case CIndex(:final array):
        final type = _typeOfExpr(array);
        if (type is CArrayType) return type.element;
        if (type is CPointerType) return type.to;
        return CTypes.intType;
      case CMember(:final object, :final name):
        var type = _typeOfExpr(object);
        if (type is CPointerType) type = type.to;
        if (type is CRecordType) {
          return type.field(name)?.type ?? CTypes.intType;
        }
        return CTypes.intType;
      case CCast(:final targetType):
        return targetType;
      case CSizeof():
        return CTypes.unsignedLong;
      case CComma(:final items):
        return _typeOfExpr(items.last);
    }
  }

  // ---- 字符串与内存辅助 ----

  /// 把 Dart 字符串以 UTF-8 + NUL 放进全局区，同一内容只存一份。
  int _internString(String value) {
    final cached = _stringLiterals[value];
    if (cached != null) return cached.address;

    final bytes = <int>[...utf8.encode(value), 0];
    final address = mem.allocateGlobals(bytes.length, 1);
    mem.writeBytes(address, bytes);
    final type = CArrayType(CTypes.charType, bytes.length);
    _stringLiterals[value] = CValue(type, address, isLValue: true);
    return address;
  }

  /// 分配一段全局内存并写入字节（内置函数构造返回值时用）。
  int allocateGlobalBytes(List<int> bytes) {
    final address = mem.allocateGlobals(bytes.isEmpty ? 1 : bytes.length, 1);
    mem.writeBytes(address, bytes);
    return address;
  }

  /// 读 C 字符串（UTF-8，遇 NUL 结束）。
  String readCString(int address, {int maxLength = 1 << 20}) {
    if (address == 0) return '';
    final bytes = <int>[];
    var offset = 0;
    while (offset < maxLength) {
      final byte = mem.readInt(address + offset, 1);
      if (byte == 0) break;
      bytes.add(byte);
      offset++;
    }
    return utf8.decode(bytes, allowMalformed: true);
  }

  /// 写 C 字符串到 [address]，最多 [capacity] 字节（含结尾 NUL）。
  void writeCString(int address, String value, {int? capacity}) {
    final bytes = utf8.encode(value);
    final limit = capacity ?? (bytes.length + 1);
    final count = bytes.length < limit - 1 ? bytes.length : limit - 1;
    mem.writeBytes(address, bytes.sublist(0, count));
    mem.writeInt(address + count, 1, 0);
  }

  Never exit(int code) {
    _exited = true;
    _exitCode = code;
    throw _ExitSignal(code);
  }

  bool get hasExited => _exited;
}

/// 以 `Uint8List` 形式读取一段内存（内置函数用）。
Uint8List readBytesAsList(CMemory memory, int address, int length) =>
    memory.readBytes(address, length);

// ---- 控制流信号 ----

class _BreakSignal implements Exception {}

class _ContinueSignal implements Exception {}

class _ReturnSignal implements Exception {
  _ReturnSignal(this.value);

  final CValue? value;
}

class _GotoSignal implements Exception {
  _GotoSignal(this.label);

  final String label;
}

/// `exit()` 用异常穿透整层调用栈。
class _ExitSignal implements Exception {
  _ExitSignal(this.code);

  final int code;
}
