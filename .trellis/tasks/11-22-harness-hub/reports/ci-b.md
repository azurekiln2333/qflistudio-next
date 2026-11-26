# CI 修复：核心测试套件挂起（B 区）

## 0. 结论

找到三条能让测试进程不退出的原因，全部已修。

根因不在断言本身。是一条**空转的刷新循环**：`agent wait` 立刻返回时，循环没有间隔地重读列表再等待。断言失败时泄漏的循环更糟：测试进程永远退不出，CI 看到的是挂起而不是失败。

三条根因与提交：

| # | 根因 | 提交 |
| --- | --- | --- |
| 1 | `agent wait` 立即返回时刷新循环空转，且睡眠用的是不可取消的定时器 | `1d35375` |
| 2 | 远程 Codex 定时器在第一帧取消时计数不减，定时器永不停止 | `dede7b2` |
| 3 | 用例只在成功路径释放主机，断言一失败就把循环和定时器留在进程里 | `323f224` |

只做了静态检查，没有跑任何测试。契约与别人的文件都没有动。

## 1. 审计范围

- `lib/harness/herdr/**`
- `lib/harness/remote/**`
- `test/harness_herdr_cli_test.dart`
- `test/harness_herdr_host_test.dart`
- `test/harness_herdr_input_test.dart`
- `test/harness_herdr_models_test.dart`
- `test/harness_herdr_platform_test.dart`
- `test/harness_herdr_terminal_test.dart`
- `test/harness_remote_host_test.dart`

逐项检查的清单如下：

- 无限刷新的循环。
- 周期定时器。
- 未取消的订阅。
- 永不完成的 completer。
- 真实进程与真实 PTY。
- 真实家目录扫描。
- `pumpAndSettle` 与重复动画。
- 缺释放。

## 2. 根因 1：刷新循环空转（`1d35375`）

### 现象

`HerdrHost._runLoop` 每轮做三件事：刷新列表、挑出工作中的 agent、对它跑一次 `agent wait`。

`agent wait` 可能在**几毫秒内**就返回。它超时了、窗格没了、服务端报错了，三种情况都是立刻返回。

旧代码在 `wait` 返回后直接进入下一轮：

- `herdr_host.dart:432` 的 `_waitQuietly` 只 `catch` 了 `HerdrException`，没有任何间隔。
- 于是 刷新、等待、刷新、等待 连续跑，每次一个 CLI 进程。

测试里的假 CLI 就是这种行为：`test/harness_herdr_host_test.dart` 的 `agent list` 固定给一个 `working` 的 agent，`agent wait` 立刻回 `{"error":{"code":"timeout"}}`。

结果：循环全速空转，`waitRequests` 无限增长。

### 危害

- 单核打满，日志列表无限增长。
- 断言失败时测试进程永远退不出。CI 看到的是 45 分钟超时，而不是一条失败的用例。
- 生产侧同样成立：Herdr 服务端报错时应用会持续拉起 CLI 进程。

### 修复

`lib/harness/herdr/herdr_host.dart`

- `herdr_host.dart:53` 与 `:75` 新增 `waitFloor`，默认 250 ms。
- `herdr_host.dart:432` 的 `_waitQuietly` 用 `Stopwatch` 量这次 `wait` 花了多久，不足 `waitFloor` 就补睡差额（`:450`）。
- 语义：`waitBudget` 限制“状态最多陈旧多久”。`waitFloor` 限制“每秒最多问几次”。真正常阻塞的 `wait` 不会因此变慢。

### 回归测试

- `test/harness_herdr_host_test.dart:314`：400 ms 窗口内新增的 `wait` 少于 6 次。旧代码是上千次。
- `test/harness_herdr_host_test.dart:320`：`dispose` 之后不再有任何 CLI 调用。

## 3. 根因 1b：睡眠定时器不可取消（同一个提交）

`HerdrHost._sleep` 旧实现是 `Future.any([Future.delayed(d), wake.future])`。

`Future.delayed` 建的是普通定时器，`Future.any` 只丢弃结果，**不会取消定时器**。释放主机时 `_wake.complete()` 让 `_sleep` 立刻返回，但那个定时器还挂在队列里，最长 `idleRefresh`（默认 30 s）。

`dart test` 的进程要等事件循环空了才退出，于是每个用例多拖 20 到 30 秒。几个用例叠加就是分钟级延迟，正好对应“之前 4 分钟”。

### 修复

`herdr_host.dart:454` 自己持有 `Timer`（`:461`），`Future.any` 返回后立刻 `timer.cancel()`。释放主机不再留下任何待触发的定时器。

## 4. 根因 2：远程轮询定时器计数不归零（`dede7b2`）

`RemoteHarnessHost.watchSessions` 用 `Stream.multi` 包一层，靠 `_watchCount` 决定何时停 `Timer.periodic(refreshInterval)`（默认 20 s）。

旧代码的顺序是：先 `controller.add(_latest)`，**之后**才挂 `controller.onCancel`。

消费方若在第一帧就取消（`.first`，或建好立刻拆掉的界面），取消回调可能还没挂上。`_watchCount` 只增不减，`_stopCodexTimer` 永远不执行。

结果是进程里留一个永不停止的周期定时器。测试进程同样退不出，反射到 CI 就是挂起。

### 修复

`lib/harness/remote/remote_harness_host.dart:120`：先挂 `onCancel`，再发第一帧（`:126`）。计数同时加了 `> 0` 保护（`:122`），重复取消不会变负。

## 5. 根因 3：用例只在成功路径释放主机（`323f224`）

所有用例都写了 `await host.dispose()`，但都在用例**末尾**。

只要中间任何一条 `expect` 失败，后面的释放就不执行。此时：

- 刷新循环还在跑（根因 1）。
- 快照终端的 1.5 s 周期定时器还在跑。
- 主机的会话流订阅还开着。

进程于是永远不退出，CI 只能等到超时。

### 修复

`test/harness_herdr_host_test.dart`

- `_host()` 工厂（`:215`）统一 `addTearDown(host.dispose)`。断言失败也释放。
- 三条直接构造的主机（`:247`、`:489`、`:507`、`:574`、`:591`）逐个补 `addTearDown`。
- `_sessions()`（`:230`）改为用完 `cancel()` 订阅。旧实现让它一直挂着。
- `testT()`（`:220`）把每个用例包上 15 s 超时：卡住的 `await` 立刻变成失败，而不是把 CI 拖到超时。

`test/harness_remote_host_test.dart`

- `testT()`（`:378`）同样是 15 s 超时。
- `tracked()`（`:382`）在构造处就登记 `addTearDown`，16 处单行构造与 2 处多行构造全部改用它。

超时用的是 `Future.timeout`，不依赖 `Timeout` 类型，测试文件仍然只导入 `flutter_test`。

## 6. 检查后判定安全的部分

- `test/harness_herdr_cli_test.dart`：`_FakeHerdr` 全程替换 runner，没有真实进程。
- `test/harness_herdr_platform_test.dart`：`environment`、`isExecutable`、`listDirectory` 全部注入，不读真实环境也不扫家目录。
- `test/harness_herdr_input_test.dart` 与 `test/harness_herdr_models_test.dart`：纯函数，无 I/O。
- `test/harness_herdr_terminal_test.dart`：没有调用 `start()`，周期定时器从未启动。`_drain` 的 12 ms 延迟链有界，队列空了就结束。
- `HerdrSnapshotTerminal.close()` 不等 `_draining`。卡住的发送拖不住释放。
- 两个测试文件里的轮询辅助函数都有上界（200 次或 100 次，每次 5 ms），不会无限等。

## 7. 未验证

- 没有跑 `flutter test`。所有结论来自静态阅读和代码路径推理。
- 45 分钟这个量级我没有本机复现。我能确认旧代码有无界循环与不可取消定时器两类问题。这两类只能靠超时收敛。
- 修复后 CI 是否恢复到分钟级，需要下一次流水线确认。

## 8. 改动面

只有四个文件，都在我的范围里：

- `lib/harness/herdr/herdr_host.dart`
- `lib/harness/remote/remote_harness_host.dart`
- `test/harness_herdr_host_test.dart`
- `test/harness_remote_host_test.dart`

静态检查：`dart format` 四个文件 0 changed。`flutter analyze --no-pub` 覆盖 `lib/harness/herdr`、`lib/harness/remote` 与上述四个测试文件，无告警。

提交时只 `git add` 了自己的路径。同一工作树里其它 Pi 的改动（`test/harness/local/**`、`test/harness/harness_hub_test.dart`、`test/harness/hub_ui_test.dart`）没有碰。

## 9. CI 修复轮次 1（run 45014758649，core `54bbfe6`）

### 结论

本轮没有一条失败属于我的范围，零改动，零提交。

### 判据

`ci-failures-1.md` 列出 10 条失败，按文件分：

| 测试文件 | 条目数 | 归属 |
| --- | --- | --- |
| `test/harness/hub_ui_test.dart` | 5 | Pi-C |
| `test/harness/harness_hub_test.dart` | 1 | Pi-C |
| `test/experience_test.dart` | 1 | Pi-C |
| `test/editor_agent_embed_test.dart` | 1 | Pi-C |
| `test/trellis_context_test.dart` | 1 | Pi-C |
| `test/github_repository_picker_test.dart` | 1 | Pi-A |

我的四个测试文件（`test/harness_herdr_cli_test.dart`、`harness_herdr_host_test.dart`、`harness_herdr_input_test.dart`、`harness_herdr_models_test.dart`、`harness_herdr_platform_test.dart`、`harness_herdr_terminal_test.dart`、`harness_remote_host_test.dart`）一条都没出现。

### 根因不在我这边的依据

两个 hub 测试文件只导入 `../support/fake_harness_host.dart`。它们不构造 `RemoteHarnessHost`，也不构造 `HerdrHost`。

我已读到 `test/harness/hub_ui_test.dart:11-27` 的导入表与 `test/harness/harness_hub_test.dart` 的 12 处主机构造，全部是 `FakeHarnessHost`。

因此 `lib/harness/remote/remote_harness_host.dart` 的取消计数修正与 `lib/harness/herdr/herdr_host.dart` 的等待地板都进不了这两条路径。

### 交接线索（留给 Pi-C）

`harness_hub_test.dart:159` 要求 `currentHostId == 'remote-pc'`。

`harness_hub.dart:556-557` 却优先返回内置 Agent 主机。这一段由 `92ab3cb` 引入，与测试的期望相反。

测试第 158 行已经断言主机列表是 `['studio', 'remote-pc']`，所以分歧点只在默认选中项。要么改测试，要么改 `_pickInitialHost` 的优先顺序，属于 hub 层，不在我的范围。

### 状态

工作树在 `54bbfe6` 上干净。本轮未做静态检查，因为没有改动。

## 10. CI 修复轮次 2（run 45018665003，core `d061253`）

### 结论

本轮 10 条失败，没有一条在我的范围。零改动，零提交。

### 判据

`ci-failures-2.md` 的 10 条按文件分：

| 测试文件 | 条目数 | 归属 |
| --- | --- | --- |
| `test/harness/hub_ui_test.dart` | 7 | Pi-C |
| `test/studio_agent_host_test.dart` | 1 | Pi-C |
| `test/retained_editor_test.dart` | 1 | Pi-C |
| `test/experience_test.dart` | 1 | Pi-C |

我的六个 herdr 测试文件与 `test/harness_remote_host_test.dart` 仍然一条都没出现。

### 我的代码进不了这些路径

分两步检查。

第一步，`test/harness/hub_ui_test.dart` 的导入表只有 `../support/fake_harness_host.dart`。

第二步，我查了 `lib/harness/ui/*.dart` 的全部导入。没有一处导入 `harness/herdr` 或 `harness/remote`。

唯一沾边的一行是 `hub_terminal_view.dart:13`。它引用 `remote_control/theme/remote_theme.dart`，与我的两个目录无关。

所以 `herdr_host.dart` 的等待地板与 `remote_harness_host.dart` 的取消计数都到不了这些用例。

### 交接线索（留给 Pi-C）

七条失败集中在同一个文件。它们都构建 hub 的会话页与 agents 面板，共享同一套装配。

`d061253`、`a458e86`、`5c13ff1` 三条提交已经在动这几条路径，说明问题正在处理。

上一轮的 `harness_hub_test.dart` 失败已由 `5c13ff1` 解决。做法是把期望改成内置 Agent 默认，即承认 `_pickInitialHost` 的优先顺序，与 `harness_hub.dart:556` 一致。我上一轮记的分歧点因此关闭。

### 状态

工作树在 `d061253` 上干净。本轮没有改动，因此没有静态检查可跑。

## 11. CI 修复轮次 3（run 45020548229，core `2ab7d2e`）

### 结论

本轮我这边 4 条失败，两条根因，两个提交。

| 失败 | 根因 | 提交 |
| --- | --- | --- |
| `test/harness_herdr_platform_test.dart` 三条 | `_join` 用 `Platform.pathSeparator`，不认注入的平台 | `093f771` |
| `test/harness_remote_host_test.dart` 的 herdr 窗格用例 | 用例用 `String.fromCharCodes` 解 UTF-8 字节 | `1a86498` |

### 根因 1：路径拼接不认注入的平台（`093f771`）

`lib/harness/herdr/herdr_platform_io.dart` 的 `_join` 用 `Platform.pathSeparator`。CI 跑在 Linux，分隔符是 `/`。

`locateHerdrExecutable` 与 `executableOnPath` 的其余规则都按注入的 `isWindows` 走。偏偏拼接这一步看宿主机。

后果：Windows 用例在 Linux runner 上拼出 `D:\ProgramFiles\herdr-windows-x86_64/herdr.exe`。探针永远匹配不上，函数于是返回 null。

三条失败同源：

- `executableOnPath accepts a Windows npm shim`：`...npm/claude.cmd` 与 `...npm\claude.cmd` 不等。
- `falls back to PATH and handles quoted Windows entries`：`D:\Program Files\herdr/herdr.exe` 不等。
- `finds a versioned herdr-* directory under Program Files`：同上。

修法：`_join(base, leaf, windows, [more])` 按 `windows` 选分隔符，即 `\` 或 `/`。

生产行为不变。真 Windows 上 `Platform.isWindows` 为真，真 Linux 上为假。变的是接缝：Windows 规则从此能在任意 runner 上验证。

### 根因 2：用例按码位解 UTF-8 字节（`1a86498`）

`RemoteTerminalChannel._emit` 把屏幕文本 `utf8.encode` 成字节。`π` 占两字节。

用例用 `String.fromCharCodes(data)` 逐字节转字符，得到 `Ï\x80`。于是 `contains('π > ready')` 失败。

同一文件另有两处同样的解码。那两处屏幕是 `PS> ` 这种纯 ASCII，碰巧能过。

修法：加 `_text()` 包一层 `utf8.decode(data, allowMalformed: true)`，三处都改用它。

生产代码没有错，错在用例的解码方式。

### 不在我这边的 6 条

- `test/github_auth_controller_test.dart` 两条，归 Pi-A。
- `test/project_card_cloud_actions_test.dart`、`test/retained_editor_test.dart`、`test/harness/hub_ui_test.dart`、`test/experience_test.dart`，归 Pi-C。

### 静态检查

`dart format` 两个文件 0 changed。

`flutter analyze --no-pub` 覆盖 `herdr_platform_io.dart`、`test/harness_remote_host_test.dart`、`test/harness_herdr_platform_test.dart`，无告警。

没有跑任何测试。

### 状态

两个提交已入分支，工作树干净。
## 12. CI 修复轮次 5（run 45023383633，core `79babb3`）

### 失败的用例

`test/harness_remote_host_test.dart` 的 `Herdr panes on the paired computer replay snapshots and send keys`。

报错为 `expected: contains 'sendKeys:w37:p14:up'`，`actual: ['refresh']`。

### 根因

`HerdrSnapshotTerminal.write` 把输入放进队列。

`_drain` 先等 12 ms 再合批发送。

用例写完 `ESC [ A` 只等 10 ms 就断言。

12 ms 的窗口还没到，`sendKeys` 一次都没发。

所以断言必然早于发送。这不是偶发，是每次必败。

`actual` 只有 `['refresh']`，正好说明连一次发送都没发生。

同一个目录的 `test/harness_herdr_terminal_test.dart` 都等 30 ms 或 40 ms。

这两处等待都在 12 ms 窗口之外。

用例的等待写错了。

生产代码的 12 ms 合批是设计选择。注释写明：让一串按键落在一次批里。

60 Hz 下一帧 16.7 ms，12 ms 的延迟看不出来。

### 修法（`02ec298`）

加 `_waitUntil(bool Function())` helper。它是 200 次、每次 5 ms 的有界轮询。

`_waitFor` 改为复用它，语义不变。

`sendKeys` 断言改成等调用落地，等不到再断言失败。

同一条用例里 `π > ready` 的 100 次手写轮询换成 helper。

### 静态检查

`dart format` 该文件 0 changed。

`flutter analyze --no-pub test/harness_remote_host_test.dart` 无告警。

没有跑任何测试。

### 状态

提交 `02ec298` 已入分支。工作树里只留下其它 Pi 的文件。

### 不在我这边的 5 条

`test/retained_editor_test.dart`、`test/service_configuration_test.dart`、`test/experience_test.dart`、`test/editor_cloud_open_lifecycle_test.dart`、`test/project_card_cloud_actions_test.dart`。
