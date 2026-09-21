import 'dart:async';

import 'package:flutter/material.dart';

import 'store/auth_store.dart';
import 'store/project_store.dart';
import 'store/settings_store.dart';

/// 与原生启动窗口同色的轻量首帧，不等待网络或人为延时。
class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final background = Theme.of(context).colorScheme.surface;
    return Scaffold(
      backgroundColor: background,
      body: Column(
        children: [
          Expanded(
            child: Center(
              child: Image.asset(
                'assets/app_icon.png',
                width: 96,
                height: 96,
                cacheWidth: (96 * MediaQuery.devicePixelRatioOf(context))
                    .round(),
              ),
            ),
          ),
          // 进度条压底：不定色（组件自适应明暗），细条全宽。
          const LinearProgressIndicator(minHeight: 3),
          // 深色模式下底部安全区不影响进度条贴底观感。
          SizedBox(
            height: MediaQuery.paddingOf(context).bottom,
            width: double.infinity,
            child: ColoredBox(color: background),
          ),
        ],
      ),
    );
  }
}

/// 三份本地数据并行加载。单项失败不阻止进入主页。
class AppBootstrap {
  AppBootstrap._();

  static Future<void> run({
    required ProjectStore store,
    required AuthStore auth,
    required SettingsStore settings,
    required ValueNotifier<bool> ready,
  }) async {
    Future<void> loadSafely(Future<void> Function() load) async {
      try {
        await load();
      } catch (error, stack) {
        debugPrint('本地配置加载失败：$error\n$stack');
      }
    }

    await Future.wait([
      loadSafely(store.load),
      loadSafely(auth.load),
      loadSafely(settings.load),
    ]);
    ready.value = true;
  }
}
