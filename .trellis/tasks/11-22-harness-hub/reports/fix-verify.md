# 修复复核：F1 到 F4

**结论：四条发现的功能修复全部到位，可以合并。只剩报告与提交历史不同步这一条文档问题。**

复核对象：`harness/integration` 在 `92ab3cb`（core）与 `4142a7d`（app）之后的新提交。
对照 `reports/integration-check.md` 的 §5 发现清单与 §9 修复记录。
方式：只读。读代码与 `git log`／`git diff`／`git show`，跑两条作用域受限的
`flutter analyze --no-pub`。未改文件，未跑 git 写命令，未跑测试与构建。

复核期间 core 分支的历史被重写过一次（见 §1.2）。本报告以复核结束时的 HEAD
`242a2ae` 为准，过程中的中间状态不计入结论。

## 1. 实际提交序列

### 1.1 最终状态

core 在 `92ab3cb` 之后有五条提交：

| 提交 | 标题 | 覆盖 | 与 §9 记录一致 |
| --- | --- | --- | --- |
| `1340b40` | fix(harness): subscribe host sessions lazily and open the remote host on demand | F1 | 是 |
| `48e0ae7` | fix(harness): let the herdr host release the pty factory it was given | F2 | 是 |
| `86380c7` | fix(harness): await host shutdown before the app exits | F3 | 是 |
| `65eb461` | fix(harness): keep the remote host build error out of release logs | F4 | **哈希不同** |
| `242a2ae` | fix(harness): hide the remote placeholder once a computer is reachable | F1 补充 | **§9 未列** |

app 在 `4142a7d` 之后没有新提交。F3 的退出钩子落在 core 的 `lib/app.dart`
（`QfliApp` 就在这个文件里），app 只需照旧 `runApp(QfliApp(...))`，所以 app
不需要改动，与 §9.3 的描述一致。

### 1.2 复核期间发生的重写

我第一次读历史时看到的是四条提交，其中 F4 的修复挂在一条标题为 F1 的提交
（`004a44c`）上，而 §9 记录的 `448cbf3` 不在分支里。复核末尾再读，历史已经变成
上表的五条：`448cbf3` 的内容以正确的标题重新提交为 `65eb461`，原来混在
`004a44c` 里的那 5 行界面补充单独成为 `242a2ae`。

`004a44c` 与 `448cbf3` 现在都没有任何分支包含，是被丢弃的旧对象。当前 HEAD
的内容与我在中间状态读到的完全一致，只有提交边界变了：`242a2ae` 的 diff
（`hub_agents_surface.dart`，+5 行）就是原先混在 `004a44c` 里的那一段。

结论不受影响，但这段历史变化说明有人在复核进行中改写了分支。如果还有别的
复核者在同时读这个分支，结论可能对不上。

### 1.3 只剩的文档问题：§9 的提交表

`integration-check.md` §9 的表格列了四条提交，与最终历史有两处出入：

1. F4 记的是 `448cbf3`，实际是 `65eb461`。
2. `242a2ae`（占位芯片的补充）没有列。

功能与追溯都还能对上（标题正确、内容唯一），只是哈希过期、少一行。建议在
合并前把 §9 的表格按上表改掉，或在 `final-review.md` 的提交序列里一并补上。
不需要改代码，也不需要改写历史。

## 2. 逐条核对

### F1（中）订阅与远程连接改成按需 —— 已修

**懒订阅**（`lib/harness/hub/harness_hub.dart`）：

- `_attachHost`（540-547）只挂状态监听，注释写明「会话订阅不在这里建立」。
  原实现在这里直接 `_listen(host)`，这是扇出的第一个源头，现已移除。
- 构造函数（149-152）只对 `_pickInitialHost` 选中的那一台调 `ensureListening`。
- `ensureListening`（251-257）与 `isListening`（260）成对提供，幂等。
- 订阅入口齐备：`selectHost`（243）、`openSession`（383）、`launch`（420）、
  `addHost`（535，仅当它成为当前主机时）、`refresh`（465-470 只对已订阅的）。
- `refresh` 里的 `if (!_listening.contains(host.id)) continue`（468）跳过没在看的
  主机，与文档注释一致。
- `allSessions`（303-306）的注释写明新语义：只包含订阅过的主机。

测试直接断言 `isListening` 的真假（`test/harness/harness_hub_test.dart:145-169`），
覆盖「首屏只订阅当前主机」「切过去才订阅」「刷新不唤醒未访问主机」。

**远程延后 attach**（`lib/harness/ui/hub_agents_surface.dart`）：

- `initState` 里原来那句 `unawaited(_attachRemoteHost(opener))` 已不存在，
  全文已无 `initState`。
- 改成 `_openRemote()`（63-88），只在用户点占位芯片时执行，带 `_remoteConnecting`
  防重入、`_remoteUnavailable` 标记失败。
- 连上后 `addHost` + `selectHost`（83-87），并且先判 `hostById == null`，因为 hub
  在平台不可见或 id 重复时会直接释放新主机，那时不能切过去。这个细节处理得对。
- 失败后 `_remoteEntry`（92-97）转去 `onAddComputer`，不会反复空转。

**占位芯片**（`lib/harness/ui/hub_host_switcher.dart:16-37,48,79-83`）：
新增 `onOpenRemote`／`remoteConnecting`／`remoteUnavailable` 三个参数与
`hub-host-pending-remote` 芯片，连接中禁用点击。一台可见主机都没有时
（手机端未配对）主机条不再整块消失，补了入口。

**补充提交**（`242a2ae`）：已绑定电脑出现在列表后占位芯片让位，避免同一台电脑
出现两个入口（`hub_agents_surface.dart:90-96`）。逻辑正确。

**回归风险已排查**：界面只读当前主机的会话（`hub_agents_surface.dart:398`、
`hub_session_list.dart:293,375`），而当前主机一定已订阅。
`providersOf`／`launchMenu`（324-357）直接向主机要 provider，与订阅无关，所以
「新建会话」菜单不受影响。这两处我特意去看，没有命中。

### F2（低）PTY 工厂释放 —— 已修

- `HerdrHost` 新增可选参数 `disposePtyFactory`（`herdr_host.dart:49,78`），
  `dispose()` 末尾调用（290），失败被吞掉不阻断其它收尾（291-293）。
- 装配点把同一个实例传给两处（`default_harness_hosts.dart:57-58`）：
  `StudioMuxPtyFactory()` 既作 `ptyFactory`，又作 `disposePtyFactory: pty.dispose`。
  所有权写法与 `LocalHarnessHost._ownsLauncher`、`OwnedRemoteHarnessHost` 一致。
- 没有改 `HarnessPtyFactory` 共享接口本身。这个判断正确：往共享接口加方法会波及
  所有实现，用回调传「谁来放」更稳。
- 测试两条（`test/harness_herdr_host_test.dart`）：正常释放，以及工厂抛异常时
  主机仍能释放完。

### F3（低）可等待的退出收尾 —— 已修

- `HarnessHub.dispose()` 依然同步、幂等，但把释放 future 存进 `_shutdown`
  （589），并在 `_openHubs` 里注销自己（573）。
- `shutdown()`（599-604）返回那个 future；从未 dispose 过时先 `dispose()` 再返回。
- `shutdownOpenHubs()`（212-216）遍历活着的 hub 逐个 `await`。
- `_drain`（607-615）逐个 `await` 并吞掉单台主机的失败，避免一台失败挡住其它
  子进程的收尾。
- `HerdrSessionHandle.dispose()` 从 `void` 改成 `Future<void>`，真的
  `await _terminal.close()`（`herdr_session.dart:123-131`）。
- `HerdrHost.dispose()` 逐个 `await handle.dispose()`（280-283）。这才是等到
  `herdr agent attach` 客户端被 kill 的地方。
- 退出钩子接在 `lib/app.dart`：`AppLifecycleListener(onExitRequested:)`（71），
  `_onExitRequested`（81-88）先 `await HarnessHub.shutdownOpenHubs()` 再返回
  `AppExitResponse.exit`，`dispose` 里释放监听器（109）。

### F4（低）发布版日志 —— 已修

`default_harness_hosts.dart:75-80` 的 `debugPrint` 已包进
`assert(() { ...; return true; }())`，与 `harness_hosts.dart` 的兄弟写法一致，
发布版不再输出异常与堆栈。

## 3. 未改动面确认

| 项 | 结果 |
| --- | --- |
| 契约 `lib/harness/harness_host.dart` | `git diff 92ab3cb..HEAD` 为空，仍与基线逐字节一致 |
| `lib/remote_control/**` | 这五条提交零改动 |
| `pubspec.yaml`／`pubspec.lock` | core 与 app 均无改动，没有新增依赖 |
| app 分支 | `4142a7d` 之后无新提交，只有 7 个插件注册文件的换行差异（未提交） |

## 4. 静态检查

```text
core  flutter analyze --no-pub lib test   → 2 条既有 info
      lib/chat/composer_card.dart:346   curly_braces_in_flow_control_structures
      lib/harness/harness_host.dart:6   unnecessary_import（契约文件，按约定保留）
app   flutter analyze --no-pub lib        → 1 条既有 info
      lib/main.dart:3                   unnecessary_import
```

没有新增告警。五条提交改动的 10 个文件都在分析范围内。工作树在分析后仍然干净。

## 5. 仍然存在的风险

1. **F3 只对桌面端有效**。`AppLifecycleListener.onExitRequested` 是否被 Windows
   runner 触发、`Alt+F4` 与系统关机两条路径是否都走到，需要真机确认。§9.7 已写，
   我认同。
2. **F1 改变了 `allSessions` 的覆盖面**。现在只含订阅过的主机。当前没有界面用它，
   将来若做「全部会话」页，必须先对每台 `ensureListening`。文档注释已写，属约定
   风险。
3. **`_openHubs` 是静态登记表**。hub 在构造函数里登记，`dispose` 里注销。若某页
   异常退出而没有 dispose，登记表会留住该 hub 与它的主机，直到退出钩子一次性
   收尾。影响有限，但属隐式生命周期约定。
4. **F5／F6 按要求未处理**：只支持一台已绑定电脑；`studioAppServices` 仍是 app 层
   可变全局。两条都是备注级。
5. **复核期间分支被改写**。若还有其他人在读同一分支，需要重新对齐结论。

## 6. 总评

F1、F2、F3、F4 的功能修复都能在代码里对上，改动位置与 §9 的描述一致，没有夹带
无关修改，契约、远程协议、依赖面都没动。新增与改写的用例在数量和意图上对得上
（hub 4 条、界面 2 条、herdr 2 条，另修了 6 条因默认主机变更而失效的旧断言）。

唯一的缺陷在文档侧：`integration-check.md` §9 的提交表里 F4 的哈希是
`448cbf3`（已不在分支上，实际为 `65eb461`），且漏列 `242a2ae`。功能、追溯都能
对上，改一下表格即可。

**判定：通过，可以合并。** 合并前建议把 §9 的提交表按 §1.1 更正。