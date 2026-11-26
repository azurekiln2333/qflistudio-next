import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:qfli_studio_core/editor/editor_output_panel.dart';
import 'package:qfli_studio_core/editor/editor_page.dart';
import 'package:qfli_studio_core/models/project.dart';
import 'package:qfli_studio_core/services/studio_profile.dart';
import 'package:qfli_studio_core/store/auth_store.dart';
import 'package:qfli_studio_core/store/project_store.dart';
import 'package:qfli_studio_core/store/settings_store.dart';
import 'package:re_editor/re_editor.dart';

/// Main page acceptance: with no local analyzer configured, opening
/// more-menu -> Output must not surface an "analyzer not installed" notice,
/// and the editor body must stay mounted behind the panel.
void main() {
  late Directory directory;
  late ProjectStore store;
  late Project project;
  final auth = AuthStore();
  final settings = SettingsStore();
  StudioProfile? previous;

  setUp(() async {
    previous = StudioProfile.current;
    // Main product; `codeAnalyzer` stays null on purpose.
    StudioProfile.current = const StudioProfile(
      id: 'main-no-analyzer-test',
      appTitle: 'QFLIStudio+',
      templates: [],
      productKey: StudioProductCatalog.qfliStudioKey,
    );
    directory = await Directory.systemTemp.createTemp('qfli_no_analyzer_');
    Directory(p.join(directory.path, 'app', 'src')).createSync(recursive: true);
    File(
      p.join(directory.path, 'app', 'src', 'main.dart'),
    ).writeAsStringSync('void main() {}\n');
    final registry = File(p.join(directory.path, 'projects.json'))
      ..writeAsStringSync('{"projects": []}');
    store = ProjectStore(storageFile: registry);
    await store.load();
    await store.addExisting(p.join(directory.path, 'app'));
    project = store.projects.single;
  });

  tearDown(() async {
    StudioProfile.current = previous;
    auth.dispose();
    settings.dispose();
    store.dispose();
    try {
      directory.deleteSync(recursive: true);
    } on FileSystemException {
      // A queued history write may still hold a handle on Windows.
    }
  });

  testWidgets(
    'main editor without an analyzer keeps Output free of the unavailable notice',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: EditorPage(
            project: project,
            auth: auth,
            store: store,
            settings: settings,
            initialOpenPath: p.join(project.path, 'src', 'main.dart'),
          ),
        ),
      );

      for (var attempt = 0; attempt < 200; attempt++) {
        await tester.pump(const Duration(milliseconds: 20));
        if (find.byType(CodeEditor).evaluate().isNotEmpty) break;
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 5)),
        );
      }
      expect(find.byType(CodeEditor), findsOneWidget);

      // Real gesture: more menu -> Output.
      await tester.tap(find.byTooltip('更多'));
      for (var attempt = 0; attempt < 40; attempt++) {
        await tester.pump(const Duration(milliseconds: 20));
        if (find.text('Output · 输出').evaluate().isNotEmpty) break;
      }
      expect(find.text('Output · 输出'), findsOneWidget);
      // The more-menu is taller than the test viewport; bring the item into
      // view before tapping so the gesture lands on it.
      await tester.ensureVisible(find.text('Output · 输出'));
      await tester.pump(const Duration(milliseconds: 200));
      await tester.tap(find.text('Output · 输出'));
      for (var attempt = 0; attempt < 40; attempt++) {
        await tester.pump(const Duration(milliseconds: 20));
        if (find.byType(EditorOutputPanel).evaluate().isNotEmpty) break;
      }

      expect(find.byType(EditorOutputPanel), findsOneWidget);
      expect(
        find.textContaining('未安装本地代码检查器'),
        findsNothing,
        reason: 'main product has no analyzer; Output must not claim one is missing',
      );
      expect(find.textContaining('检查不可用'), findsNothing);
      // The normal editor child is still mounted behind the panel.
      expect(find.byType(CodeEditor), findsOneWidget);

      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pump(const Duration(seconds: 6));
      await tester.pump();
      await tester.pumpWidget(const SizedBox.shrink());
      tester.takeException();
    },
  );
}
