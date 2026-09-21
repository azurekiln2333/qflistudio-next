import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import 'package:qfli_studio_core/services/ai_service.dart';
import 'package:qfli_studio_core/editor/project_history.dart';
import 'package:qfli_studio_core/editor/file_explorer.dart';
import 'package:qfli_studio_core/services/file_encoding.dart';
import 'package:qfli_studio_core/editor/symbols_bar.dart';
import 'package:qfli_studio_core/editor/new_file_dialog.dart';
import 'package:qfli_studio_core/editor/editor_controller.dart';
import 'package:qfli_studio_core/models/project.dart';
import 'package:qfli_studio_core/store/settings_store.dart';

void main() {
  test('endpoint：各种接口地址写法', () {
    expect(
      AiService.endpoint('https://api.deepseek.com'),
      'https://api.deepseek.com/v1/chat/completions',
    );
    expect(
      AiService.endpoint('https://api.deepseek.com/v1'),
      'https://api.deepseek.com/v1/chat/completions',
    );
    expect(
      AiService.endpoint('https://x.com/v1/chat/completions'),
      'https://x.com/v1/chat/completions',
    );
    expect(
      AiService.endpoint('http://127.0.0.1:11434/v1/'),
      'http://127.0.0.1:11434/v1/chat/completions',
    );
  });

  test('parseSegments：带路径的代码块', () {
    final segments = AiService.parseSegments(
      '给你主文件：\n```python:src/main.py\nprint(1)\n```\n完成。',
    );
    expect(segments.length, 3);
    expect(segments[0].isCode, isFalse);
    expect(segments[1].isCode, isTrue);
    expect(segments[1].path, 'src/main.py');
    expect(segments[1].lang, 'python');
    expect(segments[1].code!.trim(), 'print(1)');
    expect(segments[2].isCode, isFalse);
  });

  test('parseSegments：无路径与未闭合代码块', () {
    final s1 = AiService.parseSegments('```js\nlet a = 1;\n```');
    expect(s1.single.isCode, isTrue);
    expect(s1.single.path, isNull);
    expect(s1.single.lang, 'js');

    final s2 = AiService.parseSegments('```dart:src/a.dart\nvoid main() {}');
    expect(s2.single.isCode, isTrue);
    expect(s2.single.path, 'src/a.dart');
  });

  test('parseSegments：栅栏仅扩展名时视为路径', () {
    final s = AiService.parseSegments('```main.py\nprint(1)\n```');
    expect(s.single.isCode, isTrue);
    expect(s.single.path, 'main.py');
  });

  test('SettingsStore：AI 字段持久化', () async {
    final dir = await Directory.systemTemp.createTemp('qfli_settings');
    final store = SettingsStore(
      storageFile: File(p.join(dir.path, 'settings.json')),
    );
    await store.load();
    await store.saveAi(
      baseUrl: 'https://api.test.com',
      apiKey: 'sk-abc',
      model: 'test-model',
    );
    final reloaded = SettingsStore(
      storageFile: File(p.join(dir.path, 'settings.json')),
    );
    await reloaded.load();
    expect(reloaded.aiBaseUrl, 'https://api.test.com');
    expect(reloaded.aiApiKey, 'sk-abc');
    expect(reloaded.aiModel, 'test-model');
    await dir.delete(recursive: true);
  });



  test('ProjectHistory：保存/加载往返', () async {
    final dir = await Directory.systemTemp.createTemp('qfli_history');
    final projectPath = p.join(dir.path, 'proj');
    await Directory(projectPath).create(recursive: true);
    await ProjectHistory.save(
      projectPath,
      cursors: {
        'src/main.py': const FileCursor(
          baseIndex: 3,
          baseOffset: 6,
          extentIndex: 3,
          extentOffset: 10,
        ),
      },
      openFiles: ['src/main.py'],
      activeFile: 'src/main.py',
    );
    final session = await ProjectHistory.load(projectPath);
    expect(session.openFiles, ['src/main.py']);
    expect(session.activeFile, 'src/main.py');
    final cursor = session.cursors['src/main.py'];
    expect(cursor!.baseIndex, 3);
    expect(cursor.baseOffset, 6);
    await dir.delete(recursive: true);
  });

  test('EditorController：打开文件按历史光标定位（越界钳制）', () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    final dir = await Directory.systemTemp.createTemp('qfli_cursor');
    final projectPath = p.join(dir.path, 'proj');
    final src = Directory(p.join(projectPath, 'src'))
      ..createSync(recursive: true);
    final file = File(p.join(src.path, 'a.txt'))
      ..writeAsStringSync('l1\nl2\nl3\nl4');
    final controller = EditorController(
      project: Project.create(name: 'proj', path: projectPath),
    );
    // 历史：第 99 行（越界）→ 应钳制到最后一行；偏移 0
    await controller.openPath(
      file.path,
      cursor: const FileCursor(
        baseIndex: 99,
        baseOffset: 0,
        extentIndex: 99,
        extentOffset: 0,
      ),
    );
    final sel = controller.current!.controller.selection;
    expect(sel.baseIndex, 3);
    expect(sel.baseOffset, 0);
    controller.dispose();
    await dir.delete(recursive: true);
  });


  test('文件搜索：递归匹配并跳过 build 目录', () async {
    final dir = await Directory.systemTemp.createTemp('qfli_search');
    final root = p.join(dir.path, 'proj');
    Directory(p.join(root, 'src')).createSync(recursive: true);
    Directory(p.join(root, 'build')).createSync(recursive: true);
    File(p.join(root, 'src', 'MainClass.py')).writeAsStringSync('x');
    File(p.join(root, 'README.md')).writeAsStringSync('x');
    File(p.join(root, 'build', 'output.py')).writeAsStringSync('x');

    final results = FileExplorer.searchFiles(root, 'mainclass');
    expect(results.length, 1);
    expect(results.first.name, 'MainClass.py');
    // 大小写不敏感 + 无结果
    expect(FileExplorer.searchFiles(root, 'MAINCLASS').length, 1);
    expect(FileExplorer.searchFiles(root, 'zzz'), isEmpty);
    await dir.delete(recursive: true);
  });

  test('orderedExts：项目语言置顶 + 自定义次之', () {
    final exts = orderedExts(
      projectLanguage: 'Python',
      customExts: ['.myext'],
    );
    expect(exts.first, '.py');
    expect(exts[1], '.myext');
    expect(exts.contains('.java'), isTrue);
  });

  test('SettingsStore：自定义后缀持久化', () async {
    final dir = await Directory.systemTemp.createTemp('qfli_exts');
    final s1 = SettingsStore(
      storageFile: File(p.join(dir.path, 'settings.json')),
    );
    await s1.load();
    await s1.addCustomFileExt('md');
    await s1.addCustomFileExt('.proto');
    final s2 = SettingsStore(
      storageFile: File(p.join(dir.path, 'settings.json')),
    );
    await s2.load();
    expect(s2.customFileExts, contains('.md'));
    expect(s2.customFileExts, contains('.proto'));
    await dir.delete(recursive: true);
  });


  test('文件编码：识别与按编码编解码往返', () {
    // UTF-8 中文
    final utf8Bytes = utf8.encode('你好 world');
    expect(TextCodec.detect(utf8Bytes), 'UTF-8');
    expect(TextCodec.byName('UTF-8').decode(utf8Bytes), '你好 world');
    // GBK 中文（fast_gbk 编码）
    final gbkBytes = TextCodec.gbk.encode('你好');
    expect(TextCodec.detect(gbkBytes), 'GBK');
    expect(TextCodec.gbk.decode(gbkBytes), '你好');
    // Latin-1
    final l1 = TextCodec.latin1.encode('café');
    expect(TextCodec.latin1.decode(l1), 'café');
    // UTF-16 LE BOM
    expect(TextCodec.detect([0xFF, 0xFE, 0x41, 0x00]), 'UTF-16 LE');
  });

  test('快捷符号：语言默认集存在且互不相同', () {
    expect(kDefaultSymbolSets['Python'], contains('#'));
    expect(kDefaultSymbolSets['HTML'], contains('<'));
    expect(kDefaultSymbolSets['JSON'], contains(':'));
    expect(languageForFileName('main.py'), 'Python');
    expect(languageForFileName('index.html'), 'Web');
    expect(languageForFileName('unknown.xyz'), '');
  });
}
