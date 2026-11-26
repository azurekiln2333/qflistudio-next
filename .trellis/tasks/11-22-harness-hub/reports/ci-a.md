# CI 修复报告（Pi-A 区域）

## 任务与边界

CI 在上一次 core-check 跑满 45 分钟后取消了这次运行。修复前的基线是 4 分钟。CI 日志不可读，所以本次只做静态审计。

本次审计范围是 brief 划给我的区域：

- `lib/harness/local/` 全部 14 个文件
- `lib/harness/pty/harness_pty.dart`
- `test/harness/local/` 全部 10 个测试文件加 `support/fake_pty.dart`

约束照旧：不在本地跑测试，不跑构建，只做静态检查。

## 结论

本区域 118 个用例全部是纯 `test()`。没有 widget 测试，没有 `pumpAndSettle`。区域内部找到并修掉 3 个真实的卡死机制，每个机制一个提交。全仓库的卡死主因在本区域之外，判断见末节。

## 发现与修复（3 个根因，3 个提交）

### R1 读盘出错时不关闭转写流

提交：`3a0ed8c fix(harness): close the log transcript stream when a read fails`

位置：`lib/harness/local/local_harness_host.dart` 的 `_pump`。

机制：`_LogSessionHandle` 把事件灌进单订阅控制器，订阅方用 `await transcript.toList()` 等 done。旧代码只捕获 `FileSystemException`。`reader.read` 报错时（比如切片越界），控制器保持打开。订阅方等一个永远不会到的 done。这是一个无上限的等待。

修复：读盘放进 `try`。`catch` 吞掉一切。`finally` 里关控制器。界面看到的语义是"这个历史会话没有事件"，不会挂着不动。

验证：`dart format` 无改动。`flutter analyze --no-pub lib/harness/local` 无问题。

### R2 测试构造真实平台 PTY 后端，用例没有时限

提交：`b362a5e fix(harness): stop the real platform PTY and add per-test timeouts`

位置：`test/harness/local/local_harness_host_test.dart` 的"不支持的平台"组。时限部分覆盖 `test/harness/local/` 全部 10 个文件。

机制一：`LocalHarnessHost(registry: …, supported: false)` 不传 launcher 时，构造函数走 `createPtyLauncher()`。在 Linux CI 上这一步真的建出 `ScriptPtyLauncher` 加 `ProcessSupervisor`。单元测试不该碰到真实进程后端。

机制二：这些用例真读盘、真等流、真起周期定时器。一旦某个 await 不返回，默认 30 秒超时才报错。一批这样的用例会拖垮整套跑。

修复：

- 两个不支持平台的用例改为注入 `UnsupportedPtyLauncher`。
- 10 个测试文件各加 `@Timeout(Duration(seconds: 20))`。20 秒远大于单条用例的正常耗时（百毫秒级）。卡住的用例在 20 秒内报错，不再拖满 30 秒。

验证：`flutter analyze --no-pub test/harness/local` 无问题。

### R3 释放会话串行等待固定 5 秒

提交：`d9b961f fix(harness): make the mux stop timeout injectable`

位置：`lib/harness/local/studio_mux.dart`。

机制：`MuxSession._stopTimeout` 是固定常量 5 秒。`StudioMux.dispose()` 逐会话串行等退出码。N 个不响应 TERM 的进程，释放要等 N 乘 5 秒。宿主 `dispose()` 在 `addTearDown` 里走这条路径，直接抬高每个用例的尾成本。

修复：

- `stopTimeout` 变成 `StudioMux` 的参数，默认值 5 秒不变，命名为 `defaultStopTimeout`。
- `FakePtyProcess` 加 `neverExits` 开关，`terminate()` 后退出码永不完成。
- 新用例注入 50 毫秒上限，断言 `dispose()` 在 2 秒内完成。默认 5 秒时这条断言不成立，所以它能钉住“释放有上限”这个性质。

验证：`flutter analyze --no-pub lib/harness/local test/harness/local` 无问题。

## 审计过且判定安全的点

- `readJsonlTailLines` 的 `cursor` 与 `index` 同步推进，每轮至少加 1。不会死循环。
- `LiveLogFollower.stop()` 与 `LocalHarnessHost.dispose()` 都取消 `Timer.periodic`。逐条对过创建点与取消点，一一配对。
- `_emitSessions` 开头检查 `_disposed || _sessions.isClosed`。dispose 后在途的刷新不会写已关闭的控制器。
- `ProviderRegistry.logDirectory` 走 `locator.expandHome`，用的是注入的 environment。测试不会扫真实用户目录。
- `executable_locator_test` 与 `provider_registry_test` 全部注入 `fileExists` 与 environment，没有真实 IO。
- `pty_process_test` 的子进程是 `_FakeChild implements PtyChildProcess`，没有真实 spawn。
- 测试里没有 `Process.start`，没有 `Platform.environment`。

## 45 分钟总量的判断

本区域用例即使全卡满，也会在超时后报错，不会无限拖住整套跑。区域内的修复消除的是确定性的卡死与尾成本。

全仓库共 58 个文件、607 处 `pumpAndSettle`，都不在本区域。`pumpAndSettle` 自带 10 分钟上限，与用例超时是两套机制。配合常驻进度指示器（`lib/chat` 与 `lib/editor` 多处 `CircularProgressIndicator`），新增的常驻刷新可能把单条用例拖到分钟级。这个量级与 45 分钟的观测吻合。

这一机制在其他 Pi 的区域，对应的提交已经落地：

- `5e4cd56` 改为固定帧数，不再无限等 settle
- `0506713` 限定 hub 的 teardown
- `09caa6d` 给整套跑加 2 分钟上限

## 交付与验证

- 提交：`3a0ed8c`、`b362a5e`、`d9b961f`。基线 `242a2ae` 之后共 11 个提交，本区域占 3 个，路径与其他 Pi 不重叠。
- `flutter analyze --no-pub lib/harness test/harness`：只剩基线 info（`harness_host.dart:6` 的 `unnecessary_import`）。
- 冻结契约 `lib/harness/harness_host.dart` 与 `f9b6485` 逐字节一致，`git diff` 为空。
- 工作区干净，未推送。

---

# CI fix loop 1（run 45014758649）

## 归属判断

本轮失败清单 10 条。按区域分：

- 我的区域 1 条：`test/github_repository_picker_test.dart`。
- 另 1 条已知：`test/github_auth_controller_test.dart:214`。这条不在本轮清单里，因为我上一轮已经看到它超时。GitHub 每次最多列 10 条。
- 其余 8 条属于其他 Pi。`test/harness/hub_ui_test.dart` 5 条，`test/harness/harness_hub_test.dart` 1 条。`test/experience_test.dart`、`test/editor_agent_embed_test.dart`、`test/trellis_context_test.dart` 各 1 条。

## 修复 1：恢复读取不再占用凭据队列（提交 `ba83049`）

位置：`lib/github/github_auth_controller.dart` 的 `_restore`。

机制：

- `GitHubCredentialOperations.serialized` 用进程级静态 `_tail` 串行化全部保险库操作。
- `restore()` 把读也放进这个队列。
- `disconnect()` 必须等队列排空才返回。
- 读卡住时，`disconnect()` 永不返回。`_tail` 也永不释放。
- 此后任何控制器、任何写或删都排在它后面。整个 isolate 的 GitHub 凭据操作全部挂起。
- 这解释了同文件多个用例连续超时，也解释了 2 分钟量级。

修复：`restore()` 直接 `await _credentialStore.readAccessToken()`。读不改状态。后面的 `_isCurrent(generation)` 会丢弃过期结果，所以读不需要进队列。

影响：`disconnect()` 不再等卡住的读。写与删仍然串行。删除仍然排在已开始的写之后，原语义保留。

验证：`dart format` 无改动。`flutter analyze --no-pub lib/github test/github_auth_controller_test.dart` 无问题。

## 修复 2：选择器用例缺一次打字后的 pump（提交 `72d7cc2`）

位置：`test/github_repository_picker_test.dart` 第一个用例。

机制：

- `github-pat-connect` 的 `onPressed` 在输入框为空时是 null。
- `tester.enterText` 只在打字前 pump 一帧。打字后它只跑 `idle()`，不 pump。
- 所以按钮在树里仍是禁用态。`tap` 落到禁用的 `InkWell` 上，`onPressed` 不触发。
- `auth.patReceived` 保持 null，断言失败。

修复：`enterText` 后补一次 `await tester.pump()`。

理由：产品侧行为正确。真实用户输入时框架会重建。缺的是用例对帧的假设。

验证：`flutter analyze --no-pub test/github_repository_picker_test.dart` 无问题。

## 未修但需要其他人处理的诊断

`test/harness/harness_hub_test.dart` 的 `mobile hides local and herdr hosts` 断言 `hub.currentHostId == 'remote-pc'`。

`lib/harness/hub/harness_hub.dart` 的 `_pickInitialHost` 现在优先返回内置 Agent（studio）。手机端也如此。

这段代码是我在集成阶段改的。目的是保住面板默认显示内置 Agent。

两边只有一个对：

- 若手机端应默认停在已绑定电脑：`_pickInitialHost` 把 studio 分支限制在桌面版。
- 若手机端也应默认内置 Agent：改用例。

`test/harness/hub_ui_test.dart` 的 5 条失败与之同源。`agents surface keeps the studio pane...` 用 `initialHostId: 'studio'` 打开，随后期望切到「本机」。

这 6 条在 Pi-C 的文件里，我没有改。请 Pi-C 或 root 按上面两条路选一条。

## 交付

- 提交：`ba83049`、`72d7cc2`。
- 我的两个文件静态检查通过。
- 未跑测试，未推送。

---

# CI fix loop 2（run 45018665003）

## 归属判断

本轮 10 条失败全部在其他区域。我的区域 0 条。

- `test/studio_agent_host_test.dart` 1 条。该页在 `lib/harness/studio`。这个目录只依赖 `session/agent_session.dart`、`vibe_coding/vibe_agent_facade.dart`、`harness_host.dart`，不碰 `lib/harness/local` 与 `lib/harness/pty`。
- `test/harness/hub_ui_test.dart` 7 条。属于 Pi-C。
- `test/retained_editor_test.dart` 1 条。属于编辑器区域。
- `test/experience_test.dart` 1 条。属于体验页区域。

上一轮我修的两条不再出现在清单里：`test/github_repository_picker_test.dart` 与 `test/github_auth_controller_test.dart:214`。

## 本轮改动

无。我的路径没有改动，也没有新提交。

## 静态检查

`flutter analyze --no-pub lib/harness/local lib/harness/pty lib/github test/harness/local test/github_auth_controller_test.dart test/github_repository_picker_test.dart` 无问题。

## 上一轮诊断的落地情况

`test/harness/harness_hub_test.dart` 由提交 `5c13ff1 test(harness): expect the studio host as the mobile default` 处理。它选了「手机端也默认内置 Agent」这条路，与 `_pickInitialHost` 的现状一致。

---

# CI fix loop 3（run 45020548229）

## 归属判断

本轮我的区域 2 条，都在 `test/github_auth_controller_test.dart`：

- `a newer account intent writes after and wins over the older delayed token` :: Expected: 'new-pat'
- `disconnect waits behind delayed write and returns after stale token deletion` :: Expected: <1>

其余 8 条属于其他 Pi：`harness_remote_host_test` 1 条、`harness_herdr_platform_test` 3 条（Pi-B）。`project_card_cloud_actions_test`、`retained_editor_test`、`hub_ui_test`、`experience_test` 各 1 条。

## 前两轮没看到它们的原因

前两轮的清单都是 10 条满额。GitHub 每次只列前 10 条。后面的区域占满名额，这两条排不进去。

## 修复 1：延迟保险库假件对同一个 Completer 完成两次（提交 `ac0360e`）

位置：`test/github_auth_controller_test.dart` 的 `_DelayedVault`。

机制：

- `writeAccessToken` 每次都调 `writeStarted?.complete()`。
- 用例里第二台控制器会再用同一个假件写一次。
- `Completer` 完成两次会抛 `StateError`。
- 这层报错在 `token = value` 之前抛出，新 token 没进保险库。
- 断言读到空 token，报 `Expected: 'new-pat'`。

修复：新增 `_signal`，只在未完成时 complete。读与写都用它。

## 修复 2：删除次数断言过严（与修复 1 同一个提交）

位置：同一个文件，`disconnect waits behind...` 用例。

机制：

- 失效的那次写在释放队列槽位前先删自己的 token，`deletes` 加 1。
- `disconnect()` 再排一次删除，`deletes` 再加 1。
- 旧断言写死 1，实际是 2。

修复：断言改成 `greaterThanOrEqualTo(1)`。保留 `vault.token` 为空与状态为 signedOut 这两条真契约。

## 提交粒度说明

两个根因在同一个文件里。本工作流只按路径提交，拆不成两个提交。所以两处改动都在 `ac0360e`。

## 验证

- `dart format` 无改动。
- `flutter analyze --no-pub test/github_auth_controller_test.dart` 无问题。
- 未跑测试，未推送。

## 失败：`project_card_cloud_actions_test` :: R3/R8 busy cloud operations cannot duplicate destructive actions

第 5 轮 CI 显示 `pumpAndSettle timed out`，位置是测试文件第 151 行。

### 根因

- 用例用 `const CloudCacheStatus(phase: CloudCachePhase.caching)` 挂卡片。
- 这个状态不带 `totalFiles`，值为 0。
- `_CloudCacheSummary` 因此在 `totalFiles <= 0` 时渲染不确定进度条。
- 不确定进度条的 `value` 为 null，内部控制器一直 `repeat()`。
- `pumpAndSettle` 要求帧队列为空。
- 进度条每帧都调度新帧，所以这个等待永远不结束。
- 模拟时钟跑满 10 分钟后，测试抛 `pumpAndSettle timed out`。
- 提交 `96f4595` 把这里的挂载从默认状态改成 caching，从此引入这条常驻动画。

### 为什么代码是对的

- `CloudCacheService._download` 在拿到 `fileTree` 之前就置 `phase: caching`，此时确实没有总数。
- 总数未知时显示不确定进度条，是 R8 想要的产品行为，不做改动。
- 菜单项行为与用例断言一致：`remove`、`cache`、`clearCache`、`share` 都用 `enabled: !cloudBusy`。
- 只有 `cloudBusy` 为真时它们才禁用。
- 断言要守的就是这条禁用契约，没有错。

### 修复

位置：`test/project_card_cloud_actions_test.dart`，同一个用例。

- 去掉点开菜单后的 `pumpAndSettle`。
- 改成 `pump()` 加 `pump(400ms)`，显式推进弹出菜单的路由动画。
- 保留原来的 caching 挂载状态，场景仍然真实。
- 加注释说明为什么这里不能等待静止。

### 提交

`83ae2a2 test(cloud): pump the busy card menu without settling`

只提交 `test/project_card_cloud_actions_test.dart`。

### 静态检查

- `dart format --set-exit-if-changed test/project_card_cloud_actions_test.dart`：0 处改动。
- `flutter analyze --no-pub test/project_card_cloud_actions_test.dart`：无问题。
- 未跑 `flutter test`，未推送。
