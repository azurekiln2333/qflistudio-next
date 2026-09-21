/// 值的表示。
///
/// 设计上「每个对象都有地址」——标量、数组、结构体一视同仁地落在
/// [CMemory] 里。指针就是地址，于是 `&`、`*`、数组下标、`->` 全部退化成
/// 地址算术，不需要为每种类型写特例。
///
/// 唯一例外是纯右值（字面量、运算中间结果）：它们不落内存，直接放在
/// [immediate] 里，省掉大量临时分配。
library;

import 'c_types.dart';

class CValue {
  const CValue(this.type, this.address, {this.isLValue = false, this.immediate});

  /// 静态类型。
  final CType type;

  /// 对象地址。纯右值时为 0。
  final int address;

  /// 是否为左值（可取地址、可赋值）。
  final bool isLValue;

  /// 标量右值的直接取值（int 或 double）。
  final Object? immediate;

  bool get isImmediate => immediate != null;

  int get asInt => immediate as int;

  double get asDouble => immediate as double;

  /// 指针/函数的地址值。
  int get pointerValue => address;

  CValue withType(CType newType) => CValue(
    newType,
    address,
    isLValue: isLValue,
    immediate: immediate,
  );

  @override
  String toString() =>
      'CValue($type, addr=$address${isLValue ? ', lvalue' : ''}'
      '${immediate != null ? ', imm=$immediate' : ''})';
}

/// 一块「虚拟地址空间」。
///
/// 用高位区分区域，低位是区内偏移。这样指针就是一个普通整数，比较、减法、
/// 打印都能直接做，同时又能按区域找到真正存放数据的缓冲区。
abstract final class CSpace {
  static const int globalsBase = 0x0100000000; // 全局/静态对象、字符串字面量
  static const int heapBase = 0x0200000000; // malloc
  static const int stackBase = 0x0300000000; // 局部变量
  static const int tempBase = 0x0400000000; // 表达式临时量
  static const int codeBase = 0x0500000000; // 函数（函数指针）

  static const int offsetMask = 0x00FFFFFFFF;

  static int regionOf(int address) => (address >> 32) & 0xFF;

  static int offsetOf(int address) => address & offsetMask;

  static bool isCode(int address) => regionOf(address) == (codeBase >> 32);

  static bool isNull(int address) => address == 0;
}
