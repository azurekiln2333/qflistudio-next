# 电脑改动回到手机：技术设计

父任务：`11-23-mobile-files-agents`。
需求见同目录 `prd.md`。
裁定见 `../11-23-mobile-files-agents/reports/plan-review.md`。
本文已按 R4、R7、R8、R9、R10、R11 改写。

## 1. 边界

### 1.1 本任务负责

1. 电脑侧的新增请求与上报字段。
2. 手机侧的同步客户端与缓存。
3. 占位项目与会话流缓存。
4. git 项目的按 origin 拉取。
5. `RemoteHarnessHost` 实现 `HarnessDeviceHost`。

### 1.2 本任务不负责

1. `D:/MyNewProjects/qfli_git` 的任何改动。
2. `lib/harness/harness_host.dart` 的类型定义。
3. `HarnessDeviceInfo` 与 `HarnessDeviceHost` 的声明。
4. 首页 Agents 标签的列表与详情界面。
5. 中继服务端仓库。

`harness_host.dart` 由 Pi-C 拥有。
本任务只实现它，不修改它。

## 2. 哪段代码跑在哪台机器

### 2.1 结论

电脑侧代码就在本仓库的 `companion/remote_agent`。
它是 TypeScript 的 Node agent。
它同时内置局域网中继。

手机侧代码在共享内核 `lib/remote_control`。
它与 agent 共用同一套中继协议。

链路如下：

```text
windows_assistant ──本机回环──▶ remote_agent ──wss──▶ 中继 ◀──wss── 手机
```

### 2.2 排除的两个候选

`azurekiln-qfli-terminal` 是执行器与沙箱镜像仓库。
它没有 `server/src/agent`，与本需求无关。

`cloudterminal` 是拆分前的原仓库。
它的 `server/src/agent` 已迁到 `companion/remote_agent`。
本任务只改迁移后的副本。

## 3. 通道选择与降级

### 3.1 第一版的通道

第一版只走中继。
理由见 3.3 节的认证与加密要求。

局域网直连的代码保留在开关后面。
开关默认关闭。

### 3.2 中继的无状态约束

中继不存文件，也不存清单。
文件字节只在 `msg` 帧里穿过。

中继单帧上限 4 MiB。
分块大小定为 512 KiB。
留足 Base64 膨胀与信封开销的余量。

### 3.3 局域网直连的条件（R7）

直连必须同时满足三条。

1. 沿用配对凭据，不新开未认证的监听端口。
2. 加密强度不低于中继路径。
3. 电脑端内置中继已经能提供该强度的连接。

现状检查结果：

1. 内置中继的认证与公网中继同源。
   它检查 `agentId` 与 `secret`，认证这一条满足。
2. 内置中继默认监听明文 `ws://`。
   公网中继通常是 `wss://`。
   加密这一条不满足。

结论：第一版只走中继。
直连要等内置中继支持 TLS 与证书固定。
证书固定在配对时完成，不在运行时信任任意证书。

### 3.4 后续开启直连的形状

电脑在 `info` 里上报 `lanUrls`。
只在能提供 TLS 时上报，并同时上报能力位 `lan_tls`。

手机只接受带 `lan_tls` 的 `lanUrls`。
没有能力位就忽略该字段。
探测上限 1500 ms，失败即切回中继。
同一会话内不反复重试直连。

## 4. 协议契约：TypeScript 侧

改动仓库：`qflistudio`。
改动目录：`companion/remote_agent`。

### 4.1 文件与清单类型

写入 `src/shared/protocol.ts`：

```ts
export const FS_CHUNK_BYTES = 512 * 1024;
export const FS_MANIFEST_MAX_ENTRIES = 20000;
export const FS_IGNORE_VERSION = 1;
export const GIT_CONFIRM_BYTES = 200 * 1024 * 1024;

export type FsEntryKind = 'file' | 'dir';

export type FsEntry = {
  path: string;   // posix 相对路径，'/' 分隔，无前导斜杠
  kind: FsEntryKind;
  size: number;   // 目录为 0
  hash: string;   // 文件字节的 sha256 小写十六进制，目录为 ''
};

export type FsManifest = {
  root: string;
  ignoreVersion: number;
  entries: FsEntry[];
  truncated: boolean;
};
```

### 4.2 新增请求

追加到 `ClientRequest` 联合类型：

```ts
| { type: 'fs_manifest'; path: string }
| { type: 'fs_read'; path: string; offset: number; length?: number }
| { type: 'project_git_info'; path: string }
```

### 4.3 新增应答

追加到 `AgentMessage` 联合类型：

```ts
| { kind: 'fs_manifest'; id?: string; root: string;
    ignoreVersion: number; entries: FsEntry[]; truncated: boolean }
| { kind: 'fs_chunk'; id?: string; path: string;
    offset: number; base64: string; eof: boolean }
| { kind: 'project_git_info'; id?: string; root: string;
    supported: boolean; gitBytes?: number; remote?: string;
    branch?: string; head?: string; dirty?: boolean }
```

`gitBytes` 是电脑上该仓库 `.git` 目录的字节数。
手机用它判断克隆前是否需要确认（R8）。

### 4.4 设备信息字段

`kind: 'info'` 增加三个可选字段：

```ts
hostName?: string;   // 显示用设备名，默认 os.hostname()
os?: string;         // 'windows' | 'macos' | 'linux' | 'other'
osVersion?: string;  // 人类可读版本，例如 'Windows 11 23H2 (22631)'
```

原有 `host` 与 `platform` 不动。
旧手机读到新字段会忽略它们。

### 4.5 能力位

`info.capabilities` 追加三个字符串：

```text
fs_sync     电脑支持清单与分块读取
project_git 电脑能上报 git 远端信息与 .git 大小
lan_tls     电脑内置中继能提供加密直连
```

手机按能力位显示入口与选择通道。
没有能力位就不显示，也不选该通道。

### 4.6 局域网地址

`info` 另加一个可选字段，只在 `lan_tls` 存在时填充：

```ts
lanUrls?: string[];  // 形如 wss://192.168.1.20:8787/ws
```

第一版电脑不填该字段。
手机读到空值就只走中继。

## 5. Dart 镜像契约

改动仓库：`qfli_studio_core`。
改动文件：`lib/remote_control/models/protocol.dart`。

`protocol.dart` 的解析本就宽松。
未知字段忽略，未知事件类型落到 `UnknownEvent`。
因此新增字段不会打断旧测试。

新增三个不可变类：

```dart
class FsEntry {
  const FsEntry({
    required this.path,
    required this.kind,
    required this.size,
    required this.hash,
  });
  final String path;
  final String kind; // 'file' | 'dir'
  final int size;
  final String hash;
}

class FsManifest {
  const FsManifest({
    required this.root,
    required this.ignoreVersion,
    required this.entries,
    required this.truncated,
  });
  final String root;
  final int ignoreVersion;
  final List<FsEntry> entries;
  final bool truncated;
}

class GitProjectInfo {
  const GitProjectInfo({
    required this.root,
    required this.supported,
    this.gitBytes,
    this.remote,
    this.branch,
    this.head,
    this.dirty,
  });
  final String root;
  final bool supported;
  final int? gitBytes;
  final String? remote;
  final String? branch;
  final String? head;
  final bool? dirty;
}
```

`AgentInfo` 增加四个可空字段：

```dart
final String? hostName;
final String? os;
final String? osVersion;
final List<String>? lanUrls;
```

`AgentInfo.fromJson` 用 `json['os'] is String ? ... : null` 取值。
缺字段时对应值为 `null`。

## 6. 手机侧新增模块

新增目录：`qfli_studio_core/lib/sync`。

### 6.1 端口接口

```dart
abstract interface class DeviceFilePort {
  Future<FsManifest> manifest(String root);
  Future<List<int>> read(String path, {required int offset, int? length});
  Future<GitProjectInfo> gitInfo(String root);
}
```

端口按 `NativeGitApi` 的做法做成接口。
云端测试注入假实现，不碰真实 socket。

### 6.2 同步服务

```dart
class DeviceSyncService {
  DeviceSyncService({
    required DeviceFilePort port,
    required SyncCache cache,
    required ProjectStore store,
  });

  Future<SyncPlan> plan(Project project);
  Future<SyncReport> apply(
    SyncPlan plan, {
    void Function(SyncProgress progress)? onProgress,
  });
}

class SyncPlan {
  final Project project;
  final List<FsEntry> downloads; // 新增或内容变化
  final List<String> deletes;    // 本地有、清单没有
  final int bytes;
  final String manifestRoot;
}

class SyncReport {
  final int writtenFiles;
  final int deletedEntries;
  final int bytes;
  final bool completed;
  final String? error;
}
```

### 6.3 缓存索引

```dart
class SyncCache {
  SyncCache({required String indexFile, int budgetBytes = 512 * 1024 * 1024});

  Future<void> load();
  Future<int> usedBytes();
  Future<void> touch(String key);
  Future<List<String>> evictCandidates({required int needBytes});
  Future<void> evict(String key);
}
```

索引文件放应用数据目录。
键是 `hostId/projectKey`。
记录大小与最近使用时间。

### 6.4 git 拉取

```dart
class DeviceGitPull {
  DeviceGitPull({
    required DeviceFilePort port,
    GitCloneService? clone,
    int confirmBytes = 200 * 1024 * 1024,
  });

  Future<GitPullResult> pull(
    Project project, {
    Future<bool> Function(int gitBytes)? confirmLargeClone,
  });
}

enum GitPullOutcome { cloned, pulled, needsConfirm, fallbackToFiles, blocked }
```

判断顺序：

1. 向电脑取 `project_git_info`。
2. 电脑报告 `supported == false`，退回文件同步。
3. 远端为空，退回文件同步。
4. `gitBytes` 超过阈值且没有确认，返回 `needsConfirm`。
5. 其余情况走 `qfli_git` 克隆或抓取。

## 7. 数据流：非 git 项目同步

1. 用户点「同步」。
2. 手机经中继发 `fs_manifest`。
3. 电脑扫描根目录并按忽略表裁剪。
4. 电脑对每个文件算 sha256。
5. 电脑回 `fs_manifest`。
6. 手机与本地清单比对，得到下载组与删除组。
7. 手机逐个文件发 `fs_read`。
8. 电脑回 `fs_chunk`，每次最多 512 KiB。
9. 手机写暂存目录。
10. 每个文件写完就检查哈希。
11. 检查通过后原子改名到正式路径。
12. 全部文件就位后执行删除。
13. 手机写新清单。
14. 手机更新缓存索引。

### 7.1 失败处理

任何一步失败都保留旧清单与旧文件。
已原子改名的文件是完整的新版本。
未执行的删除保持原样。

代价是一次失败可能留下混合状态。
下一次同步会按新清单把它收敛。
这比整目录重建省一半磁盘峰值。

### 7.2 路径检查

电脑侧只接受根目录下的路径。
拒绝绝对路径、`..`、反斜杠、冒号、控制字符。
拒绝符号链接，也拒绝链接父目录。

手机侧同样检查后才落盘。
规则复用 `CloudCachePaths.relative` 的口径。

## 8. 数据流：git 项目拉取

1. 用户点「同步」。
2. 手机取 `project_git_info`。
3. 得到远端、分支、HEAD、是否有未提交改动、`.git` 字节数。
4. 字节数超过 200 MB 时先请用户确认（R8）。
5. 用户取消就停，不产生任何写入。
6. 本地没有仓库，就克隆到项目目录。
7. 本地已有仓库，就抓取并快进。
8. 有本地改动时先提示，不强行覆盖。

### 8.1 大小阈值的口径

阈值取 200 MB，写在常量 `GIT_CONFIRM_BYTES`。
`gitBytes` 是电脑上 `.git` 目录的实际占用。
它不等于网络传输量，只作量级参考。

提示文案要写清这一点。
不要让用户以为下载量正好是该数值。

### 8.2 qfli_git 现状

```c
int qg_clone(const char *url, const char *path, const char *username,
             const char *token, const int32_t *cancel_flag,
             qg_repo **out, qg_error *err);
int qg_fetch(qg_repo *repo, const char *remote, const char *username,
             const char *token, const int32_t *cancel_flag,
             qg_error *err);
```

两个函数都没有深度参数。
`qg_clone` 内部用 `GIT_CLONE_OPTIONS_INIT`。
`qg_fetch` 内部用 `GIT_FETCH_OPTIONS_INIT`。
两者都没有写入 `depth`。

本任务只用完整克隆。
浅克隆记为 `qfli_git` 的后续需求。
本任务不改该仓库。

建议的后续接口形状如下，归 `qfli_git` 负责人：

```c
/* depth 为 0 表示完整克隆 / 保持现有深度 */
int qg_clone(..., int depth, qg_repo **out, qg_error *err);
int qg_fetch(..., int depth, qg_error *err);
```

## 9. 忽略表

忽略表是数据，不是散落的字符串。
两端各有一份同版本号的表。
版本号写进清单，用来判断两端是否对齐。

版本 1 的默认条目：

| 类别 | 条目 |
| --- | --- |
| 依赖 | `node_modules/`、`.venv/`、`Pods/`、`.gradle/` |
| 构建 | `build/`、`dist/`、`out/`、`target/`、`.dart_tool/`、`DerivedData/`、`.next/` |
| 缓存 | `__pycache__/`、`.cache/`、`*.pyc` |
| 日志 | `*.log`、`logs/` |
| 会话记录 | `agent_sessions/`、`transcripts/` |
| 版本库 | `.git/` |

会话记录只在两个目录下生效。
`*.jsonl` 不再全项目匹配。
这一条写成目录白名单更稳。

## 10. 缓存与淘汰

副本根目录：

```text
<storage>/projects/deviceProjects/<sha256(hostId)[0:16]>/<projectKey>/
  manifest.json      上次同步的清单
  sync.json          时间戳与字节数
  files/             项目文件
```

`<storage>` 由 `AppPaths.storageDirectory()` 给出。
iOS 上改用文档目录，与 `projectsRoot` 一致。

淘汰规则：

1. 先算超出量。
2. 按最近使用时间升序取候选。
3. 跳过当前打开的项目。
4. 单个目录整体删除。
5. 删完重写索引。

缓存缺失不算错误。
下次同步按全量处理。

## 11. 占位项目与会话流

### 11.1 落点

```text
<storage>/projects/deviceSessions/<sha256(hostId)[0:16]>/<sessionId>/
  .qfli/project.json
  .session/stream.jsonl
  .session/state.json
```

`project.json` 复用现有 `ProjectConfig.write`。
额外写一个 `remote` 段：

```json
{
  "name": "会话标题",
  "language": "",
  "type": "",
  "remote": {
    "hostId": "…",
    "sessionId": "…",
    "root": "/home/me/work/demo",
    "placeholder": true,
    "filesPulled": false
  }
}
```

落点在应用数据目录。
不往用户的任何文件夹写元数据（与 R5 同口径）。

### 11.2 Project 新增字段

`lib/models/project.dart` 增加五个可空字段：

```dart
final String? deviceHostId;
final String? deviceSessionId;
final String? deviceRoot;
final bool placeholder;
final bool filesPulled;
```

`toJson` 用 `if (x != null)` 写法。
`fromJson` 缺字段时取 `null` 或 `false`。
旧项目文件照原样读入。

这五个字段作为独立块追加（R10）。
不重排已有字段，也不重新格式化已有代码。

### 11.3 会话流缓存

新增 `RemoteSessionStreamCache`：

```dart
class RemoteSessionStreamCache {
  RemoteSessionStreamCache({
    required Directory root,
    int maxBytes = 2 * 1024 * 1024,
    int maxEvents = 400,
  });

  Future<void> append(String sessionId, TranscriptEvent event);
  Future<List<TranscriptEvent>> read(String sessionId);
  Future<void> clear(String sessionId);
}
```

上限取 2 MiB 或 400 条（R9 采纳 Q3）。
写入走追加一行。
超过任一条上限就从头丢。
裁剪在追加的同一个调用内完成。

`remote_session.dart` 在把事件推给界面时顺带写缓存。
界面读缓存只在会话流尚未到达时兜底。

### 11.4 占位项目的生命周期

1. 编辑器带 `initialHarnessSession` 打开时查项目（R1）。
2. 没有对应项目就建占位项目。
3. 占位项目登记进 `ProjectStore`。
4. 用户点「下载项目文件」后写 `filesPulled = true`。
5. 会话结束时判断 `filesPulled`。
6. 为假就删除目录并从 `ProjectStore` 删除登记。
7. 为真就清掉 `placeholder` 标记，保留目录。

删除目录只删 `deviceSessions` 下的那一层。
不递归到 `projects` 根。

## 12. 设备信息与主机能力（R4）

### 12.1 线上字段

| 字段 | 类型 | 含义 |
| --- | --- | --- |
| `host` | string | 旧字段，设备名，保留 |
| `platform` | string | 旧字段，`process.platform`，保留 |
| `hostName` | string? | 新增，显示用设备名 |
| `os` | string? | 新增，`windows` / `macos` / `linux` / `other` |
| `osVersion` | string? | 新增，人类可读版本 |
| `capabilities` | string[] | 追加 `fs_sync`、`project_git`、`lan_tls` |
| `lanUrls` | string[]? | 新增，仅在 `lan_tls` 时填充 |

本表是线上的唯一来源。
Pi-C 的 `design.md` 引用本表，不另立字段名。

### 12.2 类型归属

`HarnessDeviceInfo` 与 `HarnessDeviceHost` 由 Pi-C 声明。
声明落在 `lib/harness/harness_host.dart`。
Pi-C 同时给出手机本机的主机实现。

本任务只实现远端那一侧：

```text
RemoteHarnessHost implements HarnessDeviceHost
```

实现落在 `lib/harness/remote/remote_harness_host.dart`。
具体成员以 Pi-C 合入的接口为准。
本文只定映射规则。

### 12.3 映射规则

| 目标成员 | 取值 | 缺失或取不到时的兜底 |
| --- | --- | --- |
| `name` | `hostName` | 取 `host` |
| `os` | `os` 映射到枚举 | 用 `platform` 映射，见 12.4 |
| `osVersion` | `osVersion` | 传 `null`，不编造 |

### 12.4 系统名映射

先看 `os`。

| 上报值 | 枚举 |
| --- | --- |
| `windows` | windows |
| `macos` | macos |
| `linux` | linux |
| `other` 或缺失 | 走下面的兜底 |

兜底看 `platform`。

| 上报值 | 枚举 |
| --- | --- |
| `win32` | windows |
| `darwin` | macos |
| `linux` | linux |
| 其他 | unknown |

`osVersion` 原样传递。
取不到就传 `null`，不填占位文字。

### 12.5 电脑侧取值方式

Windows 取 `os.release()` 与 `os.version()`。
macOS 取 `os.release()`，映射到产品名。
Linux 取 `/etc/os-release` 的 `PRETTY_NAME`。
取不到就退回 `os.release()`。

`os` 一定是小写短名。
不用 `win32` 或 `darwin` 这类运行时值。

### 12.6 合并前提（R1、R11）

Pi-C 先单独提交接口。
提交内容含 `HarnessSessionTarget`、编辑器两个参数、`HarnessDeviceInfo`、`HarnessDeviceHost`。
该提交里不放界面。

大脑把它合进 `mobile/pi-d` 之后，本任务才动 `remote_harness_host.dart`。
接口未合入前，本任务只改文档。

## 13. 改动落点

| 仓库 | 文件 | 改动 |
| --- | --- | --- |
| `qflistudio` | `companion/remote_agent/src/shared/protocol.ts` | 新增类型、请求、应答、能力位、设备字段 |
| `qflistudio` | `companion/remote_agent/src/agent/fs-sync.ts` | 新增，清单扫描、分块读取、忽略表、路径检查 |
| `qflistudio` | `companion/remote_agent/src/agent/git-info.ts` | 新增，读 `.git` 取远端、HEAD 与目录大小 |
| `qflistudio` | `companion/remote_agent/src/agent/device-info.ts` | 新增，系统与版本 |
| `qflistudio` | `companion/remote_agent/src/agent/core.ts` | 分派三条新请求，`info` 带上新字段 |
| `qflistudio` | `companion/remote_agent/test/fs-sync.test.ts` | 新增 |
| `qflistudio` | `companion/remote_agent/test/git-info.test.ts` | 新增 |
| `qfli_studio_core` | `lib/remote_control/models/protocol.dart` | 镜像类型与字段 |
| `qfli_studio_core` | `lib/harness/remote/remote_harness_host.dart` | 实现 `HarnessDeviceHost` |
| `qfli_studio_core` | `lib/sync/device_sync.dart` | 新增，计划与应用 |
| `qfli_studio_core` | `lib/sync/device_file_port.dart` | 新增，端口接口与适配器 |
| `qfli_studio_core` | `lib/sync/sync_cache.dart` | 新增，索引与淘汰 |
| `qfli_studio_core` | `lib/sync/sync_ignore.dart` | 新增，忽略表 |
| `qfli_studio_core` | `lib/sync/device_git_pull.dart` | 新增，git 拉取与大小确认 |
| `qfli_studio_core` | `lib/sync/remote_session_cache.dart` | 新增，会话流缓存 |
| `qfli_studio_core` | `lib/sync/placeholder_project.dart` | 新增，建与删 |
| `qfli_studio_core` | `lib/models/project.dart` | 追加五个可空字段（独立块） |
| `qfli_studio_core` | `lib/store/project_store.dart` | 追加登记与清理方法（独立块） |
| `qfli_studio_core` | `lib/services/app_paths.dart` | 新增两个根路径 |
| `qfli_studio_core` | `lib/harness/remote/remote_session.dart` | 顺带写会话流缓存 |
| `qfli_studio_core` | `lib/editor/ai_panel.dart` | 远端会话加「同步」「下载项目文件」入口 |
| `qfli_studio_core` | `test/sync/*.dart` | 新增四组测试 |

不在表内的文件：

1. `lib/harness/harness_host.dart`，归 Pi-C。
2. `lib/harness/ui/hub_*.dart`，归 Pi-C。
3. `lib/editor/editor_page.dart` 与 `retained_editor_host.dart`，按 R1 归 Pi-C。
4. `D:/MyNewProjects/qfli_git` 下的任何文件。

## 14. 取舍

### 14.1 清单先行，还是边扫边传

选清单先行。
理由是要先算删除组。
代价是多一次往返。

### 14.2 整目录重建，还是逐文件原子

选逐文件原子。
理由是磁盘峰值低，中断代价小。
代价是中断后可能短暂混合。

### 14.3 全量哈希，还是大小加时间

选全量哈希。
理由是不能靠 mtime 判断内容。
代价是电脑侧首次扫盘慢。
缓解办法是超过 20000 条就置 `truncated` 并要求用户缩小范围。

### 14.4 完整克隆，还是等 qfli_git 加深

先用完整克隆（R8）。
理由是 depth 要改 C 接口，跨仓库协调。
完整克隆只在首次付出成本。
超过 200 MB 时先请用户确认。

### 14.5 会话流自己存，还是复用 agent_sessions

自己存。
`agent_sessions` 按项目分目录并带消息历史。
远端事件流是另一套结构，混进去会污染列表。
新缓存是单一文件，容易限量。

### 14.6 第一版只走中继，还是同时上直连

只走中继（R7）。
理由见 3.3 节：内置中继默认明文。
直连要等 TLS 与证书固定。

## 15. 与现有测试的兼容

1. `protocol.dart` 的解析本就宽松。
   新增可选字段不影响既有断言。
2. `AgentInfo` 的新字段全部可空。
   现有构造调用不需要改。
3. `Project` 的新字段全部可空或有默认值。
   `toJson` 只在非空时写出。
4. 新增模块全部走端口接口。
   云端测试不需要 socket，也不需要原生库。
5. 不改 `harness_host.dart`。
   `RemoteHarnessHost` 原本的构造参数不变。
6. 不改 `dart_test.yaml` 的 2 分钟超时。
7. 不新增真实的 `Process.run`。
   电脑侧测试用临时目录加假文件。
8. `project.dart` 与 `project_store.dart` 只追加块（R10）。
   与 Pi-B 的同文件改动不冲突。

## 16. 上线与回滚

### 16.1 上线顺序

1. 先发电脑侧。
   新字段与新请求都是增量。
   旧手机读到新字段会忽略。
2. 再发手机侧。
   按 `capabilities` 显示入口。
3. 最后开默认开关。

集成顺序按 R11：C → B → A → D。
本任务是 D，排在最后。

### 16.2 开关

开关读 `StudioProfile`。
默认关闭，灰度期只对已绑定电脑的账号打开。

### 16.3 回滚

1. 关开关，入口立即消失。
2. 去掉 `fs_sync` 能力位，新手机也不再显示入口。
3. 已同步的副本留在 `deviceProjects`，可直接整目录删除。
4. 占位项目留在 `deviceSessions`，可直接整目录删除。
5. 以上都不涉及 `ProjectStore` 之外的持久化。

### 16.4 数据迁移

没有迁移。
新增字段缺省为 `null` 或 `false`。
旧项目按普通本地项目处理。

## 17. 裁定对照表

| 裁定 | 涉及本文位置 | 落地方式 |
| --- | --- | --- |
| R4 设备信息字段与转换 | 12.1 至 12.5 | 字段表加映射表，`RemoteHarnessHost` 实现接口 |
| R7 局域网直连必须认证 | 3.3、3.4、4.6、14.6 | 第一版只走中继，直连挂 `lan_tls` |
| R8 git 先完整克隆并提示大小 | 4.3、6.4、8.1、14.4 | `gitBytes` 加 200 MB 阈值 |
| R9 接受 Q2 至 Q5 与 Q7 | 11.3、17.1 | 上限 2 MiB 或 400 条，入口放编辑器 |
| R10 重叠文件规则 | 11.2、15 | 新字段独立块追加，不重排已有代码 |
| R11 顺序 | 12.6、16.1 | 等接口合入，集成排在 C、B、A 之后 |

### 17.1 已采纳的问答

| 问题 | 答案 | 状态 |
| --- | --- | --- |
| Q1 字段名 | `hostName`、`os`、`osVersion` | 由 R4 确认 |
| Q2 入口位置 | 编辑器 Agent 面板 | 由 R9 采纳 |
| Q3 会话流上限 | 2 MiB 或 400 条 | 由 R9 采纳 |
| Q4 不调 git 子进程 | 只读 `.git/config` 与 `HEAD` | 由 R9 采纳 |
| Q5 清单截断 | 置 `truncated` 并提示 | 由 R9 采纳 |
| Q7 不加文件专用通道 | 走 `msg` 帧分块 | 由 R9 采纳 |

## 18. 待决问题与建议答案

只剩一条，其余已在 17.1 结案。

### Q6 局域网地址从哪来（已按 R7 改写）

问题：手机怎么知道直连地址。

建议：电脑在 `info.lanUrls` 上报。
只在能力位 `lan_tls` 存在时填。
第一版不填，手机只走中继。

不接受的做法：

1. 新开一个不认证的监听端口。
2. 用明文 `ws://` 作直连，强度低于中继。
3. 运行时信任任意证书。

## 19. 风险

1. 逐文件改名在 Android 外部存储上可能跨设备失败。
   缓解：暂存目录与目标放在同一分区。
2. 完整克隆在弱网手机上耗时长。
   缓解：进度可见，可取消，超过 200 MB 先确认。
3. 清单扫描占电脑 CPU。
   缓解：分块让出事件循环。
4. 占位项目可能堆积。
   缓解：会话结束时清理，另加一次启动自检。
5. 等 Pi-C 接口期间文档与代码会短暂不一致。
   缓解：接口合入前不动代码，只改文档。
