# 接管审查：app 跨端集成就绪（A）

范围：父任务需求 1 与 2 的原生集成面。读 `11-23-mobile-files-agents/prd.md`、`reports/plan-review.md`、`11-23-share-target/{prd,design,implement}.md`，对照 `mobile/integration` 已合入代码。core 只读比对契约。

工作目录：`_wt/mobile/int/qflistudio`、`_wt/mobile/int/qfli_studio_core`。

## 结论

三端的通道消息形状与 core 的 `parseShareInboxBatch` 一致，注册项齐备。改动只落在鸿蒙收件箱一个文件。原生编译未验证，见「未验证项」。

## 保留的改动

`ohos/entry/src/main/ets/share/ShareInbox.ets`，四项：

1. **通道重绑与监听标记重置**（`configureShareInbox`）。原实现用 `if (channel !== null) return;` 早退，引擎重建后新的 `messenger` 拿不到处理器，之后的分享静默丢掉。现在每次装配都建新通道，并在已有旧通道时先 `setMethodCallHandler(null)` 摘掉处理器，再把 `dartListening` 重置为 `false`。这样新引擎的 Dart 还没调 `takePending` 时，批次回到 `pending`，不会推进一个没人接的通道。
2. **URI 去重**（`shareUris`）。`ability.params.stream` 与 `want.uri` 可能指向同一个文件，原来会收两次。现在用 `Set` 按 uri 去重。同时把 `stream` 的窄化改成 ArkTS 接受的写法：`Object | undefined` 加逐项 `typeof === 'string'`，不再出现隐式 `any`。`viewData` 收敛到 1 个、`sendData` 到 16 个，与 `module.json5` 的 `maxFileSupported` 对齐。
3. **半成品清理**（`copyBatch` 的 `catch`）。复制中途失败时原来只剩一个不完整的目标文件。现在在 `catch` 里 `unlinkSync(target)`，包一层 `try` 兜住「本来就没写出文件」。
4. **批次目录路径只算一次**（`copyBatch`）。`batchDir` 提到循环外，替换原先循环里重复的字符串拼接。纯改写，行为不变。

## 已撤回的改动

### Android 的 intent 去重（全部撤回）

我曾给 `ShareInboxBridge.kt` 加过 `rememberIntent`，用 `System.identityHashCode(intent)` 做进程级去重，想挡住 Activity 重建时的重复复制。

撤回理由成立：`identityHashCode` 不是稳定的生命周期投递身份。重建时系统可能交回一个新的 `Intent` 对象，此时去重失效。反过来，哈希碰撞会让一次真实投递直接消失。用错的身份做去重，两种错向都会出现。

`android/app/src/main/kotlin/com/azurekiln/qflistudio/ShareInboxBridge.kt` 已还原到基线，`git diff` 为空。

### 鸿蒙的批次预算改写（撤回）

我曾把 `total + declared > MAX_BATCH_BYTES` 改写成 `declared > budget`（`budget = MAX_BATCH_BYTES - total`），并声称这样能收紧整批上限。

撤回理由成立：两种写法在数学上等价。当 `declaredSize` 返回 `null` 时，两条路径都先把整个文件 `copyFile` 落盘再复核，瞬时占用都会越界。改写不解决这个问题，只是换了个写法。已还原为基线的 `total + declared` 与 `total + size`。

同一条评论里「避免同批同名覆盖」的理由也撤回。目标名带 `pad(index + 1)` 序号前缀，每个目标本就唯一，同名文件不会互相覆盖。

## 未改动项（记录理由）

1. **鸿蒙 `EntryAbility` 未显式写 `launchType`**：模块 `mainElement` 的默认启动模式是 `singleton`，`onNewWant` 正常触发。
2. **鸿蒙 `discard` 的删除**：`rmdirSync` 对不存在的目录会抛，`try` 捕获即幂等，不需要 `accessSync` 前置判断。`ensureDirectory` 里的 `accessSync` 保留，那是 `mkdirSync` 的前置条件。
3. **Android 重建时的重复复制**：现象仍在，本次没有修。要修得用稳定的投递身份，例如批次 id 随 intent 附带，或原生侧记录已消费的 intent 内容哈希加时间窗。这需要设计裁定，不在本次范围。
4. **iOS `SceneDelegate` 未改**：两个重写的签名与引擎 `FlutterSceneDelegate.mm` 一致。冷热启动都在 `super` 之后转发。
5. **Android `VIEW` 只认 `content`**：与设计 4.3 一致，不抢 http 链接。
6. **app 仓库无分享测试**：分享逻辑与测试都在 core，app 只有装配代码。

## 旧 CI 报告

`reports/ci-failures-2.md` 对应 SHA `606810bd`，是本地 `mobile/integration` 的祖先。我不为该报告里的每一条失败给出根因结论：逐条判定归 B、C、D 三方的实际证据。本报告只声明一件事：这些失败项不属于 app 原生集成面，改动落在 core 与 explorer 侧。

## 原生 CI 门禁（编译面，尚未验证）

| 端 | 作业 | 命令 | 涉及的原生文件 |
|---|---|---|---|
| iOS | `ios`（`app-installers.yml:1276`） | `flutter build ios --release --no-codesign` | `ios/Runner/SceneDelegate.swift`、`Info.plist`、`AppDelegate.swift` |
| Android | `android`（`:1598`） | `flutter build apk --release --split-per-abi` | `ShareInboxBridge.kt`、`MainActivity.kt`、`AndroidManifest.xml` |
| 鸿蒙 | `ohos`（`:1908`） | `flutter build hap --release --target-platform ohos-arm64 --no-codesign` | `share/ShareInbox.ets`、`entryability/EntryAbility.ets`、`module.json5` |

`verify-flutter` 矩阵（`:141`）另有 core 与 app 两格，跑 Dart 侧静态与测试。

本机没有 ArkTS 编译器，`ShareInbox.ets` 的语法与类型只能由 CI `ohos` 作业确认。Android 与 iOS 的原生文件本次未改。

## 显式 core SHA 的可行性（只读）

结论：可以。

- `app-installers.yml:55` 把 `core_ref` 声明为 `workflow_dispatch` 输入，说明为空时用 `env.CORE_REF`（`:85`）。
- 12 个消费方都写 `core-ref: ${{ inputs.core_ref || env.CORE_REF }}`。
- `.github/actions/app-setup/action.yml:55` 把它直接传给 `actions/checkout` 的 `ref`，该参数接受分支、标签与提交 SHA。

分支推送事件走 `env.CORE_REF`。要验证 `ci/mobile-files` 上的 core，需显式传参或改 `env.CORE_REF`（后者归 Codex）。

## 静态检查

- `dart format --set-exit-if-changed lib/main.dart`：0 changed。
- `flutter analyze --no-pub lib/main.dart test`：No issues found。
- `Info.plist` 按 XML 解析通过，根元素 `plist`。
- `module.json5` 两条 skill 在 `EntryAbility` 下，`sendData` 为 16，`viewData` 为 1。
- `ShareInbox.ets` 括号配平（`{`、`(` 均为 0），267 行。
- `ShareInboxBridge.kt` 与基线一致，`git diff` 为空。
- 未执行 `flutter test`、模拟器或真机。

## 变更路径

- `ohos/entry/src/main/ets/share/ShareInbox.ets`

未提交，由 Codex 复核后提交。Android 文件已回基线，无改动。

## 剩余缺口

1. 原生编译待 CI：鸿蒙 `ohos` 作业需确认 `ShareInbox.ets` 通过 ArkTS 编译。Android 与 iOS 原生文件未改，走既有门禁。
2. Android Activity 重建时的重复复制仍在，需要设计裁定后再修。
3. 鸿蒙整批上限在 `declaredSize` 返回 `null` 时仍会瞬时越界。修它要在复制前取到大小，或用带预算的流式复制。`copyFile` 没有这个参数。
4. 真机待验：A1–A3（Android 微信列表、三文件同批、`.md` 打开方式）。A4–A5（iOS 文件应用与微信 PDF）。A6–A7（鸿蒙分享面板与打开方式）。
5. A8/A9 冷热启动：三端都要在真机确认。鸿蒙的 `dartListening` 重置正是为冷启动后引擎重建准备的，时序只能真机确认。
6. A15 1 GiB 文件内存峰值：需真机采样。
7. 鸿蒙同一 want 里 `sendData` 与 `viewData` 都匹配时系统选哪条，只能真机确认。
8. iOS 冷启动 URL 是否在 `didInitializeImplicitFlutterEngine` 之前到达，需真机验证批次留在原生 `pending` 直到 Dart `takePending`。
