# CI 编译阻塞修复：iOS 书签选项（Pi-B）

任务：`11-23-mobile-files-agents`。
CI 运行：`run45157553417`，app `d95361d`，任务 `iOS unsigned IPA`。
错误：Swift Compiler Error，`ios/Runner/AppDelegate.swift` 第 188、250 行，
`withSecurityScope` 在 iOS 上不可用。

## 1 根因

`ExternalFolderStore` 的 iOS 实现照抄了 macOS 的书签选项。`.withSecurityScope`
是 `NSURL.BookmarkCreationOptions` / `NSURL.BookmarkResolutionOptions` 在
**macOS 上的扩展**，iOS SDK 里没有这两个选项，所以编译期直接失败。

两处命中：

1. 第 188 行附近，`resolveAll` 里
   `URL(resolvingBookmarkData:options:relativeTo:bookmarkDataIsStale:)` 传了
   `options: .withSecurityScope`。
2. 第 250 行，`makeBookmark` 里
   `url.bookmarkData(options:includingResourceValuesForKeys:relativeTo:)` 传了
   `options: .withSecurityScope`。

第 147、163、194、215 行的 `startAccessingSecurityScopedResource()` /
`stopAccessingSecurityScopedResource()` 不属于书签选项，它们在 iOS 上可用，
本轮保持不动。

## 2 依据

- Apple 官方文档 “Providing access to directories”
  （developer.apple.com/documentation/uikit/providing-access-to-directories）：
  iOS 用 `.minimalBookmark` 创建书签，解析时用默认选项。
- Apple DTS 论坛线程 772143：确认 `.withSecurityScope` 系列在 iOS 不可用。

两条都是主源，与本地推断一致。

## 3 改动（完整 diff）

只改 `ios/Runner/AppDelegate.swift`，共 2 处语义改动加 3 行注释。

```diff
@@ -186,7 +186,7 @@ final class ExternalFolderStore: NSObject, UIDocumentPickerDelegate {
       guard
         let url = try? URL(
           resolvingBookmarkData: data,
-          options: .withSecurityScope,
+          options: [],
           relativeTo: nil,
           bookmarkDataIsStale: &stale)
       else { continue }
@@ -247,8 +247,11 @@ final class ExternalFolderStore: NSObject, UIDocumentPickerDelegate {
   }
 
   private func makeBookmark(_ url: URL) throws -> Data {
+    // iOS 没有 `.withSecurityScope`（那是 macOS 专属）。
+    // Apple 的「Providing access to directories」要求用 `.minimalBookmark` 建书签，
+    // 解析时用默认选项。作用域授权仍由 startAccessingSecurityScopedResource 负责。
     return try url.bookmarkData(
-      options: .withSecurityScope, includingResourceValuesForKeys: nil, relativeTo: nil)
+      options: .minimalBookmark, includingResourceValuesForKeys: nil, relativeTo: nil)
   }
```

`options: []` 就是「默认解析选项」，与文档要求的 resolve 默认口径一致。

## 4 语义是否保持

保持，且没有引入 macOS 专属选项：

- 作用域授权仍然完全由 `startAccessingSecurityScopedResource()` /
  `stopAccessingSecurityScopedResource()` 负责。书签选项只影响书签数据的编码，
  不授予或收回权限，这两处调用未改。
- 持久化格式不变：`entries` 仍是 `[{id, name, bookmark}]`，`bookmark` 仍是
  base64。已有用户的书签是 `minimalBookmark` 形态，本来就是 iOS 唯一能建的形态。
- `resolveAll` 的 stale 续期逻辑不变：`stale` 为真时用新的 `makeBookmark`
  重写并 `saveEntries()`。
- `UIDocumentPickerViewController(documentTypes: ["public.folder"], in: .open)`
  与 `allowsMultipleSelection` 未改，部署目标 iOS 13.0 覆盖这些 API
  （`.minimalBookmark` iOS 4+，`bookmarkData` iOS 4+，picker iOS 8+）。

注意一条**未验证的迁移风险**：如果某个用户的设备上已经存在用
`.withSecurityScope` 写出的书签数据，`options: []` 解析它是否成功，我无法在本机
验证。实际影响很小，因为 iOS 上从来没能编译出带该选项的版本，这个 app 的
iOS 包此前从未跑通过这条路径。真机验证仍需覆盖「重启后重新打开外部文件夹」。

## 5 其余 iOS 编译风险排查

同一文件里其它可能缺平台保护的调用已排查，没有第二处同类问题：

- `UIDocumentPickerViewController(documentTypes:in:)`、`allowsMultipleSelection`：
  均 iOS 可用。
- 没有使用 `.securityScopeAllowOnlyReadAccess`。
- 文件内剩余 `scopes`、`folderList`、`coordinatedRead/Write` 只用 Foundation
  与 Flutter 基础 API。

## 6 改动路径

- `qflistudio/ios/Runner/AppDelegate.swift`：iOS 书签创建与解析选项。
- `qflistudio/.trellis/spec/frontend/share-target.md`：补一节 iOS 与 macOS
  书签选项差异，含错误矩阵两行。原有的 1 处分号 lint 位于第 52 行，
  是既有文本，本轮未动。
- `macos/Runner/MainFlutterWindow.swift`：**未改**。`git diff --stat macos/`
  为空。macOS 的 `.withSecurityScope`（第 165、230 行）是正确的，保留。

## 7 静态检查

- 无本地 Swift 编译或构建（按约束，且本机无 Xcode）。
- `ste-lint-zh.py` 对 `share-target.md`：新增段落 0 硬违规。文件整体剩 1 处，
  在第 52 行既有英文句子上。
- 全仓 `ios/` 目录再查 `withSecurityScope`：只剩我加的注释文本，无代码引用。

## 8 剩余风险

- 最终以云端 `iOS unsigned IPA` 任务为准。本机无法运行 Swift 编译。
- 真机需验证：重启后重新打开外部文件夹、iCloud 占位下载后刷新、书签过期续期。
- macOS 侧未改，但也未在本轮重新验证。
