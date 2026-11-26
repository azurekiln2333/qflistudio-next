import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:qfli_studio_core/editor/project_history.dart';
import 'package:qfli_studio_core/editor/retained_editor_host.dart';
import 'package:qfli_studio_core/models/project.dart';
import 'package:qfli_studio_core/services/studio_profile.dart';
import 'package:qfli_studio_core/store/auth_store.dart';
import 'package:qfli_studio_core/store/project_store.dart';
import 'package:qfli_studio_core/store/settings_store.dart';
import 'package:qfli_studio_core/workspace/saved_workspace.dart';
import 'package:qfli_studio_core/workspace/saved_workspaces_tab.dart';
import 'package:qfli_studio_core/workspace/workspace_store.dart';

const _cursor = FileCursor(
  baseIndex: 0,
  baseOffset: 0,
  extentIndex: 0,
  extentOffset: 0,
);

/// Home workspace cards must not act on their captured snapshot: the store can
/// publish a newer session, and the record can be deleted between build and tap.
void main() {
  late _Fixture fixture;
  StudioProfile? previous;

  setUp(() async {
    previous = StudioProfile.current;
    StudioProfile.current = const StudioProfile(
      id: 'main-workspaces-tab-test',
      appTitle: 'QFLIStudio+',
      templates: [],
      productKey: StudioProductCatalog.qfliStudioKey,
    );
    fixture = await _Fixture.create();
  });

  tearDown(() async {
    StudioProfile.current = previous;
    fixture.dispose();
  });

  testWidgets('tapping a card hands the newest saved session to the host', (
    tester,
  ) async {
    final controller = RetainedEditorController();
    addTearDown(controller.dispose);
    // Store IO must not run directly in a testWidgets body: the store queues
    // writes on timers that the fake zone never advances, which deadlocks the
    // first pump. Do the seeding in the real zone.
    late SavedWorkspace workspace;
    await tester.runAsync(() async {
      workspace = await fixture.saveWorkspace();
      await fixture.saveSession(workspace, 'older.dart');
    });
    await fixture.mount(tester, controller);

    // The store publishes a newer session after the card was built.
    await tester.runAsync(() => fixture.saveSession(workspace, 'newest.dart'));
    await tester.pump();

    await tester.tap(find.text(workspace.name));
    // _open resolves members with real filesystem checks before the host opens.
    for (var attempt = 0; attempt < 200; attempt++) {
      if (controller.sessionInfos.isNotEmpty) break;
      await tester.pump(const Duration(milliseconds: 20));
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 5)),
      );
    }
    expect(controller.sessionInfos, hasLength(1));

    final info = controller.sessionInfos.single;
    expect(info.workspace?.id, workspace.id);
    expect(
      info.workspace?.session.documents.map((d) => d.relativePath),
      ['newest.dart'],
      reason:
          'the host must receive the latest document, not the card snapshot',
    );
  });

  testWidgets('tapping a card whose record was deleted does not open it', (
    tester,
  ) async {
    final controller = RetainedEditorController();
    addTearDown(controller.dispose);
    final workspace = (await tester.runAsync(fixture.saveWorkspace))!;
    await fixture.mount(tester, controller);

    // Delete completes (and notifies) before the rebuild reaches the card.
    await tester.runAsync(() => fixture.workspaceStore.remove(workspace.id));
    await tester.tap(find.text(workspace.name), warnIfMissed: false);
    // _open refreshes the list before reporting; real IO needs runAsync time.
    for (var attempt = 0; attempt < 60; attempt++) {
      if (find.textContaining('已被删除').evaluate().isNotEmpty) break;
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 5)),
      );
      await tester.pump(const Duration(milliseconds: 20));
    }

    expect(controller.sessionInfos, isEmpty);
    expect(find.textContaining('已被删除'), findsOneWidget);
  });
}

class _Fixture {
  _Fixture(
    this.directory,
    this.store,
    this.workspaceStore,
    this.first,
    this.second,
  );

  final Directory directory;
  final ProjectStore store;
  final WorkspaceStore workspaceStore;
  final Project first;
  final Project second;
  final auth = AuthStore();
  final settings = SettingsStore();

  static Future<_Fixture> create() async {
    final directory = await Directory.systemTemp.createTemp('qfli_ws_tab_');
    for (final name in ['dart', 'cpp']) {
      Directory(p.join(directory.path, name)).createSync(recursive: true);
      File(p.join(directory.path, name, 'main.dart')).writeAsStringSync('x');
    }
    final registry = File(p.join(directory.path, 'projects.json'))
      ..writeAsStringSync('{"projects": []}');
    final store = ProjectStore(storageFile: registry);
    await store.load();
    await store.addExisting(p.join(directory.path, 'dart'));
    await store.addExisting(p.join(directory.path, 'cpp'));
    final workspaceStore = WorkspaceStore(
      root: Directory(p.join(directory.path, 'workspaces')),
    );
    await workspaceStore.load();
    return _Fixture(
      directory,
      store,
      workspaceStore,
      store.projects.singleWhere((project) => project.name == 'dart'),
      store.projects.singleWhere((project) => project.name == 'cpp'),
    );
  }

  Future<SavedWorkspace> saveWorkspace() async {
    final result = await workspaceStore.save(
      name: 'Workbench',
      members: [first, second],
      primary: first,
    );
    return result.workspace!;
  }

  Future<void> saveSession(
    SavedWorkspace workspace,
    String relativePath,
  ) async {
    final latest = workspaceStore.byId(workspace.id) ?? workspace;
    await workspaceStore.saveSession(
      latest,
      WorkspaceSessionSnapshot(
        primaryPath: first.path,
        documents: [
          ProjectDocumentSession(
            projectPath: first.path,
            relativePath: relativePath,
            cursor: _cursor,
            isActive: true,
          ),
        ],
      ),
    );
  }

  Future<void> mount(
    WidgetTester tester,
    RetainedEditorController controller,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: RetainedEditorScope(
          controller: controller,
          child: Scaffold(
            body: SavedWorkspacesTab(
              store: store,
              auth: auth,
              settings: settings,
              workspaceStore: workspaceStore,
            ),
          ),
        ),
      ),
    );
    for (var attempt = 0; attempt < 60; attempt++) {
      if (find.text('Workbench').evaluate().isNotEmpty) break;
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 5)),
      );
      await tester.pump(const Duration(milliseconds: 20));
    }
    expect(find.text('Workbench'), findsOneWidget);
  }

  void dispose() {
    auth.dispose();
    settings.dispose();
    store.dispose();
    workspaceStore.dispose();
    try {
      directory.deleteSync(recursive: true);
    } on FileSystemException {
      // A queued workspace write may still hold a handle on Windows.
    }
  }
}
