# Takeover CI C2：首页 Agents 的真实故障与改动清单

范围：core 工作树 `D:/MyNewProjects/_wt/mobile/int/qfli_studio_core`。
证据：`reports/takeover-core-check-failures-1.md`（18 条失败）、
`reports/takeover-log-45157553417-137634256261.txt`（原始日志）。
本 Pi 负责的 Home 组共 9 条，其中 1 条为未完成。

**本地未运行任何测试**，所有结论来自 CI 日志与代码阅读。
最后一阵由父级接管代码收尾，本文件只做记录。

## 1. 真实产品缺陷（不是测试问题）

### 缺陷：把订阅成功当成「主机已报列表」

`HomeAgentsTab._rebuild` 用 `_hub.isListening(host.id)` 判断该主机的行
能否让快照里的旧行让位：

```dart
final heard = <String>{
  for (final host in _hub.hosts)
    if (_hub.isListening(host.id) && _hub.sessionErrorOf(host.id) == null)
      host.id,
};
```

`isListening` 只表示**订阅动作已发起**（`_listening.contains(hostId)`），
不表示收到过任何一帧列表。`_sessions` 只在流回调里写入，订阅后到首帧之间
是真空白。

后果有两段：

1. 主机刚订阅、还没开口时，`heard` 已包含它，快照行因此当成陈旧数据丢掉，
   首屏闪一下空白。这正是「首屏先画快照」用例失败的场景，与快照存储本身无关。
2. 反过来，任何「用订阅状态推断数据状态」的调用方都会犯同一类错。

修复方向（父级已授权并实施）：`HarnessHub` 新增
`bool hasLoadedSessionsFor(String hostId) => _sessions.containsKey(hostId)`，
Home 的 `heard` 改用它。空列表同样会写入 `_sessions`，因此**有效空表仍然
清掉快照行**，契约不变。不要改用 `allSessions.isNotEmpty` 这路判断：
那会把有效空表当成「还没说话」。

## 2. 测试侧的真实问题

### 2.1 磁盘读取在假时钟里永远不会完成

`HomeAgentsTab` 首帧就 `_start()`：先 `snapshot.load()`，再
`StudioSessionIndex(root).read(...)`，两者都是真实 `dart:io`。
widget 测试跑在假时钟里，`dart:io` 的完成回调只在 `runAsync` 活动期间
投递。原用例的顺序是「假时钟里挂载 → 事后 `runAsync` 睡 30ms」，
挂载阶段发出的读盘请求等不到回调，行数恒为空。

日志证据（testID 1700「刷新后读到新增的内置会话」）：

- 10:38:57.276 开始。
- 之后该 testID 在整份日志里**再无任何输出**。
- 其余 suite 持续运行到 10:44:49 才停下。

原因：用例里 `await state.refresh()` 直接写在测试体里，而 `refresh()`
内部 `await _loadStudioSessions()` 等磁盘。假时钟下该 Future 永不完成，
用例永不返回。

正确做法（已在改动中采用）：

- 把**启动挂载**本身包进 `runAsync`，而不是挂载后在假时钟里补 sleep。
- 把 `refresh()` 的调用包进 `runAsync`。
- 就位判定改为**有界轮询**（`waitStudioRows`，上限 10 秒，`Stopwatch`
  计时），不再用 500ms 或固定 30ms 这类硬预算。

### 2.2 快照存储默认实现

未注入时用的是真实 `LocalFileBackend`，`read()` 经
`AppPaths.storageDirectory()` 触发 2 秒可写性探测，在假时钟里留下定时器。
改动让 `mount` 默认注入内存快照。

### 2.3 快照写回用例与真实 zone

`runAsync` 中挂载会让 `AgentsSnapshotWriter` 的防抖 `Timer` 落在真实 zone
上。只 `pump` 虚拟 3 秒不会推进它。改动为在 `runAsync` 内有界轮询
`backend.hasWrite`（同一个 `readyDeadline`，上限 10 秒）再断言，**产品防抖不变**。

### 2.4 语义标签精确匹配

`_StatusDot` 的 `Semantics(label:)` 与 `Tooltip(message:)` 叠加，语义树
合并后标签不是精确的状态词。改动：

- `Semantics(container: true, label: label)`。
- `Tooltip(message: label, excludeFromSemantics: true)`。

读屏仍能读到状态词，不止靠颜色。这是加强无障碍，不是削弱。

### 2.5 主机夹具无法表达「还没开口」

`FakeHarnessHost.watchSessions` 的 `onListen` 无条件 `add(_current)`，
一旦订阅就发一帧（往往是空表）。用空表去测「快照先顶上」与产品契约冲突。
改动新增 `emitInitialSessions`（默认 `true`，保持既有用例行为不变），
该快照用例设 `false`，用 `emitSessions(...)` 表示主机开口。

## 3. 已改文件

Core 工作树内，截至本文件写入时的 `git status`：

| 文件 | 性质 |
| --- | --- |
| `lib/harness/hub/harness_hub.dart` | 产品：新增 `hasLoadedSessionsFor` |
| `lib/harness/ui/home_agents_tab.dart` | 产品：`heard` 改用新判断，`_StatusDot` 语义容器化 |
| `test/support/fake_harness_host.dart` | 夹具：`emitInitialSessions`，默认 `true` |
| `test/harness/home_agents_tab_test.dart` | 用例：`runAsync` 包住启动与刷新、有界轮询、内存快照、空表用例 |
| `test/harness/home_agents_tab_live_status_test.dart` | 用例：同上，注入内存快照与 `remoteHostOpener` |

`test/sync/*` 三个文件的改动属他人（D 组），本 Pi 未触碰。

收尾状态：父级补完函数声明错位、`live_status` 的内存快照注入、
真实防抖等待、独立状态语义与延迟空列表断言，五个文件静态分析通过，
已提交 `21e61e0`。

## 4. 未验证部分（交接时必须知道）

1. **本 Pi 未运行任何测试。** 改动由父级接管收尾并完成静态分析，
   五个文件 `flutter analyze` 通过，已提交 `21e61e0`
   （Core 总 HEAD `0bf1ffaf22b8c0af88c22efd62bfbf0e74d9d428`）。
   云端结果见第 5 节：Home 组只剩语义用例的句柄时机问题，已由父级修正。
2. **快照「先顶上」用例的时序。** 依赖 `emitInitialSessions: false`
   加 `emitSessions` 的先后关系。云端已通过（第 5 节）。
3. **10 秒就位上限的经验值。** 快照写回与读盘就位共用同一个
   `readyDeadline`（10 秒）。取自「CI 机器上单次读盘应远小于 1 秒」，
   没有实测数据支撑，只是上限而非预算。
4. **语义用例。** `container: true` 加 `excludeFromSemantics: true` 的
   组合已在云端生效（标签断言通过），真机读屏验证仍待做。
5. **既有断言均保留**：快照先出现、主机列表替换后旧行消失、有效空表清掉
   旧行、排序、四态映射、不重读磁盘等判定条件一字未改，只调整了等待方式
   与夹具开口时机。

## 5. 云端验证结果（run 45164365603，Core `8d512245`）

Home 组已全部跑完，结论以 CI 的 check run 注解为准：

| 项 | 结果 |
| --- | --- |
| `runAsync` 内挂载与 `pump` 是否死锁 | **否，已证实不会**。Home 用例全部返回，不再出现 testID 挂死 |
| 刷新用例（原 1700 挂起点） | 已结束，不再是未完成 |
| 快照先顶上与有效空表清旧行 | 通过 |
| 磁盘就位与快照写回等待 | 通过 |
| 圆点语义用例 | **仅剩这一条**：`A SemanticsHandle was active at the end of the test.` |

唯一失败项的性质：**语义标签断言本身已过**，失败发生在断言之后。
原写法 `addTearDown(semantics.dispose)` 的回调排在框架不变量检查之后，
检查时句柄还活着。改为 `try/finally` 立即释放即对齐检查时机，
不涉及任何断言或产品代码。父级已改并提交 `d3d8995`
（`test(agents): release semantics before widget test invariants`）。

因此第 4 节第 1、2 条中的挂起担心作废：`runAsync` 内 `await pumpWidget` /
`pump` 的方案已由云端证明可行，不再作为待验证项。

## 6. 与 xcheck 记录的关系

`xcheck-c.md` 里记录过的「`detectDirty` 只比时间戳」等未修项与本次无关。
本文档第 1 节的缺陷是新增发现：此前没有任何 xcheck 记录指到
`_hub.isListening` 这个判断上。
