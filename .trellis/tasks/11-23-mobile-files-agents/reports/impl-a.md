# 接收分享文件：实现报告

任务：`11-23-share-target`（父任务 `11-23-mobile-files-agents`）
分支：`mobile/pi-a`
范围：只改 `_wt/mobile/pi-a/qflistudio`（app）与 `_wt/mobile/pi-a/qfli_studio_core`（core）。

## 总览

| 需求 | 内容 | 仓库 | 提交 |
|------|------|------|------|
| R1.1 R1.2 R1.3 | Android 分享与打开入口 | app | `f22d74a` |
| R1.4 R1.5 | iOS 文档类型与打开 URL | app | `f22d74a` `cebc213` |
| R1.6 R1.7 | 鸿蒙 skill 与 want | app | `f22d74a` `2cd5055` |
| R1 公共 | 收件箱通道与目录 | core | `eba3b30` |
| R2.1 R2.10 | 选择面板与文件清单 | core | `31154b7` `aeb97f7` |
| R2.2 R2.3 | 放进项目与重名改名 | core `aeb97f7`，app `d05e3e7` | — |
| R2.4 R2.5 R2.6 R2.7 | 附到会话与取消 | core `31154b7`，app `a587e1e` | — |
| R2.8 R2.9 | 冷启动与热启动 | 三端原生 `f22d74a`，装配 `a587e1e` | — |
| R2.11 R2.12 | 流式复制与收件箱清理 | `eba3b30` `31154b7` | — |

## 需求 1 注册为分享目标

### R1.1 R1.2 R1.3 Android

- `android/app/src/main/AndroidManifest.xml`：`activity` 增加三个 `intent-filter`。`SEND` 与 `SEND_MULTIPLE` 用 `mimeType="*/*"`。`VIEW` 只认 `scheme="content"`，故意不认 `http` 与 `https`，避免抢浏览器链接。
- 新建 `ShareInboxBridge.kt`：解析 intent（`EXTRA_STREAM`、`ClipData`、`data`），在工作线程按 1 MiB 分块复制到 `filesDir/shared_inbox/<批次>/`，文件名取 `OpenableColumns.DISPLAY_NAME`。批次 id 为 `<毫秒>-<4 位随机>`。超过 16 个文件或 2 GiB 的文件跳过。一批全部失败时删除空目录。
- `MainActivity.kt`：`configureFlutterEngine` 建通道并处理冷启动 intent，`onNewIntent` 处理热启动。通道方法 `takePending` 与 `discard`，`discard` 先检查 id 白名单再删目录。
- 冷启动与热启动共用一条流：`takePending` 之前原生缓存最后一批，之后原生主动 `invokeMethod('incoming')`。

### R1.4 R1.5 iOS

- `ios/Runner/Info.plist`：追加 `CFBundleDocumentTypes`（`public.data`、`public.text`、`public.image`，`LSHandlerRank=Alternate`），原有键一个未动。
- `ios/Runner/SceneDelegate.swift`：新增 `ShareInboxBridge`（同文件，避免改 `project.pbxproj`）。`offer(urls:)` 过滤 `file://`，按 1 MiB 用 `FileHandle` 复制，复制期间 `startAccessingSecurityScopedResource`。`SceneDelegate` 在 `willConnectTo`（冷启动）与 `openURLContexts`（热启动）先调 `super` 再交给桥。
- `AppDelegate.swift`：在 `didInitializeImplicitFlutterEngine` 里用 `applicationRegistrar.messenger()` 装配通道，与已有 `qflistudio/platform` 通道同一处。
- 不做 Share Extension，也不开 App Group：CI 出的是未签名包，用户重签后 App Group 容器可能失效。代价是少数微信内的分享类型可能不直接列出 QFLI，需真机确认（A5）。

### R1.6 R1.7 鸿蒙

- `ohos/entry/src/main/module.json5`：`skills` 增加 `sendData`（`maxFileSupported: 16`）与 `viewData`（`maxFileSupported: 1`），都用 `scheme: "file"` 与 `utd: "general.file"`。
- 新建 `ohos/entry/src/main/ets/share/ShareInbox.ets`：`offerShareWant` 从 `want.parameters['ability.params.stream']` 与 `want.uri` 取路径，用 `fileIo.copyFileSync` 复制到 `filesDir/shared_inbox/<批次>/`。`configureShareInbox` 建通道，`takePending` 与 `discard` 与另两端一致。
- `EntryAbility.ets`：`onCreate(want, launchParam)` 与 `onNewWant(want, launchParams)` 先交给 `offerShareWant` 再调 `super`，`configureFlutterEngine` 里装配通道。

### R1 公共：core 收件箱

- `lib/share/share_inbox.dart`：`kShareInboxChannel`、`SharedIncomingFile`、`ShareInboxBatch`、抽象 `ShareInbox`、`PlatformShareInbox`、`parseShareInboxBatch`。非法载荷（id 不匹配白名单、缺 path）直接忽略。
- `lib/share/share_inbox_store.dart`：`batchDirectory`、`discard`、`sweep`。`sweep` 先删超期批次，再按最旧优先删到总量不超 512 MiB。上限常量：单批 16 个文件、单文件 2 GiB、总量 512 MiB、保留 7 天。

## 需求 2 让用户选去向

### R2.1 R2.10 选择面板

- `lib/share/share_intake_sheet.dart`：三步面板（去处 → 项目 → 子目录或会话），第三项是取消。面板顶部按行列出文件名与大小（最多 6 行，其余折成计数），大小由 `formatSharedBytes` 产出。
- 键名固定：`share-intake-sheet`、`share-intake-files`、`share-intake-into-project`、`share-intake-into-session`、`share-intake-cancel`、`share-intake-project-<id>`、`share-intake-subdir-inbox`、`share-intake-subdir-root`、`share-intake-new-session`、`share-intake-session-<id>`。

### R2.2 R2.3 放进项目

- `lib/share/share_intake.dart`：`copyBatchIntoProject` 复制到 `<项目>/<子目录>`，默认子目录 `inbox`，选「项目根目录」时子目录为空串。
- 重名依次试 `name (1).ext` 到 99 次，不覆盖已有文件。
- 先写 `<name>.part` 再 rename，同名目标已存在时报错不覆盖。
- 单文件超上限或源文件不存在时跳过，记在 `ShareIntakeResult.skipped`。
- `_cleanSubdirectory` 拒绝 `..`，一旦出现回落到 `inbox`，因此面板传什么都跳不出项目。
- 选「项目根目录」时返回的相对路径就是 `a.txt`，不再带 `inbox/` 前缀。

### R2.4 R2.5 R2.6 附到会话

- 复制先进项目，再 `openEditorPage(...)`：`revealAgentPane: true`、`harnessSession: HarnessSessionTarget(hostId: kStudioHostId, sessionId: id)`、`composerPrefill: ComposerDraft(attachments: relativePaths, autoSend: false)`。
- 会话 id 为空时先 `runtime.sessions.create(project.id)`。
- `ComposerDraft` 增加 `autoSend`（默认 `true`，老调用点行为不变）。`ComposerDraft` 为假时 `WorkbenchAgentPane._bootstrap` 只 `attachAll`，不调 `_send`。
- `EditorPage` 只增加 `composerPrefill` 一个参数，`openEditorPage` 与 `RetainedEditorController.open` 同步透传，`_EditorSession` 记住它。会话定位沿用 Pi-C 的 `harnessSession`，没有第二套会话参数（裁定 R1）。

### R2.7 取消

取消时不动收件箱，文件留在 `shared_inbox/<批次>/`，7 天内 `sweep` 不会删。

### R2.8 R2.9 R2.11 R2.12 生命周期与大文件

- `lib/share/share_intake_host.dart`：订阅 `inbox.incoming`，队列化，等 `ready` 为真再弹面板，所以冷启动时批次排队到首屏就绪。热启动时 `ready` 已为真，直接弹。
- 复制全部走 1 MiB 分块流式写，内存峰值与文件大小无关。
- `ShareIntakeHost.start()` 里 `await inbox.start()` 后 `unawaited(inbox.sweep())`，启动时清理一次。
- `lib/main.dart`：启动完成后装配 `PlatformShareInbox`（根目录 `<应用数据>/shared_inbox`）与 `ShareIntakeHost`，`sessionsOf` 取自 `studioAgentRuntime` 的会话存储。装配放在 `completeStartup` 里，不拦首帧。

## 静态检查

| 仓库 | 命令 | 结果 |
|------|------|------|
| core | `dart format lib/share test/share lib/chat/composer_draft.dart lib/shell/workbench_agent_pane.dart lib/editor/agent/agent_dock.dart lib/editor/editor_page.dart lib/editor/retained_editor_host.dart test/workbench_agent_pane_test.dart` | 通过，0 处改动 |
| core | `flutter analyze --no-pub lib/share test/share` | `No issues found` |
| app | `dart format lib/main.dart` | 通过 |
| app | `flutter analyze --no-pub lib test` | `No issues found` |
| docs | `python scripts/ste-lint-zh.py .trellis/spec/frontend/share-target.md` | 硬违规 0 |

说明与偏差：

- 全仓 `flutter analyze --no-pub`（core）另有 2 条 `info`，落在 `lib/chat/composer_card.dart:346` 与 `lib/harness/harness_host.dart:6`。两个文件都不在本任务改动范围内，来自 Pi-C 合入的接口提交。本任务碰到的文件 `analyze` 无告警。
- 全仓 `flutter analyze --no-pub`（app）的报错全部在 `companion/windows_assistant` 子包。该子包不在本仓依赖里，属于既有状态。`lib` 与 `test` 干净。
- `git status` 里 `linux|macos|windows/flutter/generated_plugin_registrant*` 与 `generated_plugins.cmake` 显示已修改，但 `git diff --numstat` 为空，是 `flutter pub get` 带出的行尾噪音。按约束未提交。
- 第 6 步要求 `plutil -lint`，本机是 Windows，没有 `plutil`。`Info.plist` 用追加方式改，未动原有键，改完由 `git diff` 逐行看过。
- 鸿蒙与本机都没有 ArkTS 与 Kotlin 编译器，只有阅读级检查。`onCreate` 与 `onNewWant` 的签名对齐了本机 Flutter SDK 的 `FlutterAbility.ets`（`want` 加 `launchParam`）。`iOS` 部署目标是 13.0，因此没有引 `UniformTypeIdentifiers`，MIME 用扩展名小表推断。

## 仍需真机确认

| 编号 | 检查 | 平台 |
|------|------|------|
| A1 | 微信「用其他应用打开」列表出现 QFLI | Android |
| A2 | 三个文件一次进同一批 | Android |
| A3 | 文件管理器点开 `.md` 时 QFLI 在列表 | Android |
| A4 | 文件应用「用其他应用打开」出现 QFLI | iOS |
| A5 | 微信分享 PDF 到 QFLI，确认文档类型够用（未做 Share Extension 的代价） | iOS |
| A6 | 系统分享面板出现 QFLI | 鸿蒙 |
| A7 | 点开文件时 QFLI 在列表 | 鸿蒙 |
| A8 | 冷启动分享后首屏弹面板 | 三端 |
| A9 | 热启动分享后当前界面弹面板 | 三端 |
| A15 | 1 GiB 文件复制时内存峰值 | Android 与 iOS |

另外两项只有真机能看出问题：

- iOS 冷启动时 `SceneDelegate` 先于 `didInitializeImplicitFlutterEngine` 拿到 URL。批次会留在原生 `pending`，等 Dart `takePending` 取走。需要在 A8 里确认这条路径真的走通。
- 鸿蒙 `viewData` 一次只带一个文件，`sendData` 带多个。两个 skill 同时在列表里出现时系统给哪个 action，需要在 A6 与 A7 里各看一次。

## 未做

- 没有新增存储权限，没有把文件写到应用数据目录之外。
- 没有改 `WorkbenchState.sessionId` 的初始化逻辑，也没有加第二套会话定位参数。
- 没有动 `.qfli/` 写入规则、外部目录删除、局域网鉴权等父任务其他裁定。
- 没有实现 Share Extension，也没有开 App Group。
