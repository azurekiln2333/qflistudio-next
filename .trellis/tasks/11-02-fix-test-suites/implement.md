# 实施计划：测试全绿

## 顺序

先修「丢失实现」的纯增量部分，再改档位与测试断言，最后跑两仓库全量。

### 1. `EditorController.reloadFromDisk`

按 `test/editor_reload_from_disk_test.dart` 的 3 个用例补方法：

- 入参：`OpenFile`。
- 脏缓冲区（`open.dirty`）返回含「未保存」的提示，不改内容。
- 只读标签返回提示，不改内容。
- 内容未变时不替换 `codeLines` 引用，选区保持。
- 内容变了才更新 `controller.text`，并刷新 `modifiedAt`，`dirty` 置 false。

### 2. `PointsPage(client:)` / `TasksPage(activity:)`

读测试与该页现有实现，把注入点补成测试期望的签名，默认值保持线上行为不变。

### 3. `tool/vibe_e2e_local_executor.dart` 的 `available`

对齐 `lib/interop/interop_transport.dart` 的 `InteropTransport` 构造签名。
不修改 `lib/interop` 本身。

### 4. `studio_home_release_test.dart` 的 Tab 数

`findsNWidgets(4)` → `findsNWidgets(5)`。

### 5. 主 App 档位

`qflistudio/lib/main.dart` 的 `qfliStudioProfile` 增加本地内容设置，
使教程/示例走本地仓库。

## 验证命令

```
cd D:/MyNewProjects/qfli_studio_core
flutter test --no-pub test/editor_reload_from_disk_test.dart test/points_page_test.dart \
  test/tasks_page_checkin_test.dart test/vibe_e2e_harness_test.dart \
  test/vibe_e2e_local_executor_test.dart test/vibe_e2e_runner_test.dart \
  test/vibe_live_e2e_test.dart
flutter test --no-pub
flutter analyze

cd D:/MyNewProjects/qflistudio
flutter test --no-pub
```

## 回归红线

- 不得删除测试、不得放宽断言（第 4 项只改 Tab 计数的笔误，其余断言原样保留）。
- 不得改服务端、`lib/interop`、`ets/interop`。
- 不得格式化或提交其他 worker 的文件。

## 提交拆分

1. `test(editor): restore reloadFromDisk for open buffers`（含实现与说明）
2. `test(studio): align points, tasks and e2e harness injection points`
3. `test(studio): fix the stale workspace tab count and switch main to bundled content`

## Result

状态：完成（10 个失败修复 9 个，1 个如实记录为阻塞）。

### 失败归因与修法

| 失败 | 归因 | 修法 | 提交 |
| --- | --- | --- | --- |
| `editor_reload_from_disk_test` | 实现丢失 | 补回 `EditorController.reloadFromDisk`：干净缓冲区重读磁盘，脏缓冲区拒绝并返回说明，内容未变时不换 `codeLines` 以保留光标 | `0da69b4` |
| `points_page_test` | 实现丢失 + 本轮引入的连带回归 | 补回 `client`/`clock`/`cacheDirectory` 注入点。分栏并发加载，各栏独立 loading。各栏保留滚动位置。账号切换后重载。兑换容忍本地写盘失败 | `2b111a9` |
| `tasks_page_checkin_test` | 实现丢失 | 补回 `activity` 注入点。签到失败就地提示并可重试。本地写盘失败报「结果未知」并给刷新确认，不给重试。状态按账号加日期分组。令牌轮换后仍可确认 | `2b111a9` |
| `vibe_e2e_harness_test` / `_local_executor_test` / `_runner_test` / `vibe_live_e2e_test` | 实现丢失（测试工具侧） | `InteropProbe` 已从 `available` 改为 `status`，改调用侧。报告写入前把环境变量名脱敏（报告自带泄漏校验）。控制台消息保留原名 | `ff3b0d5` |
| `studio_content_repository_test` | 实现丢失 | `_filter` 把主 App 的产品键视为「显示全部」。`_loadExamples` 去掉按产品 id 的二次过滤。本地内容页两个 AppBar 显式 `centerTitle: false` | `910b880` |
| `studio_home_release_test`（Tab 计数与云端 scope） | 实现丢失 | 主 App profile 标为 `offlineOnly: true`。项目菜单标签加 `Flexible`，窄视口换行而不是溢出报错 | `910b880` + `34db1b8` |
| `studio_home_release_test`（content factory stays lazy） | 测试夹具（未解） | 见下方阻塞项 | — |

### 验证

```
cd D:/MyNewProjects/qfli_studio_core
flutter test --no-pub          -> 1357 通过 / 9 跳过 / 6 失败
flutter analyze lib test tool  -> 11 个既有问题，本轮触及的文件全部干净
dart analyze <本轮 9 个文件>    -> No issues found

cd D:/MyNewProjects/qflistudio
flutter test --no-pub          -> 6 通过 / 1 失败
```

core 的 6 个失败全部是 `test/java_content_render_test.dart`。用 `git show HEAD:` 把本轮改动临时换回基线后重跑，同样失败，因此是本轮之前就存在的既有失败。

### 阻塞项：`main content factory stays lazy and runs once across retained tutorial and example routes`

现象：该测试在与其他两个测试连跑时，`_waitFor('lazy tutorial route')` 超时。单跑通过。

已排除：
- 内容仓库本身。连续 3 次 `load()` 正常。连续 3 次「并发读两个大资产」正常。「先点功能页再点教程页」的 Home 场景全部在 10 轮内完成。
- 解析 isolate 不是原因。改成主 isolate 直接解析后仍超时。
- 资源包读取不是原因。连续读 3 次正常。

判断：`LocalTutorialsTab` 的 Future 在第三次挂载时一直停在 `ConnectionState.waiting`，而同一代码路径在前两次挂载时都完成。前两个测试用掉的 `runAsync` 真实时间窗口是唯一剩下的差异变量。这属于测试夹具的调度问题，不是产品缺陷。

没有改成放宽断言或加长等待，也没有删用例。后续需要给 `setUpAll` 共享的临时目录做逐用例隔离，或给 `_waitFor` 新建独立的 runAsync 节拍，之后再复核。

### 更正：主 App 不是离线产品

上一版把这个用例的断言直接套在主 App profile 上，并因此把 `qfliStudioProfile` 改成了 `offlineOnly: true`。这是错的。

`offlineOnly` 不只关两个开关。`ApiClient` 会拒绝联网。云项目与在线终端消失。AI 设置项消失。关于页换成离线文案。同一个 profile 里 `isOffline: false`，主 App 是联网产品。

处理：

1. `646c8e9` 撤销那 3 行，主 App 保持联网。
2. `c838a7d` 把「隐藏云端 scope」的断言绑到离线产品档位。用例显式挂一个 `offlineOnly: true` 的 profile。原有断言一条未改。另加一条用例，验证主 App 联网 profile 必须显示云端 scope 与云端新建入口。
3. core `6ac1442` 修掉我引入的两处回归：主 App 的「显示全部」捷径此前只按产品键判断，把 java 页面也吞了。改为仅当请求的语言等于产品 id 时才跳过语言过滤。`java_content_render_test` 的 6 例因此恢复。

### 更正：lazy catalogue 用例的根因与修法

同文件第 3 个 `testWidgets` 起，fake-async zone 不再投递 `runAsync` 之外的真实 I/O 完成回调。`w37:p2` 的独立实验得出了同一结论：同一个 adapter 在纯 `test()` 里连跑 6 次全部成功，在 `testWidgets` 里第 2 次起必然不返回。

修法：在 `setUpAll` 里用 `binding.runAsync` 预热组合目录，用例内部的工厂改返回一个继承 `StudioContentRepository` 的包装器，只重放已完成的目录。`factoryCalls == 0` 的惰性与 `same(repository)` 的单实例断言语义原样保留，没有放宽任何断言，也没有加长等待。

### 最终验证

```
cd D:/MyNewProjects/qfli_studio_core
flutter test --no-pub     -> 1363 通过 / 9 跳过 / 0 失败
dart analyze <改动文件>    -> No issues found

cd D:/MyNewProjects/qflistudio
flutter test --no-pub     -> 8 通过 / 0 失败
```
