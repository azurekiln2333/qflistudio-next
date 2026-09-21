import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:qfli_note/main.dart' show noteProfile;
import 'package:qfli_studio_core/services/project_templates.dart';
import 'package:qfli_studio_core/services/runner_service.dart';
import 'package:qfli_studio_core/services/studio_profile.dart';

/// Markdown 版 App 的接线测试。
///
/// 覆盖的正是「一个语言一个 App」的全部接缝：内核怎么知道该显示哪个模板、
/// 该跑哪个入口文件、以及运行后端有没有正确接管/交回。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory project;
  late StudioProfile? previousProfile;

  setUp(() {
    previousProfile = StudioProfile.current;
    StudioProfile.current = noteProfile;
    project = Directory.systemTemp.createTempSync('qfli_note_app_test');
  });

  tearDown(() {
    StudioProfile.current = previousProfile;
    if (project.existsSync()) project.deleteSync(recursive: true);
  });

  void write(String relative, String content) {
    final file = File(p.join(project.path, relative));
    file.parent.createSync(recursive: true);
    file.writeAsStringSync(content);
  }

  group('档位收窄', () {
    test('新建项目只放行「空项目」和 Markdown', () {
      expect(
        noteProfile.filterTemplates(ProjectTemplate.values),
        [ProjectTemplate.empty, ProjectTemplate.markdown],
      );
    });

    test('默认模板是 Markdown 而不是空项目', () {
      expect(noteProfile.defaultTemplate,
          ProjectTemplate.markdown);
    });

    test('语言筛选芯片只剩 Markdown', () {
      // 首页传给档位的候选本来就不含「空项目」——它不是一门语言。
      const all = ['Rust', 'Go', 'SQL', 'JSON', 'Markdown', 'C++', 'Lua', 'Web', 'Python', 'Java', 'Dart'];
      expect(noteProfile.filterLanguages(all), ['Markdown']);
    });

    test('产品名带 Markdown 版后缀', () {
      expect(noteProfile.appTitle, 'QFLINote');
    });

    test('档位只使用本地能力', () {
      expect(noteProfile.isOffline, isTrue);
    });
  });

  group('入口文件识别', () {
    test('优先命中 README.md', () {
      write('README.md', '// .md');
      write('other.txt', 'x');
      expect(
        RunnerService.findEntry(project.path),
        p.join(project.path, 'README.md'),
      );
    });

    test('入口表覆盖了模板自带的入口文件', () {
      // 这是「一个语言一个 App」最容易出错的地方：模板统一把源码放在 src/ 下，
      // 而入口表要是只写了根目录的文件名，新建项目后点运行就会找不到入口。
      final mainFile = ProjectTemplate.markdown.mainFile;
      expect(mainFile, isNotNull, reason: '模板里没有文件');
      expect(noteProfile.entryFileNames, contains(mainFile));
    });

    test('模板把源码放在 src/ 下时也能找到入口', () {
      final mainFile = ProjectTemplate.markdown.mainFile!;
      write(mainFile, '// 示例');
      expect(
        RunnerService.findEntry(project.path),
        p.join(project.path, mainFile),
      );
    });
  });

  group('运行能力', () {
    test('Markdown 版不注入程序运行后端', () {
      expect(noteProfile.runner, isNull);
    });
  });

  group('运行按钮分流', () {
    test('Markdown 文件显示不可运行说明，编辑与预览工具保持独立', () async {
      write('README.md', '// 示例');
      final result = await RunnerService.runProject(
        projectPath: project.path,
        entryFile: p.join(project.path, 'README.md'),
      );
      expect(result, isNotNull);
      expect(result!.hint, contains('无法识别'));
    });
  });
}
