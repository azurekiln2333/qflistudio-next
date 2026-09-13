import 'dart:convert';

import 'package:fast_gbk/fast_gbk.dart' as gbk_lib;

/// 文本编解码器：按名称提供 decode/encode（支持 UTF-8/GBK/Latin-1/UTF-16）。
class TextCodec {
  const TextCodec._(this.name, this._decode, this._encode);

  final String name;
  final String Function(List<int> bytes) _decode;
  final List<int> Function(String text) _encode;

  String decode(List<int> bytes) => _decode(bytes);
  List<int> encode(String text) => _encode(text);

  static const TextCodec utf8 = TextCodec._(
    'UTF-8',
    _decodeUtf8,
    _encodeUtf8,
  );

  static const TextCodec gbk = TextCodec._(
    'GBK',
    _decodeGbk,
    _encodeGbk,
  );

  static const TextCodec latin1 = TextCodec._(
    'Latin-1',
    _decodeLatin1,
    _encodeLatin1,
  );

  static TextCodec utf16le = TextCodec._('UTF-16 LE', (b) => _decodeUtf16(b, true),
      (s) => _encodeUtf16(s, true));
  static TextCodec utf16be = TextCodec._('UTF-16 BE',
      (b) => _decodeUtf16(b, false), (s) => _encodeUtf16(s, false));

  /// 可选编码列表（顺序即设置对话框顺序）。
  static const List<String> names = [
    'UTF-8',
    'GBK',
    'Latin-1',
    'UTF-16 LE',
    'UTF-16 BE',
  ];

  static TextCodec byName(String name) {
    switch (name) {
      case 'GBK':
        return gbk;
      case 'Latin-1':
        return latin1;
      case 'UTF-16 LE':
        return utf16le;
      case 'UTF-16 BE':
        return utf16be;
      default:
        return utf8;
    }
  }

  static String _decodeUtf8(List<int> bytes) {
    var text = const Utf8Codec(allowMalformed: true).decode(bytes);
    if (text.startsWith('\uFEFF')) text = text.substring(1); // 去 BOM
    return text;
  }

  static List<int> _encodeUtf8(String text) =>
      const Utf8Codec().encode(text);

  static String _decodeGbk(List<int> bytes) {
    var text = gbk_lib.gbk.decode(bytes);
    if (text.startsWith('\uFEFF')) text = text.substring(1);
    return text;
  }

  static List<int> _encodeGbk(String text) => gbk_lib.gbk.encode(text);

  static String _decodeLatin1(List<int> bytes) =>
      const Latin1Codec(allowInvalid: true).decode(bytes);

  static List<int> _encodeLatin1(String text) =>
      const Latin1Codec(allowInvalid: false).encode(text);

  static String _decodeUtf16(List<int> bytes, bool littleEndian) {
    final units = <int>[];
    for (var i = 0; i + 1 < bytes.length; i += 2) {
      units.add(littleEndian
          ? bytes[i] | (bytes[i + 1] << 8)
          : (bytes[i] << 8) | bytes[i + 1]);
    }
    return String.fromCharCodes(units);
  }

  static List<int> _encodeUtf16(String text, bool littleEndian) {
    final out = <int>[];
    for (final unit in text.codeUnits) {
      if (littleEndian) {
        out.add(unit & 0xFF);
        out.add((unit >> 8) & 0xFF);
      } else {
        out.add((unit >> 8) & 0xFF);
        out.add(unit & 0xFF);
      }
    }
    return out;
  }

  /// 自动识别编码：BOM → 严格 UTF-8 校验 → GBK（中文环境最常见）。
  static String detect(List<int> bytes) {
    if (bytes.length >= 3 &&
        bytes[0] == 0xEF &&
        bytes[1] == 0xBB &&
        bytes[2] == 0xBF) {
      return 'UTF-8';
    }
    if (bytes.length >= 2 && bytes[0] == 0xFF && bytes[1] == 0xFE) {
      return 'UTF-16 LE';
    }
    if (bytes.length >= 2 && bytes[0] == 0xFE && bytes[1] == 0xFF) {
      return 'UTF-16 BE';
    }
    var hasHighByte = false;
    for (final b in bytes) {
      if (b >= 0x80) {
        hasHighByte = true;
        break;
      }
    }
    if (!hasHighByte) return 'UTF-8'; // 纯 ASCII
    try {
      const Utf8Codec(allowMalformed: false).decode(bytes); // 严格校验
      return 'UTF-8';
    } on FormatException {
      // 高位字节存在且非 UTF-8：中文环境优先按 GBK 处理
      return 'GBK';
    }
  }
}
