import 'package:flutter/material.dart';

import 'app.dart';
import 'store/auth_store.dart';
import 'store/project_store.dart';
import 'store/settings_store.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final store = ProjectStore();
  await store.load();
  final auth = AuthStore();
  await auth.load();
  final settings = SettingsStore();
  await settings.load();
  runApp(QfliApp(store: store, auth: auth, settings: settings));
}
