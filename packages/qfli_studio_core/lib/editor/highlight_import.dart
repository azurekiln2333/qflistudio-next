import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:xml/xml.dart';

const maxHighlightImportSize = 512 * 1024;

/// JSON / JSONC，保留字符串内的 URL、转义和注释字符。
Map<String, dynamic> decodeHighlightJson(String source) {
  if (utf8.encode(source).length > maxHighlightImportSize) {
    throw const FormatException('高亮配置不能超过 512 KB');
  }
  final output = StringBuffer();
  var quoted = false;
  var escaped = false;
  for (var i = 0; i < source.length; i++) {
    final ch = source[i];
    if (quoted) {
      output.write(ch);
      if (escaped) {
        escaped = false;
      } else if (ch == r'\') {
        escaped = true;
      } else if (ch == '"') {
        quoted = false;
      }
      continue;
    }
    if (ch == '"') {
      quoted = true;
    } else if (ch == '/' && i + 1 < source.length) {
      if (source[i + 1] == '/') {
        while (i + 1 < source.length && source[i + 1] != '\n') {
          i++;
        }
        output.write(' ');
        continue;
      }
      if (source[i + 1] == '*') {
        final end = source.indexOf('*/', i + 2);
        if (end < 0) throw const FormatException('JSON 注释未闭合');
        i = end + 1;
        output.write(' ');
        continue;
      }
    }
    output.write(ch);
  }
  final clean = output.toString().replaceFirst('\uFEFF', '');
  final withoutTrailingCommas = StringBuffer();
  quoted = false;
  escaped = false;
  for (var i = 0; i < clean.length; i++) {
    final ch = clean[i];
    if (!quoted && ch == ',') {
      var next = i + 1;
      while (next < clean.length && clean[next].trim().isEmpty) {
        next++;
      }
      if (next < clean.length && (clean[next] == '}' || clean[next] == ']')) {
        continue;
      }
    }
    withoutTrailingCommas.write(ch);
    if (quoted && escaped) {
      escaped = false;
    } else if (quoted && ch == r'\') {
      escaped = true;
    } else if (ch == '"') {
      quoted = !quoted;
    }
  }
  final data = jsonDecode(withoutTrailingCommas.toString());
  if (data is! Map<String, dynamic>) {
    throw const FormatException('配置根节点必须是 JSON 对象');
  }
  return data;
}

Color parseHighlightColor(String value) {
  var hex = value.trim().replaceFirst(RegExp(r'^#'), '');
  if (!RegExp(r'^[0-9a-fA-F]+$').hasMatch(hex) ||
      ![3, 4, 6, 8].contains(hex.length)) {
    throw FormatException('颜色应为 #RGB、#RGBA、#RRGGBB 或 #RRGGBBAA：$value');
  }
  if (hex.length <= 4) hex = hex.split('').map((ch) => '$ch$ch').join();
  if (hex.length == 6) return Color(0xFF000000 | int.parse(hex, radix: 16));
  final rgba = int.parse(hex, radix: 16);
  return Color(((rgba & 0xFF) << 24) | (rgba >> 8));
}

class HighlightScopeRule {
  const HighlightScopeRule(this.scopes, this.foreground, this.fontStyle);

  final List<String> scopes;
  final String? foreground;
  final String? fontStyle;

  TextStyle get style => TextStyle(
    color: foreground == null ? null : parseHighlightColor(foreground!),
    fontWeight: fontStyle == null
        ? null
        : fontStyle!.contains('bold')
        ? FontWeight.bold
        : FontWeight.normal,
    fontStyle: fontStyle == null
        ? null
        : fontStyle!.contains('italic')
        ? FontStyle.italic
        : FontStyle.normal,
    decoration: fontStyle == null
        ? null
        : TextDecoration.combine([
            if (fontStyle!.contains('underline')) TextDecoration.underline,
            if (fontStyle!.contains('strikethrough'))
              TextDecoration.lineThrough,
          ]),
  );
}

/// 导入 TextMate .tmTheme (plist) 或 VS Code tokenColors JSON / JSONC。
/// 保留源文件以便重启恢复，不访问主题中引用的外部文件。
class ImportedHighlightTheme {
  const ImportedHighlightTheme({
    required this.name,
    required this.source,
    required this.editorColors,
    required this.rules,
  });

  final String name;
  final String source;
  final Map<String, String> editorColors;
  final List<HighlightScopeRule> rules;

  static ImportedHighlightTheme parse(String source, {String name = '自定义配色'}) {
    if (utf8.encode(source).length > maxHighlightImportSize) {
      throw const FormatException('主题文件不能超过 512 KB');
    }
    final Map<String, dynamic> data;
    if (source.trimLeft().startsWith('<')) {
      try {
        final document = XmlDocument.parse(source);
        final root = document.rootElement;
        final value = _plistValue(
          root.name.local == 'plist' ? root.childElements.first : root,
        );
        if (value is! Map<String, dynamic>) {
          throw const FormatException('主题 plist 根节点应为 dict');
        }
        data = value;
      } on XmlException catch (error) {
        throw FormatException('无法读取 TextMate 主题：${error.message}');
      }
    } else {
      data = decodeHighlightJson(source);
    }
    if (data['include'] != null) {
      throw const FormatException('请先合并主题的 include 文件后导入');
    }
    final colors = <String, String>{};
    final colorData = data['colors'];
    if (colorData is Map) {
      for (final key in const [
        'editor.foreground',
        'editor.background',
        'editorCursor.foreground',
        'editor.selectionBackground',
        'editor.lineHighlightBackground',
      ]) {
        final value = colorData[key];
        if (value is String) {
          parseHighlightColor(value);
          colors[key] = value;
        }
      }
    }
    final entries = data['tokenColors'] ?? data['settings'];
    if (entries is! List) {
      throw const FormatException('主题需要 tokenColors 或 TextMate settings 数组');
    }
    if (entries.length > 2048) throw const FormatException('主题规则不能超过 2048 条');
    final rules = <HighlightScopeRule>[];
    for (final entry in entries) {
      if (entry is! Map || entry['settings'] is! Map) {
        throw const FormatException('每条配色规则都需要 settings 对象');
      }
      final settings = entry['settings'] as Map;
      final foreground = settings['foreground'];
      if (foreground != null && foreground is! String) {
        throw const FormatException('foreground 必须是颜色字符串');
      }
      if (foreground is String) parseHighlightColor(foreground);
      final scope = entry['scope'];
      if (scope == null || scope == '') {
        for (final pair in const {
          'foreground': 'editor.foreground',
          'background': 'editor.background',
          'caret': 'editorCursor.foreground',
          'selection': 'editor.selectionBackground',
          'lineHighlight': 'editor.lineHighlightBackground',
        }.entries) {
          final value = settings[pair.key];
          if (value is String) {
            parseHighlightColor(value);
            colors[pair.value] = value;
          }
        }
      }
      final scopes = scope is List
          ? scope.cast<String>().expand((item) => item.split(',')).toList()
          : scope is String
          ? scope.split(',')
          : <String>[];
      rules.add(
        HighlightScopeRule(
          scopes
              .map((item) => item.trim())
              .where((item) => item.isNotEmpty)
              .toList(),
          foreground as String?,
          settings['fontStyle'] as String?,
        ),
      );
    }
    return ImportedHighlightTheme(
      name: data['name'] as String? ?? name,
      source: source,
      editorColors: colors,
      rules: rules,
    );
  }

  TextStyle styleFor(String scope, TextStyle fallback) {
    final matches = <({int specificity, int order, TextStyle style})>[];
    for (var i = 0; i < rules.length; i++) {
      final rule = rules[i];
      var specificity = rule.scopes.isEmpty ? 0 : -1;
      for (final selector in rule.scopes) {
        // 只匹配单一 scope；父作用域选择器需要完整 TextMate token 栈。
        if (scope == selector || scope.startsWith('$selector.')) {
          if (selector.length > specificity) specificity = selector.length;
        }
      }
      if (specificity >= 0) {
        matches.add((specificity: specificity, order: i, style: rule.style));
      }
    }
    matches.sort((a, b) {
      final order = a.specificity.compareTo(b.specificity);
      return order == 0 ? a.order.compareTo(b.order) : order;
    });
    var style = fallback;
    for (final match in matches) {
      style = style.merge(match.style);
    }
    return style;
  }

  static dynamic _plistValue(XmlElement node, [int depth = 0]) {
    if (depth > 40) throw const FormatException('plist 嵌套过深');
    switch (node.name.local) {
      case 'dict':
        final children = node.childElements.toList();
        if (children.length.isOdd) throw const FormatException('plist 字典缺少值');
        final result = <String, dynamic>{};
        for (var i = 0; i < children.length; i += 2) {
          if (children[i].name.local != 'key') {
            throw const FormatException('plist 字典缺少 key');
          }
          result[children[i].innerText] = _plistValue(
            children[i + 1],
            depth + 1,
          );
        }
        return result;
      case 'array':
        return node.childElements
            .map((child) => _plistValue(child, depth + 1))
            .toList();
      case 'string':
        return node.innerText;
      case 'true':
        return true;
      case 'false':
        return false;
      case 'integer':
        return int.parse(node.innerText);
      default:
        throw FormatException('不支持的 plist 节点：${node.name.local}');
    }
  }
}
