import 'dart:async';

import 'package:cloudterminal_windows/engine/sidecar_client.dart';
import 'package:cloudterminal_windows/screens/settings_page.dart';
import 'package:cloudterminal_windows/state/assistant_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _Sidecar extends SidecarClient {
  _Sidecar() : super(executable: 'unused', arguments: const <String>[]);

  final frames = StreamController<Map<String, dynamic>>.broadcast(sync: true);
  final sent = <Map<String, dynamic>>[];

  @override
  Stream<Map<String, dynamic>> get messages => frames.stream;

  @override
  Future<void> start() async {}

  @override
  void send(String type, [Map<String, dynamic> fields = const {}]) {
    sent.add(<String, dynamic>{'type': type, ...fields});
  }

  @override
  Future<void> dispose() => frames.close();
}

void main() {
  testWidgets('typing enables save and mode notices update immediately', (
    tester,
  ) async {
    final sidecar = _Sidecar();
    final controller = AssistantController(sidecar: sidecar);
    addTearDown(controller.dispose);
    await controller.start();
    sidecar.frames.add(<String, dynamic>{
      'type': 'snapshot',
      'relayOnline': true,
      'connectionMode': 'local',
      'relayUrl': 'ws://192.168.1.5:8787/ws',
    });
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SettingsPage(
            controller: controller,
            onSeedChanged: (_) {},
            onModeChanged: (_) {},
          ),
        ),
      ),
    );
    expect(find.text('当前模式：局域网'), findsOneWidget);
    final save = find.widgetWithText(FilledButton, '保存远端中继');
    expect(tester.widget<FilledButton>(save).onPressed, isNull);
    await tester.enterText(
      find.byType(TextField),
      'wss://relay.example.com/ws',
    );
    await tester.pump();
    expect(tester.widget<FilledButton>(save).onPressed, isNotNull);
    await tester.tap(save);
    expect(sidecar.sent.last, <String, dynamic>{
      'type': 'set_relay',
      'url': 'wss://relay.example.com/ws',
      'key': null,
      'clear': false,
    });
    const notice = '远端中继已保存。请关闭并重新打开助手。';
    sidecar.frames.add(<String, dynamic>{'type': 'notice', 'message': notice});
    await tester.pump();
    expect(find.text(notice), findsOneWidget);
    await tester.tap(find.text('改用局域网'));
    await tester.pump();
    expect(sidecar.sent.last['clear'], isTrue);
    expect(find.text(notice), findsNothing);
    sidecar.frames.add(<String, dynamic>{'type': 'error', 'message': '中继地址无效'});
    await tester.pump();
    expect(find.text('中继地址无效'), findsOneWidget);
  });
}
