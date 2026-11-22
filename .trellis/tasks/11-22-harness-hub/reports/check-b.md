# Pi-B 交叉检查：Pi-C 分支（hub + Agents 界面）

检查对象：`harness/pi-c`
- core 工作树 `D:/MyNewProjects/_wt/harness/pi-c/qfli_studio_core`，`harness/base..HEAD` = `37e8108`、`31a7d8b`，19 个文件 +4186/−39。
- app 工作树 `D:/MyNewProjects/_wt/harness/pi-c/qflistudio`，`release/studio-git-ui-20261120..HEAD` = `c1962e6`，2 个文件 +83/−7。

对照材料：`prd.md`（AC1–AC12）、`design.md`、契约 `lib/harness/harness_host.dart`、`reports/brief.md`、`reports/pi-c.md`。

方式：只读。逐文件阅读 diff 与新增文件，未修改对方工作树、未跑任何 git 写命令、未执行测试或构建。`pi-c.md` 里的 `flutter analyze` 结论我未复跑（避免在该工作树生成构建产物），下述结论来自代码阅读。

## 结论摘要

整体质量较高：分层清楚（hub 纯状态 / ui 纯组件 / 装配点可注入），契约文件未被修改，`lib/remote_control/**` 与 `pubspec.yaml` 零改动（wire 协议、请求 ID、重连语义都没碰），没有新增依赖，没有发现凭据泄漏。约定的界面要素基本齐备（主机切换与在线点、按 provider 分组、状态标签、对话/终端双标签、手机按键栏、结束前确认对话框、关闭只 detach、旧入口改跳转、设置里的设备与远程）。

但有一处**明确的验收违规**：对话输入卡片的“停止”按钮直接调用 `HarnessSessionHandle.stop()`，没有确认对话框，而 `stop()` 的语义是**结束整个会话**（Herdr 关面板、远程 `session_close`）。这与 `design.md:33`「`stop()` 结束会话，调用方必须先取得用户确认」和 AC5 直接冲突，也和同一分支里 `HubSessionView._confirmStop()` 的正确做法自相矛盾。他们的 widget 测试只覆盖了标题栏的停止按钮，所以这条路径没有被测到。

另有 3 条中等问题和若干低级别问题，见下。

## 一、问题清单

| # | 严重度 | 位置 | 问题 |
| --- | --- | --- | --- |
| 1 | **高** | `lib/harness/ui/hub_chat_view.dart:181` | 输入卡片的停止按钮无确认即结束会话（违反 AC5 / design.md:33） |
| 2 | **中** | `lib/harness/hub/harness_hub.dart:15-17,188` | `HarnessHostHint.installHint` 是 `String?`，与 Pi-B `HerdrHost.installHint`（`HerdrInstallHint?`）类型不兼容，Herdr 安装说明永远到不了界面 |
| 3 | **中** | `lib/pages/devices_remote_page.dart:64-88` | 页面在 `RemoteStore.open()` 期间被弹出时，新建的 `RemoteController` 不会被释放（WebSocket 与订阅泄漏） |
| 4 | **中** | `lib/harness/ui/hub_chat_view.dart:55-60` | `_HubChatViewState` 只在 `initState` 绑定句柄，`didUpdateWidget` 不处理句柄变化，复用 State 时会保留旧订阅与旧事件 |
| 5 | 低-中 | `lib/harness/hub/harness_hub.dart:316-343` | `launch(..., hostId:)` 不更新 `_currentHostId`（与 `openSession` 不一致），可让会话属于非当前主机 |
| 6 | 低 | `lib/harness/ui/hub_terminal_view.dart:60,125` | `_output` 字段从未赋值（死代码）；分块解码器在 `dispose` 时未关闭 |
| 7 | 低 | `lib/harness/ui/hub_session_list.dart:371` | 侧边栏只列当前主机；切到“内置 Agent”主机时会把内置会话重复列一遍 |
| 8 | 低 | `lib/harness/hub/harness_hub.dart:105-111` | 构造即订阅所有主机，Herdr 的 `agent wait`/`agent list` 循环在没人看 Agents 面板时也在跑 |
| 9 | 备注 | `lib/harness/hub/harness_hub.dart:430-447`、`harness_hosts.dart:88-96` | hub 释放所有主机（共享单例风险）；装配工厂异常被静默吞掉 |
| 10 | 备注 | `test/harness/hub_ui_test.dart` | 缺少覆盖第 1 条的测试，另有多处未覆盖 |

## 二、详细说明

### 1（高）输入卡片的停止按钮绕过了确认

`lib/harness/ui/hub_chat_view.dart:177-183`：

```dart
HubComposer(
  state: _composer,
  onSend: _send,
  sending: _sending,
  onStop: () => widget.handle.stop(),   // 181
  enabled: true,
),
```

`HarnessSessionHandle.stop()` 在契约里是“结束会话”，`design.md:33` 明确写「`stop()` 结束会话，调用方必须先取得用户确认」，`prd.md` AC5 也是「结束会话需要用户在界面上确认」。而这里的调用没有任何对话框，且注释（文件头第 6 行）还写着“只保留发送与停止”，读起来像“停止本轮输出”，与实际后果不一致：对 Herdr 主机是 `pane close`（关掉面板、杀掉里面的 agent），对远程主机是 `closeSession`（结束桌面会话）。用户在发送中途点“停止”，期望的是取消这次发送，实际会结束整个会话。

同一分支的 `hub_session_view.dart:98-137` 已经做对了（`_confirmStop()` 弹 `hub-stop-dialog`，取消/结束两个按钮，按钮用 error 色），说明这是遗漏而不是设计选择。

建议修法（任选其一，推荐第 1 个）：
1. 把确认逻辑上提：`HubChatView` 增加 `onStop` 回调参数，由 `HubSessionView` 传入自己的 `_confirmStop`，输入卡片与标题栏共用同一个确认流程；
2. 或者把输入卡片的停止按钮去掉（外部 harness 的发送通常很快，标题栏已有结束入口）；
3. 若确实想表达“中断本轮”，需要在契约里加能力（见第七节），不能复用 `stop()`。

配套：`test/harness/hub_ui_test.dart` 增加一条“输入卡片点停止也要先弹确认”的用例，否则修完仍可能回归。

### 2（中）安装提示的类型对不上，Herdr 的说明到不了界面

`lib/harness/hub/harness_hub.dart:15-17`：

```dart
abstract class HarnessHostHint {
  String? get installHint;
}
```

而 Pi-B 的 `HerdrHost` 提供的是结构化对象：

```dart
HerdrInstallHint? get installHint;   // {title, message, url, resolvedPath}
```

两者同名但类型不同，`HerdrHost implements HarnessHostHint` 无法通过编译，于是 `hintOf('herdr')` 恒为 `null`。`hub_agents_surface.dart:117` 的提示条因此永远不出现，`hub_agents_surface.dart:255` 只能退回通用文案「检查这台电脑上是否已安装对应程序。」。

`reports/pi-c.md` 的“契约变更请求”里提到“Pi-B should implement it for Herdr（`installHint: '未检测到 Herdr，请先安装…'`）”——按现有类型做不到，这是跨 Pi 的接口没对齐，不是 Pi-B 单方面能补的。

建议修法：
1. 短期（Pi-C 侧）：把接口改成 `Object? get hostHint;`，并在 hub 里提供 `String? hostHintText(String hostId)` 做类型分派（`String` 直接用；否则尝试读 `message`）；或
2. 正式（root 侧）：契约加 `String? get hint`，`HerdrHost` 用自己的对象拼 `message` 返回；`HarnessHostHint` 也随之删除。
3. 顺手：`hintOf` 里 `if (host is HarnessHostHint) return (host as HarnessHostHint).installHint;` 的显式转型是多余的（`is` 已提升类型），可去掉。

影响：功能降级而非崩溃——用户仍能看到 `unsupported` 的通用说明，但拿不到“未安装 Herdr / 服务未运行 / 找到但跑不起来”的区别和安装链接。

### 3（中）设备与远程页的控制器泄漏

`lib/pages/devices_remote_page.dart:64-89`：

```dart
Future<void> _boot() async {
  ...
  final store = widget.store ?? await RemoteStore.open();   // 74
  _store = store;
  _controller = RemoteController(store: store)..connect();  // 78
  _ownsController = true;
  ...
  if (mounted) setState(() => _booting = false);
}

void dispose() {
  if (_ownsController) _controller?.dispose();
  super.dispose();
}
```

`RemoteStore.open()` 是异步的（要读本地私有存储）。如果用户在这期间返回上一页，`dispose()` 先跑，此时 `_controller` 还是 `null`、`_ownsController` 还是 `false`，于是什么也没释放；随后 `_boot` 继续执行，创建并 `connect()` 了一个控制器（WebSocket 长连接 + 事件订阅），再因为 `!mounted` 跳过 `setState`。这个控制器没有任何人持有，也不会被释放，直到进程退出。

建议修法：

```dart
final store = widget.store ?? await RemoteStore.open();
if (!mounted) {
  if (widget.store == null) await store.close();   // 若 store 有 close
  return;
}
final controller = RemoteController(store: store)..connect();
if (!mounted) { controller.dispose(); return; }
setState(() { _store = store; _controller = controller; _ownsController = true; });
```

即在每个 `await` 之后检查 `mounted`，并把“创建 + 赋值”放到同一个同步段里。

同类但更轻的问题：`_PairRoute._onChanged`（`devices_remote_page.dart:298-310`）在配对完成后用 `addPostFrameCallback` 弹路由，未检查 `_paired` 与当前路由是否仍是最上层；重复触发时 `Navigator.pop` 可能把设置页一起弹掉。概率低，但把 `Navigator.of(context).canPop()` 或 `ModalRoute.of(context)?.isCurrent == true` 加进判断更稳妥。

### 4（中）对话视图不跟随句柄变化

`lib/harness/ui/hub_chat_view.dart:55-60` 只在 `initState` 调用 `_bind()`，类里没有 `didUpdateWidget`（文件里唯一的 `didUpdateWidget` 在 314 行，属于 `HubComposer`）。`_bind()` 把 `_sub` 绑到 `widget.handle.transcript` 上，`_events` 也只增不清。

`HubSessionView` 明确支持“同一个 widget 换 session”（`hub_session_view.dart:49-56` 的 `didUpdateWidget` 在 id/hostId 变化时重新 `_open()`），但 `HubChatView` 不跟着重绑：一旦 State 被复用，界面会继续显示上一个会话的事件流，而 `_send` 用的是新的 `widget.handle` —— 也就是“看到的是旧会话的内容，发出去的消息进了新会话”。

当前 app 里 `hub_agents_surface.dart:65` 给 `HubSessionView` 加了 `ValueKey('hub-view-${hostId}-${id}')`，换会话会整棵子树重建，所以这条在现有调用路径上被掩盖了。但这是巧合而不是契约：`hub_ui_test.dart` 就直接构造不带 key 的 `HubSessionView`，任何将来去掉 key 或复用视图的改动都会踩到。

建议修法：给 `_HubChatViewState` 加

```dart
@override
void didUpdateWidget(HubChatView oldWidget) {
  super.didUpdateWidget(oldWidget);
  if (!identical(oldWidget.handle, widget.handle)) {
    _events.clear();
    _answered.clear();
    _error = null;
    _bind();
  }
}
```

并在 `_bind()` 开头清空 `_events`（或在 `didUpdateWidget` 里清）。

### 5（低-中）`launch(hostId:)` 不切换当前主机

`lib/harness/hub/harness_hub.dart:316-343` 的 `launch` 只设置 `_activeSession` / `_activeHandle`，没有像 `openSession`（307 行 `if (_currentHostId != targetHostId) _currentHostId = targetHostId;`）那样同步当前主机。

后果：调用 `hub.launch(request, hostId: 'remote-pc')` 而当前是 `local` 时，`HubAgentsSurface` 会用 `currentHost`（local）画标题栏和空状态，却用 `activeSession`（remote-pc）画会话体，两者对不上；侧边栏也不会把新会话列出来（`sessionsOf(currentHost)` 里没有它）。

现在 `HubNewSessionButton` 调 `hub.launch(request)` 不传 `hostId`，所以是潜伏问题；但既然 `openSession` 已经处理了同一种情况，这里应保持一致：设置 `_currentHostId = host.id` 后再 `notifyListeners()`。

### 6（低）终端视图的死代码与资源清理

`lib/harness/ui/hub_terminal_view.dart:60` 声明了 `StreamSubscription<String>? _output;`，全文只有 `_output?.cancel()`（73、127）和 `_output = null`（129）——从未赋值。疑似早期用 `Stream<String>` 版本的残留，应删除，避免后来者以为还有第二条输出通道。

另外 `_bind()`（68-100）里的 `Utf8Decoder(...).startChunkedConversion(...)` 创建的 decoder 在 `dispose()` 中没有 `close()`。对 `allowMalformed: true` 来说只是丢掉末尾半个字符，不会崩，但流结束（`onDone`）时是关闭的、销毁时不关闭，行为不一致。建议在 `dispose` 里保存并在取消订阅后调用 `decoder.close()`。

### 7（低）侧边栏在“内置 Agent”主机下会重复列会话

`lib/harness/ui/hub_session_list.dart:371` 的 `final groups = hub.groupsOf(host.id);` 用的是**当前主机**。`HubSessionListSection` 的标题写死是「外部会话 · ${host.label}」，但当前主机若是 `studio`（内置 Agent），它会把这个主机的会话再列一遍——而这些会话已经由上面的 `SessionListView` 原生列表画过一次了。

`HarnessHub.allSessions` 与 `HubSessionRow.showHostLabel`/`hostLabel` 都已实现却没人用，说明原本想做“合并列表”，最后落成了“当前主机列表”。当前默认主机是 `local`（`_pickInitialHost` 优先 local），所以只有用户主动切到“内置 Agent”时才看得到重复。

建议修法：在 `HubSessionListSection` 开头加 `if (host.kind == HarnessHostKind.studio) return const SizedBox.shrink();`；若要真正合并多主机，则改用 `hub.allSessions` 并打开 `showHostLabel`。两种都比现在一致。

### 8（低）构造即订阅，主机刷新常驻

`lib/harness/hub/harness_hub.dart:105-111` 在构造函数里对每台主机 `_listen(host)`。`EditorPage` 在 `initState`（`editor_page.dart:454`）就建 hub，所以即使用户从不打开 Agents 面板，`HerdrHost.watchSessions()` 的循环也已经在跑：空闲时每 30 s 一次 `herdr agent list`，有 agent 工作时是 20 s 一轮 `herdr agent wait` 子进程。配合 `RetainedEditorHost` 的多会话（每个 `EditorPage` 一个 hub、一套主机），进程数会随打开过的项目数线性增长。

这不是 Pi-C 的 bug（订阅语义由 hosts 决定），但 hub 是最合适的收敛点。建议：`HarnessHub` 增加 `start()/pause()`，或把 hub 的创建推迟到 `HubAgentsSurface` 首次可见；或按 `pi-c.md` 风险 2 的建议让主机成为应用级单例、由 root 统一持有。

### 9（备注）释放语义与装配容错

- `harness_hub.dart:430-447` 的 `dispose()` 会 `host.dispose()` 每一台主机。`harness_hosts.dart:52-58` 的注释已说明“工厂每次应返回新实例”，但没有任何机制保证；如果集成时把它们做成应用级单例（很可能，因为 `RemoteController` 必须被设备页和 hub 共享），编辑器页关闭就会把全局主机 dispose 掉。Pi-B 的 `HerdrHost`/`RemoteHarnessHost` 的 `dispose()` 是幂等的、可以重复调用，但 Pi-A 的 `LocalHarnessHost` 未核对。集成时必须二选一：工厂给新实例，或 hub 不拥有主机（加 `ownsHosts: false`）。
- `harness_hosts.dart:88-96` 的 `build()` 用 `catch` 把工厂异常吞成空列表。结果是“某台主机构造失败”表现为“Agents 面板什么都没有”，没有任何可诊断信息。建议至少把异常存到 `HarnessHosts.lastError` 或在 debug 下 `assert`。

### 10（备注）测试覆盖缺口

已有测试质量不错（14 条 hub 状态用例 + 11 条 widget 用例，覆盖了平台过滤、默认主机、分组排序、同会话复用、关闭只 detach、标题栏停止需确认、按键栏修饰键、剪贴板粘贴）。缺的是：

| 缺口 | 说明 |
| --- | --- |
| 输入卡片停止路径 | 就是第 1 条；补一条“点 `hub-composer-stop` 要先弹确认”即可防回归 |
| `DevicesRemotePage` | 完全没有测试：配对态渲染、撤销确认、`_boot` 失败、以及第 3 条的“启动中被弹出” |
| `agents_entry.dart` | 没有测试：无项目时弹说明、有项目时带 `revealAgentPane` 打开编辑器 |
| `HubTerminalView` | 没有测试：字节经 chunked 解码进 xterm、多字节字符跨块、`resize` 转发、流结束回调 |
| `launch(hostId:)` 与 `openSession(hostId:)` | 只测了不传 hostId 的路径（第 5 条因此没被发现） |
| 对话换句柄 | 没有测试（第 4 条） |
| `HubSessionListSection` | 没有测试：当前主机为 studio 时的重复（第 7 条） |

## 三、没有发现问题的项（已核对）

| 检查项 | 结论 |
| --- | --- |
| 契约修改 | **无**。`lib/harness/harness_host.dart` 不在 `harness/base..HEAD` 的改动文件里；`pi-c.md` 也说明了 `dart format` 误改后已还原。 |
| wire 协议 / 请求 ID / 重连 / 重放 | **未改动**。`git diff --stat harness/base..HEAD -- lib/remote_control` 为空；新增代码只调用 `RemoteController` 的既有方法。 |
| 凭据泄漏 | **未发现**。新增/修改文件里没有 `print`/`debugPrint`/`log` 输出；设备页只渲染 `pairing.relayUrl` 与 `pairing.agentId`，`Pairing.toString()` 明确不输出 `secret`；没有任何地方读取或展示 token / auth.json / 环境变量。 |
| 新增依赖 | **无**。`pubspec.yaml` / `pubspec.lock` 均未改动；复用的是 core 已有的 `xterm`（vendored）、`ChatMessageTile`、`ComposerState`、`RemoteTheme`、`SessionListView`、`PairScreen`。 |
| 契约误用 | 除第 1 条（`stop()` 未经确认）与第 2 条（新增的可选接口类型不兼容）外，其余调用符合契约：`detach()` 只释放视图、`reply()` 只在用户点选项时调用且带 `requestId` 与 `choice`、列表用 `HarnessSessionInfo` 字段、`providers()` 结果只用于菜单。 |
| 订阅泄漏（hub 内） | `_listen` 的订阅在 `refresh()` 与 `dispose()` 中都会 `cancel`；`_stateListeners` 在 `dispose` 时逐个 `removeListener`；`HubSessionView.dispose` 通过微任务调 `closeActiveSession()`，不会在 dispose 期间触发上层重建。 |
| 重复创建 hub | `_harnessHub` 只在 `EditorPage.initState` 创建一次（`editor_page.dart:454`），未见重复赋值。 |
| 手机端平台策略 | `hostVisibleOnPlatform` 与 `_pickInitialHost` 一致：手机只留 `remote`/`studio`，默认停在第一台已绑定电脑。 |
| 旧入口 | `studio_tools_tab.dart` 的卡片改成跳转 Agents，`RemoteComputerPage` 仍导出且未修改，设置页新增“设备与远程”，符合 design 的“去掉独立首页”。 |

## 四、给 root 的集成注意

1. **第 1 条必须在合并前修**：它是 AC5 的唯一硬违规，且修法很小（把 `_confirmStop` 传下去）。若不修，Herdr 用户点一次“停止”就会关掉一个正在跑 agent 的面板。
2. **第 2 条需要 root 定接口**：`HarnessHostHint` 与 Pi-B `HerdrInstallHint` 的冲突跨两个分支，建议按第二节的方案 2 在契约里加 `String? get hint`，然后 Pi-B 一行实现、Pi-C 删掉可选接口。
3. **主机所有权要明确**（第 9 条）：`HarnessHosts.registerDefault` 的工厂返回新实例，还是返回应用级单例？建议在集成提交里写死一种，并在 `HarnessHub` 增加 `ownsHosts` 开关。`RemoteHarnessHost` 必须包共享的 `RemoteController`（否则设备页与 Agents 面板会各连一条 WebSocket），所以“宿主持有但不释放”很可能才是正确形态。
4. **第 8 条的常驻刷新**：集成后每打开一个项目就多一套 Herdr 刷新循环，建议在合并时一并处理（懒创建或单例），不要留到 P5。
5. `pi-c.md` 里的其余合并风险（配对界面 `PairScreen` 存在两份挂载点、账号绑定未接 11-21）与我的观察一致，不重复。

## 五、未验证项

- 我没有在 Pi-C 工作树内执行 `flutter analyze` / `flutter test` / 构建（只读要求 + brief 的“不跑测试/构建”）。`pi-c.md` 声称 core 仅 2 条既存 info、app 1 条既存 info；我未复核。
- 界面布局只在代码层面核对（控件、key、文案、断点分支），未在真机或桌面窗口里看过实际渲染；`pi-c.md` 的布局描述与我读到的实现一致。
- 第 3 条的泄漏路径是代码推理（异步窗口 + `dispose` 顺序），未用运行时复现。
- 第 8 条的进程开销是估算（每 hub 一套循环），未实测。
