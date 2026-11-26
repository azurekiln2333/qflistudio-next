# 分享目标交叉检查（Pi-B）

范围：`11-23-share-target` 的实现对照 `prd.md`、`design.md`、`implement.md`、计划审查裁定与 `reports/impl-a.md`。

代码基线：`mobile/integration`，core `89c7a19` 之后、app `37116fc` 之后。

结论：功能主体齐全，未发现「面板打不开」或「文件写错地方」这类阻断缺陷。本报告修了 7 处真实缺陷，其余按裁定不改。

## 1 已修的问题

| 序号 | 位置 | 严重度 | 结论 | 提交 |
| --- | --- | --- | --- | --- |
| 1 | `qfli_studio_core/lib/share/share_intake.dart:67`、`:71`、`:76`、`:84` 对 `test/share/share_intake_test.dart:97`、`:110` | P1 | `skipped` 写的是 `名字：原因`，测试断言 `<String>['gone.txt']` 与 `<String>['big.bin']`。两边必然不等。impl-a 报告写「测试未改且通过」，与实际不符。CI 上这两条必红。按 design 4.7（`skipped` 记文件名与原因）保留实现里带原因的文本，改断言为 `startsWith` | core `0a0ab7d` |
| 2 | `share_intake_host.dart:88`、`:100` | P1 | 冷启动时 `navigatorKey.currentContext` 为 null。`_drain` 直接 return 且没有重排。只剩 `ready` 变化和下一次 `incoming` 能再触发。`ready` 在 `start()` 之前就为真时，冷启动批次永远不弹面板。A8 在真机上会表现为「分享后什么都没发生」。改为下一帧重试，上限 30 帧 | core `0a0ab7d` |
| 3 | `share_intake_host.dart:146` | P2 | design 6 要求「`sweep()` 在启动后与每次处理完批次后各跑一次」，实现只在启动跑一次 | core `0a0ab7d` |
| 4 | `share_intake_host.dart:126`（旧） | P1 | 复制部分成功、部分跳过时也 `discard`，跳过的文件随批次一起消失。R2.7 要求失败或取消的批次留在收件箱，这里会把用户文件删除。改为仅当 `skipped` 为空才删 | core `e1072f9` |
| 5 | `ShareInboxBridge.kt:79`、`:221`。`SceneDelegate.swift:105`、`:121` | P2 | 批次总量上限没在复制时生效。Android 只在开始前看累计值。iOS 完全没看整批上限。一批 16 个 200 MiB 文件会写 3.2 GiB 进收件箱，与设计 6 的「批次总字节超过 512 MiB 时停止复制」不符。两端加预算参数：先查 `OpenableColumns.SIZE`，边复制边检查 | app `c08692d` |
| 6 | `ShareInboxBridge.kt:221`、`SceneDelegate.swift:121` | P2 | `copy()` 开头 `openInputStream` 返回 null 时返回 `-1L`，调用方当成「超限」。iOS 的 `try?` 吞掉写失败，返回已读字节数，上层把这个数当完整文件大小。鸿蒙按 `size <= 0` 丢弃空文件。统一为：读失败返回 null、超限返回负数、0 字节文件保留 | app `c08692d`、`addb2bf`、`d60d6a9` |
| 7 | `ohos/.../share/ShareInbox.ets:91` | P2 | `fileIo.copyFileSync` 同步复制，冷启动时跑在 `onCreate` 的 UI 线程上。几百 MiB 会让系统判无响应。改成 `await fileIo.copyFile`，调用方不等待 | app `d60d6a9` |
| 8 | `main.dart:210`（旧） | P2 | `unawaited(startShareInbox())` 没有错误出口。装配失败时（例如 `studioAgentRuntime` 抛错）会变成未捕获的异步错误，可能带倒启动。加 `catchError` 只记日志 | app `3363e17` |
| 9 | `ShareInboxBridge.kt`（`pending` 与 `dartListening` 为实例字段） | P2 | Activity 重建会换一个新桥，`dartListening` 回 false，新桥只把批次放进缓存。Dart 的 `takePending` 只在启动时调一次，该批次再也送不出去。两者改为进程级（companion，`@Volatile`），并在 `configureFlutterEngine` 里调 `flushPending()` | app `c0eaabd` |
| 10 | `ShareInboxBridge.kt:158` | P3 | `dispose()` 用 `shutdownNow()` 会中断正在复制的线程，留下半截文件。改为 `shutdown()`（不打断已提交任务） | app `c0eaabd` |
| 11 | `SceneDelegate.swift:32` | P2 | `guard channel == nil else { return }` 让重建的引擎拿不到新 messenger。之后 `invokeMethod('incoming')` 打进死通道，分享静默丢失。改为每次重新装配 | app `bf776c4` |
| 12 | `Info.plist` 的 `CFBundleDocumentTypes` | P3 | 缺 `CFBundleTypeRole`。文档类型里这是必填键，缺了 iOS 文档交互配置不完整。补 `Viewer`，只追加，未动既有键（裁定 R10） | app `d60d6a9` |
| 13 | `ShareInboxBridge.kt:48` | P3 | `intent.resolveType(context)` 在 worker 线程里取。`MainActivity` 又用 `setIntent` 覆盖了 Activity 的 intent，热启动时可能读到错误的 action 与 MIME。改为在 `offer` 入口同步取出并捕获 | app `c08692d` |
| 14 | `main.dart:141`（新） | P3 | design 5.3 第 4 步要求「提示复制的文件数」，实现没有任何成功反馈。补一条：放进项目后提示数量 | app `984aee6` |

新增测试：`test/share/share_intake_host_test.dart`。四条用例覆盖就绪后弹面板并删批次、未就绪排队、取消不删批次、部分跳过保留批次（`e1072f9` 内）。

## 2 查过未改的地方

| 位置 | 结论 |
| --- | --- |
| `AndroidManifest.xml` 三条 intent-filter | 与 design 4.3 一致，只认 `content` 与 `file`，没有 `http`/`https`，没有新增存储权限，`launchMode`/`taskAffinity` 未动 |
| `module.json5` skills | 只有 `sendData`（16）与 `viewData`（1）两条，`home` 与 interop 未动，`requestPermissions` 无新增 |
| `pbxproj` | `SceneDelegate.swift` 已在 Sources（首个提交就有），本轮没有改工程文件 |
| 收件箱路径 | 三端都落在应用私有目录（Android `filesDir`、iOS `Application Support`、鸿蒙 `filesDir`）。批次 id 先过 `[A-Za-z0-9_-]{1,64}` 白名单，三端的 `discard` 也都先检查 |
| `share_intake.dart` 子目录净化 | `..` 回落到 `inbox`，绝对路径不会拼出去。文件名净化为最后一段 |
| `ComposerDraft.autoSend` | 默认 true，既有调用行为不变。`workbench_agent_pane.dart` 仅 `attachAll` 不 `_send`。`test/workbench_agent_pane_test.dart:1340` 有覆盖 |
| 编辑器预填 | `EditorPage.composerPrefill` 传给 `EditorAgentPane.draft`，再到 `WorkbenchAgentPane._bootstrap`。会话定位走 Pi-C 的 `harnessSession`，Studio 主机直接 `selectSession`，没有第二套会话参数（裁定 R1） |
| `share_inbox.dart` 解析 | 非法 id、空 path、空 files 整批丢弃，不抛错误。`MissingPluginException` 静默降级，桌面端不受影响 |
| `share_inbox_store.dart` sweep | 先删 7 天前，再按最旧优先删到 512 MiB 以内。失败只跳过。`test/share/share_inbox_test.dart` 有覆盖 |
| 共享测试 | `share_intake_test.dart` 除第 1 条两行断言外未改。其余既有测试未触碰 |
| `.trellis/spec/frontend/share-target.md` 与 `index.md` 登记行 | 两仓 worktree 内不存在（第 9 步未落盘）。该路径不在本次可写范围，留给文档任务补 |

## 3 未验证

- 本机没有跑 `flutter test`、Kotlin、Swift、ArkTS 编译与任何真机流程，全部交给云端 CI 与真机清单（A1–A17）。
- Kotlin 与 Swift 只做了括号配平与人工对照，没有编译器。`flushPending`、`@Volatile` 静态化、`copy` 返回 `Long?` 这三处改动了行为，需要 CI 的 App installers 编译确认。
- ArkTS 的 `await fileIo.copyFile` 返回类型以官方 API 12 签名为准，CI 鸿蒙构建会给出结论。

## 4 提交清单

core：

- `0a0ab7d` fix(share): retry the intake sheet and keep its tests in step
- `e1072f9` fix(share): keep a batch when only some of its files landed

app：

- `3363e17` fix(share): keep launch and the copy loop off the fatal paths
- `c08692d` fix(share): enforce the batch size budget while copying
- `d60d6a9` fix(share): declare the ios document role and copy ohos files off the ui thread
- `c0eaabd` fix(share): hand a rebuilt activity the batch the previous one stashed
- `984aee6` feat(share): confirm how many files landed in the project
- `bf776c4` fix(share): rebind the ios inbox channel when the engine is rebuilt
- `addb2bf` fix(share): skip empty ios copies instead of keeping zero-byte leftovers

## 5 静态检查

- core：`dart format lib/share test/share` 0 处改动。`flutter analyze --no-pub lib/share test/share` 输出 No issues found
- app：`dart format lib/main.dart` 0 处改动。`flutter analyze --no-pub lib/main.dart` 输出 No issues found
- Swift 与 Kotlin：花括号与圆括号配平通过，无本地编译器
