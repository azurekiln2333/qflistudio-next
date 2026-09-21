/// 线性内存模型：全局区、堆区、栈区、临时区各占一段虚拟地址空间。
///
/// 栈区和临时区都是「撞指针 + 水位标记」，函数进入时记录水位、返回时回滚，
/// 于是不需要真的做垃圾回收；临时区还会在每条语句结束时回滚，避免循环里
/// 无限增长。
library;

import 'dart:typed_data';

import 'c_value.dart';

/// 内存访问越界或非法地址。
class CMemoryException implements Exception {
  CMemoryException(this.message);

  final String message;

  @override
  String toString() => '内存错误：$message';
}

class _Region {
  _Region(this.base, this.capacity);

  final int base;
  Uint8List _bytes = Uint8List(0);
  int capacity;

  void _ensure(int needed) {
    if (needed <= _bytes.length) return;
    var next = _bytes.isEmpty ? capacity : _bytes.length;
    while (next < needed) {
      next *= 2;
    }
    final grown = Uint8List(next);
    grown.setRange(0, _bytes.length, _bytes);
    _bytes = grown;
  }

  int read(int offset, int size) {
    if (offset < 0 || offset + size > _bytes.length) {
      throw CMemoryException('读取越界（区域 0x${base.toRadixString(16)}，偏移 $offset）');
    }
    final data = ByteData.sublistView(_bytes, offset, offset + size);
    switch (size) {
      case 1:
        return data.getUint8(0);
      case 2:
        return data.getUint16(0, Endian.little);
      case 4:
        return data.getUint32(0, Endian.little);
      case 8:
        return data.getUint64(0, Endian.little);
      default:
        throw CMemoryException('不支持 $size 字节的整数读取');
    }
  }

  void write(int offset, int size, int value) {
    _ensure(offset + size);
    final data = ByteData.sublistView(_bytes, offset, offset + size);
    switch (size) {
      case 1:
        data.setUint8(0, value & 0xFF);
      case 2:
        data.setUint16(0, value & 0xFFFF, Endian.little);
      case 4:
        data.setUint32(0, value & 0xFFFFFFFF, Endian.little);
      case 8:
        data.setUint64(0, value & 0xFFFFFFFFFFFFFFFF, Endian.little);
      default:
        throw CMemoryException('不支持 $size 字节的整数写入');
    }
  }

  double readDouble(int offset) =>
      ByteData.sublistView(_bytes, offset, offset + 8).getFloat64(0, Endian.little);

  double readFloat(int offset) =>
      ByteData.sublistView(_bytes, offset, offset + 4).getFloat32(0, Endian.little);

  void writeDouble(int offset, double value) {
    _ensure(offset + 8);
    ByteData.sublistView(_bytes, offset, offset + 8)
        .setFloat64(0, value, Endian.little);
  }

  void writeFloat(int offset, double value) {
    _ensure(offset + 4);
    ByteData.sublistView(_bytes, offset, offset + 4)
        .setFloat32(0, value, Endian.little);
  }

  Uint8List bytesAt(int offset, int length) {
    if (offset < 0 || offset + length > _bytes.length) {
      throw CMemoryException('读取越界（区域 0x${base.toRadixString(16)}，偏移 $offset）');
    }
    return Uint8List.fromList(_bytes.sublist(offset, offset + length));
  }

  void writeBytes(int offset, List<int> data) {
    _ensure(offset + data.length);
    _bytes.setRange(offset, offset + data.length, data);
  }

  /// 初始化新分配的区域为 0。
  void zero(int offset, int length) {
    _ensure(offset + length);
    _bytes.fillRange(offset, offset + length, 0);
  }
}

class _HeapBlock {
  _HeapBlock(this.offset, this.size);

  int offset;
  int size;
  bool free = false;
}

/// 内存。
class CMemory {
  CMemory();

  final _Region _globals = _Region(CSpace.globalsBase, 4096);
  final _Region _heap = _Region(CSpace.heapBase, 65536);
  final _Region _stack = _Region(CSpace.stackBase, 8192);
  final _Region _temps = _Region(CSpace.tempBase, 8192);

  int _globalsBrk = 0;
  int _heapBrk = 0;
  int _stackBrk = 0;
  int _tempBrk = 0;

  final List<_HeapBlock> _blocks = [];

  _Region _regionFor(int address) {
    final region = CSpace.regionOf(address);
    if (region == CSpace.regionOf(CSpace.globalsBase)) return _globals;
    if (region == CSpace.regionOf(CSpace.heapBase)) return _heap;
    if (region == CSpace.regionOf(CSpace.stackBase)) return _stack;
    if (region == CSpace.regionOf(CSpace.tempBase)) return _temps;
    throw CMemoryException(
      '非法地址 0x${address.toRadixString(16)}（可能是空指针或已释放的内存）',
    );
  }

  static int _align(int value, int alignment) =>
      alignment <= 1 ? value : (value + alignment - 1) & ~(alignment - 1);

  // ---- 分配 ----

  int allocateGlobals(int size, int align) {
    _globalsBrk = _align(_globalsBrk, align);
    final offset = _globalsBrk;
    _globalsBrk += size < 1 ? 1 : size;
    _globals.zero(offset, size < 1 ? 1 : size);
    return CSpace.globalsBase + offset;
  }

  int allocateStack(int size, int align) {
    _stackBrk = _align(_stackBrk, align);
    final offset = _stackBrk;
    _stackBrk += size < 1 ? 1 : size;
    _stack.zero(offset, size < 1 ? 1 : size);
    return CSpace.stackBase + offset;
  }

  int allocateTemp(int size, int align) {
    _tempBrk = _align(_tempBrk, align);
    final offset = _tempBrk;
    _tempBrk += size < 1 ? 1 : size;
    _temps.zero(offset, size < 1 ? 1 : size);
    return CSpace.tempBase + offset;
  }

  // ---- 水位 ----

  int markStack() => _stackBrk;

  void releaseStack(int mark) => _stackBrk = mark;

  int markTemps() => _tempBrk;

  void releaseTemps(int mark) => _tempBrk = mark;

  // ---- 堆 ----

  int malloc(int size) {
    final need = size < 1 ? 1 : size;
    for (final block in _blocks) {
      if (block.free && block.size >= need) {
        block.free = false;
        _heap.zero(block.offset, need);
        return CSpace.heapBase + block.offset;
      }
    }
    _heapBrk = _align(_heapBrk, 16);
    final offset = _heapBrk;
    _heapBrk += need;
    _heap.zero(offset, need);
    _blocks.add(_HeapBlock(offset, need));
    return CSpace.heapBase + offset;
  }

  bool free(int address) {
    if (CSpace.isNull(address)) return true;
    if (CSpace.regionOf(address) != CSpace.regionOf(CSpace.heapBase)) {
      throw CMemoryException(
        'free 收到了非堆地址 0x${address.toRadixString(16)}',
      );
    }
    final offset = CSpace.offsetOf(address);
    for (final block in _blocks) {
      if (block.offset == offset && !block.free) {
        block.free = true;
        _mergeFreeBlocks();
        return true;
      }
    }
    throw CMemoryException('重复释放或非法释放：0x${address.toRadixString(16)}');
  }

  void _mergeFreeBlocks() {
    _blocks.sort((a, b) => a.offset.compareTo(b.offset));
    for (var i = 0; i < _blocks.length - 1; i++) {
      final current = _blocks[i];
      final next = _blocks[i + 1];
      if (current.free && next.free && current.offset + current.size == next.offset) {
        current.size += next.size;
        _blocks.removeAt(i + 1);
        i--;
      }
    }
  }

  /// 堆上已分配的块数，用于诊断。
  int get heapBlockCount => _blocks.length;

  // ---- 读写 ----

  int readInt(int address, int size, {bool signed = false}) {
    final raw = _regionFor(address).read(CSpace.offsetOf(address), size);
    if (!signed) return raw;
    switch (size) {
      case 1:
        return (raw & 0x80) != 0 ? raw - 0x100 : raw;
      case 2:
        return (raw & 0x8000) != 0 ? raw - 0x10000 : raw;
      case 4:
        return (raw & 0x80000000) != 0 ? raw - 0x100000000 : raw;
      case 8:
        return raw;
      default:
        return raw;
    }
  }

  void writeInt(int address, int size, int value) =>
      _regionFor(address).write(CSpace.offsetOf(address), size, value);

  double readDouble(int address) =>
      _regionFor(address).readDouble(CSpace.offsetOf(address));

  double readFloat(int address) =>
      _regionFor(address).readFloat(CSpace.offsetOf(address));

  void writeDouble(int address, double value) =>
      _regionFor(address).writeDouble(CSpace.offsetOf(address), value);

  void writeFloat(int address, double value) =>
      _regionFor(address).writeFloat(CSpace.offsetOf(address), value);

  Uint8List readBytes(int address, int length) =>
      _regionFor(address).bytesAt(CSpace.offsetOf(address), length);

  void writeBytes(int address, List<int> data) =>
      _regionFor(address).writeBytes(CSpace.offsetOf(address), data);

  void zero(int address, int length) =>
      _regionFor(address).zero(CSpace.offsetOf(address), length);

  /// 把 [length] 字节从 [from] 复制到 [to]，允许重叠。
  void copy(int from, int to, int length) {
    if (from == to || length <= 0) return;
    final data = readBytes(from, length);
    writeBytes(to, data);
  }
}
