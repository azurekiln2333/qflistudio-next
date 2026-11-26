import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qfli_studio_core/content/content_repository.dart';
import 'package:qfli_studio_core/content/local_content_adapter.dart';
import 'package:qfli_studio_core/i18n/studio_localizations.dart';
import 'package:qfli_studio_core/pages/local_content_pages.dart';
import 'package:qfli_studio_core/services/example_code_store.dart';
import 'package:qfli_studio_core/services/studio_profile.dart';
import 'package:qfli_studio_core/services/tutorial_service.dart';
import 'package:qfli_studio_core/widgets/language_badge.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  StudioProfile? previousProfile;
  setUp(() {
    previousProfile = StudioProfile.current;
    StudioProfile.current = const StudioProfile(
      id: 'forge',
      appTitle: 'QFLIForge',
      templates: [],
      productKey: 'forge',
      isOffline: true,
    );
  });
  tearDown(() => StudioProfile.current = previousProfile);

  test(
    'adapter retains language and difficulty through lesson/example models',
    () async {
      final repository = _Repository();
      final tutorial = (await LocalContentAdapter.loadTutorial(
        repository: repository,
        language: 'c',
        displayName: 'Forge',
        productKey: 'forge',
      ))!;
      final examples = await LocalContentAdapter.loadExamples(
        repository: repository,
        language: 'c',
        productKey: 'forge',
      );
      expect(tutorial.allLessons.map((lesson) => lesson.language), [
        'c',
        'cpp',
        'cpp',
      ]);
      expect(tutorial.allLessons.map((lesson) => lesson.level), [
        'beginner',
        'beginner',
        'advanced',
      ]);
      expect(examples.last.level, 'advanced');
      expect(examples.last.concepts, ['vector', 'raii']);
      expect(examples.last.copyWith(code: 'edited').language, 'cpp');
      expect(examples.last.copyWith(code: 'edited').level, 'advanced');
    },
  );

  test('legacy parser preserves explicit and inherited catalog metadata', () {
    final tutorial = TutorialService.parse(
      'cpp',
      jsonEncode({
        'language': 'cpp',
        'type': 'cpp',
        'level': 'beginner',
        'chapters': [
          {
            'id': 'chapter',
            'level': 'advanced',
            'lessons': [
              {'id': 'lesson', 'title': 'Ownership', 'code': 'int main() {}'},
            ],
          },
        ],
      }),
    );
    expect(tutorial.allLessons.single.language, 'cpp');
    expect(tutorial.allLessons.single.level, 'advanced');
    expect(tutorial.examples.single.language, 'cpp');
    expect(tutorial.examples.single.level, 'advanced');
    final explicit = TutorialService.parse(
      'c',
      jsonEncode({
        'language': 'c',
        'type': 'c',
        'level': 'beginner',
        'examples': [
          {
            'id': 'explicit',
            'language': 'cpp',
            'type': 'cpp',
            'level': 'advanced',
          },
        ],
      }),
    );
    expect(explicit.examples.single.language, 'cpp');
    expect(explicit.examples.single.level, 'advanced');
  });

  test(
    'legacy saved override inherits bundled metadata and survives reload',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'qfli_filter_metadata_',
      );
      addTearDown(() => directory.delete(recursive: true));
      final file = File('${directory.path}/examples.json');
      await file.writeAsString(
        jsonEncode({
          'contentVersion': ExampleCodeStore.contentVersion,
          'examples': [
            {
              'id': 'cpp-advanced',
              'type': 'cpp',
              'title': 'Saved title',
              'code': 'my code',
            },
          ],
        }),
      );
      final defaults = await LocalContentAdapter.loadExamples(
        repository: _Repository(),
        language: 'c',
        productKey: 'forge',
      );
      final store = ExampleCodeStore(storageFile: file);
      addTearDown(store.dispose);
      await store.load(defaults: defaults);
      final saved = store.items.last;
      expect(saved.code, 'my code');
      expect(saved.title, 'Saved title');
      expect(saved.language, 'cpp');
      expect(saved.level, 'advanced');
      expect(saved.concepts, ['vector', 'raii']);
      await store.upsert(saved.copyWith(code: 'edited again'));
      final reloaded = ExampleCodeStore(storageFile: file);
      addTearDown(reloaded.dispose);
      await reloaded.load();
      expect(reloaded.items.single.language, 'cpp');
      expect(reloaded.items.single.level, 'advanced');
      expect(reloaded.items.single.code, 'edited again');
      expect(reloaded.items.single.concepts, ['vector', 'raii']);
    },
  );

  for (final tutorials in [true, false]) {
    testWidgets(
      '${tutorials ? 'tutorials' : 'examples'} combine language, level and query without reloading',
      (tester) async {
        tester.view.physicalSize = const Size(1000, 1200);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final repository = _Repository();
        await tester.pumpWidget(
          _app(
            tutorials
                ? LocalTutorialsTab(language: 'c', repository: repository)
                : ExampleCodeTab(language: 'c', repository: repository),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('C vector basics'), findsOneWidget);
        expect(find.text('C++ vector basics'), findsOneWidget);
        expect(find.text('C++ vector ownership'), findsOneWidget);
        expect(find.text('Excluded Python'), findsNothing);
        await tester.tap(find.byKey(const ValueKey('content-language-cpp')));
        await tester.pumpAndSettle();
        expect(find.text('C vector basics'), findsNothing);
        expect(find.text('C++ vector basics'), findsOneWidget);
        await tester.tap(find.byKey(const ValueKey('content-level-advanced')));
        await tester.pumpAndSettle();
        expect(find.text('C++ vector basics'), findsNothing);
        expect(find.text('C++ vector ownership'), findsOneWidget);
        await tester.enterText(
          find.byKey(const ValueKey('content-query')),
          'missing',
        );
        await tester.pumpAndSettle();
        expect(
          find.byKey(const ValueKey('content-no-results')),
          findsOneWidget,
        );
        await tester.enterText(
          find.byKey(const ValueKey('content-query')),
          'raii',
        );
        await tester.pumpAndSettle();
        expect(find.text('C++ vector ownership'), findsOneWidget);
        await tester.tap(find.text('C++ vector ownership'));
        await tester.pumpAndSettle();
        final badge = tester.widget<LanguageBadge>(
          find.descendant(
            of: find.byType(AppBar),
            matching: find.byType(LanguageBadge),
          ),
        );
        expect(languageLabel(badge.language), 'C++');
        await tester.pageBack();
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('content-reset')));
        await tester.pumpAndSettle();
        expect(find.text('C vector basics'), findsOneWidget);
        expect(find.text('C++ vector basics'), findsOneWidget);
        expect(find.text('C++ vector ownership'), findsOneWidget);
        expect(repository.tutorialRequests, tutorials ? 1 : 0);
        // Legacy lessons resolve missing fixtures from examples once on load.
        expect(repository.exampleRequests, 1);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'HTML executable examples retain CSS and JavaScript subject chips and badges',
    (tester) async {
      StudioProfile.current = const StudioProfile(
        id: 'web',
        appTitle: 'Web',
        templates: [],
        productKey: 'webforge',
        isOffline: true,
      );
      final repository = _Repository(
        rows: [
          for (final language in ['html', 'css', 'javascript'])
            {
              'id': language,
              'type': 'html',
              'language': language,
              'level': 'beginner',
              'title': '$language subject',
              'summary': 'Executable document',
              'code': '<p>Demo</p>',
            },
        ],
      );
      for (final tutorials in [true, false]) {
        await tester.pumpWidget(
          _app(
            tutorials
                ? LocalTutorialsTab(language: 'html', repository: repository)
                : ExampleCodeTab(language: 'html', repository: repository),
          ),
        );
        await tester.pumpAndSettle();
        expect(
          find.byKey(const ValueKey('content-language-css')),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey('content-language-javascript')),
          findsOneWidget,
        );
        await tester.tap(find.byKey(const ValueKey('content-language-css')));
        await tester.pumpAndSettle();
        expect(find.text('html subject'), findsNothing);
        expect(find.text('javascript subject'), findsNothing);
        expect(find.text('css subject'), findsOneWidget);
        final badge = tester.widget<LanguageBadge>(
          find.descendant(
            of: find.ancestor(
              of: find.text('css subject'),
              matching: find.byType(ListTile),
            ),
            matching: find.byType(LanguageBadge),
          ),
        );
        expect(badge.language, 'css');
        await tester.tap(find.text('css subject'));
        await tester.pumpAndSettle();
        expect(
          tester
              .widget<LanguageBadge>(
                find.descendant(
                  of: find.byType(AppBar),
                  matching: find.byType(LanguageBadge),
                ),
              )
              .language,
          'css',
        );
        await tester.pageBack();
        await tester.pumpAndSettle();
        await tester.pumpWidget(const SizedBox());
      }
    },
  );

  testWidgets(
    'single-language filters stay usable at narrow width and large text',
    (tester) async {
      tester.view.physicalSize = const Size(320, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      StudioProfile.current = null;
      await tester.pumpWidget(
        _app(
          ExampleCodeTab(language: 'c', repository: _Repository()),
          scale: 1.8,
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('content-language-c')), findsOneWidget);
      expect(find.byKey(const ValueKey('content-language-cpp')), findsNothing);
      await tester.tap(find.byKey(const ValueKey('content-language-c')));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('C vector basics'),
        200,
        scrollable: find
            .descendant(
              of: find.byType(ListView),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      expect(find.text('C vector basics'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  for (final tutorials in [true, false]) {
    testWidgets(
      'null-profile ${tutorials ? 'tutorials' : 'examples'} aggregate the main id and keep language-only queries',
      (tester) async {
        tester.view.physicalSize = const Size(1000, 1200);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        StudioProfile.current = null;
        final repository = _Repository();

        Widget page(String language) => tutorials
            ? LocalTutorialsTab(
                key: ValueKey(language),
                language: language,
                repository: repository,
              )
            : ExampleCodeTab(
                key: ValueKey(language),
                language: language,
                repository: repository,
              );

        await tester.pumpWidget(_app(page(' QFLIStudio ')));
        await tester.pumpAndSettle();
        for (final language in ['c', 'cpp', 'python']) {
          expect(
            find.byKey(ValueKey('content-language-$language')),
            findsOneWidget,
          );
        }
        await tester.tap(find.byKey(const ValueKey('content-language-python')));
        await tester.pumpAndSettle();
        expect(find.text('Excluded Python'), findsOneWidget);
        expect(find.text('C vector basics'), findsNothing);

        await tester.pumpWidget(_app(page('python')));
        await tester.pumpAndSettle();
        expect(find.text('Excluded Python'), findsOneWidget);
        expect(
          find.byKey(const ValueKey('content-language-python')),
          findsOneWidget,
        );
        expect(find.byKey(const ValueKey('content-language-c')), findsNothing);
        expect(
          find.byKey(const ValueKey('content-language-cpp')),
          findsNothing,
        );
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }
}

MaterialApp _app(Widget home, {double scale = 1}) => MaterialApp(
  locale: const Locale('en'),
  supportedLocales: StudioLocalizations.supportedLocales,
  localizationsDelegates: const [
    StudioLocalizations.delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ],
  builder: (context, child) => MediaQuery(
    data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale)),
    child: child!,
  ),
  home: home,
);

class _Repository implements ContentRepository {
  _Repository({List<Map<String, Object>>? rows})
    : catalog = ContentCatalog.fromJson(
        tutorialsSource: jsonEncode({
          'entries': [
            for (final row in rows ?? _rows)
              {
                ...row,
                'title': 'Chapter ${row['id']}',
                'lessons': [
                  {
                    ...row,
                    'id': 'lesson-${row['id']}',
                    'explain': 'Explanation',
                  },
                ],
              },
          ],
        }),
        examplesSource: jsonEncode({'entries': rows ?? _rows}),
      );

  int tutorialRequests = 0;
  int exampleRequests = 0;
  final ContentCatalog catalog;

  @override
  Future<ContentCatalog> load() async => catalog;
  @override
  Future<List<TutorialContent>> tutorials({
    ContentFilter filter = const ContentFilter(),
  }) async {
    tutorialRequests++;
    return catalog.tutorials.where(filter.matches).toList();
  }

  @override
  Future<List<ExampleContent>> examples({
    ContentFilter filter = const ContentFilter(),
  }) async {
    exampleRequests++;
    return catalog.examples.where(filter.matches).toList();
  }
}

final _rows = [
  for (final (id, type, level, title) in [
    ('c-beginner', 'c', 'beginner', 'C vector basics'),
    ('cpp-beginner', 'cpp', 'beginner', 'C++ vector basics'),
    ('cpp-advanced', 'cpp', 'advanced', 'C++ vector ownership'),
    ('python', 'python', 'beginner', 'Excluded Python'),
  ])
    {
      'id': id,
      'type': type,
      'language': type,
      'level': level,
      'title': title,
      'summary': 'Summary',
      'concepts': ['vector', if (id == 'cpp-advanced') 'raii'],
      'code': 'int main(void) { return 0; }',
      'expectedOutput': '',
    },
];
