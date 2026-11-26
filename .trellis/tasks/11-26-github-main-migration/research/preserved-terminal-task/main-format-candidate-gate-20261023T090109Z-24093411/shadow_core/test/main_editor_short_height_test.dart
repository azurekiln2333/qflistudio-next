import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:qfli_studio_core/editor/editor_page.dart';
import 'package:qfli_studio_core/editor/file_explorer.dart';
import 'package:qfli_studio_core/models/project.dart';
import 'package:qfli_studio_core/services/studio_profile.dart';
import 'package:qfli_studio_core/store/auth_store.dart';
import 'package:qfli_studio_core/store/project_store.dart';
import 'package:qfli_studio_core/store/settings_store.dart';
import 'package:re_editor/re_editor.dart';

/// The reported overflow was at 1100x175 in the ACTUAL editor page, not in a
/// standalone FileExplorer: at that width (>= 720) the page also renders the
/// 280px sidebar card, its 12px margins, the tab bar and the status bar inside
/// the same short body. This mounts the real page at that geometry.
void main() {
  late Directory directory;
  late ProjectStore store;
  late Project project;
  final auth = AuthStore();
  final settings = SettingsStore();
  StudioProfile? previous;

  setUp(() async {
    previous = StudioProfile.current;
    StudioProfile.current = const StudioProfile(
      id: 'main-short-height-test',
      appTitle: 'QFLIStudio+',
      templates: [],
      productKey: StudioProductCatalog.qfliStudioKey,
    );
    directory = await Directory.systemTemp.createTemp('qfli_short_height_');
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

  testWidgets('actual editor page lays out at 1100x175 without overflow', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1100, 175);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

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

    for (var attempt = 0; attempt < 300; attempt++) {
      await tester.pump(const Duration(milliseconds: 20));
      if (find.byType(CodeEditor).evaluate().isNotEmpty) break;
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 5)),
      );
    }
    expect(find.byType(CodeEditor), findsOneWidget);
    // Wide layout: the sidebar card lives inside the same 175px page.
    expect(find.byType(FileExplorer), findsWidgets);
    expect(
      tester.takeException(),
      isNull,
      reason: 'editor page overflows at 1100x175 (sidebar + tabs + status)',
    );

    // Same geometry with the Output panel requested through the real menu.
    await tester.tap(find.byTooltip('更多'));
    for (var attempt = 0; attempt < 60; attempt++) {
      await tester.pump(const Duration(milliseconds: 20));
      if (find.text('Output · 输出').evaluate().isNotEmpty) break;
    }
    await tester.ensureVisible(find.text('Output · 输出'));
    await tester.pump(const Duration(milliseconds: 200));
    await tester.tap(find.text('Output · 输出'));
    await tester.pump(const Duration(milliseconds: 300));
    // At 175px the activity panel is intentionally suppressed by the page's
    // height gate (bodyHeight >= minEditorHeight + 96), so the invariant here
    // is that the request is handled without overflow and the editor stays.
    expect(find.byType(CodeEditor), findsOneWidget);
    expect(
      tester.takeException(),
      isNull,
      reason: 'opening Output must not overflow the 1100x175 page',
    );

    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pump(const Duration(seconds: 6));
    await tester.pump();
    await tester.pumpWidget(const SizedBox.shrink());
    tester.takeException();
  });
}
