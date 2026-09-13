import 'dart:async';

import 'package:flutter/material.dart';

import 'app.dart';
import 'splash_screen.dart';
import 'store/auth_store.dart';
import 'store/project_store.dart';
import 'store/settings_store.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final store = ProjectStore();
  final auth = AuthStore();
  final settings = SettingsStore();
  final ready = ValueNotifier<bool>(false);
  // 先 runApp 品牌启动页（与原生遮罩同色，无白屏），数据后台并行加载。
  runApp(QfliApp(store: store, auth: auth, settings: settings, ready: ready));
  unawaited(AppBootstrap.run(
    store: store,
    auth: auth,
    settings: settings,
    ready: ready,
  ));
}
