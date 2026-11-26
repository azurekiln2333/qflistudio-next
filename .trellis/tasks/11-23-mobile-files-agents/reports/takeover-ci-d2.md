# CI 修复 D2：Core 同步组

范围：`test/sync` 下的四条同步失败。

工作树：`D:/MyNewProjects/_wt/mobile/int/qfli_studio_core`，分支 `mobile/integration`。

证据：

- `reports/takeover-core-failures-1.md`，App 流水线 45157553417，Core `f434128`。
- `reports/takeover-core-check-failures-1.md`，Core-check 流水线 45157266417，
  Core `f434128`。

## 1. 结论

四条失败全部出在测试写法上。产品代码没有改，一行都没有。

| 失败 | 改法 |
| --- | --- |
| `device_sync_dialog_test` 两条 | 真磁盘 I/O 放进 `runAsync`，等待改为有上限 |
| `device_sync_failure_test` 两条 | 同上 |
| `device_sync_test` 的 `evict removes the least recently used copy` | 夹具预算 150 改为 250 |

## 2. 根因一：假异步区里等真磁盘

`testWidgets` 跑在假异步区里。`runDeviceSync` 第一步就要读磁盘：

```dart
plan = await service.plan(remoteRoot: ..., localRoot: ...);
```

`plan()` 的 `_listLocal` 走 `root.exists()`、`list()`、`stat()`、`openRead()`，
全是 `dart:io` 的真 Future。这些 Future 在假异步区里不会完成，
于是 `plan()` 挂住，确认框从没出现，`find.text('开始同步')` 找到 0 个。

第二条用例的十分钟超时是同一条链路：它在 `runAsync` 里把文件写进磁盘，
出了 `runAsync` 再去点界面，界面那一轮又回到假异步区，再次挂住。

还有一条独立的死锁。`runDeviceSync` 跑完 `apply()` 会弹结果框，
`await showDialog(...)`，用户点「知道了」后才 `return`。
原测试在点「知道了」之前就 `await pending`，两边互相等。

## 3. 改法

三个文件，两处结构改动加一处数字改动。

### 3.1 有上限的等待助手

`device_sync_dialog_test.dart` 与 `device_sync_failure_test.dart` 各带一个
同名助手：

```dart
Future<void> pumpUntilFound(
  WidgetTester tester,
  Finder finder, {
  Duration limit = const Duration(seconds: 10),
}) async {
  final watch = Stopwatch()..start();
  await tester.runAsync(() async {
    while (finder.evaluate().isEmpty) {
      if (watch.elapsed > limit) {
        throw TestFailure('等待超时（${limit.inSeconds} 秒）：…');
      }
      await Future<void>.delayed(const Duration(milliseconds: 50));
      await tester.pump(const Duration(milliseconds: 50));
    }
  });
  await tester.pumpAndSettle();
}
```

四条性质：

- 用真 `Stopwatch` 限十秒，超时抛 `TestFailure` 并指出是哪个 finder。
  没有上限的 `while` 会把 CI 拖到作业超时。
- 每轮 `Future.delayed(50ms)` 在 `runAsync` 里是真延时，真实让出事件循环。
- 每轮 `tester.pump(50ms)` 让界面走帧。条件成立即返回，不等固定时长。
- 命中后 `pumpAndSettle()` 把入场动画推完再点，避免点到动画途中的位置。

### 3.2 用例的执行顺序

四条用例统一成这个形状：

1. 点启动按钮，包在 `runAsync` 里。在假区里点，`runDeviceSync` 的磁盘
   Future 就在假区创建，之后怎么等都不会完。
2. `pumpUntilFound` 等确认框（或失败框、结果框）出现。
3. 断言弹框内容。
4. 点「知道了」或「取消」，包在 `runAsync` 里。
5. 退出 `runAsync`，`pumpAndSettle()` 推关闭动画，断言弹框消失。
   只 `pump` 一次推不完动画。
6. 此时才 `await pending`，Future 已经可以完成。
7. 所有 `File(...).readAsString()` 与 `Directory(...).exists()` 断言
   都包在 `runAsync` 里。

唯一不在 `runAsync` 里的磁盘调用是 `setUp` / `tearDown`，
它们本来就在真异步区。

### 3.3 驱逐夹具的预算

`test/sync/device_sync_test.dart` 的 `budgetBytes` 从 `150` 改为 `250`。

原夹具：两个目录各 100 字节，`usedBytes = 200`，`needBytes = 100`，
预算 150。`evictCandidates` 的循环条件是：

```dart
if (usedBytes - freed + needBytes <= _budgetBytes) break;
```

代入：`200 - 0 + 100 = 300 > 150`，删一个后 `200 - 100 + 100 = 200 > 150`，
还得删第二个。所以在 150 下「只删一个」无解，期望值 1 自相矛盾。

改成 250 后：删一个即 `200 <= 250`，停。断言全部原样成立：
`removed == 1`、`one` 目录不存在、`two` 目录存在、
`cache.entryFor('h/one')` 为 null。

生产驱逐策略不动。这是夹具数字，不是产品参数。

## 4. 改动清单

```
test/sync/device_sync_dialog_test.dart   两条用例 + pumpUntilFound 助手
test/sync/device_sync_failure_test.dart  两条用例 + pumpUntilFound 助手
test/sync/device_sync_test.dart          evict 夹具 budgetBytes 150 -> 250
```

`lib/` 下没有任何改动。`device_sync.dart` 的驱逐策略与老文件保留契约原样，
`device_sync_dialog.dart` 的对话流程原样。

原有行为断言一字未改：进度框关掉、给出可读原因、`pending` 为 false、
旧文件仍是旧内容、文件内容为 `one` 与 `two`。

静态检查：`dart format` 后 `flutter analyze --no-pub test/sync` 为
No issues found!，无 info 级告警残留。

本地没有跑 `flutter test`。

## 5. 老文件保留契约（只读）

断言的期望可信，产品代码也满足：

1. `_writeVerified` 先把分片写进 `.incoming/<path>.part`。
2. 收完后比对摘要，不符则抛 `DeviceSyncException`，删掉 `.part`。
3. 只有摘要相符才 `temp.rename(target)`。
4. `apply()` 把错误收成 `SyncReport.failed(...)`，
   不会中途删掉已存在的 `files/a.txt`。

所以传输失败时 `files/a.txt` 仍是上一轮写入的 `'one'`。

## 6. 剩余风险

1. **验证交给云 CI**。本地只过了 `dart format` 与 `flutter analyze`。
2. **`pumpUntilFound` 的十秒上限**。云端机器极慢、单次 `plan()` 超过十秒时，
   用例会以「等待超时」失败并指出 finder。那时把 `limit` 调大，
   不要把超时检查去掉。
3. **`dart_test.yaml` 的 2 分钟限时疑似未生效**。证据里那条用例是十分钟超时。
   这一条不在本次修复范围，但值得单独查。
