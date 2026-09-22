import 'dart:async';

import 'package:flutter/material.dart';

import 'package:qfli_studio_core/app.dart';
import 'package:qfli_studio_core/services/project_templates.dart';
import 'package:qfli_studio_core/services/studio_profile.dart';
import 'package:qfli_studio_core/splash_screen.dart';
import 'package:qfli_studio_core/store/auth_store.dart';
import 'package:qfli_studio_core/store/project_store.dart';
import 'package:qfli_studio_core/store/settings_store.dart';

import 'go_runner.dart';

/// 本 App 的产品名。窗口标题、任务切换器和应用内顶栏都读它。
const String _appTitle = StudioProductCatalog.goShift;

/// Go 版档位：同一套内核 UI，收窄成只服务 Go。
///
/// 单独提出来是为了让测试能直接断言档位，而不必为了一个常量去跑 `main()`。
const StudioProfile goProfile = StudioProfile(
  id: 'go',
  appTitle: _appTitle,
  templates: [ProjectTemplate.empty, ProjectTemplate.go],
  isOffline: true,
  runner: GoProgramRunner(),
  productKey: StudioProductCatalog.goShiftKey,
  showHomeTabs: false,
  runtimeKind: 'embedded-go-runtime',
  runtimeStatus: 'unavailable',
  supportedFileExtensions: ['.go'],
  // main.go 排在默认入口表前面，保证本版一定先命中它。
  entryFileNames: ['main.go', 'src/main.go'],
);

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 在 runApp 之前定档。
  StudioProfile.current = goProfile;

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
