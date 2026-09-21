import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:qfli_studio_core/editor/highlight_import.dart';
import 'package:qfli_studio_core/editor/highlight_themes.dart';
import 'package:qfli_studio_core/editor/textmate_grammar.dart';
import 'package:qfli_studio_core/store/settings_store.dart';
import 'package:re_highlight/re_highlight.dart';

const sampleGrammar = r'''{
  "name": "Demo language",
  "scopeName": "source.demo",
  "fileTypes": ["demo"],
  "patterns": [
    {"include": "#strings"},
    {"name": "comment.line.demo", "match": "//.*$"},
    {"name": "keyword.control.demo", "match": "\\b(let|return)\\b"},
    {"name": "constant.numeric.demo", "match": "\\b[0-9]+\\b"}
  ],
  "repository": {
    "strings": {"name": "string.quoted.double.demo", "begin": "\"", "end": "\""}
  }
}''';

const sampleTheme = r'''{
  // 注释不能破坏 URL 或转义
  "name": "Sample theme",
  "url": "https://example.com/a//b",
  "colors": {"editor.background": "#112233", "editor.foreground": "#ddeeff",},
  "tokenColors": [
    {"scope": "keyword.control", "settings": {"foreground": "#abcdef", "fontStyle": "bold"}},
    {"scope": ["string", "comment"], "settings": {"foreground": "#33bb55"}},
  ],
}''';

class _Tokens implements HighlightRenderer {
  final parts = <({String text, String? scope})>[];
  final scopes = <String?>[];
  @override
  void addText(String text) =>
      parts.add((text: text, scope: scopes.isEmpty ? null : scopes.last));
  @override
  void openNode(DataNode node) =>
      scopes.add(node.scope ?? (scopes.isEmpty ? null : scopes.last));
  @override
  void closeNode(DataNode node) => scopes.removeLast();
}

void main() {
  test('JSONC 和颜色解析保留字符串内容，RGBA 顺序正确', () {
    final data = decodeHighlightJson(sampleTheme);
    expect(data['url'], 'https://example.com/a//b');
    expect(parseHighlightColor('#123').toARGB32(), 0xff112233);
    expect(parseHighlightColor('#11223344').toARGB32(), 0x44112233);
    expect(() => parseHighlightColor('#xyz'), throwsFormatException);
    final theme = ImportedHighlightTheme.parse(sampleTheme);
    final keyword = theme.styleFor('keyword.control.demo', const TextStyle());
    expect(keyword.color, const Color(0xffabcdef));
    expect(keyword.fontWeight, FontWeight.bold);
  });

  test('TextMate plist 配色含背景、作用域与字体样式', () {
    final theme = ImportedHighlightTheme.parse('''<?xml version="1.0"?>
      <plist version="1.0"><dict><key>name</key><string>Ocean</string>
      <key>settings</key><array>
        <dict><key>settings</key><dict><key>background</key><string>#001122</string></dict></dict>
        <dict><key>scope</key><string>comment, string</string><key>settings</key><dict>
          <key>foreground</key><string>#00ccaa</string><key>fontStyle</key><string>italic</string>
        </dict></dict>
      </array></dict></plist>''');
    expect(theme.name, 'Ocean');
    expect(theme.editorColors['editor.background'], '#001122');
    expect(
      theme.styleFor('comment.line', const TextStyle()).fontStyle,
      FontStyle.italic,
    );
  });

  test('TextMate 基础规则正确处理 include、关键字与跨行字符串', () {
    final grammar = TextMateGrammar.parse(sampleGrammar);
    expect(grammar.matchesFile('hello.DEMO'), isTrue);
    final highlighter = Highlight()
      ..debugMode()
      ..registerLanguage(grammar.scopeName, grammar.mode);
    const source = 'let title = "line one\nline two"; // note\nreturn 42';
    final renderer = _Tokens();
    highlighter
        .highlight(code: source, language: grammar.scopeName)
        .render(renderer);
    expect(renderer.parts.map((part) => part.text).join(), source);
    expect(
      renderer.parts.any(
        (part) =>
            part.text == 'let' &&
            grammar.scopes[part.scope] == 'keyword.control.demo',
      ),
      isTrue,
    );
    expect(
      renderer.parts.any(
        (part) =>
            part.text.contains('line two') &&
            grammar.scopes[part.scope] == 'string.quoted.double.demo',
      ),
      isTrue,
    );
    expect(
      renderer.parts.any(
        (part) =>
            part.text == '42' &&
            grammar.scopes[part.scope] == 'constant.numeric.demo',
      ),
      isTrue,
    );
  });

  test('不支持的语法与损坏的导入文件明确拒绝', () {
    expect(
      () => TextMateGrammar.parse(r'''{
      "scopeName":"source.bad", "fileTypes":["bad"],
      "patterns":[{"name":"keyword","match":"(?i)hello"}]
    }'''),
      throwsFormatException,
    );
    expect(
      () => TextMateGrammar.parse(r'''{
      "scopeName":"source.bad", "fileTypes":["bad"],
      "patterns":[{"match":"(abc)","captures":{"1":{"name":"keyword"}}}]
    }'''),
      throwsFormatException,
    );
    expect(
      () => TextMateGrammar.parse(r'''{
      "scopeName":"source.bad", "fileTypes":["bad"],
      "patterns":[{"include":"#loop"}], "repository":{"loop":{"include":"#loop"}}
    }'''),
      throwsFormatException,
    );
    expect(
      () => ImportedHighlightTheme.parse('{"include":"other.json"}'),
      throwsFormatException,
    );
    expect(
      () => decodeHighlightJson(' ' * (maxHighlightImportSize + 1)),
      throwsFormatException,
    );
  });

  test('高亮设置持久化，导入失败不会覆盖现有配置', () async {
    final directory = await Directory.systemTemp.createTemp('qfli_highlight_');
    addTearDown(() => directory.delete(recursive: true));
    final file = File(p.join(directory.path, 'settings.json'));
    final settings = SettingsStore(storageFile: file);
    addTearDown(settings.dispose);
    await settings.load();
    await settings.importHighlightTheme(sampleTheme);
    await settings.importTextMateGrammar(sampleGrammar);
    await settings.setHighlightColor('keyword', '#ff2255');
    await settings.setThemeMode('dark');
    await expectLater(
      settings.importTextMateGrammar('{broken'),
      throwsFormatException,
    );
    expect(settings.customGrammars, hasLength(1));
    final restored = SettingsStore(storageFile: file);
    addTearDown(restored.dispose);
    await restored.load();
    expect(restored.highlightTheme, 'custom');
    expect(restored.importedHighlightTheme!.name, 'Sample theme');
    expect(restored.customGrammars.single.fileTypes, ['demo']);
    expect(restored.highlightColors['keyword'], '#ff2255');
    expect(restored.themeModeValue, ThemeMode.dark);
    await restored.removeTextMateGrammar('source.demo');
    await restored.removeHighlightTheme();
    expect(restored.customGrammars, isEmpty);
    expect(restored.highlightTheme, 'system');
  });

  testWidgets('HTML 明确注册 CSS/JS，嵌入片段真正参与高亮', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: SizedBox())),
    );
    final context = tester.element(find.byType(Scaffold));
    final theme = HighlightThemes.themeFor(context, 'index.html', null)!;
    expect(theme.language, 'xml');
    final highlighter = Highlight()
      ..debugMode()
      ..registerLanguages(
        theme.languages.map((name, language) => MapEntry(name, language.mode)),
      );
    const source =
        '<style>.hello { color: red; }</style><script>const x = 1;</script>';
    final renderer = _Tokens();
    highlighter
        .highlight(code: source, language: theme.language!)
        .render(renderer);
    expect(renderer.parts.map((part) => part.text).join(), source);
    expect(
      renderer.parts.any(
        (part) => part.text == 'const' && part.scope == 'keyword',
      ),
      isTrue,
    );
    expect(
      renderer.parts.any(
        (part) => part.text == 'color' && part.scope == 'attribute',
      ),
      isTrue,
    );
  });

  testWidgets('自定义语法、颜色优先级与大文件保护', (tester) async {
    final settings = SettingsStore();
    addTearDown(settings.dispose);
    settings.customGrammars = [TextMateGrammar.parse(sampleGrammar)];
    settings.importedHighlightTheme = ImportedHighlightTheme.parse(sampleTheme);
    settings.highlightTheme = 'custom';
    await settings.setHighlightColor('keyword', '#ff2255');
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: SizedBox())),
    );
    final context = tester.element(find.byType(Scaffold));
    final theme = HighlightThemes.themeFor(
      context,
      'file.demo',
      null,
      settings: settings,
    )!;
    expect(theme.language, 'source.demo');
    final keyword = settings.customGrammars.single.scopes.entries
        .firstWhere((entry) => entry.value == 'keyword.control.demo')
        .key;
    expect(theme.theme[keyword]!.color, const Color(0xffff2255));
    expect(theme.theme['root']!.backgroundColor, const Color(0xff112233));
    expect(HighlightThemes.themeFor(context, 'a.css', 'x' * 2049), isNull);
    expect(
      HighlightThemes.themeFor(context, 'a.html', '<p>x</p>\n' * 35000),
      isNull,
    );
    await settings.setTextMateEnabled(false);
    expect(
      HighlightThemes.themeFor(context, 'file.demo', null, settings: settings),
      isNull,
    );
    await settings.setSyntaxHighlighting(false);
    expect(
      HighlightThemes.themeFor(context, 'file.dart', null, settings: settings),
      isNull,
    );
  });
}
