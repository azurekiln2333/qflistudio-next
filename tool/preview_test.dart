import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qfli_studio_core/app.dart';
import 'package:qfli_studio_core/community/models.dart';
import 'package:qfli_studio_core/services/app_paths.dart';
import 'package:qfli_studio_core/store/auth_store.dart';
import 'package:qfli_studio_core/store/project_store.dart';
import 'package:qfli_studio_core/store/settings_store.dart';

// flutter test --no-pub tool/preview_test.dart
// 可用 --dart-define=UI_FONT_PATH=... 指定含中文字符的本地字体。
void main() {
  testWidgets('导出个人页与设置的 MD3 预览', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    const fontPath = String.fromEnvironment(
      'UI_FONT_PATH',
      defaultValue: 'C:/Windows/Fonts/msyh.ttc',
    );
    await tester.runAsync(() async {
      await AppPaths.storageDirectory();
      await (FontLoader(
        'MaterialIcons',
      )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
      if (await File(fontPath).exists()) {
        final bytes = await File(fontPath).readAsBytes();
        await (FontLoader(
          'Roboto',
        )..addFont(Future.value(ByteData.sublistView(bytes)))).load();
      }
    });
    final store = ProjectStore();
    final auth = AuthStore();
    final settings = SettingsStore();
    await auth.signIn(
      'preview-only',
      const CommunityUser(
        id: 1,
        username: 'qfli_dev',
        nickname: '清风',
        bio: '写一点代码，记录一点想法。',
        avatarColor: '#4D6994',
        points: 1280,
        checkinStreak: 7,
        provider: 'local',
      ),
    );
    final boundaryKey = GlobalKey();
    await tester.pumpWidget(
      RepaintBoundary(
        key: boundaryKey,
        child: QfliApp(store: store, auth: auth, settings: settings),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.person_outline));
    await tester.pumpAndSettle();

    Future<void> capture(String name) async {
      expect(tester.takeException(), isNull);
      final boundary =
          boundaryKey.currentContext!.findRenderObject()!
              as RenderRepaintBoundary;
      await tester.runAsync(() async {
        final image = await boundary.toImage(pixelRatio: 2);
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        final file = File('docs/previews/$name.png');
        await file.parent.create(recursive: true);
        await file.writeAsBytes(bytes!.buffer.asUint8List());
        image.dispose();
      });
    }

    await capture('profile-light');
    await settings.setThemeMode('dark');
    await tester.pumpAndSettle();
    await capture('profile-dark');
    await settings.setThemeMode('light');
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('设置'));
    await tester.pumpAndSettle();
    await capture('settings-light');
    await tester.pumpWidget(const SizedBox());
    store.dispose();
    auth.dispose();
    settings.dispose();
  });
}
