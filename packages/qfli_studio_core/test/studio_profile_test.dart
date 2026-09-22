import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:qfli_studio_core/content/content_repository.dart';
import 'package:qfli_studio_core/i18n/studio_localizations.dart';
import 'package:qfli_studio_core/pages/local_content_pages.dart';
import 'package:qfli_studio_core/services/studio_profile.dart';
import 'package:qfli_studio_core/services/tutorial_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late StudioProfile? previousProfile;

  setUp(() {
    previousProfile = StudioProfile.current;
    StudioProfile.current = const StudioProfile(
      id: 'c',
      appTitle: StudioProductCatalog.forge,
      templates: [],
      isOffline: true,
    );
    TutorialService.clearCache();
  });

  tearDown(() {
    StudioProfile.current = previousProfile;
  });

  test('离线档位不默认加入联网能力', () {
    expect(StudioProfile.current!.isOffline, isTrue);
  });

  testWidgets('教程页和示例代码页读取本地 C JSON', (tester) async {
    const repository = _FixtureContentRepository();
    await tester.pumpWidget(
      const MaterialApp(
        locale: Locale('zh', 'CN'),
        supportedLocales: StudioLocalizations.supportedLocales,
        localizationsDelegates: [
          StudioLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: LocalTutorialsTab(language: 'c', repository: repository),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    final l10n = StudioLocalizations.of(tester.element(find.byType(Scaffold)));
    expect(
      find.text('${StudioProductCatalog.forge} ${l10n.tutorial}'),
      findsOneWidget,
    );
    expect(find.text('C 001: 数据建模与不变量'), findsOneWidget);

    await tester.pumpWidget(
      const MaterialApp(
        locale: Locale('zh', 'CN'),
        supportedLocales: StudioLocalizations.supportedLocales,
        localizationsDelegates: [
          StudioLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: ExampleCodeTab(language: 'c', repository: repository),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(
      find.text('${StudioProductCatalog.forge} ${l10n.examples}'),
      findsOneWidget,
    );
    expect(find.byIcon(Icons.copy_outlined), findsWidgets);
    expect(find.text('C 示例 001: 数据建模与不变量'), findsOneWidget);
  });
}

class _FixtureContentRepository implements ContentRepository {
  const _FixtureContentRepository();

  static const _tutorial = TutorialContent(
    id: 'c-tutorial-001',
    language: 'c',
    type: 'c',
    locale: 'zh-CN',
    level: 'beginner',
    title: 'C 001: 数据建模与不变量',
    summary: 'A C tutorial',
    concepts: ['arrays'],
    source: 'fixture',
    license: 'fixture',
    updatedAt: '2026-09-22',
    lessons: [
      TutorialLessonContent(
        id: 'c-tutorial-001-lesson',
        title: '实现：数据建模与不变量',
        summary: 'Run a C example',
        concepts: ['output'],
        explain: 'Explain the example',
        code: '#include <stdio.h>',
        output: 'ok',
        exercises: [],
      ),
    ],
  );

  static const _example = ExampleContent(
    id: 'c-example-001',
    language: 'c',
    type: 'c',
    locale: 'zh-CN',
    level: 'beginner',
    title: 'C 示例 001: 数据建模与不变量',
    summary: 'A C example',
    concepts: ['output'],
    source: 'fixture',
    license: 'fixture',
    updatedAt: '2026-09-22',
    code: '#include <stdio.h>',
    expectedOutput: 'ok',
    inputFixtures: {},
    templateType: 'c',
  );

  static const _catalog = ContentCatalog(
    schemaVersion: 1,
    tutorials: [_tutorial],
    examples: [_example],
  );

  @override
  Future<ContentCatalog> load() async => _catalog;

  @override
  Future<List<TutorialContent>> tutorials({
    ContentFilter filter = const ContentFilter(),
  }) async => [
    for (final entry in _catalog.tutorials)
      if (filter.matches(entry)) entry,
  ];

  @override
  Future<List<ExampleContent>> examples({
    ContentFilter filter = const ContentFilter(),
  }) async => [
    for (final entry in _catalog.examples)
      if (filter.matches(entry)) entry,
  ];
}
