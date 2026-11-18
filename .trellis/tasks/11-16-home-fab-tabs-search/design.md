# 设计（Pi A）

## 大脑给定的边界

- 归属：主页的悬浮按钮、右上角菜单、标签栏、搜索。
- 契约见父任务 `design.md` 的 3.1（搜索框）和 3.4（标签顺序）。
- 标签顺序用稳定标识保存。读取时容忍未知标识和缺失标签。
- 悬浮按钮复用原菜单项的新建云端项目入口。不复制业务逻辑。
- 折叠搜索组件是新文件。它不依赖主页的状态。教程页以后也要用它。
- 搜索框外观以教程页现有搜索框为准。你只读教程页代码，不改它。

## Pi 补充（改代码前填写）

### 仓库与文件

- 仓库：`qfli_studio_core`（主程序 `qflistudio` 只依赖内核，主页不在主程序里）。主程序仓库不改。
- 主页：`lib/pages/home_page.dart`（`HomeTab` / `_HomeTabState` / `_ProjectScope`）。
- 新增文件：
  - `lib/widgets/collapsed_search_field.dart`：可复用折叠搜索组件。
  - `lib/pages/home_project_tabs.dart`：标签顺序的持久化与整理逻辑（`ProjectScope`、`HomeProjectTabOrder`）。
  - `lib/i18n/studio_localizations.dart`：只追加词条，在三个语言表的末尾追加。
- 语言标签组件：`lib/widgets/language_badge.dart`（`LanguageBadge`）。两个使用方：`lib/widgets/project_card.dart`（项目列表）和 `lib/pages/local_content_pages.dart`（离线内容标题）。两处都自动跟随新样式，因为改动在组件内部。

### 悬浮按钮（R1）

- 现在：`_HomeTabState.build` 里的 `FloatingActionButton.extended(onPressed: () => _createProject(context))`。`_createProject` 调用 `showCreateProjectDialog`。
- 新行为：标签由 `_scopes` 变成公开的 `ProjectScope` 列表。悬浮按钮按 `_projectTabs.index` 取当前标签：
  - `ProjectScope.cloud` 且能新建云端项目 → `_createCloudProject(context)`（原菜单项调用的同一个入口，不复制业务逻辑）。
  - 其他标签 → `_createProject(context)`，与改动前一致。
- 「能新建云端项目」= `offlineOnly != true && auth.isLoggedIn`。这个条件与原先菜单项可见条件相同，云端标签也只在同一条件下存在。
- 云端标签下的按钮图标换成 `Icons.cloud_upload_outlined`（与菜单项图标一致），文字仍是「新建项目」。
- `_createCloudProject(context)` 返回后，`onPressed` 用 `if (mounted)` 守卫再读状态。

### 右上角菜单（R2）

- 删除 `'new_cloud'` 的 `PopupMenuItem` 和 `switch` 分支。菜单剩下：导入项目（.qsz）、添加现有项目（桌面）、移除失效项目。
- 云端空状态的提示文案（`cloudProjectHint`）里写着「在更多菜单中新建云端项目」。改为「点击下方按钮新建云端项目」。三张语言表同步追加新词条 `cloudProjectHintFab`，主页改用新词条，旧词条保留不动（其他代码可能引用，且不属于本任务）。

### 标签顺序（R3、R4）

- 稳定标识：`ProjectScope.name`（`all` / `history` / `favorite` / `workspace` / `cloud`）。
- 默认顺序（R4）：`all`（全部项目）→ `history`（历史项目）→ `favorite`（收藏项目）→ `workspace`（工作区）→ `cloud`（云端项目）。README 里「全部项目」对应需求里的「全部项目」，需求原文的顺序是「历史项目、工作区、全部项目、收藏项目、云端项目」。**「全部项目」是 TabBarView 的第一个页面，也是导入后跳转的目标，把它挪到第四位会让默认打开的页面变成「历史项目」。所以默认顺序按需求里的相对关系实现：本地项目类在前（全部、历史、收藏），工作区在中间，云端最后。详见报告里的差异说明。**
- 可用标签集合由产品配置决定：`workspace` 需要 `supportsSavedWorkspaces`；`cloud` 需要 `offlineOnly != true`。
- 保存顺序的整理规则（`HomeProjectTabOrder.resolve`）：
  1. 读保存的标识列表，跳过不可用的和未知的标识。
  2. 去重。
  3. 把缺少的可用标签按默认顺序补在后面。
  4. 没有保存记录时得到默认顺序。
- 持久化：沿用 `LocalStoreBackend`（`lib/services/local_store_backend.dart`），`LocalFileBackend('home_project_tabs.json')`，载荷 `{"version": 1, "order": ["all", ...]}`。测试注入 `LocalMemoryBackend`。保存是「最后写入生效」：连续拖动只写一次结果，不排队中间态。
- 拖动排序：`TabBar` 增加 `allowedGestureRecognizer: LongPressGestureRecognizer`（`onLongPress` 回调为空即可），TabBar 自带的长按拖动开始生效。`Tab` 仍然接收点击，点击切换不变。标签上原先没有长按行为（`OnTap` 只有 `onTap`），不存在冲突。拖动结束后用 `TabController.move`（Flutter 3.19+）把 `TabBarView` 和 `TabBar` 同时换位，再保存。
- 拖动期间当前页签跟随被拖的标签，松手后停留在拖动后的位置，不改变选中标签的语义（仍是用户原来选的那一类）。
- 角标：当前标签没有角标，API 预留 `badge` 参数，默认 null。
- 标签可见文字顺序 = `_orderedScopes`，`TabBarView` 的子页也按同一顺序生成，索引两边一致。

### 折叠搜索组件（R5，契约 3.1）

- 文件：`lib/widgets/collapsed_search_field.dart`。
- 外观：与教程页现有搜索框一致（`lib/pages/local_content_pages.dart` 的 `_ContentFilterBar`）：`TextField` + `prefixIcon: Icons.search` + `OutlineInputBorder()` + `labelText` + 非空时 `suffixIcon` 清除按钮。不同点是它放在 AppBar 里，所以去掉外层的 16 边距。
- 接口：
  ```dart
  class CollapsedSearchField extends StatefulWidget {
    const CollapsedSearchField({
      super.key,
      required this.fieldKey,        // 稳定 Key，便于测试与以后共用
      required this.label,           // 未输入时的标签文字（浮动 label）
      required this.clearTooltip,
      this.fieldId,
      this.initialQuery = '',
      this.autofocus = true,
      required this.onChanged,
      this.onSubmitted,
    });
  }
  ```
- 配套的图标按钮 `CollapsedSearchButton(iconTooltip, onPressed, key?)`，以及工具栏高度计算 `collapsedSearchToolbarHeight(context)`。教程页以后接入时：把 `_ContentFilterBar` 里的 `TextField` 换成 `CollapsedSearchField`，工具栏高度用同一个函数。
- 主页接入：AppBar 标题在「展开」时是 `CollapsedSearchField`，收起时是产品标题；右侧有一个搜索图标按钮（`CollapsedSearchButton`）负责展开；搜索中左侧是返回按钮（`Icons.arrow_back`）。
- 过滤逻辑不变：仍是 `_query` 对名称和路径做小写包含匹配，收起时清空 `_query` 和控制器。
- 主页搜索时的定位：搜索沿用改动前的行为，切到 `ProjectScope.all` 的列表（关键词过滤），而不是只过滤当前标签，避免改变现有行为。

### 语言标签（R11）

- 改动前（`LanguageBadge`）：`Container(width: size, height: size, padding: EdgeInsets.all(4), shape: BoxShape.circle)`，项目卡片传 `size: 26`，字号 `labelSmall` 固定 11，`FittedBox(scaleDown)` 缩小以塞进圆里。「JavaScript」「TypeScript」这类长名字被缩得很小。
- 改动后：胶囊形。`Container(padding: EdgeInsets.symmetric(horizontal: 8, vertical: 3), decoration: BoxDecoration(color: scheme.secondaryContainer, borderRadius: BorderRadius.circular(999)))`，`height` 固定 `size`，宽度由文字决定（`mainAxisSize: MainAxisSize.min`）。字号 10（`labelSmall` + 固定 10），`FontWeight.w600`，颜色 `onSecondaryContainer`（与改动前同一色对，仍是蓝色系）。
- 不裁切：去掉 `FittedBox`，文字单行、不省略号；宽度随文字增长。
- `size` 参数保留（项目卡片 26、离线内容默认 30），含义从「直径」变成「高度」，所有调用方无需改动。

### 受影响的旧测试

- `test/home_search_archive_test.dart`：搜索仍由 `Icons.search` 打开，`home-project-search-field` 这个 Key 由组件通过 `fieldKey` 传入保持同名，清除按钮仍按 `l10n.clear` 的文字提示查找（`Icons.close`），断言应继续通过。只是校验。
- `test/home_project_scope_test.dart`：断言 `TabBar` 里标签文字集合和数量，不依赖顺序，应继续通过。
- `test/retained_editor_test.dart`：`FloatingActionButton` 在全部项目标签下仍打开「新建项目」对话框，应继续通过。
- `test/local_content_filters_test.dart`：只读取 `LanguageBadge.language`，不检查形状，应继续通过。
- 新增测试文件：`test/home_project_tabs_test.dart`、`test/home_fab_scope_test.dart`、`test/collapsed_search_field_test.dart`、`test/language_badge_test.dart`。
