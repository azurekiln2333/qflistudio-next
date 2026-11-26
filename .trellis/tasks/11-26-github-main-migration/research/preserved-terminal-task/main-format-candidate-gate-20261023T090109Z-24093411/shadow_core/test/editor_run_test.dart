import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' show Tristate;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:qfli_studio_core/editor/editor_page.dart';
import 'package:qfli_studio_core/editor/editor_controller.dart';
import 'package:qfli_studio_core/editor/editor_problems_bar.dart';
import 'package:qfli_studio_core/editor/terminal_pane.dart';
import 'package:qfli_studio_core/models/project.dart';
import 'package:qfli_studio_core/services/project_config.dart';
import 'package:qfli_studio_core/services/studio_profile.dart';
import 'package:qfli_studio_core/services/web_preview_file.dart';
import 'package:qfli_studio_core/store/auth_store.dart';
import 'package:qfli_studio_core/store/project_store.dart';
import 'package:qfli_studio_core/store/settings_store.dart';
import 'package:re_editor/re_editor.dart';

const _runTooltip = '运行（长按运行当前文件）';

void main() {
  late _EditorFixture fixture;
  late StudioProfile? previousProfile;

  setUp(() {
    previousProfile = StudioProfile.current;
    fixture = _EditorFixture();
    fixture.installProfile();
  });

  tearDown(() async {
    StudioProfile.current = previousProfile;
    await fixture.dispose();
  });

  testWidgets('tap, long press, tap run Main, Main2, Main exactly once', (
    tester,
  ) async {
    await fixture.mount(tester);
    final config = File(ProjectConfig.configPath(fixture.project.path));
    final originalConfig = config.readAsStringSync();
    final run = find.byTooltip(_runTooltip);

    await tester.tap(run);
    await _waitForRun(tester, fixture.runner, 1);
    expect(fixture.runner.entries, [fixture.source('Main.java').path]);

    await tester.longPress(run);
    await _waitForRun(tester, fixture.runner, 2);
    expect(fixture.runner.entries, [
      fixture.source('Main.java').path,
      fixture.source('Main2.java').path,
    ]);

    await tester.tap(run);
    await _waitForRun(tester, fixture.runner, 3);
    expect(fixture.runner.entries, [
      fixture.source('Main.java').path,
      fixture.source('Main2.java').path,
      fixture.source('Main.java').path,
    ]);
    expect(config.readAsStringSync(), originalConfig);
    expect(tester.takeException(), isNull);
  });

  testWidgets('both gestures save edited sources before invoking the runner', (
    tester,
  ) async {
    await fixture.mount(tester);
    final editor = tester.widget<CodeEditor>(find.byType(CodeEditor));
    const firstEdit = 'class Main2 { /* saved before tap */ }\n';
    editor.controller!.text = firstEdit;
    await tester.pump();
    expect(fixture.source('Main2.java').readAsStringSync(), isNot(firstEdit));

    await tester.tap(find.byTooltip(_runTooltip));
    await _waitForRun(tester, fixture.runner, 1);
    expect(fixture.runner.savedSources.single['Main2.java'], firstEdit);

    const secondEdit = 'class Main2 { /* saved before long press */ }\n';
    editor.controller!.text = secondEdit;
    await tester.pump();
    await tester.longPress(find.byTooltip(_runTooltip));
    await _waitForRun(tester, fixture.runner, 2);
    expect(fixture.runner.savedSources.last['Main2.java'], secondEdit);
    expect(fixture.source('Main2.java').readAsStringSync(), secondEdit);
  });

  testWidgets(
    'secondary-root tap and long press use its entry and working directory',
    (tester) async {
      await fixture.mount(tester);
      final editor = fixture.editor(tester);
      final secondary = await fixture.openSecondary(tester);
      const edited = 'class Main2 { /* secondary unsaved source */ }\r\n';
      editor.current!.controller.text = edited;
      await tester.pump();

      await tester.tap(find.byTooltip(_runTooltip));
      await _waitForRun(tester, fixture.runner, 1);
      await tester.longPress(find.byTooltip(_runTooltip));
      await _waitForRun(tester, fixture.runner, 2);
      expect(fixture.runner.roots, [secondary.path, secondary.path]);
      expect(fixture.runner.entries, [
        p.join(secondary.path, 'Main.java'),
        p.join(secondary.path, 'Main2.java'),
      ]);
      expect(fixture.runner.savedSources.first['Main2.java'], edited);

      editor.select(0);
      await tester.pump();
      await tester.tap(find.byTooltip(_runTooltip));
      await _waitForRun(tester, fixture.runner, 3);
      expect(fixture.runner.roots.last, fixture.project.path);
      expect(fixture.runner.entries.last, fixture.source('Main.java').path);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('running secondary root does not save or fail on another root', (
    tester,
  ) async {
    await fixture.mount(tester);
    final primary = fixture.editor(tester).current!;
    primary.controller.text = 'class Main2 { /* leave primary dirty */ }';
    fixture.source('Main2.java').deleteSync();
    Directory(primary.path).createSync();
    final secondary = await fixture.openSecondary(tester);

    await tester.tap(find.byTooltip(_runTooltip));
    await _waitForRun(tester, fixture.runner, 1);
    expect(fixture.runner.roots.single, secondary.path);
    expect(primary.dirty, isTrue);
    expect(Directory(primary.path).existsSync(), isTrue);
  });

  testWidgets(
    'run captures secondary owner before an asynchronous save and tab switch',
    (tester) async {
      await fixture.mount(tester);
      final secondary = await fixture.openSecondary(tester);
      final editor = fixture.editor(tester);
      final saving = Completer<String?>();
      editor.current!.pendingSave = saving.future;
      await tester.tap(find.byTooltip(_runTooltip));
      await tester.pump();
      editor.select(0);
      await tester.pump();
      saving.complete(null);

      await _waitForRun(tester, fixture.runner, 1);
      expect(fixture.runner.roots.single, secondary.path);
      expect(
        fixture.runner.entries.single,
        p.join(secondary.path, 'Main.java'),
      );
    },
  );

  testWidgets('secondary HTML preview factory receives the active owner root', (
    tester,
  ) async {
    final previewRoots = <String>[];
    final previewEntries = <String>[];
    final previewDefaults = <String>[];
    StudioProfile.current = StudioProfile(
      id: 'preview-owner-test',
      appTitle: 'Preview owner',
      templates: const [],
      offlineOnly: true,
      entryFileNames: const ['index.html'],
      supportedFileExtensions: const ['.html'],
      webPreviewFactory: (root) async {
        previewRoots.add(root);
        return _RecordingPreview(root, previewEntries, previewDefaults);
      },
    );
    await fixture.mount(tester);
    final secondary = await fixture.openSecondary(tester, html: true);
    await tester.tap(find.byTooltip(_runTooltip));
    await _pumpIoUntil(tester, () => previewDefaults.length == 1);
    await tester.pump();
    await tester.longPress(find.byTooltip(_runTooltip));
    await _pumpIoUntil(tester, () => previewEntries.length == 1);
    expect(previewRoots, [secondary.path, secondary.path]);
    expect(previewDefaults, [secondary.path]);
    expect(previewEntries, [p.join(secondary.path, 'other.html')]);
    expect(fixture.runner.entries, isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets('deleted active file is rejected before save can recreate it', (
    tester,
  ) async {
    await fixture.mount(tester);
    tester.widget<CodeEditor>(find.byType(CodeEditor)).controller!.text =
        'class Main2 { /* unsaved */ }\n';
    await tester.pump();
    fixture.source('Main2.java').deleteSync();

    await tester.longPress(find.byTooltip(_runTooltip));
    await _pumpIoUntil(
      tester,
      () => find.text('active file no longer exists').evaluate().isNotEmpty,
    );

    expect(fixture.runner.entries, isEmpty);
    expect(fixture.source('Main2.java').existsSync(), isFalse);
    expect(fixture.source('Main.java').readAsStringSync(), 'class Main {}\n');
  });

  testWidgets('unsupported active file is rejected without saving edits', (
    tester,
  ) async {
    final notes = fixture.source('notes.txt')..writeAsStringSync('original');
    await fixture.mount(tester, initialOpenPath: 'notes.txt');
    tester.widget<CodeEditor>(find.byType(CodeEditor)).controller!.text =
        'unsaved notes';
    await tester.pump();

    await tester.longPress(find.byTooltip(_runTooltip));
    await _pumpIoUntil(
      tester,
      () => find.text('.txt is not runnable here').evaluate().isNotEmpty,
    );

    expect(fixture.runner.entries, isEmpty);
    expect(notes.readAsStringSync(), 'original');
  });

  testWidgets('a file outside the project is rejected without saving', (
    tester,
  ) async {
    final outside = File(p.join(fixture.directory.path, 'Outside.java'))
      ..writeAsStringSync('class Outside {}\n');
    await fixture.mount(tester, initialOpenPath: outside.path);
    tester.widget<CodeEditor>(find.byType(CodeEditor)).controller!.text =
        'class Outside { /* unsaved */ }\n';
    await tester.pump();

    await tester.longPress(find.byTooltip(_runTooltip));
    await _pumpIoUntil(
      tester,
      () =>
          find.text('active file is outside the project').evaluate().isNotEmpty,
    );

    expect(fixture.runner.entries, isEmpty);
    expect(outside.readAsStringSync(), 'class Outside {}\n');
  });

  testWidgets('long press with no open file does not run the default entry', (
    tester,
  ) async {
    await fixture.mount(tester, initialOpenPath: null);

    await tester.longPress(find.byTooltip(_runTooltip));
    await _pumpIoUntil(
      tester,
      () => find.text('no active file to run').evaluate().isNotEmpty,
    );

    expect(fixture.runner.entries, isEmpty);
  });

  testWidgets('tap without an active tab uses the primary project entry', (
    tester,
  ) async {
    await fixture.mount(tester, initialOpenPath: null);
    await tester.tap(find.byTooltip(_runTooltip));
    await _waitForRun(tester, fixture.runner, 1);
    expect(fixture.runner.roots.single, fixture.project.path);
    expect(fixture.runner.entries.single, fixture.source('Main.java').path);
  });

  testWidgets('tap rejects foreign owner metadata before saving any source', (
    tester,
  ) async {
    final outside = File(p.join(fixture.directory.path, 'Outside.java'))
      ..writeAsStringSync('class Outside {}');
    await fixture.mount(tester, initialOpenPath: outside.path);
    fixture.editor(tester).current!.controller.text = 'unsaved foreign edit';
    await tester.tap(find.byTooltip(_runTooltip));
    await _pumpIoUntil(
      tester,
      () => find.text('file is outside its project').evaluate().isNotEmpty,
    );
    expect(fixture.runner.entries, isEmpty);
    expect(outside.readAsStringSync(), 'class Outside {}');
  });

  testWidgets('tap and long press reject a physically escaping source link', (
    tester,
  ) async {
    final outside = File(p.join(fixture.directory.path, 'Outside.java'))
      ..writeAsStringSync('class Outside {}');
    final link = Link(fixture.source('Linked.java').path);
    link.createSync(outside.path);
    await fixture.mount(tester, initialOpenPath: 'Linked.java');
    fixture.editor(tester).current!.controller.text = 'unsaved linked edit';
    await tester.tap(find.byTooltip(_runTooltip));
    await _pumpIoUntil(
      tester,
      () => find.text('file is outside its project').evaluate().isNotEmpty,
    );
    await tester.longPress(find.byTooltip(_runTooltip));
    await _pumpIoUntil(
      tester,
      () =>
          find.text('active file is outside the project').evaluate().isNotEmpty,
    );
    expect(fixture.runner.entries, isEmpty);
    expect(outside.readAsStringSync(), 'class Outside {}');
  });

  testWidgets('an empty extension list delegates to the profile runner', (
    tester,
  ) async {
    fixture.installProfile(supportedExtensions: const []);
    await fixture.mount(tester);

    await tester.longPress(find.byTooltip(_runTooltip));
    await _waitForRun(tester, fixture.runner, 1);

    expect(fixture.runner.entries, [fixture.source('Main2.java').path]);
  });

  testWidgets('the default profile reaches the existing runner diagnostic', (
    tester,
  ) async {
    StudioProfile.current = null;
    fixture.source('notes.txt').writeAsStringSync('plain text');
    await fixture.mount(tester, initialOpenPath: 'notes.txt');

    await tester.longPress(find.byTooltip(_runTooltip));
    await _pumpIoUntil(
      tester,
      () => find.textContaining('无法识别可运行的入口文件').evaluate().isNotEmpty,
    );

    expect(find.text('.txt is not runnable here'), findsNothing);
    expect(fixture.runner.entries, isEmpty);
  });

  testWidgets('a save failure prevents launching even when Main exists', (
    tester,
  ) async {
    await fixture.mount(tester);
    final active = fixture.source('Main2.java');
    active.deleteSync();
    Directory(active.path).createSync();

    await tester.tap(find.byTooltip(_runTooltip));
    await _pumpIoUntil(
      tester,
      () => find.textContaining('保存失败：').evaluate().isNotEmpty,
    );

    expect(fixture.runner.entries, isEmpty);
    expect(
      tester.state<TerminalPaneState>(find.byType(TerminalPane)).busy,
      isFalse,
    );
  });

  testWidgets('Run retains keyboard activation and disabled button semantics', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    final exit = Completer<int>();
    fixture.runner.exitCode = exit.future;
    addTearDown(() {
      if (!exit.isCompleted) exit.complete(0);
    });
    await fixture.mount(tester);
    final run = find.byTooltip(_runTooltip);
    final icon = find.descendant(
      of: run,
      matching: find.byIcon(Icons.play_arrow),
    );
    // Tooltip is above the button's semantics boundary. Query the visible
    // icon so these assertions inspect the actual actionable semantics node.
    var node = tester.getSemantics(icon);
    expect(node.flagsCollection.isButton, isTrue);
    expect(node.flagsCollection.isEnabled, Tristate.isTrue);
    expect(tester.getSize(run), const Size(48, 48));
    Focus.of(tester.element(icon)).requestFocus();
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await _pumpIoUntil(tester, () => fixture.runner.entries.length == 1);
    await tester.pump();

    node = tester.getSemantics(icon);
    expect(node.flagsCollection.isButton, isTrue);
    expect(node.flagsCollection.isEnabled, Tristate.isFalse);
    expect(
      tester.widget<Icon>(icon).color,
      Theme.of(tester.element(icon)).disabledColor,
    );

    await tester.longPress(run);
    await tester.tap(run);
    await tester.pump();
    expect(fixture.runner.entries, [fixture.source('Main.java').path]);

    exit.complete(0);
    await _waitForRun(tester, fixture.runner, 1);
    expect(
      tester.getSemantics(icon).flagsCollection.isEnabled,
      Tristate.isTrue,
    );
    semantics.dispose();
  });

  testWidgets('terminal collapses on a small downward drag and reopens', (
    tester,
  ) async {
    await fixture.mount(tester);
    await _openTerminal(tester);

    final pane = find.byType(TerminalPane);
    final expandedHeight = tester.getSize(pane).height;
    expect(expandedHeight, greaterThan(0));

    // Many small downward steps must accumulate to reach the collapse
    // threshold, not be clamped away one at a time. Total displacement is
    // derived from the threshold so the test proves real accumulation.
    final expandHandle = _resizeHandleFinder();
    final gesture = await tester.startGesture(tester.getCenter(expandHandle));
    const step = 4.0;
    final steps = (expandedHeight / step).ceil() + 4;
    for (var i = 0; i < steps; i++) {
      await gesture.moveBy(const Offset(0, step));
      await tester.pump(const Duration(milliseconds: 8));
    }
    await gesture.up();
    await tester.pump();
    await tester.pump();

    // Collapsed: header + handle allocation, far shorter than expanded.
    final collapsedHeight = tester.getSize(pane).height;
    expect(collapsedHeight, lessThan(expandedHeight));
    expect(
      collapsedHeight,
      lessThanOrEqualTo(TerminalPanelMetrics.collapsedTotalHeight + 1),
    );
    // The header still exposes its expand control.
    expect(find.byTooltip('展开终端'), findsOneWidget);

    await tester.tap(find.byTooltip('展开终端'));
    await tester.pump();
    await tester.pump();
    final reopened = tester.getSize(pane).height;
    expect(reopened, greaterThan(collapsedHeight));
    expect(reopened, closeTo(expandedHeight, 1));
  });

  testWidgets('many small upward steps reopen a collapsed terminal', (
    tester,
  ) async {
    await fixture.mount(tester);
    await _openTerminal(tester);
    final pane = find.byType(TerminalPane);

    // Put a distinct marker in the transcript so retention can be proven.
    final state = tester.state<TerminalPaneState>(pane);
    state.appendSystem('retained-marker');
    await tester.pump();

    await tester.tap(find.byTooltip('收起终端'));
    await tester.pump();
    await tester.pump();
    final collapsed = tester.getSize(pane).height;
    expect(collapsed, closeTo(TerminalPanelMetrics.collapsedTotalHeight, 0.5));

    // Drag up in small steps. A deliberate drag chooses a new height from the
    // raw accumulated displacement, not the preserved preference.
    final handle = _resizeHandleFinder();
    final gesture = await tester.startGesture(tester.getCenter(handle));
    const step = 4.0;
    const travelSteps = 24;
    for (var i = 0; i < travelSteps; i++) {
      await gesture.moveBy(const Offset(0, -step));
      await tester.pump(const Duration(milliseconds: 8));
    }
    await gesture.up();
    await tester.pump();
    await tester.pump();

    final expectedFromGesture = collapsed + travelSteps * step;
    final reopened = tester.getSize(pane).height;
    expect(reopened, closeTo(expectedFromGesture, 1));
    // The session/state and its output are retained across collapse+reopen.
    expect(tester.state<TerminalPaneState>(pane), same(state));
    expect(
      find.descendant(of: pane, matching: find.text('retained-marker')),
      findsOneWidget,
    );
  });

  testWidgets('expand control restores the exact preferred height', (
    tester,
  ) async {
    await fixture.mount(tester);
    await _openTerminal(tester);
    final pane = find.byType(TerminalPane);
    final preferred = tester.getSize(pane).height;

    await tester.tap(find.byTooltip('收起终端'));
    await tester.pump();
    await tester.pump();
    expect(
      tester.getSize(pane).height,
      closeTo(TerminalPanelMetrics.collapsedTotalHeight, 0.5),
    );

    await tester.tap(find.byTooltip('展开终端'));
    await tester.pump();
    await tester.pump();
    // The expand control restores the preserved preferred expanded height.
    expect(tester.getSize(pane).height, closeTo(preferred, 1));
  });

  testWidgets('AI panel geometry is independent of terminal metrics', (
    tester,
  ) async {
    // The AI panel keeps its own 36 px collapsed header and 112 px compact
    // threshold; the terminal uses a 58 px collapsed allocation and a 120 px
    // minimum. These must be distinct so terminal sizing never leaks into AI.
    expect(TerminalPanelMetrics.collapsedTotalHeight, isNot(36.0));
    expect(
      TerminalPanelMetrics.collapsedHeight +
          TerminalPanelMetrics.dragHandleHeight,
      TerminalPanelMetrics.collapsedTotalHeight,
    );
    expect(TerminalPanelMetrics.minExpandedHeight, isNot(112.0));

    // The editor lays out and its terminal panel renders without an overflow
    // when both panels could coexist.
    await fixture.mount(tester);
    await _openTerminal(tester);
    final pane = find.byType(TerminalPane);
    expect(pane, findsOneWidget);
    expect(
      tester.getSize(pane).height,
      greaterThanOrEqualTo(TerminalPanelMetrics.collapsedTotalHeight),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('short viewport keeps the editor usable', (tester) async {
    // At a very short body the terminal must yield to the editor rather than
    // starve the code view (re_editor asserts on a zero-height line column).
    await fixture.mount(tester, size: const Size(1100, 175));
    expect(tester.view.physicalSize, const Size(1100, 175));
    await _openTerminal(tester);
    await tester.pump();
    // No layout exception, and the terminal is hidden to protect the editor.
    expect(tester.takeException(), isNull);
    expect(find.byType(CodeEditor), findsOneWidget);
    expect(tester.getSize(find.byType(CodeEditor)).height, greaterThan(0));
  });

  testWidgets('compact terminal still renders at a mid-short viewport', (
    tester,
  ) async {
    // Tall enough for the editor plus a usable terminal.
    await fixture.mount(tester, size: const Size(1100, 320));
    await _openTerminal(tester);
    await tester.pump();
    expect(tester.takeException(), isNull);
    final pane = find.byType(TerminalPane);
    expect(pane, findsOneWidget);
    // The terminal is visible and bounded by the viewport, and the editor keeps
    // a positive height (re_editor never collapses to zero).
    final paneHeight = tester.getSize(pane).height;
    expect(paneHeight, greaterThan(0));
    expect(paneHeight, lessThan(320));
    expect(tester.getSize(find.byType(CodeEditor)).height, greaterThan(0));
  });
}

Finder _resizeHandleFinder() => find.byWidgetPredicate(
  (widget) =>
      widget is MouseRegion && widget.cursor == SystemMouseCursors.resizeRow,
);

Future<void> _openTerminal(WidgetTester tester) async {
  await tester.tap(find.byTooltip('更多'));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 200));
  final item = find.byWidgetPredicate(
    (widget) => widget is PopupMenuItem<String> && widget.value == 'terminal',
  );
  expect(item, findsOneWidget);
  await tester.ensureVisible(item);
  await tester.pump(const Duration(milliseconds: 100));
  await tester.tap(item, warnIfMissed: false);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 200));
}

class _RecordingPreview implements WebFilePreviewSession {
  _RecordingPreview(this.root, this.entries, this.defaults);
  final String root;
  final List<String> entries;
  final List<String> defaults;
  @override
  String get url {
    defaults.add(root);
    throw StateError('factory default recorded before browser launch');
  }

  @override
  Stream<String> get debugStream => const Stream.empty();
  @override
  Future<void> stop() async {}
  @override
  String urlForFile(String absolutePath) {
    entries.add(absolutePath);
    throw StateError('preview entry recorded before browser launch');
  }
}

class _RecordingRunner implements ProgramRunner {
  final entries = <String>[];
  final roots = <String>[];
  final savedSources = <Map<String, String>>[];
  Future<int>? exitCode;

  @override
  Future<ProgramRunResult?> run({
    required String projectPath,
    required String entryFile,
  }) async {
    entries.add(entryFile);
    roots.add(projectPath);
    savedSources.add({
      for (final file in Directory(projectPath).listSync().whereType<File>())
        p.basename(file.path): file.readAsStringSync(),
    });
    final name = p.basenameWithoutExtension(entryFile);
    return ProgramRunResult(
      title: 'java $name',
      stdout: Stream.value('ran $name'),
      stderr: const Stream.empty(),
      exitCode: exitCode ?? Future.value(0),
    );
  }
}

class _EditorFixture {
  _EditorFixture() {
    final projectDirectory = Directory(p.join(directory.path, 'project'))
      ..createSync();
    project = Project.create(name: 'test project', path: projectDirectory.path);
    source('Main.java').writeAsStringSync('class Main {}\n');
    source('Main2.java').writeAsStringSync('class Main2 {}\n');
    final config = File(ProjectConfig.configPath(project.path));
    config.parent.createSync();
    config.writeAsStringSync(
      jsonEncode({'version': 1, 'entryFile': 'Main.java'}),
    );
  }

  final directory = Directory.systemTemp.createTempSync('qfli_editor_run_');
  final runner = _RecordingRunner();
  final auth = AuthStore();
  final store = ProjectStore();
  final settings = SettingsStore();
  late final Project project;

  File source(String name) => File(p.join(project.path, name));

  EditorController editor(WidgetTester tester) => tester
      .widget<EditorProblemsBar>(find.byType(EditorProblemsBar))
      .analysis
      .editor;

  Future<Directory> openSecondary(
    WidgetTester tester, {
    bool html = false,
  }) async {
    final root = Directory(p.join(directory.path, 'secondary'))..createSync();
    final entry = html ? 'custom.html' : 'Main.java';
    final active = html ? 'other.html' : 'Main2.java';
    File(
      p.join(root.path, entry),
    ).writeAsStringSync(html ? '<p>entry</p>' : 'class Main {}');
    File(
      p.join(root.path, active),
    ).writeAsStringSync(html ? '<p>other</p>' : 'class Main2 {}\r\n');
    final config = File(ProjectConfig.configPath(root.path));
    config.parent.createSync(recursive: true);
    config.writeAsStringSync(jsonEncode({'version': 1, 'entryFile': entry}));
    await tester.runAsync(
      () => editor(tester).openPath(
        p.join(root.path, active),
        ownerProjectName: 'secondary owner',
        ownerProjectPath: root.path,
        ownerProjectType: html ? 'web' : 'java',
      ),
    );
    await tester.pump();
    return root;
  }

  void installProfile({
    List<String> supportedExtensions = const ['.java'],
    bool isOffline = true,
  }) {
    StudioProfile.current = StudioProfile(
      id: 'test',
      appTitle: 'Editor test',
      templates: const [],
      runner: runner,
      isOffline: isOffline,
      entryFileNames: const ['Main.java'],
      supportedFileExtensions: supportedExtensions,
    );
  }

  Future<void> mount(
    WidgetTester tester, {
    String? initialOpenPath = 'Main2.java',
    Size size = const Size(1100, 850),
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(() async {
      // Tear down the widget while `tester` is still valid so EditorPage.dispose
      // can schedule its unawaited tab-history save.
      await tester.pumpWidget(const SizedBox.shrink());
      if (!_disposed) {
        _disposed = true;
        auth.dispose();
        store.dispose();
        settings.dispose();
      }
      await _disposeFixtureTree(tester, directory);
    });
    await tester.pumpWidget(
      MaterialApp(
        home: EditorPage(
          project: project,
          auth: auth,
          store: store,
          settings: settings,
          initialOpenPath: initialOpenPath,
        ),
      ),
    );
    await _pumpIoUntil(
      tester,
      () =>
          initialOpenPath == null ||
          find.byType(CodeEditor).evaluate().isNotEmpty,
    );
    await tester.pump(const Duration(milliseconds: 200));
  }

  var _disposed = false;

  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    auth.dispose();
    store.dispose();
    settings.dispose();
    // The temp tree is removed by the tester-backed tearDown registered in
    // `mount()`, which can drain the FakeAsync zone that holds the pending
    // history.json write. Here we only release the fixture stores.
  }
}

Future<void> _disposeFixtureTree(
  WidgetTester tester,
  Directory directory,
) async {
  // `EditorPage.dispose()` calls `unawaited(_saveHistory())` ->
  // `ProjectHistory.save` which awaits `Directory.create()` and then
  // `File.writeAsString(..., flush: true)` on `<project>/history.json`.
  //
  // Inside `testWidgets` that chain runs in the FakeAsync zone: real dart:io
  // completions are only delivered while `runAsync` is active, and the
  // continuations they post are microtasks that only drain on `pump`. A pure
  // real-time wait therefore never releases the open history.json handle, and
  // retrying deletion cannot help (verified: 31 retries over 3.1s still hit
  // errno 32). Alternate both zones until the deletion actually succeeds.
  const maxRounds = 50;
  FileSystemException? lastError;
  for (var round = 0; round < maxRounds; round++) {
    try {
      if (directory.existsSync()) await directory.delete(recursive: true);
      return;
    } on FileSystemException catch (error) {
      lastError = error;
      // Advance the FakeAsync zone (drains the write continuations), then the
      // real zone (lets the pending dart:io I/O complete).
      await tester.pump(const Duration(milliseconds: 20));
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
    }
  }
  // Do not silently pass: if the temporary tree is still locked after draining
  // both zones, this is a real leak worth failing on.
  throw lastError!;
}

Future<void> _waitForRun(
  WidgetTester tester,
  _RecordingRunner runner,
  int count,
) async {
  await _pumpIoUntil(
    tester,
    () =>
        runner.entries.length >= count &&
        find.byType(TerminalPane).evaluate().isNotEmpty &&
        !tester.state<TerminalPaneState>(find.byType(TerminalPane)).busy,
  );
  await tester.pump();
  expect(runner.entries, hasLength(count));
}

Future<void> _pumpIoUntil(
  WidgetTester tester,
  bool Function() condition,
) async {
  for (var attempt = 0; attempt < 200; attempt++) {
    await tester.pump(const Duration(milliseconds: 20));
    if (condition()) return;
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 10)),
    );
  }
  expect(condition(), isTrue, reason: 'The editor operation did not finish.');
}
