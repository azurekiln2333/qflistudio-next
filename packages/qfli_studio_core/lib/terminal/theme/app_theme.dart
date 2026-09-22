import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../shell/ansi.dart';

/// Material 3 theming for Terminax.
///
/// The app chrome follows the seeded MD3 palette; the terminal canvas keeps its
/// own neutral palette so command output stays readable whatever seed is used.
class AppTheme {
  const AppTheme._();

  /// Seeds offered in the appearance sheet.
  static const List<({String label, Color color})> seeds =
      <({String label, Color color})>[
    (label: '终端绿', color: Color(0xFF0F9D58)),
    (label: '靛蓝', color: Color(0xFF3D5AFE)),
    (label: '青色', color: Color(0xFF00838F)),
    (label: '紫罗兰', color: Color(0xFF7C4DFF)),
    (label: '琥珀', color: Color(0xFFB26A00)),
    (label: '石墨', color: Color(0xFF4A5568)),
  ];

  static const List<String> _monoFallback = <String>[
    'JetBrains Mono',
    'Cascadia Mono',
    'Cascadia Code',
    'Consolas',
    'SF Mono',
    'Menlo',
    'Roboto Mono',
    'DejaVu Sans Mono',
    'Noto Sans Mono',
    // Consolas and friends have no CJK glyphs, so Chinese output needs a
    // fallback or it renders as tofu.
    'Microsoft YaHei',
    'PingFang SC',
    'Noto Sans CJK SC',
    'monospace',
  ];

  /// Best-effort monospace family for the current platform.
  static String get _monoFamily {
    switch (defaultTargetPlatform) {
      case TargetPlatform.windows:
        return 'Consolas';
      case TargetPlatform.macOS:
      case TargetPlatform.iOS:
        return 'Menlo';
      default:
        // Android, Linux, Fuchsia, OpenHarmony and everything else.
        return 'monospace';
    }
  }

  /// Monospace text style used by the terminal canvas.
  static TextStyle mono(
    double fontSize, {
    Color? color,
    FontWeight? fontWeight,
    double height = 1.45,
  }) {
    return TextStyle(
      fontFamily: _monoFamily,
      fontFamilyFallback: _monoFallback,
      fontSize: fontSize,
      height: height,
      color: color,
      fontWeight: fontWeight,
    );
  }

  /// Terminal colours for the active brightness.
  static TerminalPalette palette(BuildContext context) =>
      TerminalPalette.of(Theme.of(context).brightness);

  static ThemeData light(Color seed) => _build(seed, Brightness.light);

  static ThemeData dark(Color seed) => _build(seed, Brightness.dark);

  static ThemeData _build(Color seed, Brightness brightness) {
    final scheme = ColorScheme.fromSeed(
      seedColor: seed,
      brightness: brightness,
    );
    final base = ThemeData(colorScheme: scheme, useMaterial3: true);

    return base.copyWith(
      scaffoldBackgroundColor: scheme.surface,
      appBarTheme: AppBarTheme(
        backgroundColor: scheme.surfaceContainer,
        foregroundColor: scheme.onSurface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: base.textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.w600,
          color: scheme.onSurface,
        ),
      ),
      dividerTheme: DividerThemeData(
        color: scheme.outlineVariant,
        thickness: 1,
        space: 1,
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          foregroundColor: scheme.onSurfaceVariant,
          highlightColor: scheme.primary.withValues(alpha: 0.10),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: scheme.inverseSurface,
        contentTextStyle: base.textTheme.bodyMedium?.copyWith(
          color: scheme.onInverseSurface,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: scheme.surfaceContainerLow,
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: scheme.surfaceContainerHigh,
        surfaceTintColor: Colors.transparent,
        elevation: 3,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: scheme.inverseSurface,
          borderRadius: BorderRadius.circular(8),
        ),
        textStyle: base.textTheme.labelMedium?.copyWith(
          color: scheme.onInverseSurface,
        ),
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: scheme.primary,
        thumbColor: scheme.primary,
        inactiveTrackColor: scheme.surfaceContainerHighest,
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? scheme.onPrimary
              : scheme.outline,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? scheme.primary
              : scheme.surfaceContainerHighest,
        ),
      ),
      scrollbarTheme: ScrollbarThemeData(
        thickness: const WidgetStatePropertyAll<double>(6),
        radius: const Radius.circular(3),
        thumbColor: WidgetStatePropertyAll<Color>(
          scheme.onSurfaceVariant.withValues(alpha: 0.4),
        ),
      ),
    );
  }
}
