# 只读交叉审查：Pi-D 的 device sync 测试（A）

范围：`test/sync/device_sync_dialog_test.dart`、`test/sync/device_sync_failure_test.dart`、`lib/sync/device_sync_dialog.dart`。为确认测试假设，另读了 `lib/sync/device_sync.dart` 与 `lib/sync/sync_limits.dart`。

只读审查。未改任何代码，未跑测试或探针。所有结论来自静态读码。

## 一、真实 IO 与 zone 的处理（通过）

`runDeviceSync` 经 `DeviceSyncService` 用 `dart:io` 读写。`testWidgets` 默认的 fake async zone 不会让真实 IO 的 future 完成，所以断言若落在 fake zone 里就会永久挂起。

两个测试的处理是对的：

- 按钮按下本身包在 `tester.runAsync` 里。`runDeviceSync` 的 future 因此在真实 zone 创建，`dart:io` 能正常完成。
- 用 `pumpUntilFound` 等弹框，而不是 `await pending`。`pending` 要等结果弹框关闭后才完成，先 await 会死锁。

`device_sync_dialog_test.dart` 的注释把这条讲清了。这个设计成立。

## 二、弹框关闭与 pending 返回顺序（测试正确）

`device_sync_dialog.dart:126-190` 的顺序是：

1. `unawaited(showDialog(进度框))`，不等它完成。
2. `await service.apply(...)`。
3. `navigator.popUntil((route) => route is! DialogRoute<void>)`。
4. `await showDialog(结果框)`。
5. 返回 `report.completed`。

测试「等结果框出现 → 点知道了 → pumpAndSettle → await pending」与这个顺序一致，没有问题。`on Object catch` 把 `apply` 的一切错误都接住，再换成失败弹框，用 `return false` 与成功路径分开。顺序正确。

### 独立风险：`popUntil` 的判据是类型通配（已记录，本轮不改）

`device_sync_dialog.dart:147`、`:184`、`:196`。

`popUntil` 从栈顶开始弹出，直到谓词返回 true。谓词是 `route is! DialogRoute<void>`，意思是「只要还是 `DialogRoute<void>` 就继续弹」。`rootNavigator: true` 又让作用域是整个根导航器。

理论上，同步期间若栈上还有别的 `DialogRoute<void>`，它也会跟着关掉。当前没有其它弹框叠在同步弹框之上的重现证据，这属于潜在风险而非已确认缺陷。记录在案，本轮不引入代码改动。

## 三、动画等待（低，不阻塞）

`pumpUntilFound` 结尾是 `await tester.pumpAndSettle()`，注释说「弹框已经在树里，把入场动画推完再点」。

`pumpAndSettle` 在 fake zone 里推进。进度框的 `LinearProgressIndicator(value: value.doneFiles / total)` 传了确定进度，不是无限动画，所以它不会让 `pumpAndSettle` 一直推下去。这比无限动画安全得多。

剩下的一点只是时序依赖：`pumpAndSettle` 只看得到 fake 时钟上的调度，看不到真实 zone 里的 IO 进展。成功用例里真实工作在 `runAsync` 块里推进，弹框一出现就停下来等断言，所以目前没有失败迹象。

结论：这里没有发现需要本轮修的问题。若以后遇到偶发超时，再考虑给 `pumpAndSettle` 传显式超时。

## 四、有界轮询（通过）

`pumpUntilFound` 用真实 `Stopwatch` 计时，每轮 `Future.delayed(50ms)` 让出事件循环再 `tester.pump(50ms)`。方向正确：失败会抛 `TestFailure` 而不是挂死 CI。

### 观察 1：超时检查在循环开头（低，非缺陷）

```dart
while (finder.evaluate().isEmpty) {
  if (watch.elapsed > limit) { throw ... }
  await Future<void>.delayed(...);
  await tester.pump(...);
}
```

若最后一轮 pump 之后刚好超过 `limit`，循环会再判一次 `isEmpty` 才进超时分支。这不影响正确性，只让实际超时比 `limit` 略长（最多一轮 50 ms + pump 时间）。可接受。

### 观察 2：`pumpAndSettle` 的默认超时是 10 分钟（低，非缺陷）

`pumpUntilFound` 自己在 10 秒后有界。紧跟的 `pumpAndSettle()` 用默认超时。进度框是指定进度条，不是持续动画，所以它不会让 `pumpAndSettle` 推到超时。这一行与轮询上界不矛盾。

若以后引入持续动画，记得同步收紧 `pumpAndSettle` 的超时。当前不需要改。

## 五、`failAfter` 的语义（修正：无缺陷）

`device_sync_failure_test.dart:51-57`：

```dart
Future<FsChunk> read(String path, {required int offset, int? length}) async {
  if (_reads++ >= failAfter) {
    throw StateError('与服务器的连接已断开');
  }
  final all = utf8.encode(files[path] ?? '');
  return FsChunk(path: path, offset: 0, bytes: all, eof: true);
}
```

`failAfter` 是「成功读几次之后开始抛」。两个端口各管一段，职责清晰：

- `failAfter: 9`（`:167`）只服务于用例第一轮初始化：把 `one` 完整写下去，9 次预算远多于需要的次数，所以这一轮不会失败。这是故意的。
- 真正的失败测试用的是另建的 `failing`（`:183`，默认 `failAfter: 0`），第一次读就抛。

断言 `'one'` 验证的是旧内容保留：第二轮失败在 `_writeVerified` 的读阶段，`rename` 从未发生，所以真实文件仍是第一轮写的 `one`。名实相符。

我上一版的「名字与行为不符」是误报，原因是把两个端口的职责看成一个，已修正。

### 遗留点：`read` 忽略 `offset` 与 `length`（低，不阻塞）

`read` 永远返回 `offset: 0` 的全量内容。两个用例的文件都在 3 字节以内，小于 `kSyncChunkBytes`（512 KiB），一次就读完并 `eof: true`，碰不到多分片路径。所以当前不存在错误。

若以后用这两个 fake 测大于 512 KiB 的文件，就要按 `device_sync.dart:292-317` 的真实契约切片，否则 `received != entry.size` 的检查会误报。这是待办提醒，不是现存缺陷。

## 六、评审结论

| 关注点 | 结论 |
|---|---|
| 真实 IO zone | 正确 |
| 弹框关闭与 pending 顺序（测试侧） | 正确 |
| 弹框关闭（生产侧 `popUntil`） | 潜在风险，无重现证据，本轮不改 |
| 动画等待 | 进度条是确定进度，无问题 |
| 有界轮询 | 通过 |
| `failAfter` 语义与用例 | 正确，两个端口职责分明 |

### 对上一版的修正

上一版有两项误报，原因是读代码时把 `_DroppingPort` 的两次不同实例看成一个，以及没看到 `LinearProgressIndicator` 传了 `value`：

1. 我曾说 `failAfter: 9` 用例名不副实。错。`failAfter: 9` 只用于第一轮初始化，真正的失败测试用另建的 `failing`（默认 `failAfter: 0`）。断言 `one` 验证的确实是旧内容保留。
2. 我曾说 `LinearProgressIndicator` 是无限动画、会让 `pumpAndSettle` 推到超时。错。它传了 `value: value.doneFiles / total`，是确定进度。

修正后的结论：**本轮没有发现需要修改代码的缺陷。**

唯一记录在案的是 `popUntil` 的类型通配判据。它在概念上范围偏宽，但当前没有其它弹框叠在同步弹框之上的证据。按父级要求，本轮不扩展代码范围。新 CI 已启动。

未改任何文件。本轮没有任何本地运行。
