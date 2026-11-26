# 接收分享文件：执行清单

覆盖 `11-23-share-target`。设计见 `design.md`，需求见 `prd.md`。

约束提醒：

- 两个仓库各自 `flutter pub get`。core 在 `../qfli_studio_core`。
- 本机只跑静态检查。测试只在云端 CI 跑。
- 不提交插件注册文件。
- 每步一个提交，只提交本步列出的路径。
- 每步之后跑一次本步的静态检查。
- 本清单按计划审查裁定 R1、R10、R11 改写。

## 第 0 步 等 Pi-C 接口合入

仓库：无改动。

前置条件：

1. Pi-C 先单独提交接口（裁定 R1）。
2. 提交包含 `HarnessSessionTarget`、编辑器两个参数、`HarnessDeviceInfo`、`HarnessDeviceHost`。
3. 大脑把这个提交合进 `mobile/pi-a`。

确认方式：

- 在 `lib/harness/` 找到 `HarnessSessionTarget` 定义。
- 在 `lib/editor/editor_page.dart` 找到 `initialHarnessSession`。
- 在 `lib/editor/retained_editor_host.dart` 找到 `harnessSession`。

不满足就停下，不自行命名这两个参数。

评审门：接口签名已定，本文后续步骤可以直接引用。

回滚点：无（不改代码）。

## 第 1 步 core：预填开关（autoSend）

仓库：`qfli_studio_core`。

文件：

- `lib/chat/composer_draft.dart`
- `lib/shell/workbench_agent_pane.dart`

内容：

1. `ComposerDraft` 加 `final bool autoSend`，默认 true。
2. `WorkbenchAgentPane._bootstrap` 只在 `autoSend` 为真时发送。
3. 为 `autoSend` 为假补一条 widget 测试。

静态检查：

```
dart format --output=none --set-exit-if-changed lib/chat lib/shell
flutter analyze --no-pub lib/chat lib/shell
```

评审门：

- 既有 composer 测试一处不改。
- `ComposerDraft` 的既有构造调用不改。

回滚点：还原两个文件。

## 第 2 步 core：编辑器预填参数

仓库：`qfli_studio_core`。

文件：

- `lib/editor/editor_page.dart`
- `lib/editor/retained_editor_host.dart`

内容：

1. `EditorPage` 只加 `composerPrefill`，传给 `WorkbenchAgentPane(draft: ...)`。
2. `openEditorPage` 只加 `composerPrefill` 并透传。
3. 不碰 `initialHarnessSession` 与 `harnessSession`。这两个由 Pi-C 拥有（裁定 R1 与 R10）。

静态检查：

```
dart format --output=none --set-exit-if-changed lib/editor
flutter analyze --no-pub lib/editor
```

评审门：

- 本步提交不含会话参数改动。
- 既有 `EditorPage` 构造点一处不改。
- Pi-C 的编辑器测试不改。

回滚点：还原两个文件里本步的改动。

## 第 3 步 core：收件箱通道与目录

仓库：`qfli_studio_core`。

文件：

- 新增 `lib/share/share_inbox.dart`
- 新增 `lib/share/share_inbox_store.dart`
- 新增 `test/share/share_inbox_test.dart`

内容：

1. 按 design 4.1 写模型与 `ShareInbox`。
2. 按 design 4.2 写通道消息。
3. 按 design 6 写目录布局、上限与 `sweep()`。
4. 用假通道测 `takePending`、`incoming`、`discard`、`sweep()`。

静态检查：

```
dart format --output=none --set-exit-if-changed lib/share test/share
flutter analyze --no-pub lib/share test/share
```

评审门：

- 通道名与字段名与 design 4.2 逐字一致。
- `sweep()` 的删除顺序有测试覆盖。

回滚点：删 `lib/share/` 与 `test/share/`。

## 第 4 步 core：两种去向

仓库：`qfli_studio_core`。

文件：

- 新增 `lib/share/share_intake.dart`
- 新增 `lib/share/share_intake_sheet.dart`
- 新增 `lib/share/share_intake_host.dart`
- 新增 `test/share/share_intake_test.dart`

内容：

1. 按 design 4.7 写 `copyBatchIntoProject`。
2. 按 design 4.8 写「附到会话」。会话定位传 `harnessSession`。
3. 「新建会话」用 `runtime.sessions.create(project.id)`。
4. 按 design 5.3 写选择面板。
5. 宿主等首帧与就绪信号，再弹面板。
6. 测重名改名、`.part` 落盘、批次删除、面板三选项。

静态检查：

```
dart format --output=none --set-exit-if-changed lib/share test/share
flutter analyze --no-pub lib/share test/share
```

评审门：

- 重名到 99 次时放弃，不覆盖。
- 失败时批次目录保留。
- 面板不自动发送。
- 本步用 `harnessSession` 打开编辑器，不自造会话参数。

回滚点：删本步三个文件与测试。

## 第 5 步 app：Android 分享入口

仓库：`qflistudio`。

文件：

- `android/app/src/main/AndroidManifest.xml`
- `android/app/src/main/kotlin/com/azurekiln/qflistudio/MainActivity.kt`
- 新增 `android/app/src/main/kotlin/com/azurekiln/qflistudio/ShareInboxBridge.kt`

内容：

1. 按 design 4.3 加三条 intent-filter。
2. `MainActivity` 建桥，`configureFlutterEngine` 与 `onNewIntent` 各转发一次。
3. 桥接复制按 1 MiB 分块。
4. 只认 `content` 与 `file` 两种 scheme。

静态检查：

```
dart format --output=none --set-exit-if-changed lib
flutter analyze --no-pub lib
```

说明：Kotlin 没有本机静态检查。清单改动由 CI 的 Android 构建验证。

评审门：

- 清单只增不改，`launchMode` 与 `taskAffinity` 不动。
- 没加 `http` 与 `https` 的 VIEW。
- 没加存储权限。

回滚点：还原三个文件。

## 第 6 步 app：iOS 文档类型与打开

仓库：`qflistudio`。

文件：

- `ios/Runner/Info.plist`
- `ios/Runner/SceneDelegate.swift`

内容：

1. 按 design 4.4 加 `CFBundleDocumentTypes`。只追加键，不重排既有键（裁定 R10）。
2. `SceneDelegate` 处理 `willConnectTo` 与 `openURLContexts`。
3. 复制用 `FileHandle` 分块，配 `startAccessingSecurityScopedResource`。

静态检查：

```
dart format --output=none --set-exit-if-changed lib
flutter analyze --no-pub lib
```

说明：Swift 没有本机静态检查。plist 用 `plutil -lint` 检查。

评审门：

- 不碰 `project.pbxproj`。
- 不改 `Runner.entitlements`。
- 不加 App Group。
- `Info.plist` 只追加键，既有键顺序不变。

回滚点：还原两个文件。

## 第 7 步 app：鸿蒙 skill 与 want

仓库：`qflistudio`。

文件：

- `ohos/entry/src/main/module.json5`
- `ohos/entry/src/main/ets/entryability/EntryAbility.ets`
- 新增 `ohos/entry/src/main/ets/share/ShareInbox.ets`

内容：

1. 按 design 4.5 加两条 skill。
2. `onCreate` 与 `onNewWant` 都调 `offerShareWant`。
3. 复制用 `fileIo.copyFile`。

静态检查：

```
dart format --output=none --set-exit-if-changed lib
flutter analyze --no-pub lib
```

说明：ArkTS 由 CI 的鸿蒙构建验证。

评审门：

- `skills` 只加两条，不动 home 与 interop。
- `requestPermissions` 无新增。

回滚点：还原三个文件。

## 第 8 步 app：启动装配

仓库：`qflistudio`。

文件：

- `lib/main.dart`

内容：

1. 建 `PlatformShareInbox`，首帧后 `start()`。
2. 传 `navigatorKey` 给 `ShareIntakeHost`。
3. 等 `ready` 为真再弹面板。
4. 异常只记日志，不影响启动。

静态检查：

```
dart format --output=none --set-exit-if-changed lib/main.dart
flutter analyze --no-pub lib/main.dart
```

评审门：

- 启动路径没有新增 await 阻塞首帧。
- 通道缺失时静默降级。

回滚点：还原 `lib/main.dart`。

## 第 9 步 文档与回归

仓库：`qflistudio` 与 `qfli_studio_core`。

文件：

- `.trellis/spec/frontend/` 新增 `share-target.md`
- `.trellis/spec/frontend/index.md` 加一行

内容：

1. 记录三端入口、通道契约、收件箱上限。
2. 记录测试只在 CI 跑。

静态检查：

```
python scripts/ste-lint-zh.py .trellis/spec/frontend/share-target.md
```

评审门：

- `core-check` 全绿。
- App installers 全绿。
- 原有测试文件一处不改。

回滚点：还原两份文档。

## 需要真机的检查

以下项只能在真机验证，云端 CI 覆盖不到：

| 编号 | 检查 | 平台 |
|---|---|---|
| A1 | 微信「用其他应用打开」列表出现 QFLI | Android |
| A2 | 三个文件一次进同一批 | Android |
| A3 | 文件管理器点开 .md 时 QFLI 在列表 | Android |
| A4 | 文件应用「用其他应用打开」出现 QFLI | iOS |
| A5 | 微信分享 PDF 到 QFLI | iOS |
| A6 | 系统分享面板出现 QFLI | 鸿蒙 |
| A7 | 点开文件时 QFLI 在列表 | 鸿蒙 |
| A8 | 冷启动分享后首屏弹面板 | 三端 |
| A9 | 热启动分享后当前界面弹面板 | 三端 |
| A15 | 1 GiB 文件复制时内存峰值 | Android 与 iOS |

判定方式：

- A1 至 A7 看系统列表是否出现 QFLI，再看文件是否进收件箱。
- A8 与 A9 用 `adb shell am start` 与分享 intent 复现。
- A15 用系统内存面板读数，记录峰值。

## 检查顺序总表

| 步 | 仓库 | 本机静态检查 | 真机 |
|---|---|---|---|
| 0 | 无 | 无 | 否 |
| 1 | core | format + analyze | 否 |
| 2 | core | format + analyze | 否 |
| 3 | core | format + analyze | 否 |
| 4 | core | format + analyze | 否 |
| 5 | app | format + analyze + 清单评审 | 是 |
| 6 | app | format + analyze + `plutil -lint` | 是 |
| 7 | app | format + analyze | 是 |
| 8 | app | format + analyze | 是 |
| 9 | 两仓 | `ste-lint-zh.py` | 否 |
