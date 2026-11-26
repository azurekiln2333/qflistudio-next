# App CI 45158844625 只读复核（Pi-B）

任务：`11-23-mobile-files-agents`。
证据：`reports/takeover-ci-qflistudio-next-d644b8c4b3d9-45158844625.json`、
`reports/takeover-log-45158844625-137639422054.txt`（Git iOS job 完整日志）。
sha `d644b8c4b3d91556ef3247a336d91d8bcb5cdb38`，分支 `ci/mobile-files`，attempt 1。

时间口径：job ��步骤时间戳是 UTC，与日志行（`...Z`）逐秒对得上。
json 的 `observed_at` 原值为 `11/23/2026 18:58:01`，不带时区标记，按原值引用，
不自行换算成 UTC。

## 1 结论：没有卡住，Studio Git iOS 已 success

`Studio Git iOS integration test` 状态 `completed`，结论 `success`。

| 时间点（UTC） | 事件 |
| --- | --- |
| 10:46:04 | job 开始 |
| 10:46:49 | 断言 fixture ref 等于已发布插件提交，通过 |
| 10:46:52 | 确认 fixture 就是该提交，通过（`PASS fixture HEAD`） |
| 10:49:23 | 启动 iPhone 模拟器完成 |
| 10:49:26 | 集成测试步骤开始 |
| 10:56:13 | 集成测试步骤完成，success（耗时 6.8 分钟） |
| 10:56:13 | 日志第 13745 行：`00:05 +1: All tests passed!` |
| 10:56:49 | job 收尾完成 |

集成测试耗时 6.8 分钟，步骤预算 20 分钟，job 预算 25 分钟。占用不到预算的四成，
不属于超时或卡死。

## 2 「看似卡住」的来源

快照里 `run.status` 仍是 `in_progress`，另有
`Verify core with OHOS Flutter` 也是 `in_progress`。这是快照抓取时机与 run 收尾
不同步所致，不是 Studio Git iOS 的问题：

- 该 job 的步骤时间戳已经全部填满，含 `Complete job`（10:56:49）。
- 同快照内其它 job 最晚完成时间是 10:51:25，均 success。
- iOS 打包 job（`iOS unsigned IPA`）本轮 success，说明上一轮的
  `withSecurityScope` 编译阻塞已解除。

## 3 超时设置核对

`.github/workflows/app-installers.yml`：

| 位置 | 设置值 | 判断 |
| --- | --- | --- |
| `git-ios-integration` job（第 1431 行） | `timeout-minutes: 25` | 合理 |
| 集成测试步骤（第 1542 行） | `timeout-minutes: 20` | 合理，留 5 分钟给收尾 |
| `resolve-flutter` | 10 | — |
| `verify-flutter` | 45 | — |
| `ios` 打包 | 60 | — |
| workflow 级 `timeout-minutes` | 未设置 | 依赖各 job 自己的预算 |

步骤预算 20 分钟小于 job 预算 25 分钟，层级正确：步骤先超时，收尾步骤
（`if: always()` 的日志收集与产物上传）仍有时间运行。测试步骤用
`set -o pipefail` 且无 `continue-on-error`，失败时 job 直接失败，不会静默通过。

## 4 插件版本一致性

结论：Git iOS 所测插件与打包侧读到同一个提交。具体值已从日志核对：

```
qfli_git 0.1.0 at 697291a27818612ae9dc53d83d4f99fa5887908e on Flutter 3.50.0
PASS fixture HEAD 697291a27818612ae9dc53d83d4f99fa5887908e
```

- `QFLI_PLUGIN_COMMIT` = `697291a27818612ae9dc53d83d4f99fa5887908e`
- `QFLI_PLUGIN_VERSION` = `0.1.0`
- Flutter `3.50.0`
- 日志第 1010 行：`+ qfli_git 0.1.0 from path ..`，`pub get` 解析到同一版本。

逐条链路：

1. `.github/actions/app-setup/action.yml` 第 140 行运行
   `plugin_provenance.py --write-env "$GITHUB_ENV"`，从 `pubspec.lock` 解析出
   `qfli_git` 的提交，写入 `QFLI_PLUGIN_COMMIT` 等变量。日志第 630、637 行就是
   这组输出。
2. `git-ios-integration` 的 `Set up Flutter and shared core`（第 1443 行）用的
   是同一个 `./qflistudio/.github/actions/app-setup`，`core-ref` 与 iOS 打包 job
   相同（`${{ inputs.core_ref || env.CORE_REF }}`）。
3. `Assert the fixture ref is the released plugin commit`（第 1454 行）先要求
   `QFLI_PLUGIN_COMMIT` 匹配 `^[0-9a-f]{40}$`，否则 `exit 1` 并报 `::error::`。
4. `Check out the released plugin commit` 按该 ref 检出到 `qfli_git_fixture`。
5. `Verify the fixture is that exact commit` 再比对 `git rev-parse HEAD` 与同一
   变量。日志第 882 行 `PASS fixture HEAD 697291a2...` 就是比对通过。
6. 打包侧三个 job（iOS/Android/OHOS，第 1384、1816、2234 行附近）都用
   `plugin_provenance.py --require-release-ready`，缺任一必需事实即
   `raise ProvenanceError`，`main` 返回 1。

回退到出问题的情形需要两个 var 来源分叉，或两处断言同时失效。目前两处断言
在本轮都通过，且工作流里没有第二个独立的插件版本来源。

日志未覆盖的部分：我没有打包侧 job 的日志，所以「打包 job 读到同一个
`697291a2...`」是由同一 `pubspec.lock` 与同一 `app-setup` 推导，未逐字比对。

## 5 剩余风险

- 具体插件哈希与版本号已从日志核对（`697291a2...`、`0.1.0`）。打包侧 job 的
  日志本轮未取，两侧一致由同一 `pubspec.lock` 与同一 `app-setup` 推导。
- 快照显示 run 级 `status=in_progress`，Core 验证 job 亦为 `in_progress`。
  这两处不在本轮范围内，但下一次快照前不应假定 run 已整体结束。
- 工作流没有 workflow 级 `timeout-minutes`。单 job 都有预算，但若将来新增 job
  漏写 `timeout-minutes`，会退化成 GitHub 默认的 6 小时。
