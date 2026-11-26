import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qfli_studio_core/editor/editor_analysis_controller.dart';
import 'package:qfli_studio_core/editor/editor_controller.dart';
import 'package:qfli_studio_core/editor/editor_problems_bar.dart';
import 'package:qfli_studio_core/models/project.dart';
import 'package:qfli_studio_core/services/studio_profile.dart';

void main() {
  for (final product in [
    StudioProductCatalog.qfliStudioKey,
    StudioProductCatalog.forgeKey,
  ]) {
    testWidgets('$product keeps provider availability scoped to the product', (
      tester,
    ) async {
      final previous = StudioProfile.current;
      final root = Directory.systemTemp.createTempSync('qfli-problems-');
      final editor = EditorController(
        project: Project.create(name: 'Source', path: root.path),
      );
      final analysis = EditorAnalysisController(editor: editor, analyzer: null);
      StudioProfile.current = StudioProfile(
        id: product,
        appTitle: product,
        productKey: product,
        templates: const [],
      );
      addTearDown(() {
        analysis.dispose();
        editor.dispose();
        StudioProfile.current = previous;
        root.deleteSync(recursive: true);
      });
      analysis.requestAnalysis();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: EditorProblemsBar(
              analysis: analysis,
              onOpenProblems: () {},
              child: const Text('editable source'),
            ),
          ),
        ),
      );
      expect(find.text('editable source'), findsOneWidget);
      expect(analysis.checked, isFalse);
      expect(analysis.unavailableReason, isNotNull);
      expect(
        find.byKey(const ValueKey('editor-problems-status')),
        product == StudioProductCatalog.qfliStudioKey
            ? findsNothing
            : findsOneWidget,
      );
    });
  }

  testWidgets(
    'a configured main-product analyzer retains the problems action',
    (tester) async {
      final previous = StudioProfile.current;
      final root = Directory.systemTemp.createTempSync('qfli-problems-');
      final editor = EditorController(
        project: Project.create(name: 'Source', path: root.path),
      );
      final analysis = EditorAnalysisController(
        editor: editor,
        analyzer: _Analyzer(),
      );
      StudioProfile.current = null;
      addTearDown(() {
        analysis.dispose();
        editor.dispose();
        StudioProfile.current = previous;
        root.deleteSync(recursive: true);
      });
      analysis.requestAnalysis();
      var opened = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: EditorProblemsBar(
              analysis: analysis,
              onOpenProblems: () => opened = true,
              child: const Text('editable source'),
            ),
          ),
        ),
      );
      await tester.tap(find.byKey(const ValueKey('editor-problems-status')));
      expect(opened, isTrue);
      expect(analysis.checked, isFalse);
    },
  );
}

class _Analyzer implements CodeAnalyzer {
  @override
  Future<CodeAnalysisResult> analyze(CodeAnalysisRequest request) async =>
      const CodeAnalysisResult();
}
