# 交叉检查：电脑改动回到手机（C 路）

任务：`11-23-device-sync`。
对象：`mobile/integration` 合入后的实现，以及 `wire-d.md` 的接线。
依据：`prd.md`、`design.md`、`implement.md`、`reports/plan-review.md`（R4、R7、R8、R9）、`reports/impl-d.md`、`reports/wire-d.md`。

## 1 结论

发现 13 处问题。

已修 7 处，分 4 个提交。

未修 6 处，逐条写明理由。

改动前 `flutter analyze --no-pub lib test` 只有 2 条既有 info。改动后仍是这 2 条。

TypeScript 侧 `npm run check`（`tsc --noEmit`）无错误。

`flutter test` 与 `node --test` 没有运行，按约束交给云端 CI。

## 2 已修（按提交）

### 2.1 `9364c99 fix(sync): replay the cached transcript when a session reconnects`

| 位置 | 严重度 | 问题 |
| --- | --- | --- |
| `lib/sync/remote_session_cache.dart:71` | 高 | `read()` 没有任何调用方 |
| `lib/harness/remote/remote_terminal.dart:143` | 高 | 转录流只写不读 |

`design.md` 11.3 写「界面读缓存只在会话流尚未到达时兜底」。
实现只做了写：`cache.append(...)` 在 `_pump` 里，读一次都没有。
断线重连后视图是空的，用户看到的是会话从头开始。

修法：

1. `RemoteTranscriptFeed._start` 先挂一个 700 ms 的计时器。
   这期间一条实时事件都没来，才用缓存补历史。
   实时流正常时视图本来就带全部历史，补了就重复。
2. 新增 `RemoteSessionCache.replaceWith`。
   重新订阅后视图会重放整段会话，此时把缓存换成新历史，不叠加。
3. 缓存里认不出的 `role` 与缺失字段一律跳过，不抛错。

新增 `test/sync/remote_stream_replay_test.dart` 4 个用例：补回历史、实时优先、空缓存、坏行跳过。

### 2.2 同一提交的另一处

| 位置 | 严重度 | 问题 |
| --- | --- | --- |
| `lib/harness/remote/remote_harness_host.dart:91` | 低 | 缓存落点与占位项目不在一处 |

`design.md` 11.1 规定会话文件在 `deviceSessions/<hostKey>/<sessionId>/.session`。
原来的实现是 `deviceSessions/<sessionId>/`，没有 `hostKey`，也没有 `.session`。
两台电脑上同一个会话号会共用一份缓存。

已改成 `deviceSessions/<PlaceholderProjects.hostKey(hostId)>/<sessionId>/.session`，
与 `PlaceholderProjects.streamDirectory` 同口径。

### 2.3 `5f67fe1 fix(sync): reach git projects, explain failures and keep the cache in budget`

| 位置 | 严重度 | 问题 |
| --- | --- | --- |
| `lib/sync/device_sync_launcher.dart:79` | 高 | 需求 7（DR1）整体没有落地 |
| `lib/sync/device_sync_dialog.dart:129` | 高 | 端口抛错会把用户锁进进度框 |
| `lib/sync/device_sync_launcher.dart:83` | 中 | 同步失败没有任何提示 |
| `lib/sync/sync_cache.dart:45` | 中 | 缓存上限（DR5）没有接线 |
| `lib/sync/device_sync_launcher.dart:77` | 中 | 拉完文件后项目仍指向占位目录 |

逐条：

1. **git 优先的路径根本走不到。**
   `DeviceGitPull` 只有测试调用，`_sync` 直接就是文件清单传输。
   验收标准「git 项目同步后，手机拿到与电脑同一提交的文件」无法成立。
   已加 `_pullGit`：先取 `project_git_info`，能克隆就克隆。
   `.git` 超过 200 MB 时按 R8 弹确认框，文案写明「这是占用量，不是下载量」。
   本地已有仓库时 `fetch` 之后再按 `origin/<branch>` 快进，否则工作区没有文件。
   不可读、没有 origin、用户取消，三种情况都退回文件同步。
   注意：`NativeGitBackend` 在 Android 上 `pullRebase` 直接抛「不支持」，
   所以这里走 `fetch` + `merge`，不走 `pullRebase`。
2. **进度框无法关闭。**
   `runDeviceSync` 只接住了 `DeviceSyncException`。
   `RemoteException`（「电脑未连接」「请求超时」）与 `SocketException` 会直接穿出去，
   而进度框是 `barrierDismissible: false`，用户只能杀掉应用。
   已改为接住所有错误、关掉进度框、再给一句「同步未完成 + 原因」。
   进度框改用 `popUntil((route) => route is! DialogRoute<void>)` 清理，不再依赖「顶层路由恰好是它」。
3. **失败静默。**
   `DeviceSyncLauncher.run` 原来返回 `void`，`runDeviceSync` 返回 false 时什么也不做。
   现在返回 `bool`，失败路径都弹一次 SnackBar。
4. **缓存上限没生效。**
   `SyncCache` 有 `budgetBytes` 与 `evictCandidates`，但同步从没建过 `SyncCache`。
   `DeviceSyncService.apply` 也从不淘汰，所以「超限时淘汰最久未用的项目」不会发生。
   现在 `apply` 在写入前按本次字节数申请空间（`keep` 里总有当前项目）。
   写完后再更新索引。`DeviceSyncLauncher` 用
   `<storage>/projects/deviceProjects/sync_index.json` 建立索引。
5. **拉完文件看不到文件。**
   `pullFiles` 与 `DeviceSyncLauncher` 成功后只改 `filesPulled` 与 `placeholder`，
   `project.path` 仍指向只装了 `.qfli` 的占位目录。
   用户确认过一次同步，编辑器和文件树里仍然只有隐藏目录。
   两处都改成把 `path` 指到副本根。

新增 `test/sync/device_sync_failure_test.dart` 6 个用例：
端口抛错时关框并说明、传输失败后旧文件仍在、git 三种决策、拉完指向副本。

### 2.4 `a85aaab fix(sync): resolve project-relative paths on the computer side`

| 位置 | 严重度 | 问题 |
| --- | --- | --- |
| `lib/sync/remote_device_file_port.dart:26` | 高 | 分块读取在电脑上必然失败 |
| `companion/remote_agent/src/agent/core.ts:301` | 高 | 同上，另一侧 |

清单里的 `path` 是相对项目根的。
`RemoteDeviceFilePort.read` 原样把这个相对路径发给 `fs_read`，
电脑端 `core.ts` 用 `path.resolve(msg.path)` 解析，基准是 agent 自己的进程目录。
于是 `path.relative(root, ...)` 得到 `../..` 开头的串，
`readChunk` 的 `safeRelativePath` 直接拒绝。

结果：清单能取到，文件一个都传不下来。

已加 `resolveDevicePath(root, path)`：记住清单里的 `root`，读取前拼成电脑那一侧的绝对路径，
分隔符跟着根走（`C:\` 用反斜杠）。新增 `test/sync/remote_device_file_port_test.dart` 6 个用例。

### 2.5 `5526d6a fix(companion): match the ignore table regardless of case`

| 位置 | 严重度 | 问题 |
| --- | --- | --- |
| `companion/remote_agent/src/agent/fs-sync.ts:70` | 中 | 忽略表大小写不一致 |

电脑侧用 `FS_IGNORE_DIRS.includes(name)` 精确匹配，表里写的是 `Pods`、`DerivedData`。
手机侧 `kIgnoredDirectoryNames.contains(name)` 同样精确匹配，表里也写的是 `Pods`。
清单里保留 `pods/` 时两端都当源码目录，会一直传。
`pods/` 与 `Pods/` 在不同平台上大小写不同，同一次同步会先当成新增再当成删除。

已把电脑侧改成小写比较（表本身转小写，匹配时 `toLowerCase()`），
`.PYC`、`server.LOG` 与 `pods/`、`deriveddata/` 都能识别。
新增 `test/fs-sync-ignore-case.test.ts` 4 个用例，其中一个走真实临时目录。

手机侧的表本来就与电脑侧同名同义，这一轮没动，两端现在都按小写比较。

## 3 未修（含理由）

| 位置 | 严重度 | 问题 | 未修理由 |
| --- | --- | --- | --- |
| `lib/sync/device_sync.dart:253` | 中 | 单个文件整体读进内存再计算哈希（`_fetch` 用 `BytesBuilder`），中继 4 MiB 帧下大文件峰值可达文件大小 | 要改成边收边写边算哈希，同时保留「哈希通过才改名」的语义，需要重写暂存流程与新增测试。属于结构改动，不在本次交叉检查的修复范围 |
| `lib/sync/device_sync_dialog.dart:40` | 低 | 确认框不显示已删除项数量 | 需求只要求「只传变化的文件」，删除数量属于提示优化 |
| `lib/sync/device_sync_launcher.dart:206` | 中 | 每次同步新开一次连接，中继上多一次短暂重连 | `wire-d.md` 5.1 已记录并说明取舍，复用连接要把 `RemoteController` 提到页面级 |
| `lib/sync/placeholder_project.dart:136` | 中 | `discardIfUnused` 没有调用方，会话结束不清理占位项目 | 会话结束与编辑器的生命周期耦合，属于需求 11 的收尾动作，本次不改动会话关闭路径 |
| `lib/harness/remote/remote_terminal.dart:150` | 低 | 补历史靠 700 ms 静默窗口判断，慢到没有事件的电脑会重复一遍 | 视图没有「回放中」标志，判定只能靠时间窗口。真要精确要改 `SessionView` |
| `companion/remote_agent/src/agent/git-info.ts:96` | 低 | `detectDirty` 只比时间戳，识别不出「删除未暂存」 | `impl-d.md` 8.2 已记录为已知限制 |

## 4 检查过且没有问题的点

1. 路径安全：`safeRelativePath` 与 `isSafeRelativePath` 两侧规则一致。
   绝对路径、`..`、反斜杠、冒号、控制字符一律拒收，`realpath` 再复核落点。
2. 删除的正确性：清单截断或忽略表版本不一致时整次放弃，不会把缺项当成删除。
3. 失败保留：写入走 `.incoming` 暂存 + 哈希检查 + 改名，删除放在全部写入之后。
   失败时旧文件仍在（已由新测试覆盖）。
4. 协议对齐：`fs_manifest`、`fs_read`、`fs_chunk`、`project_git_info`、`info` 的新字段
   在 `protocol.ts` 与 `protocol.dart` 上逐字段一致。
   `AgentInfo.fromJson` 对缺字段取 null，旧电脑端不会打断解析。
   `lanUrls` 只在 `wss://` 时保留。
5. 设备信息映射：R4 的三条兜底（`hostName`→`host`、`os`→`platform`、版本原样或 null）都实现了。
   `remote_harness_host.dart` 的映射与 `test/harness_remote_device_test.dart` 一致。
6. 入口可达性：`ai_panel` 的按钮要 `deviceSyncEnabled` 与 `onDeviceSync` 同时成立，
   `editor_page` 按 `DeviceSyncLauncher.canSync` 挂动作，`main.dart` 的 profile 已打开开关。
   三处串起来按钮能出现。
7. `Project` 的五个新字段：只追加块，`toJson` 只在非空或为真时写出，旧记录照常读入。

## 5 静态检查

| 项 | 范围 | 结果 |
| --- | --- | --- |
| `dart format` | 本次改动的 9 个 Dart 文件 | 2 个文件有格式化，其余 0 处改动 |
| `flutter analyze --no-pub` | 改动文件 | `No issues found!` |
| `flutter analyze --no-pub` | `lib` 与 `test` 全量 | 2 条既有 info（`composer_card.dart:346`、`harness_host.dart:6`），改动前后一致 |
| `npm run check` | `companion/remote_agent` | 无错误 |

`flutter test`、`node --test`、模拟器、虚拟机都没有运行。

## 6 提交清单

| 仓库 | 提交 | 说明 |
| --- | --- | --- |
| core | `9364c99` | 重连后补回会话流 |
| core | `5f67fe1` | 走 git、说明失败、遵守缓存上限、指向副本 |
| core | `a85aaab` | 电脑侧解析项目相对路径 |
| app | `5526d6a` | 忽略表大小写无关 |

只提交了上面点名的路径。
同工作树里别人的改动与插件注册文件没有进入任何提交。

## 7 仍需真机

1. 真实配对下点「从电脑同步」，确认电脑在线等待、确认框、进度框与结果框的顺序。
2. 在手机上克隆一个公开仓库，另配一个超过 200 MB 的仓库确认阈值文案。
3. 同步 1 万个以上文件的项目，确认分块读取与哈希检查的耗时。
4. 断网重连后打开同一个会话，确认历史补回且没有重复。
