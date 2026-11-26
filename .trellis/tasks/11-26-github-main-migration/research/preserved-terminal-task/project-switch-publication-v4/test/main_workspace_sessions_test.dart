import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:qfli_studio_core/editor/editor_controller.dart';
import 'package:qfli_studio_core/editor/editor_page.dart';
import 'package:qfli_studio_core/editor/editor_problems_bar.dart';
import 'package:qfli_studio_core/editor/project_history.dart';
import 'package:qfli_studio_core/editor/retained_editor_host.dart';
import 'package:qfli_studio_core/models/project.dart';
import 'package:qfli_studio_core/services/studio_profile.dart';
import 'package:qfli_studio_core/store/auth_store.dart';
import 'package:qfli_studio_core/store/project_store.dart';
import 'package:qfli_studio_core/store/settings_store.dart';
import 'package:qfli_studio_core/workspace/saved_workspace.dart';
import 'package:qfli_studio_core/workspace/workspace_store.dart';

const _cursor = FileCursor(
  baseIndex: 0,
  baseOffset: 0,
  extentIndex: 0,
  extentOffset: 0,
);

/// Main-release (`qflistudio`) workspace contract. Child-product legacy tests
/// stay in workspace_editor_session_test.dart / file_explorer_state_test.dart.
void main() {
  late _Fixture fixture;
  StudioProfile? previous;

  setUp(() async {
    previous = StudioProfile.current;
    StudioProfile.current = const StudioProfile(
      id: 'main-release-test',
      appTitle: 'QFLIStudio+',
      templates: [],
      productKey: StudioProductCatalog.qfliStudioKey,
    );
    fixture = await _Fixture.create();
  });

  tearDown(() async {
    StudioProfile.current = previous;
    fixture.auth.dispose();
    fixture.settings.dispose();
    fixture.store.dispose();
    try {
      await fixture.directory.delete(recursive: true);
    } on FileSystemException {
      // A queued session write may still hold a handle on Windows.
    }
  });

  test('promoted standalone session is distinct and standalone reopens reuse one buffer session', () {
    final controller = RetainedEditorController();
    addTearDown(controller.dispose);
    final workspace = fixture.workspace([fixture.first, fixture.second]);

    controller.open(
      project: fixture.first,
      auth: fixture.auth,
      store: fixture.store,
      settings: fixture.settings,
    );
    controller.attachActiveWorkspace(workspace, [
      fixture.first,
      fixture.second,
    ]);
    // The first standalone open after promotion creates a fresh session.
    controller.open(
      project: fixture.first,
      auth: fixture.auth,
      store: fixture.store,
      settings: fixture.settings,
    );
    // The next one must reuse that standalone buffer session, not allocate #3.
    controller.open(
      project: fixture.first,
      auth: fixture.auth,
      store: fixture.store,
      settings: fixture.settings,
    );
    expect(controller.projects, hasLength(2));
  });

  test('workspace identity is the workspace id and follows a surviving primary', () {
    final controller = RetainedEditorController();
    addTearDown(controller.dispose);
    final workspace = fixture.workspace([fixture.first, fixture.second]);

    controller.open(
      project: fixture.first,
      auth: fixture.auth,
      store: fixture.store,
      settings: fixture.settings,
      workspace: workspace,
      workspaceProjects: [fixture.first, fixture.second],
      workspaceStore: fixture.workspaceStore,
    );
    // Primary A is gone; Home reopens the same W with surviving primary B.
    controller.open(
      project: fixture.second,
      auth: fixture.auth,
      store: fixture.store,
      settings: fixture.settings,
      workspace: workspace,
      workspaceProjects: [fixture.second],
      workspaceStore: fixture.workspaceStore,
    );
    expect(controller.projects, hasLength(1));
    expect(controller.activeProject?.path, fixture.second.path);
  });

  testWidgets(
    'main standalone open ignores legacy cross-root history',
    (tester) async {
      await tester.runAsync(
        () => ProjectHistory.save(
          fixture.first.path,
          cursors: const {},
          openFiles: const [],
          activeFile: null,
          documents: [
            ProjectDocumentSession(
              projectPath: fixture.second.path,
              relativePath: 'other.cpp',
              cursor: _cursor,
              isActive: true,
            ),
            ProjectDocumentSession(
              projectPath: fixture.first.path,
              relativePath: 'main.dart',
              cursor: _cursor,
            ),
          ],
        ),
      );
      final editor = await fixture.mount(tester);
      expect(editor.files.map((file) => file.name), ['main.dart']);
      expect(editor.files.single.projectRootPath, fixture.first.path);
      await fixture.unmount(tester);
    },
  );

  testWidgets(
    'workspace session restores owners and saves only to the workspace document',
    (tester) async {
      late SavedWorkspace workspace;
      await tester.runAsync(() async {
        final created = await fixture.workspaceStore.save(
          name: 'Main workbench',
          members: [fixture.first, fixture.second],
          primary: fixture.first,
        );
        workspace = created.workspace!;
        await fixture.workspaceStore.saveSession(
          workspace,
          WorkspaceSessionSnapshot(
            primaryPath: fixture.first.path,
            documents: [
              ProjectDocumentSession(
                projectPath: fixture.second.path,
                relativePath: 'other.cpp',
                cursor: _cursor,
                isActive: true,
              ),
              ProjectDocumentSession(
                projectPath: fixture.first.path,
                relativePath: 'main.dart',
                cursor: _cursor,
              ),
            ],
          ),
        );
      });
      final savedWorkspace =
          fixture.workspaceStore.byId(workspace.id) ?? workspace;
      expect(savedWorkspace.session.documents, hasLength(2));
      final editor = await fixture.mount(
        tester,
        workspace: savedWorkspace,
        members: [fixture.first, fixture.second],
        expected: 2,
      );
      expect(editor.files.map((file) => file.name), ['other.cpp', 'main.dart']);
      expect(editor.files.first.projectRootPath, fixture.second.path);
      await fixture.unmount(tester);
      // Session writes are ordered; pump real IO until the in-memory document
      // reflects the editor's saved snapshot.
      for (var attempt = 0; attempt < 100; attempt++) {
        final saved = fixture.workspaceStore.byId(workspace.id);
        if (saved != null && saved.session.documents.length == 2) break;
        await tester.pump(const Duration(milliseconds: 50));
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 2)),
        );
      }
      expect(
        fixture.workspaceStore.byId(workspace.id)!.session.documents,
        hasLength(2),
      );
      final history = await tester.runAsync(
        () => ProjectHistory.load(fixture.first.path),
      );
      expect(history!.documents, isEmpty);
    },
  );

  testWidgets(
    'workspace shrink closes clean tabs, keeps dirty orphans and never writes them back',
    (tester) async {
      late SavedWorkspace workspace;
      await tester.runAsync(() async {
        final created = await fixture.workspaceStore.save(
          name: 'Main workbench',
          members: [fixture.first, fixture.second],
          primary: fixture.first,
        );
        workspace = created.workspace!;
        await fixture.workspaceStore.saveSession(
          workspace,
          WorkspaceSessionSnapshot(
            primaryPath: fixture.first.path,
            documents: [
              ProjectDocumentSession(
                projectPath: fixture.first.path,
                relativePath: 'main.dart',
                cursor: _cursor,
              ),
              ProjectDocumentSession(
                projectPath: fixture.second.path,
                relativePath: 'other.cpp',
                cursor: _cursor,
              ),
            ],
          ),
        );
      });
      final editor = await fixture.mount(
        tester,
        workspace: fixture.workspaceStore.byId(workspace.id) ?? workspace,
        members: [fixture.first, fixture.second],
        expected: 2,
      );
      final orphan = editor.files.firstWhere(
        (file) => file.name == 'main.dart',
      );
      orphan.controller.text = 'unsaved edit';
      await tester.pump();

      // The workspace lost member A while this session stayed live. Keep the
      // persisted workspace identity: a different id would be a deleted
      // workspace, whose session writes are a no-op.
      final shrunk = fixture.workspace([fixture.second], id: workspace.id);
      await fixture.mount(
        tester,
        workspace: shrunk,
        project: fixture.second,
        members: [fixture.second],
        // A is kept only as a dirty orphan; B stays a normal member tab.
        expected: 2,
      );
      expect(
        editor.files.map((file) => file.name),
        ['main.dart', 'other.cpp'],
      );
      expect(
        editor.files.firstWhere((file) => file.name == 'main.dart').dirty,
        isTrue,
      );
      await tester.pump();
      expect(find.textContaining('另存为'), findsWidgets);
      // The deleted project directory is never recreated by autosave.
      expect(
        File(p.join(fixture.first.path, 'main.dart')).readAsStringSync(),
        'one\ntwo',
      );

      // Select the orphaned dirty tab and use the real Run gesture: it must be
      // refused with the recovery notice and must not save the deleted path.
      await tester.pump(const Duration(seconds: 5));
      final orphanTab = find.descendant(
        of: find.byType(TabBar).first,
        // Cross-project tabs are labelled "owner/name", so match the suffix.
        matching: find.textContaining('main.dart'),
      );
      await tester.ensureVisible(orphanTab);
      await tester.pump(const Duration(milliseconds: 200));
      await tester.tap(orphanTab);
      // TabController only selects after its switch animation stops
      // (indexIsChanging == false), so wait for the real switch to land.
      for (var attempt = 0; attempt < 60; attempt++) {
        await tester.pump(const Duration(milliseconds: 50));
        if (editor.current?.name == 'main.dart') break;
      }
      expect(editor.current?.name, 'main.dart');
      // Selecting the tab can re-post the reconcile warning. Let it expire so the
      // Run notice is not queued behind an old SnackBar when we assert.
      for (var attempt = 0; attempt < 140; attempt++) {
        if (find.textContaining('另存为').evaluate().isEmpty) break;
        await tester.pump(const Duration(milliseconds: 50));
      }
      expect(find.textContaining('另存为'), findsNothing);
      final runButton = find.byTooltip('运行（长按运行当前文件）');
      expect(runButton, findsOneWidget);
      await tester.tap(runButton);
      // A reconcile notice can be on screen when Run is tapped, and
      // ScaffoldMessenger queues the new snackbar behind it (4s), so wait past
      // that window; a genuinely missing notice still fails below.
      for (var attempt = 0; attempt < 140; attempt++) {
        await tester.pump(const Duration(milliseconds: 50));
        if (find.textContaining('项目已从工作区移除').evaluate().isNotEmpty) break;
      }
      expect(find.textContaining('项目已从工作区移除'), findsOneWidget);
      expect(
        File(p.join(fixture.first.path, 'main.dart')).readAsStringSync(),
        'one\ntwo',
        reason: 'normal Run must not save an orphaned buffer',
      );

      await fixture.unmount(tester);
      // Store writes are queued; advance fake time so their timers fire, then
      // assert the persisted document (the contract) as well as memory.
      final documentFile = File(
        p.join(fixture.directory.path, 'workspaces', '${workspace.id}.json'),
      );
      List<String> persistedOwners() {
        if (!documentFile.existsSync()) return const [];
        final decoded =
            jsonDecode(documentFile.readAsStringSync()) as Map<String, dynamic>;
        final session = decoded['session'] as Map<String, dynamic>? ?? const {};
        final documents = session['documents'] as List<dynamic>? ?? const [];
        return [
          for (final document in documents)
            (document as Map<String, dynamic>)['projectPath'] as String,
        ];
      }

      for (var attempt = 0; attempt < 100; attempt++) {
        final current = fixture.workspaceStore.byId(workspace.id);
        final owners = persistedOwners();
        if (current != null &&
            current.session.documents.length == 1 &&
            owners.length == 1) {
          break;
        }
        await tester.pump(const Duration(milliseconds: 50));
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 2)),
        );
      }
      expect(
        persistedOwners(),
        [fixture.second.path],
        reason: 'orphaned A must not be written back into the workspace session',
      );
      final saved = fixture.workspaceStore.byId(workspace.id)!;
      expect(
        saved.session.documents.map((document) => document.projectPath),
        [fixture.second.path],
        reason: 'orphaned A must not be written back into the workspace session',
      );
    },
  );

  testWidgets(
    'workspace reopen with a missing primary keeps the surviving member',
    (tester) async {
      late SavedWorkspace workspace;
      await tester.runAsync(() async {
        final created = await fixture.workspaceStore.save(
          name: 'Main workbench',
          members: [fixture.first, fixture.second],
          primary: fixture.first,
        );
        workspace = created.workspace!;
        await fixture.workspaceStore.saveSession(
          workspace,
          WorkspaceSessionSnapshot(
            primaryPath: fixture.first.path,
            documents: [
              ProjectDocumentSession(
                projectPath: fixture.first.path,
                relativePath: 'main.dart',
                cursor: _cursor,
              ),
              ProjectDocumentSession(
                projectPath: fixture.second.path,
                relativePath: 'other.cpp',
                cursor: _cursor,
                isActive: true,
              ),
            ],
          ),
        );
      });
      // Home resolved W with surviving primary B after A disappeared.
      final editor = await fixture.mount(
        tester,
        workspace: fixture.workspaceStore.byId(workspace.id) ?? workspace,
        project: fixture.second,
        members: [fixture.second],
        expected: 1,
      );
      expect(editor.files.map((file) => file.name), ['other.cpp']);
      expect(editor.files.single.projectRootPath, fixture.second.path);
      await fixture.unmount(tester);
    },
  );
}

class _Fixture {
  _Fixture(this.directory, this.store, this.first, this.second, this.workspaceStore);

  final Directory directory;
  final ProjectStore store;
  final Project first;
  final Project second;
  final WorkspaceStore workspaceStore;
  final auth = AuthStore();
  final settings = SettingsStore();

  static Future<_Fixture> create() async {
    final directory = await Directory.systemTemp.createTemp(
      'qfli_main_workspace_',
    );
    final first = Project.create(
      name: 'Dart owner',
      path: p.join(directory.path, 'dart'),
      type: 'dart',
      language: 'Dart',
    );
    final second = Project.create(
      name: 'C++ owner',
      path: p.join(directory.path, 'cpp'),
      type: 'cpp',
      language: 'C++',
    );
    for (final project in [first, second]) {
      Directory(project.path).createSync();
    }
    File(p.join(first.path, 'main.dart')).writeAsStringSync('one\ntwo');
    File(p.join(second.path, 'other.cpp')).writeAsStringSync('one\ntwo');
    final registry = File(p.join(directory.path, 'projects.json'))
      ..writeAsStringSync(
        jsonEncode({
          'projects': [first.toJson(), second.toJson()],
        }),
      );
    final store = ProjectStore(storageFile: registry);
    await store.load();
    final workspaceStore = WorkspaceStore(
      root: Directory(p.join(directory.path, 'workspaces')),
    );
    await workspaceStore.load();
    return _Fixture(directory, store, first, second, workspaceStore);
  }

  SavedWorkspace workspace(List<Project> members, {String id = 'ws-main'}) =>
      SavedWorkspace(
        id: id,
        name: 'Main workbench',
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 1),
        members: [
          for (final project in members)
            WorkspaceMember.fromProject(
              project,
              primary: project.id == members.first.id,
            ),
        ],
      );

  /// Dropping a focused code view trips re_editor's remote input assertion in
  /// the test harness (it reads the render transform after detach), so release
  /// focus first and consume that known teardown-only exception.
  Future<void> unmount(WidgetTester tester) async {
    FocusManager.instance.primaryFocus?.unfocus();
    // Let snackbars and editor activity timers expire before teardown.
    await tester.pump(const Duration(seconds: 6));
    await tester.pump();
    await tester.pumpWidget(const SizedBox.shrink());
    tester.takeException();
  }

  Future<EditorController> mount(
    WidgetTester tester, {
    SavedWorkspace? workspace,
    List<Project> members = const [],
    Project? project,
    int expected = 1,
  }) async {
    final primary = project ?? first;
    await tester.pumpWidget(
      MaterialApp(
        home: EditorPage(
          project: primary,
          auth: auth,
          store: store,
          settings: settings,
          workspace: workspace,
          workspaceMembers: members,
          workspaceStore: workspaceStore,
        ),
      ),
    );
    EditorController? editor;
    for (var attempt = 0; attempt < 200; attempt++) {
      await tester.pump(const Duration(milliseconds: 20));
      final bars = find.byType(EditorProblemsBar);
      if (bars.evaluate().isNotEmpty) {
        editor = tester.widget<EditorProblemsBar>(bars.first).analysis.editor;
        if (editor.files.length == expected) {
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 10)),
          );
          await tester.pump();
          return editor;
        }
      }
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 10)),
      );
    }
    fail(
      'Main workspace session did not restore $expected tabs; found ${editor?.files.length}.',
    );
  }
}
