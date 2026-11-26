# 接收分享文件：设计

覆盖父任务需求 1 与需求 2。PRD 见 `prd.md`，步骤见 `implement.md`。

## 0 审查裁定

计划审查（`../11-23-mobile-files-agents/reports/plan-review.md`）覆盖本文以下建议。

| 裁定 | 内容 | 本文落点 |
|---|---|---|
| R1 | 编辑器只留一个会话定位参数。用 Pi-C 的 `HarnessSessionTarget`：`openEditorPage` 的 `harnessSession`，`EditorPage` 的 `initialHarnessSession`。Pi-A 删除 `initialAgentSessionId`，只加 `composerPrefill` | 4.6、4.8、7、8 |
| R10 | `editor_page.dart` 与 `retained_editor_host.dart` 的会话参数归 Pi-C，Pi-A 只加 `composerPrefill`。`ios/Runner/Info.plist` 只追加键 | 4.4、4.6、7 |
| R11 | Pi-C 先单独提交接口。大脑把它合进 `mobile/pi-a` 后，本任务才动代码。集成顺序 C → B → A → D | 10、`implement.md` 第 0 步 |

## 1 边界

本次只做两件事：

- 三端注册为文件分享目标。
- 文件到达后让用户选一个去向：放进项目，或附到会话。

不做 iOS Share Extension，不做 iCloud 容器，不做纯文本分享。

改动落在两个仓库：

- `qflistudio`（app）：原生清单、原生入口、启动装配。
- `qfli_studio_core`（core）：收件箱服务、选择面板、编辑器预填。

## 2 代码现状

读到的既有事实：

- Android `MainActivity.kt` 只有一行继承 `FlutterActivity`。清单只有 LAUNCHER。
- `launchMode` 已是 `singleTop`，`taskAffinity` 已是空串。热启动走 `onNewIntent`。
- core 的 `QfliPickerPlugin` 注册在 `qflistudio/platform` 通道。它已有 `readUri` 与 `writeUri`，都走 SAFF 与 `ContentResolver`。
- iOS 用 UIScene。`AppDelegate` 实现 `didInitializeImplicitFlutterEngine`，`SceneDelegate` 为空。
- iOS `Runner.entitlements` 只有空的 `keychain-access-groups`。没有 App Group。
- iOS 工程只有 Runner 与 RunnerTests 两个 target。没有 appex。
- 鸿蒙 `EntryAbility` 已在 `configureFlutterEngine` 建 `qflistudio/platform` 通道。`InteropBridgeAbility` 已示范 `onNewWant`。
- 鸿蒙分享用 `@kit.ShareKit`。`systemShare.SharedData` 已用于发出 ZIP。
- core 已有 `PlatformShareInbox` 的落点空白。`lib/services/share_service.dart` 只负责发出。
- 会话模型 `AgentSessionMeta` 带 `projectId`。`AgentSessionStore.sessionsOf(projectId)` 取某项目会话。
- 附件契约在 `AttachmentFile`：项目内文件用相对路径，项目外文件用绝对路径并登记只读白名单。
- `ComposerDraft` 只有 `text` 与 `attachments`。`WorkbenchAgentPane` 收到非空 draft 就发送。
- `EditorPage` 有 `agentPaneRequest` 计数。没有「指定会话」参数。
- `openEditorPage` 已有 `revealAgentPane`。没有会话参数，也没有预填参数。

## 3 iOS 方案对比

| 维度 | 文档类型 + 打开 URL | Share Extension |
|---|---|---|
| 出现在「用其他应用打开」 | 是 | 是 |
| 出现在微信分享面板 | 部分类型可以 | 是 |
| 需要新 target | 否 | 是，要改 pbxproj |
| 需要 App Group | 否 | 是，交文件必须共用容器 |
| 依赖签名 | 否 | 是，扩展要自己的描述文件 |
| 未签名 CI 包 + 用户重签 | 可用 | 可能失效 |
| 改动面 | Info.plist 加 SceneDelegate | 新 target、新 plist、新代码 |

结论：v1 用文档类型加打开 URL。理由是 App Group 可能活不过重签，扩展交不出文件。

代价：微信内直接点「分享」时，部分文档类型可能不列 QFLI。用户在微信内走「用其他应用打开」仍可用。

## 4 契约

### 4.1 Dart 收件箱模型

落点：`qfli_studio_core/lib/share/share_inbox.dart`。

```dart
/// 一个已落盘的外部文件。
@immutable
class SharedIncomingFile {
  const SharedIncomingFile({
    required this.path,
    required this.name,
    required this.bytes,
    this.mimeType,
  });

  /// 原生已复制到收件箱的绝对路径。
  final String path;

  /// 系统给出的显示名，已去掉路径分隔符。
  final String name;

  final int bytes;

  final String? mimeType;
}

/// 一次分享进来的一批文件。
@immutable
class ShareInboxBatch {
  const ShareInboxBatch({
    required this.id,
    required this.files,
    required this.coldStart,
    required this.source,
  });

  final String id;
  final List<SharedIncomingFile> files;

  /// true 表示随进程启动到达。
  final bool coldStart;

  /// 'send' | 'sendMultiple' | 'view' | 'document' | 'sendData' | 'viewData'
  final String source;

  int get totalBytes => files.fold(0, (sum, file) => sum + file.bytes);
}

/// 收件箱通道。三端共用。
abstract class ShareInbox {
  Stream<ShareInboxBatch> get incoming;

  /// 注册通道，并取回冷启动批次。
  Future<void> start();

  /// 删除一个批次目录。
  Future<void> discard(String batchId);

  /// 清理超期与超额批次。
  Future<void> sweep();

  void dispose();
}
```

实现类名：`PlatformShareInbox`。构造参数：`MethodChannel channel`，默认 `MethodChannel('qflistudio/share_inbox')`。

### 4.2 平台通道消息

通道名：`qflistudio/share_inbox`。

原生发给 Dart：

```
method: 'incoming'
arguments: {
  'id': String,                // 批次 id，只允许 [A-Za-z0-9_-]
  'coldStart': bool,
  'source': String,
  'files': [
    {
      'path': String,          // 收件箱内绝对路径
      'name': String,
      'bytes': int,
      'mimeType': String?,     // 取不到时为 null
    }
  ]
}
```

Dart 发给原生：

```
method: 'takePending'   // 返回冷启动批次，无批次时返回 null
method: 'discard'       // arguments: {'id': String}
```

规则：

- 原生在没有监听者时缓存最新一批，只保留一批。
- Dart 调 `takePending` 拿走缓存，原生清空缓存。
- `discard` 只删 `shared_inbox/<id>` 目录。`id` 不在白名单时返回 `INVALID_ARGUMENT`。

### 4.3 Android 契约

清单落点：`qflistudio/android/app/src/main/AndroidManifest.xml`。

```xml
<intent-filter>
  <action android:name="android.intent.action.SEND" />
  <category android:name="android.intent.category.DEFAULT" />
  <data android:mimeType="*/*" />
</intent-filter>

<intent-filter>
  <action android:name="android.intent.action.SEND_MULTIPLE" />
  <category android:name="android.intent.category.DEFAULT" />
  <data android:mimeType="*/*" />
</intent-filter>

<intent-filter>
  <action android:name="android.intent.action.VIEW" />
  <category android:name="android.intent.category.DEFAULT" />
  <category android:name="android.intent.category.BROWSABLE" />
  <data android:scheme="content" />
  <data android:mimeType="*/*" />
</intent-filter>
```

不放 `http` 与 `https`。理由：避免抢浏览器链接。

代码落点：`MainActivity.kt` 与新建 `ShareInboxBridge.kt`。

```kotlin
class ShareInboxBridge(
    private val context: Context,
    private val channel: MethodChannel,
) {
    fun offer(intent: Intent?)           // 解析并复制，完成后 channel.invokeMethod("incoming", map)
    fun takePending(result: MethodChannel.Result)
    fun discard(id: String?, result: MethodChannel.Result)
}
```

`MainActivity` 改动：

```kotlin
override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
    super.configureFlutterEngine(flutterEngine)
    bridge = ShareInboxBridge(this, MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL))
    bridge.offer(intent)
}

override fun onNewIntent(intent: Intent) {
    super.onNewIntent(intent)
    setIntent(intent)
    bridge?.offer(intent)
}
```

解析规则：

- `ACTION_SEND` 取 `Intent.EXTRA_STREAM` 的单个 `Uri`。
- `ACTION_SEND_MULTIPLE` 取 `getParcelableArrayListExtra<Uri>(EXTRA_STREAM)`。
- `ACTION_VIEW` 取 `intent.data`。
- 只认 `content` 与 `file` 两种 scheme。其它 scheme 忽略。
- 复制走 `contentResolver.openInputStream(uri)`，按 1 MiB 分块写目标文件。
- 文件名取 `OpenableColumns.DISPLAY_NAME`。取不到时用 `uri.lastPathSegment`。
- 目标路径：`filesDir/shared_inbox/<batchId>/<index>-<safeName>`。

### 4.4 iOS 契约

清单落点：`qflistudio/ios/Runner/Info.plist`。

```xml
<key>CFBundleDocumentTypes</key>
<array>
  <dict>
    <key>CFBundleTypeName</key>
    <string>QFLI document</string>
    <key>LSHandlerRank</key>
    <string>Alternate</string>
    <key>LSItemContentTypes</key>
    <array>
      <string>public.data</string>
      <string>public.text</string>
      <string>public.image</string>
    </array>
  </dict>
</array>
```

代码落点：只改 `SceneDelegate.swift`。理由：新增 Swift 文件要改 pbxproj 的 target 成员。

```swift
class SceneDelegate: FlutterSceneDelegate {
  override func scene(
    _ scene: UIScene,
    willConnectTo session: UISceneSession,
    options connectionOptions: UIScene.ConnectionOptions
  ) { /* 冷启动：读 connectionOptions.urlContexts */ }

  override func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) {
    /* 热启动：读 URLContexts */
  }
}
```

复制规则：

- 对每个 url 调 `startAccessingSecurityScopedResource()`，结束后调 `stopAccessingSecurityScopedResource()`。
- 目标目录：`Application Support/shared_inbox/<batchId>/`。
- 用 `FileHandle` 按 1 MiB 分块复制。不调 `Data(contentsOf:)`。
- 通道名与消息形状同 4.2。`FlutterMethodChannel` 由 `FlutterSceneDelegate` 的引擎取 messenger。

### 4.5 鸿蒙契约

清单落点：`qflistudio/ohos/entry/src/main/module.json5`，加到 `EntryAbility` 的 `skills`。

```json5
{
  "actions": ["ohos.want.action.sendData"],
  "uris": [{ "scheme": "file", "utd": "general.file", "maxFileSupported": 16 }]
},
{
  "actions": ["ohos.want.action.viewData"],
  "uris": [{ "scheme": "file", "utd": "general.file", "maxFileSupported": 1 }]
}
```

代码落点：`EntryAbility.ets` 与新建 `share/ShareInbox.ets`。

```ts
export function offerShareWant(want: Want, filesDir: string): void
```

规则：

- 文件 uri 取 `want.parameters['ability.params.stream']`，类型为 `string[]`。`viewData` 另读 `want.uri`。
- 复制用 `fileIo.copyFile(src, dest)`，由系统分块搬运。
- 目标目录：`filesDir + '/shared_inbox/<batchId>/'`。
- 通道名与消息形状同 4.2。`MethodChannel` 从 `FlutterEngine` 取。
- `onCreate(want)` 与 `onNewWant(want)` 都调本函数。窗口未就绪时先缓存批次。

### 4.6 编辑器预填契约

会话定位参数归 Pi-C（裁定 R1）。Pi-A 不新增会话参数，只在两个文件里加 `composerPrefill`。

core 改动：

```dart
/// 从分享面板带进工作台的一批附件。
@immutable
class ComposerDraft {
  const ComposerDraft({
    this.text = '',
    this.attachments = const [],
    this.autoSend = true,
  });

  final bool autoSend;
}
```

`WorkbenchAgentPane._bootstrap` 改法：

```dart
if (!draft.isEmpty && !_draftSent) {
  _draftSent = true;
  _composer.attachAll(draft.attachments);
  if (draft.autoSend) await _send(draft.text, draft.attachments);
}
```

`EditorPage` 只加一个参数：

```dart
this.composerPrefill,   // ComposerDraft?
```

`openEditorPage` 只加一个参数：

```dart
Future<void> openEditorPage(
  BuildContext context, {
  // 既有参数不变
  // harnessSession 由 Pi-C 的接口提交提供
  ComposerDraft? composerPrefill,
})
```

行为：

- `composerPrefill` 交给 `WorkbenchAgentPane(draft: ...)`。
- 会话选中与面板切前台由 Pi-C 的 `harnessSession` 路径完成。
- Pi-A 不碰 `WorkbenchState.sessionId` 的初始化逻辑。

### 4.7 去处契约

落点：`qfli_studio_core/lib/share/share_intake.dart`。

```dart
/// 一个批次的目标项目与子目录。
Future<ShareIntakeResult> copyBatchIntoProject({
  required ShareInboxBatch batch,
  required Project project,
  required String subdirectory,   // 默认 'inbox'
});

class ShareIntakeResult {
  const ShareIntakeResult({required this.project, required this.relativePaths});
  final Project project;
  final List<String> relativePaths;
}
```

规则：

- 目标目录不存在时新建。
- 名字先过 `FileService.isValidEntryName`。不合规时替换非法字符为 `_`。
- 重名时依次试 `name (1).ext`、`name (2).ext`，到 99 次放弃并报错。
- 写入先建 `<name>.part`，写完 rename。同名目标存在时不 rename。
- 单个文件按 1 MiB 分块复制。
- 全部成功后调 `ShareInbox.discard(batch.id)`。

### 4.8 会话附件契约

「附到会话」复用 4.7 的复制，再打开编辑器。会话定位走 Pi-C 的 `harnessSession`（裁定 R1）：

```dart
await copyBatchIntoProject(
  batch: batch,
  project: project,
  subdirectory: 'inbox',
);
await openEditorPage(
  context,
  project: project,
  auth: auth,
  store: store,
  settings: settings,
  revealAgentPane: true,
  harnessSession: HarnessSessionTarget(
    hostId: studioHostId,
    sessionId: sessionId,
  ),
  composerPrefill: ComposerDraft(attachments: relativePaths, autoSend: false),
);
```

约束：

- `HarnessSessionTarget` 的构造签名以 Pi-C 的接口提交为准。本文只固定语义：Studio 主机加会话 id。
- 目标主机是 Studio 主机时，内置 Agent 面板打开这个会话。这条由 Pi-C 实现。
- 用户选「新建会话」时，先调 `runtime.sessions.create(project.id)` 拿 id，再走上面的调用。
- 理由：`read_file` 只收项目内相对路径。复制进 `inbox/` 后，附件走既有白名单外路径，不必新开机制。

## 5 数据流

### 5.1 冷启动

1. 系统拉起进程，`MainActivity.onCreate` 或 `EntryAbility.onCreate` 或 `scene(willConnectTo:)` 收下 intent 或 url。
2. 原生复制文件到收件箱，得到 `batchId` 与文件列表。
3. 原生把批次放进缓存。此时 Dart 还没注册通道。
4. Flutter 首帧后，`ShareIntakeHost.start()` 调 `takePending`。
5. 宿主等 `ready` 为真，再弹选择面板。

### 5.2 热启动

1. 进程已在运行。Android 走 `onNewIntent`，iOS 走 `openURLContexts`，鸿蒙走 `onNewWant`。
2. 原生复制文件到收件箱。
3. 原生直接 `invokeMethod('incoming', ...)`。
4. Dart 收到批次后，等当前路由空闲再弹面板。

### 5.3 用户在面板里的两条路

放进项目：

1. 面板列项目。用户点一个项目。
2. 面板列出该项目的子目录建议值：`inbox`、项目根、最近用过的目录。
3. 用户确认后调 `copyBatchIntoProject`。
4. 复制成功后刷新项目文件树，提示复制的文件数。
5. 删除批次目录。

附到会话：

1. 面板列项目。用户点一个项目。
2. 面板列该项目的会话，带「新建会话」一项。
3. 用户确认后复制文件到 `inbox/`。
4. 调 `openEditorPage`，带会话 id 与附件 draft。
5. 编辑器首帧停在 Agent 面板，输入卡片带附件。
6. 删除批次目录。

### 5.4 取消

1. 面板关闭。
2. 批次留在收件箱。
3. 下次启动 `sweep()` 按 7 天与 512 MiB 清理。

## 6 存储与清理

目录布局：

```
<应用数据目录>/shared_inbox/<batchId>/0001-notes.md
<应用数据目录>/shared_inbox/<batchId>/0002-photo.jpg
```

规则：

- 原生新建 `batchId`：`<毫秒时间戳>-<4 位随机>`。只允许 `[A-Za-z0-9_-]`。
- 每个批次目录最多 16 个文件。
- 单文件超过 2 GiB 时跳过，并把跳过原因写进批次消息的 `error` 字段外的日志。
- 批次总字节超过 512 MiB 时停止复制后续文件。
- `sweep()` 在启动后与每次处理完批次后各跑一次。
- `sweep()` 先删 7 天前的批次，再按目录修改时间从旧到新删，直到总量不超过 512 MiB。
- 清理失败只记日志，不抛出。

## 7 落点清单

| 仓库 | 文件 | 改动 |
|---|---|---|
| core | `lib/share/share_inbox.dart` | 新增：模型、`ShareInbox`、`PlatformShareInbox` |
| core | `lib/share/share_inbox_store.dart` | 新增：批次目录、上限、`sweep()` |
| core | `lib/share/share_intake.dart` | 新增：复制进项目、打开编辑器 |
| core | `lib/share/share_intake_sheet.dart` | 新增：选择面板 |
| core | `lib/share/share_intake_host.dart` | 新增：监听通道、弹面板、等首帧 |
| core | `lib/chat/composer_draft.dart` | 加 `autoSend` |
| core | `lib/shell/workbench_agent_pane.dart` | 尊重 `autoSend` |
| core | `lib/editor/editor_page.dart` | 只加 `composerPrefill`。会话参数归 Pi-C |
| core | `lib/editor/retained_editor_host.dart` | 只透传 `composerPrefill`。会话参数归 Pi-C |
| core | `test/share/*` | 新增：单元与 widget 测试 |
| app | `lib/main.dart` | 装配收件箱与宿主 |
| app | `android/app/src/main/AndroidManifest.xml` | 三条 intent-filter |
| app | `android/app/src/main/kotlin/com/azurekiln/qflistudio/MainActivity.kt` | 建桥、转发 intent |
| app | `android/app/src/main/kotlin/com/azurekiln/qflistudio/ShareInboxBridge.kt` | 新增：解析与复制 |
| app | `ios/Runner/Info.plist` | `CFBundleDocumentTypes` |
| app | `ios/Runner/SceneDelegate.swift` | 处理冷启动与热启动 URL |
| app | `ohos/entry/src/main/module.json5` | 两条 skill |
| app | `ohos/entry/src/main/ets/entryability/EntryAbility.ets` | 接入 want |
| app | `ohos/entry/src/main/ets/share/ShareInbox.ets` | 新增：解析与复制 |

## 8 兼容既有测试

- 依赖顺序（裁定 R11）：Pi-C 的接口提交先合进 `mobile/pi-a`，本文第 4.6 与 4.8 节才成立。
- 未合入前，`harnessSession` 与 `initialHarnessSession` 不存在。本任务不自行定义这两个名字。
- `ComposerDraft.autoSend` 默认 true。既有调用与测试行为不变。
- `EditorPage` 与 `openEditorPage` 只加一个可空参数 `composerPrefill`。既有调用点不改。
- 清单、plist、module.json5 的改动只增不改。Dart 测试不读这些文件。
- `test/release_version_test.dart` 只读 pubspec 与 app.json5。本次不碰版本号。
- 既有 composer 与 editor 测试不改。新测试放 `test/share/`。
- `generated_plugin_registrant.*` 与 `GeneratedPluginRegistrant.*` 不提交。

## 9 权衡

1. 复制进项目 vs 白名单外附件
   - 选复制。代价是磁盘多一份副本。
   - 收益是 `read_file` 直接可用，不必新开只读白名单通道。

2. 原生复制 vs Dart 复制
   - 选原生。理由：Android 的 `content://` 授权会过期。
   - 代价是三端各写一份复制逻辑。

3. 一批一个面板 vs 每文件一个面板
   - 选一批一个。理由：多文件时用户只做一次决定。

4. 收件箱 7 天 vs 立即删
   - 选 7 天。理由：取消后还能再处理。
   - 代价是占磁盘。用 512 MiB 上限兜住。

5. iOS 只改 `SceneDelegate.swift`
   - 收益：不碰 pbxproj，CI 与重签都稳。
   - 代价：Swift 代码集中在一个文件，长度会增加。

## 10 上线与回滚

顺序按裁定 R11：

1. 等 Pi-C 的接口提交合进 `mobile/pi-a`。本任务不动代码。
2. core 的 `autoSend` 与 `composerPrefill`。行为兼容，可先合。
3. core 的收件箱服务与选择面板。无原生通道时 `start()` 静默失败。
4. app 的 Android 清单与桥接。
5. app 的 iOS 清单与 `SceneDelegate`。
6. app 的鸿蒙 skill 与 Ability。
7. app 的 `main.dart` 装配。

集成顺序：C → B → A → D。

回滚点：

- 预填回滚：还原 `composer_draft.dart`、`workbench_agent_pane.dart`、两个编辑器文件。
- 收件箱回滚：删除 `lib/share/`，还原 `main.dart` 的装配。
- Android 回滚：还原清单与两个 Kotlin 文件。
- iOS 回滚：还原 `Info.plist` 与 `SceneDelegate.swift`。
- 鸿蒙回滚：还原 `module.json5` 与 `EntryAbility.ets`。
- 数据回滚：删除 `<应用数据目录>/shared_inbox/`。无迁移，无版本号。
- 每一步单独提交。回滚只还原该步文件。

灰度：

- 先发 Android。Android 用户最多，验证成本最低。
- iOS 与鸿蒙同版本发。两端都靠系统列表验证，不改发布流程。

## 11 未决问题与建议答案

| 问题 | 建议答案 |
|---|---|
| 会话定位用哪个参数？ | 用 Pi-C 的 `harnessSession`。不自建会话参数（裁定 R1） |
| 「新建会话」怎么建？ | 调 `runtime.sessions.create(project.id)`，再传它的 id |
| iOS 是否加 Share Extension？ | v1 不加。先文档类型，看微信实测结果再定 |
| 附件是否复制进项目？ | 是，复制到 `inbox/`。`read_file` 只收项目内相对路径 |
| 单批文件数上限？ | 16 个 |
| 单文件上限？ | 2 GiB |
| 收件箱常驻上限？ | 512 MiB |
| 收件箱保留期？ | 7 天 |
| 重名策略？ | `name (1).ext` |
| 是否支持纯文本分享？ | v1 不支持。文本走粘贴 |
| 放进项目时默认子目录？ | `inbox` |
| 面板里是否允许新建项目？ | 不允许。先建项目再分享 |
| 鸿蒙 `maxFileSupported`？ | `sendData` 取 16，`viewData` 取 1 |
| 收件箱目录名？ | `shared_inbox` |
| 冷启动缓存几批？ | 只缓存最后一批，更早的批次由 `sweep()` 清理 |
