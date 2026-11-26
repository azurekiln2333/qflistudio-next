# Takeover CI C1：两处新用例的假异步卡死风险（只读排查）

范围：`test/editor_harness_session_wait_test.dart` 与
`test/external_explorer_listing_failure_test.dart`，均在 core
`f434128`（前一项由 `8b0d1bf` 带入）。只读检查，未改任何文件。

**结论：未找到能解释「12 分钟不结束」的确证根因。**
两份用例都不含真实平台/磁盘操作会永久悬挂的结构，已排除的路径列在第 3 节。
真正的判断要等云端日志。

## 1. `editor_harness_session_wait_test.dart`

两条 `testWidgets`，注入 `MemoryComposerDefaults()` 与 `FakeAgentRuntime`，
主机会话列表恒为空，因此页面停在 `_awaitHubSession` 里。

潜在异步源与判定：

| 异步源 | 是否在挂载时触发 | 判定 |
| --- | --- | --- |
| `_openInitialHarnessSession` → `_awaitHubSession` 的 15 秒定时器 | 是 | 假时钟泵进即可推进。第一条不泵（只 `pump(50ms)` 就拆页），靠 `dispose` 取消。可控 |
| `EditorPage._restoreSession`（首帧后 `scheduleTask(Priority.animation)`） | 是 | `ProjectHistory.load` 全部同步实现（`existsSync` + `readAsStringSync`，第 160–166 行），没有 `Timer`，不会悬挂 |
| `_saveHistory()`（`dispose` 里 `unawaited`） | 是 | 第一句就是 `if (!_sessionRestored.isCompleted) return;`，首帧后立刻拆页时直接返回，不写盘 |
| `_editor.saveFile` 的自动保存 | 否 | `settings.autoSave` 默认关，且 `_leaving` 挡住 |
| `FileExplorer`（经 `_rebuildRoot` → `ProjectHistory.load`） | 是 | 与上面同一条同步读取路径 |
| `_syncAgentFileEvents` | 是 | 订阅 `FakeAgentRuntime` 的内存流，不碰平台 |
| `store` / `settings` / `auth` 写盘 | 否 | 三者都是默认构造，`_storage` 为 null 时 `_persist()` 直接 `Future.value()`。`signIn` 在 `setUp` 里 `await` 完成，那时不在假异步区 |

值得留意的非悬挂点：第二条用例 `pump(seconds: 15)` 会先触发超时定时器，
随后才执行 `_showSnack`。`SnackBar` 自带 4 秒自动关闭定时器，但用例结尾
`pumpWidget(SizedBox.shrink())` 拆掉整棵 `MaterialApp`，`ScaffoldMessenger`
随之销毁并取消它。这条路径**不会**留下未结束的定时器，只会让断言
`find.textContaining('等待超时')` 依赖提示仍在屏上。

## 2. `external_explorer_listing_failure_test.dart`

`FileExplorer` 挂载在带 `Scaffold` 的 `MaterialApp` 下，外部根由
`store.addExistingExternal` 登记，原生列目录走 mock 通道。

潜在异步源与判定：

| 异步源 | 判定 |
| --- | --- |
| `FileService.listSorted` → `ExternalFolderService.list` → mock `folderList` | 通道已 mock，`pumpAndSettle` 可推进。失败时抛 `PlatformException`，被 `_loadChildren` 接住 |
| `ExternalFolderService.ensureAvailable()` | mock 对 `resolveFolders` 返回列表，成功返回 true，不碰真实插件 |
| `_restoreExpanded` / `_restoreLegacyWorkspace` → `ProjectHistory.load` | 同步实现，同上 |
| `_persistExpanded` → `ProjectHistory.saveExpandedDirs` | 真实 `File` 写入，但排在微任务队列上；`IosSandboxPaths` 只在 iOS 才求值（`AppPaths.isIos`），Linux CI 上是 null |
| `SnackBar` 4 秒关闭 | 用例显式 `pump(seconds: 5)` 推进，之后 `pumpAndSettle` |
| `SettingsStore()` 在 `mount` 里直接构造 | 生命周期不归用例所有，但默认 `_storage` 为 null，`_persist()` 立即返回，不会留定时器 |

`pumpAndSettle` 的默认上限是 10 分钟，超时后抛异常而不是继续等。
因此驱动这条用例卡住的机制，只能是某个**每帧都排新一轮帧**的重建循环，
或者某个**真实异步操作永不完成**。上面列出的每一项都不属于这两类。

## 3. 已排除

- 没有 `Future.timeout` 目录探测：两处都已注入 `MemoryComposerDefaults`，
  宿主目录探测不再在挂载时出现。
- 没有真实 path_provider 调用：`store` / `settings` / `auth` 都未解析存储目录。
- 没有真实进程、没有 `Timer.periodic`。
- 没有 `await tester.runAsync`，不存在真实 I/O 与假时钟混用。

## 4. 仍需云端证据才能定性的点

1. **总时长是否真由这两份文件贡献。** 12 分钟可能是多份 suite 并行后的
   整体耗时，也可能卡在别的文件。旧 CI 只跑 2 分钟，新增测试文件数量本身
   就会拉长总时长，这一点不能由「12 分钟」单独推出卡死。
2. **进程是否在推进。** 需要日志里的 testStart 序列：若 testStart 之间
   持续有输出，说明只是慢；若某个 testID 之后长时间静默，才是卡死。
3. **`pumpAndSettle` 是否撞到 10 分钟上限。** 若撞到，日志会给出
   `pumpAndSettle timed out`，那时要查这一帧被谁不停标脏。
4. **`SnackBar` 断言对时序的依赖。** 第 1 节末指出，第二条用例的
   `等待超时` 断言依赖提示在屏上。若云端出现该断言失败而非卡死，
   根因是时序而不是异步悬挂，届时再讨论是否需要调整，不改现有断言。

## 5. 未改动

本次未修改任何生产代码或测试。若云端证据落地后再定改动点，建议的最小面：

- 卡死且落在 `editor_harness_session_wait_test.dart`：优先查第二条用例的
  提示时序，而不是加 `pump` 排空。
- 卡死且落在 `external_explorer_listing_failure_test.dart`：优先查
  `_refresh` 是否与 `refreshSignal` 形成重入循环。
