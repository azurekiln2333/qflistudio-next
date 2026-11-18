# Pi A 报告：首页 FAB、页签排序与折叠搜索

任务：`.trellis/tasks/11-16-home-fab-tabs-search`（父任务 `.trellis/tasks/11-16-home-tutorial-tools-ui`，要求 R1、R2、R3、R4、R5、R11）
工作树：`D:\MyNewProjects\_wt\ui-a\qflistudio`、`D:\MyNewProjects\_wt\ui-a\qfli_studio_core`（分支 `ui/pi-a`）
基线：主应用 `d26cffc`，核心库 `573d1b6`

主应用仓库本次未改动：首页在核心库里，`lib/main.dart` 属禁改清单。
因此主应用仓库没有提交，也没有跑 analyze/test。

第一轮提交后，Brain Gate 1 只要求改一处：默认顺序必须按用户给的字面顺序（历史项目、工作区、全部项目、收藏项目、云端项目），不得偏离。
`9a363f0` 完成这项修正，本文件已按修正后的状态更新。

## 提交（qfli_studio_core，`ui/pi-a`）

| 提交 | 标题 |
| --- | --- |
| `a2758b2` | feat(home): add reorderable project tabs with a saved order |
| `68ce22b` | feat(home): create from the visible tab and drop the cloud menu entry |
| `8290900` | refactor(search): share the collapsed search field with Home |
| `05ab270` | feat(badge): make the language badge a compact capsule |
| `51b894a` | feat(home): apply a saved tab order without probing storage at startup |
| `9a363f0` | feat(home): use the requested default tab order |

`git diff --stat 573d1b6..HEAD`：

```
 lib/i18n/studio_localizations.dart      |  12 +
 lib/pages/home_page.dart                | 381 ++++++++++++++++++++-----------
 lib/pages/home_project_tabs.dart        | 170 ++++++++++++++
 lib/services/local_store_backend.dart   |  21 ++
 lib/widgets/collapsed_search_field.dart | 157 +++++++++++++
 lib/widgets/language_badge.dart         |  34 ++-
 test/collapsed_search_field_test.dart   | 306 +++++++++++++++++++++++
 test/home_fab_scope_test.dart           | 241 ++++++++++++++++
 test/home_project_scope_test.dart       |  62 +++++++++
 test/home_project_tabs_test.dart        | 349 ++++++++++++++++++++++++++++
 test/home_project_tabs_widget_test.dart | 391 +++++++++++++++++++++++++++++++
 test/home_search_archive_test.dart      |  14 +-
 test/language_badge_test.dart           | 134 +++++++++++
 13 files changed, 2117 insertions(+), 155 deletions(-)
```

逐文件核对过：没有任何文件落在 `research/dirty-files.txt` 清单里。

## 验证

`flutter analyze`（改动过的仓库，最后几行）：

```
Analyzing qfli_studio_core...
No issues found! (ran in 2.5s)
```

`flutter test`（全量）：`+1406 ~9 -1`。唯一失败项不是代码失败：

```
Failed to load test/interop_arkts_contract_test.dart:
Bad state: missing D:\MyNewProjects\_wt\ui-a\qfli_java\ohos\entry\src\main\ets\interop\InteropReceiver.ets
```

```
00:13 +442 ~5 -1: loading .../test/interop_arkts_contract_test.dart [E]
00:47 +1406 ~9 -1: Some tests failed.
```

该测试用 `Directory.current.parent` 推断同级仓库路径，要求 `qfli_java` 检出在仓库旁边。
本工作树所在的 `_wt\ui-a` 下 `qfli_java` 是空目录（ArkTS 文件仍在主仓库 `D:\MyNewProjects\qfli_java` 未提交）。
这个测试文件本次未改动，基线提交上同样失败，属工作树环境问题，主仓库正常检出时可通过。

报告规则（`pi-rules.md` 第 6 节）要求「改动过的仓库」两个检查都通过。改动过的仓库是核心库，它 analyze 干净、除上述环境性加载失败外全量通过；主应用仓库未改动，无需检查。

本任务新增/相关的套件（全部通过）：

- `test/home_project_tabs_test.dart`：23
- `test/home_project_tabs_widget_test.dart`：9
- `test/home_fab_scope_test.dart`：6
- `test/collapsed_search_field_test.dart`：7
- `test/language_badge_test.dart`：6
- `test/home_project_scope_test.dart`：5
- `test/home_search_archive_test.dart`：11

顺带修好的两个既有失败（原先与本次改动无关地存在于全量套件里）：

- `test/file_history_test.dart`「启动页：ready=false 显示品牌启动页，ready=true 进入主页」
- `test/experience_test.dart`「首屏不创建社区/个人页，外观选择立即影响全局 MD3」

两者都因 `A Timer is still pending even after the widget tree was disposed` 失败：首页在 `initState` 里读页签顺序文件会触发存储路径探测，探测留下计时器。
现在首页只在「不探测也能读」时才读，见下面「决策 2」。

## 已完成的行为

### R2 溢出菜单去掉「新建云端项目」

- 删掉 `PopupMenuButton` 里的 `'new_cloud'` 条目与对应分支。
- 菜单只剩：导入项目（.qsz）、添加已有项目（桌面）、移除失效项目。
- 云端项目只能从 FAB 或空态按钮新建，入口仍是一处。

### R1 FAB 跟随当前页签

- `_createFromCurrentScope(context)`：云端页签走 `_createCloudProject`，其余页签走 `_createProject`。
- 未登录时点云端页签的 FAB 提示 `cloudSignInRequired`（请先在「我的」页登录，再新建云端项目）。
- 云端空态文案改成 `cloudProjectHintFab`，与新入口一致。
- 新增 i18n key（三张表都追加，未改动任何既有 key）：`cloudProjectHintFab`、`cloudSignInRequired`。

### R3/R4 页签排序

- 默认顺序 **历史项目、工作区、全部项目、收藏项目、云端项目**（按 Gate 1 要求，字面执行）。
- 启动落在顺序里的第一个页签，因此首屏是「历史项目」。
- 新增 `lib/pages/home_project_tabs.dart`：
  - `ProjectScope {all, history, favorite, workspace, cloud}`
  - `defaultProjectScopes(profile)`：默认顺序
  - `resolveProjectScopes(saved, available)`：把存档顺序与当前可用范围合成，丢掉未知/重复/不可用项，补齐缺项
  - `mergeProjectScopeOrder(...)`：拖拽发生在读到存档之前时，把这次拖拽合进存档
  - `HomeTabOrderStore`：`home_project_tabs.json`，载荷 `{"version": 1, "order": [...]}`，按稳定标识（枚举名）存
- 长按拖拽用 `LongPressDraggable` + `DragTarget` 直接做在 `_buildScopeTabBar` 里。
- 拖拽后保持原选中页签选中（按范围而不是按下标找回）。
- 测试用 key：页签 `home-scope-tab-<name>`、拖拽源 `home-scope-drag-<name>`、落点 `home-scope-drop-<index>`、页面 `home-scope-page-<name>`。
- 与页签位置无关的两处：
  - 导入项目后跳「全部项目」用 `_orderedScopes.indexOf(ProjectScope.all)`，按范围查找，不是按下标 0。
  - 搜索始终渲染「全部项目」列表（`_buildProjectList(scope: ProjectScope.all, keyword: _query)`），也不是按下标。

### R5 折叠搜索

新增 `lib/widgets/collapsed_search_field.dart`，供首页与教程页共用：

```dart
CollapsedSearchField(
  fieldKey: const ValueKey('home-project-search-field'),
  controller: _searchController,
  label: l10n.searchProjectHint,
  clearTooltip: l10n.clear,
  onChanged: (value) => setState(() => _query = value),
)
```

同时导出 `CollapsedSearchButton({tooltip, onPressed})` 与 `collapsedSearchToolbarHeight(context)`。
AppBar 高度用后者，2.0 倍字体下也不溢出。
组件本身可传 `fieldKey`、`label`、`clearTooltip`、`controller`、`initialQuery`、`autofocus`、`onChanged`、`onSubmitted`。
首页只传了前四项，其余走默认值。
外观与教程页一致（描边输入框 + 前置搜索图标 + 清空按钮），唯一差异是清空按钮的图标：教程页用 `Icons.clear`，首页用 `Icons.close`，见「决策 5」。

### R11 语言徽标

改前：`Container` 圆形（`BoxShape.circle`），宽高都等于 `size`，`FittedBox(scaleDown)` 把长名字压小，字号 11，默认 `size` 30。
改后：胶囊形（`height = size`，左右内边距 8、上下 2，圆角 `size / 2`），字号常量 `LanguageBadge.labelFontSize = 9.5`，去掉 `FittedBox`，按内容收缩（外套 `Center(widthFactor: 1, heightFactor: 1)`），默认 `size` 26，key `ValueKey('language-badge')`。
调用方：`lib/widgets/project_card.dart`（size 26）、`lib/pages/local_content_pages.dart`（默认）。
`size` 的语义从直径变为高度，两处调用方视觉重量不变。

## 决策与偏离

1. **默认顺序按字面执行**（`9a363f0` 起）。第一轮曾按「全部项目排第一」实现，理由是导入跳转与首屏页面；Gate 1 判定这是用户明确要求，不得偏离，已改为历史项目、工作区、全部项目、收藏项目、云端项目。
   首屏因此变为「历史项目」；导入跳转与搜索改为按范围查找，位置变化不影响它们。
   既有测试 `test/home_project_scope_test.dart` 原先在挂载时就断言「全部项目」页内容与语言 chips，现改为：先断言首屏是历史项目（最新在前），再显式切到「全部项目」断言名称排序与 chips 有无。
   该文件的 `_expectScopeLabels` 也由「只查标签存在」改成「按左右顺序断言标签列表」，断言变强而非放松。
2. **读取时机**。页签顺序是外观偏好，不该拖慢首帧。`LocalStoreBackend` 增加 `isReady`：`LocalFileBackend` 只在存储路径已解析时返回 true。首页在 `didChangeDependencies` 里「能直接读就读」，否则推迟到第一次拖拽。正常启动在 bootstrap 阶段已解析路径，所以存档顺序当次生效；仍在探测的情况（以及 widget 测试）不会留下探测计时器。这也是上面两个既有测试恢复通过的原因。
3. **拖拽发生在读到存档之前**。直接存当前顺序会把未拖动过的页签打回默认。`mergeProjectScopeOrder` 保留存档里其他页签的相对位置，只挪被拖的那个。两个列表不是「恰好移动一项」时退回当前顺序，不猜。
4. **`TabBar` 无法原地重排**。`flutter_ohos` 3.27.5 的 `TabBar` 有 `onLongPress` 但没有 `onReorder`，`TabController` 也没有 `move()`。页签原本没有长按行为，所以长按拖拽不冲突；轻点仍选中，横向拖动仍滚动。
5. **清空图标用 `Icons.close`**。教程页的 `_ContentFilterBar` 用的是 `Icons.clear`，两者 IconData 不同。首页沿用旧搜索的 `Icons.close`，既有测试的 finder 不用改，也便于在同一屏区分两个字段。
6. **云端 FAB 未登录**只给提示，不跳登录页：现有登录入口在「我的」页，跨页跳转会改导航结构；文案直接说去哪登录。
7. **搜索测试里的名称比对改成「集合相等」**。搜索页是「全部项目」列表（按名称排序），折叠后回到首屏「历史项目」页（按最近打开排序），两者顺序本就不同。断言的意图是「过滤清掉后两个项目都回来了」，所以折叠后用 `unorderedEquals`；搜索页仍按名称顺序断言（`['Alpha', 'Beta']`）。
   同时把 `_visibleNames` 改成读 `ProjectCard` 而不是读可命中的 `Text`，避免被 `TabBarView` 保活的其他页面干扰，并新增用例 «searching shows the all-projects list, not the current tab»：先断言首屏（历史项目）没有语言 chips 且顺序不是按名称排序，再断言搜索页有 chips 且按名称排序。

## 给 Pi B 的接口

- 折叠搜索：`lib/widgets/collapsed_search_field.dart`，`CollapsedSearchField` / `CollapsedSearchButton` / `collapsedSearchToolbarHeight`。首页的用法见上面 R5 段落，可直接照搬到教程页。
- 语言徽标：`lib/widgets/language_badge.dart` 已改为胶囊并按内容收缩，教程页直接放即可，不需要再套 `FittedBox`。
- 页签排序：排序状态由 `HomeTabOrderStore` 持有，教程页若要做页签排序可复用 `resolveProjectScopes`，但枚举 `ProjectScope` 是首页专用的。
- 默认页签顺序现在是「历史项目、工作区、全部项目、收藏项目、云端项目」，首屏是「历史项目」。教程页若要参照首页布局，按这个顺序。

## 对照验收标准

| 验收项 | 结果 | 依据 |
| --- | --- | --- |
| 云端页签点 FAB 进新建云端流程 | 通过 | `test/home_fab_scope_test.dart`「on the cloud scope the FAB opens the cloud project dialog」 |
| 另外四个页签 FAB 行为不变 | 通过 | 同文件 4 个用例（全部/历史/收藏/工作区） |
| 右上角菜单无「新建云端项目」 | 通过 | `test/home_project_tabs_widget_test.dart`「the overflow menu no longer offers a new cloud project」 |
| 无保存记录时的默认顺序 | 通过 | 「the default tab order is history first and cloud last」按字面顺序断言；首屏由「launch opens the first tab of that order」断言 |
| 长按拖动改变并保存，重建后保留 | 通过 | 「long-press dragging a tab reorders it and the order is saved」 |
| 存档含未知标识或缺页签时不崩溃、缺项补在最后 | 通过 | `test/home_project_tabs_test.dart` 与「a saved order with unknown identifiers still renders every tab once」 |
| 默认只显搜索图标，展开后可过滤，收起清除 | 通过 | `test/collapsed_search_field_test.dart` 7 个用例 |
| 折叠搜索在独立文件，报告写路径与用法 | 通过 | `lib/widgets/collapsed_search_field.dart`，见「R5」与「给 Pi B 的接口」 |
| 语言标签为胶囊形、字变小、报告写前后字号与尺寸 | 通过 | `test/language_badge_test.dart`；改前圆直径/字号 11，改后高 26/字号 9.5，见「R11」 |
| 最长语言名称完整显示 | 通过 | 同文件「javascript」用例，无 `FittedBox` 也未被裁切 |
| 改动过的仓库 analyze 无问题、test 全通过 | **部分通过** | analyze 无问题；test 除 `interop_arkts_contract_test.dart` 的环境性加载失败外全通过，见「验证」 |
| 未改禁改路径 | 通过 | 逐文件核对 `573d1b6..HEAD` |
| 报告已写 | 通过 | 本文件 |

## 未做

- 主应用仓库无需改动（首页在核心库）。
- 未创建、未启动、未归档任何 Trellis 任务。
