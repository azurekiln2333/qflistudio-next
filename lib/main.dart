import 'dart:async';

import 'package:flutter/material.dart';

import 'package:qfli_studio_core/app.dart';
import 'package:qfli_studio_core/services/project_templates.dart';
import 'package:qfli_studio_core/services/studio_profile.dart';
import 'package:qfli_studio_core/splash_screen.dart';
import 'package:qfli_studio_core/store/auth_store.dart';
import 'package:qfli_studio_core/store/project_store.dart';
import 'package:qfli_studio_core/store/settings_store.dart';

final StudioProfile qfliStudioProfile = StudioProfile(
  id: StudioProductCatalog.qfliStudioKey,
  appTitle: StudioProductCatalog.qfliStudio,
  templates: ProjectTemplate.values,
  isOffline: false,
  productKey: StudioProductCatalog.qfliStudioKey,
  showHomeTabs: true,
  runtimeKind: 'multi-runtime',
  runtimeStatus: 'unavailable',
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
  WidgetsFlutterBinding.ensureInitialized();
  StudioProfile.current = qfliStudioProfile;
  final store = ProjectStore();
  final auth = AuthStore();
  final settings = SettingsStore();
  final ready = ValueNotifier<bool>(false);
  // 先 runApp 品牌启动页（与原生遮罩同色，无白屏），数据后台并行加载。
  runApp(QfliApp(store: store, auth: auth, settings: settings, ready: ready));
  // 首帧提交后再做磁盘/插件初始化，避免与首帧构建争用主 isolate。
  WidgetsBinding.instance.addPostFrameCallback((_) {
    unawaited(
      AppBootstrap.run(
        store: store,
        auth: auth,
        settings: settings,
        ready: ready,
      ),
    );
  });
}
