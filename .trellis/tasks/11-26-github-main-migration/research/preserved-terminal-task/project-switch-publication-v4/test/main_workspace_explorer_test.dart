import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:qfli_studio_core/editor/editor_controller.dart';
import 'package:qfli_studio_core/editor/file_explorer.dart';
import 'package:qfli_studio_core/models/project.dart';
import 'package:qfli_studio_core/services/studio_profile.dart';
import 'package:qfli_studio_core/store/project_store.dart';
import 'package:qfli_studio_core/store/settings_store.dart';
import 'package:qfli_studio_core/workspace/editor_workspace.dart';
import 'package:qfli_studio_core/workspace/saved_workspace.dart';
import 'package:qfli_studio_core/workspace/workspace_store.dart';

/// Main-release explorer regressions: primary fallback and expansion merge.
/// Mounts the real tree, not just controller state.
void main() {
  late _Fixture fixture;
  StudioProfile? previous;

  setUp(() async {
    previous = StudioProfile.current;
    StudioProfile.current = const StudioProfile(
      id: 'main-explorer-test',
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

  testWidgets(
    'primary fallback moves browsing off the deleted root and keeps the survivor tree',
    (tester) async {
      late SavedWorkspace workspace;
      await tester.runAsync(() async {
        workspace = await fixture.saveWorkspace([fixture.first, fixture.second]);
      });
      await fixture.mount(tester, workspace: workspace);
      await fixture.expand(tester, fixture.first, 'src', 'nested');
      await fixture.expand(tester, fixture.second, 'other', 'second.json');
      expect(fixture.entry(fixture.first, 'nested'), findsOneWidget);
      expect(fixture.entry(fixture.second, 'second.json'), findsOneWidget);

      // A disappeared: Home reopens the same workspace with B as primary.
      await fixture.mount(
        tester,
        workspace: fixture.reopened(workspace, [fixture.second]),
        project: fixture.second,
        members: [fixture.second],
      );
      // The deleted root is gone and browsing followed the effective primary.
      expect(fixture.root(fixture.first), findsNothing);
      expect(fixture.root(fixture.second), findsOneWidget);
      // The survivor's own expansion is preserved in the same live tree.
      await fixture.expectVisible(
        tester,
        fixture.entry(fixture.second, 'second.json'),
        reason: 'fallback must keep the survivor root expansion',
      );
    },
  );

  testWidgets(
    'removing and re-adding a root restores its previous expansion',
    (tester) async {
      late SavedWorkspace workspace;
      await tester.runAsync(() async {
        workspace = await fixture.saveWorkspace([fixture.first, fixture.second]);
      });
      await fixture.mount(tester, workspace: workspace);
      await fixture.expand(tester, fixture.second, 'other', 'second.json');
      expect(fixture.entry(fixture.second, 'second.json'), findsOneWidget);

      // Drop B from the workspace: its root disappears from the tree.
      await fixture.mount(
        tester,
        workspace: fixture.reopened(workspace, [fixture.first]),
        members: [fixture.first],
      );
      expect(fixture.root(fixture.second), findsNothing);

      // Re-add B: the retained expansion metadata must restore `other`.
      await fixture.mount(
        tester,
        workspace: fixture.reopened(workspace, [fixture.first, fixture.second]),
        members: [fixture.first, fixture.second],
      );
      expect(fixture.root(fixture.second), findsOneWidget);
      await fixture.expectVisible(
        tester,
        fixture.entry(fixture.second, 'second.json'),
        reason: 're-added root must restore its previously expanded folder',
      );
    },
  );

  testWidgets(
    'expansion metadata of a removed root never opens its files',
    (tester) async {
      late SavedWorkspace workspace;
      await tester.runAsync(() async {
        workspace = await fixture.saveWorkspace([fixture.first, fixture.second]);
      });
      await fixture.mount(tester, workspace: workspace);
      await fixture.expand(tester, fixture.second, 'other', 'second.json');
      await fixture.mount(
        tester,
        workspace: fixture.reopened(workspace, [fixture.first]),
        members: [fixture.first],
      );
      expect(fixture.entry(fixture.second, 'second.json'), findsNothing);
      expect(
        find.descendant(
          of: fixture.root(fixture.first),
          matching: find.text('second.json'),
        ),
        findsNothing,
      );
      expect(fixture.editor.files, isEmpty);
    },
  );
  testWidgets(
    'short 1100x175 panel lays out the header and tree without overflow',
    (tester) async {
      late SavedWorkspace workspace;
      await tester.runAsync(() async {
        workspace = await fixture.saveWorkspace([
          fixture.first,
          fixture.second,
        ]);
      });
      for (final scale in [1.0, 2.0]) {
        await fixture.mount(
          tester,
          workspace: workspace,
          surface: const Size(1100, 175),
          scale: scale,
        );
        await tester.pump(const Duration(milliseconds: 50));
        expect(
          tester.takeException(),
          isNull,
          reason:
              'header/tree must not overflow a 1100x175 panel at '
              'text scale $scale',
        );
        // The workspace action stays reachable on a short panel.
        expect(find.byTooltip('工作区项目'), findsOneWidget);
      }
    },
  );
}

class _Fixture {
  _Fixture(this.directory, this.store, this.first, this.second, this.workspaceStore)
    : editor = EditorController(project: first);

  final Directory directory;
  final ProjectStore store;
  final Project first;
  final Project second;
  final WorkspaceStore workspaceStore;
  final EditorController editor;
  final settings = SettingsStore();
  bool _disposed = false;

  static Future<_Fixture> create() async {
    final directory = await Directory.systemTemp.createTemp(
      'qfli_main_explorer_',
    );
    for (final name in ['first', 'second']) {
      Directory(
        p.join(directory.path, name, 'src', 'nested'),
      ).createSync(recursive: true);
      Directory(p.join(directory.path, name, 'other')).createSync();
      File(p.join(directory.path, name, 'src', 'first.json'))
          .writeAsStringSync('{}');
      File(p.join(directory.path, name, 'other', 'second.json'))
          .writeAsStringSync('{}');
    }
    final store = ProjectStore(
      storageFile: File(p.join(directory.path, 'registry.json')),
    );
    await store.load();
    await store.addExisting(p.join(directory.path, 'first'));
    await store.addExisting(p.join(directory.path, 'second'));
    final workspaceStore = WorkspaceStore(
      root: Directory(p.join(directory.path, 'workspaces')),
    );
    await workspaceStore.load();
    return _Fixture(
      directory,
      store,
      store.projects.singleWhere((project) => project.name == 'first'),
      store.projects.singleWhere((project) => project.name == 'second'),
      workspaceStore,
    );
  }

  Future<SavedWorkspace> saveWorkspace(List<Project> members) async {
    final result = await workspaceStore.save(
      name: 'Main workbench',
      members: members,
      primary: members.first,
    );
    return result.workspace!;
  }

  /// Same workspace identity with a new member set, as Home would resolve it.
  SavedWorkspace reopened(SavedWorkspace workspace, List<Project> members) =>
      workspace.copyWith(
        updatedAt: workspace.updatedAt.add(const Duration(seconds: 1)),
        members: [
          for (final project in members)
            WorkspaceMember.fromProject(
              project,
              primary: p.equals(project.path, members.first.path),
            ),
        ],
      );

  Finder root(Project project) =>
      find.byKey(ValueKey('workspace-root-${project.path}'));

  Finder entry(Project project, String name) =>
      find.descendant(of: root(project), matching: find.text(name));

  /// Waits for a restored row to appear; a real restore regression still fails,
  /// but with an explicit reason instead of a race.
  Future<void> expectVisible(
    WidgetTester tester,
    Finder finder, {
    required String reason,
  }) async {
    for (var attempt = 0; attempt < 300; attempt++) {
      if (finder.evaluate().isNotEmpty) break;
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 5)),
      );
      await tester.pump(const Duration(milliseconds: 20));
    }
    expect(finder, findsOneWidget, reason: reason);
  }

  Future<void> expand(
    WidgetTester tester,
    Project project,
    String folder,
    String expectVisible,
  ) async {
    // Children load asynchronously after the root row appears.
    await waitForIo(tester, () => entry(project, folder).evaluate().isNotEmpty);
    await tester.tap(entry(project, folder));
    await waitForIo(
      tester,
      () => find
          .descendant(of: root(project), matching: find.text(expectVisible))
          .evaluate()
          .isNotEmpty,
    );
  }

  Future<void> mount(
    WidgetTester tester, {
    required SavedWorkspace workspace,
    Project? project,
    List<Project>? members,
    Size? surface,
    double scale = 1,
  }) async {
    final primary = project ?? first;
    final memberList = members ?? [first, second];
    if (surface != null && !_viewSized) {
      _viewSized = true;
      tester.view.physicalSize = surface;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
    }
    final explorer = FileExplorer(
      project: primary,
      editor: editor,
      store: store,
      settings: settings,
      workspace: workspace,
      workspaceMembers: memberList,
      workspaceStore: workspaceStore,
      onWorkspaceChanged: (EditorWorkspaceState state) {
        // Mirrors EditorPage: the explorer's merged expansion is the state
        // written back into the workspace document.
        lastState = state;
      },
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
          body: surface != null
              ? explorer
              : Align(
                  alignment: Alignment.topLeft,
                  child: SizedBox(width: 360, height: 700, child: explorer),
                ),
        ),
      ),
    );
    await waitForIo(
      tester,
      () =>
          root(memberList.first).evaluate().isNotEmpty &&
          // The root row renders before its children are read from disk.
          find
              .descendant(
                of: root(memberList.first),
                matching: find.text('src'),
              )
              .evaluate()
              .isNotEmpty,
    );
  }

  bool _viewSized = false;
  EditorWorkspaceState? lastState;

  Future<void> waitForIo(
    WidgetTester tester,
    bool Function() complete,
  ) async {
    for (var attempt = 0; attempt < 300 && !complete(); attempt++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 5)),
      );
      await tester.pump(const Duration(milliseconds: 20));
    }
    expect(complete(), isTrue, reason: 'explorer IO did not finish');
  }

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    editor.dispose();
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
