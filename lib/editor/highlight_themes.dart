import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:re_editor/re_editor.dart';
import 'package:re_highlight/languages/c.dart';
import 'package:re_highlight/languages/cpp.dart';
import 'package:re_highlight/languages/css.dart';
import 'package:re_highlight/languages/dart.dart';
import 'package:re_highlight/languages/java.dart';
import 'package:re_highlight/languages/javascript.dart';
import 'package:re_highlight/languages/json.dart';
import 'package:re_highlight/languages/kotlin.dart';
import 'package:re_highlight/languages/plaintext.dart';
import 'package:re_highlight/languages/python.dart';
import 'package:re_highlight/languages/xml.dart';
import 'package:re_highlight/styles/github-dark.dart';
import 'package:re_highlight/styles/vs.dart';

/// 基于 re_highlight 的语法高亮主题构建（亮色 vs / 暗色 github-dark）。
abstract final class HighlightThemes {
  static final Map<String, CodeHighlightThemeMode> _languages = {
    'dart': CodeHighlightThemeMode(mode: langDart),
    'java': CodeHighlightThemeMode(mode: langJava),
    'python': CodeHighlightThemeMode(mode: langPython),
    'c': CodeHighlightThemeMode(mode: langC),
    'cpp': CodeHighlightThemeMode(mode: langCpp),
    'kotlin': CodeHighlightThemeMode(mode: langKotlin),
    'javascript': CodeHighlightThemeMode(mode: langJavascript),
    'css': CodeHighlightThemeMode(mode: langCss),
    'xml': CodeHighlightThemeMode(mode: langXml),
    'json': CodeHighlightThemeMode(mode: langJson),
    'plaintext': CodeHighlightThemeMode(mode: langPlaintext),
  };

  /// 扩展名 → hljs 语言名。
  static const Map<String, String> _extToLang = {
    '.dart': 'dart',
    '.java': 'java',
    '.py': 'python',
    '.c': 'c',
    '.h': 'c',
    '.cpp': 'cpp',
    '.hpp': 'cpp',
    '.cc': 'cpp',
    '.cxx': 'cpp',
    '.kt': 'kotlin',
    '.kts': 'kotlin',
    '.js': 'javascript',
    '.mjs': 'javascript',
    '.ts': 'javascript',
    '.jsx': 'javascript',
    '.tsx': 'javascript',
    '.css': 'css',
    '.scss': 'css',
    '.html': 'xml',
    '.htm': 'xml',
    '.xml': 'xml',
    '.svg': 'xml',
    '.json': 'json',
  };

  /// 根据文件名与内容构造高亮主题；超大内容返回 null（纯文本渲染）。
  static CodeHighlightTheme? themeFor(
    BuildContext context,
    String fileName,
    String content,
  ) {
    final ext = p.extension(fileName).toLowerCase();
    final lang = _extToLang[ext] ?? 'plaintext';
    if (content.length > 100 * 1024) return null;
    return CodeHighlightTheme(
      languages: {lang: _languages[lang]!},
      theme: Theme.of(context).brightness == Brightness.dark
          ? githubDarkTheme
          : vsTheme,
    );
  }
}
