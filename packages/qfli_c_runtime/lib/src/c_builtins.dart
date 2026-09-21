/// C 标准库的内置实现。
///
/// 手机上没有 libc 可以链接，所以 `printf`、`malloc`、`sqrt` 这些全部用
/// Dart 直接实现。头文件里的原型负责给出正确的类型，这里的实现负责行为。
library;

import 'dart:math' as math;

import 'c_interpreter.dart';
import 'c_memory.dart';
import 'c_types.dart';
import 'c_value.dart';

/// 把内置函数全部注册到解释器。
void registerBuiltins(CInterpreter interpreter) {
  for (final entry in _builtins.entries) {
    interpreter.registerFunction(
      CFunction(
        name: entry.key,
        type: entry.value.signature,
        builtin: entry.value.body,
      ),
    );
  }
}

typedef _Builtin = CValue Function(CInterpreter, List<CValue>);

class _Entry {
  const _Entry(this.signature, this.body);

  final CFunctionType signature;
  final _Builtin body;
}

// ---- 便捷取值 ----

int _argInt(List<CValue> args, int index) {
  if (index >= args.length) return 0;
  final value = args[index];
  if (value.isImmediate) {
    final immediate = value.immediate!;
    return immediate is double ? immediate.truncate() : immediate as int;
  }
  final type = value.type;
  if (type is CFloatType) {
    final d = type.size == 4
        ? _doubleOf(value)
        : _doubleOf(value);
    return d.truncate();
  }
  return _intOf(value);
}

double _argDouble(List<CValue> args, int index) {
  if (index >= args.length) return 0;
  final value = args[index];
  if (value.isImmediate) {
    final immediate = value.immediate!;
    return immediate is double ? immediate : (immediate as int).toDouble();
  }
  if (value.type is CFloatType) return _doubleOf(value);
  return _intOf(value).toDouble();
}

int _argPointer(List<CValue> args, int index) {
  if (index >= args.length) return 0;
  final value = args[index];
  if (value.isImmediate) return value.immediate as int;
  if (value.type is CPointerType) return _pointerOf(value);
  return value.address;
}

String _argCString(CInterpreter ctx, List<CValue> args, int index) =>
    ctx.readCString(_argPointer(args, index));

/// 从内存里按值类型取整数（内置函数拿到的参数可能还没转成纯值）。
int _intOf(CValue value) {
  final memory = _memoryOf(value);
  final type = value.type;
  if (type is CIntegerType) {
    return memory.readInt(value.address, type.size, signed: type.isSigned);
  }
  if (type is CPointerType) return memory.readInt(value.address, 8);
  if (type is CEnumType) return memory.readInt(value.address, 4, signed: true);
  return memory.readInt(value.address, 4, signed: true);
}

double _doubleOf(CValue value) {
  final memory = _memoryOf(value);
  final type = value.type;
  if (type is CFloatType) {
    return type.size == 4
        ? memory.readFloat(value.address)
        : memory.readDouble(value.address);
  }
  return _intOf(value).toDouble();
}

int _pointerOf(CValue value) {
  if (value.isImmediate) return value.immediate as int;
  if (value.type is CPointerType) {
    return _memoryOf(value).readInt(value.address, 8);
  }
  return value.address;
}

/// 内置函数拿到的参数是 [CValue]，需要借解释器的内存来读。
CMemory _memoryOf(CValue value) => _activeMemory!;

/// 当前正在执行的内置函数所对应的内存。内置调用是同步的，用栈式保存即可。
CMemory? _activeMemory;

CValue _int(int value) => CValue(CTypes.intType, 0, immediate: value);

CValue _long(int value) => CValue(CTypes.longType, 0, immediate: value);

CValue _double(double value) =>
    CValue(CTypes.doubleType, 0, immediate: value);

CValue _pointer(int address, [CType? type]) =>
    CValue(type ?? CTypes.voidPointer, 0, immediate: address);

CValue _sizeValue(int value) => CValue(CTypes.unsignedLong, 0, immediate: value);

CFunctionType _sig(
  CType returnType,
  List<CType> parameters, {
  bool variadic = false,
}) => CFunctionType(
  returnType: returnType,
  parameters: parameters,
  variadic: variadic,
  prototype: true,
);

/// 包一层：内置函数执行期间把内存挂到 [_activeMemory]。
_Builtin _wrap(_Builtin body) {
  return (ctx, args) {
    final previous = _activeMemory;
    _activeMemory = ctx.mem;
    try {
      return body(ctx, args);
    } finally {
      _activeMemory = previous;
    }
  };
}

// ---- printf 格式化 ----

class _FormatResult {
  const _FormatResult(this.text, this.consumed);

  final String text;
  final int consumed;
}

String _digits(String format, int start) {
  var i = start;
  while (i < format.length &&
      format.codeUnitAt(i) >= 0x30 &&
      format.codeUnitAt(i) <= 0x39) {
    i++;
  }
  return format.substring(start, i);
}

String _pad(String text, int? width, bool leftAlign, bool zeroFill) {
  if (width == null || text.length >= width) return text;
  final fill = width - text.length;
  if (leftAlign) return text + ' ' * fill;
  if (!zeroFill) return ' ' * fill + text;

  // 补零要插在符号/前缀之后。
  final signLength = (text.startsWith('-') ||
          text.startsWith('+') ||
          text.startsWith(' '))
      ? 1
      : (text.startsWith('0x') || text.startsWith('0X') || text.startsWith('0b'))
      ? 2
      : 0;
  return text.substring(0, signLength) +
      '0' * fill +
      text.substring(signLength);
}

String _formatUnsigned(int value, int radix, bool upper, bool hash) {
  final unsigned = value < 0
      ? (BigInt.from(value) + (BigInt.one << 64))
      : BigInt.from(value);
  var text = unsigned.toRadixString(radix);
  if (upper) text = text.toUpperCase();
  if (hash) {
    if (radix == 16) text = '${upper ? '0X' : '0x'}$text';
    if (radix == 8) text = '0$text';
    if (radix == 2) text = '0b$text';
  }
  return text;
}

String _formatDouble(double value, int? precision, String spec) {
  final p = precision ?? 6;
  switch (spec) {
    case 'f':
    case 'F':
      return value.toStringAsFixed(p);
    case 'e':
    case 'E':
      final text = _normalizeExponent(value.toStringAsExponential(p));
      return spec == 'E' ? text.toUpperCase() : text;
    default:
      // %g：按指数决定用定点还是科学计数。
      if (value == 0) return precision == null ? '0' : '0';
      final exponent = (math.log(value.abs()) / math.ln10).floor();
      if (exponent < -4 || exponent >= (precision ?? 6)) {
        final digits = (precision ?? 6) - 1;
        return _trimTrailingZeros(
          _normalizeExponent(
            value.toStringAsExponential(digits < 0 ? 0 : digits),
          ),
        );
      }
      final decimals = (precision ?? 6) - 1 - exponent;
      return _trimTrailingZeros(
        value.toStringAsFixed(decimals < 0 ? 0 : decimals),
      );
  }
}

/// 把 `1.235e+3` 补成 C 习惯的 `1.235e+03`。
String _normalizeExponent(String text) {
  final match = RegExp(r'([eE])([+-])(\d+)$').firstMatch(text);
  if (match == null) return text;
  final digits = match.group(3)!.padLeft(2, '0');
  return '${text.substring(0, match.start)}${match.group(1)}${match.group(2)}$digits';
}

String _trimTrailingZeros(String text) {
  if (!text.contains('.')) return text;
  var mantissa = text;
  var exponent = '';
  final eIndex = text.indexOf(RegExp(r'[eE]'));
  if (eIndex >= 0) {
    mantissa = text.substring(0, eIndex);
    exponent = text.substring(eIndex);
  }
  while (mantissa.endsWith('0')) {
    mantissa = mantissa.substring(0, mantissa.length - 1);
  }
  if (mantissa.endsWith('.')) {
    mantissa = mantissa.substring(0, mantissa.length - 1);
  }
  return mantissa + exponent;
}

/// 按 [format] 消费 [args] 中从 [start] 起的参数，返回文本与消费个数。
_FormatResult _format(
  CInterpreter ctx,
  String format,
  List<CValue> args,
  int start,
) {
  final out = StringBuffer();
  var index = start;
  var i = 0;

  while (i < format.length) {
    final c = format[i];
    if (c != '%') {
      out.write(c);
      i++;
      continue;
    }
    i++;
    if (i >= format.length) break;
    if (format[i] == '%') {
      out.write('%');
      i++;
      continue;
    }

    var leftAlign = false;
    var showSign = false;
    var spaceSign = false;
    var hash = false;
    var zeroFill = false;
    while (i < format.length) {
      final flag = format[i];
      if (flag == '-') {
        leftAlign = true;
      } else if (flag == '+') {
        showSign = true;
      } else if (flag == ' ') {
        spaceSign = true;
      } else if (flag == '#') {
        hash = true;
      } else if (flag == '0') {
        zeroFill = true;
      } else {
        break;
      }
      i++;
    }

    int? width;
    if (i < format.length && format[i] == '*') {
      width = _argInt(args, index++);
      i++;
    } else {
      final digits = _digits(format, i);
      if (digits.isNotEmpty) {
        width = int.parse(digits);
        i += digits.length;
      }
    }

    int? precision;
    if (i < format.length && format[i] == '.') {
      i++;
      if (i < format.length && format[i] == '*') {
        precision = _argInt(args, index++);
        i++;
      } else {
        final digits = _digits(format, i);
        precision = digits.isEmpty ? 0 : int.parse(digits);
        i += digits.length;
      }
    }

    // 长度修饰符（hh/h/l/ll/L/z/j/t）不影响取值，跳过即可。
    while (i < format.length && 'hlLjztq'.contains(format[i])) {
      i++;
    }
    if (i >= format.length) break;
    final spec = format[i];
    i++;

    String text;
    switch (spec) {
      case 'd':
      case 'i':
        final value = _argInt(args, index++);
        var body = value.abs().toString();
        if (precision != null && precision > body.length) {
          body = body.padLeft(precision, '0');
        }
        if (value < 0) {
          text = '-$body';
        } else if (showSign) {
          text = '+$body';
        } else if (spaceSign) {
          text = ' $body';
        } else {
          text = body;
        }
      case 'u':
        text = _formatUnsigned(_argInt(args, index++), 10, false, false);
        if (precision != null && precision > text.length) {
          text = text.padLeft(precision, '0');
        }
      case 'o':
        text = _formatUnsigned(_argInt(args, index++), 8, false, hash);
      case 'x':
      case 'X':
        text = _formatUnsigned(
          _argInt(args, index++),
          16,
          spec == 'X',
          hash,
        );
        if (precision != null && precision > text.length) {
          text = text.padLeft(precision, '0');
        }
      case 'b':
        text = _formatUnsigned(_argInt(args, index++), 2, false, hash);
      case 'f':
      case 'F':
      case 'e':
      case 'E':
      case 'g':
      case 'G':
        final value = _argDouble(args, index++);
        text = _formatDouble(value, precision, spec);
        if (value >= 0) {
          if (showSign) {
            text = '+$text';
          } else if (spaceSign) {
            text = ' $text';
          }
        }
      case 'c':
        final code = _argInt(args, index++);
        text = String.fromCharCode(code);
      case 's':
        final value = _argCString(ctx, args, index++);
        text = precision != null && precision < value.length
            ? value.substring(0, precision)
            : value;
      case 'p':
        final address = _argPointer(args, index++);
        text = address == 0
            ? '(nil)'
            : '0x${address.toRadixString(16)}';
      case 'n':
        // 写入已输出字符数，教学代码几乎不用，消费掉参数即可。
        index++;
        text = '';
      default:
        text = '%$spec';
    }

    out.write(_pad(text, width, leftAlign, zeroFill && !leftAlign));
  }

  return _FormatResult(out.toString(), index - start);
}

// ---- scanf 家族 ----

/// 输入游标：把解释器的字符流包成「读一个 / 退回一个」。
///
/// 退回是必需的——`%d` 得先把数字后面的那个字符读出来，才知道数字到哪儿结束。
class _ScanInput {
  _ScanInput(this._next, this._pushBack);

  final int Function() _next;
  final void Function(int) _pushBack;

  /// 是否读到过 EOF。`scanf` 靠它区分「输入耗尽」（返回 EOF）和
  /// 「字符不匹配」（返回已完成的项数）。
  bool hitEof = false;

  int read() {
    final code = _next();
    if (code < 0) hitEof = true;
    return code;
  }

  void unread(int code) {
    if (code >= 0) _pushBack(code);
  }

  /// 把一整串字符原样退回去（后进先出，所以倒着压）。
  void unreadAll(String text) {
    for (var i = text.length - 1; i >= 0; i--) {
      unread(text.codeUnitAt(i));
    }
  }

  static bool isSpace(int c) =>
      c == 0x20 || c == 0x09 || c == 0x0A || c == 0x0B || c == 0x0C || c == 0x0D;

  /// 跳过空白；遇到第一个非空白字符（已退回）返回 true，到 EOF 返回 false。
  bool skipSpace() {
    while (true) {
      final c = read();
      if (c < 0) return false;
      if (isSpace(c)) continue;
      unread(c);
      return true;
    }
  }
}

int _digitValue(int unit) {
  if (unit >= 0x30 && unit <= 0x39) return unit - 0x30;
  if (unit >= 0x61 && unit <= 0x7A) return unit - 0x61 + 10;
  if (unit >= 0x41 && unit <= 0x5A) return unit - 0x41 + 10;
  return -1;
}

/// `scanf` 参数指向的目标字节数；拿不到指针类型时按 `int` 处理。
int _pointeeSize(CValue target) {
  final type = target.type;
  if (type is CPointerType) {
    final size = type.to.size;
    if (size > 0) return size;
  }
  return 4;
}

/// 扫描一个整数。成功时通过 [store] 写回，失败返回 false。
///
/// [radix] 为 0 表示按前缀自动判断（`%i`：`0x` 十六进制、`0` 八进制、其余十进制）。
bool _scanInteger(
  _ScanInput input,
  int width,
  int radix, {
  required void Function(int value) store,
}) {
  var remaining = width <= 0 ? 1 << 30 : width;
  var negative = false;
  var value = 0;
  var digits = 0;
  var effectiveRadix = radix;
  final consumed = StringBuffer();

  var c = input.read();
  if (c < 0) return false;

  if ((c == 0x2B || c == 0x2D) && remaining > 1) {
    negative = c == 0x2D;
    consumed.writeCharCode(c);
    remaining--;
    c = input.read();
  }

  // 十六进制前缀：`%x` 和 `%i` 都接受。
  if (c == 0x30 && (effectiveRadix == 0 || effectiveRadix == 16) && remaining > 2) {
    final marker = input.read();
    if (marker == 0x78 || marker == 0x58) {
      final after = input.read();
      if (after >= 0 && _digitValue(after) >= 0 && _digitValue(after) < 16) {
        effectiveRadix = 16;
        consumed.write('0x');
        remaining -= 2;
        c = after;
      } else {
        // 后面不是十六进制数字：`0x` 不是前缀，退回去按普通数字处理。
        input.unread(after);
        input.unread(marker);
        effectiveRadix = effectiveRadix == 0 ? 8 : effectiveRadix;
      }
    } else {
      input.unread(marker);
      if (effectiveRadix == 0) effectiveRadix = 8;
    }
  } else if (effectiveRadix == 0) {
    effectiveRadix = c == 0x30 ? 8 : 10;
  }

  while (c >= 0 && remaining > 0) {
    final digit = _digitValue(c);
    if (digit < 0 || digit >= effectiveRadix) break;
    value = value * effectiveRadix + digit;
    digits++;
    consumed.writeCharCode(c);
    remaining--;
    c = input.read();
  }

  input.unread(c);
  if (digits == 0) {
    // 一个合法数字都没有：把已经吃掉的字符全部退回去，让调用方判定失败。
    input.unreadAll(consumed.toString());
    return false;
  }
  store(negative ? -value : value);
  return true;
}

/// 扫描一个浮点数。语法：`[+-] 数字 [. 数字] [(e|E) [+-] 数字]`。
///
/// 指数部分只有在「e + 可选符号 + 至少一位数字」全部成立时才算数，否则把 `e`
/// 退回去——`scanf("%f", &x)` 读 `12e` 应该得到 12，而不是把 `e` 也吞掉。
bool _scanDouble(
  _ScanInput input,
  int width, {
  required void Function(double value) store,
}) {
  var remaining = width <= 0 ? 1 << 30 : width;
  final text = StringBuffer();
  final consumed = StringBuffer();

  void take(int code) {
    text.writeCharCode(code);
    consumed.writeCharCode(code);
    remaining--;
  }

  var c = input.read();
  if (c < 0) return false;

  if ((c == 0x2B || c == 0x2D) && remaining > 1) {
    take(c);
    c = input.read();
  }

  var digits = 0;
  while (c >= 0x30 && c <= 0x39 && remaining > 0) {
    take(c);
    digits++;
    c = input.read();
  }

  if (c == 0x2E && remaining > 1) {
    final after = input.read();
    if (after >= 0x30 && after <= 0x39) {
      take(c);
      c = after;
      while (c >= 0x30 && c <= 0x39 && remaining > 0) {
        take(c);
        digits++;
        c = input.read();
      }
    } else {
      input.unread(after);
    }
  }

  if (digits == 0) {
    input.unread(c);
    input.unreadAll(consumed.toString());
    return false;
  }

  if ((c == 0x65 || c == 0x45) && remaining > 1) {
    final mantissa = text.toString();
    final exponent = StringBuffer()..writeCharCode(c);
    remaining--;
    var after = input.read();
    if ((after == 0x2B || after == 0x2D) && remaining > 1) {
      exponent.writeCharCode(after);
      remaining--;
      after = input.read();
    }
    if (after >= 0x30 && after <= 0x39) {
      while (after >= 0x30 && after <= 0x39 && remaining > 0) {
        exponent.writeCharCode(after);
        remaining--;
        after = input.read();
      }
      input.unread(after);
      text.write(exponent);
      consumed
        ..clear()
        ..write(text.toString());
    } else {
      input.unread(after);
      input.unreadAll(exponent.toString());
      text
        ..clear()
        ..write(mantissa);
      consumed
        ..clear()
        ..write(mantissa);
    }
  } else {
    input.unread(c);
  }

  final parsed = double.tryParse(text.toString());
  if (parsed == null) {
    input.unreadAll(consumed.toString());
    return false;
  }
  store(parsed);
  return true;
}

/// 实现 `scanf` / `sscanf` / `fscanf`。
///
/// 覆盖教学里真正会用到的转换：`%d %i %u %o %x %f %lf %e %g %c %s %%`，
/// 外加宽度、`*` 抑制赋值、格式串空白与字面量匹配。转换失败即停止并返回已经
/// 成功赋值的项数——和标准库的行为一致。
int _scan(
  CInterpreter ctx,
  _ScanInput input,
  String format,
  List<CValue> args,
  int start,
) {
  var assigned = 0;
  var index = start;
  var i = 0;

  /// 收尾：一次转换都没成功、而且是输入先耗尽，按标准库的约定返回 EOF。
  /// 「字符不匹配」（比如 `%d` 撞上字母）则返回已完成的项数。
  int finishScan() => assigned == 0 && input.hitEof ? -1 : assigned;

  while (i < format.length) {
    final f = format.codeUnitAt(i);

    if (_ScanInput.isSpace(f)) {
      // 格式串里的空白匹配输入里任意长度的空白（一个都没有也行）。
      input.skipSpace();
      i++;
      continue;
    }

    if (f != 0x25) {
      // 普通字符必须逐个匹配。
      final c = input.read();
      if (c != f) {
        input.unread(c);
        return finishScan();
      }
      i++;
      continue;
    }

    i++; // 跳过 '%'
    if (i >= format.length) break;
    if (format.codeUnitAt(i) == 0x25) {
      final c = input.read();
      if (c != 0x25) {
        input.unread(c);
        return finishScan();
      }
      i++;
      continue;
    }

    var suppress = false;
    if (format.codeUnitAt(i) == 0x2A) {
      suppress = true;
      i++;
    }

    var width = 0;
    while (i < format.length) {
      final digit = format.codeUnitAt(i) - 0x30;
      if (digit < 0 || digit > 9) break;
      width = width * 10 + digit;
      i++;
    }

    var isLong = false;
    while (i < format.length) {
      final modifier = format[i];
      if (modifier == 'l') {
        isLong = true;
        i++;
      } else if (modifier == 'h' ||
          modifier == 'L' ||
          modifier == 'z' ||
          modifier == 'j' ||
          modifier == 't') {
        i++;
      } else {
        break;
      }
    }

    if (i >= format.length) break;
    final spec = format[i];
    i++;

    final target = suppress || index >= args.length ? null : args[index];
    final size = target == null ? 4 : _pointeeSize(target);

    switch (spec) {
      case 'c':
        // %c 不跳过前导空白（这是它和 %s 最容易被忽略的区别）。
        final count = width <= 0 ? 1 : width;
        final codes = <int>[];
        for (var n = 0; n < count; n++) {
          final c = input.read();
          if (c < 0) break;
          codes.add(c);
        }
        if (codes.isEmpty) return finishScan();
        if (target != null) {
          ctx.mem.writeBytes(_argPointer(args, index), codes);
          assigned++;
        }
        if (!suppress) index++;
      case 's':
        if (!input.skipSpace()) return finishScan();
        final buffer = StringBuffer();
        var remaining = width <= 0 ? 1 << 30 : width;
        while (remaining > 0) {
          final c = input.read();
          if (c < 0 || _ScanInput.isSpace(c)) break;
          buffer.writeCharCode(c);
          remaining--;
        }
        if (buffer.isEmpty) return finishScan();
        if (target != null) {
          // %s 会补一个结尾 NUL，目标缓冲区要留得出这个字节。
          ctx.writeCString(_argPointer(args, index), buffer.toString());
          assigned++;
        }
        if (!suppress) index++;
      case 'd':
      case 'u':
      case 'o':
      case 'x':
      case 'X':
      case 'i':
        if (!input.skipSpace()) return finishScan();
        final radix = switch (spec) {
          'o' => 8,
          'x' || 'X' => 16,
          'i' => 0,
          _ => 10,
        };
        final ok = _scanInteger(
          input,
          width,
          radix,
          store: (value) {
            if (target == null) return;
            ctx.mem.writeInt(_argPointer(args, index), size, value);
          },
        );
        if (!ok) return finishScan();
        if (target != null) assigned++;
        if (!suppress) index++;
      case 'f':
      case 'F':
      case 'e':
      case 'E':
      case 'g':
      case 'G':
      case 'a':
      case 'A':
        if (!input.skipSpace()) return finishScan();
        final ok = _scanDouble(
          input,
          width,
          store: (value) {
            if (target == null) return;
            final address = _argPointer(args, index);
            // %lf / %le / %lg 写 8 字节 double，其余写 4 字节 float。
            if (isLong || size == 8) {
              ctx.mem.writeDouble(address, value);
            } else {
              ctx.mem.writeFloat(address, value);
            }
          },
        );
        if (!ok) return finishScan();
        if (target != null) assigned++;
        if (!suppress) index++;
      case 'n':
        if (!suppress) index++;
      default:
        // 不认识的转换：停在原地，交出已经完成的项数。
        return finishScan();
    }
  }

  return finishScan();
}

// ---- 内置函数表 ----

final Map<String, _Entry> _builtins = {
  // ===== stdio =====
  'printf': _Entry(
    _sig(CTypes.intType, [CTypes.charPointer], variadic: true),
    _wrap((ctx, args) {
      final format = _argCString(ctx, args, 0);
      final result = _format(ctx, format, args, 1);
      ctx.write(result.text);
      return _int(result.text.length);
    }),
  ),
  'fprintf': _Entry(
    _sig(CTypes.intType, [CTypes.voidPointer, CTypes.charPointer],
        variadic: true),
    _wrap((ctx, args) {
      final format = _argCString(ctx, args, 1);
      final result = _format(ctx, format, args, 2);
      ctx.write(result.text);
      return _int(result.text.length);
    }),
  ),
  'sprintf': _Entry(
    _sig(CTypes.intType, [CTypes.charPointer, CTypes.charPointer],
        variadic: true),
    _wrap((ctx, args) {
      final destination = _argPointer(args, 0);
      final format = _argCString(ctx, args, 1);
      final result = _format(ctx, format, args, 2);
      ctx.writeCString(destination, result.text);
      return _int(result.text.length);
    }),
  ),
  'snprintf': _Entry(
    _sig(
      CTypes.intType,
      [CTypes.charPointer, CTypes.unsignedLong, CTypes.charPointer],
      variadic: true,
    ),
    _wrap((ctx, args) {
      final destination = _argPointer(args, 0);
      final capacity = _argInt(args, 1);
      final format = _argCString(ctx, args, 2);
      final result = _format(ctx, format, args, 3);
      ctx.writeCString(destination, result.text, capacity: capacity);
      return _int(result.text.length);
    }),
  ),
  'puts': _Entry(
    _sig(CTypes.intType, [CTypes.charPointer]),
    _wrap((ctx, args) {
      ctx.writeLine(_argCString(ctx, args, 0));
      return _int(0);
    }),
  ),
  'fputs': _Entry(
    _sig(CTypes.intType, [CTypes.charPointer, CTypes.voidPointer]),
    _wrap((ctx, args) {
      ctx.write(_argCString(ctx, args, 0));
      return _int(0);
    }),
  ),
  'putchar': _Entry(
    _sig(CTypes.intType, [CTypes.intType]),
    _wrap((ctx, args) {
      final code = _argInt(args, 0);
      ctx.write(String.fromCharCode(code));
      return _int(code);
    }),
  ),
  'getchar': _Entry(
    _sig(CTypes.intType, []),
    _wrap((ctx, args) {
      final code = ctx.readStdinChar();
      if (code < 0) ctx.stdinStarvedReads++;
      return _int(code);
    }),
  ),
  'ungetc': _Entry(
    _sig(CTypes.intType, [CTypes.intType, CTypes.voidPointer]),
    _wrap((ctx, args) {
      final code = _argInt(args, 0);
      ctx.unreadStdinChar(code);
      return _int(code);
    }),
  ),
  'scanf': _Entry(
    _sig(CTypes.intType, [CTypes.charPointer], variadic: true),
    _wrap((ctx, args) {
      // 回退缓冲挂在解释器上而不是本次调用里：`scanf` 多读一个字符才收手，
      // 这个字符必须留给下一次 `scanf` / `getchar`。
      final assigned = _scan(
        ctx,
        _ScanInput(ctx.readStdinChar, ctx.unreadStdinChar),
        _argCString(ctx, args, 0),
        args,
        1,
      );
      // 返回 -1 表示「一次转换都没做成，输入就没了」。
      if (assigned < 0) ctx.stdinStarvedReads++;
      return _int(assigned);
    }),
  ),
  'sscanf': _Entry(
    _sig(CTypes.intType, [CTypes.charPointer, CTypes.charPointer],
        variadic: true),
    _wrap((ctx, args) {
      final source = _argCString(ctx, args, 0);
      // 游标和回退缓冲都在本次调用内部：`sscanf` 绝不该碰标准输入。
      var cursor = 0;
      final pushback = <int>[];
      return _int(
        _scan(
          ctx,
          _ScanInput(
            () => pushback.isNotEmpty
                ? pushback.removeLast()
                : (cursor < source.length ? source.codeUnitAt(cursor++) : -1),
            pushback.add,
          ),
          _argCString(ctx, args, 1),
          args,
          2,
        ),
      );
    }),
  ),
  'fscanf': _Entry(
    _sig(CTypes.intType, [CTypes.voidPointer, CTypes.charPointer],
        variadic: true),
    _wrap((ctx, args) {
      // 只支持从 stdin 读；其它 FILE* 视为空流。
      final isStdin = _argPointer(args, 0) == 0;
      if (!isStdin) return _int(-1);
      final assigned = _scan(
        ctx,
        _ScanInput(ctx.readStdinChar, ctx.unreadStdinChar),
        _argCString(ctx, args, 1),
        args,
        2,
      );
      if (assigned < 0) ctx.stdinStarvedReads++;
      return _int(assigned);
    }),
  ),
  'gets': _Entry(
    _sig(CTypes.charPointer, [CTypes.charPointer]),
    _wrap((ctx, args) {
      final address = _argPointer(args, 0);
      final line = ctx.readStdinLine();
      if (line == null) {
        ctx.stdinStarvedReads++;
        return _pointer(0, CTypes.charPointer);
      }
      ctx.writeCString(address, line);
      return _pointer(address, CTypes.charPointer);
    }),
  ),
  'fgets': _Entry(
    _sig(CTypes.charPointer, [CTypes.charPointer, CTypes.intType,
        CTypes.voidPointer]),
    _wrap((ctx, args) {
      final address = _argPointer(args, 0);
      final capacity = _argInt(args, 1);
      if (capacity <= 1) {
        if (capacity == 1) ctx.writeCString(address, '');
        return capacity == 1
            ? _pointer(address, CTypes.charPointer)
            : _pointer(0, CTypes.charPointer);
      }
      // 最多读 capacity - 1 个字符，再补 NUL。
      final line = ctx.readStdinLine();
      if (line == null) {
        ctx.stdinStarvedReads++;
        return _pointer(0, CTypes.charPointer);
      }
      final kept = line.length > capacity - 1
          ? line.substring(0, capacity - 1)
          : line;
      ctx.writeCString(address, kept);
      return _pointer(address, CTypes.charPointer);
    }),
  ),
  'fflush': _Entry(
    _sig(CTypes.intType, [CTypes.voidPointer]),
    _wrap((ctx, args) => _int(0)),
  ),
  'remove': _Entry(
    _sig(CTypes.intType, [CTypes.charPointer]),
    _wrap((ctx, args) => _int(-1)),
  ),

  // ===== string =====
  'strlen': _Entry(
    _sig(CTypes.unsignedLong, [CTypes.charPointer]),
    _wrap((ctx, args) =>
        _sizeValue(ctx.readCString(_argPointer(args, 0)).length)),
  ),
  'strcpy': _Entry(
    _sig(CTypes.charPointer, [CTypes.charPointer, CTypes.charPointer]),
    _wrap((ctx, args) {
      final destination = _argPointer(args, 0);
      ctx.writeCString(destination, _argCString(ctx, args, 1));
      return _pointer(destination, CTypes.charPointer);
    }),
  ),
  'strncpy': _Entry(
    _sig(
      CTypes.charPointer,
      [CTypes.charPointer, CTypes.charPointer, CTypes.unsignedLong],
    ),
    _wrap((ctx, args) {
      final destination = _argPointer(args, 0);
      final source = _argCString(ctx, args, 1);
      final count = _argInt(args, 2);
      // 与 C 一致：不足部分补 NUL。
      final padded = source.length >= count
          ? source.substring(0, count)
          : source.padRight(count, '\x00');
      ctx.mem.writeBytes(destination, padded.codeUnits);
      return _pointer(destination, CTypes.charPointer);
    }),
  ),
  'strcat': _Entry(
    _sig(CTypes.charPointer, [CTypes.charPointer, CTypes.charPointer]),
    _wrap((ctx, args) {
      final destination = _argPointer(args, 0);
      final existing = ctx.readCString(destination);
      ctx.writeCString(destination, existing + _argCString(ctx, args, 1));
      return _pointer(destination, CTypes.charPointer);
    }),
  ),
  'strncat': _Entry(
    _sig(
      CTypes.charPointer,
      [CTypes.charPointer, CTypes.charPointer, CTypes.unsignedLong],
    ),
    _wrap((ctx, args) {
      final destination = _argPointer(args, 0);
      final existing = ctx.readCString(destination);
      final source = _argCString(ctx, args, 1);
      final count = _argInt(args, 2);
      final appended = source.length > count ? source.substring(0, count) : source;
      ctx.writeCString(destination, existing + appended);
      return _pointer(destination, CTypes.charPointer);
    }),
  ),
  'strcmp': _Entry(
    _sig(CTypes.intType, [CTypes.charPointer, CTypes.charPointer]),
    _wrap((ctx, args) => _int(
      _compareStrings(_argCString(ctx, args, 0), _argCString(ctx, args, 1), null),
    )),
  ),
  'strncmp': _Entry(
    _sig(
      CTypes.intType,
      [CTypes.charPointer, CTypes.charPointer, CTypes.unsignedLong],
    ),
    _wrap((ctx, args) => _int(_compareStrings(
      _argCString(ctx, args, 0),
      _argCString(ctx, args, 1),
      _argInt(args, 2),
    ))),
  ),
  'strchr': _Entry(
    _sig(CTypes.charPointer, [CTypes.charPointer, CTypes.intType]),
    _wrap((ctx, args) {
      final source = _argCString(ctx, args, 0);
      final target = String.fromCharCode(_argInt(args, 1));
      final index = source.indexOf(target);
      if (index < 0) return _pointer(0, CTypes.charPointer);
      return _pointer(_argPointer(args, 0) + index, CTypes.charPointer);
    }),
  ),
  'strrchr': _Entry(
    _sig(CTypes.charPointer, [CTypes.charPointer, CTypes.intType]),
    _wrap((ctx, args) {
      final source = _argCString(ctx, args, 0);
      final target = String.fromCharCode(_argInt(args, 1));
      final index = source.lastIndexOf(target);
      if (index < 0) return _pointer(0, CTypes.charPointer);
      return _pointer(_argPointer(args, 0) + index, CTypes.charPointer);
    }),
  ),
  'strstr': _Entry(
    _sig(CTypes.charPointer, [CTypes.charPointer, CTypes.charPointer]),
    _wrap((ctx, args) {
      final haystack = _argCString(ctx, args, 0);
      final needle = _argCString(ctx, args, 1);
      if (needle.isEmpty) return _pointer(_argPointer(args, 0), CTypes.charPointer);
      final index = haystack.indexOf(needle);
      if (index < 0) return _pointer(0, CTypes.charPointer);
      return _pointer(_argPointer(args, 0) + index, CTypes.charPointer);
    }),
  ),
  'strdup': _Entry(
    _sig(CTypes.charPointer, [CTypes.charPointer]),
    _wrap((ctx, args) {
      final source = _argCString(ctx, args, 0);
      final bytes = [...source.codeUnits, 0];
      final address = ctx.mem.malloc(bytes.length);
      ctx.mem.writeBytes(address, bytes);
      return _pointer(address, CTypes.charPointer);
    }),
  ),

  // ===== 内存 =====
  'memset': _Entry(
    _sig(
      CTypes.voidPointer,
      [CTypes.voidPointer, CTypes.intType, CTypes.unsignedLong],
    ),
    _wrap((ctx, args) {
      final destination = _argPointer(args, 0);
      final byte = _argInt(args, 1) & 0xFF;
      final count = _argInt(args, 2);
      if (count > 0) {
        ctx.mem.writeBytes(destination, List<int>.filled(count, byte));
      }
      return _pointer(destination);
    }),
  ),
  'memcpy': _Entry(
    _sig(
      CTypes.voidPointer,
      [CTypes.voidPointer, CTypes.voidPointer, CTypes.unsignedLong],
    ),
    _wrap((ctx, args) {
      final destination = _argPointer(args, 0);
      final source = _argPointer(args, 1);
      final count = _argInt(args, 2);
      if (count > 0) ctx.mem.copy(source, destination, count);
      return _pointer(destination);
    }),
  ),
  'memmove': _Entry(
    _sig(
      CTypes.voidPointer,
      [CTypes.voidPointer, CTypes.voidPointer, CTypes.unsignedLong],
    ),
    _wrap((ctx, args) {
      final destination = _argPointer(args, 0);
      final source = _argPointer(args, 1);
      final count = _argInt(args, 2);
      if (count > 0) ctx.mem.copy(source, destination, count);
      return _pointer(destination);
    }),
  ),
  'memcmp': _Entry(
    _sig(
      CTypes.intType,
      [CTypes.voidPointer, CTypes.voidPointer, CTypes.unsignedLong],
    ),
    _wrap((ctx, args) {
      final left = ctx.mem.readBytes(_argPointer(args, 0), _argInt(args, 2));
      final right = ctx.mem.readBytes(_argPointer(args, 1), _argInt(args, 2));
      for (var i = 0; i < left.length; i++) {
        if (left[i] != right[i]) return _int(left[i] - right[i]);
      }
      return _int(0);
    }),
  ),
  'malloc': _Entry(
    _sig(CTypes.voidPointer, [CTypes.unsignedLong]),
    _wrap((ctx, args) => _pointer(ctx.mem.malloc(_argInt(args, 0)))),
  ),
  'calloc': _Entry(
    _sig(CTypes.voidPointer, [CTypes.unsignedLong, CTypes.unsignedLong]),
    _wrap((ctx, args) {
      final total = _argInt(args, 0) * _argInt(args, 1);
      final address = ctx.mem.malloc(total);
      ctx.mem.zero(address, total);
      return _pointer(address);
    }),
  ),
  'realloc': _Entry(
    _sig(CTypes.voidPointer, [CTypes.voidPointer, CTypes.unsignedLong]),
    _wrap((ctx, args) {
      final oldAddress = _argPointer(args, 0);
      final size = _argInt(args, 1);
      if (oldAddress == 0) return _pointer(ctx.mem.malloc(size));
      final address = ctx.mem.malloc(size);
      if (size > 0) {
        // 尽力复制：读不到就跳过（旧块可能比 size 小）。
        try {
          final previous = ctx.mem.readBytes(
            oldAddress,
            size > 4096 ? 4096 : size,
          );
          ctx.mem.writeBytes(address, previous);
        } catch (_) {
          // 忽略。
        }
      }
      ctx.mem.free(oldAddress);
      return _pointer(address);
    }),
  ),
  'free': _Entry(
    _sig(CTypes.voidType, [CTypes.voidPointer]),
    _wrap((ctx, args) {
      ctx.mem.free(_argPointer(args, 0));
      return CValue(CTypes.voidType, 0, immediate: 0);
    }),
  ),

  // ===== stdlib =====
  'exit': _Entry(
    _sig(CTypes.voidType, [CTypes.intType]),
    _wrap((ctx, args) => ctx.exit(_argInt(args, 0))),
  ),
  'abort': _Entry(
    _sig(CTypes.voidType, []),
    _wrap((ctx, args) => ctx.exit(134)),
  ),
  'atoi': _Entry(
    _sig(CTypes.intType, [CTypes.charPointer]),
    _wrap((ctx, args) => _int(_parseLongPrefix(_argCString(ctx, args, 0)))),
  ),
  'atol': _Entry(
    _sig(CTypes.longType, [CTypes.charPointer]),
    _wrap((ctx, args) => _long(_parseLongPrefix(_argCString(ctx, args, 0)))),
  ),
  'atof': _Entry(
    _sig(CTypes.doubleType, [CTypes.charPointer]),
    _wrap((ctx, args) => _double(_parseDoublePrefix(_argCString(ctx, args, 0)))),
  ),
  'strtol': _Entry(
    _sig(
      CTypes.longType,
      [CTypes.charPointer, CTypes.voidPointer, CTypes.intType],
    ),
    _wrap((ctx, args) => _long(_parseLongPrefix(_argCString(ctx, args, 0)))),
  ),
  'strtod': _Entry(
    _sig(CTypes.doubleType, [CTypes.charPointer, CTypes.voidPointer]),
    _wrap((ctx, args) => _double(_parseDoublePrefix(_argCString(ctx, args, 0)))),
  ),
  'abs': _Entry(
    _sig(CTypes.intType, [CTypes.intType]),
    _wrap((ctx, args) => _int(_argInt(args, 0).abs())),
  ),
  'labs': _Entry(
    _sig(CTypes.longType, [CTypes.longType]),
    _wrap((ctx, args) => _long(_argInt(args, 0).abs())),
  ),
  'rand': _Entry(
    _sig(CTypes.intType, []),
    _wrap((ctx, args) => _int(ctx.nextRandom())),
  ),
  'srand': _Entry(
    _sig(CTypes.voidType, [CTypes.unsignedInt]),
    _wrap((ctx, args) {
      ctx.seedRandom(_argInt(args, 0));
      return CValue(CTypes.voidType, 0, immediate: 0);
    }),
  ),

  // ===== math =====
  'sqrt': _Entry(
    _sig(CTypes.doubleType, [CTypes.doubleType]),
    _wrap((ctx, args) => _double(math.sqrt(_argDouble(args, 0)))),
  ),
  'cbrt': _Entry(
    _sig(CTypes.doubleType, [CTypes.doubleType]),
    _wrap((ctx, args) {
      final x = _argDouble(args, 0);
      return _double(
        x < 0
            ? -math.pow(-x, 1 / 3).toDouble()
            : math.pow(x, 1 / 3).toDouble(),
      );
    }),
  ),
  'pow': _Entry(
    _sig(CTypes.doubleType, [CTypes.doubleType, CTypes.doubleType]),
    _wrap((ctx, args) =>
        _double(math.pow(_argDouble(args, 0), _argDouble(args, 1)).toDouble())),
  ),
  'fabs': _Entry(
    _sig(CTypes.doubleType, [CTypes.doubleType]),
    _wrap((ctx, args) => _double(_argDouble(args, 0).abs())),
  ),
  'floor': _Entry(
    _sig(CTypes.doubleType, [CTypes.doubleType]),
    _wrap((ctx, args) => _double(_argDouble(args, 0).floorToDouble())),
  ),
  'ceil': _Entry(
    _sig(CTypes.doubleType, [CTypes.doubleType]),
    _wrap((ctx, args) => _double(_argDouble(args, 0).ceilToDouble())),
  ),
  'round': _Entry(
    _sig(CTypes.doubleType, [CTypes.doubleType]),
    _wrap((ctx, args) => _double(_argDouble(args, 0).roundToDouble())),
  ),
  'trunc': _Entry(
    _sig(CTypes.doubleType, [CTypes.doubleType]),
    _wrap((ctx, args) => _double(_argDouble(args, 0).truncateToDouble())),
  ),
  'fmod': _Entry(
    _sig(CTypes.doubleType, [CTypes.doubleType, CTypes.doubleType]),
    _wrap((ctx, args) {
      final x = _argDouble(args, 0);
      final y = _argDouble(args, 1);
      if (y == 0) return _double(double.nan);
      return _double(x - (x / y).truncateToDouble() * y);
    }),
  ),
  'sin': _Entry(
    _sig(CTypes.doubleType, [CTypes.doubleType]),
    _wrap((ctx, args) => _double(math.sin(_argDouble(args, 0)))),
  ),
  'cos': _Entry(
    _sig(CTypes.doubleType, [CTypes.doubleType]),
    _wrap((ctx, args) => _double(math.cos(_argDouble(args, 0)))),
  ),
  'tan': _Entry(
    _sig(CTypes.doubleType, [CTypes.doubleType]),
    _wrap((ctx, args) => _double(math.tan(_argDouble(args, 0)))),
  ),
  'asin': _Entry(
    _sig(CTypes.doubleType, [CTypes.doubleType]),
    _wrap((ctx, args) => _double(math.asin(_argDouble(args, 0)))),
  ),
  'acos': _Entry(
    _sig(CTypes.doubleType, [CTypes.doubleType]),
    _wrap((ctx, args) => _double(math.acos(_argDouble(args, 0)))),
  ),
  'atan': _Entry(
    _sig(CTypes.doubleType, [CTypes.doubleType]),
    _wrap((ctx, args) => _double(math.atan(_argDouble(args, 0)))),
  ),
  'atan2': _Entry(
    _sig(CTypes.doubleType, [CTypes.doubleType, CTypes.doubleType]),
    _wrap((ctx, args) =>
        _double(math.atan2(_argDouble(args, 0), _argDouble(args, 1)))),
  ),
  'sinh': _Entry(
    _sig(CTypes.doubleType, [CTypes.doubleType]),
    _wrap((ctx, args) {
      final x = _argDouble(args, 0);
      return _double((math.exp(x) - math.exp(-x)) / 2);
    }),
  ),
  'cosh': _Entry(
    _sig(CTypes.doubleType, [CTypes.doubleType]),
    _wrap((ctx, args) {
      final x = _argDouble(args, 0);
      return _double((math.exp(x) + math.exp(-x)) / 2);
    }),
  ),
  'tanh': _Entry(
    _sig(CTypes.doubleType, [CTypes.doubleType]),
    _wrap((ctx, args) {
      final x = _argDouble(args, 0);
      return _double((math.exp(x) - math.exp(-x)) / (math.exp(x) + math.exp(-x)));
    }),
  ),
  'log': _Entry(
    _sig(CTypes.doubleType, [CTypes.doubleType]),
    _wrap((ctx, args) => _double(math.log(_argDouble(args, 0)))),
  ),
  'log10': _Entry(
    _sig(CTypes.doubleType, [CTypes.doubleType]),
    _wrap((ctx, args) => _double(math.log(_argDouble(args, 0)) / math.ln10)),
  ),
  'log2': _Entry(
    _sig(CTypes.doubleType, [CTypes.doubleType]),
    _wrap((ctx, args) => _double(math.log(_argDouble(args, 0)) / math.ln2)),
  ),
  'exp': _Entry(
    _sig(CTypes.doubleType, [CTypes.doubleType]),
    _wrap((ctx, args) => _double(math.exp(_argDouble(args, 0)))),
  ),
  'hypot': _Entry(
    _sig(CTypes.doubleType, [CTypes.doubleType, CTypes.doubleType]),
    _wrap((ctx, args) {
      final x = _argDouble(args, 0);
      final y = _argDouble(args, 1);
      return _double(math.sqrt(x * x + y * y));
    }),
  ),
  'fmin': _Entry(
    _sig(CTypes.doubleType, [CTypes.doubleType, CTypes.doubleType]),
    _wrap((ctx, args) => _double(math.min(_argDouble(args, 0), _argDouble(args, 1)))),
  ),
  'fmax': _Entry(
    _sig(CTypes.doubleType, [CTypes.doubleType, CTypes.doubleType]),
    _wrap((ctx, args) => _double(math.max(_argDouble(args, 0), _argDouble(args, 1)))),
  ),
  'ldexp': _Entry(
    _sig(CTypes.doubleType, [CTypes.doubleType, CTypes.intType]),
    _wrap((ctx, args) =>
        _double(_argDouble(args, 0) * math.pow(2, _argInt(args, 1)).toDouble())),
  ),
  'modf': _Entry(
    _sig(CTypes.doubleType, [CTypes.doubleType, CTypes.voidPointer]),
    _wrap((ctx, args) {
      final x = _argDouble(args, 0);
      final integral = x.truncateToDouble();
      final pointer = _argPointer(args, 1);
      if (pointer != 0) ctx.mem.writeDouble(pointer, integral);
      return _double(x - integral);
    }),
  ),

  // ===== ctype =====
  'isalpha': _Entry(
    _sig(CTypes.intType, [CTypes.intType]),
    _wrap((ctx, args) => _int(_isAlpha(_argInt(args, 0)) ? 1 : 0)),
  ),
  'isdigit': _Entry(
    _sig(CTypes.intType, [CTypes.intType]),
    _wrap((ctx, args) => _int(_isDigit(_argInt(args, 0)) ? 1 : 0)),
  ),
  'isalnum': _Entry(
    _sig(CTypes.intType, [CTypes.intType]),
    _wrap((ctx, args) => _int(
      (_isAlpha(_argInt(args, 0)) || _isDigit(_argInt(args, 0))) ? 1 : 0,
    )),
  ),
  'isspace': _Entry(
    _sig(CTypes.intType, [CTypes.intType]),
    _wrap((ctx, args) {
      final c = _argInt(args, 0);
      return _int(
        (c == 0x20 || (c >= 0x09 && c <= 0x0D)) ? 1 : 0,
      );
    }),
  ),
  'isupper': _Entry(
    _sig(CTypes.intType, [CTypes.intType]),
    _wrap((ctx, args) {
      final c = _argInt(args, 0);
      return _int((c >= 0x41 && c <= 0x5A) ? 1 : 0);
    }),
  ),
  'islower': _Entry(
    _sig(CTypes.intType, [CTypes.intType]),
    _wrap((ctx, args) {
      final c = _argInt(args, 0);
      return _int((c >= 0x61 && c <= 0x7A) ? 1 : 0);
    }),
  ),
  'ispunct': _Entry(
    _sig(CTypes.intType, [CTypes.intType]),
    _wrap((ctx, args) {
      final c = _argInt(args, 0);
      final printable = c >= 0x21 && c <= 0x7E;
      return _int((printable && !_isAlpha(c) && !_isDigit(c)) ? 1 : 0);
    }),
  ),
  'isxdigit': _Entry(
    _sig(CTypes.intType, [CTypes.intType]),
    _wrap((ctx, args) {
      final c = _argInt(args, 0);
      return _int(
        (_isDigit(c) || (c >= 0x41 && c <= 0x46) || (c >= 0x61 && c <= 0x66))
            ? 1
            : 0,
      );
    }),
  ),
  'isprint': _Entry(
    _sig(CTypes.intType, [CTypes.intType]),
    _wrap((ctx, args) {
      final c = _argInt(args, 0);
      return _int((c >= 0x20 && c <= 0x7E) ? 1 : 0);
    }),
  ),
  'iscntrl': _Entry(
    _sig(CTypes.intType, [CTypes.intType]),
    _wrap((ctx, args) {
      final c = _argInt(args, 0);
      return _int((c < 0x20 || c == 0x7F) ? 1 : 0);
    }),
  ),
  'toupper': _Entry(
    _sig(CTypes.intType, [CTypes.intType]),
    _wrap((ctx, args) {
      final c = _argInt(args, 0);
      return _int((c >= 0x61 && c <= 0x7A) ? c - 32 : c);
    }),
  ),
  'tolower': _Entry(
    _sig(CTypes.intType, [CTypes.intType]),
    _wrap((ctx, args) {
      final c = _argInt(args, 0);
      return _int((c >= 0x41 && c <= 0x5A) ? c + 32 : c);
    }),
  ),

  // ===== time =====
  'time': _Entry(
    _sig(CTypes.longType, [CTypes.voidPointer]),
    _wrap((ctx, args) {
      final seconds = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      final pointer = _argPointer(args, 0);
      if (pointer != 0) ctx.mem.writeInt(pointer, 8, seconds);
      return _long(seconds);
    }),
  ),
  'clock': _Entry(
    _sig(CTypes.longType, []),
    _wrap((ctx, args) => _long(ctx.elapsedMicroseconds)),
  ),

  // ===== assert =====
  '__assert_fail': _Entry(
    _sig(CTypes.voidType, [CTypes.charPointer, CTypes.charPointer, CTypes.intType]),
    _wrap((ctx, args) {
      final expression = _argCString(ctx, args, 0);
      final file = _argCString(ctx, args, 1);
      final line = _argInt(args, 2);
      ctx.writeLine('断言失败：$expression（$file:$line）');
      ctx.exit(134);
    }),
  ),
};

// ---- 小工具 ----

bool _isAlpha(int c) => (c >= 0x41 && c <= 0x5A) || (c >= 0x61 && c <= 0x7A);

bool _isDigit(int c) => c >= 0x30 && c <= 0x39;

int _compareStrings(String left, String right, int? count) {
  final a = count == null || count > left.length ? left : left.substring(0, count);
  final b =
      count == null || count > right.length ? right : right.substring(0, count);
  final limit = math.min(a.length, b.length);
  for (var i = 0; i < limit; i++) {
    if (a.codeUnitAt(i) != b.codeUnitAt(i)) {
      return a.codeUnitAt(i) - b.codeUnitAt(i);
    }
  }
  return a.length - b.length;
}

int _parseLongPrefix(String text) {
  final trimmed = text.trimLeft();
  final match = RegExp(r'^[+-]?\d+').firstMatch(trimmed);
  if (match == null) return 0;
  return int.tryParse(match.group(0)!) ?? 0;
}

double _parseDoublePrefix(String text) {
  final trimmed = text.trimLeft();
  final match =
      RegExp(r'^[+-]?(\d+\.?\d*|\.\d+)([eE][+-]?\d+)?').firstMatch(trimmed);
  if (match == null) return 0;
  return double.tryParse(match.group(0)!) ?? 0;
}
