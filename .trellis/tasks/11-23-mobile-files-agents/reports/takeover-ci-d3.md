# CI 修复 D3：同步挂点收束

## 1. 结论

同步组的挂点已经解决。定向云 CI run45164365603 上，
两个 sync 挂点均通过，全部同步测试通过。

## 2. 有效修复

把 `await pending` 移回 `runAsync` 内。

涉及两条用例：

- `device_sync_failure_test.dart` 的「端口抛错时关掉进度框并说明原因」
- `device_sync_dialog_test.dart` 的「the sync dialog writes the files
  after confirmation」

这两个 `pending` 都在 `runAsync` 里由点击按钮启动。
在 fake 区外 await 一个在真区里启动的 Future，等不到完成。
移回 `runAsync` 内之后两条都通过。

提交 `45ff454 test(sync): keep completion futures in the real async zone`。

## 3. 证据

| 项 | 值 |
| --- | --- |
| 流水线 | run45164365603 |
| 基线提交 | `0bf1ffa` 之后的修复提交 `45ff454` |
| 挂点结果 | 两条均通过 |
| 同步测试 | 全部通过 |

前一轮 `0bf1ffa` 的 run45161876449 是 2489 completed / 0 failed /
2 unfinished，未完成的两条正是这两条用例。

## 4. 结论收束

`tester.pump` 本身没有死锁。之前的猜测不成立，已放弃。
唯一有效的原因是 `pending` 的 await 位置，这一点已由云端结果确认。

## 5. 改动范围

只有 `test/sync` 下的两条用例调整了 await 位置。
`lib/` 未改。
