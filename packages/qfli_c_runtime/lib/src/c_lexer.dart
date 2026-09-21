/// C 词法分析。
///
/// 输入是预处理之后的文本（`#include` 已展开、宏已替换），输出带行号的
/// 记号流。行号是预处理输出的行号，由 `CSourceMap` 反查回原始文件位置。
library;

import 'c_types.dart';

enum CTokenKind {
  eof,
  identifier,
  intLiteral,
  floatLiteral,
  charLiteral,
  stringLiteral,
  punctuator,
}

/// 一个记号。
class CToken {
  CToken({
    required this.kind,
    required this.text,
    required this.line,
    required this.column,
    this.intValue,
    this.doubleValue,
    this.stringValue,
  });

  final CTokenKind kind;

  /// 原始文本（标识符、关键字、标点）。
  final String text;

  /// 预处理输出的行号（0 基）。
  final int line;

  /// 列号（0 基），用于错误提示。
  final int column;

  /// 整数字面量取值。
  final int? intValue;

  /// 浮点字面量取值。
  final double? doubleValue;

  /// 字符串/字符字面量解码后的值。
  final String? stringValue;

  bool get isEof => kind == CTokenKind.eof;

  /// 是否为指定文本的标点或关键字。
  bool isText(String value) => text == value;

  bool get isIdentifier => kind == CTokenKind.identifier;

  bool get isString => kind == CTokenKind.stringLiteral;

  bool get isNumber =>
      kind == CTokenKind.intLiteral || kind == CTokenKind.floatLiteral;

  @override
  String toString() => '${kind.name}(${text.replaceAll('\n', r'\n')})';
}

/// 词法错误。
class CLexException implements Exception {
  CLexException(this.message, this.line, this.column);

  final String message;
  final int line;
  final int column;

  @override
  String toString() => '词法错误：$message';
}

/// 把预处理后的源码切成记号。
class CLexer {
  CLexer(this.source);

  final String source;

  final List<CToken> _tokens = [];
  int _pos = 0;
  int _line = 0;
  int _lineStart = 0;

  /// 多字符标点，按长度从长到短匹配。
  static const List<String> _punctuators = [
    '<<=',
    '>>=',
    '...',
    '->',
    '++',
    '--',
    '<<',
    '>>',
    '<=',
    '>=',
    '==',
    '!=',
    '&&',
    '||',
    '+=',
    '-=',
    '*=',
    '/=',
    '%=',
    '&=',
    '|=',
    '^=',
    '+',
    '-',
    '*',
    '/',
    '%',
    '=',
    '<',
    '>',
    '!',
    '~',
    '&',
    '|',
    '^',
    '?',
    ':',
    ';',
    ',',
    '.',
    '(',
    ')',
    '[',
    ']',
    '{',
    '}',
    '#',
  ];

  List<CToken> tokenize() {
    while (_pos < source.length) {
      final c = source[_pos];
      if (c == '\n') {
        _pos++;
        _line++;
        _lineStart = _pos;
        continue;
      }
      if (c == ' ' || c == '\t' || c == '\r') {
        _pos++;
        continue;
      }
      // 注释在预处理阶段已剥离，这里兜底。
      if (c == '/' && _peek(1) == '/') {
        while (_pos < source.length && source[_pos] != '\n') {
          _pos++;
        }
        continue;
      }
      if (c == '/' && _peek(1) == '*') {
        _pos += 2;
        while (_pos < source.length &&
            !(source[_pos] == '*' && _peek(1) == '/')) {
          if (source[_pos] == '\n') {
            _line++;
            _lineStart = _pos + 1;
          }
          _pos++;
        }
        _pos = (_pos + 2).clamp(0, source.length);
        continue;
      }
      if (_isIdentStart(c)) {
        _readIdentifier();
        continue;
      }
      if (_isDigit(c) || (c == '.' && _isDigit(_peek(1)))) {
        _readNumber();
        continue;
      }
      if (c == '"') {
        _readString();
        continue;
      }
      if (c == "'") {
        _readChar();
        continue;
      }
      _readPunctuator();
    }
    _tokens.add(
      CToken(
        kind: CTokenKind.eof,
        text: '',
        line: _line,
        column: _pos - _lineStart,
      ),
    );
    return _tokens;
  }

  String _peek(int offset) {
    final i = _pos + offset;
    return i < source.length ? source[i] : '';
  }

  static bool _isIdentStart(String c) =>
      c.isNotEmpty && (RegExp(r'[A-Za-z_$]').hasMatch(c));

  static bool _isIdentPart(String c) =>
      c.isNotEmpty && (RegExp(r'[A-Za-z0-9_$]').hasMatch(c));

  static bool _isDigit(String c) => c.isNotEmpty && c.codeUnitAt(0) >= 0x30 && c.codeUnitAt(0) <= 0x39;

  static bool _isHexDigit(String c) =>
      c.isNotEmpty && RegExp(r'[0-9a-fA-F]').hasMatch(c);

  void _readIdentifier() {
    final start = _pos;
    while (_pos < source.length && _isIdentPart(source[_pos])) {
      _pos++;
    }
    _tokens.add(
      CToken(
        kind: CTokenKind.identifier,
        text: source.substring(start, _pos),
        line: _line,
        column: start - _lineStart,
      ),
    );
  }

  void _readNumber() {
    final start = _pos;
    var isFloat = false;

    if (source[_pos] == '0' && (_peek(1) == 'x' || _peek(1) == 'X')) {
      _pos += 2;
      while (_pos < source.length && _isHexDigit(source[_pos])) {
        _pos++;
      }
    } else if (source[_pos] == '0' && (_peek(1) == 'b' || _peek(1) == 'B')) {
      _pos += 2;
      while (_pos < source.length && (source[_pos] == '0' || source[_pos] == '1')) {
        _pos++;
      }
    } else {
      while (_pos < source.length && _isDigit(source[_pos])) {
        _pos++;
      }
      if (_pos < source.length && source[_pos] == '.') {
        isFloat = true;
        _pos++;
        while (_pos < source.length && _isDigit(source[_pos])) {
          _pos++;
        }
      }
      if (_pos < source.length &&
          (source[_pos] == 'e' || source[_pos] == 'E')) {
        final save = _pos;
        _pos++;
        if (_pos < source.length &&
            (source[_pos] == '+' || source[_pos] == '-')) {
          _pos++;
        }
        if (_pos < source.length && _isDigit(source[_pos])) {
          isFloat = true;
          while (_pos < source.length && _isDigit(source[_pos])) {
            _pos++;
          }
        } else {
          _pos = save;
        }
      }
    }

    // 后缀：u/U/l/L/ll/LL/f/F
    while (_pos < source.length &&
        RegExp(r'[uUlLfF]').hasMatch(source[_pos])) {
      final ch = source[_pos];
      if (ch == 'f' || ch == 'F') isFloat = true;
      _pos++;
    }

    final raw = source.substring(start, _pos);
    final column = start - _lineStart;
    if (isFloat) {
      _tokens.add(
        CToken(
          kind: CTokenKind.floatLiteral,
          text: raw,
          line: _line,
          column: column,
          doubleValue: _parseDouble(raw),
        ),
      );
      return;
    }
    _tokens.add(
      CToken(
        kind: CTokenKind.intLiteral,
        text: raw,
        line: _line,
        column: column,
        intValue: _parseInt(raw),
      ),
    );
  }

  static double _parseDouble(String raw) {
    var s = raw.replaceAll(RegExp(r'[fFlL]$'), '');
    return double.tryParse(s) ?? 0.0;
  }

  static int _parseInt(String raw) {
    var s = raw.replaceAll(RegExp(r'[uUlL]+$'), '');
    var radix = 10;
    if (s.startsWith('0x') || s.startsWith('0X')) {
      radix = 16;
      s = s.substring(2);
    } else if (s.startsWith('0b') || s.startsWith('0B')) {
      radix = 2;
      s = s.substring(2);
    } else if (s.length > 1 && s.startsWith('0')) {
      radix = 8;
      s = s.substring(1);
    }
    if (s.isEmpty) return 0;
    final v = int.tryParse(s, radix: radix);
    if (v != null) return v;
    // 超出有符号 64 位（如 ULONG_MAX）时按补码折回 Dart 的 64 位 int。
    final big = BigInt.tryParse(s, radix: radix);
    if (big == null) return 0;
    const mask = 0xFFFFFFFFFFFFFFFF;
    final masked = big & BigInt.parse('$mask', radix: 16);
    final signBit = BigInt.one << 63;
    final modulus = BigInt.one << 64;
    return (masked >= signBit ? masked - modulus : masked).toInt();
  }

  void _readString() {
    final start = _pos;
    _pos++; // 开引号
    final buffer = StringBuffer();
    while (_pos < source.length && source[_pos] != '"') {
      if (source[_pos] == '\\') {
        _pos++;
        buffer.write(_readEscape());
      } else {
        if (source[_pos] == '\n') {
          _line++;
          _lineStart = _pos + 1;
        }
        buffer.write(source[_pos]);
        _pos++;
      }
    }
    if (_pos >= source.length) {
      throw CLexException('字符串字面量缺少结尾引号', _line, start - _lineStart);
    }
    _pos++; // 闭引号
    _tokens.add(
      CToken(
        kind: CTokenKind.stringLiteral,
        text: source.substring(start, _pos),
        line: _line,
        column: start - _lineStart,
        stringValue: buffer.toString(),
      ),
    );
  }

  void _readChar() {
    final start = _pos;
    _pos++; // 开引号
    var value = 0;
    if (_pos < source.length && source[_pos] == '\\') {
      _pos++;
      final esc = _readEscape();
      value = esc.isEmpty ? 0 : esc.codeUnitAt(0);
    } else if (_pos < source.length) {
      value = source[_pos].codeUnitAt(0);
      _pos++;
    }
    if (_pos >= source.length || source[_pos] != "'") {
      throw CLexException('字符字面量缺少结尾引号', _line, start - _lineStart);
    }
    _pos++;
    _tokens.add(
      CToken(
        kind: CTokenKind.charLiteral,
        text: source.substring(start, _pos),
        line: _line,
        column: start - _lineStart,
        intValue: value,
      ),
    );
  }

  /// 读取一个转义序列，返回其字符（多字节转义只取首字符）。
  String _readEscape() {
    if (_pos >= source.length) return '';
    final c = source[_pos++];
    switch (c) {
      case 'n':
        return '\n';
      case 't':
        return '\t';
      case 'r':
        return '\r';
      case '0':
        return '\x00';
      case 'a':
        return '\x07';
      case 'b':
        return '\x08';
      case 'f':
        return '\x0C';
      case 'v':
        return '\x0B';
      case '\\':
        return '\\';
      case "'":
        return "'";
      case '"':
        return '"';
      case '?':
        return '?';
      case 'x':
        final hex = StringBuffer();
        while (_pos < source.length && _isHexDigit(source[_pos])) {
          hex.write(source[_pos++]);
        }
        final v = int.tryParse(hex.toString(), radix: 16) ?? 0;
        return String.fromCharCode(v);
      default:
        if (_isDigit(c)) {
          // 八进制转义，最多 3 位。
          final oct = StringBuffer(c);
          while (oct.length < 3 &&
              _pos < source.length &&
              RegExp(r'[0-7]').hasMatch(source[_pos])) {
            oct.write(source[_pos++]);
          }
          return String.fromCharCode(int.parse(oct.toString(), radix: 8));
        }
        return c;
    }
  }

  void _readPunctuator() {
    for (final p in _punctuators) {
      if (source.startsWith(p, _pos)) {
        _tokens.add(
          CToken(
            kind: CTokenKind.punctuator,
            text: p,
            line: _line,
            column: _pos - _lineStart,
          ),
        );
        _pos += p.length;
        return;
      }
    }
    throw CLexException(
      '无法识别的字符 "${source[_pos]}"',
      _line,
      _pos - _lineStart,
    );
  }
}

/// 整数类型转换辅助：把 Dart 的任意精度整数截断到目标类型宽度。
int cTruncate(int value, CIntegerType type) {
  if (type.bits >= 64) return value;
  final mask = (1 << type.bits) - 1;
  var v = value & mask;
  if (type.isSigned && (v & (1 << (type.bits - 1))) != 0) {
    v -= 1 << type.bits;
  }
  return v;
}
