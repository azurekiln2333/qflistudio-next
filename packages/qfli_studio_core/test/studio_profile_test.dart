import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
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
      appTitle: 'QFLIStudio+ C 版',
      templates: const [],
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
      const MaterialApp(home: LocalTutorialsTab(language: 'c')),
    );
    await tester.pumpAndSettle();
    expect(find.text('C 教程'), findsOneWidget);
    expect(find.text('第一章 从零开始'), findsOneWidget);

    await tester.pumpWidget(
      const MaterialApp(home: ExampleCodeTab(language: 'c')),
    );
    await tester.pumpAndSettle();
    expect(find.text('C 示例代码'), findsOneWidget);
    expect(find.byIcon(Icons.copy_outlined), findsWidgets);
  });
}
