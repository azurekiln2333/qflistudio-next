import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
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
      id: 'forge',
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
        home: LocalTutorialsTab(language: 'c'),
      ),
    );
    await tester.pumpAndSettle();
    final l10n = StudioLocalizations.of(
      tester.element(find.byType(Scaffold)),
    );
    expect(
      find.text('${StudioProductCatalog.forge} ${l10n.tutorial}'),
      findsOneWidget,
    );
    expect(find.text('第一章 从零开始'), findsOneWidget);

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
        home: ExampleCodeTab(language: 'c'),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.text('${StudioProductCatalog.forge} ${l10n.examples}'),
      findsOneWidget,
    );
    expect(find.byIcon(Icons.copy_outlined), findsWidgets);
  });
}
