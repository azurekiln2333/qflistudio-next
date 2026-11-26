import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:qfli_studio_core/editor/editor_page.dart';
import 'package:qfli_studio_core/editor/file_explorer.dart';
import 'package:qfli_studio_core/editor/retained_editor_host.dart';
import 'package:qfli_studio_core/models/project.dart';
import 'package:qfli_studio_core/services/studio_profile.dart';
import 'package:qfli_studio_core/store/auth_store.dart';
import 'package:qfli_studio_core/store/project_store.dart';
import 'package:qfli_studio_core/store/settings_store.dart';
import 'package:qfli_studio_core/workspace/saved_workspace.dart';
import 'package:qfli_studio_core/workspace/workspace_store.dart';

void main() {
  StudioProfile? previous;
  setUp(() {
    previous = StudioProfile.current;
    StudioProfile.current = const StudioProfile(
      id: 'workspace-dialog-test',
      appTitle: 'QFLIStudio+',
      templates: [],
      productKey: StudioProductCatalog.qfliStudioKey,
    );
  });
  tearDown(() => StudioProfile.current = previous);

  for (final scenario in [
    (platform: TargetPlatform.ohos, size: const Size(390, 720)),
    (platform: TargetPlatform.ohos, size: const Size(1100, 720)),
    (platform: TargetPlatform.android, size: const Size(390, 720)),
  ]) {
    testWidgets(
      '${scenario.platform.name} ${scenario.size.width} retained workspace settings paints and applies',
      (tester) async {
        final fixture = (await tester.runAsync(_Fixture.create))!;
        addTearDown(fixture.dispose);
        addTearDown(() => fixture.unmount(tester));
        await fixture.mount(
          tester,
          size: scenario.size,
          platform: scenario.platform,
        );
        final originalSource = File(
          p.join(fixture.first.path, 'main.txt'),
        ).readAsStringSync();
        final editorState = tester.state(find.byType(EditorPage));

        await _openSettings(tester);
        expect(tester.takeException(), isNull);
        expect(find.text('工作区设置').hitTestable(), findsOneWidget);
        expect(
          find.byKey(const ValueKey('workspace-name-field')).hitTestable(),
          findsOneWidget,
        );
        expect(
          find.widgetWithText(TextButton, '取消').hitTestable(),
          findsOneWidget,
        );

        // A focused name field opens the phone keyboard. The dialog must still
        // paint its controls and keep the final project reachable by scrolling.
        tester.view.viewInsets = const FakeViewPadding(bottom: 300);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
        expect(tester.takeException(), isNull);
        final last = find.byKey(
          ValueKey('workspace-project-${fixture.last.id}'),
        );
        await tester.ensureVisible(last);
        await tester.pump(const Duration(milliseconds: 200));
        expect(last.hitTestable(), findsOneWidget);
        await tester.tap(last);
        await tester.enterText(
          find.byKey(const ValueKey('workspace-name-field')),
          '手机工作区',
        );
        await tester.tap(find.widgetWithText(FilledButton, '应用'));
        await _pumpUntil(
          tester,
          () =>
              find.byType(AlertDialog).evaluate().isEmpty &&
              fixture.workspaces.workspaces.single.name == '手机工作区' &&
              find.text('手机工作区 · 2 个项目').evaluate().isNotEmpty,
          'workspace apply',
        );
        final saved = fixture.workspaces.workspaces.single;
        expect(saved.members.map((member) => member.projectId), [
          fixture.first.id,
          fixture.last.id,
        ]);
        expect(fixture.host.sessionInfos.single.workspace?.id, saved.id);
        expect(find.byType(EditorPage), findsOneWidget);
        expect(tester.state(find.byType(EditorPage)), same(editorState));
        expect(
          File(p.join(fixture.first.path, 'main.txt')).readAsStringSync(),
          originalSource,
        );
        expect(tester.takeException(), isNull);

        // Reopening and cancelling must remove the barrier and return input to
        // the same editor's toolbar, including after the keyboard was visible.
        await _openSettings(tester);
        await tester.tap(find.widgetWithText(TextButton, '取消'));
        await _pumpUntil(
          tester,
          () => find.byType(AlertDialog).evaluate().isEmpty,
          'settings cancel',
        );
        expect(find.byTooltip('工作区项目').hitTestable(), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('OHOS standalone single project saves from actual editor', (
    tester,
  ) async {
    final fixture = (await tester.runAsync(
      () => _Fixture.create(saveWorkspace: false, projectCount: 1),
    ))!;
    addTearDown(fixture.dispose);
    addTearDown(() => fixture.unmount(tester));
    await fixture.mount(tester);
    await _openSettings(tester);
    expect(find.text('保存工作区').hitTestable(), findsOneWidget);
    expect(find.byType(CheckboxListTile), findsOneWidget);
    await tester.enterText(
      find.byKey(const ValueKey('workspace-name-field')),
      '单项目工作区',
    );
    await tester.tap(find.widgetWithText(FilledButton, '保存'));
    await _pumpUntil(
      tester,
      () =>
          find.byType(AlertDialog).evaluate().isEmpty &&
          fixture.host.sessionInfos.single.workspace?.name == '单项目工作区',
      'standalone workspace save',
    );
    final saved = fixture.workspaces.workspaces.single;
    expect(saved.members.single.projectId, fixture.first.id);
    expect(
      File(
        p.join(fixture.directory.path, 'workspaces', '${saved.id}.json'),
      ).readAsStringSync(),
      contains('单项目工作区'),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('OHOS language editor project dialog scrolls and applies', (
    tester,
  ) async {
    StudioProfile.current = const StudioProfile(
      id: 'language-workspace-dialog-test',
      appTitle: 'Language editor',
      templates: [],
      isOffline: true,
      productKey: StudioProductCatalog.jvmxKey,
    );
    final fixture = (await tester.runAsync(
      () => _Fixture.create(saveWorkspace: false),
    ))!;
    addTearDown(fixture.dispose);
    addTearDown(() => fixture.unmount(tester));
    await fixture.mount(tester);
    await _openSettings(tester);
    expect(find.text('工作区项目').hitTestable(), findsOneWidget);
    final last = find.byKey(ValueKey('workspace-project-${fixture.last.id}'));
    await tester.ensureVisible(last);
    await tester.pump(const Duration(milliseconds: 200));
    expect(last.hitTestable(), findsOneWidget);
    await tester.tap(last);
    await tester.tap(find.widgetWithText(FilledButton, '应用'));
    await _pumpUntil(
      tester,
      () => find
          .byKey(ValueKey('workspace-root-${fixture.last.path}'))
          .evaluate()
          .isNotEmpty,
      'legacy membership apply',
    );
    expect(fixture.workspaces.workspaces, isEmpty);
    expect(find.byTooltip('工作区项目').hitTestable(), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

Future<void> _openSettings(WidgetTester tester) async {
  if (find.byTooltip('工作区项目').hitTestable().evaluate().isEmpty) {
    await tester.tap(find.byTooltip('打开文件树'));
    await _pumpUntil(
      tester,
      () => find.byTooltip('工作区项目').hitTestable().evaluate().isNotEmpty,
      'editor file drawer',
    );
  }
  expect(find.byType(FileExplorer), findsOneWidget);
  await tester.tap(find.byTooltip('工作区项目'));
  await _pumpUntil(
    tester,
    () => find.byType(AlertDialog).evaluate().isNotEmpty,
    'workspace settings route',
  );
}

Future<void> _pumpUntil(
  WidgetTester tester,
  bool Function() done,
  String operation,
) async {
  for (var attempt = 0; attempt < 100 && !done(); attempt++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 5)),
    );
    await tester.pump(const Duration(milliseconds: 20));
  }
  expect(done(), isTrue, reason: '$operation did not finish');
  await tester.pump(const Duration(milliseconds: 300));
}

class _Fixture {
  _Fixture(this.directory, this.projects, this.workspaces, this.saved);

  final Directory directory;
  final ProjectStore projects;
  final WorkspaceStore workspaces;
  final SavedWorkspace? saved;
  final auth = AuthStore();
  final settings = SettingsStore();
  final host = RetainedEditorController();

  Project get first => projects.projects.first;
  Project get last => projects.projects.last;

  static Future<_Fixture> create({
    bool saveWorkspace = true,
    int projectCount = 10,
  }) async {
    final directory = await Directory.systemTemp.createTemp(
      'workspace_dialog_',
    );
    final projects = ProjectStore(
      storageFile: File(p.join(directory.path, 'projects.json')),
    );
    await projects.load();
    for (var index = 0; index < projectCount; index++) {
      final root = await Directory(
        p.join(directory.path, 'project_$index'),
      ).create();
      await File(p.join(root.path, 'main.txt')).writeAsString('source $index');
      final result = await projects.addExisting(root.path);
      if (result.project == null) throw StateError(result.error!);
    }
    final workspaces = WorkspaceStore(
      root: Directory(p.join(directory.path, 'workspaces')),
    );
    await workspaces.load();
    SavedWorkspace? saved;
    if (saveWorkspace) {
      final result = await workspaces.save(
        name: '原工作区',
        members: [projects.projects.first],
        primary: projects.projects.first,
      );
      if (result.workspace == null) throw StateError(result.error!);
      saved = result.workspace;
    }
    return _Fixture(directory, projects, workspaces, saved);
  }

  Future<void> mount(
    WidgetTester tester, {
    Size size = const Size(390, 720),
    TargetPlatform platform = TargetPlatform.ohos,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(platform: platform),
        locale: const Locale('zh', 'CN'),
        supportedLocales: const [Locale('zh', 'CN')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        navigatorObservers: [host.navigatorObserver],
        builder: (context, child) =>
            RetainedEditorHost(controller: host, child: child!),
        home: const Scaffold(body: Text('首页')),
      ),
    );
    host.open(
      project: first,
      auth: auth,
      store: projects,
      settings: settings,
      workspace: saved,
      workspaceProjects: [first],
      workspaceStore: workspaces,
    );
    await _pumpUntil(
      tester,
      () =>
          find.byType(EditorPage).evaluate().isNotEmpty &&
          find.byTooltip('更多').evaluate().isNotEmpty,
      'retained editor',
    );
  }

  Future<void> unmount(WidgetTester tester) async {
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpWidget(const SizedBox.shrink());
    var drained = false;
    final pending = Future.wait([workspaces.settle(), projects.refresh()]);
    pending.then((_) => drained = true);
    await _pumpUntil(tester, () => drained, 'workspace IO drain');
    await pending;
    for (var round = 0; round < 4; round++) {
      await tester.pump(const Duration(milliseconds: 20));
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 10)),
      );
    }
  }

  void dispose() {
    host.dispose();
    auth.dispose();
    settings.dispose();
    projects.dispose();
    workspaces.dispose();
    directory.deleteSync(recursive: true);
  }
}
