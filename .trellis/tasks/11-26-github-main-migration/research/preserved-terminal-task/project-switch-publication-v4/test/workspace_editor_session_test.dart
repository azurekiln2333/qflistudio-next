import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:qfli_studio_core/editor/editor_controller.dart';
import 'package:qfli_studio_core/editor/editor_page.dart';
import 'package:qfli_studio_core/editor/editor_problems_bar.dart';
import 'package:qfli_studio_core/editor/project_history.dart';
import 'package:qfli_studio_core/models/project.dart';
import 'package:qfli_studio_core/services/studio_profile.dart';
import 'package:qfli_studio_core/store/auth_store.dart';
import 'package:qfli_studio_core/store/project_store.dart';
import 'package:qfli_studio_core/store/settings_store.dart';
import 'package:re_editor/re_editor.dart';

const _cursor = FileCursor(
  baseIndex: 1,
  baseOffset: 2,
  extentIndex: 1,
  extentOffset: 4,
);

void main() {
  late _Fixture fixture;
  StudioProfile? previous;
  setUp(() async {
    previous = StudioProfile.current;
    StudioProfile.current = const StudioProfile(
      id: 'workspace-test',
      appTitle: 'Workspace',
      templates: [],
      isOffline: true,
      offlineOnly: true,
      // A real child product keeps the legacy multi-root history contract;
      // the main release (qflistudio / null) uses saved workspaces instead.
      productKey: StudioProductCatalog.forgeKey,
    );
    fixture = await _Fixture.create();
  });
  tearDown(() async {
    StudioProfile.current = previous;
    await ProjectHistory.load(fixture.first.path);
    fixture.auth.dispose();
    fixture.settings.dispose();
    fixture.store.dispose();
    await fixture.directory.delete(recursive: true);
  });

  testWidgets(
    'actual EditorPage restores cross-root order, owner, active tab and cursors after reconstruction',
    (tester) async {
      await tester.runAsync(
        () => fixture.seed([
          fixture.document(fixture.second, 'local.h'),
          fixture.document(fixture.first, 'main.dart', active: true),
          fixture.document(fixture.second, 'other.cpp'),
        ]),
      );
      // Removing a root from the tree leaves its open document tabs intact.
      await tester.runAsync(
        () => ProjectHistory.saveWorkspaceRoots(fixture.first.path, [
          fixture.first.path,
        ]),
      );
      var editor = await fixture.mount(tester, expected: 3);
      expect(editor.files.map((file) => file.name), [
        'local.h',
        'main.dart',
        'other.cpp',
      ]);
      expect(editor.files.first.projectRootPath, fixture.second.path);
      expect(editor.files.first.ownerProjectName, 'C++ owner');
      expect(editor.files.first.projectType, 'cpp');
      expect(editor.currentIndex, 1);
      expect(editor.current!.controller.selection.baseOffset, 2);
      editor.select(0);
      editor.current!.controller.selection = const CodeLineSelection.collapsed(
        index: 2,
        offset: 1,
      );
      await tester.pump();
      await fixture.unmount(tester);
      final saved = await fixture.readHistory(tester);
      expect(saved.documents.map((document) => document.relativePath), [
        'local.h',
        'main.dart',
        'other.cpp',
      ]);
      expect(saved.documents.first.isActive, isTrue);
      expect(saved.documents.first.cursor.baseIndex, 2);
      expect(saved.openFiles, ['main.dart']);
      expect(saved.workspaceRoots, [fixture.first.path]);

      editor = await fixture.mount(tester, expected: 3);
      expect(editor.current!.name, 'local.h');
      expect(editor.current!.controller.selection.baseIndex, 2);
      expect(editor.current!.controller.selection.baseOffset, 1);
      expect(editor.current!.dirty, isFalse);
      expect(editor.files.map((file) => file.name), [
        'local.h',
        'main.dart',
        'other.cpp',
      ]);
      await fixture.unmount(tester);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'folded cross-root selections restore their source lines and both endpoints',
    (tester) async {
      const source = 'void f() {\n  first;\n  second;\n}\nafter;\nlast;';
      await tester.runAsync(() async {
        await File(
          p.join(fixture.first.path, 'main.dart'),
        ).writeAsString(source);
        await File(
          p.join(fixture.second.path, 'other.cpp'),
        ).writeAsString(source);
        await fixture.seed([
          fixture.document(fixture.first, 'main.dart'),
          fixture.document(fixture.second, 'other.cpp', active: true),
        ]);
      });
      var editor = await fixture.mount(tester, expected: 2);
      for (final file in editor.files) {
        file.controller.collapseChunk(0, 4);
        file.controller.selection = const CodeLineSelection(
          baseIndex: 2,
          baseOffset: 3,
          extentIndex: 1,
          extentOffset: 2,
        );
        expect(file.controller.codeLines.index2lineIndex(2), 5);
      }
      await tester.pump();
      await fixture.unmount(tester);
      final saved = await fixture.readHistory(tester);
      for (final document in saved.documents) {
        expect(document.cursor.baseIndex, 5);
        expect(document.cursor.extentIndex, 4);
      }
      expect(saved.cursors['main.dart']!.baseIndex, 5);
      expect(saved.cursors['main.dart']!.extentIndex, 4);
      editor = await fixture.mount(tester, expected: 2);
      for (final file in editor.files) {
        expect(file.controller.selection.baseIndex, 5);
        expect(file.controller.selection.baseOffset, 3);
        expect(file.controller.selection.extentIndex, 4);
        expect(file.controller.selection.extentOffset, 2);
        expect(file.controller.text, source);
        expect(file.dirty, isFalse);
      }
      await fixture.unmount(tester);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'legacy main-root sessions retain cursor and active-file restoration',
    (tester) async {
      await tester.runAsync(
        () => ProjectHistory.save(
          fixture.first.path,
          cursors: {'main.dart': _cursor},
          openFiles: ['main.dart'],
          activeFile: 'main.dart',
        ),
      );
      final editor = await fixture.mount(tester, expected: 1);
      expect(editor.current!.name, 'main.dart');
      expect(editor.current!.projectRootPath, fixture.first.path);
      expect(editor.current!.controller.selection.baseIndex, 1);
      expect(editor.current!.controller.selection.extentOffset, 4);
      await fixture.unmount(tester);
    },
  );

  testWidgets(
    'restore skips foreign owners, traversal, absolute paths, missing files and duplicate tabs',
    (tester) async {
      final external = Project.create(
        name: 'Unregistered',
        path: fixture.directory.path,
      );
      File(p.join(external.path, 'outside.dart')).writeAsStringSync('private');
      await tester.runAsync(
        () => fixture.seed([
          fixture.document(external, 'outside.dart', active: true),
          fixture.document(fixture.first, '../outside.dart', active: true),
          fixture.document(
            fixture.first,
            p.join(fixture.second.path, 'local.h'),
            active: true,
          ),
          fixture.document(fixture.first, 'missing.dart', active: true),
          fixture.document(fixture.first, 'main.dart', active: true),
          fixture.document(fixture.first, 'main.dart'),
        ]),
      );
      final editor = await fixture.mount(tester, expected: 1);
      expect(editor.files.single.path, p.join(fixture.first.path, 'main.dart'));
      expect(editor.current!.controller.selection.baseIndex, 1);
      expect(
        File(p.join(external.path, 'outside.dart')).readAsStringSync(),
        'private',
      );
      await fixture.unmount(tester);
      expect(tester.takeException(), isNull);
    },
  );
}

class _Fixture {
  _Fixture(this.directory, this.store, this.first, this.second);
  final Directory directory;
  final ProjectStore store;
  final Project first;
  final Project second;
  final auth = AuthStore();
  final settings = SettingsStore();

  static Future<_Fixture> create() async {
    final directory = await Directory.systemTemp.createTemp(
      'qfli_workspace_session_',
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
    for (final path in [
      p.join(first.path, 'main.dart'),
      p.join(second.path, 'local.h'),
      p.join(second.path, 'other.cpp'),
    ]) {
      File(path).writeAsStringSync('first\nsecond\nthird');
    }
    final registry = File(p.join(directory.path, 'projects.json'))
      ..writeAsStringSync(
        jsonEncode({
          'projects': [first.toJson(), second.toJson()],
        }),
      );
    final store = ProjectStore(storageFile: registry);
    await store.load();
    return _Fixture(directory, store, first, second);
  }

  ProjectDocumentSession document(
    Project owner,
    String path, {
    bool active = false,
  }) => ProjectDocumentSession(
    projectPath: owner.path,
    relativePath: path,
    cursor: _cursor,
    isActive: active,
  );

  Future<void> seed(List<ProjectDocumentSession> documents) =>
      ProjectHistory.save(
        first.path,
        cursors: const {},
        openFiles: const [],
        activeFile: null,
        documents: documents,
      );

  Future<EditorController> mount(
    WidgetTester tester, {
    required int expected,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: EditorPage(
          project: first,
          auth: auth,
          store: store,
          settings: settings,
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
          await tester.pump(const Duration(milliseconds: 40));
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
      'Workspace session did not restore $expected tabs; found ${editor?.files.length}.',
    );
  }

  Future<void> unmount(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await readHistory(tester);
  }

  Future<ProjectSession> readHistory(WidgetTester tester) async {
    ProjectSession? session;
    ProjectHistory.load(first.path).then((value) => session = value);
    for (var attempt = 0; attempt < 200; attempt++) {
      await tester.pump();
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 5)),
      );
      if (session != null) return session!;
    }
    fail('Workspace history did not finish its queued writes.');
  }
}
