import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:qfli_studio_core/i18n/studio_localizations.dart';
import 'package:qfli_studio_core/content/content_repository.dart';
import 'package:qfli_studio_core/models/project.dart';
import 'package:qfli_studio_core/pages/community/post_list_page.dart';
import 'package:qfli_studio_core/pages/home_page.dart';
import 'package:qfli_studio_core/pages/local_content_pages.dart';
import 'package:qfli_studio_core/services/app_paths.dart';
import 'package:qfli_studio_core/services/studio_profile.dart';
import 'package:qfli_studio_core/services/task_activity_service.dart';
import 'package:qfli_studio_core/store/auth_store.dart';
import 'package:qfli_studio_core/store/project_store.dart';
import 'package:qfli_studio_core/store/settings_store.dart';
import 'package:qfli_studio_core/theme/app_theme.dart';
import 'package:qfli_studio_core/widgets/project_card.dart';
import 'package:qfli_studio_core/workspace/saved_workspaces_tab.dart';
import 'package:qflistudio/content/studio_content_repository.dart';
import 'package:qflistudio/main.dart' show qfliStudioProfile;

/// Exercises the production main profile through Home's actual page routing.
/// Catalog tests alone cannot catch a shell that still opens the online feed.
void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();
  const pathsChannel = MethodChannel('plugins.flutter.io/path_provider');
  late Directory root;
  StudioProfile? previousProfile;

  /// 已加载的组合目录，与它所属的仓库。
  ///
  /// 在 `setUpAll` 里预热：那时 binding 还肯投递真实 I/O 回调。
  late StudioContentRepository bundledRepository;
  late ContentCatalog bundledCatalog;

  setUpAll(() async {
    root = await Directory.systemTemp.createTemp('qfli_studio_home_release_');
    binding.defaultBinaryMessenger.setMockMethodCallHandler(
      pathsChannel,
      (call) async => switch (call.method) {
        'getApplicationSupportDirectory' ||
        'getApplicationDocumentsDirectory' ||
        'getTemporaryDirectory' => root.path,
        _ => null,
      },
    );
    // Fail before creating app metadata if the path provider is not isolated.
    expect(await AppPaths.storageDirectory(), root.path);
    await AppPaths.projectsRoot(create: true);
    await TaskActivityService.instance.initialize();
    bundledRepository = qfliStudioProfile.contentRepositoryFactory!()
        as StudioContentRepository;
    final catalog = await binding.runAsync(
      () => bundledRepository.load(),
    );
    bundledCatalog = catalog!;
  });

  setUp(() {
    previousProfile = StudioProfile.current;
    StudioProfile.current = qfliStudioProfile;
  });

  tearDown(() => StudioProfile.current = previousProfile);

  tearDownAll(() async {
    binding.defaultBinaryMessenger.setMockMethodCallHandler(pathsChannel, null);
    if (root.existsSync()) await root.delete(recursive: true);
  });

  testWidgets(
    'an offline product Home hides cloud scope, creation and registered cloud cards and opens workspaces',
    (tester) async {
      // The cloud scope is hidden by the offline product tier, not by the main
      // App's identity. This case pins that tier; the networked main App is
      // pinned separately below.
      final fixture = await _mount(
        tester,
        root,
        profile: StudioProfile(
          id: qfliStudioProfile.id,
          appTitle: qfliStudioProfile.appTitle,
          templates: qfliStudioProfile.templates,
          productKey: qfliStudioProfile.productKey,
          isOffline: false,
          offlineOnly: true,
          showHomeTabs: qfliStudioProfile.showHomeTabs,
          runtimeKind: qfliStudioProfile.runtimeKind,
          runtimeStatus: qfliStudioProfile.runtimeStatus,
          supportedFileExtensions: qfliStudioProfile.supportedFileExtensions,
          contentRepositoryFactory: qfliStudioProfile.contentRepositoryFactory,
        ),
      );
      final l10n = StudioLocalizations.of(tester.element(find.byType(HomeTab)));
      final scopes = find.byType(TabBar);
      expect(scopes, findsOneWidget);
      for (final label in [
        l10n.allProjects,
        l10n.historyProjects,
        l10n.favoriteProjects,
        '工作区',
      ]) {
        expect(
          find.descendant(of: scopes, matching: find.text(label)),
          findsOneWidget,
        );
      }
      expect(
        find.descendant(of: scopes, matching: find.byType(Tab)),
        findsNWidgets(4),
      );
      expect(find.text(l10n.cloudProjects), findsNothing);
      expect(_visibleProjects(tester), ['Local release project']);
      // Hidden cloud data remains in the real registry.
      expect(
        fixture.projects.projects.map((project) => project.name),
        containsAll(['Local release project', 'Cloud release project']),
      );

      await tester.tap(
        find.descendant(
          of: find.descendant(
            of: find.byType(HomeTab),
            matching: find.byType(AppBar),
          ),
          matching: find.byType(PopupMenuButton<String>),
        ),
      );
      await _settle(tester);
      expect(find.text('导入项目（.qsz）'), findsOneWidget);
      expect(find.text(l10n.newCloudProject), findsNothing);
      expect(find.byIcon(Icons.cloud_upload_outlined), findsNothing);
      await tester.binding.handlePopRoute();
      await _settle(tester);

      final workspaceTab = find.descendant(
        of: scopes,
        matching: find.text('工作区'),
      );
      await tester.ensureVisible(workspaceTab);
      await tester.tap(workspaceTab);
      await _waitFor(
        tester,
        () => find.text('还没有保存的工作区').evaluate().isNotEmpty,
        'saved-workspaces empty state',
      );
      expect(find.byType(SavedWorkspacesTab), findsOneWidget);
      expect(fixture.projects.projects, hasLength(2));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'the networked main App Home keeps the cloud scope and its creation entry',
    (tester) async {
      // The main App is a networked product: isOffline false and offlineOnly
      // unset. Hiding the cloud scope here would also make ApiClient refuse
      // network calls, drop the online terminal and switch the about page to
      // offline copy.
      await _mount(tester, root);
      final l10n = StudioLocalizations.of(tester.element(find.byType(HomeTab)));
      final scopes = find.byType(TabBar);
      expect(
        find.descendant(of: scopes, matching: find.text(l10n.cloudProjects)),
        findsOneWidget,
      );
      expect(
        find.descendant(of: scopes, matching: find.byType(Tab)),
        findsNWidgets(5),
      );
      await tester.tap(
        find.descendant(
          of: find.descendant(
            of: find.byType(HomeTab),
            matching: find.byType(AppBar),
          ),
          matching: find.byType(PopupMenuButton<String>),
        ),
      );
      await _settle(tester);
      expect(find.text(l10n.newCloudProject), findsOneWidget);
      await tester.binding.handlePopRoute();
      await _settle(tester);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'production Home opens bundled local tutorials and examples without publishing controls',
    (tester) async {
      await _mount(tester, root);
      await _selectPage(tester, 2);
      await _waitFor(
        tester,
        () => _cppFilter(LocalTutorialsTab).evaluate().isNotEmpty,
        'production main tutorial catalog',
      );
      expect(find.byType(TutorialsTab), findsNothing);
      expect(find.byType(PostListPage), findsNothing);
      final tutorial = tester.widget<LocalTutorialsTab>(
        find.byType(LocalTutorialsTab),
      );
      expect(tutorial.language, qfliStudioProfile.id);
      expect(tutorial.repository, isA<StudioContentRepository>());
      final repository = tutorial.repository!;
      final catalogFuture = repository.load();
      final catalog = (await tester.runAsync(() => catalogFuture))!;
      expect(catalog.tutorials, isNotEmpty);
      final lessonCount = catalog.tutorials.fold<int>(
        0,
        (sum, item) => sum + item.lessons.length,
      );
      expect(find.text('$lessonCount lessons'), findsOneWidget);
      expect(find.byKey(const ValueKey('content-language-c')), findsOneWidget);
      expect(
        find.byKey(const ValueKey('content-language-cpp')),
        findsOneWidget,
      );
      expect(find.text('写教程'), findsNothing);
      final tutorialSurface = find.byType(LocalTutorialsTab);
      expect(
        find.descendant(
          of: tutorialSurface,
          matching: find.byType(FloatingActionButton),
        ),
        findsNothing,
      );
      expect(
        find.descendant(of: tutorialSurface, matching: find.byIcon(Icons.add)),
        findsNothing,
      );
      final header = tester.widget<AppBar>(
        find.descendant(of: tutorialSurface, matching: find.byType(AppBar)),
      );
      expect(header.centerTitle, isFalse);
      expect(header.actions, isNull);

      await _selectPage(tester, 3);
      await _waitFor(
        tester,
        () => _cppFilter(ExampleCodeTab).evaluate().isNotEmpty,
        'production main example catalog',
      );
      final examples = tester.widget<ExampleCodeTab>(
        find.byType(ExampleCodeTab),
      );
      expect(examples.repository, same(repository));
      expect(repository.load(), same(catalogFuture));
      final l10n = StudioLocalizations.of(
        tester.element(find.byType(ExampleCodeTab)),
      );
      expect(find.text(l10n.localExamplesMissing), findsNothing);
      expect(
        find.text(l10n.examplesCount(catalog.examples.length)),
        findsOneWidget,
      );
      expect(
        catalog.examples.every((example) => example.code.trim().isNotEmpty),
        isTrue,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'main content factory stays lazy and runs once across retained tutorial and example routes',
    (tester) async {
      var factoryCalls = 0;
      // Real asset I/O stops arriving from the fake-async zone once earlier
      // widget tests in this file have run, so the page would spin forever.
      // The catalogue was warmed in setUpAll; hand the page a repository that
      // only replays that finished load. The laziness and single-instance
      // assertions below still hold: the factory is not called until the
      // tutorial route mounts, and it is called exactly once.
      // Retain the main product's production flags and real bundled factory,
      // adding only a counter at its public injection boundary.
      StudioProfile.current = StudioProfile(
        id: qfliStudioProfile.id,
        appTitle: qfliStudioProfile.appTitle,
        templates: qfliStudioProfile.templates,
        productKey: qfliStudioProfile.productKey,
        isOffline: qfliStudioProfile.isOffline,
        offlineOnly: qfliStudioProfile.offlineOnly,
        showHomeTabs: qfliStudioProfile.showHomeTabs,
        runtimeKind: qfliStudioProfile.runtimeKind,
        runtimeStatus: qfliStudioProfile.runtimeStatus,
        supportedFileExtensions: qfliStudioProfile.supportedFileExtensions,
        contentRepositoryFactory: () {
          factoryCalls++;
          return _WarmRepository(bundledCatalog);
        },
      );
      await _mount(tester, root);
      expect(factoryCalls, 0);
      await _selectPage(tester, 1);
      expect(factoryCalls, 0);
      await _selectPage(tester, 2);
      await _waitFor(
        tester,
        () => _cppFilter(LocalTutorialsTab).evaluate().isNotEmpty,
        'lazy tutorial route',
      );
      expect(factoryCalls, 1);
      final repository = tester
          .widget<LocalTutorialsTab>(find.byType(LocalTutorialsTab))
          .repository;
      expect(repository, isA<StudioContentRepository>());
      await _selectPage(tester, 3);
      await _waitFor(
        tester,
        () => _cppFilter(ExampleCodeTab).evaluate().isNotEmpty,
        'shared example route',
      );
      expect(
        tester.widget<ExampleCodeTab>(find.byType(ExampleCodeTab)).repository,
        same(repository),
      );
      await _selectPage(tester, 0);
      await _selectPage(tester, 2);
      await _selectPage(tester, 3);
      expect(factoryCalls, 1);
      expect(
        tester.widget<ExampleCodeTab>(find.byType(ExampleCodeTab)).repository,
        same(repository),
      );
      expect(tester.takeException(), isNull);
    },
  );
}

Future<_Fixture> _mount(
  WidgetTester tester,
  Directory root, {
  StudioProfile? profile,
}) async {
  if (profile != null) StudioProfile.current = profile;
  tester.view.physicalSize = const Size(600, 1000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final fixture = _Fixture.create(root);
  addTearDown(() async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    fixture.projects.dispose();
    fixture.auth.dispose();
    fixture.settings.dispose();
    await tester.runAsync(() => fixture.directory.delete(recursive: true));
  });
  await tester.runAsync(() => fixture.projects.load());
  await tester.pumpWidget(
    MaterialApp(
      locale: const Locale('en'),
      supportedLocales: StudioLocalizations.supportedLocales,
      localizationsDelegates: const [
        StudioLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: AppTheme.light,
      home: HomePage(
        store: fixture.projects,
        auth: fixture.auth,
        settings: fixture.settings,
      ),
    ),
  );
  await _settle(tester);
  return fixture;
}

Future<void> _selectPage(WidgetTester tester, int index) async {
  // The page movement finishes before NavigationBar's own selected-destination
  // animation starts. Let that finite animation settle before the next tap.
  for (var frame = 0; frame < 20; frame++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
  final destinations = find.descendant(
    of: find.byType(NavigationBar),
    matching: find.byWidgetPredicate((widget) => widget is InkResponse),
  );
  expect(destinations, findsNWidgets(5));
  await tester.tap(destinations.at(index));
  await _settle(tester);
  expect(
    tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
    index,
  );
}

Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 500));
  await tester.pump();
}

Future<void> _waitFor(
  WidgetTester tester,
  bool Function() condition,
  String description,
) async {
  for (var attempt = 0; attempt < 600; attempt++) {
    // Bundled asset I/O and isolate parsing need real event-loop time. These
    // bounded polls establish completion, not a device frame-time guarantee.
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 10)),
    );
    await tester.pump(const Duration(milliseconds: 20));
    if (condition()) return;
  }
  final selected = find.byType(NavigationBar).evaluate().isEmpty
      ? null
      : tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex;
  final visibleText = tester
      .widgetList<Text>(find.byType(Text))
      .map((text) => text.data)
      .whereType<String>()
      .take(30)
      .join(' | ');
  fail(
    'Timed out waiting for $description (navigation=$selected, visible=$visibleText)',
  );
}

List<String> _visibleProjects(WidgetTester tester) => tester
    .widgetList<ProjectCard>(find.byType(ProjectCard).hitTestable())
    .map((card) => card.project.name)
    .toList();

Finder _cppFilter(Type pageType) => find.descendant(
  of: find.byType(pageType),
  matching: find.byKey(const ValueKey('content-language-cpp')),
);

class _Fixture {
  _Fixture(this.directory, this.projects);

  final Directory directory;
  final ProjectStore projects;
  final auth = _SignedInVisibilityAuth();
  final settings = SettingsStore();

  factory _Fixture.create(Directory root) {
    final directory = root.createTempSync('registry_');
    Project project(String id, String name, {String? cloudId}) {
      final projectDirectory = Directory(p.join(directory.path, id))
        ..createSync();
      File(
        p.join(projectDirectory.path, 'main.c'),
      ).writeAsStringSync('int main(void) { return 0; }');
      return Project(
        id: id,
        name: name,
        path: projectDirectory.path,
        createdAt: DateTime.utc(2026),
        lastOpenedAt: DateTime.utc(2026, 10, 23),
        favorite: true,
        cloudId: cloudId,
        language: 'C',
        type: 'c',
      );
    }

    final projects = [
      project('local', 'Local release project'),
      project('cloud', 'Cloud release project', cloudId: 'release-cloud'),
    ];
    final registry = File(p.join(directory.path, 'projects.json'))
      ..writeAsStringSync(
        jsonEncode({
          'version': 1,
          'projects': [for (final project in projects) project.toJson()],
        }),
      );
    return _Fixture(directory, ProjectStore(storageFile: registry));
  }
}

/// Exercise the signed-in visibility gate without a token or remote requests.
class _SignedInVisibilityAuth extends AuthStore {
  @override
  bool get isLoggedIn => true;
}

/// Replays a warmed catalogue load, warming it on the first call.
///
/// Bundled asset I/O is delivered through a real event loop. A widget test's
/// fake-async zone stops forwarding those completions once earlier widget
/// tests in the same file have run, so the page would stay on a spinner.
/// The first read awaits the warm-up inside `runAsync`; every later read finds
/// the catalogue already loaded.
/// Replays an already-loaded catalogue.
///
/// Bundled asset I/O is delivered through a real event loop. A widget test's
/// fake-async zone stops forwarding those completions once earlier widget
/// tests in the same file have run, so the page would spin forever. The
/// catalogue is warmed in `setUpAll` and replayed here, which keeps the type
/// the shell expects while removing the I/O from the widget test.
class _WarmRepository extends StudioContentRepository {
  _WarmRepository(ContentCatalog catalog) : _catalog = catalog;

  /// 已在 `setUpAll` 里加载完成的目录。
  final ContentCatalog _catalog;

  @override
  Future<ContentCatalog> load() async => _catalog;

  @override
  Future<List<TutorialContent>> tutorials({
    ContentFilter filter = const ContentFilter(),
  }) async => [
    for (final tutorial in _catalog.tutorials)
      if (filter.matches(tutorial)) tutorial,
  ];

  @override
  Future<List<ExampleContent>> examples({
    ContentFilter filter = const ContentFilter(),
  }) async => [
    for (final example in _catalog.examples)
      if (filter.matches(example)) example,
  ];
}
