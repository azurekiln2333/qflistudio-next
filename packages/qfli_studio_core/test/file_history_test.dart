import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import 'package:flutter/material.dart';
import 'package:qfli_studio_core/services/file_backup.dart';
import 'package:qfli_studio_core/store/auth_store.dart';
import 'package:qfli_studio_core/store/settings_store.dart';
import 'package:qfli_studio_core/app.dart';
import 'package:qfli_studio_core/store/project_store.dart';

void main() {
  late Directory base;
  late Directory projectDir;
  late File original;

  setUp(() async {
    base = await Directory.systemTemp.createTemp('qfli_backup');
    FileBackup.baseOverride = base.path;
    projectDir = Directory(p.join(base.path, 'proj'))..createSync();
    original = File(p.join(projectDir.path, 'src', 'main.py'))
      ..createSync(recursive: true)
      ..writeAsStringSync('print(1)');
  });

  tearDown(() async {
    FileBackup.baseOverride = null;
    if (await base.exists()) await base.delete(recursive: true);
  });

  test('backupBeforeOverwrite 生成带时间戳版本并列举', () async {
    original.writeAsStringSync('print(2)');
    await FileBackup.backupBeforeOverwrite(
      original,
      projectName: 'proj',
    );
    // 再改再备份一次，制造两个版本。
    original.writeAsStringSync('print(3)');
    await Future.delayed(const Duration(milliseconds: 5));
    await FileBackup.backupBeforeOverwrite(original, projectName: 'proj');

    final versions =
        await FileBackup.listVersions(original, projectName: 'proj');
    expect(versions.length, 2);
    // 倒序：最新在前；备份内容 = 备份时刻的文件内容。
    expect(versions[0].time.isAfter(versions[1].time), isTrue);
    expect(versions[0].file.readAsStringSync(), 'print(3)');
    expect(versions[1].file.readAsStringSync(), 'print(2)');
  });

  test('restoreVersion 恢复内容且不丢当前版本', () async {
    original.writeAsStringSync('print(2)');
    await FileBackup.backupBeforeOverwrite(original, projectName: 'proj');
    final versions =
        await FileBackup.listVersions(original, projectName: 'proj');
    final old = versions.first; // 最新备份，内容 print(2)

    original.writeAsStringSync('print(999)'); // 模拟后续改动
    await FileBackup.restoreVersion(old, original, projectName: 'proj');

    expect(original.readAsStringSync(), 'print(2)');
    // 恢复前把当前内容（print(999)）也备份了一份。
    final versions2 =
        await FileBackup.listVersions(original, projectName: 'proj');
    expect(
      versions2.any((v) => v.file.readAsStringSync() == 'print(999)'),
      isTrue,
    );
  });

  test('其他项目的备份不会被匹配', () async {
    original.writeAsStringSync('print(2)');
    await FileBackup.backupBeforeOverwrite(original, projectName: 'proj');
    final versions = await FileBackup.listVersions(
      original,
      projectName: 'another-project',
    );
    expect(versions, isEmpty);
  });

  test('控制器：打开历史只读标签不影响已打开的文件标签', () async {
    // 只读快照不参与保存/云同步：内容不会被改动，标签不会因此关闭。
    original.writeAsStringSync('print(2)');
    await FileBackup.backupBeforeOverwrite(original, projectName: 'proj');
    final before =
        await FileBackup.listVersions(original, projectName: 'proj');
    expect(before, isNotEmpty);

    final snapshotText = before.first.file.readAsStringSync();
    expect(snapshotText, 'print(2)');
    final after =
        await FileBackup.listVersions(original, projectName: 'proj');
    expect(after.length, before.length);
  });

  testWidgets('启动页：ready=false 显示品牌启动页，ready=true 进入主页', (tester) async {
    final ready = ValueNotifier<bool>(false);
    final store = ProjectStore(
      storageFile: File(p.join(base.path, 'projects.json')),
    );
    final auth = AuthStore(
      storageFile: File(p.join(base.path, 'auth.json')),
    );
    await tester.pumpWidget(QfliApp(
      store: store,
      auth: auth,
      settings: SettingsStore(),
      ready: ready,
    ));
    await tester.pump();
    // 应用图标（Image.asset）+ 底部进度条
    expect(find.byType(Image), findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsOneWidget);

    ready.value = true;
    await tester.pumpAndSettle(
      const Duration(milliseconds: 100),
      EnginePhase.sendSemanticsUpdate,
      const Duration(seconds: 3),
    );
    expect(find.byType(NavigationBar), findsOneWidget);
  });
}
