# 外部文件夹实施计划

## 0. 审查裁定与提交划分

`reports/plan-review.md` 的三条裁定改变本计划。

- R5：不往外部文件夹写 `.qfli/`。外部项目元数据存注册表。
- R6：第一版不删外部文件。删除外部项目只移出列表。
- R10：`project.dart` 与 `project_store.dart` 只追加新块。不重排已有代码。

提交按父任务的需求号划分，一个需求一个提交。

| 提交 | 需求 | 内容 |
| --- | --- | --- |
| 1 | 3 | iOS 选择器与书签、core 服务层 |
| 2 | 4 | Mac 权限与原生方法 |
| 3 | 5 | 协调读写、占位下载、读写接缝 |
| 4 | 6 | 外部文件夹当项目根 |

## 前置约定

- 静态检查只在本机跑：`dart format` 与 `flutter analyze --no-pub`。
- 测试只在云端 CI 跑。本机不跑 `flutter test`。
- 原生构建只在 CI 的 App installers 里做。本机不跑 Xcode 构建。
- 回滚点按提交切分。回滚一个提交不影响前一个。
- 新增 Swift 代码写进现有文件，不动 `project.pbxproj`。

## 步骤 1：core 服务层（需求 3）

仓库：`qfli_studio_core`

文件：新 `lib/services/external_folder_service.dart`、新 `test/external_folder_service_test.dart`

动作：实现 `pickFolder`、`resolveFolders`、`releaseFolder` 三条通道。实现 `adopt`、`isExternal`、`folderIdOf`。实现 `ensureAvailable` 的握手与缓存。

静态检查：

```
dart format lib/services/external_folder_service.dart test/external_folder_service_test.dart
flutter analyze --no-pub lib/services/external_folder_service.dart test/external_folder_service_test.dart
```

审查门 G1：确认 `supported` 与 `ensureAvailable` 的降级路径。

回滚点 R1。

## 步骤 2：iOS 原生选择与书签（需求 3）

仓库：`qflistudio`

文件：`ios/Runner/AppDelegate.swift`

动作：加 `pickFolder`、`resolveFolders`、`releaseFolder`。加书签存储文件的读写。加范围登记表。

静态检查：本步无 Dart 改动，跳过 analyze。CI 走 App installers 的 iOS 构建。

审查门 G1：书签存储结构与六个错误码冻结。

回滚点 R2。

## 步骤 3：Mac 沙盒权限（需求 4）

仓库：`qflistudio`

文件：`macos/Runner/DebugProfile.entitlements`、`macos/Runner/Release.entitlements`

动作：补 `com.apple.security.files.user-selected.read-write` 与 `com.apple.security.files.bookmarks.app-scope`。

静态检查：`plutil -lint` 两个文件（需要在 macOS 上执行）。本机不能跑时留到 CI。

审查门：确认 Debug 与 Release 两份一致。

回滚点 R3：两个文件一起回滚。

## 步骤 4：Mac 原生选择与书签（需求 4）

仓库：`qflistudio`

文件：`macos/Runner/MainFlutterWindow.swift`

动作：加同一套方法。`pickFolder` 用 `NSOpenPanel`。书签存储路径拼 `Bundle.main.bundleIdentifier`。

静态检查：本步无 Dart 改动，跳过 analyze。

审查门 G2：原生契约冻结。两地方法名、参数名、返回结构逐项对照。

回滚点 R4。

## 步骤 5：core 读写接缝（需求 5）

仓库：`qfli_studio_core`

文件：新 `lib/services/project_file_access.dart`、新 `test/project_file_access_test.dart`，以及 `lib/services/external_folder_service.dart` 里的 `list`、`read`、`write`

动作：按路径分流。外部根走原生。其它路径走 `dart:io`。

静态检查：

```
dart format lib/services/project_file_access.dart lib/services/external_folder_service.dart test/project_file_access_test.dart
flutter analyze --no-pub lib/services/project_file_access.dart lib/services/external_folder_service.dart test/project_file_access_test.dart
```

审查门：确认未登记外部根时行为与现在完全一致。

回滚点 R5。

## 步骤 6：原生协调读写与占位下载（需求 5）

仓库：`qflistudio`

文件：`ios/Runner/AppDelegate.swift`、`macos/Runner/MainFlutterWindow.swift`

动作：加 `coordinatedRead`、`coordinatedWrite`、`folderList`。加串行队列与主线程回复。加下载超时。

静态检查：本步无 Dart 改动，跳过 analyze。

审查门：确认写盘用 `.forReplacing`，新建文件用空选项。

回滚点 R6。

## 步骤 7：编辑器与 agent 工具接缝（需求 5）

仓库：`qfli_studio_core`

文件：`lib/editor/editor_controller.dart`、`lib/vibe_coding/vibe_tools.dart`、`lib/services/file_service.dart`

动作：`saveFile` 的写盘走 `ProjectFileAccess.writeBytes`。`vibe_tools` 的 `read` 与 `_commitWrite` 走接缝。`listSorted` 支持外部根。

静态检查：

```
dart format lib/editor/editor_controller.dart lib/vibe_coding/vibe_tools.dart lib/services/file_service.dart
flutter analyze --no-pub lib/editor/editor_controller.dart lib/vibe_coding/vibe_tools.dart lib/services/file_service.dart
```

审查门：确认 `saveFile` 的返回值与错误文案不变。

回滚点 R7。

## 步骤 8：项目模型与注册表（需求 6）

仓库：`qfli_studio_core`

文件：`lib/models/project.dart`、`lib/store/project_store.dart`

动作：`Project` 追加 `externalFolderId`。`addExisting` 加可选 `folderId`。`_reload` 调 `restore()` 并换路径。注册表读写新字段。按 R5 跳过外部项目的 `.qfli` 写入。按 R6 让 `deleteProject` 对外部项目只移出列表。

静态检查：

```
dart format lib/models/project.dart lib/store/project_store.dart
flutter analyze --no-pub lib/models/project.dart lib/store/project_store.dart
```

审查门 G3：注册表结构冻结。确认旧 `projects.json` 可读。

回滚点 R8。

## 步骤 9：选择器接线（需求 6）

仓库：`qfli_studio_core`

文件：`lib/widgets/project_dialogs.dart`

动作：`_pickFolder` 先试 `ExternalFolderService.pick()`。不可用时退回 `getDirectoryPath()`。选中后把 `folderId` 传给 `addExisting`。

静态检查：`dart format` 与 `flutter analyze --no-pub lib/widgets/project_dialogs.dart`。

审查门：确认 Windows 与 Linux 路径不变。

回滚点 R9。

## 步骤 10：CI 验证

仓库：两个

文件：无新增

动作：推分支，等 core-check 与 App installers 全绿。

静态检查：CI 产出为准。本机只跑 analyze。

审查门 G4：两套流水线全绿才进入真机验收。

回滚点：不适用。

## 步骤 11：真机验收

仓库：两个

文件：无

动作：按下表逐项验收。每项记录设备、系统版本、结果。

| 项 | 需要真机 | 说明 |
| --- | --- | --- |
| iOS 选 Obsidian 文件夹 | 是 | 系统选择器只有真机有 |
| 重启后仍能读写 | 是 | 书签解析与续期 |
| 书签过期自动续期 | 是 | 需要旧书签，靠时间或重装触发 |
| 编辑写盘不损坏 | 是 | 与 Obsidian 同时开同一文件 |
| iCloud 占位先下载 | 是 | 需要 iCloud 与“删除下载”状态 |
| Mac 沙盒包读写 | 是 | 必须签名后的沙盒包 |
| Mac 重启后仍能读写 | 是 | app-scope 书签 |
| 文件树、编辑、写盘、agent 工具 | 是 | 端到端 |
| 删除外部项目不动目录 | 是 | 目录与文件都还在 |
| 降级路径（原生缺失） | 否 | 可用旧包配新 Dart 验证 |

## 步骤 12：规范同步

仓库：`qflistudio`

文件：`.trellis/spec/frontend/project-storage.md`

动作：补一节外部根契约。写明书签字段、路径改写规则、元数据存放位置、协调写入范围。

静态检查：`python scripts/ste-lint-zh.py .trellis/spec/frontend/project-storage.md`。

审查门：与实现对照，确认无遗漏。

回滚点 R10。

## 检查汇总

| 检查 | 位置 | 频率 |
| --- | --- | --- |
| `dart format` | core 与 app 的改动文件 | 每步 |
| `flutter analyze --no-pub` | 每步列出的路径 | 每步 |
| `plutil -lint` | macOS entitlements | 步骤 3 |
| core-check | 云端 CI | 步骤 10 |
| App installers | 云端 CI | 步骤 10 |
| 真机验收 | iOS 与 Mac | 步骤 11 |

## 失败处理

- analyze 失败：先修静态问题，再提交。不跳过检查。
- CI 失败：只改本任务的路径。其它 Pi 的文件不碰。
- 真机失败：回到对应步骤，补测试或改实现。不改验收标准。
