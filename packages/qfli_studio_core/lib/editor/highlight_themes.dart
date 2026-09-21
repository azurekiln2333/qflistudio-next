import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:re_editor/re_editor.dart';
import 'package:re_highlight/re_highlight.dart';
import 'package:re_highlight/languages/c.dart';
import 'package:re_highlight/languages/cpp.dart';
import 'package:re_highlight/languages/css.dart';
import 'package:re_highlight/languages/dart.dart';
import 'package:re_highlight/languages/java.dart';
import 'package:re_highlight/languages/javascript.dart';
import 'package:re_highlight/languages/json.dart';
import 'package:re_highlight/languages/kotlin.dart';
import 'package:re_highlight/languages/python.dart';
import 'package:re_highlight/languages/xml.dart';
import 'package:re_highlight/styles/github-dark.dart';
import 'package:re_highlight/styles/vs.dart';

import '../store/settings_store.dart';
import 'highlight_import.dart';
import 'textmate_grammar.dart';

abstract final class HighlightThemes {
  static const maxFileSize = 256 * 1024;
  static const maxLineLength = 2048;

  static final Map<String, Mode> _languages = {
    'dart': langDart,
    'java': langJava,
    'python': langPython,
    'c': langC,
    'cpp': langCpp,
    'kotlin': langKotlin,
    'javascript': langJavascript,
    'css': langCss,
    'xml': _htmlMode(),
    'json': langJson,
  };

  static const _extToLang = {
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

  static const tokenLabels = {
    'keyword': '关键字',
    'string': '字符串',
    'comment': '注释',
    'number': '数字',
    'title': '函数与类型',
    'tag': 'HTML 标签',
    'name': '标签名称',
    'attr': 'HTML 属性',
    'attribute': 'CSS 属性',
    'selector-class': 'CSS 类选择器',
    'selector-tag': 'CSS 标签选择器',
  };

  static const _tokenScopes = {
    'keyword': 'keyword.control',
    'string': 'string.quoted',
    'comment': 'comment.line',
    'number': 'constant.numeric',
    'literal': 'constant.language',
    'title': 'entity.name.function',
    'type': 'entity.name.type',
    'built_in': 'support.function',
    'tag': 'entity.name.tag',
    'name': 'entity.name.tag',
    'attr': 'entity.other.attribute-name',
    'attribute': 'support.type.property-name',
    'selector-class': 'entity.other.attribute-name.class.css',
    'selector-id': 'entity.other.attribute-name.id.css',
    'selector-tag': 'entity.name.tag.css',
    'selector-pseudo': 'entity.other.attribute-name.pseudo-class.css',
    'variable': 'variable.other',
    'params': 'variable.parameter',
    'meta': 'meta.preprocessor',
    'regexp': 'string.regexp',
  };

  static SettingsStore? _cachedSettings;
  static int _cachedRevision = -1;
  static Brightness? _cachedBrightness;
  static final Map<String, CodeHighlightTheme> _cache = {};

  static Mode _htmlMode() {
    // XML 自带的 <style>/<script> 使用自动识别列表。已知语言直接指定，
    // 同时注册两个嵌入语法，避免缺失 CSS/JS 或重复猜测整个片段。
    final mode = langXml.copyWith();
    mode.contains = [
      for (final item in (langXml.contains as List<Mode>))
        if (item.starts?.subLanguage is List &&
            (item.starts!.subLanguage as List).contains('css'))
          item.copyWith(
            Mode(starts: item.starts!.copyWith(Mode(subLanguage: 'css'))),
          )
        else if (item.starts?.subLanguage is List &&
            (item.starts!.subLanguage as List).contains('javascript'))
          item.copyWith(
            Mode(
              starts: item.starts!.copyWith(Mode(subLanguage: 'javascript')),
            ),
          )
        else
          item,
    ];
    return mode;
  }

  static Map<String, TextStyle> paletteFor(
    BuildContext context,
    SettingsStore? settings,
  ) {
    final choice = settings?.highlightTheme ?? 'system';
    final dark =
        choice == 'dark' ||
        (choice != 'light' && Theme.of(context).brightness == Brightness.dark);
    final palette = <String, TextStyle>{...(dark ? githubDarkTheme : vsTheme)};
    final imported = choice == 'custom'
        ? settings?.importedHighlightTheme
        : null;
    if (imported != null) {
      for (final entry in _tokenScopes.entries) {
        palette[entry.key] = imported.styleFor(
          entry.value,
          palette[entry.key] ?? const TextStyle(),
        );
      }
      palette['root'] = (palette['root'] ?? const TextStyle()).copyWith(
        color: _color(imported.editorColors['editor.foreground']),
        backgroundColor: _color(imported.editorColors['editor.background']),
      );
    }
    for (final entry
        in settings?.highlightColors.entries ?? <MapEntry<String, String>>[]) {
      palette[entry.key] = (palette[entry.key] ?? const TextStyle()).copyWith(
        color: parseHighlightColor(entry.value),
      );
    }
    return palette;
  }

  static Color? editorColor(SettingsStore settings, String key) {
    if (settings.highlightTheme != 'custom') return null;
    return _color(settings.importedHighlightTheme?.editorColors[key]);
  }

  static Color? _color(String? value) =>
      value == null ? null : parseHighlightColor(value);

  /// 内容只用于独立预览的限制检查。编辑器传 null，由 worker 检查 CodeLines，
  /// 避免在 UI build 中重复拼接整份源码。
  static CodeHighlightTheme? themeFor(
    BuildContext context,
    String fileName,
    String? content, {
    SettingsStore? settings,
  }) {
    if (settings?.syntaxHighlighting == false) return null;
    if (content != null &&
        (content.length > maxFileSize || _hasLongLine(content))) {
      return null;
    }
    final brightness = Theme.of(context).brightness;
    final revision = settings?.highlightRevision ?? 0;
    if (!identical(settings, _cachedSettings) ||
        _cachedRevision != revision ||
        _cachedBrightness != brightness) {
      _cache.clear();
      _cachedSettings = settings;
      _cachedRevision = revision;
      _cachedBrightness = brightness;
    }
    TextMateGrammar? grammar;
    if (settings?.textMateEnabled == true) {
      for (final candidate in settings!.customGrammars) {
        if (candidate.matchesFile(fileName)) {
          grammar = candidate;
          break;
        }
      }
    }
    final language =
        grammar?.scopeName ?? _extToLang[p.extension(fileName).toLowerCase()];
    if (language == null) return null;
    final cacheKey = grammar == null ? language : 'tm:$language';
    if (_cache[cacheKey] case final cached?) return cached;
    final palette = paletteFor(context, settings);
    final modes = <String, CodeHighlightThemeMode>{};
    void register(String key, Mode mode) {
      modes[key] = CodeHighlightThemeMode(
        mode: mode,
        maxSize: maxFileSize,
        maxLineLength: maxLineLength,
      );
    }

    if (grammar != null) {
      register(language, grammar.mode);
      for (final entry in grammar.scopes.entries) {
        final token = _tokenForScope(entry.value);
        var style = palette[token] ?? palette['root'] ?? const TextStyle();
        if (settings!.highlightTheme == 'custom') {
          style = settings.importedHighlightTheme!.styleFor(entry.value, style);
        }
        // 手动调色优先于导入配色。
        final override = settings.highlightColors[token];
        if (override != null) {
          style = style.copyWith(color: parseHighlightColor(override));
        }
        palette[entry.key] = style.copyWith(
          backgroundColor: Colors.transparent,
        );
      }
    } else {
      register(language, _languages[language]!);
      if (language == 'xml') {
        register('css', _languages['css']!);
        register('javascript', _languages['javascript']!);
      }
    }
    return _cache[cacheKey] = CodeHighlightTheme(
      languages: modes,
      language: language,
      theme: palette,
    );
  }

  static String _tokenForScope(String scope) {
    if (scope.startsWith('comment')) return 'comment';
    if (scope.startsWith('string')) return 'string';
    if (scope.startsWith('constant.numeric')) return 'number';
    if (scope.startsWith('constant')) return 'literal';
    if (scope.startsWith('keyword') || scope.startsWith('storage')) {
      return 'keyword';
    }
    if (scope.startsWith('entity.name.tag')) return 'name';
    if (scope.startsWith('entity.other.attribute-name')) return 'attr';
    if (scope.startsWith('entity.name')) return 'title';
    if (scope.startsWith('support.type.property-name')) return 'attribute';
    if (scope.startsWith('support')) return 'built_in';
    if (scope.startsWith('variable')) return 'variable';
    return 'root';
  }

  static bool _hasLongLine(String content) {
    var start = 0;
    for (var index = 0; index < content.length; index++) {
      if (content.codeUnitAt(index) == 10) start = index + 1;
      if (index - start >= maxLineLength) return true;
    }
    return false;
  }
}
