import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qfli_studio_core/services/picker_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('picker channel keeps HarmonyOS URI opaque and reads bytes by channel', () async {
    PickerService.forcePlatformChannel = true;
    addTearDown(() => PickerService.forcePlatformChannel = false);
    const channel = MethodChannel('qflistudio/platform');
    final calls = <MethodCall>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call);
          if (call.method == 'pickDocument') {
            return {'uri': 'file://opaque/document.json', 'name': 'document.json'};
          }
          if (call.method == 'readUri') return Uint8List.fromList([1, 2, 3]);
          return null;
        });
    addTearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null),
    );

    final picked = await PickerService.pickDocument();
    expect(picked?.uri, 'file://opaque/document.json');
    expect(picked?.path, isNull);
    expect(await PickerService.readUri(picked!.uri!), [1, 2, 3]);
    expect(calls.map((call) => call.method), ['pickDocument', 'readUri']);
  });
}
