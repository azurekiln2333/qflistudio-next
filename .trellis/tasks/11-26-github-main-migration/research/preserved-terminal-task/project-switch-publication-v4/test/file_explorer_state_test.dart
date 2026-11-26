import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:qfli_studio_core/editor/editor_controller.dart';
import 'package:qfli_studio_core/editor/file_explorer.dart';
import 'package:qfli_studio_core/editor/project_history.dart';
import 'package:qfli_studio_core/models/project.dart';
import 'package:qfli_studio_core/services/studio_profile.dart';
import 'package:qfli_studio_core/store/project_store.dart';
import 'package:qfli_studio_core/store/settings_store.dart';
import 'package:qfli_studio_core/services/recycle_bin.dart';

void main() {
  late _ExplorerFixture fixture;
  StudioProfile? previous;

  setUp(() async {
    previous = StudioProfile.current;
    // Legacy child contract: multi-root membership and expansion live in the
    // project's history. The main release uses explicit saved workspaces.
    StudioProfile.current = const StudioProfile(
      id: 'explorer-test',
      appTitle: 'Explorer',
      templates: [],
      isOffline: true,
      offlineOnly: true,
      productKey: StudioProductCatalog.forgeKey,
    );
    fixture = await _ExplorerFixture.create();
  });

  tearDown(() {
    StudioProfile.current = previous;
  });

  testWidgets('reconstructed explorer restores nested expansion', (
    tester,
  ) async {
    await fixture.mount(tester);
    await _waitForIo(tester, () => find.text('src').evaluate().isNotEmpty);
    await tester.tap(find.text('src'));
    await _waitForIo(tester, () => find.text('nested').evaluate().isNotEmpty);
    await tester.tap(find.text('nested'));
    await _waitForIo(
      tester,
      () => find.text('data.json').evaluate().isNotEmpty,
    );

    // Rebuild immediately; the unawaited expansion save may still be pending.
    await tester.pumpWidget(const SizedBox.shrink());
    await fixture.mount(tester);
    await _waitForIo(
      tester,
      () => find.text('data.json').evaluate().isNotEmpty,
    );
    expect(find.text('nested'), findsOneWidget);
    expect(find.text('data.json'), findsOneWidget);
    await fixture.dispose(tester);
  });

  testWidgets('closing and reopening the drawer keeps expanded folders', (
    tester,
  ) async {
    await fixture.mount(tester, drawer: true);
    await tester.tap(find.byTooltip('Open explorer'));
    await tester.pumpAndSettle();
    await _waitForIo(tester, () => find.text('src').evaluate().isNotEmpty);
    await tester.tap(find.text('src'));
    await _waitForIo(tester, () => find.text('nested').evaluate().isNotEmpty);
    await tester.tap(find.text('nested'));
    await _waitForIo(
      tester,
      () => find.text('data.json').evaluate().isNotEmpty,
    );

    await tester.tapAt(const Offset(750, 500));
    await tester.pumpAndSettle();
    expect(find.text('data.json'), findsNothing);
    await tester.tap(find.byTooltip('Open explorer'));
    await tester.pumpAndSettle();
    await _waitForIo(
      tester,
      () => find.text('data.json').evaluate().isNotEmpty,
    );
    expect(find.text('nested'), findsOneWidget);
    await fixture.dispose(tester);
  });

  testWidgets('rapid switches keep each project expansion and file ownership', (
    tester,
  ) async {
    await tester.runAsync(() async {
      await ProjectHistory.saveExpandedDirs(fixture.first.path, ['src']);
      await ProjectHistory.saveExpandedDirs(fixture.second.path, ['other']);
    });
    await fixture.mount(tester);

    final switcher = tester.widget<PopupMenuButton<Project>>(
      find.byType(PopupMenuButton<Project>),
    );
    // Queue restoration for three roots before their asynchronous reads finish.
    switcher.onSelected!(fixture.second);
    switcher.onSelected!(fixture.first);
    switcher.onSelected!(fixture.second);
    await _waitForIo(
      tester,
      () => find.text('second.json').evaluate().isNotEmpty,
    );
    expect(find.text('nested'), findsNothing);
    expect(find.text('first.json'), findsNothing);
    expect(fixture.store.lastBrowsedProjectId, fixture.second.id);

    await tester.tap(find.text('second.json'));
    await _waitForIo(tester, () => fixture.editor.current != null);
    expect(fixture.editor.current!.projectRootPath, fixture.second.path);
    expect(fixture.editor.current!.ownerProjectName, fixture.second.name);

    switcher.onSelected!(fixture.first);
    await _waitForIo(
      tester,
      () => find.text('first.json').evaluate().isNotEmpty,
    );
    expect(find.text('second.json'), findsNothing);
    await fixture.dispose(tester);
  });

  testWidgets('workspace displays local roots and opens both in shared tabs', (
    tester,
  ) async {
    await fixture.mount(tester);
    await fixture.selectSecondRoot(tester);
    expect(fixture.rootFinder(fixture.first), findsOneWidget);
    expect(fixture.rootFinder(fixture.second), findsOneWidget);
    await tester.tap(fixture.entry(fixture.first, 'src'));
    await _waitForIo(
      tester,
      () => fixture.entry(fixture.first, 'nested').evaluate().isNotEmpty,
    );
    await tester.tap(fixture.entry(fixture.first, 'nested'));
    await _waitForIo(
      tester,
      () => fixture.entry(fixture.first, 'data.json').evaluate().isNotEmpty,
    );
    await tester.tap(fixture.entry(fixture.first, 'data.json'));
    await _waitForIo(tester, () => fixture.editor.files.length == 1);

    await tester.tap(fixture.entry(fixture.second, 'other'));
    await _waitForIo(
      tester,
      () => fixture.entry(fixture.second, 'second.json').evaluate().isNotEmpty,
    );
    await tester.tap(fixture.entry(fixture.second, 'second.json'));
    await _waitForIo(tester, () => fixture.editor.files.length == 2);
    expect(fixture.editor.files.map((file) => file.projectRootPath), [
      fixture.first.path,
      fixture.second.path,
    ]);
    expect(fixture.editor.files.map((file) => file.ownerProjectName), [
      fixture.first.name,
      fixture.second.name,
    ]);
    await fixture.dispose(tester);
  });

  testWidgets(
    'workspace create and backed-up delete operate on the selected owner root',
    (tester) async {
      final previousBase = RecycleBin.baseOverride;
      RecycleBin.baseOverride = fixture.root.path;
      addTearDown(() => RecycleBin.baseOverride = previousBase);
      await fixture.mount(tester);
      await fixture.selectSecondRoot(tester);
      await tester.longPress(
        fixture.entry(fixture.second, fixture.second.name),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('新建文件夹'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.byType(TextField),
        ),
        'generated',
      );
      await tester.tap(find.widgetWithText(FilledButton, '创建'));
      final created = Directory(p.join(fixture.second.path, 'generated'));
      await _waitForIo(
        tester,
        () =>
            created.existsSync() &&
            fixture.entry(fixture.second, 'generated').evaluate().isNotEmpty,
      );
      expect(
        Directory(p.join(fixture.first.path, 'generated')).existsSync(),
        isFalse,
      );
      File(
        p.join(created.path, 'keep.txt'),
      ).writeAsStringSync('preserve in recycle bin');
      await tester.longPress(fixture.entry(fixture.second, 'generated'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('删除'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, '删除'));
      await _waitForIo(tester, () => !created.existsSync());
      final metadata =
          Directory(p.join(fixture.root.path, 'recyclebin', 'files_bin'))
              .listSync()
              .whereType<File>()
              .singleWhere((file) => file.path.endsWith('.metadata.json'));
      final saved =
          jsonDecode(metadata.readAsStringSync()) as Map<String, dynamic>;
      expect(saved['projectName'], fixture.second.name);
      expect(saved['originalPath'], p.normalize(created.path));
      expect(
        File(
          p.join(fixture.first.path, 'src', 'first.json'),
        ).readAsStringSync(),
        '{}',
      );
      await fixture.dispose(tester);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('workspace membership and independent root expansion restore', (
    tester,
  ) async {
    await fixture.mount(tester);
    await fixture.selectSecondRoot(tester);
    await tester.tap(fixture.entry(fixture.first, 'src'));
    await _waitForIo(
      tester,
      () => fixture.entry(fixture.first, 'first.json').evaluate().isNotEmpty,
    );
    await tester.tap(fixture.entry(fixture.second, 'other'));
    await _waitForIo(
      tester,
      () => fixture.entry(fixture.second, 'second.json').evaluate().isNotEmpty,
    );
    await tester.tap(fixture.entry(fixture.second, fixture.second.name));
    await tester.pump();
    expect(fixture.entry(fixture.second, 'other'), findsNothing);

    await tester.pumpWidget(const SizedBox.shrink());
    await fixture.mount(tester);
    await _waitForIo(
      tester,
      () =>
          fixture.entry(fixture.first, 'first.json').evaluate().isNotEmpty &&
          fixture.rootFinder(fixture.second).evaluate().isNotEmpty,
    );
    expect(fixture.rootFinder(fixture.second), findsOneWidget);
    expect(fixture.entry(fixture.second, 'other'), findsNothing);
    await tester.tap(fixture.entry(fixture.second, fixture.second.name));
    await _waitForIo(
      tester,
      () => fixture.entry(fixture.second, 'second.json').evaluate().isNotEmpty,
    );
    await fixture.dispose(tester);
  });

  testWidgets('creating inside a collapsed folder persists its expansion', (
    tester,
  ) async {
    await fixture.mount(tester);
    await _waitForIo(tester, () => find.text('src').evaluate().isNotEmpty);
    expect(find.text('first.json'), findsNothing);
    await tester.longPress(fixture.entry(fixture.first, 'src'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('新建文件夹'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.byType(TextField),
      ),
      'generated',
    );
    await tester.tap(find.widgetWithText(FilledButton, '创建'));
    await _waitForIo(
      tester,
      () => fixture.entry(fixture.first, 'generated').evaluate().isNotEmpty,
    );
    await tester.pumpWidget(const SizedBox.shrink());
    ProjectSession? saved;
    ProjectHistory.load(fixture.first.path).then((value) => saved = value);
    await _waitForIo(tester, () => saved != null);
    expect(saved!.expandedDirs, contains('src'));
    await fixture.mount(tester);
    await _waitForIo(
      tester,
      () => fixture.entry(fixture.first, 'generated').evaluate().isNotEmpty,
    );
    expect(find.text('first.json'), findsOneWidget);
    await fixture.dispose(tester);
  });

  testWidgets('backed-up deletion finishes safely after editor disposal', (
    tester,
  ) async {
    final previousBase = RecycleBin.baseOverride;
    RecycleBin.baseOverride = fixture.root.path;
    addTearDown(() => RecycleBin.baseOverride = previousBase);
    final source = Directory(p.join(fixture.first.path, 'src'));
    await fixture.mount(tester);
    await _waitForIo(tester, () => find.text('src').evaluate().isNotEmpty);
    await tester.longPress(fixture.entry(fixture.first, 'src'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('删除'));
    await tester.pumpAndSettle();
    // Invoke confirmation and close the page before draining real backup IO.
    tester
        .widget<FilledButton>(find.widgetWithText(FilledButton, '删除'))
        .onPressed!();
    await tester.pumpWidget(const SizedBox.shrink());
    expect(source.existsSync(), isTrue);
    fixture.closeEditor();
    await _waitForIo(tester, () => !source.existsSync());
    final metadata =
        Directory(p.join(fixture.root.path, 'recyclebin', 'files_bin'))
            .listSync()
            .whereType<File>()
            .singleWhere((file) => file.path.endsWith('.metadata.json'));
    expect(
      (jsonDecode(metadata.readAsStringSync()) as Map)['originalPath'],
      p.normalize(source.path),
    );
    await fixture.dispose(tester);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'workspace removal preserves source files, open tabs and expansion',
    (tester) async {
      await fixture.mount(tester);
      await fixture.selectSecondRoot(tester);
      await tester.tap(fixture.entry(fixture.second, 'other'));
      await _waitForIo(
        tester,
        () =>
            fixture.entry(fixture.second, 'second.json').evaluate().isNotEmpty,
      );
      await tester.tap(fixture.entry(fixture.second, 'second.json'));
      await _waitForIo(tester, () => fixture.editor.files.length == 1);
      await fixture.selectSecondRoot(tester, selected: false);
      expect(fixture.rootFinder(fixture.second), findsNothing);
      expect(fixture.editor.files.single.projectRootPath, fixture.second.path);
      expect(
        File(p.join(fixture.second.path, 'other', 'second.json')).existsSync(),
        isTrue,
      );
      await fixture.selectSecondRoot(tester);
      await _waitForIo(
        tester,
        () =>
            fixture.entry(fixture.second, 'second.json').evaluate().isNotEmpty,
      );
      await fixture.dispose(tester);
    },
  );

  testWidgets(
    'workspace search covers both roots and preserves result ownership',
    (tester) async {
      await fixture.mount(tester);
      await fixture.selectSecondRoot(tester);
      await tester.tap(find.byTooltip('搜索文件'));
      await tester.pump();
      await tester.enterText(find.byType(TextField), 'second.json');
      await tester.pump();
      expect(find.text('first/other/second.json'), findsOneWidget);
      expect(find.text('second/other/second.json'), findsOneWidget);
      await tester.tap(find.text('second/other/second.json'));
      await _waitForIo(tester, () => fixture.editor.current != null);
      expect(fixture.editor.current!.projectRootPath, fixture.second.path);
      expect(fixture.editor.current!.ownerProjectName, fixture.second.name);
      await fixture.dispose(tester);
    },
  );

  for (final scale in [1.0, 2.0]) {
    testWidgets('workspace toolbar fits a 280px sidebar at text scale $scale', (
      tester,
    ) async {
      await fixture.mount(tester, width: 280, scale: scale);
      await _waitForIo(tester, () => find.text('src').evaluate().isNotEmpty);
      expect(tester.takeException(), isNull);
      await tester.tap(find.byTooltip('工作区项目'));
      await tester.pumpAndSettle();
      expect(find.byType(CheckboxListTile), findsNWidgets(2));
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('取消'));
      await tester.pumpAndSettle();
      await fixture.dispose(tester);
    });
  }
}

class _ExplorerFixture {
  _ExplorerFixture(this.root, this.store, this.first, this.second)
    : editor = EditorController(project: first);

  final Directory root;
  final ProjectStore store;
  final Project first;
  final Project second;
  final EditorController editor;
  final settings = SettingsStore();
  bool _registeredTeardown = false;
  bool _disposed = false;
  bool _editorDisposed = false;

  void closeEditor() {
    if (_editorDisposed) return;
    _editorDisposed = true;
    editor.dispose();
  }

  Finder rootFinder(Project project) =>
      find.byKey(ValueKey('workspace-root-${project.path}'));

  Finder entry(Project project, String name) =>
      find.descendant(of: rootFinder(project), matching: find.text(name));

  Future<void> selectSecondRoot(
    WidgetTester tester, {
    bool selected = true,
  }) async {
    await tester.tap(find.byTooltip('工作区项目'));
    await tester.pumpAndSettle();
    final choice = find.byKey(ValueKey('workspace-project-${second.id}'));
    final tile = tester.widget<CheckboxListTile>(choice);
    if (tile.value != selected) await tester.tap(choice);
    await tester.tap(find.text('应用'));
    await tester.pumpAndSettle();
    await _waitForIo(
      tester,
      () =>
          rootFinder(second).evaluate().isNotEmpty == selected &&
          entry(first, 'src').evaluate().isNotEmpty &&
          (!selected || entry(second, 'other').evaluate().isNotEmpty),
    );
  }

  static Future<_ExplorerFixture> create() async {
    final root = await Directory.systemTemp.createTemp('qfli_explorer_state_');
    for (final name in ['first', 'second']) {
      Directory(
        p.join(root.path, name, 'src', 'nested'),
      ).createSync(recursive: true);
      Directory(p.join(root.path, name, 'other')).createSync();
      File(
        p.join(root.path, name, 'src', 'nested', 'data.json'),
      ).writeAsStringSync('{}');
      File(
        p.join(root.path, name, 'src', 'first.json'),
      ).writeAsStringSync('{}');
      File(
        p.join(root.path, name, 'other', 'second.json'),
      ).writeAsStringSync('{}');
    }
    final store = ProjectStore(
      storageFile: File(p.join(root.path, 'registry.json')),
    );
    await store.load();
    await store.addExisting(p.join(root.path, 'first'));
    await store.addExisting(p.join(root.path, 'second'));
    return _ExplorerFixture(
      root,
      store,
      store.projects.singleWhere((project) => project.name == 'first'),
      store.projects.singleWhere((project) => project.name == 'second'),
    );
  }

  Future<void> mount(
    WidgetTester tester, {
    bool drawer = false,
    double? width,
    double scale = 1,
  }) async {
    if (!_registeredTeardown) {
      _registeredTeardown = true;
      tester.view.physicalSize = const Size(900, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      addTearDown(() => dispose(tester));
    }
    Widget explorer() => FileExplorer(
      project: first,
      editor: editor,
      store: store,
      settings: settings,
    );
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(scale)),
          child: child!,
        ),
        home: Scaffold(
          drawer: drawer ? Drawer(width: 500, child: explorer()) : null,
          appBar: drawer
              ? AppBar(
                  leading: Builder(
                    builder: (context) => IconButton(
                      tooltip: 'Open explorer',
                      icon: const Icon(Icons.menu),
                      onPressed: Scaffold.of(context).openDrawer,
                    ),
                  ),
                )
              : null,
          body: drawer
              ? const SizedBox.expand()
              : Align(
                  alignment: Alignment.topLeft,
                  child: SizedBox(
                    width: width ?? double.infinity,
                    child: explorer(),
                  ),
                ),
        ),
      ),
    );
  }

  Future<void> dispose(WidgetTester tester) async {
    if (_disposed) return;
    _disposed = true;
    await tester.pumpWidget(const SizedBox.shrink());
    var drained = false;
    Future.wait([
      ProjectHistory.load(first.path),
      ProjectHistory.load(second.path),
      store.refresh(),
    ]).then((_) => drained = true);
    await _waitForIo(tester, () => drained);
    closeEditor();
    settings.dispose();
    store.dispose();
    await tester.runAsync(() => root.delete(recursive: true));
  }
}

Future<void> _waitForIo(WidgetTester tester, bool Function() complete) async {
  for (var attempt = 0; attempt < 100 && !complete(); attempt++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 5)),
    );
    await tester.pump();
  }
  expect(complete(), isTrue, reason: 'File explorer IO did not finish');
}
