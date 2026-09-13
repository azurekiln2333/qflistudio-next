import 'dart:async';

import 'package:flutter/material.dart';

import 'store/auth_store.dart';
import 'store/project_store.dart';
import 'store/settings_store.dart';

/// 启动页：与原生启动遮罩同底色（亮 #F8F9FF / 暗 #111418），无缝衔接。
/// 数据由 main 的 bootstrap 并行加载，加载完且停留满最短时长后淡出。
class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    // 与 ohos startWindowBackground / Android splash_background 完全一致，
    // 遮罩消失时视觉零跳变。
    final background = brightness == Brightness.dark
        ? const Color(0xFF111418)
        : const Color(0xFFF8F9FF);
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: background,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 84,
              height: 84,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    scheme.primary,
                    scheme.tertiary.withValues(alpha: 0.85),
                  ],
                ),
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: scheme.primary.withValues(alpha: 0.25),
                    blurRadius: 24,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: const Icon(
                Icons.terminal,
                size: 44,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'QFLIStudio+',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                  ),
            ),
            const SizedBox(height: 28),
            SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(
                strokeWidth: 2.4,
                color: scheme.primary,
              ),
            ),
          ],
        ),
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
