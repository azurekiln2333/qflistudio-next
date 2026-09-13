import 'dart:async';

import 'package:flutter/material.dart';

import 'store/auth_store.dart';
import 'store/project_store.dart';
import 'store/settings_store.dart';

/// 启动页：Flutter 原生组件，纯白/纯黑背景自适应，
/// 应用图标居中，进度条压在屏幕底部。
/// 背景色与原生启动遮罩（startWindowBackground / launch_background）
/// 保持一致：亮色纯白、深色纯黑，遮罩消失时零跳变。
class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: isDark ? Colors.black : Colors.white,
      body: Column(
        children: [
          Expanded(
            child: Center(
              child: Image.asset(
                'assets/app_icon.png',
                width: 96,
                height: 96,
                filterQuality: FilterQuality.high,
              ),
            ),
          ),
          // 进度条压底：不定色（组件自适应明暗），细条全宽。
          const LinearProgressIndicator(minHeight: 3),
          // 深色模式下底部安全区不影响进度条贴底观感。
          SizedBox(
            height: MediaQuery.paddingOf(context).bottom,
            width: double.infinity,
            child: ColoredBox(
              color: isDark ? Colors.black : Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}

/// 引导加载器：main 里 runApp 后台加载三库，完成（且满最短展示时长）后
/// 置 ready=true，QfliApp 随之把启动页换成主页。
class AppBootstrap {
  AppBootstrap._();

  static const Duration minSplashDuration = Duration(milliseconds: 900);

  static Future<void> run({
    required ProjectStore store,
    required AuthStore auth,
    required SettingsStore settings,
    required ValueNotifier<bool> ready,
  }) async {
    final startedAt = DateTime.now();
    await Future.wait([
      store.load(),
      auth.load(),
      settings.load(),
    ]);
    final elapsed = DateTime.now().difference(startedAt);
    if (elapsed < minSplashDuration) {
      await Future.delayed(minSplashDuration - elapsed);
    }
    ready.value = true;
  }
}
