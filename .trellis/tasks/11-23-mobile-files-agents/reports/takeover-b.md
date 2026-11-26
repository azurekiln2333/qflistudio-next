# 外部文件夹接管记录（Pi-B）

任务：`11-23-mobile-files-agents`，子任务 `11-23-external-folders`。
范围：外部根的登记、文件树读失败的降级，以及对应测试。
工作树：`_wt/mobile/int/qfli_studio_core`。

## 1 上一版报告错在哪

上一版把 `external_explorer_menu_test` 的根因写成「`VibeProjectFiles.resolve` 拼错路径」。这条不成立：文件树的调用链里没有 `VibeProjectFiles`。

实际链路逐段检查：

1. `FileExplorer._rebuildRoot()` 用 `_roots` 建根节点，`_loadChildren` 读这一层。
2. `_loadChildren` 调 `FileService.listSorted(dir.path)`。
3. `FileService.listSorted` 的分支键是 `ExternalFolderService.isExternal(dirPath)`（`file_service.dart:30`）。
4. `isExternal` 只看内存登记 `_rootByFolder`，不发通道。
5. 登记不为空时才调 `ExternalFolderService.list`，走原生 `folderList`。

文件树不经过 `vibe_tools.dart`。上一版把两条 CI 失败并成同一个根因，是错的。

## 2 真实根因（`external_explorer_menu_test`）

`ProjectStore.addExistingExternal` → `_registerExistingFolder(rawPath, externalFolderId: ...)` 只把 `externalFolderId` 写进 `Project` 与注册表，从不调用 `ExternalFolderService.adopt`。

测试里的顺序：

1. `store.load()`：注册表为空，`_resolveExternalPaths` 开头就返回，`restore()` 一次都没跑。
2. `store.addExistingExternal(vault, folderId: 'vault')`：项目进列表，但没有任何 `adopt`。
3. `FileExplorer` 建树：`isExternal(vault)` 为 false，走 `Directory(vault).list()` 普通分支。
4. 桩只给原生 `folderList` 备了 `note.md`。原生列表从未触发，条目进不了树。

结论：契约缺口在登记，不在解析。

## 3 修复

### 3.1 登记（`lib/store/project_store.dart`）

`_registerLocalProject` 落盘成功后、`notifyListeners()` 之前，按 `project.externalFolderId` / `path` / `name` 调一次 `ExternalFolderService.adopt`。

- 放在 `_persist` 之后，回滚分支不需要任何撤销逻辑。上一版加的前置 `adopt` 与 `forget` 已删除，`external_folder_service.dart` 回到与 HEAD 完全一致。
- 只写内存映射，不碰通道，不会「每次文件操作都握手」。
- `pick()` 在选中时登记过外部根，这里兼顾直接调 `add` 的调用方。
- 覆盖同一 folder id 的场景与上一版相同（按 id 存路径），未引入新的覆盖面。

### 3.2 读失败不吞成空目录（`lib/editor/file_explorer.dart`）

上一版写的 `on StateError` 把失败吞成空列表，这是错的：空目录等于「这层什么都没有」，用户看不出权限问题。现在：

- `PlatformException`（原生收回权限、书签失效）与 `StateError`（通道未就绪、无返回）都不逃逸出 `_loadChildren`。
- 两种失败都保留 `_children[dir.path]` 里已有的节点。
- `_showListingFailure` 弹一次提示，带目录名。`ScaffoldMessenger.maybeOf` 在没有 Scaffold 的宿主里安静跳过。
- 提示额度由 `_listingFailurePath` 记录：同一目录读成功后才重新武装。`_rebuildRoot`（换项目或换根）时重置。
- 额度重置只在 `listed == true` 的分支执行。上一版放在 catch 之后无条件执行，失败当场就把额度重新武装，提示不止一次。

`FileSystemException` 分支保持原样（清空这一层），那是真实的「目录不在」，与访问失败不是一回事。

### 3.3 刷新不再清空缓存（`lib/editor/file_explorer.dart`）

上一版留了 `_refresh()` 开头的 `_children.clear()`，它在读取之前就把缓存清掉，3.2 的「保留旧节点」在真实刷新路径上完全失效。改为：

- 去掉无条件 `_children.clear()`。
- 新增 `_pruneStaleDescendants(dirPath, children)`，只在父层**读成功**后调用，按可信列表丢掉该层已不存在的子目录缓存。
- 失败路径不碰任何缓存，旧节点继续显示。

## 4 新增回归测试（`test/external_explorer_listing_failure_test.dart`）

刷新走 `FileExplorer.refreshSignal`（`ValueListenable<int>`）。它让同一个 State 重读目录，不重建组件，也不丢 `_children`。全程一个 State，没有伪造缓存注入。

- `注册外部根后条目出现在文件树`：断言 `isExternal(vault)` 为真且 `note.md` 可见。这条锁住 3.1 的缺口。
- `同一棵树刷新失败保留节点并报错，恢复后再次失败能再报`，四步：
  1. 首帧读成功，`note.md` 在，无提示。
  2. 同一 State 刷新、原生抛 `PlatformException`：`note.md` 仍在，出现一次 SnackBar。
  3. 再失败一次：仍然只有一个 SnackBar，失败没有把额度重新武装。
  4. 原生恢复后刷新：读到条目、提示消失。再失败：SnackBar 重新出现，说明额度确实重置。

既有 `external_explorer_menu_test.dart`、`external_agent_files_test.dart`、`external_agent_root_resolve_test.dart` 的断言一处未改。

## 5 与 CI 报告的对照

`ci-failures-2.md` 对应 `606810bd`。

| CI 失败 | 真实根因 | 现在是否已修 |
| --- | --- | --- |
| `external_agent_files_test.dart :: read 与 write 走协调通道` | `resolve` 只认 `projectRoot`。外部根的 `todo.md` 拼成项目内路径，`isExternal` 判否，协调读取不触发。桩还用了 `'远程正文'.codeUnits` 造非法 UTF-8 | 是。`9847ea7` 的 `_externalRoot` 让 `resolve` 返外部绝对路径。`a796ccb` 把桩改成 `utf8.encode`。这条与文件树无关 |
| `external_explorer_menu_test.dart :: 外部根条目不提供删除` | `addExistingExternal` 不 `adopt`，`isExternal` 为假，原生列表不触发，树为空 | 是。本轮 3.1 |

## 6 改动路径

- `qfli_studio_core/lib/store/project_store.dart`：`_registerLocalProject` 落盘成功后登记外部根。
- `qfli_studio_core/lib/editor/file_explorer.dart`：两种读失败不逃逸、保留旧节点、提示一次并可重新武装。`_refresh` 不再无条件清缓存，改为成功后裁剪。
- `qfli_studio_core/test/external_explorer_listing_failure_test.dart`：新增回归。

`lib/services/external_folder_service.dart` 与 HEAD 无差异。没碰 `editor_page.dart`、`models/project.dart` 与生成的插件注册文件。

## 7 静态检查

- `dart format lib/editor/file_explorer.dart lib/store/project_store.dart lib/services/external_folder_service.dart test/external_explorer_listing_failure_test.dart`：无改动。
- `flutter analyze --no-pub`，对象为上述 4 个文件加 `external_explorer_menu_test.dart`、`external_agent_files_test.dart`、`external_folder_service_test.dart`、`external_project_root_test.dart`、`external_agent_root_resolve_test.dart`：No issues found。
- 未跑 `flutter test`，按约束交给云端 CI。

## 8 剩余风险

- 无法本地执行测试。两条 CI 失败的「已修」判断来自调用链推导与静态检查，最终以 CI 为准。
- `ExternalFolderService.list` 仍用 `StateError` 表达「平台不支持或原生无返回」，与「目录为空」只能靠异常类型区分。收窄类型要动服务层接口与两处调用方，本轮按指示不做。
- `_pruneStaleDescendants` 只清理直接子目录这一层，更深层由各自的父层在读成功时处理。父层一直读不到的深层缓存会留到下次成功，属于可接受的有界残留。
- 真机仍待验证：iOS 首次授权、iCloud 占位下载后刷新文件树、书签过期续期后的列表。
