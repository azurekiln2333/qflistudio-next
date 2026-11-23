import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:qfli_studio_core/app.dart';
import 'package:qfli_studio_core/chat/composer_draft.dart';
import 'package:qfli_studio_core/config/ohos_platform.dart';
import 'package:qfli_studio_core/editor/retained_editor_host.dart';
import 'package:qfli_studio_core/harness/harness_session_target.dart';
import 'package:qfli_studio_core/harness/hub/default_harness_hosts.dart';
import 'package:qfli_studio_core/harness/studio/studio_agent_host.dart';
import 'package:qfli_studio_core/services/app_paths.dart';
import 'package:qfli_studio_core/services/project_templates.dart';
import 'package:qfli_studio_core/interop/interop_runner.dart';
import 'package:qfli_studio_core/interop/interop_background_transport.dart';
import 'package:qfli_studio_core/services/studio_profile.dart';
import 'package:qfli_studio_core/share/share_inbox.dart';
import 'package:qfli_studio_core/share/share_inbox_store.dart';
import 'package:qfli_studio_core/share/share_intake.dart';
import 'package:qfli_studio_core/share/share_intake_host.dart';
import 'package:qfli_studio_core/shell/agent_runtime_factory.dart';
import 'package:qfli_studio_core/splash_screen.dart';
import 'package:qfli_studio_core/sync/placeholder_project.dart';
import 'package:qfli_studio_core/store/auth_store.dart';
import 'package:qfli_studio_core/store/project_store.dart';
import 'package:qfli_studio_core/store/settings_store.dart';

import 'content/studio_content_repository.dart';
import 'studio_tools_tab.dart';

final StudioProfile qfliStudioProfile = StudioProfile(
  id: StudioProductCatalog.qfliStudioKey,
  appTitle: StudioProductCatalog.qfliStudio,
  clientVersion: '5.0.11',
  templates: ProjectTemplate.values,
  isOffline: false,
  productKey: StudioProductCatalog.qfliStudioKey,
  showHomeTabs: true,
  runtimeKind: 'multi-runtime',
  runtimeStatus: 'unavailable',
  // 主 App 是联动发起方：项目入口属于哪门语言，就交给对应的 qfli_* 子 App
  // 用它的本地工具链编译运行。
  interopRunner: const InteropRunner(),
  backgroundInteropRunner: const InteropRunner(
    transport: MethodChannelBackgroundInteropTransport(),
  ),
  // 主 App 的本地教程/示例读取 assets/content/ 下由
  // tool/generate_studio_content.dart 组合的各产品权威课程。
  contentRepositoryFactory: () => StudioContentRepository(),
  // 主 App 的功能页在共享内核的默认内容上增加一个「远程电脑」入口。
  // 离线语言产品不设置这个构建器，因此看不到该在线入口。
  toolsTabBuilder: buildStudioToolsTab,
  // 主 App 有配对电脑，才谈得上从电脑拉项目。离线语言产品不设这个开关，
  // 因此保留默认的关闭值，编辑器里不会出现同步入口。
  deviceSyncEnabled: true,
  supportedFileExtensions: [
    '.c',
    '.h',
    '.cpp',
    '.cc',
    '.cxx',
    '.hpp',
    '.hh',
    '.lua',
    '.js',
    '.ts',
    '.sh',
    '.rs',
    '.go',
    '.java',
    '.html',
    '.css',
    '.py',
    '.dart',
    '.sql',
    '.json',
    '.md',
  ],
);

Future<void> main() async {
  final binding = WidgetsFlutterBinding.ensureInitialized();
  final nativeStartup = isOhosPlatform;
  if (nativeStartup) binding.deferFirstFrame();
  StudioProfile.current = qfliStudioProfile;
  final store = ProjectStore();
  final auth = AuthStore();
  final settings = SettingsStore();
  // 工具页的 Agents 卡片需要账号与设置才能打开编辑器，签名的限制见
  // studio_tools_tab.dart 里的说明。
  studioAppServices = (auth: auth, settings: settings);
  // 四类 harness 主机在启动时注册一次：编辑器页只负责建 hub，
  // 具体装哪些主机由 core 的集成装配文件决定。
  registerDefaultHarnessHosts();
  final ready = ValueNotifier<bool>(false);
  final navigatorKey = GlobalKey<NavigatorState>();
  runApp(
    QfliApp(
      navigatorKey: navigatorKey,
      store: store,
      auth: auth,
      settings: settings,
      ready: ready,
    ),
  );

  Future<void> startShareInbox() async {
    final base = await AppPaths.storageDirectory();
    if (base == null) return;
    final inbox = PlatformShareInbox(
      store: ShareInboxStore(root: Directory('$base/shared_inbox')),
    );
    // 会话列表是本地文件，读它不会碰网络。
    final runtime = await studioAgentRuntime(
      auth: auth,
      store: store,
      settings: settings,
    );
    void showSnack(String message) {
      final context = navigatorKey.currentContext;
      if (context == null) return;
      ScaffoldMessenger.maybeOf(
        context,
      )?.showSnackBar(SnackBar(content: Text(message)));
    }

    final host = ShareIntakeHost(
      inbox: inbox,
      navigatorKey: navigatorKey,
      projects: () => store.projects,
      sessionsOf: (projectId) => runtime.sessions.sessionsOf(projectId),
      ready: ready,
      onCopy: (batch, project, subdirectory) async {
        final result = await copyBatchIntoProject(
          batch: batch,
          project: project,
          subdirectory: subdirectory,
        );
        if (result.relativePaths.isNotEmpty) {
          showSnack('${result.relativePaths.length} 个文件已放进 ${project.name}');
        }
        return result;
      },
      onAttach: (batch, project, sessionId) async {
        final result = await copyBatchIntoProject(
          batch: batch,
          project: project,
        );
        final id = sessionId ?? (await runtime.sessions.create(project.id)).id;
        final context = navigatorKey.currentContext;
        if (context == null || !context.mounted) {
          throw StateError('界面尚未就绪');
        }
        await openEditorPage(
          context,
          project: project,
          auth: auth,
          store: store,
          settings: settings,
          revealAgentPane: true,
          harnessSession: HarnessSessionTarget(
            hostId: kStudioHostId,
            sessionId: id,
          ),
          composerPrefill: ComposerDraft(
            attachments: result.relativePaths,
            autoSend: false,
          ),
        );
      },
      onError: showSnack,
    );
    await host.start();
  }

  const platformChannel = MethodChannel('qflistudio/platform');
  Future<void> reportProgress(double progress) async {
    try {
      await platformChannel.invokeMethod<void>('startupProgress', {
        'progress': progress,
      });
    } on PlatformException catch (error) {
      debugPrint('Startup progress unavailable: ${error.code}');
    } on MissingPluginException {
      // Native startup progress is optional for other entry shells.
    }
  }

  Future<void> completeStartup() async {
    try {
      final minimumDisplay = nativeStartup
          ? Future<void>.delayed(const Duration(milliseconds: 1100))
          : Future<void>.value();
      if (nativeStartup) {
        await Future<void>.delayed(const Duration(milliseconds: 160));
      }
      await AppBootstrap.run(
        store: store,
        auth: auth,
        settings: settings,
        ready: ready,
        onProgress: nativeStartup
            ? (progress) => unawaited(reportProgress(progress))
            : null,
      );
      // 分享收件箱不拦首帧：启动完再装通道，冷启动批次由 takePending 取。
      // 失败只记日志：收不到分享不能连带启动失败。
      unawaited(
        startShareInbox().catchError((Object error) {
          debugPrint('分享收件箱装配失败：$error');
        }),
      );
      // 占位项目扫一遍：会话没了、又没拉过文件的项目只占手机空间。
      // 磁盘要等运行时装配完才能问，所以不拦首帧。
      unawaited(
        PlaceholderProjects.sweepPlaceholders(
          store: store,
          sessions: (await studioAgentRuntime(
            auth: auth,
            store: store,
            settings: settings,
          )).sessions,
        ).catchError((Object error) {
          debugPrint('占位项目清理失败：$error');
          return 0;
        }),
      );
      await Future.wait([
        minimumDisplay,
        if (nativeStartup)
          Future<void>.delayed(const Duration(milliseconds: 320)),
      ]);
      // Submit the home page only after its build and layout have finished.
      if (nativeStartup) await binding.endOfFrame;
    } finally {
      if (nativeStartup) binding.allowFirstFrame();
    }
  }

  binding.addPostFrameCallback((_) {
    unawaited(completeStartup());
  });
}
