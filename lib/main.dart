import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:qfli_studio_core/app.dart';
import 'package:qfli_studio_core/services/project_templates.dart';
import 'package:qfli_studio_core/interop/interop_runner.dart';
import 'package:qfli_studio_core/services/studio_profile.dart';
import 'package:qfli_studio_core/splash_screen.dart';
import 'package:qfli_studio_core/store/auth_store.dart';
import 'package:qfli_studio_core/store/project_store.dart';
import 'package:qfli_studio_core/store/settings_store.dart';

import 'content/studio_content_repository.dart';

final StudioProfile qfliStudioProfile = StudioProfile(
  id: StudioProductCatalog.qfliStudioKey,
  appTitle: StudioProductCatalog.qfliStudio,
  clientVersion: '5.0.1',
  templates: ProjectTemplate.values,
  isOffline: false,
  productKey: StudioProductCatalog.qfliStudioKey,
  showHomeTabs: true,
  runtimeKind: 'multi-runtime',
  runtimeStatus: 'unavailable',
  // 主 App 是联动发起方：项目入口属于哪门语言，就交给对应的 qfli_* 子 App
  // 用它的本地工具链编译运行。
  interopRunner: const InteropRunner(),
  // 主 App 的本地教程/示例读取 assets/content/ 下由
  // tool/generate_studio_content.dart 组合的各产品权威课程。
  contentRepositoryFactory: () => StudioContentRepository(),
  supportedFileExtensions: [
    '.c',
    '.h',
    '.cpp',
    '.cc',
    '.cxx',
    '.hpp',
    '.hh',
    '.lua',
    '.js',
    '.ts',
    '.sh',
    '.rs',
    '.go',
    '.java',
    '.html',
    '.css',
    '.py',
    '.dart',
    '.sql',
    '.json',
    '.md',
  ],
);

Future<void> main() async {
  final binding = WidgetsFlutterBinding.ensureInitialized();
  final nativeStartup = !kIsWeb && defaultTargetPlatform == TargetPlatform.ohos;
  if (nativeStartup) binding.deferFirstFrame();
  StudioProfile.current = qfliStudioProfile;
  final store = ProjectStore();
  final auth = AuthStore();
  final settings = SettingsStore();
  final ready = ValueNotifier<bool>(false);
  runApp(QfliApp(store: store, auth: auth, settings: settings, ready: ready));

  const platformChannel = MethodChannel('qflistudio/platform');
  Future<void> reportProgress(double progress) async {
    try {
      await platformChannel.invokeMethod<void>('startupProgress', {
        'progress': progress,
      });
    } on PlatformException catch (error) {
      debugPrint('Startup progress unavailable: ${error.code}');
    } on MissingPluginException {
      // Native startup progress is optional for other entry shells.
    }
  }

  Future<void> completeStartup() async {
    try {
      final minimumDisplay = nativeStartup
          ? Future<void>.delayed(const Duration(milliseconds: 1100))
          : Future<void>.value();
      if (nativeStartup) {
        await Future<void>.delayed(const Duration(milliseconds: 160));
      }
      await AppBootstrap.run(
        store: store,
        auth: auth,
        settings: settings,
        ready: ready,
        onProgress: nativeStartup
            ? (progress) => unawaited(reportProgress(progress))
            : null,
      );
      await Future.wait([
        minimumDisplay,
        if (nativeStartup)
          Future<void>.delayed(const Duration(milliseconds: 320)),
      ]);
      // Submit the home page only after its build and layout have finished.
      if (nativeStartup) await binding.endOfFrame;
    } finally {
      if (nativeStartup) binding.allowFirstFrame();
    }
  }

  binding.addPostFrameCallback((_) {
    unawaited(completeStartup());
  });
}
