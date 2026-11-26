# Takeover C：编辑器 / 会话生命周期

负责范围：`test/editor_harness_session_target_test.dart` 的 pending Timer 失败，以及编辑器会话生命周期的收尾归属。

工作树：`D:/MyNewProjects/_wt/mobile/int/qfli_studio_core`（`mobile/integration`，已含全部合并改动）。
未做任何 git 写命令。未改 `remote_harness_host.dart`，未改外部文件夹相关文件。

## 1. CI 失败项与本机现状核对

`reports/ci-failures-6.md` 记录的是 core `606810bd` 的失败。逐条核对本机代码：

| 失败项 | 本机现状 | 归属 |
| --- | --- | --- |
| `harness_remote_device_test.dart`（7 条：设备字段全为 null、os 回退到 unknown） | `758a704`「report the device as soon as the host is built」已在构造函数里先取一帧 | 他人，已修 |
| `external_agent_files_test.dart :: read 与 write 走协调通道` | `9847ea7`「resolve project paths against an external root」已修 | 他人，本 Pi 早前提交 |
| `external_explorer_menu_test.dart :: 外部根条目不提供删除` | `a796ccb`「keep an external root usable when the native list is missing」已修。工作树另有未提交的 `lib/editor/file_explorer.dart` | 他人 |
| `editor_harness_session_target_test.dart :: 内置 Agent 的会话不进 hub，直接选中会话 id` | 旧证据指向的根因仍未修，见下 | 本 Pi |

结论：其余三项在新代码上已有对应修复，本次只需处理编辑器用例这一项。

## 2. 根因（有日志证据，不是猜测）

`reports/takeover-old-core-suite.log` 第 3366–3368 行，testID 1546：

```
Pending timers:
Timer (duration: 0:00:02.000000, periodic: false), created:
#0  new FakeTimer._
#6  AppPaths._writableProviderPath (lib/services/app_paths.dart:97)
#7  AppPaths._findStorageDirectory (lib/services/app_paths.dart:87)
#8  AppPaths.storageDirectory (lib/services/app_paths.dart:72)
#9  FileComposerDefaultsStore._file (lib/chat/composer_state.dart:344)
#10 FileComposerDefaultsStore._readAll (lib/chat/composer_state.dart:353)
#11 FileComposerDefaultsStore.read (lib/chat/composer_state.dart:370)
#12 ComposerState.loadDefaults (lib/chat/composer_state.dart:139)
#13 _WorkbenchAgentPaneState._bootstrap (lib/shell/workbench_agent_pane.dart:220)
#14 _WorkbenchAgentPaneState.initState.<anonymous closure> (:167)
```

链路：

1. 首帧选中内置会话，`_openInitialHarnessSession` 发现 `hostId == kStudioHostId`，
   走 `_revealAgentPane()` + `selectSession` 后直接返回。它是同步返回，
   这里不建定时器。
2. 面板展开后 `WorkbenchAgentPane` 第一帧跑 `_bootstrap`，其中
   `_composer.loadDefaults()` 要落到 `FileComposerDefaultsStore`。
3. 该存储没有 `root` 覆盖，于是去问 `AppPaths.storageDirectory()`。
4. `_writableProviderPath` 用 `getter().timeout(const Duration(seconds: 2))`
   探测应用支持目录。widget 测试里 path_provider 的平台通道不回应，
   这个 2 秒定时器一直挂着。
5. 用例结束，`AutomatedTestWidgetsFlutterBinding._verifyInvariants` 断言
   `!timersPending` 失败。

这是**测试隔离缺失**，不是生产生命周期缺陷：

- 定时器属于「探测可写目录」这一超时保护，生产里有真实平台通道回应，
  2 秒内必定结束，或者由 `catch` 吞掉。
- 该定时器由 `Future.timeout` 内部创建，调用方没有句柄，页面 `dispose`
  也无从取消。要它在页面销毁时消失，只能改探测实现本身（见第 6 节遗留项）。
- 同一目录下 10 份编辑器用例一直通过构造参数注入内存实现来避开它，
  注释里写的正是「不碰文件系统，也不留目录探测定时器」。
  两份 harness 用例没有注入，因此吃到了这个定时器。

## 3. 修复

改动全部在测试侧，断言与生产行为零改动。

- 新增 `test/support/memory_composer_defaults.dart`：`MemoryComposerDefaults`
  实现 `ComposerDefaultsStore`，读写都在内存，带 `valueFor(projectId)`
  供断言。文档注释写明为什么编辑器用例要注入它。
- `test/editor_harness_session_target_test.dart`：`mount()` 里传
  `composerDefaults: MemoryComposerDefaults()`，并在 `mount` 的文档注释里
  写明原因与证据链。
- `test/editor_harness_session_wait_test.dart`：两处挂载同样注入。
  这份是 `cf5927a` 新增的用例，本来也缺这一项隔离。

没有改任何 `expect`，没有加 `pump` 去「排空」定时器，没有动
`editor_page.dart` 或 `workbench_agent_pane.dart`。

## 4. 另一处修复的定位说明

`cf5927a`（已提交，本 Pi）修的是另一处真实泄漏：`_awaitHubSession` 的
15 秒超时定时器只在自身 `finally` 里取消，页面先销毁时会越过 `dispose`。
它在**非内置主机**路径上成立，对「内置会话」这条失败不构成解释，
也不冲突：内置路径根本不会进 `_awaitHubSession`。

本次失败即第 2 节那条 2 秒定时器，与 `_awaitHubSession` 无关。
两个问题都已修，互不替代。

## 5. 静态核对

在 `D:/MyNewProjects/_wt/mobile/int/qfli_studio_core`：

- `dart format`（逐文件）：`test/support/memory_composer_defaults.dart`、
  `test/editor_harness_session_target_test.dart`、
  `test/editor_harness_session_wait_test.dart` → 3 个文件，0 变更。
- `flutter analyze --no-pub` 上述 3 个文件 → `No issues found!`
- 未运行任何测试（按约定由云端 CI 运行）。

## 6. 本次改动路径

工作树内、待 Codex 审阅提交：

- `test/support/memory_composer_defaults.dart`（新增）
- `test/editor_harness_session_target_test.dart`（+7 行）
- `test/editor_harness_session_wait_test.dart`（+3 行）

同工作树另有他人未提交改动，未触碰：`lib/editor/file_explorer.dart`、
`test/external_explorer_listing_failure_test.dart`。

## 7. 遗留项（不阻断本次）

1. **`Future.timeout` 的定时器无法随页面取消。**
   `AppPaths._writableProviderPath` 与 `_findWritableDirectory` 的 `tryAdd`
   都用 `Future.timeout`。页面销毁时无从取消。当前靠缓存
   `_storageFuture` / `_storagePathCache` 让整个进程只探测一次，
   生产路径上可接受。若将来要求「页面销毁后零残留定时器」，需要把探测
   改成显式 `Timer` + `Completer`，由调用方绑定生命周期。这属于生产改动，
   本次无证据支持，未做。
2. **其余 `EditorPage` 用例的同样缺口。**
   `editor_background_run_test.dart`、`editor_cloud_open_lifecycle_test.dart`
   等 18 份文件也没有注入 `composerDefaults`。它们在 CI 上目前通过
   （其中一部分不进入 Agent 面板，或首帧只 pump 一次），因此不属本次失败。
   若后续出现同类 pending Timer，按同一方式注入
   `MemoryComposerDefaults` 即可，不需要改断言。
3. **生产侧同类入口。** `home_agents_tab.dart:266` 与
   `agent_runtime_factory.dart:28` 等也走 `AppPaths.storageDirectory()`，
   在 widget 测试里同样会留 2 秒定时器。它们不在编辑器失败路径上，
   本次未改。
4. **真机验证。** 编辑器面板的会话选中、等待超时提示与销毁收尾仍需
   真机走一遍，见 `impl-c.md` §8 与 `wire-c.md` §7。
