# 接线报告（D 路）

任务：`11-23-device-sync`（`11-23-mobile-files-agents` 的子任务）。
分支：`mobile/integration`，集成工作树 `_wt/mobile/int`。
两个缺口各一个提交。

## 1. 提交一览

| 缺口 | 仓库 | 提交 | 提交说明 |
| --- | --- | --- | --- |
| W1 | core | `9c803fc` | `feat(sync): reach the device sync entry from the editor` |
| W1 | app | `8d860b8` | `feat(sync): turn on the device sync entry for the main app` |
| W2 | core | `086cd12` | `feat(harness): open a placeholder project for a session that is not here` |

## 2. W1：同步入口不通

### 2.1 问题

`AiPanel` 的「从电脑同步」按钮要两个条件才显示：产品开着 `deviceSyncEnabled`，并且宿主传入 `onDeviceSync`。
审查发现两边都没有：编辑器页构造 `AiPanel` 时不传 `onDeviceSync`，主 App 的 profile 也不设 `deviceSyncEnabled`。
结果按钮永远不出现。

### 2.2 改动

新增 `DeviceSyncLauncher`，由它承担按下按钮之后的一切。
编辑器页只在项目来自配对电脑时才把动作挂上去。主 App 的 profile 打开产品开关。

判定写成两处，各自守一件事：

1. 产品开关 `deviceSyncEnabled` 守「这个产品有没有这个入口」。主 App 设为 true，离线语言产品保持默认的 false。
2. `DeviceSyncLauncher.canSync` 守「这个项目能不能从电脑同步」。条件是 `project.isDevice` 并且有 `deviceHostId`。

两处同时成立，按钮才出现。只满足一处时按钮不存在，不会出现点了没反应的按钮。

### 2.3 连接的归属

编辑器页不持有配对连接。一个页面对多个会话，而配对只有一份，把 `RemoteController` 挂在页面上会多出一条常驻的 WebSocket。
所以 `DeviceSyncLauncher.run` 在按下按钮时才打开 `RemoteStore` 与 `RemoteController`，同步结束立刻 `dispose`。
借用期间完成三件事：取 `deviceProjects` 下的副本根、调 `runDeviceSync` 走确认与分块传输、成功后把项目从占位改成已拉取并 `store.touch`。

失败一律转成一次 SnackBar 说明，不抛给界面。三种情况有各自的文案：项目没记下电脑路径、取不到可写的本地目录、没有配对或电脑不在线。

### 2.4 文件

core：
- `lib/sync/device_sync_launcher.dart`（新增，`DeviceSyncLauncher.canSync` 与 `run`，借用的连接在 `finally` 里关掉）
- `lib/editor/editor_page.dart`（`_syncFromComputer`，并在 `AiPanel` 构造处按 `canSync` 决定是否挂上 `onDeviceSync`）
- `test/sync/device_sync_wiring_test.dart`（新增 9 个用例）

app：
- `lib/main.dart`（主 App profile 设 `deviceSyncEnabled: true`，并写明离线产品不设该开关）

### 2.5 静态检查

- `dart format` 上述文件：0 处改动。
- `flutter analyze --no-pub` 上述文件：`No issues found!`

### 2.6 新测试覆盖

`test/sync/device_sync_wiring_test.dart` 覆盖下列情形。
配对电脑项目可同步。普通本地项目、云端项目、缺 `deviceHostId` 的项目都不可同步。
离线产品的 `deviceSyncEnabled` 默认关闭。主 App 的 profile 开启后为 true。
同一台电脑同一会话的 `hostKey` 稳定。已拉取文件的占位项目不在移除之列。
远程会话行的 `hostKind` 为 `remote` 且带着会话目录。空仓库里查设备项目返回 null。

## 3. W2：会话落到错误的项目

### 3.1 问题

首页 Agents 标签点一行会话时，`openAgentSession` 先按会话目录找本地项目，找不到就退回「最近更新的本地项目」。
配对电脑上的会话在手机上当然找不到目录，于是每次都打开最近那个项目。
编辑器显示的目录、文件树与保存位置都不是用户以为的那个项目。

### 3.2 改动

退回顺序改成三步：会话目录对应的本地项目、该会话已有的占位项目、建一个占位项目。
只有远程会话走占位项目这条路，本机与 Herdr 的会话保持原来的退回行为。

占位项目由 `PlaceholderProjects.ensure` 建在 `projects/deviceSessions/<hostKey>/<sessionId>/`，同时登记到项目列表。
登记失败时不阻断打开：目录已经在，会话能落上去，下一次点同一行会按「已有」命中。

随后 `openEditorPage` 照原样带上 `harnessSession`，编辑器页首帧就选中该会话。

### 3.3 文件

core：
- `lib/harness/ui/agents_entry.dart`（`openAgentSession` 改用 `resolveSessionProject`。新增 `resolveSessionProject`。补 `harness_host.dart` 与 `placeholder_project.dart` 的引用）

### 3.4 静态检查

- `dart format` 上述文件：0 处改动。
- `flutter analyze --no-pub` 上述文件：`No issues found!`
- 新增的 `await` 让 `BuildContext` 跨越异步间隙，补了 `if (!context.mounted) return;`，`use_build_context_synchronously` 已清零。

## 4. 与其它 Pi 的共存

两个工作树有别人同时在改。提交一律按路径点名，只含下面这些文件：

- `lib/sync/device_sync_launcher.dart`
- `lib/editor/editor_page.dart`（只有我这 27 行）
- `test/sync/device_sync_wiring_test.dart`
- `lib/harness/ui/agents_entry.dart`
- `lib/main.dart`（只有这 3 行）

生成的插件注册文件（`linux/`、`macos/`、`windows/` 下的 `generated_plugin*`）在 app 工作树里是脏的。这些不是我的改动，没有进任何提交。

## 5. 残留风险

1. 同步按钮每次按下都开一条新连接再关掉，中继上会看到一次短暂的重连。配对与鉴权不变，只是多一次连接开销。以后若要复用连接，得把 `RemoteController` 提到页面级，那是更大的改动，本次没做。
2. 占位项目按「会话 id」建目录。电脑侧同一个项目换一个会话，手机上会再多一个占位项目，两份文件各自存一份。要合并得先有稳定的项目标识，目前协议里没有。
3. `resolveSessionProject` 里登记失败时仍然打开目录，此时项目列表里暂时看不到它。进程重启后记录丢失，下一次点同一行会重建。
4. 这条链路没有在真机上跑过，确认框、分块传输、占位项目落盘只有单元测试与静态检查覆盖。真实配对与中继行为留给云端 CI 与真机验收。

## 6. 静态检查汇总

| 项 | 结果 |
| --- | --- |
| `flutter analyze --no-pub`（core，本任务触及的 4 个文件） | `No issues found!` |
| `dart format`（core 与 app，本任务触及的文件） | 0 处改动 |
| `flutter analyze --no-pub`（core，全库） | 4 条，全部为既有项，见下 |
| `flutter analyze --no-pub`（app，全库） | 72 条，全部在 `companion/windows_assistant` 与生成文件，非本次改动 |

core 全库的 4 条：`lib/chat/composer_card.dart:346`、`lib/harness/harness_host.dart:6`，以及 `test/harness/home_agents_tab_live_status_test.dart` 的两个未用导入。后两个文件是别的 Pi 刚加的，不在我的提交里。

`flutter test`、`node --test`、模拟器与虚拟机都没有运行，按任务约束交给云端 CI。


## 7. 交叉检查后的两处修复（F1、F2）

`xcheck-c.md` 第 3 节列了 6 项未修。大脑接受了其中 4 项，F1 与 F2 在本轮修掉。

### 7.1 F1 占位项目没人清理

问题：`PlaceholderProjects.discardIfUnused` 没有调用方。用户在首页点过一条会话，
手机上就多一个占位项目，此后没有任何路径移除它。`xcheck-c.md` 记在
`lib/sync/placeholder_project.dart:136`。

改动：

1. 删会话时清掉它的占位项目。`SessionListView._delete` 删完会话调
   `discardSessionPlaceholders(store, meta.id)`。只处理 `deviceSessionId` 对得上、
   仍是占位、且没拉过文件的项目。拉过文件的副本是用户自己的项目，不动。
   `SessionListView` 新增可选参数 `store`，`editor_page.dart` 传 `widget.store`。
2. 启动扫一遍。`PlaceholderProjects.sweep` 遍历设备项目，问一次会话还在不在，
   不在的删目录并从项目列表移除。`main.dart` 在首帧之后、运行时装配完成时调
   `PlaceholderProjects.sweepPlaceholders`，`unawaited`，失败只记日志。
3. 会话存在性判定新增 `AgentSessionStore.exists`。文件实现先看索引，
   索引旧时再看 `.jsonl` 与遗留文件：索引丢了不能当成会话没了。

电脑上删了会话、用户重新配对换了主机 id，这两条路径都由启动扫描覆盖。

文件：

| 仓库 | 文件 |
| --- | --- |
| core | `lib/sync/placeholder_project.dart` |
| core | `lib/session/agent_session.dart` |
| core | `lib/editor/agent/session_list_view.dart` |
| core | `lib/editor/editor_page.dart` |
| core | `test/support/fake_agent.dart` |
| core | `test/sync/placeholder_project_test.dart` |
| core | `test/sync/session_placeholder_discard_test.dart`（新增） |
| core | `test/agent_session_test.dart` |
| app | `lib/main.dart` |

提交：core `1e7f68d`，app `ec78710`。

测试：`placeholder_project_test.dart` 新增 5 例（删目录并移除记录、会话还在不动、
拉过文件的不扫、普通本地项目不参与、问不出会话时留着）。
`session_placeholder_discard_test.dart` 新增 4 例（删完消失、拉过文件留着、
只动本会话、没有项目仓库时不动）。
`agent_session_test.dart` 新增 1 例（索引在、索引丢了但正文还在、完全没有）。

### 7.2 F2 大文件整份读进内存

问题：`DeviceSyncService._fetch` 用 `BytesBuilder` 收完整份文件再算哈希，
传输途中峰值等于文件大小。`xcheck-c.md` 记在 `lib/sync/device_sync.dart:253`。

选第一种做法：边写暂存文件边算哈希，保留「哈希通过才改名」。
跳过 32 MiB 以上的文件会把大项目同步静默砍掉一块，用户看到的「同步完成」
并不完整，比多占内存更糟。

改动：`_fetch` 与 `_writeVerified` 合成一个 `_writeVerified(localRoot, entry)`。

1. 打开 `.incoming/<path>.part`，每个分片同时写进文件与
   `sha256.startChunkedConversion`。内存里只有一片 `kSyncChunkBytes`。
2. 边收边比清单里的 `size`：多一个字节立刻失败，少一个字节在 `eof` 之后失败。
3. 摘要对上才改名到正式路径。对不上就删 `.part` 再抛错误，暂存区不留残片。
4. 进度与报告改用清单记录的 `entry.size`，不再用收到的字节数。

文件：

| 仓库 | 文件 |
| --- | --- |
| core | `lib/sync/device_sync.dart` |
| core | `test/sync/device_sync_test.dart` |

提交：core `606810b`。

测试：`device_sync_test.dart` 新增 3 例（检查失败后暂存区不留残片、
三块大文件逐块写入后内容与原文一致、电脑交的字节少于清单时失败且不改名）。

### 7.3 本轮静态检查

| 项 | 范围 | 结果 |
| --- | --- | --- |
| `dart format` | 改动与新增的 13 个文件 | 0 处改动 |
| `flutter analyze --no-pub` | core `lib/sync`、`lib/session`、`lib/editor`、`test/sync`、`test/support` | `No issues found!` |
| `flutter analyze --no-pub` | app `lib/main.dart` | `No issues found!` |

`flutter test` 与 `node --test` 仍然没有运行。

### 7.4 仍未修

`xcheck-c.md` 第 3 节剩下 4 项保持原样：

1. 确认框不显示移除项数量。
2. 每次同步新开一次连接。
3. 补历史靠 700 ms 静默窗口判断。
4. `detectDirty` 只比时间戳。

新增一条已知边界：`sweep` 判会话存在时用会话目录里的索引与文件。
用户清掉整个 `agent_sessions` 目录后，所有没拉过文件的占位项目会在下次启动
一起消失。这正是「会话没了就连同占位项目一起走」的本意，但会话历史也已经
不在了，所以记在这里。