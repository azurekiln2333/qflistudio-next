import 'dart:convert';

import 'package:path/path.dart' as p;

/// 代码格式化结果。
class FormatResult {
  const FormatResult({required this.text, required this.changed});

  final String text;
  final bool changed;
}

/// 轻量代码格式化：
/// - JSON：完整解析后按 2 空格缩进重排（键序保留）。
/// - C-like（java/c/cpp/js/ts/cs/dart/kt/go/rs/css）：按花括号深度重缩进，
///   `{` 保留行尾、`}` 独立成行（K&R 风格），字符串/注释内的括号不参与统计。
/// - 其他（含 Python、HTML 等）：仅清理空白（行尾空格、3+ 连续空行、文件末尾换行）。
abstract final class CodeFormatter {
  static const Set<String> _cLikeExts = {
    '.java', '.c', '.h', '.cpp', '.hpp', '.cc', '.cxx', '.cs', '.js', '.mjs',
    '.ts', '.jsx', '.tsx', '.dart', '.kt', '.kts', '.go', '.rs', '.css',
    '.scss', '.less', '.php', '.swift', '.scala',
  };

  static FormatResult format(String fileName, String text) {
    final ext = p.extension(fileName).toLowerCase();
    if (ext == '.json') {
      return _formatJson(text);
    }
    if (_cLikeExts.contains(ext)) {
      return _reindentBraces(text);
    }
    return _cleanup(text);
  }

  /// JSON 格式化；解析失败返回原文并标记 changed=false。
  static FormatResult _formatJson(String text) {
    try {
      final decoded = jsonDecode(text);
      const encoder = JsonEncoder.withIndent('  ');
      var out = encoder.convert(decoded);
      if (!out.endsWith('\n')) out += '\n';
      return FormatResult(text: out, changed: out != text);
    } on FormatException {
      return FormatResult(text: text, changed: false);
    }
  }

  /// C-like 花括号重缩进。
  static FormatResult _reindentBraces(String text) {
    final out = StringBuffer();
    var depth = 0;
    var inLineComment = false;
    var inBlockComment = false;
    String? stringChar;

    // 当前行是否尚未写出可见字符（需要写缩进）。
    var atLineStart = true;
    // 刚写过 { 或 }，下一个可见字符前应换行。
    var pendingNewline = false;

    void writeIndent() {
      out.write('  ' * depth);
      atLineStart = false;
    }

    void breakLine() {
      out.write('\n');
      atLineStart = true;
      pendingNewline = false;
    }

    void writeVisible(String s) {
      if (atLineStart) writeIndent();
      out.write(s);
    }

    for (var i = 0; i < text.length; i++) {
      final ch = text[i];
      final next = i + 1 < text.length ? text[i + 1] : '';

      if (inLineComment) {
        if (ch == '\n') {
          inLineComment = false;
          breakLine();
        } else {
          out.write(ch);
        }
        continue;
      }
      if (inBlockComment) {
        out.write(ch);
        if (ch == '*' && next == '/') {
          out.write(next);
          i++;
          inBlockComment = false;
        }
        continue;
      }
      if (stringChar != null) {
        out.write(ch);
        if (ch == r'\' && next.isNotEmpty) {
          out.write(next);
          i++;
        } else if (ch == stringChar) {
          stringChar = null;
        }
        continue;
      }

      switch (ch) {
        case '\n':
          breakLine();
        case ' ':
        case '\t':
        case '\r':
          // 缩进统一由 writeIndent 生成，行内必要空格保留。
          if (!atLineStart && !pendingNewline) out.write(ch);
        case '{':
        case '[':
          if (pendingNewline) breakLine();
          writeVisible(ch);
          depth++;
          pendingNewline = true;
        case '}':
        case ']':
          if (depth > 0) depth--;
          if (!atLineStart) {
            out.write('\n');
            atLineStart = true;
          }
          writeIndent();
          out.write(ch);
          pendingNewline = true;
        case '/':
          if (pendingNewline) breakLine();
          if (next == '/') {
            writeVisible('//');
            i++;
            inLineComment = true;
          } else if (next == '*') {
            writeVisible('/*');
            i++;
            inBlockComment = true;
          } else {
            writeVisible(ch);
          }
        case '"':
        case "'":
        case '`':
          if (pendingNewline) breakLine();
          writeVisible(ch);
          stringChar = ch;
        default:
          if (pendingNewline) breakLine();
          writeVisible(ch);
      }
    }

    var result = out.toString();
    result = _collapseBlankLines(result);
    return FormatResult(text: result, changed: result != text);
  }

  /// 通用空白清理（Python/HTML/文本等不做结构重排）。
  static FormatResult _cleanup(String text) {
    var result = text.split('\n')
        .map((line) => line.replaceFirst(RegExp(r'[ \t]+$'), ''))
        .join('\n');
    result = _collapseBlankLines(result);
    return FormatResult(text: result, changed: result != text);
  }

  static String _collapseBlankLines(String text) {
    var result = text.replaceAll(RegExp(r'\n{3,}'), '\n\n');
    if (result.isNotEmpty && !result.endsWith('\n')) result += '\n';
    return result;
  }
}
