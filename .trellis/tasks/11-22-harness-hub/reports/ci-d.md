# ci-d：CI 挂起静态审计（Pi-D 负责范围）

任务：11-22-harness-hub
分支：`harness/integration`
工作区：`D:/MyNewProjects/_wt/harness/integration/qfli_studio_core`
起点：`242a2ae`（改动前工作区干净）

## 结论

本片范围没有找到"某条用例自身死等"的证据。找到三处会拖长或拖死整轮运行的东西。
三处都修了，各一个提交。整轮运行的兜底限时由我新增的 `dart_test.yaml` 承担。

| 风险 | 位置 | 影响 | 修法 | 提交 |
| --- | --- | --- | --- | --- |
| 全仓没有测试限时配置 | `dart_test.yaml`（新增） | 一条挂住的用例要等默认限时才失败，几条叠加超过作业上限 45 分钟 | 全局 `timeout: 2m` | `09caa6d` |
| 项目脚本"打印完不退出"时永远等下去 | `lib/trellis/trellis_context.dart:170`（旧 167-186） | 会话开头取上下文卡死，一轮会话停在这里 | 新增 `awaitWithin`，stdout / exitCode / stderr 三步共用一个时限 | `dce5f06` |
| 控制器用例只受全局限时约束 | `test/vibe_trellis_session_test.dart:93,122,154,178` | 轮询卡住时要等全局 2 分钟才报名字 | 每条加 `Timeout(Duration(seconds: 30))` | `51edcaf` |

## 风险一：没有全局测试限时

`verify-flutter` 作业用 `timeout-minutes: 45`，跑 `flutter test --no-pub --reporter json`。
命令没有传 `--timeout`，所以每条用例吃框架默认值：`testWidgets` 10 分钟，普通 `test()` 30 秒。
挂住的用例不会自己失败，只能等作业到上限后取消。取消后日志里没有用例名，所以读不出原因。

修法：在 core 根新增 `dart_test.yaml`，只写一行 `timeout: 2m`。
`package:test` 从包根读这份配置，`flutter test` 走同一套加载逻辑。
2 分钟的依据：改动前整轮 4 分钟，单文件用例都在秒级。留足了余量。

提交 `09caa6d test: fail a hung suite run after two minutes`。

## 风险二：项目脚本永不退出

`TrellisContextLoader._runScript` 旧代码：

```dart
final completed = await Future.any<Object?>([
  stdoutText,
  Future<Object?>.delayed(timeout, () => null),
]);
...
final code = await exit;          // 无时限
await stderrDrained;              // 无时限
```

旧代码只给 stdout 设了时限。脚本打印完就把标准输出关掉、自己却卡住不退出时，
`stdoutText` 正常完成，随后 `await exit` 没有时限。`load()` 永远不返回。
真实触发场景：脚本等 stdin、或脚本的子进程占着管道不放。

修法（`lib/trellis/trellis_context.dart:170-183`）：

1. stdout 用 `awaitWithin` 等，超时返回 null。
2. exitCode 用同一个 `awaitWithin` 等，超时返回 null。
3. stderr 只是防管道堵死的排水口，同样限时，排不完不影响已经拿到的正文。
4. 任一步拿不到就返回 null，走 Dart 解析回退。
5. `finally` 里 `supervisor.dispose()` 收尸。这一步有界：宽限 500 ms 加强制退出 2 s（`lib/services/process_supervisor.dart:313-314,365`）。

新增 `awaitWithin`（`trellis_context.dart:199`）：用 `Timer` 与 `Completer` 竞速，超时返回 null。
原 future 保持原样，错误照原样抛出，不吞。

新增 3 条测试（`test/trellis_context_test.dart` 的 `script deadline` 组，第 179-211 行）：

1. 永不结束的等待在 20 ms 后返回 null，原 future 事后仍能正常完成。
2. 及时到达的值原样返回。
3. 错误照原样抛出。

这三条不启动进程，也不依赖 python。三条测试覆盖等待策略本身。

提交 `dce5f06 fix(trellis): stop waiting on a project script that never exits`。

## 风险三：控制器用例没有自己的限时

`test/vibe_trellis_session_test.dart` 的 `settle()` 用真 `Future.delayed` 轮询，最多 500 次乘 2 ms。
四条用例都跑真 `VibeCodingController`。卡住时要等全局限时才报名字。
修法：四条各加 `timeout: const Timeout(Duration(seconds: 30))`。
提交 `51edcaf test(agent): cap the Trellis session tests at thirty seconds`。

## 逐文件审计结论（未改动）

### `test/trellis_context_test.dart`

没有 `Process`、没有 `Timer`、没有网络。
两条 python 路径都进不去：

1. `runsProjectScript` 要两道开关同时开（`trellis_context.dart:133`）。
2. `trellis_context.dart:158` 拒绝符号链接脚本。
3. `preferPython: true` 的用例只走 Dart 解析。
4. 临时目录走 `addTearDown` 删除。

### `test/trellis_project_test.dart`

全同步文件读，`followLinks: false`，没有递归遍历。
`lib/trellis/trellis_panel.dart:68,72` 的 visited 集合挡住了互指子任务。
对应用例只钉住这条契约，不会递归。

### `test/vibe_skill_discovery_test.dart`

不扫真 home。`library()` 把 `userSkillsDirs` 全指向临时 home（第 53-59 行）。
`setUp` 建临时目录，`tearDown` 删。

### `test/vibe_coding_skills_test.dart`

不扫真 home。除显式 `userSkillsDir` 外一律 `includeUserSkills: false`。
`resolves the home directory without guessing` 只读环境变量，不列目录。

### `test/vibe_e2e_harness_test.dart`

纯离线。没有 `Process`、没有 HTTP。
`scenario.prepare!` 只写夹具文件。
四处 teardown 删的是各自临时子目录，不碰系统临时根。
`_env` 是常量表，密钥是假串。

### `test/studio_agent_host_test.dart`

用 `FakeAgentRuntime` 与 `MemoryAgentSessionStore`。
流是单次 `Stream.multi`，`onCancel` 摘监听（`studio_agent_host.dart:89,320`）。
`dispose` 与 `detach` 显式释放（`:182`、`:364`）。
`tearDown` 关主机，签出用例用 `addTearDown`。
没有 `Timer`、没有 `Process`。

### `lib/harness/studio`

没有 `Timer`、没有 `Process`、没有周期轮询。
所有 `await` 只落在门面的 `send` / `cancel` / 会话保存上。
监听集合在 `dispose` 与 `detach` 里清空。

### `lib/vibe_coding/vibe_skills.dart`

列目录有 `FileSystemException` 兜底（第 410-415 行）。
读文件只取 16 KiB 头（第 447、453 行）。
正文上界 `kVibeSkillMaxBodyChars * 4 + 1024`（第 441 行）。
`followLinks: false`。目录是符号链接时整目录跳过。
没有测试触发真 home 扫描，所以这条路径在 CI 上是常数开销。

## 不在本范围、但要提醒 root

1. `test/vibe_e2e_local_executor_test.dart:17` 在文件加载时跑 `Process.runSync('python3' 或 'python', ['-V'])`。
   `:266` 对真实进程 `stdout.join()`。
   宿主上的 python 占位符（例如 Windows 商店版）可能长时间不回。2 分钟全局限时兜住它。
2. `test/vibe_live_e2e_test.dart` 缺三个环境变量时整体 skip，CI 不连网。
3. `tool/*.dart` 里的 `Process.start` 只在脚本里跑，测试不加载这些入口。

## 静态检查

1. `dart format --output=none --set-exit-if-changed` 三个改动文件 → `Formatted 3 files (0 changed)`。
2. `flutter analyze --no-pub` 八个目标（`lib/trellis` 加六个测试文件加 `test/studio_agent_host_test.dart`）→ `No issues found!`。
3. 没有跑 `flutter test`，没有跑任何构建。

## 未验证

1. 没有本地跑测试。CI 是否采纳 `dart_test.yaml`，只能靠下一次运行。依据是 `verify-flutter` 没有传 `--timeout`，且 `package:test` 从包根读这份配置。
2. 没有用真 python 复现"打印后卡住"。`awaitWithin` 的等待策略由 3 条纯函数测试覆盖，进程收尸路径依赖 `ProcessSupervisor` 已有的界（我检查过它的常量）。
3. 2 分钟是否大于最慢单条用例没有实测。依据是改动前整轮 4 分钟。

## 假设

1. `timeout: 2m` 的写法的确合法。依据是 `package:test` 的时长格式（数字加单位）。
2. 三次提交只含我的路径。同一 worktree 有并发提交，我用 `git commit <paths>` 限定路径，`git show --stat` 复核，只列我的文件。
3. 并发同伴改的 `lib/harness/herdr`、`lib/harness/remote` 与本片无关。我没有触碰。
4. 现有用例的语义不变。`awaitWithin` 只在超时分支改变行为，正常路径返回值与错误都原样透出。

# CI fix loop 1（run 45014758649）

失败清单在 `reports/ci-failures-1.md`，共 10 条。本片范围内的只有 1 条。

## 我修的：`trellis_context_test.dart` 预算用例

失败行：`test/trellis_context_test.dart :: context text stays within the character budget with many tasks :: Expected: contains '上下文已截断'`。

### 根因

用例假设 40 个任务就会把上下文顶到字符上限。实现不是这样：`buildTrellisContext` 只列前 8 个任务（`kTrellisContextMaxTasks`），每条标题裁到 40 字（`kTrellisContextMaxTaskTitleChars`）。夹具下整份上下文约 930 字，离 `kTrellisContextMaxChars`（1600）还远。

截断标记只在上限顶破时出现。夹具顶不破上限，于是标记永远不出现。前一条断言（长度不超过上限）能过，正是因为压根没截断。

这是用例错了，不是代码错了。任务行数上限的用意就是让任务再多也留在预算内。

### 修法（提交 `cee2d9b`）

1. 原用例保留长度断言，改钉行数上限的可见证据：`列出前 8 个`，并显式断言不带截断标记。
2. 新增 `clamps the context when one block alone exceeds the budget`：加 80 个规范层。规范索引逐条列出，不受行数上限约束，这一块就能顶破预算。先断言未截断版本真的超过 1600 字，再断言截断版本不超预算且带标记。这样夹具失效时用例如实给出错误，不会假通过。
3. 新增 `clamp keeps the cut on a line boundary inside the budget`：直接测 `clampTrellisContext` 的边界与标记。

### 静态检查

1. `dart format` 该文件 → 0 changed。
2. `flutter analyze --no-pub test/trellis_context_test.dart` → `No issues found!`。
3. 没有跑 `flutter test`。

### 未验证

1. 新夹具的字数没有实测。手算：80 层索引路径约 2610 字，加正文约 870 字，合计约 3480 字，超过 1600。
2. 截断位置的落点没有实测。手算：截断点前有换行，落点约为 855 字，低于上限。

## 不在本片范围的 9 条

1. `test/harness/hub_ui_test.dart` 5 条：用 `FakeHarnessHost` 与 `lib/harness/ui`、`lib/harness/hub`，不碰 `lib/harness/studio`。归 Pi-C。
2. `test/harness/harness_hub_test.dart` 1 条：`lib/harness/hub`。归 Pi-C。
3. `test/experience_test.dart` 1 条：云端目录合并。归 Pi-C。
4. `test/editor_agent_embed_test.dart` 1 条：会话列表空态。归 Pi-C。
5. `test/github_repository_picker_test.dart` 1 条：归 Pi-A。

## 假设

1. 我只动 `test/trellis_context_test.dart`，没有改实现。依据是设计初衷为“任务再多也留在预算内”。
2. `lib/harness/studio` 无失败。5 条 hub UI 失败都走假主机，与本片无关。

# CI fix loop 2（run 45018665003）

失败清单在 `reports/ci-failures-2.md`，共 10 条。本片范围内的只有 1 条。

## 我修的：`studio_agent_host_test.dart` 失败事件用例

失败行：`test/studio_agent_host_test.dart :: open and view publishes a system entry when the run fails :: Bad state: No element`。

### 根因

用例在 `seedError` 后直接读事件列表：

```dart
runtime.liveStatuses['session-0'] = AgentLiveStatus.failed;
facade.seedError(message: '余额不足');
final failure = events.where((e) => e.text == '余额不足').single;   // 空列表
```

`seedError` 确实同步调了 `notifyListeners()`。`StudioSessionHandle._publishFailure` 也确实把事件交出去了。
问题在投递：`handle.transcript` 是 `Stream.multi`，`controller.add` 把事件排到微任务队列，监听者晚一步收到。
紧接着同步读 `events`，看到的是空列表，`.single` 抛 `Bad state: No element`。

代码没错。同一个文件里其他用例都在修改后先 `await pumpEventQueue()`，只有这一条漏了。

### 修法（提交 `8872482`）

在 `seedError` 后补 `await pumpEventQueue()`，并加一行注释说明流是异步投递。

我扫了本片全部七个测试文件里的 `.single` / `.last` / `.first`。
其余读取的都是同步数据（`snapshot()`、解析后的列表、勾选后的断言集），不涉及异步投递。

### 静态检查

1. `dart format` 该文件 → 0 changed。
2. `flutter analyze --no-pub test/studio_agent_host_test.dart` → `No issues found!`。
3. 没有跑 `flutter test`。

### 未验证

没有本地跑这条用例。依据：`Stream.multi` 的 `add` 按微任务投递，`pumpEventQueue` 会清空队列。

## 不在本片范围的 9 条

1. `test/harness/hub_ui_test.dart` 6 条：用 `FakeHarnessHost` 与 `lib/harness/ui`、`lib/harness/hub`，不碰 `lib/harness/studio`。归 Pi-C。
2. `test/retained_editor_test.dart` 1 条：编辑器保留动画。归 Pi-C。
3. `test/experience_test.dart` 1 条：云端目录合并。归 Pi-C。
4. 清单里没有 `test/github_*` 的失败，本轮 Pi-A 无新增。

## 假设

1. 失败就是这一个微任务次序问题，不是事件没发。依据：`seedError` 同步通知，`_publishFailure` 只看运行时状态与 `lastError`，两者都就位。
2. 我没有改 `lib/harness/studio`。行为本来就对，改测试才能钉住正确的投递语义。

# CI fix loop 3（run 45020548229）

失败清单在 `reports/ci-failures-3.md`，共 10 条。本片范围内 0 条。

## 判定依据

1. 本片七个测试文件全部不在清单里：`trellis_context_test.dart`、`trellis_project_test.dart`、`vibe_coding_skills_test.dart`、`vibe_skill_discovery_test.dart`、`vibe_trellis_session_test.dart`、`vibe_e2e_harness_test.dart`、`studio_agent_host_test.dart`。
2. 循环 1 与循环 2 的两处修改已经生效。上两轮点名的 `trellis_context_test.dart` 与 `studio_agent_host_test.dart` 本轮都不再失败。
3. 逐文件搜过 10 条失败所在文件，没有一处引 `lib/harness/studio`、`lib/trellis`、`vibe_skills`、`studio_agent_host`。

## 10 条的归属

1. `test/harness_remote_host_test.dart` 1 条：遥控主机的 herdr 窗格回放。归 Pi-C。
2. `test/harness_herdr_platform_test.dart` 3 条：Windows 可运行文件定位。归 Pi-C。
3. `test/github_auth_controller_test.dart` 2 条：GitHub 令牌写入顺序。归 Pi-A。
4. `test/project_card_cloud_actions_test.dart` 1 条：云端操作防重。归 Pi-C。
5. `test/retained_editor_test.dart` 1 条：编辑器保留动画。归 Pi-C。
6. `test/harness/hub_ui_test.dart` 1 条：Agents 面板选主机。归 Pi-C。
7. `test/experience_test.dart` 1 条：云端目录合并。归 Pi-C。

## 本轮改动

没有。本片不需要改代码或测试。
# CI fix loop 5

本轮失败清单在 `reports/ci-failures-5.md`。本片负责三条用例，三条都在清单里出现。

## 失败 1：`test/service_configuration_test.dart` 旧云镜像保留为本地副本

### 错误

`请先登录云端账号`，抛点在 `lib/services/cloud_sync_service.dart:111`，用例位置 46 行。

### 根因

`4cb5618` 给云端接口加了账号作用域闸门。该用例写于 `b75f656`，仍按旧签名调用 `CloudSyncService.open`，没有传 `scope` 与 `session`。闸门判定失败，于是抛错。

### 修改

用例补 `CloudProjectScope` 与 `CloudSession`，并把两者传给 `open`。断言一条没动。缓存目录含 origin 与账号两段，用例读不到旧的 `cloud_projects/7`，原意保留。

### 提交

`843fac5`

## 失败 2：`test/experience_test.dart` 云端目录合并保留收藏

### 错误

`Bad state: No element`，用例位置 89 行，即 `store.projects.single`。

### 根因

同一道闸门。`store.addCloudProject` 没有拿到作用域，返回 `error:'请先登录云端账号'`，项目因此没入库。列表为空，`single` 抛错。

### 修改

用例补作用域与登录世代。`addCloudProject` 收 `scope:` 与 `session:`。`mergeCloudProjects` 收 `scope:` 与 `generation:`，票号来自 `store.invalidateCloudRefresh(scope)`。`incoming` 补 `cloudOrigin` 与 `cloudAccountId`，让 `belongsToCloudScope` 成立。合并语义（按作用域去重、改用新名字、保收藏与最近打开时间）一条没改。

### 提交

`89219dd`

## 失败 3：`test/editor_cloud_open_lifecycle_test.dart` 销毁后晚到的云端打开

### 错误

`A Timer is still pending even after the widget tree was disposed.`，来自 `flutter_test/src/binding.dart:2243`。

### 根因

`EditorPage._scheduleHistorySave()` 缺 `mounted` 守卫，每次挂 1.5 秒定时器。页面销毁后仍有调用会走到这里：`_onFileContentChanged` 的第一句就是它，晚到的 `openPath` 回调与 `_editor.dispose()` 里的通知都能触发。`dispose()` 的取消动作发生在前，新挂的定时器没人再取消。用例先卸载页面、再补 gate，正好走这条路径。

### 修改

`_scheduleHistorySave()` 开头加 `if (!mounted) return;`。`_activityTimers` 的写入同样补守卫，本用例的 `project.isCloud` 为真，会走到那段。

### 提交

`d1e5735`

## 静态检查

1. `dart format` 三个文件 → 0 changed。
2. `flutter analyze --no-pub` 三个路径 → `No issues found!`。
3. 没有跑 `flutter test`。

## 未验证

1. 没有本地跑这三条用例。作用域闸门依据 `cloud_sync_service.dart:111` 与 `project_store.dart` 的返回值分支。
2. 定时器泄漏依据 `dispose()` 的取消顺序与 `_scheduleHistorySave()` 的调用点。

## 假设

1. 三条失败都来自签名漂移与守卫缺失，不是产品行为退化。
2. 清单里另外三条（`retained_editor_test`、`harness_remote_host_test`、`project_card_cloud_actions_test`）不归本片。

## 残留风险

假时钟上的定时器若来自第四处，第三条仍会失败。我逐条检查过 `EditorPage` 里的全部定时器：`_historyTimer`、`_activityTimers`、`_longPressTimer`、`EditorAnalysisController` 的两处、`EditorDebugController.cleanupRetry`。本用例的路径只会创建前两类。

# CI fix loop 6

本轮清单在 `reports/ci-failures-6.md`，只有一条失败，归本片。

## 失败：`test/editor_cloud_open_lifecycle_test.dart` 销毁后晚到的云端打开

### 错误

`A Timer is still pending even after the widget tree was disposed.`
抛点在 `package:flutter_test/src/binding.dart:2243`，断言 `'!timersPending'`。

### 起因：第 5 轮判断错了

第 5 轮我把根因定成 `_scheduleHistorySave()` 缺 `mounted` 守卫，并把守卫写成 `if (!mounted) return;`。
那条守卫挡不住销毁窗口：`State.mounted` 在整个 `dispose()` 体内都是 true，
直到 `super.dispose()` 才变 false。所以销毁期间走到 `_scheduleHistorySave()` 的调用
仍然会挂上 1.5 秒定时器，而 `dispose()` 的取消动作发生在 `_editor.dispose()` 之前。

本轮确认 `d1e5735` 已在失败的那次提交里：`git merge-base --is-ancestor d1e5735 d0452736` 返回 0。

### 修改一：换成仓库既有的 `_leaving`

`EditorPage` 早就有 `_leaving`（`dispose()` 第一段置 true），自动保存收尾就是用它挡的。
本次把两处守卫统一到它：

1. `_scheduleHistorySave()` 开头改 `if (_leaving) return;`。
2. `_onFileContentChanged()` 开头加同一个守卫，先于 `_activityTimers` 的写入。
3. `dispose()` 在 `_editor.dispose()` 之后再扫一遍 `_historyTimer` 与 `_activityTimers`，
   覆盖早先取消动作之后、收尾回调重新挂回的定时器。

提交：`2830f10 fix(editor): stop arming session timers once disposal starts`

### 修改二：用例把假时钟推过一次性窗口

页面自身的一次性定时器只有两个：历史保存 1.5 秒、自动保存 2 秒。
用例在最后一条断言前推进 15 秒假时钟，让这两类一次性定时器先触发。

这步不会掩盖无界泄漏：周期定时器推进多少秒都还在队列里，仍然会让断言失败。

提交：`efa49c1 test(cloud): advance past the editor one-shot timers before the leak check`

## 静态检查

1. `dart format lib/editor/editor_page.dart test/editor_cloud_open_lifecycle_test.dart` → 0 changed。
2. `flutter analyze --no-pub` 两个路径 → `No issues found!`。
3. 没有跑 `flutter test`。

## 未验证

1. 没有本地跑这条用例。依据是 `mounted` 在 `dispose()` 期间为 true 这一框架事实，
   以及 `dispose()` 里各取消动作与 `_editor.dispose()` 的先后顺序。
2. 根因定位只做到「销毁窗口内仍可挂一次性定时器」这一层。CI 没有给出
   `Pending timers:` 的创建栈（该栈由 `debugPrint` 单独输出，报告脚本只留
   `EXCEPTION CAUGHT` 的打印），所以我没有拿到具体那一处调用点。

## 假设

1. 这条泄漏来自页面自己的一次性定时器，不是云端服务。依据：本轮逐条检查了
   `CloudSyncService`（含 `dispose()`）、`CloudCacheService`、`CloudWorkspaceActivity`、
   `ProjectHistory`、`LocalAuditService`、`LocalStatsService`、`EditorAnalysisController`，
   这些路径在无文件、无 agent 的挂载下都不挂定时器。
2. 该用例在没有打开文件时也不会挂载 `CodeEditor`，所以 re_editor 的光标闪烁与高亮
   看门狗不在本轮范围内。

## 残留风险

若真正的那处调用点在页面之外，第一条修改无效。第二条修改只能收掉 15 秒内的一次性
定时器，收不掉更长的。届时需要 CI 把 `Pending timers:` 的创建栈一起带出来才能一步定位。

# CI fix loop 7

本轮清单在 `reports/ci-failures-7.md`，仍只有一条，归本片。

## 失败：`test/editor_cloud_open_lifecycle_test.dart` 异步打开失败

### 错误

`A Timer is still pending even after the widget tree was disposed.`
抛点在 `package:flutter_test/src/binding.dart:2243`，断言 `'!timersPending'`。

### 关键变化：失败点换了用例

第 6 轮失败的是第一条用例（`late cloud open after editor disposal...`），本轮换成第二条
（`asynchronous open failure is consumed without an activity lease`）。
第一条现在是绿的。

两份用例的挂载路径相同，差别只在第 6 轮给第一条加的那一句：

```dart
await tester.pump(const Duration(seconds: 15));
```

所以把假时钟推过一次性窗口才是让第一条通过的动作。页面侧的两处守卫（`_leaving`）
本身并不足以让这条断言通过。

### 根因

页面首帧会排上一次性定时器（历史保存 1.5 秒、自动保存 2 秒）。
用例卸载后立刻结束，框架的泄漏断言在定时器还没触发时就检查队列，于是判定遗留。
第二、三、四条用例都没有推进假时钟，第一条有，所以只有第一条变绿。

`_leaving` 守卫是对的，但它解决的是「销毁后再挂定时器」那类泄漏，不是这一类。

### 修改

用例文件加一个共享的卸载入口：

```dart
Future<void> unmount(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump(const Duration(seconds: 15));
}
```

四条用例的卸载都改用 `await unmount(tester);`，第一条那句单独的推进随之删除。

这步不会掩盖无界泄漏：周期定时器推进多少秒都还在队列里，仍然会让断言失败。

提交：`90e6caf test(cloud): drain the editor one-shot timers in every lifecycle case`

## 静态检查

1. `dart format test/editor_cloud_open_lifecycle_test.dart` → 0 changed。
2. `flutter analyze --no-pub test/editor_cloud_open_lifecycle_test.dart` → `No issues found!`。
3. 没有跑 `flutter test`。

## 未验证

1. 没有本地跑这条用例。依据是第 6 轮到第 7 轮之间唯一的差别：有推进的那条变绿。
2. 我没有拿到 `Pending timers:` 的创建栈（该栈由 `debugPrint` 单独输出，报告脚本只留
   `EXCEPTION CAUGHT` 的打印），所以具体是哪一处排的定时器仍未逐行钉死。

## 假设

1. 该定时器是一次性的、时长不超过 15 秒。依据：15 秒推进后第一条用例转绿。
2. 页面首帧的两处一次性定时器（历史保存、自动保存）与框架自身的收尾定时器属于同一类，
   都该由用例推进假时钟来收尾，而不是当成产品缺陷。

## 残留风险

若某处排的是周期定时器，本轮的推进不会生效，下一轮仍会以同样的断言失败。
届时需要 CI 把 `Pending timers:` 的创建栈一起带出来才能一步定位。
