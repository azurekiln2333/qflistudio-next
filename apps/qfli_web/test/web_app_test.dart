import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:qfli_web/main.dart' show webProfile;
import 'package:qfli_studio_core/services/project_templates.dart';
import 'package:qfli_studio_core/services/runner_service.dart';
import 'package:qfli_studio_core/services/studio_profile.dart';

/// Web 版 App 的接线测试。
///
/// Web 版是五个语言里唯一「不用自带解释器就能跑」的：内核的 RunnerService 会用
/// LocalWebServer 起一个本地静态服务器，把项目目录当网站serve出去，并往页面里
/// 注入调试桥（劫持 console.log / window.onerror 回传）。所以这里的重点不是
/// 「后端接管」，而是「内核那条路真的通」——起服务器、拿到 URL、页面里能看到
/// 项目内容、调试桥被注入了。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory project;
  late StudioProfile? previousProfile;

  setUp(() {
    previousProfile = StudioProfile.current;
    StudioProfile.current = webProfile;
    project = Directory.systemTemp.createTempSync('qfli_web_app_test');
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
    test('新建项目只放行「空项目」和 Web', () {
      expect(
        webProfile.filterTemplates(ProjectTemplate.values),
        [ProjectTemplate.empty, ProjectTemplate.html],
      );
    });

    test('默认模板是 Web', () {
      expect(webProfile.defaultTemplate, ProjectTemplate.html);
    });

    test('语言筛选芯片只剩 Web', () {
      const all = ['C', 'Python', 'Java', 'Web', 'Dart'];
      expect(webProfile.filterLanguages(all), ['Web']);
    });

    test('不注入运行后端，交给内核的静态服务器', () {
      expect(webProfile.runner, isNull);
    });

    test('产品名带 Web 版后缀', () {
      expect(webProfile.appTitle, 'QFLIStudio+ Web 版');
    });
  });

  group('入口文件识别', () {
    test('优先命中 index.html', () {
      write('index.html', '<html></html>');
      write('src/index.html', '<html></html>');
      expect(
        RunnerService.findEntry(project.path),
        p.join(project.path, 'index.html'),
      );
    });

    test('index.html 在 src/ 下也能找到', () {
      write('src/index.html', '<html></html>');
      expect(
        RunnerService.findEntry(project.path),
        p.join(project.path, 'src/index.html'),
      );
    });

    test('入口表覆盖了模板自带的入口文件', () {
      // 模板统一把源码放在 src/ 下，入口表必须包含它，否则新建项目后点运行
      // 会找不到入口。
      final mainFile = ProjectTemplate.html.mainFile;
      expect(mainFile, isNotNull, reason: '模板里没有文件');
      expect(webProfile.entryFileNames, contains(mainFile));
    });
  });

  group('运行按钮', () {
    test('起本地服务器并返回可访问的 URL', () async {
      write('index.html', '<html><body><h1>你好</h1></body></html>');
      final result = await RunnerService.runProject(
        projectPath: project.path,
        entryFile: p.join(project.path, 'index.html'),
      );
      expect(result, isNotNull);
      expect(result!.webServer, isNotNull, reason: '没有起静态服务器');
      expect(result.hint, isNull);
      expect(result.title, startsWith('http://127.0.0.1:'));

      final server = result.webServer!;
      addTearDown(server.stop);
      // 服务器必须真的在服务这个项目目录，而不是只返回了一个字符串。
      final body = await _get(server.url);
      expect(body, contains('你好'));
    });

    test('页面里被注入了调试桥，console.log 能回传', () async {
      write('index.html', '<html><body>hi</body></html>');
      final result = await RunnerService.runProject(
        projectPath: project.path,
        entryFile: p.join(project.path, 'index.html'),
      );
      final server = result!.webServer!;
      addTearDown(server.stop);

      final body = await _get(server.url);
      expect(body, contains('/__debug'), reason: '页面里没有调试桥');
    });

    test('子目录资源按路径取得到', () async {
      write('index.html', '<html><body>root</body></html>');
      write('css/site.css', 'body { color: red; }');
      final result = await RunnerService.runProject(
        projectPath: project.path,
        entryFile: p.join(project.path, 'index.html'),
      );
      final server = result!.webServer!;
      addTearDown(server.stop);

      final base = server.url.substring(0, server.url.lastIndexOf('/') + 1);
      expect(await _get('${base}css/site.css'), contains('color: red'));
    });
  });
}

/// 直接取一次 HTTP 响应体。
///
/// 两个坑：
/// - flutter_test 会装一个 HttpOverrides，把所有请求拦成空响应（免得用例误连
///   外网）。这里要连的是**本进程刚起的**预览服务器，所以必须临时把 overrides
///   摘掉，否则拿到的永远是空 body。
/// - 解码要用 utf8：SystemEncoding 在 Windows 上是 ANSI 代码页，会把页面里的
///   中文解成乱码。
Future<String> _get(String url) async {
  final saved = HttpOverrides.current;
  HttpOverrides.global = null;
  final client = HttpClient();
  try {
    final request = await client.getUrl(Uri.parse(url));
    final response = await request.close();
    return await response.transform(utf8.decoder).join();
  } finally {
    client.close();
    HttpOverrides.global = saved;
  }
}
