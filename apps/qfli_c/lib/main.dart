import 'dart:async';

import 'package:flutter/material.dart';

import 'package:qfli_studio_core/app.dart';
import 'package:qfli_studio_core/services/project_templates.dart';
import 'package:qfli_studio_core/services/studio_profile.dart';
import 'package:qfli_studio_core/splash_screen.dart';
import 'package:qfli_studio_core/store/auth_store.dart';
import 'package:qfli_studio_core/store/project_store.dart';
import 'package:qfli_studio_core/store/settings_store.dart';

import 'c_runner.dart';

/// 本 App 的产品名。窗口标题、任务切换器和应用内顶栏都读它。
const String _appTitle = StudioProductCatalog.forge;

/// C 版档位：同一套内核 UI，收窄成只服务 C 语言。
///
/// 新建项目只出现 C 模板，运行按钮交给应用内的 C 解释器。
/// 单独提出来是为了让测试能直接断言档位，而不必为了一个常量去跑 `main()`。
const StudioProfile cProfile = StudioProfile(
  id: 'c',
  appTitle: _appTitle,
  templates: [ProjectTemplate.empty, ProjectTemplate.c],
  runner: CProgramRunner(),
  isOffline: true,
  showEditorTabs: false,
  // `main.c` 排在默认入口表前面，保证 C 版一定先命中它。
  entryFileNames: ['main.c', 'src/main.c'],
);

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 在 runApp 之前定档。
  StudioProfile.current = cProfile;

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
