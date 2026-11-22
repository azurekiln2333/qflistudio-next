# check-d：Pi-A 分支互查（local host）

互查人：Pi-D。被查分支：`harness/pi-a`。
范围：`_wt/harness/pi-a/qfli_studio_core`（`harness/base..HEAD`，2 个提交，
28 文件 +4933 行）与 `_wt/harness/pi-a/qflistudio`
（`release/studio-git-ui-20261120..HEAD`，空）。
对照：`prd.md`（AC1–AC12）、`design.md`、`reports/brief.md`、
契约 `lib/harness/harness_host.dart`、`reports/pi-a.md`、
`spec/frontend/process-lifecycle.md`。

全程只读：没有改动对方工作树的任何文件，没有执行任何 git 写命令，也没有
在对方工作树里跑 `flutter pub get` / `flutter analyze` / `flutter test`
（会写 `.dart_tool`）。唯一执行的是 `dart format --output=none`，它只解析
不落盘。

## 1. 结论

**不建议直接进 P4 集成。** 三个问题需要先修：`sendLine` 的非 ASCII 截断
（D1）、Windows 下 stderr 全丢（D2）、`detach()` 后对话记录永久失效（D3）。
另有 AC1 在 Windows 上的能力缺口，需要 root 决策（见 D0）。

Pi-A 的报告基本诚实：契约未改、无新增依赖、风险章节主动披露了 Windows
无 ConPTY、`resize()` 恒 false、日志格式未对真实文件校验。下面这些问题
报告里没有提到，属于实现细节。

| 等级 | 数量 | 编号 |
| --- | --- | --- |
| 高（功能错误 / 验收不可能通过） | 3 | D0、D1、D2 |
| 中高 | 1 | D3 |
| 中 | 3 | D4、D5、D6 |
| 低 | 9 | D7–D15 |

## 2. 发现

### D0 [高] Windows 上 AC1 不可能通过：pipe 后端跑交互式 TUI

`lib/harness/local/pty_process.dart:236-247`（`createPtyLauncher`）、
`lib/harness/local/pty_process.dart:203-235`（`PipePtyLauncher`）。

Windows 只有 `pipe` 后端，子进程 `allocatesTerminal == false`。Claude Code、
Codex、Pi 的默认界面是 Ink/全屏 TUI，靠 `isTTY` 决定是否进入交互模式；管道
模式下它们要么拒绝启动、要么退化成一次性输出，AC1（三系统都能启动 shell /
Claude / Codex / Pi 会话）在 Windows 上无法达成。Pi-A 在报告风险 1 里已披露，
但这是验收阻断项，不应只写在风险里。

建议（二选一，需 root 决策）：

1. P5 之前补原生 ConPTY（`flutter_pty` 或 FFI 模块），`PtyLauncher` 已留好
   接入点，`StudioMux` / `LocalHarnessHost` 不需要改；
2. 过渡期让 `provider.available` 在 `strategy == 'pipe'` 时对
   `claude` / `codex` / `pi` 返回 false（或加 `requiresTty` 标记），界面因此
   不提供“启动”按钮，而不是启动一个必定卡住的会话。宁可显示“不支持”，
   也不要给用户一个假终端。

无论选哪条，`reports/pi-a.md` 的 AC1 一行都应从“未验证”改成“Windows 不
满足”，并同步给 Pi-C 的界面（不要渲染一个不能用的启动入口）。

### D1 [高] `sendLine` 用 UTF-16 码元写 PTY，中文提示词被截断成非法字节

`lib/harness/local/studio_mux.dart:158-160`

```dart
void sendLine(String text) {
  write(Uint8List.fromList(<int>[...text.codeUnits, 13]));
}
```

`String.codeUnits` 是 UTF-16 码元，`Uint8List.fromList` 只保留低 8 位。
`'修'`（U+4FEE）会变成 `0xEE`，`'复'` 变成 `0x0D`——**恰好等于回车**，
一行中文提示词会被拆成多行垃圾并按回车提交给 harness。所有非 ASCII 输入
（中文提示词、中文路径、emoji）都会中招。

链路：`HarnessSessionHandle.sendPrompt` → `_LiveSessionHandle.sendPrompt`
（`local_harness_host.dart:86-90`）→ `MuxSession.sendLine`。这是 hub 里
“给本机 harness 发提示词”的唯一路径，对一个中文优先的产品是硬伤。

修复：

```dart
void sendLine(String text) => write(Uint8List.fromList(<int>[...utf8.encode(text), 13]));
```

测试现状：`test/harness/local/studio_mux_test.dart` 的
`sendLine 写入文本并回车` 只用 `'ls'` 断言 `[0x6c, 0x73, 13]`，所以覆盖
不到这个 bug。补一条 `'你好'` → `utf8.encode('你好\r')` 的断言即可。

### D2 [高] `SupervisedPtyProcess` 只转发 stdout，stderr 全部丢弃

`lib/harness/local/pty_process.dart:249-257`

```dart
_subscription = _process.stdout.listen(...);   // stderr 没有订阅
```

`ManagedProcess` 内部把 stdout 与 stderr 都排空了（不会死锁），但
`SupervisedPtyProcess.output` 只接 stdout，stderr 的字节被丢弃。`script`
后端下 stderr 属于同一个 pty，看不到差别；**Windows 的 pipe 后端下 stderr
是独立管道**，而 Windows 又是本项目的主要开发平台。CLI 的报错、进度、
`npm`/`node` 的告警几乎都走 stderr，界面上的表现是“启动了但一直没有任何
输出”。

这也违反 `spec/frontend/process-lifecycle.md` §2/§3：
“Expose `ManagedProcess.stdout`, `stderr` …”“Drain stdout and stderr”。

修复：在同一个构造函数里订阅 `_process.stderr`，与 stdout 一起并进
`_output`（真实 PTY 下两者本就是同一设备，合并对 `script` 后端无副作用）。
补一条 fake process 的 stderr 转发测试。

### D3 [中高] `detach()` 会永久停掉日志跟随，重开会话拿不到对话记录

`lib/harness/local/local_harness_host.dart:101-105`、`:268-271`、`:312-313`、
`:427-431`

```dart
Future<void> detach() async {
  _detached = true;
  await _follower?.stop();     // 关闭 broadcast controller，取消 2 s 轮询
}
```

`_followers` 只在会话 `exited` 事件里移除（`:430`），`detach()` 不移除。
`open()` 仍然 `follower: _followers[sessionId]`，于是重开后：

- `transcript` 是一条**已关闭**的广播流，订阅者立刻收到 done，一条事件也没有；
- follower 已经不再轮询，之后的新事件永远不会出现。

hub 的常规操作就是“打开会话 → 关掉面板 → 再打开”，这条路径直接坏掉，
和 AC4“关闭视图不结束会话”的意图相悖（会话确实还活着，但结构化对话永久
丢失）。另外即使不 detach，`events` 是广播流、不重放，晚于 launch 打开的
会话也看不到已有事件。

修复：`detach()` 里 `_followers.remove(id)` 并停止；`open()` 时若 follower
为 null 或已停止则重建一个（`since` 用 `session.startedAt`，让 follower 能
重新找到同一个文件）。更好的做法是让 follower 自己缓存最近 N 条事件，新
订阅者先收 backlog。补一条 `launch → detach → open → transcript 非空` 的
回归测试。

### D4 [中] `watchSessions()` 不重放当前快照，后加入的订阅者最长空等 20 秒

`lib/harness/local/local_harness_host.dart:252-257`、`:392-404`

`_sessions` 是 `StreamController.broadcast()`，`watchSessions()` 直接返回
它的 stream；只有 `_emitSessions()` 时才 `add`。`_beginWatching()` 对首个
调用者会触发一次刷新，但 `_watching == true` 之后直接 `return`，不再发帧。

后果：第二个订阅者（`StreamBuilder` 重建、hub 在“本机 / 已绑定电脑”之间
来回切换、Agents 页面 dispose 后重建）在注册表加载完成到下一次
`refreshLogSessions()` 之间看到的是**空列表**，最长 20 秒（
`logRefreshInterval`）。契约没有要求有状态，但 `HarnessHost.watchSessions()`
的调用方（Pi-C）默认它是“当前列表的流”。

修复：缓存最后一次 `infos`，在 `onListen` 时补发；或改用 `Stream.multi`
让每个订阅者先拿一帧当前快照。补一条“两次 `watchSessions()` 都能拿到
非空首帧”的测试。

### D5 [中] 直播对话记录用“事件条数”当游标，窗口封顶后永久停更

`lib/harness/local/live_log_follower.dart:66-79`

```dart
final events = await reader.read(path, maxEvents: maxEvents);  // maxEvents = 2000
if (events.length < _delivered) _delivered = 0;
for (var index = _delivered; index < events.length; index++) { ... }
_delivered = events.length;
```

`read()` 返回的是尾部窗口（512 KiB）内、并且被 `maxEvents` 再截一次的事件。
一旦窗口里的事件数达到 2000 并保持封顶，文件继续追加时 `events.length`
恒等于 `_delivered`，**新事件永远不会推送**——长会话的对话记录会静默冻结。
反过来，窗口滑走导致条数变少时会 `_delivered = 0`，把整窗重推一遍。

修复：不要用条数做游标。让 `read()` 额外返回“本窗口第一个事件在文件中的
绝对行号”，或用事件 id 定位（`final i = events.indexWhere((e) => e.id == _lastId)`，
`i < 0` 时才回退到重推）。配合 D6 一起改。

### D6 [中] 事件 id 用窗口内下标，窗口滑动后 id 不稳定

`lib/harness/local/transcript_log_reader.dart:266-267`

```dart
String logEventId(String sessionBase, int index, [int part = 0]) =>
    part == 0 ? '$sessionBase#$index' : '$sessionBase#$index/$part';
```

`index` 是“本次读取窗口内的行号”，不是文件里的绝对行号。尾部窗口滚动后，
同一条消息的 id 会变；不同消息也可能拿到同一个 id。hub 若用 `id` 做列表
key 或去重，会出现列表跳动、消息重复或漏渲染。三个 reader 的“事件 id 稳定”
测试只覆盖“一次读取内不重复”，覆盖不到跨刷新。

修复：`readJsonlTail` 在丢弃半行时顺便统计被丢弃的行数，作为绝对行号偏移
传给 reader；id 用 `绝对行号` 而不是窗口下标。

### D7 [低] `enabled: false` 的用户覆盖项会被丢弃，无法关掉内置 provider

`lib/harness/local/harness_provider.dart:276`、`lib/harness/local/provider_registry.dart:117`

`HarnessProviderConfig.parse` 里 `if (spec == null || !spec.enabled) continue;`
把 `enabled:false` 的项直接扔掉，于是同 id 的覆盖项根本到不了
`ProviderRegistry.load` 的 `if (!spec.enabled) continue;`（那行对用户项是
死代码）。结果：配置里写 `{"id":"claude","executable":"claude","enabled":false}`
不会禁用 Claude，内置项照旧可用。

`README.md` 写的是“同 `id` 的用户项覆盖内置项”，schema 里也有 `enabled`，
行为和文档不一致。`provider_registry_test.dart` 的
`enabled 为 false 的项被丢弃` 把这个行为固化成了预期，测试反而挡住了修复。

修复：`parse` 只对“新增 id”丢弃禁用项，对同 id 的覆盖保留并让 `load()`
跳过；或者单独支持 `disabled: ["claude"]`。同时改那条测试。

### D8 [低] 用户对 `shell` 的 `executable` 覆盖被忽略

`lib/harness/local/provider_registry.dart:174-201`

`_resolveShell` 在 Windows 恒用 `powershell.exe`，POSIX 先看 `$SHELL`，
都不看用户给 `shell` 配的 `executable`。其余 provider 都遵守“同 id 覆盖”，
只有 `shell` 例外。修复：`spec.executable` 非空且不是内置默认值时优先。

### D9 [低] `_refreshTimer` 在 await 之后创建，dispose 期间的启动会漏一个常驻定时器

`lib/harness/local/local_harness_host.dart:392-404`

```dart
_watching = true;
await _ensureStarted();                      // 这里可能跨越 dispose()
_refreshTimer ??= Timer.periodic(...);       // dispose() 已经 cancel 过了
await refreshLogSessions();
```

`dispose()` 里 `_refreshTimer?.cancel(); _refreshTimer = null;` 之后，这个
`Timer.periodic` 仍会被建出来且永不取消。回调里 `refreshLogSessions()` 因为
`_disposed` 立刻返回，所以不会报错，但定时器常驻到进程结束。

修复：`await _ensureStarted(); if (_disposed) return;` 再建定时器。

### D10 [低] `_start()` 在 `await _registry.load()` 之后没有复查 `_disposed`

`lib/harness/local/local_harness_host.dart:406-437`

`_start()` 只在入口检查一次 `_disposed`。如果 `dispose()` 发生在
`await _registry.load()` 期间，随后仍会 `StudioMux(launcher: _launcher)`、
`mux.events.listen(...)` 并写 `_state.value`——`_muxEvents` 再也没人取消，
mux 也没人 dispose。测试里 `addTearDown(host.dispose)` 与启动竞争时可能偶发。

修复：每个 await 之后 `if (_disposed) return;`，并在返回前回收刚创建的 mux；
`_state.value = online` 前也补一次检查（dispose 之后写已 dispose 的
`ValueNotifier` 会抛）。

### D11 [低] `_sessions` 只增不减，退出会话连同 512 KiB 滚动缓冲常驻

`lib/harness/local/studio_mux.dart:305`、`:263-265`

会话进程退出后仍留在 `_sessions` 里（只有 `dispose()` 一次性 `clear()`），
每个 `MuxSession` 带一份默认 512 KiB 的 `TerminalScrollback`。
`LocalHarnessHost._emitSessions()` 也会一直把它们列出来。

长时间运行的桌面应用里，反复启动/结束会话会单调增长内存，列表里也堆满
`exited` 会话。修复：会话退出后保留一段时间（例如 10 分钟）或最多 N 条，
到期从 map 移除并 `session.dispose()`；或让 `maxSessionEntries` 同时约束
mux 侧。

### D12 [低] launcher 自己的 `ProcessSupervisor` 从未 dispose

`lib/harness/local/pty_process.dart:236-247`、`lib/harness/local/studio_mux.dart:225-233`

`LocalHarnessHost` 用 `StudioMux(launcher: _launcher)`，构造里
`_ownsSupervisor = launcher == null` → false，于是：
`StudioMux` 自己 new 的 `_supervisor` 没人 dispose（无害，没有子进程）；
`createPtyLauncher()` 内部 `shared = ProcessSupervisor()` 也没人 dispose。
子进程本身在 `LocalHarnessHost.dispose()` → `session.stop()` →
`ManagedProcess.cancel()` 里被杀掉，所以**不泄漏进程**；但
`process-lifecycle.md` §3 要求“Page or app disposal must call the
supervisor's idempotent `dispose()`”，这一条没做到。将来若某条路径忘了
stop 会话，就没有兜底。

修复：给 `PtyLauncher` 加 `Future<void> dispose()`，`LocalHarnessHost.dispose()`
里调用；`StudioMux` 只在真正自己创建 launcher 时才由自己管 supervisor。

### D13 [低] 历史会话的 transcript 是单订阅流且没有 `onCancel`

`lib/harness/local/local_harness_host.dart:126-152`

`_createController()` 用默认（单订阅）构造，只在 `onListen` 里 `_pump`。
UI 取消订阅后 controller 不会关闭，`_pump` 依然把整窗事件写进去（读到读完
为止，最多 400 条），这些事件缓冲在无监听者的 controller 里。第二次订阅
同一句柄会抛 “Stream has already been listened to”。

修复：`onCancel: () => controller.close()`；或直接暴露一次
`Future<List<TranscriptEvent>>` 快照 + 广播增量。

### D14 [低] 日志会话的 `status` 是刷新时快照，句柄打开后不更新

`lib/harness/local/local_harness_host.dart:24-40`、`:113-117`

`_LogEntry.status` 在 `refreshLogSessions()` 时算一次，`_LogEntry.info` 与
`_LogSessionHandle._status` 都用它。日志会话在两次刷新（默认 20 s）之间
结束/推进时，列表标签和句柄状态都是旧的；`open()` 里虽然会
`refreshLogSessions()`，但用的仍是同一个 `_entry` 快照。

修复：`open()` 后按 `entry.reader` 重算一次 `lastRole/pendingRequestId`
再初始化 notifier，或把状态更新挂到刷新回调上。

### D15 [低] `logSessionId` 只用文件名，跨目录同名会互相覆盖

`lib/harness/local/transcript_log_reader.dart:262-263`

`'log:$providerId:${p.basename(filePath)}'`。Claude / Pi 的日志目录按项目
编码分目录，理论上不同项目下可能有同名文件（实际是 UUID，概率低），一旦
同名，`_logEntries` 里后读到的会覆盖前一个，`open()` 打开错文件。

修复：用相对 `rootPath` 的路径（或加短 hash）。Claude 一个项目目录内
文件名唯一，跨项目才冲突。

## 3. 已验证无问题

- **契约未改**：`git diff --name-only harness/base..HEAD` 中唯一匹配
  `harness_host.dart` 的是 `lib/harness/local/local_harness_host.dart`。
  `HarnessHost` / `HarnessSessionHandle` / `HarnessTerminalChannel` 的成员
  全部实现，签名一致（`MuxSession.resize` 返回 `bool` 覆盖 `void` 是合法的，
  `bool` 是 `void` 的子类型）。
- **能力声明与实现一致**：直播会话只声明 terminal/transcript/prompt/stop
  （`d5305dc` 修掉了 `approve`）；历史会话只声明 transcript，`sendPrompt` /
  `reply` / `stop` 抛 `UnsupportedError`；`terminal` 为 null 与
  “没有 raw PTY”一致。没有虚报能力。
- **无凭证泄漏**：整份 diff 里没有 `print(` / `debugPrint` /
  `apiKey` / `token` / `password` / `secret` / `Authorization` 字样；
  诊断信息 `warnings` 只写 id、标签与错误类型，不写文件内容；
  日志读取器只读、不写、不回显正文（`transcript_log_reader.dart:1-10`
  的注释与实现一致）。
- **无 wire-protocol 改动**：本机 host 全部是进程内 Dart（进程 + 文件），
  没有新增 platform channel、socket、序列化协议；`PtyLauncher` 是纯 Dart
  抽象。Pi-C/Pi-B 的远程协议不受影响（AC8 无回归）。
- **无新增依赖**：只用了既有的 `services/process_supervisor.dart`、
  `services/app_paths.dart`、`package:path`、`flutter/foundation.dart`。
- **语法与格式**：`dart format --output=none --set-exit-if-changed
  lib/harness/local test/harness/local` → `Formatted 23 files (0 changed)`，
  说明 23 个文件都能解析。**注意**：我没有在对方工作树里跑
  `dart analyze` / `flutter test`，所以“零告警”“测试全绿”仍是 Pi-A 的
  自述，不是独立验证。
- **App 工作树无改动**：
  `git -C _wt/harness/pi-a/qflistudio log release/studio-git-ui-20261120..HEAD`
  为空，`git status --short` 干净，HEAD 就是 `d31ad29`。因此
  `git diff release/studio-git-ui-20261120..HEAD` 没有内容可审——本阶段
  确实没有 UI，UI 规则（`component-guidelines` 等）不在本次审查范围内。
- **测试**：9 个测试文件、约 60 个用例，覆盖注册表合并、PATHEXT 探测、
  `script`/`pipe` 命令组装、滚动缓冲、stop 幂等、idle→working、三个 reader
  的解析与尾部窗口、follower 的增量与 cwd 匹配、host 的 unsupported 分支。
  质量总体不错，夹具是手写而非真实日志（Pi-A 已披露）。

## 4. 缺失的测试（建议补）

| 对应 | 建议用例 |
| --- | --- |
| D1 | `sendLine('你好')` → `utf8.encode('你好\r')` |
| D2 | fake process 的 stderr → `output` 能收到 |
| D3 | `launch` → `detach` → `open` → `transcript` 非空且继续推送 |
| D4 | 连续两次 `watchSessions()`，第二次也能拿到非空首帧 |
| D5 | 写入 > `maxEvents` 条事件后继续追加，仍能收到新事件 |
| D6 | 两次读取（窗口已滑动）同一条消息的 id 相同 |
| D7 | 同 id + `enabled:false` 的覆盖项能禁用一个内置 provider |
| D9/D10 | `dispose()` 与 `_ensureStarted()` 竞争后没有遗留定时器/订阅 |
| D11 | 会话退出后从 `mux.sessions` 移除（或超出上限时淘汰） |
| D12 | `LocalHarnessHost.dispose()` 后 launcher 的 supervisor 已 dispose |

另外建议补一条 `LocalHarnessHost` 的“第二个 `open()` 返回的句柄能独立
`detach` 而互不影响”——当前 `_LiveSessionHandle._detached` 是每句柄一份，
逻辑上没问题，但没有测试固定这个语义。

## 5. 与 AC 的对应

| AC | Pi-A 相关部分 | 状态 |
| --- | --- | --- |
| AC1 | 三系统启动 shell / Claude / Codex / Pi | **Windows 不满足**（D0）；macOS/Linux 未真机验证 |
| AC4 | 关闭视图不结束会话 | 进程语义正确，但对话记录会丢（D3） |
| AC5 | 结束会话需确认 | 契约要求调用方确认，Mux 不自作主张；OK |
| AC11 | 配置添加未识别 harness | 解析与合并有单测；禁用内置项不可用（D7） |
| AC12 | 自动检查 | 测试已写，未运行（CI 归属 root） |

AC2/AC3 属 Pi-B（Herdr），AC6–AC8 属 Pi-C/远程，AC9/AC10 属 Pi-D，
不在本次范围。

## 6. 说明与限制

- 只能静态审查：没有真实启动 `script`/`pipe` 子进程，也没有真实
  Claude/Codex/Pi 日志可对。D0/D2 的结论来自代码路径与 node CLI 的
  `isTTY` 行为，不是实测。
- 我按“最小惊讶”给等级：能导致用户可见错误或验收不通过的记高；
  只在特定时序/长会话下出错的记中；泄漏、文档不一致、边界记低。
- 若 root 决定 P4 直接合入，**至少**要修 D1、D2、D3，并把 D0 的结论同步给
  Pi-C，避免界面渲染出必定失败的启动入口。
