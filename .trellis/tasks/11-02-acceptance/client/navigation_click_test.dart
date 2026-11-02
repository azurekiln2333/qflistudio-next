@TestOn('vm')
library;

import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qfli_studio_core/config/agreement_config.dart';
import 'package:qfli_studio_core/i18n/studio_localizations.dart';
import 'package:qfli_studio_core/pages/auth/agreement_page.dart';
import 'package:qfli_studio_core/pages/home_page.dart';
import 'package:qfli_studio_core/pages/profile_page.dart';
import 'package:qfli_studio_core/pages/settings_page.dart';
import 'package:qfli_studio_core/services/app_paths.dart';
import 'package:qfli_studio_core/services/studio_profile.dart';
import 'package:qfli_studio_core/store/auth_store.dart';
import 'package:qfli_studio_core/store/project_store.dart';
import 'package:qfli_studio_core/store/settings_store.dart';
import 'package:qflistudio/main.dart' show qfliStudioProfile;

// Test-local fixture. Every route, destination and tile is production code.
// Scrolling makes lazy list tiles visible; only actual taps count as clicks.
void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();
  const paths = MethodChannel('plugins.flutter.io/path_provider');
  const host = MethodChannel('qflistudio/platform');
  late Directory root;
  late StudioProfile? oldProfile;
  late List<MethodCall> hostCalls;

  setUpAll(() async {
    root = await Directory.systemTemp.createTemp('qfli_acceptance_navigation_');
    binding.defaultBinaryMessenger.setMockMethodCallHandler(paths, (
      call,
    ) async {
      return switch (call.method) {
        'getApplicationSupportDirectory' ||
        'getApplicationDocumentsDirectory' ||
        'getTemporaryDirectory' => root.path,
        _ => null,
      };
    });
    expect(await AppPaths.storageDirectory(), root.path);
  });

  setUp(() {
    oldProfile = StudioProfile.current;
    StudioProfile.current = qfliStudioProfile;
    hostCalls = [];
    binding.defaultBinaryMessenger.setMockMethodCallHandler(host, (call) async {
      hostCalls.add(call);
      // Capture a real native-reader request without claiming native rendering.
      if (call.method == 'openAgreement') {
        throw PlatformException(
          code: 'acceptance.capture',
          message: 'Captured',
        );
      }
      return false;
    });
  });

  tearDown(() {
    StudioProfile.current = oldProfile;
    debugDefaultTargetPlatformOverride = null;
    binding.defaultBinaryMessenger.setMockMethodCallHandler(host, null);
  });

  tearDownAll(() {
    binding.defaultBinaryMessenger.setMockMethodCallHandler(paths, null);
    root.deleteSync(recursive: true);
  });

  for (final size in [const Size(360, 800), const Size(600, 1000)]) {
    for (final title in ['用户协议', '隐私政策']) {
      testWidgets('Home to $title uses 3 taps at ${size.width}x${size.height}', (
        tester,
      ) async {
        await _withOhos(() async {
          tester.view.physicalSize = size;
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.reset);
          final storage = root.createTempSync('stores_');
          final projects = ProjectStore(
            storageFile: File('${storage.path}/projects.json'),
          );
          final auth = AuthStore(
            storageFile: File('${storage.path}/auth.json'),
          );
          final settings = SettingsStore();
          addTearDown(() async {
            await tester.pumpWidget(const SizedBox.shrink());
            projects.dispose();
            auth.dispose();
            settings.dispose();
          });
          await tester.runAsync(projects.load);
          await tester.pumpWidget(
            MaterialApp(
              locale: const Locale('zh'),
              supportedLocales: StudioLocalizations.supportedLocales,
              localizationsDelegates: const [
                StudioLocalizations.delegate,
                GlobalMaterialLocalizations.delegate,
                GlobalWidgetsLocalizations.delegate,
                GlobalCupertinoLocalizations.delegate,
              ],
              home: HomePage(store: projects, auth: auth, settings: settings),
            ),
          );
          await tester.pumpAndSettle();
          expect(
            tester
                .widget<NavigationBar>(find.byType(NavigationBar))
                .selectedIndex,
            0,
          );
          var taps = 0;
          final destinations = find.descendant(
            of: find.byType(NavigationBar),
            matching: find.byWidgetPredicate((widget) => widget is InkResponse),
          );
          expect(destinations, findsNWidgets(5));
          await tester.tap(destinations.at(4));
          taps++;
          await tester.pumpAndSettle();
          expect(find.byType(ProfileTab), findsOneWidget);
          final profileList = find
              .descendant(
                of: find.byType(ProfileTab),
                matching: find.byType(Scrollable),
              )
              .first;
          final settingsTile = find.widgetWithText(ListTile, '设置');
          await tester.scrollUntilVisible(
            settingsTile,
            300,
            scrollable: profileList,
          );
          await tester.ensureVisible(settingsTile);
          await tester.pumpAndSettle();
          expect(settingsTile.hitTestable(), findsOneWidget);
          await tester.tap(settingsTile);
          taps++;
          await tester.pumpAndSettle();
          expect(find.byType(SettingsPage), findsOneWidget);
          final settingsList = find
              .descendant(
                of: find.byType(SettingsPage),
                matching: find.byType(Scrollable),
              )
              .first;
          final agreementTile = find.widgetWithText(ListTile, title);
          await tester.scrollUntilVisible(
            agreementTile,
            250,
            scrollable: settingsList,
          );
          await tester.ensureVisible(agreementTile);
          await tester.pumpAndSettle();
          expect(agreementTile.hitTestable(), findsOneWidget);
          await tester.tap(agreementTile);
          taps++;
          await tester.pumpAndSettle();
          expect(taps, 3);
          expect(find.byType(AgreementPage), findsOneWidget);
          if (title == '用户协议') {
            expect(userAgreementUrl, isEmpty);
            expect(find.text('协议暂未发布'), findsOneWidget);
            expect(
              hostCalls.where((c) => c.method == 'openAgreement'),
              isEmpty,
            );
          } else {
            final call = hostCalls.singleWhere(
              (c) => c.method == 'openAgreement',
            );
            expect(call.arguments, {'title': title, 'url': privacyPolicyUrl});
          }
          expect(tester.takeException(), isNull);
          // Raw evidence includes dimensions and the actual tap count.
          debugPrint(
            'ACCEPTANCE path=Home>我的>设置>$title taps=$taps '
            'viewport=${size.width}x${size.height} scrolls=allowed '
            'nativeReader=fixture userAgreementPublished=$userAgreementAvailable',
          );
        });
      });
    }
  }
}

Future<void> _withOhos(Future<void> Function() body) async {
  final old = debugDefaultTargetPlatformOverride;
  debugDefaultTargetPlatformOverride = TargetPlatform.ohos;
  try {
    await body();
  } finally {
    debugDefaultTargetPlatformOverride = old;
  }
}
