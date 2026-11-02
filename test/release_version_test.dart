import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qfli_studio_core/config/client_platform.dart';
import 'package:qfli_studio_core/services/studio_profile.dart';
import 'package:qflistudio/main.dart' show qfliStudioProfile;

void main() {
  test('release manifests and the HarmonyOS HTTP version agree', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    final version = RegExp(
      r'^version:\s*(\d+\.\d+\.\d+)\+(\d+)\s*$',
      multiLine: true,
    ).firstMatch(pubspec);
    expect(
      version,
      isNotNull,
      reason: 'Use versionName+versionCode in pubspec.',
    );
    final versionName = version!.group(1)!;
    final versionCode = int.parse(version.group(2)!);
    final app =
        (jsonDecode(File('ohos/AppScope/app.json5').readAsStringSync())
                as Map<String, dynamic>)['app']
            as Map<String, dynamic>;

    expect(app['versionName'], versionName);
    expect(app['versionCode'], versionCode);
    expect(versionCode, greaterThan(0));
    expect(qfliStudioProfile.clientVersion, versionName);

    final previousProfile = StudioProfile.current;
    final previousPlatform = debugDefaultTargetPlatformOverride;
    addTearDown(() {
      StudioProfile.current = previousProfile;
      debugDefaultTargetPlatformOverride = previousPlatform;
    });
    StudioProfile.current = qfliStudioProfile;
    debugDefaultTargetPlatformOverride = TargetPlatform.ohos;
    expect(ClientPlatform.header, 'harmonyos-app/$versionName');
  });
}
