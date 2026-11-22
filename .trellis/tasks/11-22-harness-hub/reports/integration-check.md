# 集成复核：Harness Hub 合并结果

复核范围：

- core 工作树 `D:/MyNewProjects/_wt/harness/integration/qfli_studio_core`。
- core 分支 `harness/integration`，HEAD `92ab3cb`，基线 `f9b6485`。
- app 工作树 `D:/MyNewProjects/_wt/harness/integration/qflistudio`。
- app 分支 `harness/integration`，HEAD `4142a7d`，基线 `d31ad29`。
- 对照 `reports/final-review.md`、`prd.md`、`design.md`。
- 对照契约 `lib/harness/harness_host.dart` 与 `reports/check-a.md`。
- 对照 `reports/check-b.md` 与 `reports/pi-b.md`。

## 0. 方式与结论

方式：只读。读代码与 `git diff`、`git ls-files`、`Get-FileHash`。

只跑了两条静态检查。一条是 `flutter analyze --no-pub lib/harness`。另一条是 app 的 `flutter analyze --no-pub lib`。

未修改集成工作树任何文件。未跑测试、构建、模拟器或服务。

**结论：可以合并。** 没有阻断项。

合并内容完整。协议未变。主工作树没有改动。四条分支评审提到的功能缺陷都已修好。

剩下的问题是一条中等级别的资源扇出。另有三条低级别清理项。都可以合并后单独提交，不需要打回。

## 1. 合并正确性

### 1.1 我的分支内容完整进入

我把 Pi-B 交付的 18 个文件与 `harness/pi-b` 的 HEAD（`2115282`）逐个比对 SHA256。

全部逐字节一致。比对前先统一换行符，因为两边工作树的 `core.autocrlf` 状态不同。

```
lib/harness/pty/harness_pty.dart
lib/harness/herdr/{herdr,herdr_cli,herdr_host,herdr_input,herdr_models,
                   herdr_platform,herdr_platform_io,herdr_platform_stub,
                   herdr_session,herdr_terminal}.dart
lib/harness/remote/{remote_harness,remote_harness_host,remote_mapping,
                    remote_ports,remote_session,remote_terminal}.dart
lib/remote_control/state/session_view.dart
```

`54ca0d2` 合的是我的 `2115282`，也就是修复后的版本。不是修复前的 `09df701`。

我抽查了六处修复标记，全部命中：

| 我的修复 | 集成里的位置 |
| --- | --- |
| H1 远程终端旁路 | `remote_terminal.dart:41-51` 与 `session_view.dart:49-70` |
| H1 旁路重放 | `session_view.dart:198-201` |
| M2 死句柄 | `herdr_host.dart:191`、`remote_harness_host.dart:172,253` |
| M3 输入串行 | `herdr_terminal.dart` 的 `_pending` 与 `_draining` |
| M4 宿主 id | `remote_harness_host.dart:37,46` |
| M5 单等待 | `herdr_host.dart:401` 的 `busy.first` |
| L3 与 L6 | `herdr_host.dart:163` 与 `297` |

### 1.2 四条的评审意见都已落地

check-b 对 Pi-C 有 8 条发现。我在集成树里逐条检查：

| 编号 | 状态 | 证据 |
| --- | --- | --- |
| #1 高 停止绕过确认 | 已修 | `hub_session_view.dart:186` 转给 `_confirmStop()` |
| #2 中 提示类型不兼容 | 已修 | `harness_hub.dart:20` 的 `Object?` 加 `harnessHintText()` |
| #3 中 设备页控制器泄漏 | 已修 | `devices_remote_page.dart:80-88` 补 `mounted` 检查 |
| #4 中 对话视图不重绑 | 已修 | `hub_chat_view.dart:71-81` 的 `didUpdateWidget` |
| #5 低 启动不切当前主机 | 已修 | `harness_hub.dart:386` |
| #6 低 终端视图死字段 | 已修 | `hub_terminal_view.dart:115-120` 的 `_decoder` |
| #7 低 内置 Agent 会话重复 | 已修 | `hub_session_list.dart:372` 跳过 studio 主机 |
| #8 低 构造即订阅 | 未修，见 F1 | `harness_hub.dart:138` 构造里就 `_attachHost` |
| #9 备注 释放语义 | 已修 | `ownsHosts`（134）与 `hostBuildError`（`harness_hosts.dart:96`） |
| #10 备注 测试缺口 | 大部分已补 | `hub_ui_test.dart:340` 有停止确认用例 |

### 1.3 冲突解决

文件级冲突为零。四条分支改的文件不相交。五处语义冲突的解法我逐条看过，判断都成立。

1. **`HubHostContext` 补字段**：新增 `runtime`、`projectId`、`signedIn`、`desktop`。内置 Agent 主机确实需要运行时与项目 id。用可选参数表达“这一页不开内置 Agent”是合适的。
2. **PTY 适配器**：`StudioMuxPtyFactory` 把 `PtyLauncher` 包成 `HarnessPtyFactory`。`allocatesTerminal == false` 时抛 `HarnessPtyException`，让 Herdr 退到快照终端。这正是 `pi-b.md` §10.2 建议的形状。`_ownsLauncher` 的所有权语义也写对了。
3. **异步远程主机**：`OwnedRemoteHarnessHost` 把 `RemoteController` 与 `HerdrController` 的所有权收在一处`dispose()`。`RemoteHarnessHost` 自己只摘监听，端口由调用方提供。谁持有谁释放。
4. **默认主机改成内置 Agent 优先**：桌面端原来默认本机，会让 Agents 面板一开就是空的。现在按 studio、local（仅桌面）、remote 的顺序挑。测试断言同步改了（`harness_hub_test.dart:106,125`）。
5. **装配入口唯一**：`registerDefaultHarnessHosts()` 在 `runApp` 之前调一次。编辑器页仍只调 `harnessHubFor(...)`。

### 1.4 未发现的问题

- 全仓 `lib` 与 `test` 无冲突标记。
- 新增代码里没有 `TODO`、`FIXME`、`HACK`、`XXX`。
- 没有 `print(`。只有两处 `debugPrint`，见 F4。

## 2. 协议与契约兼容性

| 检查项 | 结果 |
| --- | --- |
| 契约文件 | 与基线 `f9b6485` 逐字节一致 |
| 契约 diff | `git diff` 为空，四条分支都没动它 |
| 远程控制改动面 | 只有 `state/session_view.dart` 一个文件（+68 行） |
| 旁路内容 | `terminalLog`、两个监听接口、`eventRevision` |
| wire 协议 | 未改，请求 id 与重连逻辑零改动 |
| 重放语义 | 只多了一次清屏通知，属于显示层 |
| 新增依赖 | 无，`pubspec` 两个仓都没改 |
| 旧远程入口 | `RemoteComputerPage` 未改，存储格式未变 |
| 凭据 | 新代码不打印 token 或 secret |

平台插件注册文件是 `flutter pub get` 留下的脏状态。app 工作树有 7 个 `generated_plugin_registrant*`。`git diff --numstat` 全为 `0 0`，只有换行符差异。与 `final-review.md` 风险 9 一致，不构成改动。

## 3. 主工作树没有改动

| 工作树 | 分支与 HEAD | 是否含本任务改动 |
| --- | --- | --- |
| `D:/MyNewProjects/qfli_studio_core` | `main`、`573d1b6` | 没有，`lib/harness` 整个目录不存在 |
| `D:/MyNewProjects/qflistudio` | `main`、`fd50419` | 没有，`lib/main.dart` 改动属于另一条任务 |

主 core 树里 `git ls-files lib/harness` 为空。

主 app 树的 `lib/main.dart` 有未提交改动。内容是 `interop_background_transport` 与 `backgroundInteropRunner`。不含 `harness`、`registerDefaultHarnessHosts`、`studioAppServices`。

本任务在 app 主工作树只写了 `.trellis/tasks/11-22-harness-hub/` 下的报告与任务文件。

## 4. 静态检查

### core

```text
flutter analyze --no-pub lib/harness lib/pages/devices_remote_page.dart
→ 1 issue: info unnecessary_import @ lib/harness/harness_host.dart:6:8
```

这一条是基线既有的。契约文件按约定保留。

另两条 `lib` 全量 info 在 `chat/composer_card.dart`，不在本次作用域。

### app

```text
flutter analyze --no-pub lib
→ 1 issue: info unnecessary_import @ lib/main.dart:3:8
```

这一条也是基线既有的。

分析器跑完后两个工作树都没有新增脏文件。插件注册文件除外，见 §2。

## 5. 发现清单

### F1（中）每页一套主机，构造即订阅，面板常挂

**现象**：打开一个项目就会同时起四条后台链路。用户没看过 Agents 面板也照起。

链路：

1. `default_harness_hosts.dart:47` 的工厂每次都创建新实例。三台主机各一份。
2. `harness_hub.dart:138` 的构造函数对每台主机直接 `_attachHost`。`_attachHost`（485-492）立刻订阅 `watchSessions()`。
3. 三台主机的 `watchSessions()` 都会启动后台循环。

三条循环分别是：

- `LocalHarnessHost` 起 `Timer.periodic`，默认 20 s（`local_harness_host.dart:225`）。每轮扫日志目录。
- `HerdrHost` 空闲时每 30 s 跑一次 `herdr agent list`。有 agent 工作时每轮起一个 `herdr agent wait`，预算 20 s。
- `RemoteHarnessHost` 起 Codex 目录轮询定时器，默认 20 s（`remote_harness_host.dart:110-127`）。

4. `hub_agents_surface.dart:57` 的 `initState` 立刻 `unawaited(_attachRemoteHost(opener))`。`opener` 就是 `openRemoteHarnessHost`。它会 `RemoteStore.open()` 并 `RemoteController..connect()`，也就是一条 WebSocket。
5. 面板放在 `Offstage` 里常挂。`editor_page.dart:3737` 组出 `agentPane`，`:3880` 交给 `_buildAgentDockStack`。`Offstage` 只跳过绘制，Element 照样挂载，`initState` 照样跑。

**放大**：`RetainedEditorHost` 会保活多个编辑器页。同时开 5 个项目就是 5 套主机。也就是 5 条 WebSocket、5 个 Herdr 轮询、5 个日志定时器。

Windows 上一次 `agent wait` 就是一次进程启动，约 50 到 200 ms。5 份同时跑时用户会看到明显的 CPU 占用与风扇声，而界面上什么都没做。

**建议**（三选一）：

1. **懒订阅**：`_listen` 延迟到首次需要该主机。切换主机或读该主机会话时再拉起。切走不取消。
2. **应用级共享主机**：`buildDefaultHarnessHosts` 返回缓存实例，hub 传 `ownsHosts: false`。退出时统一 `await` 一次。`RemoteHarnessHost` 尤其适合这样。
3. **远程连接延后**：`HubAgentsSurface` 不在 `initState` 开远程。改成第一次切到 remote 主机时再 `openRemoteHarnessHost()`，并显示“正在连”。

推荐 1 加 3。1 解决三台本机主机的空转。3 解决没配对也开 WebSocket 的问题。

### F2（低）`StudioMuxPtyFactory` 从不释放

`HerdrHost.dispose()`（`herdr_host.dart:264-277`）只释放 `_runner`。`_ptyFactory` 没有释放。

`default_harness_hosts.dart:63` 传进去的是 `StudioMuxPtyFactory()`。它的 `dispose()`（`studio_mux_pty.dart:70-78`）会释放自己惰性创建的 `PtyLauncher`。后者持有 `ProcessSupervisor` 与全部子进程订阅。

同分支另外两处都做对了。`LocalHarnessHost.dispose()`（`local_harness_host.dart:514`）有 `if (_ownsLauncher) await _launcher.dispose()`。`OwnedRemoteHarnessHost.dispose()` 释放控制器。只有 Herdr 这条有缺口。

实际影响有限。PTY 子进程在 `HerdrPtyTerminal.close()` 里已 `kill()`。漏掉的是 `ProcessSupervisor` 与 `PtyLauncher` 的对象图，每页一份，可交给 GC。

**建议**：`HerdrHost` 增加 `ownsPtyFactory` 或 `onDispose` 回调。也可以包一层 `OwnedHerdrHost`，与 `OwnedRemoteHarnessHost` 对称。

### F3（低）释放链路不等结果，退出时可能留下孤儿进程

三层都用了 `unawaited`。`HarnessHub.dispose()`（`harness_hub.dart:524`）不等主机。`HerdrSessionHandle.dispose()`（`herdr_session.dart:113-119`）不等终端关闭。

正常退出没问题。进程会在几毫秒内自己消失。但应用直接退出时（关窗、任务管理器、`Alt+F4`），Dart 侧不保证这些 future 跑完。`herdr agent attach` 的子进程可能变成孤儿，占着 pane 的独占 attach。

这类残留会表现为提示“pane 占用中”。用户很难自己诊断。

**建议**：`HarnessHub` 加 `Future<void> shutdown()`。内部 `await` 全部主机与句柄释放。由 `main()` 的退出钩子 `await` 一次。`dispose()` 保持同步语义。

### F4（低）`openRemoteHarnessHost` 的日志没有 debug 守卫

`default_harness_hosts.dart:73` 直接 `debugPrint` 错误与完整堆栈。

同文件兄弟在 `harness_hosts.dart:105-110`，写法是 `assert(() { ...; return true; }())`。release 下不打印。

这里漏了守卫。release 版会把错误与堆栈打到日志。不涉及凭据，但属于发布版噪声，也与兄弟写法不一致。

**建议**：改成同样的 `assert` 包裹，或 `if (kDebugMode)` 判断。

### F5（备注）只支持一台已绑定电脑

`RemoteStore.pairing` 是单个 `Pairing?`（`remote_store.dart:100`）。所以 `openRemoteHarnessHost()` 最多产出一台 `remote:` 主机。

设备页可以对多台电脑做配对。Agents 面板只挂当前那一台。这是既定范围，`remote_control` 的存储模型本来就这样。记录在此，以免当成合并缺陷。

### F6（备注）`studioAppServices` 是 app 层的可变全局

app 的 `studio_tools_tab.dart:14` 声明，`lib/main.dart:79` 赋值。注释写明“其它产品不设置这些字段，也就看不到这个入口”。

可接受。但它是隐式契约。将来第二个 `main` 忘了赋值，Agents 卡片只会退化成兜底页。

**建议**：在文档注释里点明“由 `main()` 负责赋值”。或在入口里加 `assert(services != null)`，让 debug 版早暴露。

## 6. 与 `final-review.md` 风险表的对照

| 风险 | 我的判断 |
| --- | --- |
| 1 没有真实终端 | 认同，这是 AC1 与 AC3 的唯一硬缺口 |
| 2 远程一页一条连接 | 认同，并升级为 F1，范围更大 |
| 3 内置 Agent 会话重复 | 已用“跳过 studio 主机”解决 |
| 4 attach 依赖真实终端 | 认同，等同风险 1 |
| 5 BusyBox 兼容性 | 认同，属真机验收项 |
| 6 日志字段未检查 | 认同，读取器返回空表，不易诊断 |
| 7 单测没跑过 | 认同，我这边同样没跑 |
| 8 规范漂移 | 认同，需要 root 合并后同步 |
| 9 插件注册文件脏状态 | 已核实是换行差异 |

## 7. 未验证项

- 没有跑 `flutter test`。所有测试结论都是静态读代码得出。
- 没有真机、模拟器、真实 Herdr 服务、真实 relay。AC1、AC2、AC3、AC6、AC7、AC8 的真机部分仍未验证。
- F1 的开销是代码推理。没有做进程或内存采样。
- F2 的泄漏量是推理。没有做 heap 对比。
- 没有验证多项目并发时的 WebSocket 实际条数。

## 8. 建议的处理顺序

1. 合并。没有阻断项。
2. 合并后单独提一个提交做 F1。它决定同时开多个项目时的可用性。
3. F2 与 F3 一起做。给主机加统一的所有权与 `shutdown()` 约定。
4. 云端 CI 跑 core 与 app 的 `flutter test`。然后按 `final-review.md` §7 走真机验收。

## 9. 修复阶段（integration 分支）

本节记录 §5 四条发现的修复。提交都在 core 仓的 `harness/integration` 上。

一条发现一个提交。全部用显式路径 `git add`。没有 merge、reset、stash 等操作，也没有 AI 署名。

| 提交 | 标题 | 覆盖 |
| --- | --- | --- |
| `1340b40` | 会话懒订阅与远程按需连接 | F1 |
| `48e0ae7` | Herdr 主机释放注入的 PTY 工厂 | F2 |
| `86380c7` | 退出前等待主机释放完成 | F3 |
| `65eb461` | 发布版不打印远程装配错误 | F4 |
| `242a2ae` | 远程占位芯片在连上后隐藏 | F1 收尾 |

最后一条是写界面用例时发现的边界。远程主机挂上之后占位芯片还在，同一台电脑会多出一个入口。

它属于 F1 的行为。但 `1340b40` 已在历史中间，补在顶端比改写历史干净。

### 9.1 F1（中）订阅与远程连接改成按需

两条建议都做了。

**建议 1：主机会话懒订阅**（`harness_hub.dart`）

- 新增 `_listening` 集合、`ensureListening(hostId)` 与 `isListening(hostId)`。
- 订阅点从 `_attachHost` 挪到这里。构造时只订阅 `_pickInitialHost` 选中的那一台。
- 其余入口：`selectHost`、`addHost`、`openSession`、`launch`、`refresh`。
- `addHost` 只在它成为当前主机时才订阅。
- `refresh` 只刷新已订阅的主机。
- 切走不取消。来回切不该反复重拉历史。
- 语义变化已写进注释。`allSessions` 现在只含已订阅的主机。界面只读当前主机的会话（`hub_session_list.dart:293,375`），所以显示效果不变。

**建议 3：远程主机首次点击才连**（`hub_agents_surface.dart` 与 `hub_host_switcher.dart`）

- 删掉 `initState` 里的 `unawaited(_attachRemoteHost(opener))`。
- 状态改成 `_openRemote()` 加两个标记：`_remoteConnecting` 与 `_remoteUnavailable`。
- 主机条新增一枚“已绑定电脑”占位芯片，key 是 `hub-host-pending-remote`。
- 点了才去 `openRemoteHost()`。连接中画成“连接中…”，并且禁用点击。
- 另有一行说明，key 是 `hub-remote-connecting`。
- 连上后 `addHost` 再 `selectHost`。用户点名的电脑直接成为当前主机。
- 没配对时芯片保留。再点转去配对页，也就是 `onAddComputer`。
- 一台可见主机都没有时（手机端未配对），主机条原本整块不画。现在补了一行，用户能找到“添加电脑”。
- 已有一台已绑定电脑在列表里时，占位芯片不画（`242a2ae`）。

**测试**

- `harness_hub_test.dart` 新增 4 条。[1]

[1] 四条分别是：首屏只订阅当前主机。刷新不唤醒未访问主机。访问过的每台合并成一张表。`shutdown` 等待释放完成。

- `hub_ui_test.dart` 新增 2 条。[2]

[2] 两条分别是：挂载不连接、点击进入连接中、连上后切换。失败时转去配对。

同时修了 6 条旧断言。这些断言本来就会失败。

它们仍按“默认主机是本机”写。断言对象是 `currentSessions`、`launchMenu`、`sessionsOf('local')`。

集成分支早把默认主机改成内置 Agent（`_pickInitialHost`，`harness_hub.dart:549`）。这些用例从那次改动起就没跑过。与本次改动无关，但同文件，一起改成先 `selectHost('local')` 再读。

### 9.2 F2（低）PTY 工厂的释放

- `HerdrHost` 新增可选参数 `disposePtyFactory`，类型是 `Future<void> Function()?`。
- `dispose()` 末尾调用它。失败不阻断其它收尾。
- `default_harness_hosts.dart` 先建一个 `StudioMuxPtyFactory` 变量。同时传给 `ptyFactory` 与 `disposePtyFactory: pty.dispose`。
- 与 `LocalHarnessHost` 的 `_ownsLauncher`、`OwnedRemoteHarnessHost` 的控制器所有权写法一致。
- 测试两条：`dispose` 会释放注入的工厂。工厂抛错时主机仍然释放完成。

没有改 `HarnessPtyFactory` 契约本身。它是共享接口，加方法会破坏所有实现。改用回调传“谁来放”。

### 9.3 F3（低）可等待的退出收尾

- `HarnessHub.shutdown()` 返回 `dispose()` 发起的那组清理。可重复调用。
- `dispose()` 语义不变。同步、幂等，只是把释放 future 存进 `_shutdown`。
- 新增 `HarnessHub.shutdownOpenHubs()` 与静态 `_openHubs` 登记表。退出钩子一次收尾所有活着的 hub。
- `HerdrSessionHandle.dispose()` 由 `void` 改成 `Future<void>`。不再 `unawaited(_terminal.close())`。
- `HerdrHost.dispose()` 逐个 `await`。这才是真正等到 attach 客户端结束的地方。
- 退出钩子接在 `lib/app.dart`。`_QfliAppState` 注册 `AppLifecycleListener(onExitRequested: ...)`。里面对 `shutdownOpenHubs()` 求值后再返回 `AppExitResponse.exit`。
- 手机端不会走这条路径，因为没有本机子进程。
- 测试两条：`shutdown()` 会等到主机释放真的跑完。`shutdownOpenHubs()` 释放所有活着的 hub。

### 9.4 F4（低）发布版日志

`default_harness_hosts.dart` 的 `debugPrint` 包进 `assert(() { ...; return true; }())`。

写法与 `harness_hosts.dart:106-109` 一致。发布版不再把错误与堆栈打到日志。

### 9.5 自动文件的处理

app 工作树里 7 个 `generated_plugin_registrant*` 的脏状态没有提交。

理由有两条。`git diff` 内容为空，`--numstat` 全是 `0 0`，只有换行差异。本分支也没改过 `pubspec.yaml` 与 `pubspec.lock`，相对基线 `d31ad29` 为空。

所以它们不反映本分支新增的依赖。属于 `flutter pub get` 造成的既有噪声。

### 9.6 静态检查与测试

```text
core  dart format <9 个改动文件>        → 0 changed
core  flutter analyze --no-pub lib test → 2 个既有 info
app   flutter analyze --no-pub lib      → 1 个既有 info
```

core 的两条 info 是 `chat/composer_card.dart:346` 与 `harness/harness_host.dart:6`。app 的一条是 `main.dart:3`。都是基线既有。

没有新增告警。契约 `harness_host.dart` 仍未改动。`lib/remote_control` 与 `pubspec` 也没有动。

按简报没有在本地跑测试。本次新增或改写的用例共 8 条，交给云端 CI。

### 9.7 未验证与遗留

- 退出钩子只在桌面端有效。Windows runner 是否触发 `onExitRequested`，`Alt+F4` 与系统关机两条路径是否都走到，需要真机确认。
- 懒订阅后 `allSessions` 的覆盖面变小。已写进文档注释。当前没有界面用它。以后要做“全部会话”页，得先对每台 `ensureListening`。
- F5 与 F6 按要求未处理。
