# 外部文件夹设计

## 0. 审查裁定

`reports/plan-review.md` 对本设计有三条裁定，实现按裁定执行。

| 裁定 | 内容 | 对本设计的改动 |
| --- | --- | --- |
| R5 | 不往外部文件夹写 `.qfli/` | 删除 `ProjectConfig.write` 的接缝。外部项目的元数据留在应用数据目录，按文件夹 id 关联。已有 `.qfli/project.json` 可读 |
| R6 | 第一版不删外部文件 | `deleteProject` 对外部项目只移出列表并释放书签。不动用户的目录 |
| R10 | 重叠文件只追加 | `project.dart` 与 `project_store.dart` 的新字段各自成块追加。不重排，不重新格式化已有代码。`Info.plist` 只追加键 |

`plan-review.md` 的 R11 定集成顺序 C → B → A → D。本任务的 Dart 改动不依赖 C 的接口。

## 1. 边界

本任务只覆盖 iOS 与 Mac 的外部文件夹。范围有四块：选择与书签、协调读写、占位下载、项目根接线。

不做：Android SAF 目录当项目根、鸿蒙目录授权、外部文件删除、跨设备同步。

依据：父任务 `11-23-mobile-files-agents` 的需求 3-6，以及裁定 R5、R6。

## 2. 契约

### 2.1 通道

沿用通道名 `qflistudio/platform`。iOS 与 Mac 各注册同一套方法。

返回结构沿用 Android 的 `{uri, name}` 形状。名字加一个不透明句柄。

| 方法 | 参数 | 返回 |
| --- | --- | --- |
| `pickFolder` | `{}` | `{id, name, path}` 或 null |
| `resolveFolders` | `{}` | `[{id, name, path, stale}]` |
| `releaseFolder` | `{id}` | null |
| `folderList` | `{path}` | `[{name, path, isDirectory, size, downloaded}]` |
| `coordinatedRead` | `{path}` | `Uint8List` |
| `coordinatedWrite` | `{path, bytes}` | null |

错误码固定六个：`INVALID_ARGUMENT`、`NO_SCOPE`、`READ_FAILED`、`WRITE_FAILED`、`DOWNLOAD_FAILED`、`PICKER_BUSY`。

`NO_SCOPE` 表示路径不在已授权的根内。原生在每次调用前做前缀校验。

与 Android 的对应：`id` 对应 SAF 的 `uri`。两者都是不透明句柄。iOS 与 Mac 多返回 `path`，因为 `dart:io` 需要路径。

### 2.2 Dart 接口

新文件 `lib/services/external_folder_service.dart`（core 仓库）。

```dart
class ExternalFolder {
  const ExternalFolder({
    required this.id,
    required this.name,
    required this.path,
  });

  final String id;
  final String name;
  final String path;
}

class ExternalFolderEntry {
  const ExternalFolderEntry({
    required this.name,
    required this.path,
    required this.isDirectory,
    required this.size,
    required this.downloaded,
  });

  final String name;
  final String path;
  final bool isDirectory;
  final int size;
  final bool downloaded;
}

abstract final class ExternalFolderService {
  static const MethodChannel _channel = MethodChannel('qflistudio/platform');

  /// iOS 与 Mac 为 true。其它平台为 false。
  static bool get supported;

  /// 握手一次并缓存。通道缺失时返回 false。
  static Future<bool> ensureAvailable();

  static Future<ExternalFolder?> pick();

  static Future<List<ExternalFolder>> restore();

  static Future<void> release(String id);

  static Future<List<ExternalFolderEntry>> list(String directoryPath);

  static Future<Uint8List> read(String path);

  static Future<void> write(String path, Uint8List bytes);

  /// 登记本进程内的外部根。选择与恢复后调用。
  static void adopt(ExternalFolder folder);

  static bool isExternal(String path);

  static String? folderIdOf(String path);
}
```

新文件 `lib/services/project_file_access.dart`（core 仓库）。它是读写接缝。

```dart
abstract final class ProjectFileAccess {
  static bool isExternal(String path);

  static Future<Uint8List> readBytes(String path);

  static Future<String> readString(String path);

  static Future<void> writeBytes(String path, List<int> bytes);

  static Future<void> writeString(String path, String text);

  static Future<List<ExternalFolderEntry>> listEntries(String directoryPath);
}
```

语义：外部根走原生。其它路径走 `File(path)` 的现有行为。

### 2.3 原生接口

iOS 写在 `ios/Runner/AppDelegate.swift`。Mac 写在 `macos/Runner/MainFlutterWindow.swift`。

方法名、参数名、返回结构两边一致。UI 与线程模型由各平台自己决定。

新增 Swift 类型放进这两个文件，不改 `project.pbxproj`。理由是手改工程文件容易破坏构建，而本机无法编译验证。

书签创建：

```swift
let data = try url.bookmarkData(
  options: .withSecurityScope,
  includingResourceValuesForKeys: nil,
  relativeTo: nil)
```

书签解析与续期：

```swift
var stale = false
let url = try URL(
  resolvingBookmarkData: data,
  options: .withSecurityScope,
  relativeTo: nil,
  bookmarkDataIsStale: &stale)
_ = url.startAccessingSecurityScopedResource()
if stale { bookmark = try url.bookmarkData(
  options: .withSecurityScope,
  includingResourceValuesForKeys: nil,
  relativeTo: nil) }
```

选择器：

```swift
// iOS
let picker = UIDocumentPickerViewController(
  forOpeningContentTypes: [.folder], asCopy: false)
picker.delegate = self
picker.allowsMultipleSelection = false

// macOS
let panel = NSOpenPanel()
panel.canChooseDirectories = true
panel.canChooseFiles = false
panel.allowsMultipleSelection = false
```

协调写入：

```swift
let coordinator = NSFileCoordinator()
var coordinationError: NSError?
let exists = FileManager.default.fileExists(atPath: url.path)
coordinator.coordinate(
  writingItemAt: url,
  options: exists ? .forReplacing : [],
  error: &coordinationError
) { writeURL in
  try? data.write(to: writeURL, options: .atomic)
}
```

协调读取加下载：

```swift
let keys: Set<URLResourceKey> = [
  .isUbiquitousItemKey, .ubiquitousItemDownloadingStatusKey]
let values = try url.resourceValues(forKeys: keys)
if values.isUbiquitousItem == true,
   values.ubiquitousItemDownloadingStatus != .current {
  try FileManager.default.startDownloadingUbiquitousItem(at: url)
}
var coordinationError: NSError?
coordinator.coordinate(
  readingItemAt: url, options: [], error: &coordinationError
) { readURL in
  payload = try? Data(contentsOf: readURL)
}
```

线程：每个请求派到串行队列 `qfli.external.fs`。回复回主线程。

`folderList` 用 `FileManager.contentsOfDirectory` 逐项取 `isDirectoryKey`、`fileSizeKey`、`isUbiquitousItemKey`、`ubiquitousItemDownloadingStatusKey`。名字以 `.icloud` 结尾的条目按占位处理，`downloaded` 记为 false，名字去掉前缀点与后缀。返回路径换成去掉占位后缀的真实路径。

### 2.4 书签存储

原生自己存储书签。Dart 只见 `id`。

文件：`Application Support/qfli_external_folders.json`。macOS 需拼 `Bundle.main.bundleIdentifier`。

结构：`[{id, name, bookmark}]`。`bookmark` 是 base64 字符串。`id` 用 `UUID().uuidString`。

写入走临时文件加原子替换。加载失败当作空表。

解析失败时跳过该条目，其余条目照常返回。

### 2.5 范围登记

原生维护 `scopes: [String: URL]`。

`pickFolder` 与 `resolveFolders` 成功后写入 `scopes`。`releaseFolder` 调 `stopAccessingSecurityScopedResource`，再删条目与书签。

进程存活期间不释放范围。这样 `dart:io` 的 `stat`、`exists`、`create`、`list` 都能直接用。

## 3. 数据流

1. 用户点"添加现有项目"，再点"选择目录"。
2. iOS 与 Mac 调 `pickFolder`。原生弹选择器。
3. 用户选中后，原生建书签、存盘、开范围，返回 `{id, name, path}`。
4. Dart 调 `ExternalFolderService.adopt`，把根登记到进程内表。
5. `ProjectStore.addExisting(path, folderId: id)` 建项目。注册表在应用数据目录记 `externalFolderId` 与名称、语言、类型。
6. 外部目录里已有 `.qfli/project.json` 时只读它。不创建，不改写。
7. 下次启动 `_reload()` 调 `resolveFolders`，拿到 `id → 路径` 映射。
8. 书签解析出新路径时，改写 `project.path` 并落盘。
9. 编辑器写盘走 `ProjectFileAccess.writeBytes`。外部根转 `coordinatedWrite`。
10. agent 的 `read_file` 与 `write_file` 走同一层。
11. 文件树列目录走 `ProjectFileAccess.listEntries`。外部根转 `folderList`。
12. 用户删除外部项目时只移出列表，再释放书签。目录保持不动。

## 4. 改动清单

### core 仓库 `qfli_studio_core`

| 文件 | 改动 |
| --- | --- |
| 新 `lib/services/external_folder_service.dart` | 通道封装、根登记、可用性握手 |
| 新 `lib/services/project_file_access.dart` | 读写接缝，按路径分流 |
| `lib/models/project.dart` | 追加 `externalFolderId` 字段、`toJson` 与 `fromJson` |
| `lib/store/project_store.dart` | `addExisting` 加可选 `folderId`、`_reload` 换路径、`_registryEntry` 落字段、`deleteProject` 加外部分支 |
| `lib/widgets/project_dialogs.dart` | `_pickFolder` 先试外部文件夹服务 |
| `lib/editor/editor_controller.dart` | `saveFile` 的写盘改走接缝 |
| `lib/vibe_coding/vibe_tools.dart` | `read` 与 `_commitWrite` 改走接缝 |
| `lib/services/file_service.dart` | `listSorted` 支持外部根 |
| 新 `test/external_folder_service_test.dart` | 通道 mock，覆盖六条通道与降级 |
| 新 `test/project_file_access_test.dart` | 覆盖内外部路径分流 |

### app 仓库 `qflistudio`

| 文件 | 改动 |
| --- | --- |
| `ios/Runner/AppDelegate.swift` | 六个方法、书签存储、协调读写、占位下载 |
| `macos/Runner/MainFlutterWindow.swift` | 同一套方法 |
| `macos/Runner/DebugProfile.entitlements` | 补两个 entitlement |
| `macos/Runner/Release.entitlements` | 补两个 entitlement |

### 不改的文件

- `android/src/main/java/com/azurekiln/qfli/core/QfliPickerPlugin.java`
- `lib/services/picker_service.dart`
- `lib/services/project_config.dart`
- `ios/Runner/Info.plist`

## 5. 权衡

### 书签存在哪

选原生。Dart 不碰二进制书签。代价是多一份原生状态文件。

另一种做法是 Dart 存 base64 书签。少一个原生文件。Dart 要编解码，还要在两个平台判断 stale。放弃。

### 原生接管多少文件操作

只让协调敏感的调用走原生：写盘、读取、列目录。其余保持 `dart:io`。

好处是改动面小，错误语义与现有代码一致。代价是要判断路径归属。

全部走原生可以让语义统一。改动面太大，`stat` 与 `create` 也要包一层。放弃。

### 是否复制到沙箱

不复制。省空间，Obsidian 与 QFLI 看同一份文件。

代价是受 file provider 状态影响。断网时未下载的文件读不到。

### 书签与绝对路径

项目注册表继续存绝对路径。另存 `externalFolderId`。

启动时书签解析出新路径才改写 `project.path`。这只更新同一书签的解析结果，不算目录迁移。

### 元数据放哪

按 R5，外部项目不写 `.qfli/`。名称、语言、类型留在注册表。注册表在应用数据目录，随项目条目走。

代价是元数据与文件夹分离。换设备需要重建项目条目。

## 6. 与现有测试的兼容

- `ExternalFolderService.supported` 只看平台。Linux CI 为 false。
- macOS CI 宿主为 true。`ensureAvailable()` 捕获 `MissingPluginException` 并缓存 false。
- `ProjectStore.addExisting` 保留原签名。`folderId` 是可选命名参数。
- `Project.toJson` 新字段可缺省。旧 `projects.json` 照常读。
- `FileService.listSorted` 未登记外部根时走原路径。
- `PickerService` 与 `ProjectConfig` 不改。对应测试不受影响。
- `deleteProject` 的外部分支不改内部项目的现有行为。
- 按 R10，`project.dart` 与 `project_store.dart` 只追加新块。已有行号与格式保持原样。

## 7. 发布与回滚

发布顺序：原生先行，Dart 后接。

原生方法缺失时 Dart 降级到 `getDirectoryPath` 与 `dart:io`。旧安装包配新 Dart 不会崩。

回滚点按提交切分，每个提交单独可回滚。

回滚 Dart 接缝后，外部项目退化为普通绝对路径项目。文件仍可读写。书签失效后用户需重选一次。

回滚原生改动后，Mac 版退回沙盒默认。外部文件夹在重启后失权。

## 8. 开放问题

### Q1 Android SAF 目录当项目根是否在本任务做

裁定 R6 已采纳：不做，父任务记为后续事项。SAF 目录没有 `dart:io` 路径，需要整套 `DocumentFile` 适配。

### Q2 书签解析出新路径时改写 `project.path` 吗

建议：改写。只在解析成功且路径不同的时候改写。项目路径规范（`project-storage.md`）要求保留绝对路径，这里更新的是同一书签的解析结果。

### Q3 外部目录里的文件能否删除

裁定 R6 已采纳：第一版不删。删除外部项目只移出列表。外部文件删除另开任务。

### Q4 是否把 `.qfli/project.json` 写进用户的文件夹

裁定 R5 已覆盖本问题：不创建，不改写。已有文件可读。元数据存应用数据目录，按文件夹 id 关联。

### Q5 占位下载的超时设多久

建议：10 s。超时抛 `DOWNLOAD_FAILED`，界面提示"文件仍在下载"。

### Q6 Mac 是否放弃 `file_selector`

建议：是。沙盒下只有 `NSOpenPanel` 的授权能创建书签。Windows 与 Linux 保留 `file_selector`。

### Q7 应用进后台时是否释放范围

建议：不释放。进程存活期间保持。重启时由 `resolveFolders` 重新开范围。

### Q8 外部根是否参与"最近打开"与工作区

建议：参与。现有逻辑以路径为键，无需额外改动。书签解析出路径变化时，按新路径重排。
