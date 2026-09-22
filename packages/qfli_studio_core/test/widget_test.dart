import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import 'package:qfli_studio_core/app.dart';
import 'package:qfli_studio_core/editor/editor_delete_fix.dart';
import 'package:qfli_studio_core/editor/highlight_themes.dart';
import 'package:qfli_studio_core/i18n/studio_localizations.dart';
import 'package:qfli_studio_core/services/code_formatter.dart';
import 'package:qfli_studio_core/editor/editor_controller.dart';
import 'package:qfli_studio_core/models/project.dart';
import 'package:qfli_studio_core/services/file_backup.dart';
import 'package:qfli_studio_core/services/project_config.dart';
import 'package:qfli_studio_core/services/project_templates.dart';
import 'package:qfli_studio_core/services/recycle_bin.dart';
import 'package:qfli_studio_core/store/auth_store.dart';
import 'package:qfli_studio_core/store/project_store.dart';
import 'package:qfli_studio_core/store/settings_store.dart';
import 'package:qfli_studio_core/widgets/project_card.dart';
import 'package:re_editor/re_editor.dart';

void main() {
  late Directory tempDir;
  late File storage;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('qflistudio_test');
    storage = File(p.join(tempDir.path, 'projects.json'));
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  test('项目创建并持久化到磁盘', () async {
    final store = ProjectStore(storageFile: storage);
    await store.load();
    final workspace = Directory(p.join(tempDir.path, 'workspace'))
      ..createSync();

    final result = await store.createProject(
      name: 'demo',
      location: workspace.path,
    );
    expect(result.error, isNull);
    expect(result.project, isNotNull);
    expect(Directory(p.join(workspace.path, 'demo')).existsSync(), isTrue);

    // 重新加载，验证持久化。
    final reloaded = ProjectStore(storageFile: storage);
    await reloaded.load();
    expect(reloaded.projects.length, 1);
    expect(reloaded.projects.first.name, 'demo');

    // 名称校验。
    final bad = await store.createProject(
      name: 'a/b',
      location: workspace.path,
    );
    expect(bad.error, isNotNull);
  });

  test('编辑器：打开、编辑、保存写回磁盘', () async {
    final projDir = Directory(p.join(tempDir.path, 'editor_proj'))
      ..createSync();
    final file = File(p.join(projDir.path, 'note.txt'));
    await file.writeAsString('hello');

    final controller = EditorController(
      project: Project.create(name: 'editor_proj', path: projDir.path),
    );

    final openError = await controller.openPath(file.path);
    expect(openError, isNull);
    expect(controller.current, isNotNull);
    expect(controller.current!.controller.text, 'hello');
    expect(controller.current!.dirty, isFalse);

    controller.current!.controller.text = 'hello world';
    expect(controller.current!.dirty, isTrue);

    final saveError = await controller.saveAt(controller.currentIndex);
    expect(saveError, isNull);
    expect(controller.current!.dirty, isFalse);
    expect(file.readAsStringSync(), 'hello world');

    // 已打开的文件不会重复打开。
    final dupError = await controller.openPath(file.path);
    expect(dupError, isNull);
    expect(controller.files.length, 1);

    // 二进制文件拒绝打开。
    await File(p.join(projDir.path, 'bin.dat')).writeAsBytes([0, 1, 2, 0, 3]);
    final binError = await controller.openPath(p.join(projDir.path, 'bin.dat'));
    expect(binError, isNotNull);

    controller.dispose();
  });

  testWidgets('主页：空状态 -> 添加项目 -> 卡片显示名称路径 -> 进入编辑器', (tester) async {
    final store = ProjectStore(storageFile: storage);
    await tester.runAsync(() => store.load());
    await tester.pumpWidget(QfliApp(store: store, auth: AuthStore()));
    await tester.pumpAndSettle(
      const Duration(milliseconds: 100),
      EnginePhase.sendSemanticsUpdate,
      const Duration(seconds: 3),
    );

    final l10n = StudioLocalizations.of(
      tester.element(find.byType(NavigationBar)),
    );
    expect(find.text(l10n.noProjects), findsOneWidget);

    // 添加一个已有文件夹作为项目。
    final projDir = Directory(p.join(tempDir.path, 'demo'))..createSync();
    Directory(p.join(projDir.path, 'src')).createSync();
    File(p.join(projDir.path, 'src', 'main.txt')).writeAsStringSync('hello');
    await tester.runAsync(() => store.addExisting(projDir.path));
    await tester.pumpAndSettle(
      const Duration(milliseconds: 100),
      EnginePhase.sendSemanticsUpdate,
      const Duration(seconds: 3),
    );

    expect(find.text('demo'), findsOneWidget);
    // 路径过长时可见文本左省略，完整路径保留在卡片的 Tooltip 中。
    expect(
      find.byWidgetPredicate(
        (widget) => widget is Tooltip && widget.message == projDir.path,
      ),
      findsOneWidget,
    );

    // 点击项目卡片进入编辑器（侧栏默认隐藏，顶栏副标题显示未打开文件）。
    await tester.tap(find.text('demo'));
    await tester.pumpAndSettle(
      const Duration(milliseconds: 100),
      EnginePhase.sendSemanticsUpdate,
      const Duration(seconds: 3),
    );
    expect(find.text('demo'), findsWidgets);
    expect(find.text('未打开文件'), findsOneWidget);

    // 展开侧栏，src 目录可见。
    await tester.tap(find.byIcon(Icons.menu));
    await tester.pumpAndSettle(
      const Duration(milliseconds: 100),
      EnginePhase.sendSemanticsUpdate,
      const Duration(seconds: 3),
    );
    expect(find.text('src'), findsOneWidget);
  });

  testWidgets('底部导航：主页/教程/讨论/我的 四个 Tab 切换', (tester) async {
    final store = ProjectStore(storageFile: storage);
    await tester.runAsync(() => store.load());
    await tester.pumpWidget(QfliApp(store: store, auth: AuthStore()));
    await tester.pumpAndSettle(
      const Duration(milliseconds: 100),
      EnginePhase.sendSemanticsUpdate,
      const Duration(seconds: 3),
    );

    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.byKey(const ValueKey('home-page-view')), findsOneWidget);
    final l10n = StudioLocalizations.of(
      tester.element(find.byType(NavigationBar)),
    );
    expect(find.text(l10n.noProjects), findsOneWidget);

    await tester.tap(find.byIcon(Icons.apps_outlined));
    await tester.pumpAndSettle(
      const Duration(milliseconds: 100),
      EnginePhase.sendSemanticsUpdate,
      const Duration(seconds: 3),
    );
    expect(find.text(l10n.functions), findsWidgets);
    expect(find.text(l10n.terminal), findsOneWidget);

    await tester.tap(find.byIcon(Icons.forum_outlined));
    await tester.pumpAndSettle(
      const Duration(milliseconds: 100),
      EnginePhase.sendSemanticsUpdate,
      const Duration(seconds: 3),
    );
    expect(find.text(l10n.discussion), findsWidgets);

    await tester.tap(find.byIcon(Icons.person_outline));
    await tester.pumpAndSettle(
      const Duration(milliseconds: 100),
      EnginePhase.sendSemanticsUpdate,
      const Duration(seconds: 3),
    );
    expect(find.text('未登录'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.home_outlined));
    await tester.pumpAndSettle(
      const Duration(milliseconds: 100),
      EnginePhase.sendSemanticsUpdate,
      const Duration(seconds: 3),
    );
    expect(find.text(l10n.noProjects), findsOneWidget);
  });

  testWidgets('宽屏编辑器：左上角按钮可收起/展开文件树侧栏', (tester) async {
    final store = ProjectStore(storageFile: storage);
    await tester.runAsync(() => store.load());
    final projDir = Directory(p.join(tempDir.path, 'demo'))..createSync();
    Directory(p.join(projDir.path, 'src')).createSync();
    File(p.join(projDir.path, 'src', 'main.txt')).writeAsStringSync('hello');
    await tester.runAsync(() => store.addExisting(projDir.path));
    await tester.pumpWidget(QfliApp(store: store, auth: AuthStore()));
    await tester.pumpAndSettle(
      const Duration(milliseconds: 100),
      EnginePhase.sendSemanticsUpdate,
      const Duration(seconds: 3),
    );

    await tester.tap(find.text('demo'));
    await tester.pumpAndSettle(
      const Duration(milliseconds: 100),
      EnginePhase.sendSemanticsUpdate,
      const Duration(seconds: 3),
    );

    // 默认收起（侧栏显隐由顶栏左侧按钮控制）。
    expect(
      tester.widget<AnimatedAlign>(find.byType(AnimatedAlign)).widthFactor,
      0.0,
    );

    // 展开侧栏。
    await tester.tap(find.byIcon(Icons.menu));
    await tester.pumpAndSettle(
      const Duration(milliseconds: 100),
      EnginePhase.sendSemanticsUpdate,
      const Duration(seconds: 3),
    );
    expect(find.text('src'), findsOneWidget);
    expect(
      tester.widget<AnimatedAlign>(find.byType(AnimatedAlign)).widthFactor,
      1.0,
    );

    // 再次收起。
    await tester.tap(find.byIcon(Icons.menu));
    await tester.pumpAndSettle(
      const Duration(milliseconds: 100),
      EnginePhase.sendSemanticsUpdate,
      const Duration(seconds: 3),
    );
    expect(
      tester.widget<AnimatedAlign>(find.byType(AnimatedAlign)).widthFactor,
      0.0,
    );
  });

  testWidgets('窄屏编辑器：文件树通过抽屉（Drawer）打开', (tester) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final store = ProjectStore(storageFile: storage);
    await tester.runAsync(() => store.load());
    final projDir = Directory(p.join(tempDir.path, 'demo'))..createSync();
    Directory(p.join(projDir.path, 'src')).createSync();
    File(p.join(projDir.path, 'src', 'main.txt')).writeAsStringSync('hello');
    await tester.runAsync(() => store.addExisting(projDir.path));
    await tester.pumpWidget(QfliApp(store: store, auth: AuthStore()));
    await tester.pumpAndSettle(
      const Duration(milliseconds: 100),
      EnginePhase.sendSemanticsUpdate,
      const Duration(seconds: 3),
    );

    await tester.tap(find.text('demo'));
    await tester.pumpAndSettle(
      const Duration(milliseconds: 100),
      EnginePhase.sendSemanticsUpdate,
      const Duration(seconds: 3),
    );

    // 窄屏默认没有内联文件树。
    expect(find.text('src'), findsNothing);

    // 左上角按钮打开抽屉。
    await tester.tap(find.byIcon(Icons.menu));
    await tester.pumpAndSettle(
      const Duration(milliseconds: 100),
      EnginePhase.sendSemanticsUpdate,
      const Duration(seconds: 3),
    );
    expect(find.text('src'), findsOneWidget);

    // 点击遮罩关闭抽屉。
    await tester.tapAt(const Offset(360, 400));
    await tester.pumpAndSettle(
      const Duration(milliseconds: 100),
      EnginePhase.sendSemanticsUpdate,
      const Duration(seconds: 3),
    );
    expect(find.text('src'), findsNothing);
  });

  test('模板创建：Python 项目生成 main.py，C 项目生成 main.c', () async {
    final store = ProjectStore(storageFile: storage);
    await store.load();
    final workspace = Directory(p.join(tempDir.path, 'ws2'))..createSync();

    final py = await store.createProject(
      name: 'pyproj',
      location: workspace.path,
      template: ProjectTemplate.python,
    );
    expect(py.error, isNull);
    final pyMain = File(p.join(workspace.path, 'pyproj', 'src', 'main.py'));
    expect(pyMain.existsSync(), isTrue);
    expect(pyMain.readAsStringSync(), contains('print'));
    expect(ProjectTemplate.python.mainFile, 'src/main.py');

    final c = await store.createProject(
      name: 'cproj',
      location: workspace.path,
      template: ProjectTemplate.c,
    );
    expect(c.error, isNull);
    final cMain = File(p.join(workspace.path, 'cproj', 'src', 'main.c'));
    expect(cMain.existsSync(), isTrue);
    expect(cMain.readAsStringSync(), contains('printf'));
  });

  testWidgets('主页搜索：展开搜索栏并按名称过滤项目', (tester) async {
    final store = ProjectStore(storageFile: storage);
    await tester.runAsync(() => store.load());
    final demoDir = Directory(p.join(tempDir.path, 'demo'))..createSync();
    final otherDir = Directory(p.join(tempDir.path, 'other'))..createSync();
    await tester.runAsync(() => store.addExisting(demoDir.path));
    await tester.runAsync(() => store.addExisting(otherDir.path));
    await tester.pumpWidget(QfliApp(store: store, auth: AuthStore()));
    await tester.pumpAndSettle(
      const Duration(milliseconds: 100),
      EnginePhase.sendSemanticsUpdate,
      const Duration(seconds: 3),
    );

    expect(find.widgetWithText(ProjectCard, 'demo'), findsOneWidget);
    expect(find.widgetWithText(ProjectCard, 'other'), findsOneWidget);

    // 点击搜索图标展开搜索栏。
    await tester.tap(find.byIcon(Icons.search));
    await tester.pumpAndSettle(
      const Duration(milliseconds: 100),
      EnginePhase.sendSemanticsUpdate,
      const Duration(seconds: 3),
    );
    expect(find.byType(TextField), findsOneWidget);

    // 输入关键词，实时过滤。
    await tester.enterText(find.byType(TextField), 'demo');
    await tester.pumpAndSettle(
      const Duration(milliseconds: 100),
      EnginePhase.sendSemanticsUpdate,
      const Duration(seconds: 3),
    );
    expect(find.widgetWithText(ProjectCard, 'demo'), findsOneWidget);
    expect(find.widgetWithText(ProjectCard, 'other'), findsNothing);

    // 无结果状态。
    await tester.enterText(find.byType(TextField), 'zzz');
    await tester.pumpAndSettle(
      const Duration(milliseconds: 100),
      EnginePhase.sendSemanticsUpdate,
      const Duration(seconds: 3),
    );
    final l10n = StudioLocalizations.of(
      tester.element(find.byType(NavigationBar)),
    );
    expect(find.text(l10n.noMatchingProjects), findsOneWidget);

    // 退出搜索恢复完整列表。
    await tester.tap(find.byIcon(Icons.arrow_back));
    await tester.pumpAndSettle(
      const Duration(milliseconds: 100),
      EnginePhase.sendSemanticsUpdate,
      const Duration(seconds: 3),
    );
    expect(find.widgetWithText(ProjectCard, 'other'), findsOneWidget);
  });

  testWidgets('语法高亮：按文件类型生成明暗主题', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: SizedBox.shrink())),
    );
    final context = tester.element(find.byType(Scaffold));
    final dartTheme = HighlightThemes.themeFor(
      context,
      'main.dart',
      'void main() {}',
    );
    expect(dartTheme, isNotNull);
    final binTheme = HighlightThemes.themeFor(context, 'data.bin', 'anything');
    expect(binTheme, isNull);
    // 超大文件退回纯文本（null 主题）。
    final huge = HighlightThemes.themeFor(context, 'a.dart', 'x' * 200000);
    expect(huge, isNull);
  });

  test('代码格式化：JSON 与 C-like 重缩进', () {
    final json = CodeFormatter.format('a.json', '{"b":[1,2],"a":"x"}');
    expect(json.changed, isTrue);
    expect(json.text, contains('  "a": '));

    final code = CodeFormatter.format('main.cpp', 'int main(){if(x){y();}}');
    expect(code.text, contains('int main(){'));
    expect(code.text, contains('\n  if(x){'));
  });

  test('删除项目：压缩备份到回收站 projects_bin 后删除文件夹', () async {
    final store = ProjectStore(storageFile: storage);
    await store.load();
    final workspace = Directory(p.join(tempDir.path, 'ws_del'))..createSync();
    final result = await store.createProject(
      name: 'delme',
      location: workspace.path,
      template: ProjectTemplate.python,
    );
    expect(result.error, isNull);
    final project = result.project!;
    final projPath = project.path;

    RecycleBin.baseOverride = tempDir.path;
    addTearDown(() => RecycleBin.baseOverride = null);

    final error = await store.deleteProject(project);
    expect(error, isNull);
    expect(Directory(projPath).existsSync(), isFalse);
    expect(store.projects.any((e) => e.id == project.id), isFalse);

    final binDir = Directory(
      p.join(tempDir.path, 'recyclebin', 'projects_bin'),
    );
    final zips = binDir.listSync().whereType<File>().toList();
    expect(zips.length, 1);
    expect(p.basename(zips.first.path), contains('delme'));

    // 解压校验备份内容：zip 以项目文件夹为根，模板文件与配置都在。
    final archive = ZipDecoder().decodeBytes(await zips.first.readAsBytes());
    expect(archive.findFile('delme/src/main.py'), isNotNull);
    expect(archive.findFile('delme/.qfli/project.json'), isNotNull);
    final py = archive.findFile('delme/src/main.py')!;
    expect(String.fromCharCodes(py.content), contains('def main'));
  });

  test('删除文件/文件夹前备份到 files_bin', () async {
    RecycleBin.baseOverride = tempDir.path;
    addTearDown(() => RecycleBin.baseOverride = null);

    final sub = Directory(p.join(tempDir.path, 'sub'))..createSync();
    await File(p.join(sub.path, 'a.txt')).writeAsString('A');
    final file = File(p.join(tempDir.path, 'note.txt'));
    await file.writeAsString('N');

    var error = await RecycleBin.backupEntry(sub, projectName: 'proj');
    expect(error, isNull);
    error = await RecycleBin.backupEntry(file, projectName: 'proj');
    expect(error, isNull);

    final binDir = Directory(p.join(tempDir.path, 'recyclebin', 'files_bin'));
    final zips = binDir.listSync().whereType<File>().toList();
    expect(zips.length, 2);
    final folderZip = zips.firstWhere(
      (f) => p.basename(f.path).contains('sub'),
    );
    final archive = ZipDecoder().decodeBytes(await folderZip.readAsBytes());
    expect(archive.findFile('sub/a.txt'), isNotNull);
    final entry = archive.findFile('sub/a.txt')!;
    expect(String.fromCharCodes(entry.content), 'A');
  });

  test('选区/光标/composing 变化不标脏，内容修改才标脏', () async {
    final projDir = Directory(p.join(tempDir.path, 'sel_proj'))..createSync();
    final file = File(p.join(projDir.path, 'a.txt'));
    await file.writeAsString('hello');

    final controller = EditorController(
      project: Project.create(name: 'sel_proj', path: projDir.path),
    );
    addTearDown(controller.dispose);
    final openError = await controller.openPath(file.path);
    expect(openError, isNull);
    final open = controller.current!;
    final editor = open.controller;
    expect(open.dirty, isFalse);

    // 拖选（含全选场景）：只改选区，不应出现未保存圆点。
    editor.selection = const CodeLineSelection(
      baseIndex: 0,
      baseOffset: 0,
      extentIndex: 0,
      extentOffset: 5,
    );
    expect(open.dirty, isFalse);

    // 移动光标同理。
    editor.selection = const CodeLineSelection.collapsed(index: 0, offset: 2);
    expect(open.dirty, isFalse);

    // IME composing 阶段同样不算修改。
    editor.composing = const TextRange(start: 2, end: 3);
    expect(open.dirty, isFalse);
    editor.composing = TextRange.empty;
    expect(open.dirty, isFalse);

    // 真正修改内容：标脏并通知（未保存圆点出现）。
    var notified = false;
    controller.addListener(() => notified = true);
    editor.text = 'hello world';
    expect(open.dirty, isTrue);
    expect(notified, isTrue);

    // 保存后恢复干净状态。
    final saveError = await controller.saveAt(controller.currentIndex);
    expect(saveError, isNull);
    expect(open.dirty, isFalse);
  });

  test('项目配置：创建写入 .qfli，添加已有优先配置，加载回填语言', () async {
    final store = ProjectStore(storageFile: storage);
    await store.load();
    final workspace = Directory(p.join(tempDir.path, 'ws_cfg'))..createSync();

    // 创建时写入配置文件。
    final created = await store.createProject(
      name: 'cfg',
      location: workspace.path,
      template: ProjectTemplate.python,
    );
    final projPath = created.project!.path;
    expect(ProjectConfig.readLanguage(projPath), 'Python');

    // 添加已有项目：配置文件语言优先于扩展名检测。
    final legacy = Directory(p.join(workspace.path, 'legacy'))..createSync();
    File(p.join(legacy.path, 'x.py')).writeAsStringSync('print(1)');
    final cfgDir = Directory(p.join(legacy.path, '.qfli'))..createSync();
    File(
      p.join(cfgDir.path, 'project.json'),
    ).writeAsStringSync('{"version": 1, "name": "legacy", "language": "Java"}');
    final added = await store.addExisting(legacy.path);
    expect(added.error, isNull);
    expect(added.project!.language, 'Java');

    // 无配置时按扩展名检测，并补写配置文件。
    final fresh = Directory(p.join(workspace.path, 'fresh'))..createSync();
    File(p.join(fresh.path, 'y.py')).writeAsStringSync('print(2)');
    final added2 = await store.addExisting(fresh.path);
    expect(added2.error, isNull);
    expect(added2.project!.language, 'Python');
    expect(ProjectConfig.readLanguage(fresh.path), 'Python');

    // 注册表语言缺失时从配置文件回填。
    await storage.writeAsString(
      jsonEncode({
        'projects': [
          {
            'id': 'backfill',
            'name': 'backfill',
            'path': projPath,
            'createdAt': '2026-01-01T00:00:00.000',
            'lastOpenedAt': '2026-01-01T00:00:00.000',
            'language': '',
          },
        ],
      }),
    );
    final reloaded = ProjectStore(storageFile: storage);
    await reloaded.load();
    expect(reloaded.projects.first.language, 'Python');
  });

  test('设置：settings.json 持久化与重载', () async {
    final file = File(p.join(tempDir.path, 'settings.json'));
    final s1 = SettingsStore(storageFile: file);
    await s1.load();
    expect(s1.loaded, isTrue);
    expect(s1.minimap, isTrue);
    expect(s1.autoSave, isFalse);

    var notified = 0;
    s1.addListener(() => notified++);
    await s1.setMinimap(true);
    expect(notified, 0);
    await s1.setMinimap(false);
    await s1.setAutoSave(true);
    expect(notified, 2);
    expect(file.existsSync(), isTrue);

    final s2 = SettingsStore(storageFile: file);
    await s2.load();
    expect(s2.minimap, isFalse);
    expect(s2.autoSave, isTrue);

    // 配置损坏时回退默认值。
    await file.writeAsString('{broken');
    final s3 = SettingsStore(storageFile: file);
    await s3.load();
    expect(s3.minimap, isTrue);
    expect(s3.autoSave, isFalse);
  });

  test('空首行退格：自定义 Delete 动作把空首行并入下一行', () {
    final controller = CodeLineEditingController.fromText('\na');
    final action = EditorDeleteAction(controller);
    action.invoke(const CodeShortcutDeleteIntent(false));
    expect(controller.text, 'a');
    controller.dispose();
  });

  test('Delete 动作其余场景原样委托控制器', () {
    final controller = CodeLineEditingController.fromText('abc');
    final action = EditorDeleteAction(controller);

    // 非空首行退格：走原 deleteBackward。
    controller.selection = const CodeLineSelection.collapsed(
      index: 0,
      offset: 3,
    );
    action.invoke(const CodeShortcutDeleteIntent(false));
    expect(controller.text, 'ab');

    // Forward 删除：走原 deleteForward。
    controller.selection = const CodeLineSelection.collapsed(
      index: 0,
      offset: 0,
    );
    action.invoke(const CodeShortcutDeleteIntent(true));
    expect(controller.text, 'b');
    controller.dispose();
  });

  test('files_backup：覆盖前生成带时间戳备份，缺文件跳过，项目名清洗', () async {
    final projDir = Directory(p.join(tempDir.path, 'bk_proj'))..createSync();
    final file = File(p.join(projDir.path, 'main.py'));
    await file.writeAsString('v1');

    FileBackup.baseOverride = tempDir.path;
    addTearDown(() => FileBackup.baseOverride = null);

    expect(
      await FileBackup.backupBeforeOverwrite(file, projectName: 'demo'),
      isNull,
    );
    final projectDir = Directory(p.join(tempDir.path, 'files_backup', 'demo'));
    List<String> backupNames() => projectDir
        .listSync()
        .whereType<File>()
        .map((f) => p.basename(f.path))
        .toList();
    final first = backupNames();
    expect(first.length, 1);
    expect(first.single, startsWith('main-'));
    expect(first.single, endsWith('.py'));
    expect(
      File(p.join(projectDir.path, first.single)).readAsStringSync(),
      'v1',
    );

    // 同名文件再备份：时间戳冲突时追加序号。
    await FileBackup.backupBeforeOverwrite(file, projectName: 'demo');
    expect(backupNames().length, 2);

    // 文件不存在（新建）时跳过。
    final missing = File(p.join(projDir.path, 'ghost.py'));
    await FileBackup.backupBeforeOverwrite(missing, projectName: 'demo');
    expect(backupNames().length, 2);

    // 项目名含非法路径字符时清洗为合法目录。
    await FileBackup.backupBeforeOverwrite(file, projectName: 'a/b');
    expect(
      Directory(p.join(tempDir.path, 'files_backup', 'a_b')).existsSync(),
      isTrue,
    );
  });
}
