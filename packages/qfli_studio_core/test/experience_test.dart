import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:qfli_studio_core/app.dart';
import 'package:qfli_studio_core/models/project.dart';
import 'package:qfli_studio_core/pages/community/post_list_page.dart';
import 'package:qfli_studio_core/pages/profile_page.dart';
import 'package:qfli_studio_core/splash_screen.dart';
import 'package:qfli_studio_core/store/auth_store.dart';
import 'package:qfli_studio_core/store/project_store.dart';
import 'package:qfli_studio_core/store/settings_store.dart';

class _RefreshStore extends ProjectStore {
  int refreshes = 0;
  Completer<void>? completion;
  @override
  Future<void> refresh() async {
    refreshes++;
    await completion?.future;
  }
}

class _BrokenProjects extends ProjectStore {
  @override
  Future<void> load() async => throw const FileSystemException('test failure');
}

class _ReadyAuth extends AuthStore {
  @override
  Future<void> load() async {}
}

class _ReadySettings extends SettingsStore {
  final completion = Completer<void>();
  @override
  Future<void> load() => completion.future;
}

void main() {
  test('重复载入和刷新不产生重复记录，损坏注册表不清空现有列表', () async {
    final directory = await Directory.systemTemp.createTemp('qfli_refresh_');
    addTearDown(() => directory.delete(recursive: true));
    final registry = File(p.join(directory.path, 'projects.json'));
    final project = Project.create(name: 'demo', path: directory.path);
    await registry.writeAsString(
      jsonEncode({
        'projects': [project.toJson(), project.toJson()],
      }),
    );
    final store = ProjectStore(storageFile: registry);
    addTearDown(store.dispose);
    await store.load();
    await store.load();
    expect(store.projects, hasLength(1));
    project.name = 'renamed';
    await registry.writeAsString(
      jsonEncode({
        'projects': [project.toJson()],
      }),
    );
    await store.refresh();
    expect(store.projects.single.name, 'renamed');
    await store.setFavorite(store.projects.single, true);
    await store.refresh();
    expect(store.projects.single.favorite, isTrue);
    await registry.writeAsString('{broken');
    await expectLater(store.refresh(), throwsFormatException);
    expect(store.projects.single.name, 'renamed');
  });

  test('云端目录合并保留收藏，不重复追加已有项目', () async {
    final directory = await Directory.systemTemp.createTemp('qfli_cloud_list_');
    addTearDown(() => directory.delete(recursive: true));
    final store = ProjectStore(
      storageFile: File(p.join(directory.path, 'projects.json')),
    );
    addTearDown(store.dispose);
    await store.load();
    await store.addCloudProject(
      name: 'old',
      cloudId: '7',
      cachePath: directory.path,
    );
    await store.setFavorite(store.projects.single, true);
    final lastOpened = store.projects.single.lastOpenedAt;
    final incoming = Project.create(
      name: 'new',
      path: directory.path,
      cloudId: '7',
    );
    await store.mergeCloudProjects([incoming]);
    await store.mergeCloudProjects([incoming]);
    expect(store.projects, hasLength(1));
    expect(store.projects.single.name, 'new');
    expect(store.projects.single.favorite, isTrue);
    expect(store.projects.single.lastOpenedAt, lastOpened);
  });

  testWidgets('启动只等待本地加载，无固定延时；单项失败仍进入主页', (tester) async {
    final store = _BrokenProjects();
    final auth = _ReadyAuth();
    final settings = _ReadySettings();
    final ready = ValueNotifier(false);
    final loading = AppBootstrap.run(
      store: store,
      auth: auth,
      settings: settings,
      ready: ready,
    );
    await tester.pump();
    expect(ready.value, isFalse);
    settings.completion.complete();
    await tester.pump();
    // 不推进 fake clock，已完成的配置应立即放行。
    expect(ready.value, isTrue);
    await loading;
    store.dispose();
    auth.dispose();
    settings.dispose();
    ready.dispose();
  });

  testWidgets('首屏不创建社区/个人页，外观选择立即影响全局 MD3', (tester) async {
    final store = ProjectStore();
    final auth = AuthStore();
    final settings = SettingsStore();
    await tester.pumpWidget(
      QfliApp(store: store, auth: auth, settings: settings),
    );
    await tester.pumpAndSettle();
    expect(find.byType(PostListPage, skipOffstage: false), findsNothing);
    expect(find.byType(ProfileTab, skipOffstage: false), findsNothing);
    await settings.setThemeMode('dark');
    await tester.pumpAndSettle();
    var context = tester.element(find.byType(NavigationBar));
    expect(Theme.of(context).brightness, Brightness.dark);
    expect(Theme.of(context).useMaterial3, isTrue);
    await settings.setThemeMode('light');
    await tester.pumpAndSettle();
    context = tester.element(find.byType(NavigationBar));
    expect(Theme.of(context).brightness, Brightness.light);
    await tester.pumpWidget(const SizedBox());
    store.dispose();
    auth.dispose();
    settings.dispose();
  });

  testWidgets('空项目列表也能拉出原生刷新球并执行刷新', (tester) async {
    final store = _RefreshStore()..completion = Completer<void>();
    final auth = AuthStore();
    await tester.pumpWidget(QfliApp(store: store, auth: auth));
    await tester.pumpAndSettle();
    await tester.drag(
      find.byType(CustomScrollView).first,
      const Offset(0, 360),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(store.refreshes, 1);
    expect(find.byType(RefreshProgressIndicator), findsOneWidget);
    store.completion!.complete();
    await tester.pumpAndSettle();
    expect(find.byType(RefreshProgressIndicator), findsNothing);
    await tester.pumpWidget(const SizedBox());
    store.dispose();
    auth.dispose();
  });

  testWidgets('窄屏大字体的个人页与登录页没有服务器自定义入口', (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 1.6;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    final store = ProjectStore();
    final auth = AuthStore();
    await tester.pumpWidget(QfliApp(store: store, auth: auth));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.person_outline));
    await tester.pumpAndSettle();
    expect(find.text('未登录'), findsOneWidget);
    expect(find.text('创作与成长'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('登录 / 注册'));
    await tester.pumpAndSettle();
    expect(find.byType(TextField), findsNWidgets(2));
    expect(find.text('服务器地址'), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    store.dispose();
    auth.dispose();
  });
}
