# 旧 run 45161937167 的 Studio Git iOS 失败（Pi-B，只读）

任务：`11-23-mobile-files-agents`。
对象：App run `45161937167`，sha `ef5e222e5b5411682686d4f6c5b4cac3b3f3ce3a`，
分支 `ci/mobile-files`，job `137649310992`（Studio Git iOS integration test）。
证据：`takeover-ci-qflistudio-next-ef5e222e5b54-45161937167.json`、
`takeover-log-45161937167-137649310992.txt`（1692697 字节）。
日志由 `takeover_logs.py --job "Studio Git iOS integration test"` 取得，取日志时
该 job 已结束。本轮未改代码、未跑测试、未提交、未推送、未取消或重跑任何 job。

时间口径：job 与步骤时间戳为 UTC，与日志行 `...Z` 逐秒一致。

## 1 结论

这个 job 死于**步骤超时**，不是测试断言失败。

`Run the plugin integration test on the simulator` 步骤自带
`timeout-minutes: 20`，实际运行 11:18:40 → 11:38:54，即 **20 分 14 秒**，被
GitHub 强制终止。终止行按原文引用：

```
2026-11-23T11:38:54.3294050Z ##[error]The action 'Run the plugin integration test on the simulator' has timed out after 20 minutes.
```

job 总时长 11:15:31 → 11:39:53，约 24 分 22 秒，落在 job 级 25 分钟预算内，
所以是**步骤先超时**，job 级预算没有触发。

## 2 超时前卡在哪一步

按原文时间线：

```
11:21:00.060  running test package with arguments: [... flow_test.dart]
11:21:00.727  00:00 +0: loading .../integration_test/flow_test.dart
11:21:00.828  test 0: starting test .../integration_test/flow_test.dart
11:21:00.863  test 0: starting test device
11:21:00.874  test 0: awaiting connection to test device
11:25:23.213  executing: ... xcrun simctl launch B290E327-... com.example.qfliGitExample
11:25:26.558  com.example.qfliGitExample: 18947
11:25:26.587  Waiting for VM Service port to be available...
11:38:54.329  ##[error]The action ... has timed out after 20 minutes.
```

即：App 已装上并启动（进程号 18947），但工具停在
`Waiting for VM Service port to be available...` 这一行，之后 **13 分 28 秒**
没有任何新的工具输出，直到超时。

对照成功的 run `45158844625` 同一 job：日志第 1365 行同样有
`running test package with arguments`，第 13745 行是 `00:05 +1: All tests passed!`。
本次日志里没有 `All tests passed`，也没有任何 `+1` 之类的测试进度行。

## 3 区分「VM Service 启动超时」与「测试断言失败」

按证据，属于前者，理由三条：

1. 没有断言输出。断言失败会留下 `Expected:` / `Actual:`、`EXCEPTION CAUGHT BY
   FLUTTER TEST FRAMEWORK` 或 `Some tests failed`。本日志一条都没有。
2. 没有测试进度。成功的 run 会打印 `+1: All tests passed!`。本日志停在
   `+0`，测试体一行都没跑。
3. 终止方是 GitHub Actions 的步骤超时，不是 Dart 测试框架的失败退出。最后
   一条工具输出是等待 VM Service，之后整段静默。

所以这是**测试宿主未完成连接**导致步骤被砍，而不是集成测试里的某个断言不成立。

## 4 不做无依据的根因断言

以下我只能在证据上确认「观察到」的事实，不宣称已证明的根因：

- 观察到：`simctl launch` 返回了进程号 18947，说明安装与启动调用本身返回了。
- 观察到：随后始终没有 VM Service 端口可用的迹象。
- 观察到：同一 job 的 `Collect the Runner system log` 步骤跑过且 success，
  其 crash reports 段落内容为 `Retired`，没有输出新的崩溃报告文件。
- 未观察到：本日志里没有 App 端崩溃栈、没有 `Runner` 进程的 Dart 异常。
  我没有该 artifact 里的 `git-ios-flow-test.log` 与
  `git-ios-runner-system.log` 全文，只有步骤串流输出。

因此「为什么 VM Service 没起来」本轮**未定性**。可能是模拟器上的 App 卡在启动、
可能是端口转发未建立、也可能是环境抖动。需要那两个 artifact 才能进一步区分。

## 5 插件与版本身份

本 run 的 `QFLI_PLUGIN_COMMIT` = `697291a27818612ae9dc53d83d4f99fa5887908e`，
与上一轮成功 run `45158844625` 相同。失败的 `Verify the fixture is that exact
commit` 之前的 `Assert the fixture ref is the released plugin commit`、
`Check out the released plugin commit`、`Verify the fixture is that exact commit`、
`Check the fixture native lock` 四步均 success。

本 run 的 `CORE_REF` = `0bf1ffaf22b8c0af88c22efd62bfbf0e74d9d428`，不是最终
pin 的 `d3d8995`。这条只作事实记录。它是否影响本 job 超时，我本轮未验证。

## 6 后续状态（父级提供）

父级报告：App 最终 run `45165599562`（`055dd22`）已整体 SUCCESS，含同一个
Git iOS job。这与其他 job 的结论一致：旧 run 的 Git iOS 失败没有在最终 run
复现，本次记为一次性失败。我没有独立核对 `45165599562`，此处按父级信息转述。

## 7 剩余风险

- 本轮只读了一份日志，没有取 `git-ios-integration-45161937167` artifact。VM
  Service 未启动的具体原因仍未定位。
- 20 分钟步骤预算足以覆盖正常路径（成功 run 用 6.8 分钟），但对「启动卡住」
  这种静默场景只能在满 20 分钟后才报失败，反馈慢。这是配置层面的观察，本轮
  未做任何改动。
