# check-a：Pi-B 交叉复核（HerdrHost / RemoteHarnessHost）

复核对象：`D:/MyNewProjects/_wt/harness/pi-b/qfli_studio_core` 分支 `harness/pi-b`
（`c1625ad`、`09df701`），App 工作树 `.../pi-b/qflistudio`。
对照 `prd.md`（AC1–AC12）、`design.md`、契约 `lib/harness/harness_host.dart`、
`reports/brief.md`（Pi-B 段 70–91 行）与 `reports/pi-b.md`。

方式：只读代码审阅 + 只读 `git diff`；未修改对方任何文件，未运行 git 写命令。
额外做了一次只读的 `dart analyze lib/harness <6 个测试文件>`（结果见 §5）。
按规则未运行 `flutter test`，因此测试结论均为静态推断。

结论：**不能原样合并。** 有 1 个高严重度功能缺陷（远程终端永远是空屏，
且其覆盖测试本身会失败），另有若干中低风险正确性、资源与契约问题。

---

## 1. 高严重度

### H1. 远程终端通道永远不发任何字节（AC6/AC7 的终端页实际为空）

- `lib/harness/remote/remote_terminal.dart:31`（构造时回放）与
  `lib/harness/remote/remote_terminal.dart:70`（`_pump`）都在
  `_view.events` 里找 `TerminalOutputEvent`：

  ```dart
  for (final event in _view.events) {
    if (event is protocol.TerminalOutputEvent) _emit(event.data);
    _lastSeq = event.seq;
  }
  ```

- 但 `SessionView` 根本不把终端字节放进 `_events`。`lib/remote_control/state/session_view.dart:127-134`：

  ```dart
  bool _add(SessionEvent e) {
    if (e.seq <= lastSeq) return false;
    _lastSeq = e.seq;
    if (e is TerminalOutputEvent) {
      terminal.write(e.data);   // 只写进 xterm 缓冲
      return true;              // 提前返回，_events 里没有它
    }
    _events.add(e);
  ```

  回放路径 `applyBacklog()` 走的也是 `_add`，同样被拦截。

影响：`RemoteTerminalChannel.output` 永远只发得出零个事件，
`session:`（Claude/终端）会话的“终端”标签在手机与桌面都是空白；
后端 PTY 明明在跑，用户看不到任何输出。这与 AC6（手机看远程会话）
和 AC7（手机终端按键栏）直接冲突。

同一处还说明测试没被执行过：
`test/harness_remote_host_test.dart:524`「a terminal session streams bytes and
types exact input」在 `539-550` 行订阅输出、`pushEvent(TerminalOutputEvent)` 后断言
`expect(chunks.single, 'PS> '.codeUnits)`。按上面的 `_add` 逻辑 `chunks` 必为空，
`.single` 会抛 `StateError: No element`。也就是说这条测试一旦跑就是红的。

建议修法（二选一，改动都很小）：

1. 在 `SessionView` 增加一个原始输出旁路，例如
   `void Function(String)? onTerminalOutput;`，在 `_add` 的
   `terminal.write(e.data)` 旁同时回调；`RemoteTerminalChannel` 订阅它，
   `_view.events` 只用于对话事件。
2. 让远程终端直接复用现成的 `_view.terminal`（11-20 迁入的 xterm 实例，
   `RemoteTerminalPane` 就是这么渲染的），`HarnessTerminalChannel` 只保留
   `write`/`resize` 两个方向。

修好后同步改 `harness_remote_host_test.dart:524` 的夹具（把事件推给新回调），
并补一条“打开第二次仍能回放屏幕”的断言。

---

## 2. 中严重度

### M1. `HerdrHost` 没有可用的 PTY 实现，AC3「输出实时刷新」实际不成立

- `lib/harness/pty/harness_pty.dart` 只定义了 `HarnessPty` / `HarnessPtyFactory`，
  仓库里没有任何实现类；`herdr_host.dart:487-508`（`_createTerminal`）在
  `_ptyFactory == null` 或抛 `HarnessPtyException` 时一律退到
  `HerdrSnapshotTerminal`（`herdr_terminal.dart:110-165`，1.5 s 一次 `pane read`）。
- 交付里也没有构造 `HerdrHost` 时注入默认 factory 的地方，所以“合并后默认”
  就是快照模式：输出是准实时，不是 brief 要的「实时刷新」。

brief（`reports/brief.md:79-81`）明确写了“reuse the same PTY layer core already
has; coordinate in your report if you need Pi-A's StudioMux”。`pi-b.md` §10.2 确实
做了协调并给出 ~30 行适配器，但没有随分支落地，于是 AC3 处于“要等集成”的状态。

建议：把 `StudioMuxPtyFactory`（`pi-b.md` §10.2 那段）直接放进
`lib/harness/local/` 并在 `HerdrHost` 默认构造里使用；`allocatesTerminal == false`
时直接抛 `HarnessPtyException` 走快照分支（与 `pi-b.md` §9.1 的判断一致），
避免 Windows 上卡在坏掉的 `agent attach`。

### M2. `stop()` 之后 `open()` 会返回已经死掉的句柄

- `lib/harness/herdr/herdr_session.dart:104-112`：`stop()` 只置 `_stopped`、
  关终端、`pane close`、把状态改成 `exited`，**没有**从宿主的 `_handles` 里移除。
- `lib/harness/herdr/herdr_host.dart:179-180`：
  ```dart
  final cached = _handles[sessionId];
  if (cached != null) return cached;
  ```
- 远程侧同样：`remote_session.dart:160-167`（`closeSession` 后保留在 map），
  `remote_harness_host.dart:141-145` 直接返回缓存。

后果：用户 `stop()` 后再点同一个会话（列表里可能还留着 exited 行，或重新出现
同 id 的会话），拿到的是终端已关闭、`_status` 恒为 `exited` 的句柄；
再 `write()` 是静默丢弃（`herdr_terminal.dart:191` 的 `_closed` 判断），
用户会以为“打开了但不动”。

建议：`stop()` 里调用 `_onDetached(this)`（或显式 `_handles.remove(id)`）后
再 `dispose()`；`open()` 命中缓存但句柄已 `_stopped`/`_detached` 时视为未命中。

### M3. 快照终端的输入会乱序，而且一次按键一个 CLI 进程

- `lib/harness/herdr/herdr_terminal.dart:191-193`：
  ```dart
  void write(Uint8List data) {
    if (_closed) return;
    unawaited(_dispatch(translator.translate(data)));
  }
  ```
  `_dispatch`（`239-252`）内部是 `await _sendText(...)` / `await _sendKeys(...)`
  串行，但**多个 `_dispatch` 之间没有任何串行化**。终端的 `write` 是按 chunk 来的：
  "hello" 与随后的 Enter 在两个 chunk 里，就是两条并发的 CLI 调用，
  `pane send-keys enter` 完全可能先于 `pane send-text hello` 到达。
- 同时每个 chunk 都起一个 `herdr` 进程（一次按键 ≈ 一个进程，50–200 ms），
  在 Windows（默认走快照）上打字会明显卡顿并伴随错序。

建议：在 `HerdrSnapshotTerminal` 内维护一个串行队列
（`_queue = _queue.then((_) => _dispatch(ops))`），并给文本加 ~20–30 ms 合并窗口，
把一次输入的多个字符合成一条 `pane send-text`；`close()` 时丢弃队列尾部。

### M4. `RemoteHarnessHost.id` 不稳定，且未配对时会撞 id

- `lib/harness/remote/remote_harness_host.dart:67-71`：
  ```dart
  String get id {
    final key = _remote.hostId.trim();
    return key.isEmpty ? 'remote' : 'remote:$key';
  }
  ```
  `hostId` 来自 `pairing?.agentId ?? agent?.host ?? 'remote'`
  （`remote_ports.dart:88-93`），是**运行时可变**的：宿主对象常在配对信息
  加载前就构造好，之后 pairing 到位，`id` 从 `remote` 变成 `remote:<agentId>`。
- 契约把 `id` 当作宿主的稳定标识，Pi-C 的 hub 用 map 按 id 注册；
  `HarnessSessionInfo.hostId` 也在每次 `_emit()` 里用当时的 `id` 盖章。

后果：hub 里同一个宿主出现两个 key（或旧的 `remote` 条目变成僵尸，
点开会话时 `hostId` 与列表行不一致）；两台都未配对的电脑 id 都是 `remote`，
在 map 里互相覆盖。

建议：构造时解析一次并缓存（`late final String _hostId = _resolveHostId();`），
在 `pi-b.md` 里写明“配对信息必须早于宿主构造”或由 hub 在配对变化时重建宿主；
未配对时退化为 `remote:<agentId>` 或加随机后缀，不要用常量。

### M5. `agent wait` 的输家子进程不会取消，会堆积

- `lib/harness/herdr/herdr_host.dart:359-371`：
  ```dart
  final waits = <Future<void>>[for (final agent in busy) _waitQuietly(cli, agent)];
  await Future.any<void>(waits);
  ```
  `Future.any` 只取第一个完成，其余 `agent wait` 仍会跑到 `waitBudget`
  （默认 20 s）才结束。循环每轮都会重新为**所有** working 的 agent 起一批，
  于是一有 agent 结束就再起 N 个，旧的那批还在跑。
  面板多、状态频繁翻转时，同时存活的 `herdr` 子进程会明显多于面板数；
  `dispose()` 只 `_supervisor.dispose()`，不针对单个 wait 收尾。

建议：给 `HerdrProcessRunner` 加取消能力（token / `Completer`），
`Future.any` 完成后取消其余；或退化成“一次只等一个 agent”（挑最早 working 的），
并在 `_disposed` 时统一取消。

### M6. Codex 句柄的状态永远停在打开那一刻

- `lib/harness/remote/remote_session.dart:311-320`：`_status` 只在构造时
  `remoteCodexStatus(view.thread.status)` 算一次；`_CodexTranscriptFeed`
  只负责往流里推条目，从不更新 `_status`。
- 对比 `RemoteSessionStatusNotifier`（`remote_terminal.dart:168-197`）会
  `_view.addListener` 同步状态，Codex 这条路径漏了同样的处理。

后果：桌面上线程从 `active` 变成 `blocked`/`done` 后，Agents 列表里的状态
标签不再变化，用户看不到“需要我处理”。

建议：在 `RemoteCodexThreadHandle` 里监听 `_view.changes`，把
`remoteCodexStatus(_view.thread.status)` 写进 `_status`，`dispose()` 时移除监听。

---

## 3. 低严重度

### L1. `dispose()` 与在途刷新/等待的竞态

- `lib/harness/herdr/herdr_host.dart:254`：`_wake?.complete();` 没有
  `isCompleted` 判断（`refreshNow()` 在 `331-335` 行是判过的）。
  若此刻 `_wake` 已被 `refreshNow()` 完成但尚未被 `_sleep` 清空，
  `complete()` 会抛 `StateError`，`dispose()` 直接失败。
- `herdr_host.dart:409-446`：`_refreshOnce()` 在 `_disposed` 检查之后还有多处
  `await`，回来仍会写 `_state.value`；`dispose()` 已经 `_state.dispose()`，
  这时写 `ValueNotifier` 会抛异常（async 上下文里变成未捕获错误）。
- `herdr_host.dart:339-355`：`_runLoop` 的循环体没有 try/catch，`_refreshOnce`
  只捕获 `HerdrException`；任何其他异常（如解析出非预期类型）会让刷新循环
  **永久停止**，而宿主仍显示 online。

建议：`if (_wake case final w? when !w.isCompleted) w.complete();`；
刷新完成后再判一次 `_disposed`；`_runLoop` 整体包 try/catch 并记录 `_lastError`。

### L2. `closePane` 绕过了 `HerdrActions` 与 `HerdrController.run`

- `lib/harness/remote/remote_ports.dart:223-226` 手拼 wire JSON：
  ```dart
  await remote.herdrAct(<String, dynamic>{'kind': 'pane_close', 'paneId': paneId});
  ```
- 而 `lib/remote_control/models/herdr.dart:527` 已经提供了唯一出口
  `HerdrActions.paneClose(paneId)`（该文件自称 “single owner … tests can
  assert it directly”），`HerdrController.run()`（`herdr_controller.dart:920`）
  还负责去重、错误中文化与刷新。

建议：改成 `controller.run('pane-close:$paneId', () => remote.herdrAct(HerdrActions.paneClose(paneId)))`。
现在这样一旦 wire 侧字段改名，这里会静默失效且没有任何测试能发现。

### L3. provider 可用性是猜的

- `lib/harness/remote/remote_harness_host.dart:118-135`：`claude` 与 `shell`
  一律 `available: true`。`AgentInfo`（`protocol.dart:141-178`）里没有
  claude 可用性字段，所以桌面上没装 Claude 时菜单仍会给出条目，点了才报错。
- `lib/harness/herdr/herdr_cli.dart`：`HerdrProviderSpec.forKind` 对表外 kind
  用 `executable: kind` 兜底，`HerdrHost.providers()` 再用
  `executableOnPath(...)` 判可用（`herdr_host.dart:150-166`）。`agentKinds` 里的
  `agy / maki / muse / hermes / kilo / qodercli / letta / mastracode / kiro`
  可执行名并不等于 kind，会被判成 `available: false` 而被界面隐藏 —— 但
  `agent start --kind X` 的解析在 Herdr 自己那边，Studio 的 PATH 不该是门槛。

建议：远程侧把 `available` 当成“协议支持”而不是“已安装”，或干脆由
`launch()` 失败后回写；Herdr 侧对表外 kind 直接 `available: true`
（Herdr 认这个 kind 就能起），把可执行文件探测只当作提示信息。

### L4. `launch()` 丢参数；自由文本没有 `-` 保护

- `lib/harness/remote/remote_harness_host.dart:216-231`：`HarnessLaunchRequest.args`
  被完全忽略（`createTerminal`/`createSession` 都不带）。契约里 `args` 是
  “额外启动参数”，静默丢弃会让 Pi-C 的“带参数新建”看起来成功但没生效。
  建议：`args.isNotEmpty` 时抛 `UnsupportedError` 或写进 `prompt`/记录到 `pi-b.md`。
- `lib/harness/herdr/herdr_cli.dart:331`（`agent prompt <target> <text>`）与
  `349-353`（`pane send-text <pane> <text>`）：`_requireTarget` 会拒绝以 `-` 开头的
  target，但 `text` 没有同等保护；用户发一条以 `-` 开头的提示（如 `--help 是什么`）
  可能被 herdr 当成选项。建议在 `text` 前插入 `--` 结束符（若 herdr 支持），
  或对首字符是 `-` 的文本改走 `send-text` 并显式拒绝/转义。

### L5. 翻译器丢 Alt 与未知 CSI（影响 AC7 的 Alt 键）

- `lib/harness/herdr/herdr_input.dart:117-120`：ESC 后接可打印字符直接
  `return _Escape(null, start + 2)`，注释写明 “Herdr has no Alt verb”，
  连 `send-text` 的 ESC 前缀退路也没走；未知 CSI 同理被丢弃。
- AC7 要求手机终端提供 Esc、Tab、Ctrl、**Alt**、方向键和粘贴。
  `session:` 会话走原始字节（`remote_terminal.dart:47-56`）没问题，
  但 `herdr:` 面板走的就是这个翻译器，Alt 组合与 Alt+方向键会静默无效。

建议：Alt 用 `send-text` 发 `\x1b` + 字符（`pane send-text` 写的是字面字节，
语义等价），或先确认 herdr 是否接受 `alt+x` 键名再补进 `keyNames`；
至少在 `pi-b.md` 里把这个能力缺口写进“未验证/不支持”。

### L6. 显式设置的 herdr 路径无效时报“未安装”

- `lib/harness/herdr/herdr_platform_io.dart:56-60`：`explicitPath` 探测失败
  直接 `return null`，宿主于是给出 `HerdrInstallHint('未安装 Herdr')`。
  用户明明在设置里指了一个路径，界面却说没装，`resolvedPath` 也是空的。

建议：区分“未配置”与“配置了但不可执行”，后者用
`HerdrInstallHint(title: 'Herdr 路径无效', resolvedPath: explicit)` 并保留原文。

### L7. 每来一个事件就把整份事件表复制一遍

- `lib/remote_control/state/session_view.dart:29`：`events` 每次访问都
  `List.unmodifiable(_events)` 复制；`remote_terminal.dart:70` 与 `142`
  在**每次** `notifyListeners()`（流式输出时是每个 token）都遍历一次。
  长会话下是 O(n²) 的分配与扫描。

建议：`_pump` 里改用长度游标（`_seenLength`）只在列表变长时取一次快照，
或推动 `SessionView` 暴露 `eventsSince(int seq)`。

### L8. 其他小项

- `herdr_host.dart:150-166`：`_providers` 缓存到 `dispose`，用户在 Studio 运行中
  新装 harness 后菜单不更新（重启才能刷）。建议加 `refreshProviders()` 或 TTL。
- `remote_harness_host.dart:104-110`：`watchSessions()` 一被调用就起
  `_codexTimer`，之后即使没有监听者也每 20 s 拉一次 Codex 目录。建议在
  最后一个监听者取消时停表（`Stream.multi` 的 `onCancel`）。
- `remote_session.dart:84`：`terminal` 在 `detach()` 后仍非 null（只是内部
  `_closed`），与契约“没有终端时返回 null”的语义略显含糊；`HerdrSessionHandle`
  在同样场景是返回 null 的，建议统一。
- `herdr_platform_stub.dart:12`：Web 构建下 `locateHerdrExecutable` 返回 null，
  宿主会显示“未安装 Herdr”而不是“此平台不支持”。文案小事，但会误导 Web 用户。

---

## 4. 测试覆盖缺口

已写 6 个测试文件（models / cli / platform / input / host / remote），
方向是对的，CLI argv 精确断言与 fail-closed 审批的用例质量不错。缺口：

| 缺口 | 说明 |
| --- | --- |
| 远程终端字节 | `harness_remote_host_test.dart:524` 这条按现在的实现**必定失败**（见 H1），也就是说“终端通道有输出”这件事实际上没有被覆盖。 |
| stop → open 同一会话 | 两个宿主都没有用例，正好漏掉 M2。 |
| `RemoteHarnessHost.id` 稳定性 | 没有“配对信息后到”的用例，漏掉 M4。 |
| 刷新循环健壮性 | 没有“`agent list` 抛非 `HerdrException` 后循环仍活着”的用例，漏掉 L1。 |
| 快照终端输入顺序 | `herdr_input_test` 只测翻译结果，没有测 `_dispatch` 并发下的顺序（M3）。 |
| Codex 状态刷新 | 没有“线程状态变化后 `handle.status` 跟着变”的用例（M6）。 |
| Alt / 未知 CSI | 未知 CSI 有“丢弃”用例，但 Alt 组合没有用例，也没有在报告里标为不支持（L5）。 |

---

## 5. 复核确认无误的部分

- **契约未改**：`git diff harness/base..HEAD -- lib/harness/harness_host.dart` 为空；
  两个提交只动 `lib/harness/**` 与 6 个测试文件（23 files，+6115）。
- **App 工作树未改**：`git diff release/studio-git-ui-20261120..HEAD` 为空、
  `git status` 干净。因此本分支没有 UI 规则违例可言（UI 属 Pi-C）。
- **wire 协议未改**：`lib/remote_control/**` 零改动；只调用既有
  `herdrAct` / `closeSession` / `codex*` 方法，没有新请求、没有改 request id、
  没有动重连与重放语义。`remote_ports.dart` 三个端口都是薄委托。
- **无凭据泄漏**：`lib/harness` 内没有 `print` / `debugPrint` / 写日志；
  错误文案只带 herdr 错误码与首行 stderr；不读 herdr socket / 配置 / 状态文件，
  也不碰 `agent_session` 里的会话日志路径（`herdr_models.dart` 顶注有明确说明）。
- **平台隔离**：`dart:io` 只出现在 `herdr_platform_io.dart`，由
  `herdr_platform.dart` 条件导出，`herdr_platform_stub.dart` 签名对齐。
- **进程管理**：CLI 调用走 `ProcessSupervisor`、`runInShell: false`、
  每个参数一个 argv 元素、2 MB 输出上限、超时 `cancel()` 后 `await exitCode`；
  符合 `process-lifecycle.md`。
- **审批安全**：`reply()` 在 Herdr 侧抛 `UnsupportedError`（不猜对话框），
  远程侧未知 decision 一律 `deny`，问题型请求必须带答案，没有“打开即同意”的路径。
- **detach/stop 语义**：`detach()` 不发 `session_close`、不 `pane close`，只解订阅；
  `stop()` 才结束，且测试断言了这一点（`harness_herdr_host_test.dart` 的
  “stop closes the pane after an explicit call”、`harness_remote_host_test.dart`
  的 “stop closes the session; detach does not”）。
- **静态检查**：我在对方工作树跑
  `dart analyze lib/harness test/harness_herdr_*_test.dart test/harness_remote_host_test.dart`，
  结果只有基线契约里那条 `lib/harness/harness_host.dart:6 unnecessary_import`
  info，与 `pi-b.md` §6 一致（我未修改该文件）。
- **新增依赖**：无。`pubspec` 未改。

---

## 6. 与验收项对照（我的判断）

| AC | 结论 |
| --- | --- |
| AC2 Herdr 列表与状态 | 代码完成，字段形状与 `pi-b.md` §11 的只读探测一致；未在真实 Herdr 上验证（可接受）。 |
| AC3 打开面板实时刷新、输入立即送达 | **不成立**：默认没有 PTY 实现 → 1.5 s 快照（M1）；且 Windows 只剩管道后端时更明显。修 M1 后可达成。 |
| AC4 关闭视图不结束会话 | 通过（代码与用例一致）。 |
| AC5 结束需确认 | 契约层通过（`stop()` 是唯一结束路径），确认框属 Pi-C。 |
| AC6 手机端切换本机/已绑定电脑 | 数据源具备，但**远程终端是空屏**（H1），会话详情不可用。 |
| AC7 手机终端按键栏（含 Alt、粘贴） | `session:` 走原始字节，OK；`herdr:` 面板 Alt 不可用（L5），无粘贴语义（`pi-b.md` §4 已自述）。 |
| AC8 旧协议兼容 | 通过：wire 零改动。 |
| AC12 自动检查覆盖 Herdr 解析 | 基本覆盖；但终端与状态刷新两类用例缺失/失效（§4）。 |

---

## 7. 建议的处理顺序

1. **H1**（远程终端空屏）必须修，且要修对测试；否则远程会话详情页等于不能用。
2. **M1**（PTY 适配器落地）决定 AC3 是否达标，且需要与 Pi-A 的 `PtyLauncher` 合并。
3. **M2 / M3 / M4** 属用户可感知的正确性：重开死句柄、输入乱序、宿主 id 漂移。
4. **M5 / L1** 属资源与稳定性，合并前修一遍成本很低。
5. 其余 L 项可作为后续清理，但 L2（绕过 `HerdrActions`）建议顺手改，避免 wire 漂移。

以上均为静态审阅结论；H1 建议先用 `flutter test test/harness_remote_host_test.dart`
复现一次再动手（我按规则没有运行测试）。
