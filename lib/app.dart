import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'store/auth_store.dart';
import 'store/project_store.dart';
import 'store/settings_store.dart';
import 'pages/home_page.dart';
import 'splash_screen.dart';

class QfliApp extends StatelessWidget {
  const QfliApp({
    super.key,
    required this.store,
    required this.auth,
    this.settings,
    this.ready,
  });

  final ProjectStore store;
  final AuthStore auth;

  /// 应用设置；未传入时用未加载的默认值（测试场景）。
  final SettingsStore? settings;

  /// 启动完成信号：false 时显示品牌启动页（数据后台加载）。
  /// 默认 null = 立即就绪（测试/预览场景直接进主页）。
  final ValueListenable<bool>? ready;

  /// 品牌色：basic_blue #2196F3、basic_deep_blue #1976D2。
  ///
  /// fromSeed 生成的是 MD3 色调调色板：表面带灰蓝蒙色、亮色模式 primary
  /// 落在深蓝档、tertiary 会被色相旋转成别的色系，观感偏离品牌基础色。
  /// 因此在种子调色板上整体覆盖：交互色统一 #2196F3，深蓝作浅色容器上的
  /// 前景，表面用纯净中性色阶；error/inverse 等未覆盖角色沿用种子结果。
  static const Color brandSeed = Color(0xFF2196F3);
  static const Color _deepBlue = Color(0xFF1976D2); // basic_deep_blue
  static const Color _blueContainer = Color(0xFFE3F2FD); // Blue 50

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: ready ?? ValueNotifier<bool>(true),
      builder: (context, _) {
        final isReady = ready?.value ?? true;
        return MaterialApp(
          title: 'QFLIStudio+',
          debugShowCheckedModeBanner: false,
          theme: _buildTheme(Brightness.light),
          darkTheme: _buildTheme(Brightness.dark),
          themeMode: ThemeMode.system,
          home: isReady
              ? HomePage(
                  store: store,
                  auth: auth,
                  settings: settings ?? SettingsStore(),
                )
              : const SplashScreen(),
        );
      },
    );
  }

  static ThemeData _buildTheme(Brightness brightness) {
    final base = ColorScheme.fromSeed(
      seedColor: brandSeed,
      brightness: brightness,
    );
    final isLight = brightness == Brightness.light;
    return ThemeData(
      useMaterial3: true,
      colorScheme: base.copyWith(
        primary: brandSeed,
        onPrimary: Colors.white,
        secondary: brandSeed,
        onSecondary: Colors.white,
        tertiary: brandSeed,
        onTertiary: Colors.white,
        primaryContainer: isLight ? _blueContainer : _deepBlue,
        onPrimaryContainer: isLight ? _deepBlue : _blueContainer,
        secondaryContainer: isLight ? _blueContainer : _deepBlue,
        onSecondaryContainer: isLight ? _deepBlue : _blueContainer,
        tertiaryContainer: isLight ? _blueContainer : _deepBlue,
        onTertiaryContainer: isLight ? _deepBlue : _blueContainer,
        surface: isLight ? Colors.white : const Color(0xFF121212),
        onSurface: isLight ? const Color(0xFF212121) : const Color(0xFFE6E6E6),
        surfaceContainerLowest: isLight
            ? Colors.white
            : const Color(0xFF0E0E0E),
        surfaceContainerLow: isLight
            ? const Color(0xFFFAFAFA)
            : const Color(0xFF161616),
        surfaceContainer: isLight
            ? const Color(0xFFF5F5F5)
            : const Color(0xFF1C1C1C),
        surfaceContainerHigh: isLight
            ? const Color(0xFFF0F0F0)
            : const Color(0xFF242424),
        surfaceContainerHighest: isLight
            ? const Color(0xFFEAEAEA)
            : const Color(0xFF2B2B2B),
        onSurfaceVariant: isLight
            ? const Color(0xFF616161)
            : const Color(0xFF9E9E9E),
        outline: isLight ? const Color(0xFFBDBDBD) : const Color(0xFF8A8A8A),
        outlineVariant: isLight
            ? const Color(0xFFE0E0E0)
            : const Color(0xFF3A3A3A),
        surfaceTint: Colors.transparent,
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: brandSeed,
        foregroundColor: Colors.white,
      ),
      // 全部输入框统一 outline 风格（未显式覆盖 border 的输入框都生效）。
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
    );
  }
}
