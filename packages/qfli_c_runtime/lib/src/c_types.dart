/// C 类型系统。
///
/// 目标平台按 LP64 建模（arm64 / 鸿蒙）：`int` 4 字节、`long` 8 字节、
/// 指针 8 字节。这与设备上的真机行为一致，避免「本地能跑、上机就溢出」。
library;

/// 类型种类。
enum CTypeKind {
  voidType,
  integer,
  floating,
  pointer,
  array,
  record, // struct / union
  enumType,
  function,
}

/// 基类。子类实现 [size] / [align]，并保证值相等即类型相等（结构等价）。
sealed class CType {
  const CType();

  /// 占用字节数。
  int get size;

  /// 对齐字节数。
  int get align;

  /// 是否为算术类型（整数或浮点）。
  bool get isArithmetic => this is CIntegerType || this is CFloatType;

  /// 是否为整数类型。
  bool get isInteger => this is CIntegerType;

  /// 是否为指针类型。
  bool get isPointer => this is CPointerType;

  /// 是否为数组类型。
  bool get isArray => this is CArrayType;

  /// 是否为标量（可以参与算术/比较）。
  bool get isScalar => isArithmetic || isPointer;

  /// 去掉数组后的元素类型；非数组返回自身。
  CType get decayed {
    var t = this;
    while (t is CArrayType) {
      t = t.element;
    }
    return t;
  }

  /// 指针指向的类型；非指针返回 null。
  CType? get pointee => this is CPointerType ? (this as CPointerType).to : null;
}

/// 整数类型。
class CIntegerType extends CType {
  const CIntegerType._(this.name, this.bits, this.isSigned);

  final String name;
  final int bits;
  final bool isSigned;

  @override
  int get size => bits ~/ 8;

  @override
  int get align => size;

  /// 可表示的最大值（无符号）或最大值（有符号）。
  int get maxValue => isSigned ? (1 << (bits - 1)) - 1 : (1 << bits) - 1;

  int get minValue => isSigned ? -(1 << (bits - 1)) : 0;

  @override
  bool operator ==(Object other) =>
      other is CIntegerType &&
      other.bits == bits &&
      other.isSigned == isSigned;

  @override
  int get hashCode => Object.hash(bits, isSigned);

  @override
  String toString() => name;
}

/// 浮点类型。
class CFloatType extends CType {
  const CFloatType._(this.name, this.size);

  final String name;

  @override
  final int size;

  @override
  int get align => size;

  @override
  bool operator ==(Object other) => other is CFloatType && other.size == size;

  @override
  int get hashCode => size;

  @override
  String toString() => name;
}

/// `void`。
class CVoidType extends CType {
  const CVoidType();

  @override
  int get size => 0;

  @override
  int get align => 1;

  @override
  bool operator ==(Object other) => other is CVoidType;

  @override
  int get hashCode => 0;

  @override
  String toString() => 'void';
}

/// 指针。
class CPointerType extends CType {
  const CPointerType(this.to);

  final CType to;

  @override
  int get size => 8;

  @override
  int get align => 8;

  @override
  bool operator ==(Object other) =>
      other is CPointerType && other.to == to;

  @override
  int get hashCode => Object.hash('ptr', to);

  @override
  String toString() => '$to*';
}

/// 数组。`length` 为 -1 表示长度未定（由初始化列表推导）。
class CArrayType extends CType {
  const CArrayType(this.element, this.length);

  final CType element;
  final int length;

  @override
  int get size => length < 0 ? 0 : element.size * length;

  @override
  int get align => element.align;

  @override
  bool operator ==(Object other) =>
      other is CArrayType &&
      other.element == element &&
      other.length == length;

  @override
  int get hashCode => Object.hash('arr', element, length);

  @override
  String toString() => '$element[$length]';
}

/// 结构体 / 联合体的一个字段。
class CField {
  const CField(this.name, this.type, this.offset);

  final String name;
  final CType type;

  /// 相对结构体起始的字节偏移。
  final int offset;

  @override
  String toString() => '$type $name@$offset';
}

/// 结构体 / 联合体。
class CRecordType extends CType {
  CRecordType({required this.tag, required this.isUnion});

  final String tag;
  final bool isUnion;

  /// 声明阶段字段可能还不完整（例如 `struct Node { struct Node *next; }`）。
  final List<CField> fields = [];

  int? _size;
  int? _align;

  /// 标记布局已计算完成。
  bool _laidOut = false;

  bool get isComplete => _laidOut;

  /// 按声明顺序追加字段，并完成布局。
  void layout() {
    var offset = 0;
    var maxAlign = 1;
    var maxSize = 0;
    for (final f in fields) {
      final a = f.type.align;
      if (a > maxAlign) maxAlign = a;
      if (isUnion) {
        // 联合体所有字段共享偏移 0。
        if (f.type.size > maxSize) maxSize = f.type.size;
      } else {
        offset = _roundUp(offset, a);
        _fieldOffsets[f.name] = offset;
        offset += f.type.size;
      }
      if (f.type.size > maxSize) maxSize = f.type.size;
    }
    if (isUnion) {
      _size = _roundUp(maxSize, maxAlign);
    } else {
      _size = _roundUp(offset, maxAlign);
    }
    _align = maxAlign;
    _laidOut = true;
  }

  final Map<String, int> _fieldOffsets = {};

  /// 字段的字节偏移（联合体恒为 0）。
  int offsetOf(String name) => isUnion ? 0 : (_fieldOffsets[name] ?? 0);

  CField? field(String name) {
    for (final f in fields) {
      if (f.name == name) return f;
    }
    return null;
  }

  static int _roundUp(int value, int alignment) =>
      (value + alignment - 1) & ~(alignment - 1);

  @override
  int get size {
    if (!_laidOut) layout();
    return _size!;
  }

  @override
  int get align {
    if (!_laidOut) layout();
    return _align!;
  }

  @override
  bool operator ==(Object other) => identical(this, other);

  @override
  int get hashCode => identityHashCode(this);

  @override
  String toString() => '${isUnion ? 'union' : 'struct'} $tag';
}

/// 枚举。底层类型固定为 `int`。
class CEnumType extends CType {
  CEnumType(this.tag);

  final String tag;
  final Map<String, int> constants = {};

  @override
  int get size => 4;

  @override
  int get align => 4;

  @override
  bool operator ==(Object other) => identical(this, other);

  @override
  int get hashCode => identityHashCode(this);

  @override
  String toString() => 'enum $tag';
}

/// 函数类型。
class CFunctionType extends CType {
  const CFunctionType({
    required this.returnType,
    required this.parameters,
    required this.variadic,
    this.prototype = false,
  });

  final CType returnType;
  final List<CType> parameters;
  final bool variadic;

  /// 是否来自带参数列表的原型声明（决定实参是否按原型转换）。
  final bool prototype;

  @override
  int get size => 0;

  @override
  int get align => 1;

  @override
  bool operator ==(Object other) =>
      other is CFunctionType &&
      other.returnType == returnType &&
      other.variadic == variadic &&
      _sameList(other.parameters, parameters);

  static bool _sameList(List<CType> a, List<CType> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hash(returnType, variadic, parameters.length);

  @override
  String toString() => '$returnType(...)';
}

/// 预置类型常量。
abstract final class CTypes {
  static const CVoidType voidType = CVoidType();

  static const CIntegerType charType = CIntegerType._('char', 8, true);
  static const CIntegerType signedChar = CIntegerType._('signed char', 8, true);
  static const CIntegerType unsignedChar =
      CIntegerType._('unsigned char', 8, false);
  static const CIntegerType shortType = CIntegerType._('short', 16, true);
  static const CIntegerType unsignedShort =
      CIntegerType._('unsigned short', 16, false);
  static const CIntegerType intType = CIntegerType._('int', 32, true);
  static const CIntegerType unsignedInt =
      CIntegerType._('unsigned int', 32, false);
  static const CIntegerType longType = CIntegerType._('long', 64, true);
  static const CIntegerType unsignedLong =
      CIntegerType._('unsigned long', 64, false);
  static const CIntegerType longLong = CIntegerType._('long long', 64, true);
  static const CIntegerType unsignedLongLong =
      CIntegerType._('unsigned long long', 64, false);
  static const CIntegerType boolType = CIntegerType._('_Bool', 8, false);

  static const CFloatType floatType = CFloatType._('float', 4);
  static const CFloatType doubleType = CFloatType._('double', 8);

  static const CPointerType voidPointer = CPointerType(voidType);
  static const CPointerType charPointer = CPointerType(charType);
}
