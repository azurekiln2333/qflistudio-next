import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'pages/home_page.dart';
import 'services/studio_profile.dart';
import 'splash_screen.dart';
import 'store/auth_store.dart';
import 'store/project_store.dart';
import 'store/settings_store.dart';
import 'theme/app_theme.dart';

class QfliApp extends StatefulWidget {
  const QfliApp({
    super.key,
    required this.store,
    required this.auth,
    this.settings,
    this.ready,
  });

  final ProjectStore store;
  final AuthStore auth;
  final SettingsStore? settings;
  final ValueListenable<bool>? ready;

  static const Color brandSeed = AppTheme.brandSeed;

  @override
  State<QfliApp> createState() => _QfliAppState();
}

class _QfliAppState extends State<QfliApp> {
  late final SettingsStore _fallbackSettings = SettingsStore();

  @override
  void dispose() {
    _fallbackSettings.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settings = widget.settings ?? _fallbackSettings;
    return ListenableBuilder(
      listenable: Listenable.merge([settings, widget.ready]),
      builder: (context, _) => MaterialApp(
        title: StudioProfile.current?.appTitle ?? 'QFLIStudio+',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        darkTheme: AppTheme.dark,
        themeMode: settings.themeModeValue,
        home: widget.ready?.value == false
            ? const SplashScreen()
            : HomePage(
                store: widget.store,
                auth: widget.auth,
                settings: settings,
              ),
      ),
    );
  }
}
