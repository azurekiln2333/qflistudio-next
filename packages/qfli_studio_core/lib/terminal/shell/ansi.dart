import 'package:flutter/material.dart';

/// Semantic role of a segment, resolved against the active [ColorScheme].
/// Used for prompt echoes and stderr, which are not ANSI coloured.
enum TerminalEmphasis { normal, prompt, command, system, error }

/// A run of text with an ANSI-derived style.
@immutable
class TerminalStyle {
  const TerminalStyle({
    this.foreground,
    this.background,
    this.bold = false,
    this.dim = false,
    this.underline = false,
    this.inverted = false,
  });

  /// ANSI 256-colour index, or null for the terminal default.
  final int? foreground;
  final int? background;

  final bool bold;
  final bool dim;
  final bool underline;
  final bool inverted;

  static const TerminalStyle plain = TerminalStyle();

  @override
  bool operator ==(Object other) =>
      other is TerminalStyle &&
      other.foreground == foreground &&
      other.background == background &&
      other.bold == bold &&
      other.dim == dim &&
      other.underline == underline &&
      other.inverted == inverted;

  @override
  int get hashCode =>
      Object.hash(foreground, background, bold, dim, underline, inverted);

  TerminalStyle copyWith({
    int? foreground,
    bool clearForeground = false,
    int? background,
    bool clearBackground = false,
    bool? bold,
    bool? dim,
    bool? underline,
    bool? inverted,
  }) {
    return TerminalStyle(
      foreground: clearForeground ? null : (foreground ?? this.foreground),
      background: clearBackground ? null : (background ?? this.background),
      bold: bold ?? this.bold,
      dim: dim ?? this.dim,
      underline: underline ?? this.underline,
      inverted: inverted ?? this.inverted,
    );
  }
}

@immutable
class TerminalSegment {
  const TerminalSegment(
    this.text, {
    this.style = TerminalStyle.plain,
    this.emphasis = TerminalEmphasis.normal,
  });

  final String text;
  final TerminalStyle style;
  final TerminalEmphasis emphasis;
}

/// The 16 base ANSI colours plus the 256-colour cube, tuned for each brightness.
@immutable
class TerminalPalette {
  const TerminalPalette({
    required this.background,
    required this.foreground,
    required this.normal,
    required this.bright,
  });

  final Color background;
  final Color foreground;
  final List<Color> normal;
  final List<Color> bright;

  static const TerminalPalette dark = TerminalPalette(
    background: Color(0xFF11151A),
    foreground: Color(0xFFD8E0E8),
    normal: <Color>[
      Color(0xFF3B4252),
      Color(0xFFFF6B6B),
      Color(0xFF7BE38A),
      Color(0xFFF2C86B),
      Color(0xFF6FA8FF),
      Color(0xFFD98BFF),
      Color(0xFF5FD9D9),
      Color(0xFFC6CED8),
    ],
    bright: <Color>[
      Color(0xFF5A6478),
      Color(0xFFFF8A8A),
      Color(0xFF9BF0A6),
      Color(0xFFFFDE8A),
      Color(0xFF93C0FF),
      Color(0xFFE8A9FF),
      Color(0xFF84EDED),
      Color(0xFFF2F6FA),
    ],
  );

  static const TerminalPalette light = TerminalPalette(
    background: Color(0xFFF7F9FB),
    foreground: Color(0xFF1B1F24),
    normal: <Color>[
      Color(0xFF4C566A),
      Color(0xFFC0392B),
      Color(0xFF1E7B3C),
      Color(0xFF9A6B00),
      Color(0xFF1D5FBF),
      Color(0xFF7B3FBF),
      Color(0xFF0E7C7B),
      Color(0xFF3B4252),
    ],
    bright: <Color>[
      Color(0xFF6B7280),
      Color(0xFFE04B3A),
      Color(0xFF2E9B4F),
      Color(0xFFB8860B),
      Color(0xFF2D74D8),
      Color(0xFF9A55D6),
      Color(0xFF159B99),
      Color(0xFF1B1F24),
    ],
  );

  static TerminalPalette of(Brightness brightness) =>
      brightness == Brightness.dark ? dark : light;

  /// Resolves an ANSI 256-colour index to a concrete colour.
  Color resolve(int index) {
    if (index < 0) return foreground;
    if (index < 8) return normal[index];
    if (index < 16) return bright[index - 8];
    if (index < 232) {
      final n = index - 16;
      final r = n ~/ 36;
      final g = (n % 36) ~/ 6;
      final b = n % 6;
      return Color.fromARGB(
        255,
        r == 0 ? 0 : 55 + r * 40,
        g == 0 ? 0 : 55 + g * 40,
        b == 0 ? 0 : 55 + b * 40,
      );
    }
    final level = 8 + (index - 232) * 10;
    return Color.fromARGB(255, level, level, level);
  }
}

/// Incremental ANSI decoder.
///
/// Feed it arbitrary chunks; it returns styled segments and keeps a partial
/// escape sequence buffered until the rest arrives. Control sequences that do
/// not affect text appearance (cursor movement, OSC titles, ...) are dropped.
class AnsiDecoder {
  String _carry = '';
  TerminalStyle _style = TerminalStyle.plain;

  void reset() {
    _carry = '';
    _style = TerminalStyle.plain;
  }

  List<TerminalSegment> decode(String chunk) {
    final data = _carry.isEmpty ? chunk : '$_carry$chunk';
    _carry = '';

    final segments = <TerminalSegment>[];
    final chars = <int>[];

    void flush() {
      if (chars.isEmpty) return;
      segments.add(
        TerminalSegment(
          String.fromCharCodes(chars),
          style: _style,
        ),
      );
      chars.clear();
    }

    var i = 0;
    while (i < data.length) {
      final code = data.codeUnitAt(i);

      if (code == 0x1B) {
        final consumed = _consumeEscape(data, i);
        if (consumed == -1) {
          // Incomplete sequence: keep the tail for the next chunk.
          _carry = data.substring(i);
          break;
        }
        flush();
        i += consumed;
        continue;
      }

      if (code == 0x07) {
        // Bell: ignore.
        i++;
        continue;
      }

      if (code == 0x08) {
        // Backspace: drop the previous character of the current run.
        if (chars.isNotEmpty) chars.removeLast();
        i++;
        continue;
      }

      chars.add(code);
      i++;
    }

    flush();
    return segments;
  }

  /// Returns the number of characters consumed, or -1 when the sequence is
  /// truncated and must be buffered.
  int _consumeEscape(String data, int start) {
    if (start + 1 >= data.length) return -1;
    final next = data.codeUnitAt(start + 1);

    if (next == 0x5B) {
      // CSI: ESC [ params... intermediates... final
      var j = start + 2;
      while (j < data.length) {
        final c = data.codeUnitAt(j);
        if (c >= 0x40 && c <= 0x7E) {
          _applyCsi(data.substring(start + 2, j), String.fromCharCode(c));
          return j - start + 1;
        }
        if (c < 0x20 || c > 0x3F) {
          // Malformed; swallow the ESC [ pair only.
          return 2;
        }
        j++;
      }
      return -1;
    }

    if (next == 0x5D) {
      // OSC: ESC ] ... (BEL | ESC \)
      var j = start + 2;
      while (j < data.length) {
        final c = data.codeUnitAt(j);
        if (c == 0x07) return j - start + 1;
        if (c == 0x1B && j + 1 < data.length && data.codeUnitAt(j + 1) == 0x5C) {
          return j - start + 2;
        }
        j++;
      }
      return -1;
    }

    // Two-character escape (ESC =, ESC >, ESC (B ...). Swallow the pair.
    return 2;
  }

  void _applyCsi(String params, String finalByte) {
    if (finalByte != 'm') return;
    if (params.isEmpty) {
      _style = TerminalStyle.plain;
      return;
    }

    final parts = params.split(';');
    var i = 0;
    while (i < parts.length) {
      final raw = parts[i];
      final value = int.tryParse(raw) ?? 0;

      switch (value) {
        case 0:
          _style = TerminalStyle.plain;
        case 1:
          _style = _style.copyWith(bold: true);
        case 2:
          _style = _style.copyWith(dim: true);
        case 3:
          _style = _style.copyWith(underline: true);
        case 7:
          _style = _style.copyWith(inverted: true);
        case 21:
        case 22:
          _style = _style.copyWith(bold: false, dim: false);
        case 23:
          _style = _style.copyWith(underline: false);
        case 27:
          _style = _style.copyWith(inverted: false);
        case 39:
          _style = _style.copyWith(clearForeground: true);
        case 49:
          _style = _style.copyWith(clearBackground: true);
        case 38:
        case 48:
          final consumed = _applyExtendedColor(parts, i, value == 38);
          i = consumed;
        default:
          if (value >= 30 && value <= 37) {
            _style = _style.copyWith(foreground: value - 30);
          } else if (value >= 90 && value <= 97) {
            _style = _style.copyWith(foreground: value - 90 + 8);
          } else if (value >= 40 && value <= 47) {
            _style = _style.copyWith(background: value - 40);
          } else if (value >= 100 && value <= 107) {
            _style = _style.copyWith(background: value - 100 + 8);
          }
      }
      i++;
    }
  }

  /// Handles `38;5;n` and `38;2;r;g;b`. Returns the index of the last consumed
  /// parameter.
  int _applyExtendedColor(List<String> parts, int index, bool isForeground) {
    if (index + 1 >= parts.length) return index;
    final mode = int.tryParse(parts[index + 1]) ?? -1;

    if (mode == 5 && index + 2 < parts.length) {
      final value = int.tryParse(parts[index + 2]);
      if (value != null) {
        _style = isForeground
            ? _style.copyWith(foreground: value)
            : _style.copyWith(background: value);
      }
      return index + 2;
    }

    if (mode == 2 && index + 4 < parts.length) {
      final r = int.tryParse(parts[index + 2]) ?? 0;
      final g = int.tryParse(parts[index + 3]) ?? 0;
      final b = int.tryParse(parts[index + 4]) ?? 0;
      // Pack the RGB triple into the 256-colour cube's nearest neighbour.
      final packed = _nearest256(r, g, b);
      _style = isForeground
          ? _style.copyWith(foreground: packed)
          : _style.copyWith(background: packed);
      return index + 4;
    }

    return index;
  }

  static int _nearest256(int r, int g, int b) {
    int quantise(int value) {
      if (value < 48) return 0;
      return ((value - 55) / 40).round().clamp(0, 5);
    }

    final index = 16 + 36 * quantise(r) + 6 * quantise(g) + quantise(b);
    return index.clamp(0, 231);
  }
}
