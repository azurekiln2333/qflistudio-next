# 交叉检查报告：外部文件夹（11-23-external-folders）

对照 `11-23-external-folders` 的 `prd.md`、`design.md`、`implement.md`、`reports/plan-review.md`、`reports/impl-b.md`，检查 `mobile/integration` 上合并后的代码。范围是 `D:/MyNewProjects/_wt/mobile/int/qflistudio`（应用）与 `D:/MyNewProjects/_wt/mobile/int/qfli_studio_core`（核心）。

## 结论

主体实现与设计一致。通道契约、六种错误码、原生前缀检查（`NO_SCOPE`）都已按 R1–R10 落地。书签续期、`NSFileCoordinator` 读写、iCloud 占位下载同样到位。外部根不写 `.qfli`，外部项目删除不动用户目录。Mac 两份 entitlements 与 iOS `Info.plist` 没有多余授权。

发现 5 处真实缺陷，均已修复并补测试。其余为已接受的取舍，列在「未改项」。

## 已修复

### 1. 编辑器打不开外部根里的 iCloud 占位文件（严重）

`qfli_studio_core/lib/editor/editor_controller.dart:58`（`openPath`）、`:287`（`reloadFromDisk`）、`:346`（`differsFromDisk`）、`:247`（`reopenWithEncoding`）

原实现用 `File(path).stat()` 判断存在，再 `file.readAsBytes()` 直读。iCloud 未下载的文件在盘上只有 `.名字.icloud`。真实路径不存在，`stat().type` 是 `notFound`，于是点开占位文件一律返回「文件不存在」。即使绕过这一步，直读也不会触发下载。这违反 R5「打开未下载文件时先下载再显示正文」。R6「编辑器可打开外部文件」也因此对 iCloud 目录整体失效。

修复方式是外部路径跳过 `stat` 前置判断，改走 `ProjectFileAccess.readBytes`。原生侧先 `materialize` 再 `NSFileCoordinator`，读完再判大小上限。

`modifiedAt` 在下载后补取。三条重载与比对路径同样换成协调读取。

提交：`e956f63 fix(editor): read external files through the coordinated seam`
### 2. 外部根的条目仍可删除（严重）

`qfli_studio_core/lib/editor/file_explorer.dart:1099`（`_showMenu`）

R6 要求不删除用户文件。`ProjectStore.deleteProject` 的外部分支确实只摘登记，但文件树的右键菜单照旧给出「删除」。该入口走 `RecycleBin.backupEntry` 加 `entity.delete`，会直接删除用户目录里的文件。

修复方式是外部路径不渲染「删除」项。新测试 `test/external_explorer_menu_test.dart` 断言外部根条目只有「打开」、没有「删除」，且源文件仍在。

提交：`1838677`，断言修正见 `664d90e`

### 3. 外部根里新建文件绕过协调写入，还会覆盖占位文件（中等）

`qfli_studio_core/lib/editor/file_explorer.dart:1018`（`_create`）

原实现用 `File(path).writeAsString('')` 直写，不走 `NSFileCoordinator`（R4）。存在性判断对占位文件返回 false，用户在同名占位文件上新建会静默覆盖尚未下载的正文。

修复方式是外部路径改走 `ProjectFileAccess.writeBytes`。存在性判断以原生 `folderList` 返回的真实名字为准。

提交：同 `1838677`

### 4. 文件夹选择器取消后又弹一次（中等）

`qfli_studio_core/lib/widgets/project_dialogs.dart:432`（`_pickFolder`）

`ExternalFolderService.pick()` 返回 null（用户取消）时无条件退回 `getDirectoryPath()`。iOS 与 Mac 的 `file_selector` 也支持选目录，取消后立刻弹出第二个选择器。

修复方式是 `ExternalFolderService.supported` 为真时只认系统选择器，取消即结束。其余平台保持原有 `getDirectoryPath()` 回退。

提交：`40febc0 fix(projects): stop reopening a picker after the folder picker is cancelled`

### 5. agent 看不到外部根里的 iCloud 占位文件（中等）

`qfli_studio_core/lib/vibe_coding/vibe_tools.dart:318`（`list`）

`list` 用 `Directory.list` 直列并跳过隐藏项。占位文件在盘上是 `.名字.icloud`，名字以点开头，所以它不出现在列表里，`list_dir` 对纯 iCloud 目录返回空。另外 `entity.length()` 对占位文件抛异常，会让整次列目录失败。R6 要求 agent 三件套在外部根可用。

修复方式是外部目录改走 `FileService.listSorted`（原生 `folderList`，返回真实名字）。文件大小取不到时按 0 计。测试 `test/external_agent_files_test.dart` 覆盖占位文件可见，以及 `read`、`write` 走协调通道。

提交：`0134af8 fix(agent): list external folders through the coordinated seam`

## 未改项（记录理由）

1. **`file_explorer.dart` 的搜索（`searchFiles`）仍用 `dir.listSync`**：搜索结果看不到占位文件，也不会触发下载。搜索针对已下载内容，逐文件下载会拖垮搜索性能，按 R5「只在读取时下载」的取向保留现状。
2. **`ProjectFileAccess.listEntries` 与 `readString` 没有调用方**：设计里预留的 seam，测试已覆盖，暂不删除。
3. **`editor_page.dart:1784` 的 `file.existsSync()` 前置判断**：占位文件进入编辑器前必定已下载，判断成立。用户在其它应用里删除外部文件后，界面要等下次刷新才同步，属已知取舍。
4. **`ensureAvailable()` 用 `resolveFolders` 作握手**：会顺带激活已存书签的作用域。原生侧 `if scopes[id] == nil` 有保护，重复调用幂等，不额外改通道。
5. **Windows、Linux、Android 不提供外部根**：`supported` 仅 iOS 与 macOS，与 PRD 范围一致（无 Android SAF）。

## 平台配置复核

- `macos/Runner/DebugProfile.entitlements`、`Release.entitlements`：`files.user-selected.read-write` 与 `files.bookmarks.app-scope` 齐备，仅 Debug 多 `cs.allow-jit`，无越权。
- `ios/Runner/Info.plist`：`LSSupportsOpeningDocumentsInPlace`、`UIFileSharingEnabled` 已在，无新增键。`Runner.entitlements` 未加无用项。
- 未新增 Swift 文件，`project.pbxproj` 无需改目标成员。
- 两个原生类（`ExternalFolderStore`）都在既有文件内。`handle(_:reply:)` 覆盖 `pickFolder`、`resolveFolders`、`releaseFolder`、`folderList`、`coordinatedRead`、`coordinatedWrite`，未知方法返回 false 交回后续处理器。

## 静态检查

- `dart format`：改动文件均已格式化。
- `flutter analyze --no-pub lib test`（核心）：无 error 与 warning。余 2 条既有 info（`lib/chat/composer_card.dart:346`、`lib/harness/harness_host.dart:6`），不在本次改动范围。
- 未执行 `flutter test`、模拟器或真机（按约束由 CI 与人工验证）。

## 真机待验（CI 不覆盖）

1. iOS：iCloud 目录选为项目根，点开未下载的 `.md` 应下载后进编辑器（本次修复的直接目标）。
2. iOS 与 Mac：取消文件夹选择器后不应再弹第二个选择器。
3. Mac 沙盒：重启后书签续期，仍能读写原目录。
4. iOS：外部根右键菜单没有「删除」。
5. agent `list_dir` 在纯 iCloud 目录能列出文件名。
