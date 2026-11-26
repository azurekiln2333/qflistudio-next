import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:qfli_studio_core/editor/editor_controller.dart';
import 'package:qfli_studio_core/editor/editor_page.dart';
import 'package:qfli_studio_core/editor/editor_selection_toolbar.dart';
import 'package:qfli_studio_core/editor/file_explorer.dart';
import 'package:qfli_studio_core/editor/project_history.dart';
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
      id: 'workspace-project-switch-test',
      appTitle: 'QFLIStudio+',
      templates: [],
      productKey: StudioProductCatalog.qfliStudioKey,
    );
  });
  tearDown(() => StudioProfile.current = previous);

  testWidgets(
    'member selection preserves the tree; external selection uses a retained standalone',
    (tester) async {
      final fixture = (await tester.runAsync(_Fixture.create))!;
      addTearDown(fixture.dispose);
      addTearDown(() => fixture.unmount(tester));
      await fixture.mount(tester, retained: true);
      await fixture.expandWorkspace(tester);
      await tester.tap(_entry(fixture.first, 'a.txt'));
      await _pumpUntil(tester, () => _editor(tester).current != null, 'open A');
      final editor = _editor(tester);
      final pageState = tester.state(find.byType(EditorPage));
      final buffer = editor.current!;
      const dirtyText = 'unsaved workspace A';
      buffer.controller.text = dirtyText;
      await tester.pump();
      expect(buffer.dirty, isTrue);
      final treeScroll = _treeScroll(tester);
      treeScroll.position.jumpTo(20);
      await tester.pump();
      final treeOffset = treeScroll.position.pixels;
      expect(treeOffset, greaterThan(0));

      await _chooseProject(tester, fixture.second);
      _expectWorkspaceTree(tester, fixture);
      expect(
        find.descendant(
          of: find.byType(PopupMenuButton<Project>),
          matching: find.text(fixture.second.name),
        ),
        findsOneWidget,
      );
      expect(_treeScroll(tester), same(treeScroll));
      expect(treeScroll.position.pixels, treeOffset);
      expect(tester.state(find.byType(EditorPage)), same(pageState));
      expect(_editor(tester), same(editor));
      expect(editor.current, same(buffer));
      expect(buffer.controller.text, dirtyText);
      expect(buffer.dirty, isTrue);

      // The selector still changes the default creation target within W(A,B).
      await tester.tap(find.byTooltip('新建文件夹'));
      await _pumpUntil(
        tester,
        () => find.byType(AlertDialog).evaluate().isNotEmpty,
        'new folder dialog',
      );
      await tester.enterText(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.byType(TextField),
        ),
        'selected_b',
      );
      await tester.tap(find.text('创建').last);
      await _pumpUntil(
        tester,
        () => Directory(p.join(fixture.second.path, 'selected_b')).existsSync(),
        'folder in selected B',
      );
      expect(
        Directory(p.join(fixture.first.path, 'selected_b')).existsSync(),
        isFalse,
      );

      await _chooseProject(tester, fixture.first);
      _expectWorkspaceTree(tester, fixture);
      expect(_editor(tester), same(editor));
      expect(editor.current, same(buffer));
      expect(buffer.controller.text, dirtyText);

      await _chooseProject(tester, fixture.external);
      await _waitForProject(tester, fixture.external);
      expect(_rootOrder(), ['workspace-root-${fixture.external.path}']);
      final standalonePage = tester.state(find.byType(EditorPage));
      final standaloneEditor = _editor(tester);
      expect(standaloneEditor, isNot(same(editor)));
      final standalone = fixture.host.sessionInfos.singleWhere(
        (session) => session.project.id == fixture.external.id,
      );
      expect(standalone.workspace, isNull);
      expect(fixture.host.sessionInfos, hasLength(2));
      await _pumpUntil(
        tester,
        () => _entry(
          fixture.external,
          'src_c',
        ).hitTestable().evaluate().isNotEmpty,
        'external directory read',
      );
      await tester.tap(_entry(fixture.external, 'src_c'));
      await _pumpUntil(
        tester,
        () => _entry(fixture.external, 'c.txt').evaluate().isNotEmpty,
        'external children',
      );
      await tester.tap(_entry(fixture.external, 'c.txt'));
      await _pumpUntil(
        tester,
        () => standaloneEditor.current?.name == 'c.txt',
        'external file open',
      );
      expect(standaloneEditor.current!.projectRootPath, fixture.external.path);
      expect(standaloneEditor.current!.ownerProjectName, fixture.external.name);
      fixture.expectSavedMembersUnchanged();

      fixture.host.resume(fixture.first, workspace: fixture.saved);
      await _waitForProject(tester, fixture.first);
      _expectWorkspaceTree(tester, fixture);
      expect(tester.state(find.byType(EditorPage)), same(pageState));
      expect(_editor(tester), same(editor));
      expect(editor.current, same(buffer));
      expect(buffer.controller.text, dirtyText);
      expect(buffer.dirty, isTrue);

      // C is already mounted: choosing it again must reuse that standalone.
      await _chooseProject(tester, fixture.external);
      await _waitForProject(tester, fixture.external);
      expect(fixture.host.sessionInfos, hasLength(2));
      expect(tester.state(find.byType(EditorPage)), same(standalonePage));
      expect(_editor(tester), same(standaloneEditor));
      expect(standaloneEditor.current!.name, 'c.txt');
      expect(_rootOrder(), ['workspace-root-${fixture.external.path}']);
      fixture.host.resume(fixture.first, workspace: fixture.saved);
      await _waitForProject(tester, fixture.first);
      _expectWorkspaceTree(tester, fixture);
      expect(tester.state(find.byType(EditorPage)), same(pageState));
      expect(_editor(tester), same(editor));
      expect(editor.current, same(buffer));
      expect(buffer.controller.text, dirtyText);
      fixture.expectSavedMembersUnchanged();
      fixture.expectOriginalSources();
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'without a retained host external selection opens a standalone route',
    (tester) async {
      final fixture = (await tester.runAsync(_Fixture.create))!;
      addTearDown(fixture.dispose);
      addTearDown(() => fixture.unmount(tester));
      await fixture.mount(tester, retained: false);
      await fixture.expandWorkspace(tester);
      await tester.tap(_entry(fixture.first, 'a.txt'));
      await _pumpUntil(tester, () => _editor(tester).current != null, 'open A');
      final editor = _editor(tester);
      final pageState = tester.state(find.byType(EditorPage));
      final buffer = editor.current!;
      buffer.controller.text = 'unsaved route A';
      await tester.pump();

      await _chooseProject(tester, fixture.external);
      await _waitForProject(tester, fixture.external);
      expect(_rootOrder(), ['workspace-root-${fixture.external.path}']);
      expect(
        tester.widget<EditorPage>(find.byType(EditorPage)).workspace,
        isNull,
      );
      expect(_editor(tester), isNot(same(editor)));
      await tester.binding.handlePopRoute();
      await _waitForProject(tester, fixture.first);
      _expectWorkspaceTree(tester, fixture);
      expect(tester.state(find.byType(EditorPage)), same(pageState));
      expect(_editor(tester), same(editor));
      expect(editor.current, same(buffer));
      expect(buffer.controller.text, 'unsaved route A');
      expect(buffer.dirty, isTrue);
      fixture.expectSavedMembersUnchanged();
      fixture.expectOriginalSources();
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'standalone selector replaces the tree with the external project',
    (tester) async {
      final fixture = (await tester.runAsync(_Fixture.create))!;
      addTearDown(fixture.dispose);
      addTearDown(() => fixture.unmount(tester));
      await fixture.mount(tester, retained: true, workspace: false);
      expect(_rootOrder(), ['workspace-root-${fixture.first.path}']);
      final firstState = tester.state(find.byType(EditorPage));
      await _chooseProject(tester, fixture.external);
      await _waitForProject(tester, fixture.external);
      expect(_rootOrder(), ['workspace-root-${fixture.external.path}']);
      expect(fixture.host.sessionInfos, hasLength(2));
      expect(
        fixture.host.sessionInfos.every((session) => session.workspace == null),
        isTrue,
      );
      await _chooseProject(tester, fixture.first);
      await _waitForProject(tester, fixture.first);
      expect(_rootOrder(), ['workspace-root-${fixture.first.path}']);
      expect(tester.state(find.byType(EditorPage)), same(firstState));
      expect(fixture.host.sessionInfos, hasLength(2));
      fixture.expectSavedMembersUnchanged();
      expect(tester.takeException(), isNull);
    },
  );
}

EditorController _editor(WidgetTester tester) =>
    tester
            .widget<SelectionToolbarScope>(find.byType(SelectionToolbarScope))
            .editor
        as EditorController;

Finder _root(Project project) =>
    find.byKey(ValueKey('workspace-root-${project.path}'));

Finder _entry(Project project, String name) =>
    find.descendant(of: _root(project), matching: find.text(name));

List<String> _rootOrder() => find
    .byWidgetPredicate(
      (widget) =>
          widget is KeyedSubtree &&
          widget.key is ValueKey<String> &&
          (widget.key as ValueKey<String>).value.startsWith('workspace-root-'),
    )
    .evaluate()
    .map((element) => (element.widget.key as ValueKey<String>).value)
    .toList();

ScrollableState _treeScroll(WidgetTester tester) =>
    tester.state<ScrollableState>(
      find.descendant(
        of: find.byType(FileExplorer),
        matching: find.byType(Scrollable),
      ),
    );

void _expectWorkspaceTree(WidgetTester tester, _Fixture fixture) {
  expect(_rootOrder(), [
    'workspace-root-${fixture.first.path}',
    'workspace-root-${fixture.second.path}',
  ]);
  expect(_entry(fixture.first, 'a.txt').hitTestable(), findsOneWidget);
  expect(_entry(fixture.second, 'b.txt').hitTestable(), findsOneWidget);
  expect(tester.takeException(), isNull);
}

Future<void> _chooseProject(WidgetTester tester, Project project) async {
  final selector = find.descendant(
    of: find.byType(FileExplorer),
    matching: find.byType(PopupMenuButton<Project>),
  );
  expect(selector.hitTestable(), findsOneWidget);
  await tester.tap(selector);
  await _pumpUntil(
    tester,
    () => find
        .byWidgetPredicate(
          (widget) =>
              widget is PopupMenuItem<Project> &&
              widget.value?.id == project.id,
        )
        .evaluate()
        .isNotEmpty,
    'project selector menu',
  );
  final item = find.byWidgetPredicate(
    (widget) =>
        widget is PopupMenuItem<Project> && widget.value?.id == project.id,
  );
  await tester.ensureVisible(item);
  await tester.pump(const Duration(milliseconds: 200));
  expect(item.hitTestable(), findsOneWidget);
  await tester.tap(item);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
}

Future<void> _waitForProject(WidgetTester tester, Project project) async {
  await _pumpUntil(
    tester,
    () =>
        find.byType(EditorPage).evaluate().length == 1 &&
        tester.widget<EditorPage>(find.byType(EditorPage)).project.id ==
            project.id &&
        _root(project).evaluate().isNotEmpty,
    'visible editor ${project.name}',
  );
  final openTree = find.byTooltip('打开文件树').hitTestable();
  if (openTree.evaluate().isNotEmpty) {
    await tester.tap(openTree);
  }
  await _pumpUntil(
    tester,
    () => _root(project).hitTestable().evaluate().isNotEmpty,
    'interactive tree ${project.name}',
  );
}

Future<void> _pumpUntil(
  WidgetTester tester,
  bool Function() done,
  String operation,
) async {
  for (var attempt = 0; attempt < 150 && !done(); attempt++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 5)),
    );
    await tester.pump(const Duration(milliseconds: 20));
  }
  expect(done(), isTrue, reason: '$operation did not finish');
  await tester.pump(const Duration(milliseconds: 300));
}

class _Fixture {
  _Fixture(
    this.directory,
    this.projects,
    this.workspaces,
    this.saved,
    this.first,
    this.second,
    this.external,
  );

  final Directory directory;
  final ProjectStore projects;
  final WorkspaceStore workspaces;
  final SavedWorkspace saved;
  final Project first;
  final Project second;
  final Project external;
  final auth = AuthStore();
  final settings = SettingsStore();
  final host = RetainedEditorController();

  static Future<_Fixture> create() async {
    final directory = await Directory.systemTemp.createTemp(
      'workspace_switch_',
    );
    final projects = ProjectStore(
      storageFile: File(p.join(directory.path, 'projects.json')),
    );
    await projects.load();
    final registered = <Project>[];
    for (final letter in ['a', 'b', 'c']) {
      final root = Directory(p.join(directory.path, 'project_$letter'));
      await Directory(p.join(root.path, 'src_$letter')).create(recursive: true);
      await File(
        p.join(root.path, 'src_$letter', '$letter.txt'),
      ).writeAsString('source $letter');
      if (letter == 'b') {
        for (var index = 0; index < 30; index++) {
          await File(
            p.join(root.path, 'src_b', 'z_$index.txt'),
          ).writeAsString('tail');
        }
      }
      final result = await projects.addExisting(root.path);
      if (result.project == null) throw StateError(result.error!);
      registered.add(result.project!);
    }
    final workspaces = WorkspaceStore(
      root: Directory(p.join(directory.path, 'workspaces')),
    );
    await workspaces.load();
    final result = await workspaces.save(
      name: '工作区 A+B',
      members: [registered[0], registered[1]],
      primary: registered[0],
    );
    if (result.workspace == null) throw StateError(result.error!);
    return _Fixture(
      directory,
      projects,
      workspaces,
      result.workspace!,
      registered[0],
      registered[1],
      registered[2],
    );
  }

  Future<void> mount(
    WidgetTester tester, {
    required bool retained,
    bool workspace = true,
  }) async {
    tester.view.physicalSize = const Size(1100, 850);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(platform: TargetPlatform.ohos),
        locale: const Locale('zh', 'CN'),
        supportedLocales: const [Locale('zh', 'CN')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        navigatorObservers: retained ? [host.navigatorObserver] : [],
        builder: retained
            ? (context, child) =>
                  RetainedEditorHost(controller: host, child: child!)
            : null,
        home: retained
            ? const Scaffold(body: Text('首页'))
            : EditorPage(
                project: first,
                auth: auth,
                store: projects,
                settings: settings,
                workspace: workspace ? saved : null,
                workspaceMembers: workspace ? [first, second] : const [],
                workspaceStore: workspaces,
              ),
      ),
    );
    if (retained) {
      host.open(
        project: first,
        auth: auth,
        store: projects,
        settings: settings,
        workspace: workspace ? saved : null,
        workspaceProjects: workspace ? [first, second] : const [],
        workspaceStore: workspaces,
      );
    }
    await _waitForProject(tester, first);
    await _pumpUntil(
      tester,
      () =>
          _entry(first, 'src_a').hitTestable().evaluate().isNotEmpty &&
          (!workspace ||
              _entry(second, 'src_b').hitTestable().evaluate().isNotEmpty),
      'workspace directory reads',
    );
  }

  Future<void> expandWorkspace(WidgetTester tester) async {
    await tester.tap(_entry(first, 'src_a'));
    await tester.tap(_entry(second, 'src_b'));
    await _pumpUntil(
      tester,
      () =>
          _entry(first, 'a.txt').evaluate().isNotEmpty &&
          _entry(second, 'b.txt').evaluate().isNotEmpty,
      'workspace expansion',
    );
  }

  void expectSavedMembersUnchanged() {
    final document =
        jsonDecode(
              File(
                p.join(directory.path, 'workspaces', '${saved.id}.json'),
              ).readAsStringSync(),
            )
            as Map<String, dynamic>;
    expect(
      (document['members'] as List).map(
        (member) => (member as Map<String, dynamic>)['projectId'],
      ),
      [first.id, second.id],
    );
    expect(workspaces.byId(saved.id)!.memberPaths, [first.path, second.path]);
  }

  void expectOriginalSources() {
    for (final pair in [(first, 'a'), (second, 'b'), (external, 'c')]) {
      expect(
        File(
          p.join(pair.$1.path, 'src_${pair.$2}', '${pair.$2}.txt'),
        ).readAsStringSync(),
        'source ${pair.$2}',
      );
    }
  }

  Future<void> unmount(WidgetTester tester) async {
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpWidget(const SizedBox.shrink());
    var drained = false;
    final pending = Future.wait([
      workspaces.settle(),
      projects.refresh(),
      for (final project in [first, second, external])
        ProjectHistory.load(project.path),
    ]);
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
