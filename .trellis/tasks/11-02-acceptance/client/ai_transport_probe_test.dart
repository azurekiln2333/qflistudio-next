@TestOn('vm')
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qfli_studio_core/editor/ai_panel.dart';
import 'package:qfli_studio_core/services/studio_profile.dart';
import 'package:qfli_studio_core/store/settings_store.dart';
import 'package:qflistudio/main.dart' show qfliStudioProfile;

// Characterization probe: success means the documented defect reproduced.
// A real loopback server receives the production panel's actual HTTP request.
// No external endpoint, production key, token, or real device is used.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late HttpServer server;
  late HttpClient client;
  final requests = <Map<String, Object?>>[];

  setUpAll(() async {
    final previous = HttpOverrides.current;
    HttpOverrides.global = null;
    try {
      client = HttpClient();
    } finally {
      HttpOverrides.global = previous;
    }
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((request) async {
      final body = jsonDecode(await utf8.decoder.bind(request).join());
      requests.add({
        'method': request.method,
        'path': request.uri.path,
        'model': (body as Map)['model'],
      });
      request.response.headers.contentType = ContentType.json;
      request.response.write(
        jsonEncode({
          'choices': [
            {
              'message': {
                'role': 'assistant',
                'content': 'Acceptance loopback reply',
              },
            },
          ],
        }),
      );
      await request.response.close();
    });
  });

  tearDownAll(() async {
    client.close(force: true);
    await server.close(force: true);
  });

  testWidgets('official profile still sends to a saved custom AI endpoint', (
    tester,
  ) async {
    final previousProfile = StudioProfile.current;
    final previousPlatform = debugDefaultTargetPlatformOverride;
    StudioProfile.current = qfliStudioProfile;
    debugDefaultTargetPlatformOverride = TargetPlatform.ohos;
    final settings = SettingsStore()
      ..aiBaseUrl = 'http://127.0.0.1:${server.port}'
      ..aiModel = 'acceptance-local-only';
    try {
      await HttpOverrides.runZoned(() async {
        expect(qfliStudioProfile.allowCustomAiEndpoint, isFalse);
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: AiPanel(
                projectPath: Directory.systemTemp.path,
                projectName: 'Acceptance',
                language: 'dart',
                settings: settings,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('AI 助手 · 官方转发'), findsOneWidget);
        expect(find.byTooltip('AI 接口设置'), findsNothing);
        await tester.enterText(
          find.byType(TextField),
          'Acceptance local probe',
        );
        await tester.tap(find.byTooltip('发送'));
        // Drive real I/O while preserving the production widget and send path.
        for (var attempt = 0; attempt < 150; attempt++) {
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 20)),
          );
          await tester.pump(const Duration(milliseconds: 20));
          if (find.text('Acceptance loopback reply').evaluate().isNotEmpty) {
            break;
          }
        }
        expect(requests, hasLength(1));
        expect(requests.single, {
          'method': 'POST',
          'path': '/v1/chat/completions',
          'model': 'acceptance-local-only',
        });
        expect(find.text('Acceptance loopback reply'), findsOneWidget);
        expect(find.text('内容由AI生成'), findsOneWidget);
        debugPrint(
          'ACCEPTANCE DEFECT_REPRODUCED allowCustomAiEndpoint=false '
          'platform=ohos label=official-forwarding '
          'received=${jsonEncode(requests)} replyLabel=内容由AI生成',
        );
      }, createHttpClient: (_) => client);
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      // Close the owned real client before widget-test timer verification.
      client.close(force: true);
      await tester.pump(const Duration(seconds: 1));
      settings.dispose();
      StudioProfile.current = previousProfile;
      debugDefaultTargetPlatformOverride = previousPlatform;
    }
  });
}
