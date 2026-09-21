/// C 预处理器。
///
/// 采用「文本进、文本出」的实现：先剥注释、拼续行，再逐行处理 `#` 指令与
/// 宏展开，最后把展开后的文本交给词法分析。对教学场景来说，这比基于记号的
/// 预处理器简单得多，也足够覆盖 `#include` / `#define` / 条件编译。
library;

import 'c_headers.dart';

/// 预处理输出中某一行的来源。
class CSourceLocation {
  const CSourceLocation(this.file, this.line);

  /// 项目内相对路径（`/` 分隔），虚拟头文件用 `<stdio.h>` 形式。
  final String file;

  /// 原始文件中的行号（1 基）。
  final int line;

  @override
  String toString() => '$file:$line';
}

/// 预处理结果。
class CPreprocessedSource {
  const CPreprocessedSource(this.text, this.origins);

  /// 展开后的完整文本。
  final String text;

  /// 逐行来源，下标即 [text] 的行号（0 基）。
  final List<CSourceLocation> origins;

  /// 把展开后的行号翻译成用户能看懂的位置。
  CSourceLocation originOf(int line) {
    if (line < 0 || line >= origins.length) {
      return const CSourceLocation('<未知>', 0);
    }
    return origins[line];
  }
}

/// 预处理阶段的错误。
class CPreprocessException implements Exception {
  CPreprocessException(this.message, this.file, this.line);

  final String message;
  final String file;
  final int line;

  @override
  String toString() => '$file:$line: $message';
}

/// 一个宏定义。
class CMacro {
  CMacro({
    required this.name,
    required this.params,
    required this.body,
    this.variadic = false,
  });

  final String name;

  /// null 表示对象式宏。
  final List<String>? params;

  final String body;
  final bool variadic;

  bool get isFunctionLike => params != null;
}

/// 预处理器的输入。
class CPreprocessInput {
  const CPreprocessInput({required this.entryPath, required this.files});

  /// 入口文件在 [files] 中的键。
  final String entryPath;

  /// 项目内所有可包含的文本文件，键为相对路径（`/` 分隔）。
  final Map<String, String> files;
}

/// 预处理 `input`，返回展开后的源码。
CPreprocessedSource preprocess(
  CPreprocessInput input, {
  int maxIncludeDepth = 32,
}) {
  final pp = _Preprocessor(input, maxIncludeDepth);
  return pp.run();
}

class _Preprocessor {
  _Preprocessor(this.input, this.maxIncludeDepth);

  final CPreprocessInput input;
  final int maxIncludeDepth;

  final Map<String, CMacro> _macros = {};
  final List<String> _output = [];
  final List<CSourceLocation> _origins = [];
  final Set<String> _pragmaOnce = {};
  final Set<String> _includedOnce = {};
  int _depth = 0;

  CPreprocessedSource run() {
    _defineBuiltinMacros();
    _processFile(input.entryPath, input.files[input.entryPath] ?? '');
    return CPreprocessedSource(_output.join('\n'), _origins);
  }

  void _defineBuiltinMacros() {
    void def(String name, String body) {
      _macros[name] = CMacro(name: name, params: null, body: body);
    }

    def('__STDC__', '1');
    def('__STDC_VERSION__', '201112L');
    def('__STDC_HOSTED__', '1');
    def('__QFLI_C__', '1');
    def('__aarch64__', '1');
    def('__LP64__', '1');
    def('__CHAR_BIT__', '8');
    def('__SIZEOF_INT__', '4');
    def('__SIZEOF_LONG__', '8');
    def('__SIZEOF_POINTER__', '8');
    def('__INT_MAX__', '2147483647');
    def('__LONG_MAX__', '9223372036854775807L');
  }

  // ---- 文件处理 ----

  void _processFile(String path, String rawSource) {
    if (_depth >= maxIncludeDepth) {
      throw CPreprocessException('头文件嵌套超过 $maxIncludeDepth 层，疑似循环包含', path, 1);
    }
    final key = _normalize(path);
    if (_pragmaOnce.contains(key)) {
      if (_includedOnce.contains(key)) return;
    }
    _includedOnce.add(key);
    _depth++;
    try {
      _processLines(path, rawSource);
    } finally {
      _depth--;
    }
  }

  void _processLines(String path, String rawSource) {
    final stripped = _stripComments(rawSource);
    final lines = _joinContinuations(stripped);

    // 条件编译状态栈：每一层记录「外层是否活跃」和「本层是否活跃」。
    final condStack = <_CondFrame>[];

    bool active() => condStack.every((f) => f.outerActive && f.takenHere);

    for (var i = 0; i < lines.length; i++) {
      final lineNo = i + 1;
      final line = lines[i];
      final trimmed = line.trimLeft();

      if (trimmed.startsWith('#')) {
        final directive = _parseDirective(trimmed);
        switch (directive.name) {
          case 'include':
            if (active()) _handleInclude(path, lineNo, directive.rest);
            continue;
          case 'define':
            if (active()) _handleDefine(lineNo, directive.rest);
            continue;
          case 'undef':
            if (active()) {
              final name = directive.rest.trim().split(RegExp(r'\s+')).first;
              _macros.remove(name);
            }
            continue;
          case 'ifdef':
          case 'ifndef':
            final outerActive = active();
            final name =
                directive.rest.trim().split(RegExp(r'\s+')).first;
            final defined = _macros.containsKey(name);
            final cond = directive.name == 'ifdef' ? defined : !defined;
            condStack.add(
              _CondFrame(
                outerActive: outerActive,
                takenHere: cond,
                anyTaken: cond,
              ),
            );
            continue;
          case 'if':
            final outerActive = active();
            final cond = outerActive && _evalCondition(path, lineNo, directive.rest);
            condStack.add(
              _CondFrame(
                outerActive: outerActive,
                takenHere: cond,
                anyTaken: cond,
              ),
            );
            continue;
          case 'elif':
            if (condStack.isEmpty) {
              throw CPreprocessException('#elif 没有对应的 #if', path, lineNo);
            }
            final frame = condStack.last;
            if (frame.anyTaken) {
              frame.takenHere = false;
            } else {
              final cond =
                  frame.outerActive && _evalCondition(path, lineNo, directive.rest);
              frame.takenHere = cond;
              frame.anyTaken = cond;
            }
            continue;
          case 'else':
            if (condStack.isEmpty) {
              throw CPreprocessException('#else 没有对应的 #if', path, lineNo);
            }
            final frame = condStack.last;
            frame.takenHere = !frame.anyTaken;
            frame.anyTaken = true;
            continue;
          case 'endif':
            if (condStack.isEmpty) {
              throw CPreprocessException('#endif 没有对应的 #if', path, lineNo);
            }
            condStack.removeLast();
            continue;
          case 'pragma':
            if (active()) {
              final rest = directive.rest.trim();
              if (rest == 'once') {
                _pragmaOnce.add(_normalize(path));
              }
            }
            continue;
          case 'error':
            if (active()) {
              throw CPreprocessException(
                '#error ${directive.rest.trim()}',
                path,
                lineNo,
              );
            }
            continue;
          case 'line':
          case 'warning':
          case 'pragma_message':
            continue;
          default:
            // 未知指令：按普通文本处理，方便兼容非标准扩展。
            break;
        }
      }

      if (!active()) continue;

      _emit(_expand(line, const {}, path, lineNo), path, lineNo);
    }

    if (condStack.isNotEmpty) {
      throw CPreprocessException('有 #if 没有闭合', path, lines.length);
    }
  }

  void _emit(String text, String file, int line) {
    // 展开可能产生换行（宏体里带 \n 的情况极少），逐行登记来源。
    final parts = text.split('\n');
    for (final part in parts) {
      _output.add(part);
      _origins.add(CSourceLocation(file, line));
    }
  }

  // ---- 指令解析 ----

  static _Directive _parseDirective(String line) {
    var rest = line.substring(1);
    var i = 0;
    while (i < rest.length && (rest[i] == ' ' || rest[i] == '\t')) {
      i++;
    }
    final start = i;
    while (i < rest.length && _isIdentPart(rest[i])) {
      i++;
    }
    final name = rest.substring(start, i);
    return _Directive(name, rest.substring(i));
  }

  void _handleInclude(String currentFile, int lineNo, String rest) {
    final trimmed = rest.trim();
    String? target;
    var angled = false;

    if (trimmed.startsWith('<')) {
      final end = trimmed.indexOf('>');
      if (end < 0) {
        throw CPreprocessException('#include 缺少 ">"', currentFile, lineNo);
      }
      target = trimmed.substring(1, end);
      angled = true;
    } else if (trimmed.startsWith('"')) {
      final end = trimmed.indexOf('"', 1);
      if (end < 0) {
        throw CPreprocessException('#include 缺少结尾引号', currentFile, lineNo);
      }
      target = trimmed.substring(1, end);
    } else {
      // 允许 #include MACRO 形式。
      final expanded = _expand(trimmed, const {}, currentFile, lineNo).trim();
      return _handleInclude(currentFile, lineNo, expanded);
    }

    final name = kHeaderAliases[target] ?? target;

    // 1) 内置虚拟头文件（带引号也允许，方便工程里直接写 #include "stdio.h"）
    final virtual = kVirtualHeaders[name];
    if (virtual != null) {
      _processFile('<$name>', virtual);
      return;
    }

    // 2) 项目内文件：带引号先按当前目录解析，再按工程根目录。
    final candidates = <String>[];
    if (!angled) {
      final dir = _dirOf(currentFile);
      candidates.add(dir.isEmpty ? name : '$dir/$name');
    }
    candidates.add(name);

    for (final candidate in candidates) {
      final key = _normalize(candidate);
      final source = input.files[key];
      if (source != null) {
        _processFile(key, source);
        return;
      }
    }

    throw CPreprocessException('找不到头文件 $target', currentFile, lineNo);
  }

  void _handleDefine(int lineNo, String rest) {
    final text = rest.trim();
    if (text.isEmpty) {
      throw CPreprocessException('#define 缺少宏名', input.entryPath, lineNo);
    }
    var i = 0;
    while (i < text.length && _isIdentPart(text[i])) {
      i++;
    }
    final name = text.substring(0, i);
    var body = text.substring(i);

    if (body.startsWith('(')) {
      // 函数式宏：参数列表紧跟宏名，中间不能有空格。
      final close = _matchParen(body, 0);
      if (close < 0) {
        throw CPreprocessException('#define 参数列表未闭合', input.entryPath, lineNo);
      }
      final paramsText = body.substring(1, close);
      final params = <String>[];
      var variadic = false;
      for (final raw in paramsText.split(',')) {
        final p = raw.trim();
        if (p.isEmpty) continue;
        if (p == '...') {
          variadic = true;
          params.add('__VA_ARGS__');
        } else if (p.endsWith('...')) {
          variadic = true;
          params.add(p.substring(0, p.length - 3).trim());
          params.add('__VA_ARGS__');
        } else {
          params.add(p);
        }
      }
      body = body.substring(close + 1).trim();
      _macros[name] = CMacro(
        name: name,
        params: params,
        body: body,
        variadic: variadic,
      );
      return;
    }

    _macros[name] = CMacro(name: name, params: null, body: body.trim());
  }

  // ---- 宏展开 ----

  String _expand(String text, Set<String> activeNames, String file, int line) {
    if (!text.contains(RegExp(r'[A-Za-z_$]'))) return text;
    final out = StringBuffer();
    var i = 0;
    while (i < text.length) {
      final c = text[i];

      // 字符串/字符字面量原样复制，绝不展开。
      if (c == '"' || c == "'") {
        final end = _skipLiteral(text, i);
        out.write(text.substring(i, end));
        i = end;
        continue;
      }

      if (_isIdentStart(c)) {
        final start = i;
        while (i < text.length && _isIdentPart(text[i])) {
          i++;
        }
        final name = text.substring(start, i);

        if (name == '__FILE__') {
          out.write('"${_escapeString(file)}"');
          continue;
        }
        if (name == '__LINE__') {
          out.write('$line');
          continue;
        }

        final macro = _macros[name];
        if (macro == null || activeNames.contains(name)) {
          out.write(name);
          continue;
        }

        if (!macro.isFunctionLike) {
          out.write(_expand(macro.body, {...activeNames, name}, file, line));
          continue;
        }

        // 函数式宏必须紧跟 '('（允许中间空白）。
        var j = i;
        while (j < text.length && (text[j] == ' ' || text[j] == '\t')) {
          j++;
        }
        if (j >= text.length || text[j] != '(') {
          out.write(name);
          continue;
        }
        final parsed = _parseMacroArgs(text, j);
        if (parsed == null) {
          out.write(name);
          continue;
        }
        i = parsed.end;
        final expandedArgs = parsed.args
            .map((a) => _expand(a, {...activeNames, name}, file, line))
            .toList();
        final substituted = _substitute(
          macro,
          parsed.args,
          expandedArgs,
          file,
          line,
        );
        out.write(_expand(substituted, {...activeNames, name}, file, line));
        continue;
      }

      out.write(c);
      i++;
    }
    return out.toString();
  }

  String _substitute(
    CMacro macro,
    List<String> rawArgs,
    List<String> expandedArgs,
    String file,
    int line,
  ) {
    final params = macro.params ?? const <String>[];
    final mapping = <String, String>{};
    final rawMapping = <String, String>{};
    for (var k = 0; k < params.length; k++) {
      final isVariadic = params[k] == '__VA_ARGS__';
      if (isVariadic) {
        // 变参部分把所有剩余实参用逗号拼回。
        final rest = k < rawArgs.length
            ? rawArgs.sublist(k).join(', ')
            : '';
        mapping[params[k]] = rest;
        rawMapping[params[k]] = rest;
      } else {
        mapping[params[k]] = k < expandedArgs.length ? expandedArgs[k] : '';
        rawMapping[params[k]] = k < rawArgs.length ? rawArgs[k] : '';
      }
    }

    final body = macro.body;
    final out = StringBuffer();
    var i = 0;
    while (i < body.length) {
      final c = body[i];
      if (c == '"' || c == "'") {
        final end = _skipLiteral(body, i);
        out.write(body.substring(i, end));
        i = end;
        continue;
      }
      // #param -> 字符串化（用未展开的实参）
      if (c == '#' && i + 1 < body.length && _isIdentStart(body[i + 1])) {
        var j = i + 1;
        while (j < body.length && _isIdentPart(body[j])) {
          j++;
        }
        final param = body.substring(i + 1, j);
        if (rawMapping.containsKey(param)) {
          out.write('"${_escapeString(rawMapping[param]!.trim())}"');
          i = j;
          continue;
        }
      }
      // a ## b -> 记号拼接
      if (c == '#' && i + 1 < body.length && body[i + 1] == '#') {
        i += 2;
        continue;
      }
      if (_isIdentStart(c)) {
        final start = i;
        while (i < body.length && _isIdentPart(body[i])) {
          i++;
        }
        final word = body.substring(start, i);
        out.write(mapping[word] ?? word);
        continue;
      }
      out.write(c);
      i++;
    }
    return out.toString();
  }

  /// 从 `(` 开始解析宏调用的实参，返回实参与结束位置。
  static _MacroArgs? _parseMacroArgs(String text, int openIndex) {
    var depth = 0;
    var i = openIndex;
    final args = <String>[];
    final current = StringBuffer();
    var sawAny = false;

    while (i < text.length) {
      final c = text[i];
      if (c == '"' || c == "'") {
        final end = _skipLiteral(text, i);
        current.write(text.substring(i, end));
        i = end;
        sawAny = true;
        continue;
      }
      if (c == '(') {
        depth++;
        if (depth > 1) current.write(c);
        i++;
        continue;
      }
      if (c == ')') {
        depth--;
        if (depth == 0) {
          if (sawAny || current.toString().trim().isNotEmpty) {
            args.add(current.toString());
          }
          return _MacroArgs(args, i + 1);
        }
        current.write(c);
        i++;
        continue;
      }
      if (c == ',' && depth == 1) {
        args.add(current.toString());
        current.clear();
        sawAny = true;
        i++;
        continue;
      }
      current.write(c);
      i++;
    }
    return null; // 未闭合
  }

  // ---- 条件表达式 ----

  bool _evalCondition(String file, int line, String expr) {
    // 先处理 defined(...) / defined X，再展开宏。
    var text = _replaceDefined(expr);
    text = _expand(text, const {}, file, line);
    final value = _CondEvaluator(text).parse();
    return value != 0;
  }

  String _replaceDefined(String expr) {
    final out = StringBuffer();
    var i = 0;
    while (i < expr.length) {
      final c = expr[i];
      if (c == '"' || c == "'") {
        final end = _skipLiteral(expr, i);
        out.write(expr.substring(i, end));
        i = end;
        continue;
      }
      if (expr.startsWith('defined', i) &&
          (i == 0 || !_isIdentPart(expr[i - 1]))) {
        var j = i + 'defined'.length;
        while (j < expr.length && (expr[j] == ' ' || expr[j] == '\t')) {
          j++;
        }
        var paren = false;
        if (j < expr.length && expr[j] == '(') {
          paren = true;
          j++;
          while (j < expr.length && (expr[j] == ' ' || expr[j] == '\t')) {
            j++;
          }
        }
        final start = j;
        while (j < expr.length && _isIdentPart(expr[j])) {
          j++;
        }
        final name = expr.substring(start, j);
        if (paren) {
          while (j < expr.length && (expr[j] == ' ' || expr[j] == '\t')) {
            j++;
          }
          if (j < expr.length && expr[j] == ')') j++;
        }
        out.write(_macros.containsKey(name) ? '1' : '0');
        i = j;
        continue;
      }
      out.write(c);
      i++;
    }
    return out.toString();
  }

  // ---- 文本工具 ----

  /// 剥掉注释，保留字符串与字符字面量里的内容。
  static String _stripComments(String source) {
    final out = StringBuffer();
    var i = 0;
    while (i < source.length) {
      final c = source[i];
      if (c == '"' || c == "'") {
        final end = _skipLiteral(source, i);
        out.write(source.substring(i, end));
        i = end;
        continue;
      }
      if (c == '/' && i + 1 < source.length && source[i + 1] == '/') {
        while (i < source.length && source[i] != '\n') {
          i++;
        }
        continue;
      }
      if (c == '/' && i + 1 < source.length && source[i + 1] == '*') {
        i += 2;
        while (i + 1 < source.length &&
            !(source[i] == '*' && source[i + 1] == '/')) {
          // 注释里的换行要保留，否则行号会错位。
          if (source[i] == '\n') out.write('\n');
          i++;
        }
        i = (i + 2).clamp(0, source.length);
        continue;
      }
      out.write(c);
      i++;
    }
    return out.toString();
  }

  /// 拼接以 `\` 结尾的续行。
  static List<String> _joinContinuations(String source) {
    final rawLines = source.split('\n');
    final result = <String>[];
    final buffer = StringBuffer();
    for (final line in rawLines) {
      if (line.endsWith('\\')) {
        buffer.write(line.substring(0, line.length - 1));
        continue;
      }
      buffer.write(line);
      result.add(buffer.toString());
      buffer.clear();
    }
    if (buffer.isNotEmpty) result.add(buffer.toString());
    return result;
  }

  /// 跳过一个字符串/字符字面量，返回结束位置（含结尾引号之后）。
  static int _skipLiteral(String text, int start) {
    final quote = text[start];
    var i = start + 1;
    while (i < text.length) {
      if (text[i] == '\\') {
        i += 2;
        continue;
      }
      if (text[i] == quote) return i + 1;
      i++;
    }
    return text.length;
  }

  static int _matchParen(String text, int openIndex) {
    var depth = 0;
    var i = openIndex;
    while (i < text.length) {
      final c = text[i];
      if (c == '"' || c == "'") {
        i = _skipLiteral(text, i);
        continue;
      }
      if (c == '(') depth++;
      if (c == ')') {
        depth--;
        if (depth == 0) return i;
      }
      i++;
    }
    return -1;
  }

  static String _escapeString(String value) {
    final out = StringBuffer();
    for (final unit in value.codeUnits) {
      if (unit == 0x5C) {
        out.write(r'\\');
      } else if (unit == 0x22) {
        out.write(r'\"');
      } else if (unit == 0x0A) {
        out.write(r'\n');
      } else {
        out.writeCharCode(unit);
      }
    }
    return out.toString();
  }

  static String _normalize(String path) {
    final parts = <String>[];
    for (final segment in path.replaceAll('\\', '/').split('/')) {
      if (segment.isEmpty || segment == '.') continue;
      if (segment == '..') {
        if (parts.isNotEmpty) parts.removeLast();
        continue;
      }
      parts.add(segment);
    }
    return parts.join('/');
  }

  static String _dirOf(String path) {
    final normalized = _normalize(path);
    final index = normalized.lastIndexOf('/');
    return index < 0 ? '' : normalized.substring(0, index);
  }

  static bool _isIdentStart(String c) =>
      c.isNotEmpty && RegExp(r'[A-Za-z_$]').hasMatch(c);

  static bool _isIdentPart(String c) =>
      c.isNotEmpty && RegExp(r'[A-Za-z0-9_$]').hasMatch(c);
}

class _Directive {
  const _Directive(this.name, this.rest);

  final String name;
  final String rest;
}

class _MacroArgs {
  const _MacroArgs(this.args, this.end);

  final List<String> args;
  final int end;
}

class _CondFrame {
  _CondFrame({
    required this.outerActive,
    required this.takenHere,
    required this.anyTaken,
  });

  final bool outerActive;
  bool takenHere;
  bool anyTaken;
}

/// `#if` 表达式求值：整数算术 + 比较 + 逻辑运算，未定义标识符按 0。
class _CondEvaluator {
  _CondEvaluator(this.text);

  final String text;
  int _pos = 0;

  int parse() {
    final value = _conditional();
    return value;
  }

  int _conditional() {
    final cond = _logicalOr();
    _skipSpace();
    if (_peek() == '?') {
      _pos++;
      final a = _conditional();
      _skipSpace();
      if (_peek() == ':') _pos++;
      final b = _conditional();
      return cond != 0 ? a : b;
    }
    return cond;
  }

  int _logicalOr() {
    var left = _logicalAnd();
    while (true) {
      _skipSpace();
      if (_peek() == '|' && _peekAt(1) == '|') {
        _pos += 2;
        final right = _logicalAnd();
        left = (left != 0 || right != 0) ? 1 : 0;
        continue;
      }
      return left;
    }
  }

  int _logicalAnd() {
    var left = _bitOr();
    while (true) {
      _skipSpace();
      if (_peek() == '&' && _peekAt(1) == '&') {
        _pos += 2;
        final right = _bitOr();
        left = (left != 0 && right != 0) ? 1 : 0;
        continue;
      }
      return left;
    }
  }

  int _bitOr() {
    var left = _bitXor();
    while (true) {
      _skipSpace();
      if (_peek() == '|' && _peekAt(1) != '|') {
        _pos++;
        left |= _bitXor();
        continue;
      }
      return left;
    }
  }

  int _bitXor() {
    var left = _bitAnd();
    while (true) {
      _skipSpace();
      if (_peek() == '^') {
        _pos++;
        left ^= _bitAnd();
        continue;
      }
      return left;
    }
  }

  int _bitAnd() {
    var left = _equality();
    while (true) {
      _skipSpace();
      if (_peek() == '&' && _peekAt(1) != '&') {
        _pos++;
        left &= _equality();
        continue;
      }
      return left;
    }
  }

  int _equality() {
    var left = _relational();
    while (true) {
      _skipSpace();
      if (_peek() == '=' && _peekAt(1) == '=') {
        _pos += 2;
        left = left == _relational() ? 1 : 0;
        continue;
      }
      if (_peek() == '!' && _peekAt(1) == '=') {
        _pos += 2;
        left = left != _relational() ? 1 : 0;
        continue;
      }
      return left;
    }
  }

  int _relational() {
    var left = _shift();
    while (true) {
      _skipSpace();
      final c = _peek();
      final n = _peekAt(1);
      if (c == '<' && n == '=') {
        _pos += 2;
        left = left <= _shift() ? 1 : 0;
        continue;
      }
      if (c == '>' && n == '=') {
        _pos += 2;
        left = left >= _shift() ? 1 : 0;
        continue;
      }
      if (c == '<' && n != '<') {
        _pos++;
        left = left < _shift() ? 1 : 0;
        continue;
      }
      if (c == '>' && n != '>') {
        _pos++;
        left = left > _shift() ? 1 : 0;
        continue;
      }
      return left;
    }
  }

  int _shift() {
    var left = _additive();
    while (true) {
      _skipSpace();
      final c = _peek();
      final n = _peekAt(1);
      if (c == '<' && n == '<') {
        _pos += 2;
        left <<= _additive();
        continue;
      }
      if (c == '>' && n == '>') {
        _pos += 2;
        left >>= _additive();
        continue;
      }
      return left;
    }
  }

  int _additive() {
    var left = _multiplicative();
    while (true) {
      _skipSpace();
      final c = _peek();
      if (c == '+') {
        _pos++;
        left += _multiplicative();
        continue;
      }
      if (c == '-') {
        _pos++;
        left -= _multiplicative();
        continue;
      }
      return left;
    }
  }

  int _multiplicative() {
    var left = _unary();
    while (true) {
      _skipSpace();
      final c = _peek();
      if (c == '*') {
        _pos++;
        left *= _unary();
        continue;
      }
      if (c == '/') {
        _pos++;
        final r = _unary();
        left = r == 0 ? 0 : left ~/ r;
        continue;
      }
      if (c == '%') {
        _pos++;
        final r = _unary();
        left = r == 0 ? 0 : left % r;
        continue;
      }
      return left;
    }
  }

  int _unary() {
    _skipSpace();
    final c = _peek();
    if (c == '-') {
      _pos++;
      return -_unary();
    }
    if (c == '+') {
      _pos++;
      return _unary();
    }
    if (c == '!') {
      _pos++;
      return _unary() == 0 ? 1 : 0;
    }
    if (c == '~') {
      _pos++;
      return ~_unary();
    }
    if (c == '(') {
      _pos++;
      final v = _conditional();
      _skipSpace();
      if (_peek() == ')') _pos++;
      return v;
    }
    return _primary();
  }

  int _primary() {
    _skipSpace();
    final c = _peek();
    if (c == "'") {
      // 字符字面量
      final start = _pos;
      _pos++;
      var value = 0;
      if (_peek() == '\\') {
        _pos++;
        final esc = _peek();
        _pos++;
        value = switch (esc) {
          'n' => 10,
          't' => 9,
          'r' => 13,
          '0' => 0,
          '\\' => 92,
          _ => esc.isEmpty ? 0 : esc.codeUnitAt(0),
        };
      } else {
        value = _peek().isEmpty ? 0 : _peek().codeUnitAt(0);
        _pos++;
      }
      if (_peek() == "'") _pos++;
      if (_pos == start) _pos++;
      return value;
    }
    if (_isDigit(c)) {
      final start = _pos;
      if (c == '0' && (_peekAt(1) == 'x' || _peekAt(1) == 'X')) {
        _pos += 2;
        while (_isHex(_peek())) {
          _pos++;
        }
        final raw = text
            .substring(start + 2, _pos)
            .replaceAll(RegExp(r'[uUlL]+$'), '');
        _skipSuffix();
        return int.tryParse(raw, radix: 16) ?? 0;
      }
      while (_isDigit(_peek()) || _isHex(_peek())) {
        _pos++;
      }
      var raw = text.substring(start, _pos);
      _skipSuffix();
      var radix = 10;
      if (raw.length > 1 && raw.startsWith('0')) {
        radix = 8;
        raw = raw.substring(1);
      }
      return int.tryParse(raw, radix: radix) ?? 0;
    }
    if (_isIdentStart(c)) {
      // 未展开的标识符在 #if 里按 0 处理。
      while (_isIdentPart(_peek())) {
        _pos++;
      }
      return 0;
    }
    // 无法识别时跳过，避免死循环。
    if (_pos < text.length) _pos++;
    return 0;
  }

  void _skipSuffix() {
    while (RegExp(r'[uUlL]').hasMatch(_peek()) && _peek().isNotEmpty) {
      _pos++;
    }
  }

  void _skipSpace() {
    while (_pos < text.length &&
        (text[_pos] == ' ' || text[_pos] == '\t' || text[_pos] == '\r')) {
      _pos++;
    }
  }

  String _peek() => _pos < text.length ? text[_pos] : '';

  String _peekAt(int offset) {
    final i = _pos + offset;
    return i < text.length ? text[i] : '';
  }

  static bool _isDigit(String c) =>
      c.isNotEmpty && c.codeUnitAt(0) >= 0x30 && c.codeUnitAt(0) <= 0x39;

  static bool _isHex(String c) =>
      c.isNotEmpty && RegExp(r'[0-9a-fA-F]').hasMatch(c);

  static bool _isIdentStart(String c) =>
      c.isNotEmpty && RegExp(r'[A-Za-z_$]').hasMatch(c);

  static bool _isIdentPart(String c) =>
      c.isNotEmpty && RegExp(r'[A-Za-z0-9_$]').hasMatch(c);
}
