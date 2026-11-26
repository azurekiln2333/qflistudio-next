# CI 卡死排查：Agents hub 与界面

范围：`lib/harness/hub`、`lib/harness/ui`、编辑器页的 Agents 接线、
`test/harness` 的 hub 与界面测试。

分支：`harness/integration`
工作树：`D:/MyNewProjects/_wt/harness/integration/qfli_studio_core`

## 结论

找到三个真实根因，全部在测试侧，均已修复。

1. `pumpAndSettle()` 碰上永远转圈的指示器。25 处调用，每处都要耗满 10 分钟
   兜底超时才报错。
2. hub 的收尾走一张进程级全局表。用例中途失败会把 hub 留在表里，下一个用例
   等一次永不完成的释放。widget 测试的默认超时是 `Timeout.none`，进程就卡住。
3. 一处 `expect` 没有 await，异步断言挂在后台。

按源文件看，`lib/harness/hub` 与 `lib/harness/ui` 里没有 `Process.start`、
`Timer`、`Future.delayed`、`Stream.periodic` 或家目录扫描。卡死来自测试的等待
方式，不是被测代码偷偷起了真实资源。

## 根因 1：`pumpAndSettle()` 永远等不到静止

`test/harness/hub_ui_test.dart`（修复前 25 处，行号 181、184、188、192、194、
211、214、231、239、253、264、267、307、371、411、435、447、452、456、466、
475、483、493、549、628）。

`pumpAndSettle()` 的语义是“一直抽帧，直到没有新帧被调度”。Agents 面板有三处
不确定进度的转圈，它们每帧都请求下一帧：

| 转圈来源 | 何时出现 |
| --- | --- |
| `lib/harness/ui/hub_status.dart:69` | 会话状态是 `working`（列表行与会话页头都画） |
| `lib/harness/ui/hub_session_view.dart:148` | 会话还在打开，`_handle == null` |
| `lib/chat/composer_card.dart:535` | 输入卡片正在发送 |

测试夹具 `l1` 的状态就是 `working`，所以每个用到 `HubSessionView` 的用例都
带着转圈。

超时预算：`packages/flutter_test/lib/src/widget_tester.dart:699` 里
`pumpAndSettle` 的默认 `timeout` 是 10 分钟（模拟时钟）。10 分钟的帧跑下来
是几千次 build 与 paint，25 处叠加，整套测试就成了“跑不完”。

修复：新增 `_settle(tester)`（`test/harness/hub_ui_test.dart:38`），推进 10 帧、
每帧 60 毫秒，25 处全部改用它。600 毫秒足够走完对话框这类有限动画，界面状态
改由 `expect` 断言。文件头补了原因，避免以后又被加回来。

提交：`5e4cd56 test(harness): pump a fixed number of frames instead of settling`

## 根因 2：全局 hub 表 + 无上限收尾

`lib/harness/hub/harness_hub.dart:206` 有一张 `static final Set<HarnessHub>
_openHubs`；`shutdownOpenHubs()`（:212）逐个 `await hub.shutdown()`，不设上限。
`dispose()`（:571）把每个主机的 `dispose()` 收进 `_shutdown`。

单个用例本身没问题，问题在失败路径：

- `test/harness/harness_hub_test.dart`（修复前 :531）的 `_SlowDisposeHost`
  用 `Completer` 卡住 `dispose()`，由用例末尾手动放行。
- 若该用例前面的断言先失败，`hub.dispose()` 不再执行，hub 留在 `_openHubs`
  里，门也没开。
- 下一个用例的 `shutdownOpenHubs()` 于是等这一次永不完成的释放，而
  `packages/flutter_test/lib/src/binding.dart:2434` 把
  `defaultTestTimeout` 设成 `Timeout.none`，没有兜底。

结果不是“一个用例失败”，而是整个文件挂住，直到 CI 超时取消。这与观察到的
45 分钟被取消一致：失败被转成了挂起。

修复：

- 新增 `trackHub(hub)`（`test/harness/harness_hub_test.dart:95`），所有 hub
  统一登记兜底释放，30 秒等不到就直接 `fail`。
- `_SlowDisposeHost.finishDispose()` 改成幂等，并 `addTearDown` 注册
  （:451），失败路径也把门打开。
- 两个涉及门的用例加显式 `timeout: Timeout(Duration(seconds: 30))`
  （:465、:479）。

提交：`0506713 test(harness): bound hub teardown so a stuck host cannot hang the run`

## 根因 3：没有 await 的异步断言

`test/harness/harness_hub_test.dart`（修复前 :385）
`expect(hub.launchMenu(), completion(isEmpty));` 没有 await。`completion` 是
异步匹配器，断言挂在后台，失败时报到下一个用例头上；若这个 future 不完成，
它就一直挂着。

修复：改成 `await expectLater(...)`（:409）。

同上提交。

## 静态审查后确认干净的部分

- `test/support/fake_harness_host.dart`：只有广播 `StreamController` 和
  `Completer`，没有定时器、没有 IO、没有真实进程。`watchSessions()` 的
  `onListen` 只回放当前列表，不递归。
- `test/harness/*`：没有 `Future.delayed`、`Timer`、`sleep`。等待只用
  `pumpEventQueue()`，它有固定轮数。
- `lib/harness/ui`：只有 `AnimatedBuilder` 监听 `hub`，以及一个
  `addPostFrameCallback`（`hub_chat_view.dart:107`，滚到底部，触发一次）。
  没有 `AnimationController.repeat()`。
- `vendor/xterm` 的 `TerminalView`：只在键盘弹出时补一个 post-frame 回调
  （`terminal_view.dart:435`），没有光标闪烁定时器。
- 编辑器页接线：`EditorPage.initState`（`lib/editor/editor_page.dart:455`）
  在每次测试里都会建一个 hub，但 `HarnessHosts` 没有注册工厂时主机列表为空，
  面板只剩静态行，没有转圈。`_harnessHub` 在 `dispose`（:934）释放。
  `_openHubSession`（:2016）用 `try/catch` 包住打开动作，不会留下未捕获的
  异步错误。

## 关于全局限时（`dart_test.yaml`）

`dart_test.yaml` 已由另一个 agent 提交（`09caa6d`），内容是全局
`timeout: 2m`，注释把原因写成“`testWidgets` 默认 10 分钟、`test()` 默认
30 秒”。两点要纠正，免得以后只靠它兜底：

1. `test()` 的默认 30 秒成立；`testWidgets` 不是 10 分钟。
   `widget_tester.dart:204` 取的是 `binding.defaultTestTimeout`，而
   `binding.dart:2434` 把它设成 `Timeout.none`。`test_api` 的
   `Timeout.none` 文档写的是“测试永不超时”。10 分钟是 `pumpAndSettle`
   自己的兜底，不是用例限时。
2. 因为 `testWidgets` 显式传了 `Timeout.none`，`dart_test.yaml` 的 `2m`
   只作用于普通 `test()`，对 widget 测试无效。它盖不住本报告里的
   根因 1。

本轮修复不依赖它：转圈处改成固定帧数，收尾处自带 30 秒兜底。

## 未修复、需要上游决定的风险

1. `HarnessHub.shutdownOpenHubs()` 在生产退出钩子里逐个 `await`，无上限。
   一台主机的 `dispose()` 卡住（例如 `herdr agent attach` 的终止信号没回来），
   应用退出就跟着卡住。测试侧已用兜底超时挡住；产品侧要不要加超时，属于
   语义取舍：超时会让子进程变成孤儿，正是 `harness_hub.dart:594` 注释里想
   避免的情况。建议由根分支决定，本轮不改。
2. `registerDefaultHarnessHosts()`（`lib/harness/hub/default_harness_hosts.dart:27`）
   目前**没有调用方**，应用启动时没有装配真实主机。一旦接线，任何在同
   isolate 里注册过工厂的测试再建编辑页，就会真的构造 `LocalHarnessHost`
   与 `HerdrHost`（扫描家目录、起 `herdr`、1.5 秒轮询快照）。测试要用真实
   主机请走 `HarnessHosts.overrideForTesting`，并在 tearDown 里还原。
3. `HubAgentsSurface._openRemote()`（`lib/harness/ui/hub_agents_surface.dart:101`）
   对 `opener()` 没有超时。`RemoteStore.open()` 若卡住，占位芯片会一直显示
   “连接中…”且不可点。那里没有转圈，不会造成测试挂起，但界面变成死路。

## 验证

只做静态检查，没有跑 `flutter test`、构建或模拟器（brief 规定）。

- `flutter analyze --no-pub test/harness` → 无问题。
- `flutter analyze --no-pub lib/harness` → 1 条既有 info：
  `lib/harness/harness_host.dart:6` 的 `unnecessary_import`。该文件是冻结契约，
  不属于本分支可改范围。
- `dart format` 没有执行。这个 fork 的格式化器会把与本任务无关的文件整体
  重排（此前重写过冻结契约），收益不抵风险；改动的两处按现有风格手写。

## 提交清单

| 提交 | 内容 |
| --- | --- |
| `5e4cd56` | 界面测试改用固定帧数推进 |
| `0506713` | hub 收尾加兜底超时与幂等门，补上未 await 的断言 |

只提交了自有的两个测试文件。工作树里其他 agent 的改动没有碰：
`lib/harness/herdr/herdr_host.dart`、`lib/harness/remote/remote_harness_host.dart`、
`lib/harness/local/local_harness_host.dart`、`lib/trellis/trellis_context.dart`、
`test/harness_herdr_host_test.dart`、`test/harness_remote_host_test.dart`、
`test/trellis_context_test.dart`、`test/harness/local/local_harness_host_test.dart`、
`dart_test.yaml`（后由 `09caa6d` 提交）。
---

# CI 修复轮次 1（run 45014758649，core `54bbfe6`）

失败清单见 `ci-failures-1.md`。属于本范围的 6 条，另 1 条编辑器用例。

先说明诊断条件：CI 注解只带 `error` 的第一行。`testWidgets` 的失败统一走
`reportTestException`（`flutter_test/src/test_exception_reporter.dart:40`），
注解里只剩「Test failed. See exception logs above.」，真实异常只在控制台。
所以下面每条结论都注明是「代码可证」还是「按代码路径排除后剩下的唯一可能」。

## 修复 1：编辑器会话列表的空态被挤掉（`test/editor_agent_embed_test.dart`）

位置：`lib/editor/agent/session_list_view.dart:58`。

`extra` 是为「其它主机的会话」新加的插槽，编辑器页每次都传一个
`HubSessionListSection`。空态的判断写的是 `sessions.isEmpty && extra == null`，
`extra` 永远非空，于是内置会话为空时画的是 `ListView` 而不是 `_buildEmpty`：

- 「还没有会话」和「新会话」按钮都不见了，只剩一张空白卡片。
- 用例 `空会话列表给出说明和主操作` 找 `还没有会话` 与 `session-empty-create`，
  两个都找不到。

这不是用例写错。真实用户在没有会话的侧边栏里也看不到新建入口。

修复：空态改成同一个列表的第一项，外部会话段排在它后面。`_buildEmpty` 是
`Center`，在无界高度里会收缩到内容高度，放进 `ListView` 是安全的。

提交：`609e3de fix(editor): keep the session empty state when external sessions are wired`

## 修复 2：手机端默认主机（`test/harness/harness_hub_test.dart`）

位置：`test/harness/harness_hub_test.dart:159`。

用例要求 `currentHostId == 'remote-pc'`。`_pickInitialHost`
（`lib/harness/hub/harness_hub.dart` 内）现在优先返回内置 Agent 主机，
手机端也一样，所以实际是 `'studio'`。

两边只能对一个：

- `desktop keeps every host and opens on the studio one` 已经写明默认落在内置
  Agent，这是 `92ab3cb` 的意图（面板默认显示内置 Agent）。
- 没有任何地方要求手机端默认停在已绑定电脑。

所以是用例的期望过期了，不是代码退步。同一用例上一行已经断言主机列表是
`['studio', 'remote-pc']`，它本来要证明的是「本机与 Herdr 被平台过滤掉」。

修复：期望改成 `'studio'`，并补注释说明默认选中规则。

提交：`5c13ff1 test(harness): expect the studio host as the mobile default`

## 修复 3：会话视图第一帧停在转圈（`test/harness/hub_ui_test.dart` 5 条）

位置：`lib/harness/ui/hub_session_view.dart:44`（`initState`）、`:66`（`_open`）。

这 5 条的共同点是都挂 `HubSessionView`：`stopping…`、`closing…`、`chat tab…`、
`approval…`、`agents surface…`。其余用例（包括只挂 `HubChatView` 的
`chat view rebinds…`）不在清单里。

代码路径上的问题有两处：

1. `initState` 一律走异步打开。即使 hub 已经持有这个会话的句柄（这些用例都在
   用例体里先 `openSession` 过），第一帧也只能画转圈，页头、标签、输入卡片
   要等 `openSession` 的 future 落地后才出现。用例一旦在这之前点
   `hub-session-stop` / `hub-session-close` / 输入框，就只能点空。
2. `_open()` 在 `initState` 里同步调 `setState`。第一帧本来就还没有内容，
   这次重建是多余的；它发生在父级 build 期间，属于最容易被框架断言拦住写法。

修复：

- 新增 `_adoptActiveHandle()`：hub 的 `activeHandle` 与传入会话的
  `id`/`hostId` 一致时直接取用，第一帧就画出完整视图；`didUpdateWidget`
  换会话时也先走它。
- `_open()` 只在确实需要清旧状态（`_error != null || _handle != null`）时才
  `setState`，首帧不再重建。

这一条是本轮唯一不能百分百钉死的：注解里读不到真实异常。已按代码路径逐项排除
后只剩上面两处：`openSession` 复用分支确实存在（`harness_hub.dart:384`），
`closeActiveSession` 的 `notifyListeners` 有 `_disposed` 保护，`_scrollToEnd`
有 `hasClients` 保护，`FakeHarnessHost` 与 `test/flutter_test_config.dart`
在本轮都没有变化。

提交：`a458e86 fix(harness): adopt an already open hub session on the first frame`

## 修复 4：用例在视图还挂着的时候释放 hub

位置：`test/harness/hub_ui_test.dart`（上述 5 条）。

5 条用例都在用例体末尾直接 `hub.dispose()`，此时 `HubSessionView` 还在树上。
`HarnessHub` 是 `ChangeNotifier`，被释放后再被触碰会抛
`FlutterError: A HarnessHub was used after being disposed.`，而
`testWidgets` 的拆树发生在用例体之后。释放时机应该晚于拆树。

修复：改用 `addTearDown(hub.dispose)`（`agents surface…` 里 `studio` 同样处理），
断言不变。

提交：`d061253 test(harness): let the hub outlive the widget tree in session view cases`

## 静态检查

- `flutter analyze --no-pub test/harness lib/harness/ui lib/editor/agent`：无问题。
- 未跑 `flutter test`，未跑构建。

## 归属说明

本轮不属于我的 4 条没有碰：`test/experience_test.dart`、
`test/trellis_context_test.dart`（Pi-C 范围）、`test/github_repository_picker_test.dart`
（Pi-A 范围）。只提交了自己改的 4 个路径，工作树里其他人的改动没有动。

---

# CI 修复轮次 2（run 45018665003，core `d061253`）

失败清单见 `ci-failures-2.md`。注释接口能读到全部 10 条（`check-runs` 的
annotations 返回 11 条，含 GitHub 自己加的「Process completed with exit code 1」），
本轮失败的用例总数就是 10，没有被截断。

本范围的 7 条全部在 `test/harness/hub_ui_test.dart`。

## 定位方法

上一轮注解里只有「Test failed. See exception logs above.」，这轮失败清单里多了
`chat view rebinds when the handle changes`：它不挂 `HubSessionView`，所以问题
不在会话详情。数下来，失败的 7 条正好是**用例体里调用 `hub.openSession()`
的全部 7 条**，其余 10 条（主机条、会话分组、终端、按键栏等）全过。

共同点再缩小一层：这 7 条都在 `buildHub()` 之后**同步**读
`hub.sessionsOf('local').first`，作为 `openSession` 的实参。

## 根因 1：第一次会话快照还没到（6 条）

位置：`test/harness/hub_ui_test.dart`，6 处 `sessionsOf(...).first`。

`FakeHarnessHost.watchSessions()` 用的是普通（非 sync）broadcast 控制器：

```dart
StreamController<List<HarnessSessionInfo>>.broadcast(
  onListen: () => controller.add(_current),
);
```

`onListen` 里的 `add` 投递到**微任务**。`HarnessHub` 构造函数只订阅当前主机
（`ensureListening(current)`），所以 `buildHub()` 返回时 `_sessions` 还是空的。
用例体紧接着求值 `hub.sessionsOf('local')` → `const []` → `.first` 抛
`StateError('No element')`。异常发生在 `testWidgets` 里，注解被
`reportTestException` 折叠成通用文案，所以前两轮看不到。

同一轮里另外两条失败也正好是 `Bad state: No element`
（`studio_agent_host_test`、`experience_test`），是同一类「读空列表」问题。

修复：新增 `awaitSessions(tester)`，在 `buildHub()` 之后 `pump()` 一次把微任务
跑完，再读列表。6 处都补上。这是用例的问题，不是 hub 的问题：
`watchSessions()` 的契约不保证首次快照同步送达，真实主机（本机 / Herdr /
已绑定电脑）都是按自己的节奏推送。

提交：`2ab7d2e test(harness): wait for the host session snapshot before opening one`

## 根因 2：切主机后只推一帧（1 条）

位置：`test/harness/hub_ui_test.dart:337`（`agents surface keeps the studio pane…`）。

用例点「本机」后只 `await tester.pump()` 一次，随后就要点
`hub-session-local-l1`。切主机要等两件事落地：

1. `selectHost()` → `ensureListening()` 建立的订阅要收到首次快照；
2. `_HostEmptyState` 里的会话分组要等 `providersOf()` 返回后才画得出行。

一帧之后行还没出现，`tap` 找不到 key，用例在点空处结束。

修复：改用 `_settle(tester)`（10 × 60 毫秒），和其他用例一致。

提交：与根因 1 同一个提交。

## 不属于本范围、没有碰的 3 条

| 用例 | 归属判断 |
| --- | --- |
| `test/studio_agent_host_test.dart :: open and view publishes a system entry when the run fails` | 内置 Agent 主机，不在 `lib/harness/hub` / `lib/harness/ui` / 编辑器 Agents 接线范围内 |
| `test/retained_editor_test.dart :: live editor survives Home, tools, content and restore` | 考的是编辑器保留状态、滚动位置和工具页跳转，不涉及 Agents 面板；测试文件也不在 `test/harness` |
| `test/experience_test.dart :: 云端目录合并保留收藏，不重复追加已有项目` | 云端目录合并（Pi-C 范围），同样是 `Bad state: No element` |

`retained_editor_test` 的失败和 `42cfe8d`（把四台主机接进 hub）无关：该提交对
`lib/editor/editor_page.dart` 只加了三行参数和一行 `openRemoteHost` 回调，
回调只在用户点「已绑定电脑」时才执行；测试里没有这一步，也不注册主机工厂，
`harnessHubFor` 拿到的是空 hub。

## 静态检查

- `flutter analyze --no-pub test/harness lib/harness/ui lib/harness/hub lib/editor/agent`：无问题。
- 工作树干净，只提交了 `test/harness/hub_ui_test.dart`。
- 未跑 `flutter test`，未跑构建。

---

# CI 修复轮次 3（run 45020548229，core `2ab7d2e`）

失败清单见 `ci-failures-3.md`。本范围只剩 1 条：

`test/harness/hub_ui_test.dart :: agents surface keeps the studio pane until an external host is chosen`

上一轮的 6 条 `sessionsOf(...).first` 已经全绿，说明「首次会话快照是异步送来的」
这条根因判断成立。

## 根因：用例在一个不渲染会话列表的面板里点会话行

位置：`test/harness/hub_ui_test.dart`（该用例尾部）。

用例原来的流程是：切到「本机」→ 断言 `选择一个会话` → 点
`hub-session-local-l1` → 断言面板显示会话视图。问题在第三步：

`HubAgentsSurface` **不渲染会话列表**。它的 `build` 只有三选一：

- 内置 Agent 主机 → `widget.studioPane`；
- 其它主机且没有活动会话 → `_HostEmptyState`；
- 有活动会话 → `HubSessionView`。

`_HostEmptyState`（`hub_agents_surface.dart:397`）只画图标、一句说明和一个
新建入口，列表项不在这里。会话行由兄弟组件 `HubSessionList` /
`HubSessionGroups` 画（`hub_agents_surface.dart` 里没有引用它们），编辑器页是
把 `HubSessionList` 放在侧边栏、面板放在右栏。用例只挂了面板，所以
`hub-session-local-l1` 这个 key 在树上根本不存在，`tester.tap` 报
「No widget found」。

顺带确认：这条用例不是「面板应该自己带列表」。窄屏也走同一套
`HubAgentsSurface`，列表仍在侧边栏（抽屉）里，面板只负责详情。所以是用例
假设错了，不是界面缺功能。

修复：改成通过 hub 打开会话，再断言面板自己从空态切成会话视图：

```dart
await hub.openSession(hub.sessionsOf('local').first);
await _settle(tester);
expect(find.text('Claude 会话'), findsOneWidget);
expect(find.byKey(const ValueKey('hub-tab-0')), findsOneWidget);
```

用例仍然守住它名字里的承诺（内置 Agent 面板一直显示，切到外部主机才离开，
且打开会话后面板跟着切），只是不再假装面板里有列表。行点击这条路径由
`tapping a session row opens it through the hub` 覆盖，那条用例直接挂
`HubSessionGroups`，一直是绿的。

提交：`d2e478b test(harness): open the agent session through the hub instead of a row tap`

## 不属于本范围、没有碰的 6 条

| 用例 | 归属 |
| --- | --- |
| `test/harness_remote_host_test.dart :: Herdr panes on the paired computer replay snapshots and send keys` | 远端主机实现 |
| `test/harness_herdr_platform_test.dart` × 3（`executableOnPath`、`locateHerdrExecutable` × 2） | Herdr 平台探测 |
| `test/github_auth_controller_test.dart` × 2 | Pi-A |
| `test/project_card_cloud_actions_test.dart :: R3/R8 busy cloud operations…` | 云端操作 |
| `test/retained_editor_test.dart :: live editor survives Home, tools, content and restore` | 编辑器保留状态（与 Agents 面板无关，判断同上一轮） |
| `test/experience_test.dart :: 云端目录合并保留收藏…` | 云端目录合并 |

工作树里 `lib/harness/herdr/herdr_platform_io.dart` 和 `lint4.txt` 是别的 agent
正在改的，没有碰。

## 静态检查

- `flutter analyze --no-pub test/harness`：无问题。
- 只提交了 `test/harness/hub_ui_test.dart`。
- 未跑 `flutter test`，未跑构建。

---

# 第 5 轮（loop 5）：`retained_editor_test.dart`

本轮 CI 打印了被捕获的异常，第一次失败点确定在
`test/retained_editor_test.dart:242:18`：

```
The following StateError was thrown running a test:
Bad state: No element
#3      main.<anonymous closure> (test/retained_editor_test.dart:242:18)
```

该行是 `await tester.ensureVisible(jsonCard);`。

## 根因

工具页在 `fcbb803`（移植 netrix 工具集）改成 `ToolsBrowser`。这版页面用
`CustomScrollView` 加 `SliverChildBuilderDelegate`，卡片改为懒构建。
`ea3901a` 又把宽松网格从「按卡片最大宽度铺开」改成「持久化一列或两列」。
默认列数是 1，标题栏同时多了一个列数切换控件。

在用例的 1100x850 窗口里，卡片区可用高度约 794 dp。
构建缓存再多 250 dp，合计 1044 dp。
默认一列时「通用」分组有 9 张卡，`JSON 格式化` 是第 5 张。
它距列表顶部约 1240 dp，落在构建缓存之外。
Flutter 因此不构建这张卡。`find.text` 返回 0 个元素。
`ensureVisible` 内部按单个元素取值，于是抛 `Bad state: No element`。

`0b2519c` 当时只需补一帧，因为那时默认是 3 列。
`JSON 格式化` 排在第 2 行，一直在缓存范围内。

## 判断

产品行为正确。懒构建是 sliver 网格的常规做法。
默认一列是「工具卡片列数」任务的既定选择。
用例假设卡片已构建，所以错在用例。

## 修复

把 `ensureVisible` 换成 `scrollUntilVisible`。
滚动目标限定到带 `tools-scroll` 键的页面列表。
搜索框和分类条各自带一个 `Scrollable`，不能取全页唯一的那一个。
找到卡片后仍按原注释等一帧再点。

`studio_profile_test.dart` 里已有同样的滚动入口写法，这里保持一致。

提交：`d045273 test(editor): scroll the lazy tools grid before tapping the JSON card`

## 静态检查

- `dart format test/retained_editor_test.dart`：0 changed。
- `flutter analyze --no-pub test/retained_editor_test.dart`：无问题。
- 只提交了 `test/retained_editor_test.dart`。
- 未跑 `flutter test`，未跑构建。
