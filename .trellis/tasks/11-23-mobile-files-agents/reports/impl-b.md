# 外部文件夹实现报告（Pi-B）

范围：父任务 `11-23-mobile-files-agents` 的需求 3-6。

本报告按需求逐项记录改动、文件、提交、静态检查与真机缺口。

## 0. 裁定与决定的落实

| 裁定 | 落实 |
| --- | --- |
| R5 不写 `.qfli/` | `ProjectStore._registerExistingFolder` 在外部项目上跳过 `ProjectConfig.write`。`VibeProjectFiles._backup` 对外部根直接返回 null，`_commitWrite` 跳过该分支。已有 `.qfli/project.json` 仍可读 |
| R6 不删外部文件 | `deleteProject` 对外部项目只移出列表并调 `releaseFolder`。目录与文件保持不动 |
| R10 只追加 | `project.dart` 与 `project_store.dart` 的新字段与新方法各自成块。没有重排或重新格式化已有代码。`Info.plist` 未改 |

实现期新增的三条决定：

1. 需求跨两个仓库，所以每个需求在两个仓库各有一个提交。同一需求的两个提交用同名消息。
2. 新增 Swift 类型写进现有的 `AppDelegate.swift` 与 `MainFlutterWindow.swift`。不改 `project.pbxproj`，避免手改工程文件破坏构建。
3. `ProjectStore.addExisting` 的签名保持原样。外部入口改用新方法 `addExistingExternal`。原因：两个现有测试继承 `ProjectStore` 并覆写 `addExisting(String)`，加可选参数会让它们的覆写失效。

## 1. 需求 3：iOS 文件夹授权与书签

### 改了什么

- 新增 core 服务层 `ExternalFolderService`。三条通道：`pickFolder`、`resolveFolders`、`releaseFolder`。另有 `adopt`、`isExternal`、`folderIdOf` 与握手缓存。
- 通道名沿用 `qflistudio/platform`。返回结构沿用 Android 的 `{uri, name}` 形状，这里为 `{id, name, path}`。
- iOS 原生实现选择器、书签存储、范围登记与过期续期。
- 书签存 `Application Support/qfli_external_folders.json`。Dart 只见 `id`。
- `ensureAvailable()` 捕获 `MissingPluginException` 并缓存 false。macOS 上的单元测试宿主不会因此报错。

### 文件

core：

- `lib/services/external_folder_service.dart`（新）
- `test/external_folder_service_test.dart`（新）

app：

- `ios/Runner/AppDelegate.swift`

### 提交

- core `1b2725e`：feat(folders): open iOS external folders with security-scoped bookmarks
- app `e3734f3`：feat(ios): pick external folders and keep their bookmarks

### 静态检查

- `dart format lib/services/external_folder_service.dart test/external_folder_service_test.dart`：0 changed
- `flutter analyze --no-pub lib/services/external_folder_service.dart test/external_folder_service_test.dart`：No issues found
- Swift：本机无 Xcode，未编译。CI 的 App installers 负责 iOS 构建

### 真机缺口

系统文件夹选择器、书签续期、重启后读写都只能在真机验证。

## 2. 需求 4：Mac 沙盒权限与同一套书签

### 改了什么

- 两个 entitlements 各补两项：`com.apple.security.files.user-selected.read-write`、`com.apple.security.files.bookmarks.app-scope`。
- macOS 原生实现同一套三条通道。选择器用 `NSOpenPanel`，`canChooseDirectories` 为 true，`canChooseFiles` 为 false。
- 书签存储路径拼 `Bundle.main.bundleIdentifier`，与 path_provider 在 macOS 的布局一致。

### 文件

- `macos/Runner/DebugProfile.entitlements`
- `macos/Runner/Release.entitlements`
- `macos/Runner/MainFlutterWindow.swift`

### 提交

- app `7ef5186`：feat(macos): grant sandboxed folder access with app-scoped bookmarks

### 静态检查

- 本步无 Dart 改动。`plutil -lint` 需要 macOS，本机不运行
- Swift 括号配平检查：`MainFlutterWindow.swift` 花括号 45/45、圆括号 91/91、方括号 26/26

### 真机缺口

沙盒包的选择器授权、重启后读写、entitlement 生效都需要签名后的 Mac 构建。

## 3. 需求 5：协调写入与占位下载

### 改了什么

- 新增 `ProjectFileAccess`。按路径归属分流：外部根走原生，其它走 `dart:io`。
- 原生新增 `coordinatedRead`、`coordinatedWrite`、`folderList`。读写都过 `NSFileCoordinator`，写入按文件是否存在选 `.forReplacing` 或空选项。
- 读取前调 `materialize`：iCloud 占位先 `startDownloadingUbiquitousItem`，再轮询下载状态，10 s 超时抛 `DOWNLOAD_FAILED`。
- `folderList` 把 `.名字.icloud` 占位条目换成真实名字返回，`downloaded` 记 false。文件树因此能看到未下载的文件。
- 编辑器写盘改走接缝：`EditorController.saveFile` 用 `ProjectFileAccess.writeBytes`。
- agent 读写改走接缝：`VibeProjectFiles.read` 用 `readBytes`，`_commitWrite` 用 `writeBytes`。读取时外部根跳过 `exists` 预检，因为占位文件在下载前 `exists` 为假。
- `FileService.listSorted` 对外部根走 `folderList`。
- `ProjectFileAccess.delete` 对外部根抛 `FileSystemException('外部文件夹不支持由 QFLI 删除文件')`。这是 R6 的 agent 侧守卫。现有 agent 工具集里没有删除工具，守卫为将来接线预备。

### 文件

core：

- `lib/services/project_file_access.dart`（新）
- `test/project_file_access_test.dart`（新）
- `lib/editor/editor_controller.dart`
- `lib/vibe_coding/vibe_tools.dart`
- `lib/services/file_service.dart`

app：

- `ios/Runner/AppDelegate.swift`
- `macos/Runner/MainFlutterWindow.swift`

### 提交

- core `7092391`：feat(files): coordinate external writes and read past placeholders
- app `bc84cf4`：feat(ios,macos): coordinate external file reads and writes

### 静态检查

- `dart format` 五个文件：0 changed（首次运行改了 `file_service.dart` 的换行）
- `flutter analyze --no-pub lib/services/project_file_access.dart lib/services/file_service.dart lib/editor/editor_controller.dart lib/vibe_coding/vibe_tools.dart test/project_file_access_test.dart`：No issues found
- Swift 括号配平：iOS 花括号 93/93、圆括号 160/160、方括号 46/46。macOS 花括号 81/81、圆括号 155/155、方括号 42/42

### 真机缺口

- 与 Obsidian 同时写同一文件的完整性
- iCloud 占位文件的下载等待与超时
- `.icloud` 占位在文件树里的显示

## 4. 需求 6：外部文件夹当项目根

### 改了什么

- `Project` 加 `externalFolderId` 字段、`isExternalFolder` 取值、`toJson` 与 `fromJson` 读写。
- `ProjectStore` 新增 `addExistingExternal(path, folderId:)`。原 `addExisting` 签名不变。
- 外部项目注册时跳过 `ProjectConfig.write`，名称、语言、类型只进注册表（R5）。
- `_reload` 后调 `_resolveExternalPaths`：按书签重新解析路径。解析结果与登记路径不同就改写 `project.path` 并落盘。
- `deleteProject` 加外部分支：移出列表、释放书签、不动目录（R6）。
- `_AddExistingDialog._pickFolder` 先试 `ExternalFolderService.pick()`。拿到书签就用外部路径，拿不到退回 `getDirectoryPath()`。手改路径会清掉书签。
- 新增 `test/external_project_root_test.dart`：四条用例覆盖注册表元数据、路径重解析、删除保目录、普通项目仍写 `.qfli`。

### 文件

- `lib/models/project.dart`
- `lib/store/project_store.dart`
- `lib/widgets/project_dialogs.dart`
- `test/external_project_root_test.dart`（新）

### 提交

- core `44e8953`：feat(projects): register external folders as project roots

### 静态检查

- `dart format` 四个文件：0 changed（首次运行改了测试文件）
- `flutter analyze --no-pub lib/models/project.dart lib/store/project_store.dart lib/widgets/project_dialogs.dart test/external_project_root_test.dart`：No issues found
- 全量 `flutter analyze --no-pub lib test`：只剩 2 条既有 info，均在未改动的文件（`lib/chat/composer_card.dart:346`、`lib/harness/harness_host.dart:6`）

### 真机缺口

重启后外部项目仍可打开、外部项目不在应用目录、删除外部项目后目录完好。

## 5. 未完成的步骤

implement.md 步骤 12 要求更新 `.trellis/spec/frontend/project-storage.md`。该文件不在本任务允许改动的路径内（只允许 `11-23-external-folders` 的文档与本报告）。留给后续任务补。

## 6. 需要真机验证的清单

| 项 | 说明 |
| --- | --- |
| iOS 选择"我的 iPhone/Obsidian" | 系统选择器只有真机有 |
| iOS 重启后读写 | 书签解析 |
| 书签过期自动续期 | 靠时间或重装触发 |
| Obsidian 同时写同一文件 | 协调写入的实测 |
| iCloud 占位先下载 | 需要"删除下载"状态 |
| Mac 沙盒包选择与重启 | 必须签名后的沙盒构建 |
| 外部项目删除后目录完好 | R6 的端到端确认 |
| 降级路径 | 旧包配新 Dart，确认不崩 |

## 7. 未验证的部分

- 本机没有跑任何测试，也没有跑 Xcode 构建。
- Swift 只做了括号配平与人工审阅。编译与链接由 CI 的 App installers 确认。
- 新增的 Dart 测试只在云端 core-check 跑。
