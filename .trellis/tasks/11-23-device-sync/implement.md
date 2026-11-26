# 电脑改动回到手机：实施计划

需求见 `prd.md`。
技术设计见 `design.md`。
裁定见 `../11-23-mobile-files-agents/reports/plan-review.md`。
本文已按 R4、R7、R8、R9、R10、R11 改写。

## 0. 执行前提

1. 分支为 `mobile/pi-d`。
2. App 工作区 `_wt/mobile/pi-d/qflistudio`。
3. Core 工作区 `_wt/mobile/pi-d/qfli_studio_core`。
4. 不修改 `D:/MyNewProjects/qfli_git`。
5. 不修改 `lib/harness/harness_host.dart`。
6. 不修改 `lib/editor/editor_page.dart`。
7. 本机只做静态检查，不跑测试。

## 0.1 等接口合入（R1、R11）

Pi-C 先单独提交接口。
提交内容含 `HarnessSessionTarget`、编辑器两个参数、`HarnessDeviceInfo`、`HarnessDeviceHost`。
那个提交不含界面。

大脑把该提交合进 `mobile/pi-d`。
合入前本任务只改文档，不动代码。

合入后先确认三件事：

1. `lib/harness/harness_host.dart` 里有 `HarnessDeviceInfo`。
2. 同名文件里有 `HarnessDeviceHost`。
3. `EditorPage` 接受 `initialHarnessSession`。

静态检查：

```powershell
cd _wt/mobile/pi-d/qfli_studio_core
flutter analyze --no-pub lib/harness/harness_host.dart
```

任何一项缺失就停下，先向大脑确认。

## 1. 阶段划分

| 阶段 | 内容 | 提交粒度 |
| --- | --- | --- |
| A | 电脑侧协议与实现 | 三个提交 |
| B | Core 镜像类型与设备主机 | 两个提交 |
| C | 同步客户端与缓存 | 三个提交 |
| D | git 拉取与大小确认 | 一个提交 |
| E | 占位项目与会话流 | 两个提交 |
| F | 界面入口与开关 | 一个提交 |

每个阶段结束都过一遍静态检查。
每个阶段是一个回滚点。
集成顺序按 R11 为 C、B、A、D，本任务排在最后。

## 2. 阶段 A：电脑侧

### A1 协议类型

改 `companion/remote_agent/src/shared/protocol.ts`。
加 `FsEntry`、`FsManifest`、三条请求、三条应答。
`project_git_info` 带 `gitBytes`。
`info` 加 `hostName`、`os`、`osVersion`、`lanUrls`。
加三个能力位常量与 `GIT_CONFIRM_BYTES`。

静态检查：

```powershell
cd companion/remote_agent
npm run check
```

回滚点：单独一次提交，只含此文件。

### A2 文件同步实现

新建 `src/agent/fs-sync.ts`。
实现清单扫描、忽略表、分块读取、路径检查。
忽略表带 `FS_IGNORE_VERSION`。
会话记录只在 `agent_sessions/` 与 `transcripts/` 下忽略。

改 `src/agent/core.ts`。
分派 `fs_manifest` 与 `fs_read`。

新增 `test/fs-sync.test.ts`。
覆盖忽略表、路径拒绝、分块边界、截断标记。

静态检查：

```powershell
npm run check
node --test test/fs-sync.test.ts
```

回滚点：单独一次提交。

### A3 设备信息与 git 信息

新建 `src/agent/device-info.ts`。
取系统名与版本，取不到就退回 `os.release()`。
`os` 只输出小写短名。

新建 `src/agent/git-info.ts`。
只读 `.git/config` 与 `.git/HEAD`，不起子进程。
另算 `.git` 目录字节数，填进 `gitBytes`。

改 `src/agent/core.ts` 的 `info` 分支。
带上四个新字段与三个能力位。
第一版不填 `lanUrls`。

新增 `test/git-info.test.ts` 与 `test/device-info.test.ts`。

静态检查：

```powershell
npm run check
node --test test/git-info.test.ts test/device-info.test.ts
```

回滚点：单独一次提交。

## 3. 阶段 B：Core 镜像与设备主机

### B1 镜像类型

改 `lib/remote_control/models/protocol.dart`。
加 `FsEntry`、`FsManifest`、`GitProjectInfo`。
`AgentInfo` 加四个可空字段与对应解析。

静态检查：

```powershell
dart format lib/remote_control/models/protocol.dart
flutter analyze --no-pub lib/remote_control/models/protocol.dart
```

回滚点：单独一次提交，只含此文件。

### B2 RemoteHarnessHost 实现设备主机（R4）

前置：B1 已合入，且 Pi-C 的接口已在分支上。

改 `lib/harness/remote/remote_harness_host.dart`。
让 `RemoteHarnessHost` 实现 `HarnessDeviceHost`。

映射按 `design.md` 12.3 与 12.4 节：

1. `name` 取 `hostName`，缺了取 `host`。
2. `os` 先按上报值映射。
3. 上报值为 `other` 或缺失时用 `platform` 兜底。
4. `osVersion` 原样传，取不到传 `null`。

不改构造参数。
不改 `lib/harness/harness_host.dart`。

新增 `test/harness/remote_harness_device_test.dart`。
覆盖四条：正常上报、`other` 走兜底、字段全缺、未知平台。

静态检查：

```powershell
dart format lib/harness/remote/remote_harness_host.dart
flutter analyze --no-pub lib/harness/remote/remote_harness_host.dart
```

回滚点：单独一次提交。

## 4. 阶段 C：同步客户端与缓存

### C1 端口与忽略表

新建 `lib/sync/device_file_port.dart`。
定义 `DeviceFilePort` 与中继适配器。

新建 `lib/sync/sync_ignore.dart`。
与电脑侧同版本号的忽略表。

静态检查：`dart format` 加 `flutter analyze --no-pub` 两个文件。

### C2 同步服务

新建 `lib/sync/device_sync.dart`。
实现 `plan` 与 `apply`。
写入走暂存目录加哈希检查加原子改名。

暂存目录与目标放同一分区。
这一点写进注释，避免后来人挪走。

静态检查：

```powershell
dart format lib/sync
flutter analyze --no-pub lib/sync
```

### C3 缓存索引

新建 `lib/sync/sync_cache.dart`。
实现预算、最近使用时间、淘汰候选。
跳过的键由调用方传入，服务本身不判断打开状态。

新增 `test/sync/sync_cache_test.dart`。
覆盖预算、淘汰顺序、跳过打开项目、索引重建。

静态检查：

```powershell
dart format lib/sync test/sync
flutter analyze --no-pub lib/sync test/sync
```

回滚点：C1 到 C3 各一个提交。

## 5. 阶段 D：git 拉取与大小确认

新建 `lib/sync/device_git_pull.dart`。
先取 `project_git_info`。
`gitBytes` 超过 200 MB 时返回 `needsConfirm`（R8）。
确认后走 `GitCloneService` 或 `GitBackend.pullRebase`。
不支持时返回 `fallbackToFiles`。

界面的确认文案要写清：该数值是 `.git` 占用，不是下载量。

新增 `test/sync/device_git_pull_test.dart`。
用假的 `DeviceFilePort` 与假的克隆回调。
覆盖五种判断：支持、不支持、无远端、需确认、有本地改动。

静态检查：`dart format` 加 `flutter analyze --no-pub`。

回滚点：单独一次提交。

## 6. 阶段 E：占位项目与会话流

### E1 路径与模型

改 `lib/services/app_paths.dart`。
新增 `deviceProjectRoot` 与 `deviceSessionRoot`。

改 `lib/models/project.dart`。
追加五个可空字段与序列化。
按 R10 只追加独立块，不重排已有字段，不重排已有方法。

改 `lib/store/project_store.dart`。
追加登记与清理两个方法。
同样只追加独立块。

新增 `test/sync/placeholder_project_test.dart`。
覆盖建目录、写配置、登记、按标记删除。

静态检查：

```powershell
dart format lib/services/app_paths.dart lib/models/project.dart lib/store/project_store.dart
flutter analyze --no-pub lib/services/app_paths.dart lib/models/project.dart lib/store/project_store.dart
```

### E2 会话流缓存

新建 `lib/sync/remote_session_cache.dart`。
上限取 2 MiB 或 400 条，按两者中先到的裁剪。

改 `lib/harness/remote/remote_session.dart`。
把事件顺带写进缓存。

新增 `test/sync/remote_session_cache_test.dart`。
覆盖上限裁剪、重启后可读、清空。

静态检查：`dart format` 加 `flutter analyze --no-pub`。

回滚点：E1 与 E2 各一个提交。

## 7. 阶段 F：界面入口与开关

改 `lib/editor/ai_panel.dart`。
远端会话加「同步」与「下载项目文件」两个动作。
按钮按 `capabilities` 显示。

改 `StudioProfile` 对应的开关读取处。
默认关闭。

大克隆的确认弹窗也挂在这一步。

静态检查：

```powershell
dart format lib/editor/ai_panel.dart
flutter analyze --no-pub lib/editor/ai_panel.dart
```

回滚点：关开关即回滚，代码可留。

## 8. 每步都要过的通用检查

1. `dart format` 只格式化改动文件。
   不跑整个目录，避免大量无关改动。
2. `flutter analyze --no-pub` 只看改动路径。
3. 不新增 `Process.run`。
4. 不新增真实网络调用。
5. 新增公开类型写文档注释。
6. 提交信息用 `feat(sync):` 或 `feat(companion):` 前缀。
7. 不碰第 0.1 节列出的他人文件。

## 9. 评审闸门

### 闸门 1：A 阶段结束

检查四件事。
协议是纯增量，旧字段不动。
路径检查拒绝四类输入。
忽略表有版本号。
`lanUrls` 在第一版为空。

### 闸门 2：B 阶段结束

检查三件事。
`protocol.dart` 的解析对缺字段不抛错误。
`RemoteHarnessHost` 实现了 `HarnessDeviceHost`。
`harness_host.dart` 没有改动。

### 闸门 3：C 阶段结束

检查四件事。
暂存目录与目标同分区。
失败保留旧清单。
删除在文件就位之后。
淘汰不碰打开的项目。

### 闸门 4：D 阶段结束

检查三件事。
`qfli_git` 保持原样。
超过 200 MB 会先确认。
不支持时能退回文件同步。

### 闸门 5：E 阶段结束

检查三件事。
占位项目落在 `deviceSessions` 下。
会话流有双上限。
未拉文件时能整层删除。

### 闸门 6：F 阶段结束

检查两件事。
入口只在 `EditorPage` 内。
开关关闭时入口不出现。

## 10. 仅本机可做的检查

1. `dart format` 与 `flutter analyze --no-pub`。
2. `npm run check`，即 TypeScript 类型检查。
3. `node --test` 跑的单元测试，只在电脑侧。
4. 文档的 `ste-lint-zh.py`。

## 11. 必须真机的检查

1. 中继断线后重连的续传。
   需要一台电脑与一部手机，分处不同网络。
2. 弱网下的完整克隆。
   需要真实仓库与可限速的网络。
3. Android 外部存储上的原子改名。
   需要真机，模拟器不覆盖该分区。
4. iOS 沙盒内的目录写入。
   需要真机，模拟器路径不同。
5. 大目录清单扫描的耗时。
   需要 20000 条以上的真实项目。
6. 电脑侧设备信息在真实系统上的取值。
   需要 Windows、macOS、Linux 各一台。

局域网直连不在本任务的验证范围。
第一版只走中继（R7）。

## 12. 必须云端 CI 的检查

1. `flutter test` 全量。
2. `npm test` 全量。
3. App installers 的构建。
4. core-check 的矩阵。

本机不跑上述四项。

## 13. 交付物清单

| 项 | 位置 |
| --- | --- |
| 协议类型 | `companion/remote_agent/src/shared/protocol.ts` |
| 电脑侧实现 | `companion/remote_agent/src/agent/fs-sync.ts` 等四个文件 |
| 电脑侧测试 | `companion/remote_agent/test/fs-sync.test.ts` 等三个文件 |
| 镜像类型 | `lib/remote_control/models/protocol.dart` |
| 设备主机 | `lib/harness/remote/remote_harness_host.dart` |
| 同步客户端 | `lib/sync/` 六个文件 |
| 模型与存储 | `lib/models/project.dart`、`lib/store/project_store.dart` |
| 路径 | `lib/services/app_paths.dart` |
| 界面入口 | `lib/editor/ai_panel.dart` |
| 测试 | `test/sync/` 四个文件，另加 `test/harness/` 一个 |

## 14. 完成判据

1. `prd.md` 的验收标准逐条有对应实现。
2. 阶段 A 到 F 的闸门全部通过。
3. 静态检查零问题。
4. 真机检查项写进报告，未跑就标未验证。
5. 云端 CI 绿后才算完成。
6. `qfli_git` 与 `harness_host.dart` 的提交记录里没有任何改动。