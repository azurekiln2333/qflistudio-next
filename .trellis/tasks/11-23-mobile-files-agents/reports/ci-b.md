# CI 修复记录（Pi-B，第 1 轮）

来源：`ci1-b.list`。两条都落在 core 仓库。

两个修复合成一个提交：`a796ccb` fix(explorer): keep an external root usable when the native list is missing。

## 失败 1 `test/external_agent_files_test.dart :: read 与 write 走协调通道`

### 现象

`VibeProjectFiles._decodeText` 抛 `文件不是 UTF-8 文本，工具拒绝读取或覆盖`。

### 根因

测试桩用 `Uint8List.fromList('远程正文'.codeUnits)` 造通道返回。`codeUnits` 是 UTF-16 码元，每个汉字大于 0xFF，`Uint8List` 截断后得到一串非法 UTF-8 字节。原生 `coordinatedRead` 实际回的是文件原始字节（UTF-8），生产代码按 UTF-8 严格解码没有错。错在测试桩。

### 修复

桩改为 `Uint8List.fromList(utf8.encode('远程正文'))`，并补 `dart:convert` 导入。生产代码不变。

### 判定

测试本身错，按规则改测试。断言（`expect(await files.read('todo.md'), '远程正文')`）保持原样，说明修复后仍然是同一个契约。

## 失败 2 `test/external_explorer_menu_test.dart :: 外部根条目不提供删除`

### 现象

`find.text('note.md')` 找到 0 个 widget，长按失败。

### 根因

`FileExplorer._loadChildren` 只捕获 `FileSystemException`。外部根的目录列表走 `FileService.listSorted` → `ExternalFolderService.list`，该函数在通道返回 null 时抛 `StateError('外部文件夹未返回列表')`。异常穿过 `_loadChildren`，`_refresh` 中断，`_children` 保持为空，树上一个条目都没有。

测试桩对 `folderList` 应返回 `[note.md]`。真实场景里原生可能暂时不回列表，此时 `ExternalFolderService.list` 抛 `StateError`。两种情况下生产代码都把整棵树打成空白。这是错的行为：外部根应当降级成空目录，而不是让文件树整体不可用。

### 修复

`lib/editor/file_explorer.dart` 的 `_loadChildren` 增加 `on StateError` 分支，与 `FileSystemException` 一样回落到空列表。只影响这一层目录，其它目录与树的其余部分照常显示。

### 判定

生产代码错（异常类型收窄得太死），改代码，测试不动。

## 静态检查

- `dart format lib/editor/file_explorer.dart test/external_agent_files_test.dart` 0 处改动（首轮格式化后）
- `flutter analyze --no-pub lib/editor/file_explorer.dart test/external_agent_files_test.dart test/external_explorer_menu_test.dart` 输出 No issues found
- 未跑 `flutter test`，按约束交给云端 CI
