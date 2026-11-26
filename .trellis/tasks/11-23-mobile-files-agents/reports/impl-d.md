# 实现报告（D 路）

任务：`11-23-device-sync`（`11-23-mobile-files-agents` 的子任务）。
分支：`mobile/pi-d`。两个仓库各一个提交，按需求号划分。

## 1. 提交一览

| 需求 | 仓库 | 提交 | 提交说明 |
| --- | --- | --- | --- |
| 11 | core | `57531fd` | `feat(harness): report the paired computer device information` |
| 11 | app | `5866f9a` | `feat(companion): report hostname, os and os version to the phone` |
| 7 | core | `ce56d1a` | `feat(sync): pull device git projects after a size prompt` |
| 7 | app | `3d28ffe` | `feat(companion): answer git metadata for a project directory` |
| 8 | core | `c22a8d7` | `feat(sync): copy a paired computer project file by file` |
| 8 | app | `8977b12` | `feat(companion): serve a project manifest and file chunks` |
| 12 | core | `b1b6172` | `feat(sync): keep a placeholder project and a session stream cache` |

每个需求在 app 与 core 各产生一个提交，因为两个工作树是两个独立仓库。
需求 12 没有 app 侧改动。

## 2. 需求 7：Git 项目走 qfli_git 拉取

### 2.1 改动

电脑端回答 `project_git_info`，给出远程地址、分支、HEAD、是否有未提交改动，以及 `.git` 目录的字节数。
读取全程不启动 git 进程，只读 `.git/config`、`.git/HEAD` 与 HEAD 指向的引用文件。
手机端按四步判断。仓库不可读则退回文件同步。没有 `origin` 也退回文件同步。`.git` 超过 200 MB 且用户未确认则返回需要确认。其余情况走克隆或抓取。

`.git` 大小用新增的 `gitBytes` 字段承载，只作量级参考，不等于网络传输量。
阈值写在 `kGitConfirmBytes`（core）与 `GIT_CONFIRM_BYTES`（app）两处，值都是 200 MB。

### 2.2 文件

app：
- `companion/remote_agent/src/agent/git-info.ts`（新增，`parseOriginUrl`、`parseHead`、`detectDirty`、`directoryBytes`、`readGitInfo`）
- `companion/remote_agent/src/shared/protocol.ts`（新增 `project_git_info` 请求与应答、`GIT_CONFIRM_BYTES`、`project_git` 能力位、`lanUrls`）
- `companion/remote_agent/src/agent/core.ts`（分发 `project_git_info`，能力位追加 `project_git`）
- `companion/remote_agent/test/git-info.test.ts`（新增 17 个用例）

core：
- `lib/remote_control/models/protocol.dart`（`GitProjectInfo`、`lanUrls` 只保留 `wss://`）
- `lib/remote_control/state/remote_controller.dart`（`projectGitInfo`）
- `lib/sync/sync_limits.dart`（新增，两个阈值常量）
- `lib/sync/device_file_port.dart`（新增，端口接口）
- `lib/sync/remote_device_file_port.dart`（新增，真实实现）
- `lib/sync/device_git_pull.dart`（新增，`DeviceGitPull`、`GitPullOutcome`、`GitPullReport`）
- `test/sync/device_git_pull_test.dart`（新增 12 个用例）
- `test/remote_agent_capabilities_test.dart`（新增 8 个用例，含局域网地址门禁）

### 2.3 按裁决 R7、R8 的处理

传输只走中继。内置中继要求 `agentId` 与 `secret`，但使用的是明文 `ws://`，达不到「加密强度不低于中继」的门槛，所以 v1 不开局域网直连。
`lanUrls` 保留在协议里，由能力位 `lan_tls` 控制：没有该能力位，或者地址不是 `wss://`，手机一律当空列表。
本任务没有新增任何监听端口。

克隆只做完整克隆。`qfli_git` 的 `qg_clone` 与 `qg_fetch` 没有深度参数，`QfliGit.clone` 与 `fetch` 也没有，`lib/` 与 `native/` 里搜 `depth`、`shallow` 均为零命中。浅克隆记为 `qfli_git` 的后续需求，本任务不碰该仓库。

### 2.4 静态检查

- `npm run check`（`tsc --noEmit`）：无错误。
- `dart format` 上述文件：0 处改动。
- `flutter analyze --no-pub` 上述文件：`No issues found!`

### 2.5 还需要真机

- 真机克隆一个私有仓库（走令牌）与一个公开仓库，确认 `qfli_git` 在 Android 与 iOS 上都能落地。
- 真机看 200 MB 提示的文案与观感，确认用户能理解「这是 `.git` 占用，不是下载量」。
- 真机看 `detectDirty` 在大型仓库上的表现。当前用索引文件与 HEAD 的时间戳比较，只能识别「索引比 HEAD 新」，不能识别文件删除。

## 3. 需求 8：非 Git 项目按需同步

### 3.1 改动

电脑端按忽略表遍历项目根目录，为每个文件算 sha256，返回清单。清单超过 20000 条时置 `truncated` 并停止遍历。
手机端先取清单，与本地副本比对，得到下载组与删除组，再逐个文件分块读取，每块最多 512 KiB。
每个文件先写暂存目录，检查哈希通过后原子改名到正式路径。删除放在所有写入之后。
忽略表是数据，两端各一份，版本号写进清单。版本不一致时拒绝同步，避免把缺项当成删除。

### 3.2 文件

app：
- `companion/remote_agent/src/agent/fs-sync.ts`（新增，`FS_CHUNK_BYTES`、`FS_MANIFEST_MAX_ENTRIES`、`FS_IGNORE_VERSION`、`FS_IGNORE_DIRS`、`FS_IGNORE_SUFFIXES`、`safeRelativePath`、`resolveInside`、`buildManifest`、`readChunk`）
- `companion/remote_agent/src/shared/protocol.ts`（新增 `fs_manifest`、`fs_read` 请求与 `fs_manifest`、`fs_chunk` 应答、`FsEntry`）
- `companion/remote_agent/src/agent/core.ts`（分发 `fs_manifest` 与 `fs_read`，能力位追加 `fs_sync`）
- `companion/remote_agent/test/fs-sync.test.ts`（新增 30 个用例）

core：
- `lib/remote_control/models/protocol.dart`（`FsEntry`、`FsManifest`、`FsChunk`）
- `lib/remote_control/state/remote_controller.dart`（`projectFsManifest`、`projectFsRead`）
- `lib/sync/device_file_port.dart`（追加 `manifest`、`read`）
- `lib/sync/remote_device_file_port.dart`（追加两个方法）
- `lib/sync/sync_ignore.dart`（新增，忽略表与路径检查）
- `lib/sync/sync_cache.dart`（新增，索引、预算、最近最少使用淘汰）
- `lib/sync/device_sync.dart`（新增，`DeviceSyncService`、`SyncPlan`、`SyncReport`、`SyncProgress`）
- `lib/sync/device_sync_dialog.dart`（新增，确认框、进度框、结果框）
- `lib/editor/ai_panel.dart`（新增「从电脑同步」入口，仅在产品开启且宿主传入动作时显示）
- `lib/services/studio_profile.dart`（新增 `deviceSyncEnabled`，默认关闭）
- `test/sync/device_sync_test.dart`（新增 14 个用例）
- `test/sync/device_sync_dialog_test.dart`（新增 4 个用例）

### 3.3 安全与失败处理

电脑端拒绝绝对路径、`..`、反斜杠、冒号与控制字符，并用 `realpath` 复核落点在根目录内。所以项目里的符号链接指不到项目外。
手机端用同一套规则再检查一次才落盘。清单里出现不安全路径就整次失败。
任何一步失败都保留旧文件与旧清单。已经改名的文件是完整的新版本，下次同步按新清单收敛。

### 3.4 忽略表（版本 1）

| 类别 | 条目 |
| --- | --- |
| 依赖 | `node_modules`、`.venv`、`Pods`、`.gradle` |
| 构建 | `build`、`dist`、`out`、`target`、`.dart_tool`、`DerivedData`、`.next` |
| 缓存 | `__pycache__`、`.cache`、`*.pyc` |
| 日志 | `logs`、`*.log` |
| 会话记录 | `agent_sessions`、`transcripts` |
| 版本库 | `.git` |

会话记录按目录名匹配，不用 `*.jsonl` 全项目匹配。

### 3.5 静态检查

- `npm run check`：无错误。
- `dart format` 上述文件：0 处改动。
- `flutter analyze --no-pub` 上述文件：`No issues found!`

### 3.6 还需要真机

- 真机跑一次十万级文件的目录，看清单耗时与内存，确认 20000 条上限合适。
- 真机在同步中途断网，确认已写入的文件完整、旧文件仍在，下一次同步能收敛。
- 真机看 512 KiB 分块在中继下的吞吐，按实测结果调整块大小。
- 真机看进度框在慢网络下的刷新频率。

## 4. 需求 11：电脑上报设备名与系统

### 4.1 改动

电脑端 `info` 应答新增 `hostName`、`os`、`osVersion`。`os` 只发 `windows`、`macos`、`linux`、`other` 四个短名，不发 `win32`、`darwin` 这类运行时值。
手机端 `AgentInfo` 解析这三个字段。`RemoteHarnessHost` 把它们翻译成共用契约里的 `HarnessDeviceInfo`。设备名取 `hostName`，缺失时退回 `host`。系统名取 `os`，`other` 或缺失时退回 `platform`。版本原样使用，不猜。

### 4.2 文件

app：
- `companion/remote_agent/src/agent/device-info.ts`（新增，`mapPlatform`、`formatOsVersion`、`macOSName`、`readLinuxPrettyName`、`collectDeviceInfo`）
- `companion/remote_agent/src/shared/protocol.ts`（`info` 追加三个可选字段）
- `companion/remote_agent/src/agent/core.ts`（填充三个字段）
- `companion/remote_agent/test/device-info.test.ts`（新增 11 个用例）

core：
- `lib/remote_control/models/protocol.dart`（`AgentInfo` 追加三个字段）
- `lib/harness/remote/remote_ports.dart`（新增可选接口 `RemoteDevicePort` 与适配器实现）
- `lib/harness/remote/remote_harness_host.dart`（实现 `HarnessDeviceHost`）
- `test/harness_remote_device_test.dart`（新增 11 个用例）

### 4.3 与 Pi-C 的字段约定

字段名 `hostName`、`os`、`osVersion` 与 `HarnessDeviceInfo` 的 `hostName`、`os`、`osVersion` 一一对应，转换只做加法，不改名。
`RemoteDevicePort` 做成可选接口，没有设备信息的端口不必实现，既有测试替身无需改动。

### 4.4 静态检查

- `npm run check`：无错误。
- `dart format` 上述文件：0 处改动。
- `flutter analyze --no-pub` 上述文件：`No issues found!`

### 4.5 还需要真机

- 真机在 Windows 11、macOS 15、Ubuntu 24.04 上各配一次，确认设备名与版本串符合预期。
- Linux 上确认 `/etc/os-release` 读不到时退回内核版本串。
- 旧版电脑端（不发这三个字段）连新版手机，确认详情页显示为未知而不是空串。

## 5. 需求 12：占位项目与会话流缓存

### 5.1 改动

会话在电脑上、手机本地没有项目时，为它建一个占位项目，落在应用数据目录的 `projects/deviceSessions/<hostKey>/<sessionId>/`。里面有 `.qfli/project.json` 与会话流目录。
会话流按行写 `stream.jsonl`，双重上限：2 MiB 或 400 行，超了先丢最旧的。
项目文件只在用户确认后才下载，下载到 `projects/deviceProjects/<hostKey>/<projectId>/files`。
没有拉过文件的占位项目随会话一起删除。拉过文件的保留，当作普通项目。

`Project` 新增五个字段 `deviceHostId`、`deviceSessionId`、`deviceRoot`、`placeholder`、`filesPulled`，全部有默认值，旧记录能照常读出。

### 5.2 文件

core：
- `lib/services/app_paths.dart`（新增 `appDataSubdirectory`、`deviceProjectsRoot`、`deviceSessionsRoot`）
- `lib/models/project.dart`（追加块：五个字段与 `isDevice`）
- `lib/store/project_store.dart`（追加块：`deviceProjectFor`、`registerDeviceProject`、`discardDevicePlaceholder`）
- `lib/sync/placeholder_project.dart`（新增，`PlaceholderProjects`、`hostKey`、`ensure`、`filesRoot`、`pullFiles`、`discardIfUnused`）
- `lib/sync/remote_session_cache.dart`（新增，`RemoteSessionCache`）
- `lib/harness/remote/remote_terminal.dart`（转录流写入缓存）
- `lib/harness/remote/remote_session.dart`（会话句柄把缓存交给转录流）
- `lib/harness/remote/remote_harness_host.dart`（按会话建缓存，`cacheTranscripts` 开关默认开启）
- `test/sync/placeholder_project_test.dart`（新增 8 个用例）
- `test/sync/remote_session_cache_test.dart`（新增 10 个用例）

### 5.3 按裁决 R10 的处理

`lib/models/project.dart` 与 `lib/store/project_store.dart` 与 B 路共用，改法一律是追加：
原有字段顺序、原有方法体、原有格式都不动，只在其后追加独立的一节，并用注释标明是追加块。
`toJson` 只在末尾追加键，未设置时不写出，避免旧版本读到陌生键。

### 5.4 静态检查

- `dart format` 上述文件：0 处改动。
- `flutter analyze --no-pub` 上述文件：`No issues found!`

### 5.5 还需要真机

- 真机确认占位项目目录在 iOS 文档目录、Android 应用数据目录下都可写。
- 真机断线重连，确认会话流缓存能补回可读的历史。
- 真机确认占位项目的删除不影响用户自己的项目目录。
- 真机确认 2 MiB 上限在长会话下不拖慢界面。

## 6. 静态检查汇总

| 项 | 结果 |
| --- | --- |
| `npm run check`（app，`companion/remote_agent`） | 无错误 |
| `dart format`（core，本任务触及的文件） | 0 处改动 |
| `flutter analyze --no-pub`（core，本任务触及的文件） | `No issues found!` |
| `flutter analyze --no-pub`（core，全库） | 2 条 info，均为既有问题，见 §8 |

`flutter test`、`node --test`、模拟器与虚拟机都没有运行，按任务约束交给云端 CI。

## 7. 决策与假设

1. 传输只走中继，不开局域网直连（裁决 R7）。理由是内置中继虽鉴权但明文，加密门槛不达标，宁可慢也不降级。
2. 完整克隆，浅克隆记为 `qfli_git` 的后续需求（裁决 R8）。`qfli_git` 现有接口没有深度参数，本任务不改该仓库。
3. `.git` 大小只作量级参考，提示文案要写清这一点，避免用户以为下载量正好等于该数值。
4. `project_git_info` 与 `fs_manifest`、`fs_read` 的路径统一用 `checkPath` 收进允许的根目录，再用 `realpath` 复核。`fs_read` 的根取「包含该路径的允许根」，以便相对路径计算一致。
5. `DeviceGitPull` 用显式入参（远端根、本地根）而不是 `Project`，因为需求 12 的字段在需求 7 之后落地。`PlaceholderProjects.pullFiles` 做这层衔接。
6. 同步入口放在 `ai_panel.dart`，由 `StudioProfile.deviceSyncEnabled` 与宿主传入的动作双重控制。面板本身不持有 `RemoteController`，谁持有配对连接谁传动作，避免出现点了没反应的按钮。
7. 忽略表两端各存一份，版本号进清单。不同步版本时拒绝同步，防止缺项当成删除。
8. 会话流缓存的键取 `hostKey` 与 `sessionId` 清洗后的片段，非字母数字字符一律替换成下划线，避免路径穿越。
9. `RemoteSessionCache` 的写失败不抛出，只是少一份历史。会话本身仍可用。

## 8. 残留风险

1. 全库 `flutter analyze --no-pub` 仍有 2 条 info，都在本任务范围之外：
   `lib/chat/composer_card.dart:346` 的 `curly_braces_in_flow_control_structures`，以及 `lib/harness/harness_host.dart:6` 的 `unnecessary_import`（Pi-C 合并进来的契约文件，本任务只读）。两条都与本任务改动无关，提交前后一致。
2. `detectDirty` 只看索引与 HEAD 的时间戳，识别不出「文件已删除但未暂存」这类改动。提示语只能说「可能有未提交改动」，不能断言干净。
3. `directoryBytes` 对超大 `.git` 目录要遍历全部文件，冷启动时可能耗时数秒。已放在请求内部，界面需要自己加等待提示。
4. `buildManifest` 对每个文件算 sha256，十万级文件的项目第一次同步会明显耗时。上限 20000 条能挡住最坏情况，但没有做增量哈希缓存。
5. 会话流缓存按行数或字节数丢最旧的，可能把一条尚未结束的流式消息截断在半句。恢复后表现为历史里少一条。
6. `PlaceholderProjects.ensure` 的项目 id 由 `hostKey` 与 `sessionId` 拼成。同一会话在重装后仍是同一 id，但换了电脑侧会话 id 就会当成新项目。
7. 端到端没有在真机上跑过。中继连接、局域网能力位、克隆、分块传输、索引淘汰、会话流补写都只有单元测试覆盖。

## 9. 过程记录

一次 `dart format` 误用了目录通配，短暂改写了 60 个本任务范围之外的文件。发现后立即用反向补丁逐个还原。还原前后 `git diff --numstat` 均为纯新增。本任务的 7 个提交只包含上面列出的文件。工作树当前干净。
