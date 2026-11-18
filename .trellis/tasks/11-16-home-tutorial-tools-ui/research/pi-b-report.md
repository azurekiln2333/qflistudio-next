# Pi B 报告：教程页与示例代码页合并 + netrix 第 3 批

写入时间：2026-11-17。
工作目录：`D:\MyNewProjects\_wt\ui-b`。分支：内核 `ui/pi-b`、主程序 `ui/pi-b`。
基线：主程序 `d26cffc`，内核 `573d1b6`。

## 0. 结论速览

| 部分 | 状态 |
|---|---|
| 第一部分：R6 页面合并 | 已完成、已提交、`flutter analyze` 与 `flutter test` 通过 |
| 第一部分（第二轮）：合入 Pi A 与折叠搜索 | 已完成、已提交、`flutter analyze` 与 `flutter test` 通过 |
| 第二部分：netrix 第 3 批（ADV 组 19 个） | **未开始**。等待 120 分钟仍未出现 `research/tools-port-contract.md` |

## 1. 提交列表

### 1.1 内核 `qfli_studio_core`（分支 `ui/pi-b`）

| 哈希 | 标题 |
|---|---|
| `3df651c` | `feat(content): merge tutorials and example code into one page` |
| `ba6751b` | `docs(content): reword the merged tutorial page comments`（只改注释文字，不改行为） |
| `811f147` | `Merge branch 'ui/pi-a' into ui/pi-b`（合入 A 的前四个提交，无冲突） |
| `7f7418c` | `feat(content): collapse the merged tutorial page search into the app bar` |
| `b0e7f52` | `Merge branch 'ui/pi-a' into ui/pi-b`（合入 A 的默认页签顺序 `9a363f0`，无冲突） |

### 1.2 主程序 `qflistudio`（分支 `ui/pi-b`）

| 哈希 | 标题 |
|---|---|
| `3a8a2f1` | `test(home): assert the merged tutorial page replaces the example tab` |
| `ffe4f71` | `test(home): follow the scoped FAB and the collapsed tutorial search` |

另有一个反显未提交的改动：`linux/`、`macos/`、`windows/` 下的 `generated_plugin_registrant.*`
因本地 `pub get` 重新生成而变动，与本次无关，未暂存。

以上提交都不含 `Co-Authored-By`、`Generated with` 或任何 AI 署名。`git add` 全部用明确路径。

## 2. 改动文件

### 内核（9 个文件，+985 / −110 行，第一轮）

第二轮在此基础上新增：`lib/i18n/studio_localizations.dart`（+6 行，新键 `searchContent`）、
`lib/pages/local_content_pages.dart`（折叠搜索）、`test/tutorial_center_page_test.dart`（+3 个用例）。
合入 Pi A 带进的 `lib/pages/home_project_tabs.dart`、`lib/widgets/collapsed_search_field.dart`、
`lib/widgets/language_badge.dart`、`lib/services/local_store_backend.dart` 与 5 个测试文件都属于 A 的改动，不是我写的。

| 文件 | 性质 | 说明 |
|---|---|---|
| `lib/pages/local_content_pages.dart` | 产品代码 | 新增 `TutorialCenterPage` 合并页；提炼共用示例加载；芯片栏改单行横向滚动；两段共用一份筛选状态。第二个提交 `ba6751b` 只改这个文件里的注释文字 |
| `lib/pages/home_page.dart` | 产品代码 | 外壳从 5 个目的地改为 4 个；下标 2 路由到合并页；删除示例代码目的地与对应页面路由 |
| `test/tutorial_center_page_test.dart` | 新测试 | 合并页验收（7 个用例） |
| `test/widget_test.dart` | 旧测试调整 | 导航断言 5→4；示例代码改在页内进入 |
| `test/home_navigation_test.dart` | 旧测试调整 | 导航断言 5→4；「示例代码」不再有目的地标签 |
| `test/home_content_repository_test.dart` | 旧测试调整 | 断言合并页的仓库注入 |
| `test/content_idle_frames_test.dart` | 旧测试调整 | 空转帧断言改走页内示例段 |
| `test/content_code_import_test.dart` | 旧测试调整 | `_homeDetail` 改为先开教程页再切示例段 |
| `test/retained_editor_test.dart` | 旧测试调整 | 新增 `_examplesSection` 帮助函数替代点击「示例代码」图标 |

### 主程序（1 个文件，+67 / −19 行）

| 文件 | 性质 | 说明 |
|---|---|---|
| `test/studio_home_release_test.dart` | 旧测试调整 + 新增 | 生产档位走合并页；新增「外壳没有独立示例代码入口」用例 |

`git diff --stat` 显示以上文件都不在 `research/dirty-files.txt` 里。特别核对的禁止路径：
`lib/main.dart`、`pubspec.lock`、`lib/services/studio_profile.dart`、`lib/editor/editor_page.dart`、
`.trellis/spec/frontend/index.md`、`.trellis/spec/frontend/interop.md` 均未改动。

## 3. 验证输出

### 3.1 内核 `qfli_studio_core`

```
flutter analyze
Analyzing qfli_studio_core...
No issues found!

flutter test
00:41 +1363 ~9 -1: Some tests failed.
[E] 00:09 +403 ~5 -1: loading .../test/interop_arkts_contract_test.dart [E]
```

`+1363` 通过，`~9` 跳过，**唯一失败**是 `interop_arkts_contract_test.dart` 在**加载阶段**失败：

```
Failed to load ".../test/interop_arkts_contract_test.dart":
Bad state: missing D:\MyNewProjects\_wt\ui-b\qfli_java\ohos\entry\src\main\ets\interop\InteropReceiver.ets
```

这不是本次改动引起的，两点证据：

1. 该测试用 `Directory.current.parent` 推断兄弟目录，在基线 `573d1b6` 里就是这么写的
   （`git show 573d1b6:test/interop_arkts_contract_test.dart` 可见）。
2. 在基线未改动的 `D:\MyNewProjects\_wt\ui-int\qfli_studio_core`（`573d1b6`，工作区干净）
   运行同一条命令，得到同一个失败。
   我的 worktree 里 `D:\MyNewProjects\_wt\ui-b\qfli_java` 只有一个 `.trellis` 目录、不是 git 仓库，
   所以该测试找不到 ArkTS 源码。

本次没有跳过、删除或放宽它；按 `pi-rules.md` 第 7 节，这属于「环境缺件」而非「基线无法编译」，
不影响提交，故在此如实报告，交由大脑在集成阶段处理（`ui-int` 同样缺 `qfli_java`）。

合并页新增测试单独运行：`00:02 +7: All tests passed!`。

### 3.2 主程序 `qflistudio`

```
flutter analyze
Analyzing qflistudio...
No issues found!

flutter test
00:03 +9: All tests passed!
```

## 4. 验收标准逐条状态

| 验收标准 | 状态 | 证据 |
|---|---|---|
| 只有一页。顶栏标题是「教程」。有组件测试 | 通过 | 外壳 4 个目的地，下标 2 是 `TutorialCenterPage`。`tutorial_center_page_test.dart`「the merged page titles itself 教程 and shares one language bar」；`studio_home_release_test.dart`「the shell offers no separate example-code entry」 |
| 语言栏单行横向滚动，窄屏宽 360 下一行。有组件测试 | 通过 | `_SingleLineChipRow`（`SingleChildScrollView` + `Row`）。测试「many languages stay one line at width 360」：主 App 的 16 种语言、宽 360、逐芯片断言纵向在同一行带内、`maxScrollExtent > 0` |
| 页内切换教程与示例代码，切换后语言选择保留。有组件测试 | 通过 | 共享 `_ContentFilterSelection`。测试「the section switch keeps the chosen language」断言切到示例段后 java 芯片仍 `selected`，再切回仍 `selected`。测试「one language selection filters both sections」断言选 C++ 后两段都只剩 C++ |
| 选语言后教程列表和示例代码列表都被过滤。有组件测试 | 通过 | 同上两个用例；行级断言用 `find.text('C++ lesson')` / `find.text('C++ example')` 与 Java / Python 行消失 |
| 应用内找不到独立的示例代码页入口。报告写明每个原入口的处理 | 通过 | 见第 5 节。测试「the shell offers no separate example-code entry」断言 `Icons.code_outlined` / `Icons.code` 为空 |
| 搜索默认只有图标，展开出现输入框，收起清空搜索词，与首页一致 | 通过 | 第 8.2 / 8.4 节。`tutorial_center_page_test.dart`「the search collapses to an icon like Home」「collapsing the search clears the query」「the search and the section switch share one query」 |
| 合入 Pi A 后两边行为共存 | 通过 | 两次 `git merge ui/pi-a` 均无冲突。A 的 5 个新测试文件逐个通过：`collapsed_search_field_test.dart`、`home_fab_scope_test.dart`、`home_project_tabs_test.dart`、`home_project_tabs_widget_test.dart`、`language_badge_test.dart` |
| 教程和示例代码的旧测试继续通过。必须调整的测试逐个说明 | 通过 | 页面级旧测试全部未改。走外壳的测试与 `content-query` 键的处理见第 6 节与第 8.4 节 |
| 第 3 批工具全部移植，或清单写明第 3 批为空 | **未通过（阻塞）** | 清单第 7.3 节现为 19 个工具（ADV 组），不再是空。契约文件 `research/tools-port-contract.md` 在 120 分钟轮询内未出现，无骨架提交可合、无契约可依，见第 9 节 |
| 改动过的仓库 `flutter analyze` 无问题，`flutter test` 全部通过 | 通过（有 1 个基线既存失败） | 见第 3 节 |
| 没有改动 `research/dirty-files.txt` 的路径 | 通过 | 见第 2 节 |
| 报告 `research/pi-b-report.md` 已写 | 通过 | 本文件 |

## 5. 每个原入口的处理

| 入口 | 处理 |
|---|---|
| 底部导航「示例代码」（原下标 3，`Icons.code_outlined`） | **删除**。导航变为 4 项：首页 / 工具 / 教程 / 我的 |
| 底部导航「教程」（下标 2） | 指向 `TutorialCenterPage`；它是两段内容的唯一入口 |
| 页内的「教程 / 示例代码」栏目标签栏 | **新增**，`TabBar(isScrollable: true)`，恒为单行可横向滚动 |
| 联网档位（`offlineOnly == false` 且无 `contentRepositoryFactory`）的教程 | 保持原样，仍是社区的 `TutorialsTab`；示例代码入口随导航项一起消失 |
| 课时详情 `_LessonPage`、示例详情 `ExampleDetailPage` | 不变，仍从合并页内打开 |
| 旧页面组件 `LocalTutorialsTab` / `ExampleCodeTab` | **保留**、公开 API 不变、标题不变。应用内不再有入口，但组件和它们的页面级测试继续存在。理由：`pi-rules.md` 禁止删除旧测试 |
| 全仓库检索 | `ExampleCodeTab` / `LocalTutorialsTab` 只剩测试引用，没有别的菜单、路由或深链 |

## 6. 旧测试调整逐个说明

原则：**没有删除任何测试，没有放宽任何断言**。页面级测试（直接挂载 `LocalTutorialsTab` /
`ExampleCodeTab` 的）一行未改、原样通过，因为两个组件的公开 API、标题、筛选行为和列表结构都保持不变。
只有「经过外壳、按导航下标或图标去找示例代码」的测试必须改，因为那个窗口被 R6 删掉了，
这些测试里的 `- 示例代码` 步骤被等价的「页内切到示例段」替代。

### 内核

1. **`widget_test.dart`「底部导航：…五个 Tab 切换」**
   - `find.byType(NavigationDestination)` 5 → 4。
   - 点 `Icons.code_outlined` 改为点 `TutorialCenterPage.examplesSectionKey`。
   - `localExamplesMissing` 与 `l10n.examples` 两条断言原样保留，于是仍然证明「找不到示例时显示缺失提示」。
   - 测试标题改为「…四个 Tab 切换，教程页内切示例代码」。
2. **`home_navigation_test.dart`**
   - 「only the home tab shows the product name」：循环 `[1,2,3,4]` → `[1,2,3]`（少了被删的第 4 页）。
   - 「each tab has its own title」：`find.text('示例代码')` 由 `findsWidgets` 改为 `findsNothing`
     （这正符合 A5：应用内不再有独立示例代码页入口）。其余四条标签断言原样。
   - 「the profile tab is reachable」：`_selectTab(4)` → `_selectTab(3)`。**断言对象没变**，仍是「最后一页是 `ProfileTab`」。
   - 助手 `_selectTab` 的 `findsNWidgets(5)` → `findsNWidgets(4)`。
3. **`home_content_repository_test.dart`**
   - 原来分别取 `LocalTutorialsTab.repository` 和 `ExampleCodeTab.repository` 断言「同一个仓库」，
     改为取唯一一个 `TutorialCenterPage.repository`，并在页内切段后再断言一次 `calls == 1`。
     「内容工厂只调用一次、且是懒惰的」这条原有含义完整保留。
4. **`content_idle_frames_test.dart`**
   - `_selectTab(tester, 3)`（示例页）改为新增的 `_selectExamplesSection`：先到下标 2，再点示例段标签。
   - `find.byType(LocalTutorialsTab, skipOffstage: false)` 改为 `find.byType(TutorialCenterPage, ...)`，
     用来断言「合并页仍在树里且教程段还在加载」——含义不变。
   - 从示例详情返回后，`_selectTab(2)` 改为 `_selectSection(TutorialCenterPage.tutorialSectionKey)`。
   - 助手 `_selectTab` 的 `findsNWidgets(5)` → `findsNWidgets(4)`。
   - 「空转帧」与「加载中有动画」的所有断言原样保留并全部通过。
5. **`content_code_import_test.dart`**
   - 只有助手 `_homeDetail` 变了：原来按导航标签 `l10n.examples` 点第 3 页，
     现在点 `l10n.tutorial`，再点示例段标签。两条 Home 级导入/保存用例的断言全部原样。
   - 单页挂载 `ExampleCodeTab` 的用例（`_catalog`、不可读已保存示例等）**未改**。
6. **`retained_editor_test.dart`**
   - 两处 `_tab(tester, Icons.code_outlined)` 改为新增的 `_examplesSection(tester)`。
   - 帮助函数 `_examplesSection` 的注释写明了为什么：外壳不再提供示例目的地。

### 主程序

7. **`studio_home_release_test.dart`**
   - 「production Home opens bundled local tutorials and examples…」：
     页面类型 `LocalTutorialsTab` / `ExampleCodeTab` → `TutorialCenterPage`；示例部分改为页内切段。
     另外**新增**一条断言：顶栏标题是 `l10n.tutorial`（直接对应 R6「顶栏标题就教程就好」）。
     原有的「无发布按钮 / 无 `Icons.add` / `centerTitle == false` / `actions == null`」原样保留。
   - 「main content factory stays lazy and runs once…」：仓库注入断言改指向合并页，`factoryCalls` 断言原样。
   - `_selectPage` 的 `findsNWidgets(5)` → `findsNWidgets(4)`。
   - **新增**用例「the shell offers no separate example-code entry」（5 条断言，见第 4 节表格）。

## 7. 代码实现要点

### 7.1 合并页结构

```
AppBar            标题「教程」（titleLarge + colorScheme.primary，左对齐，无动作）
TabBar            恒单行横向滚动：「教程」/「示例代码」
Expanded          当前栏目的内容
  ├ 教程段   FutureBuilder<Tutorial?>  → _TutorialList
  └ 示例代码 FutureBuilder<_ExampleCatalog> → _ExampleCodeList
       两者的列表第 0 项仍是 _ContentFilterBar（搜索框 + 语言栏 + 难度栏 + 统计/重置）
```

- 每个栏目保持「筛选栏是列表第 0 项」的既有结构，所以 `local_content_lazy_catalog_test.dart` 里
  `estimatedChildCount == 103 / 101` 这类断言不用改。
- 两段各自 `FutureBuilder`，一段慢不阻塞另一段，也不阻塞页内的栏目切换。
- 共用筛选状态 `_ContentFilterSelection`（语言 / 难度 / 搜索词）由页面持有，
  下传给 `_TutorialList` / `_ExampleCodeList`（新参数 `selection`，可为空）。
  为空时列表自己持有并 dispose 自己的状态 → 旧页面的行为与生命周期一字不变。

### 7.2 单行芯片栏

`_ContentFilterBar` 的三处 `Wrap` 换成不折行的容器：

- 语言栏与难度栏 → 新的 `_SingleLineChipRow`：
  `SingleChildScrollView(scrollDirection: Axis.horizontal)` 包一个 `Row`，芯片间距 8。
  外层容器原本就是 `Padding > Column`（`git show 573d1b6` 可核对），不需要动。
- 统计行（结果文案 + 重置按钮）→ `Row`：结果为 `Expanded`，重置在右。

键名（`content-language-*`、`content-level-*`、`content-reset`、`content-no-results`）、
筛选语义、结果文案全部不变。窄屏不会溢出（`content_code_import_test.dart` 的
320dp + 2x 字体现有用例仍通过）。

### 7.3 示例加载提炼

新私有函数 `_loadExampleCatalog({repository, language, store})` 返回
`_ExampleCatalog(items, savedUnavailable)`，把原先写在 `_ExampleCodeTabState._loadExamples`
里的全部规则搬出来：随包目录 → 本地已保存覆盖 → `ExampleCodeStore.load`（`FileSystemException`
时标记提示） → 产品过滤 → 主 App「language 等于产品 id 时返回全域」特例。

`ExampleCodeTab` 和 `TutorialCenterPage` 都调它，避免两套过滤规则再次漂移。

### 7.4 与「大脑的解释」不一致、需要大脑确认的地方

1. **切换栏目时难度重置为「全部」**。语言和搜索词保留（R6 明确要求语言保留）。
   理由：难度选项按当前栏目的数据计算，沿用上一栏目的 `advanced` 很可能把另一栏目直接筛成空列表。
   如果大脑要求难度也保留，改一行即可（`_selectSection` 里的 `_filter.level = null`）。
2. **共用的是「选择」和「这一条栏」，不是两个集合的并集**。芯片选项仍按当前栏目的数据去重，
   因此切到某一栏目时，另一栏目独有的语言可能暂时不在栏上。
   `prd.md` 只要求「共用一条语言栏」，这是最贴近原话、也最不容易出现「选了却全空」的做法。
3. **联网档位（`offlineOnly == false` 且无本地内容源）仍走社区 `TutorialsTab`**。
   R6 说的是「教程页和示例代码页」，指的是本地内容页；把社区教程塞进合并页会超出需求，
   而且 `TutorialsTab` 没有语言栏。该档位下示例代码入口按 A5 删除。

## 8. 第二轮：合入 Pi A 与折叠搜索

智者 Gate 1 回复要求两件事，均已完成。

### 8.1 `git merge ui/pi-a`

共两次合入，**都没有冲突**：

| 合入 | 包含的 A 侧提交 | 结果 |
|---|---|---|
| `811f147` | `a2758b2` 可拖动页签、`68ce22b` FAB 跟随页签并去掉云端菜单项、`8290900` 折叠搜索共享、`05ab270` 语言徽标胶囊 | 自动合并，两边行为共存 |
| `b0e7f52` | `51b894a` 启动时应用已保存的页签顺序、`9a363f0` 默认页签顺序 | 自动合并，行为共存 |

无冲突的原因：A 改的是首页（`_HomeTabState` 的页签栏、FAB、搜索栏、溢出菜单），
我改的是外壳目的地表与教程页（`_createPageView`、`TutorialCenterPage`）。两边改动区域不重叠。
合并后同时保留：

- A 的：可拖动页签（`_buildScopeTabBar` + `_dropScopeTab`）、FAB 按当前页签创建（`_createFromCurrentScope`）、
  折叠搜索（`CollapsedSearchField` / `CollapsedSearchButton` / `collapsedSearchToolbarHeight`）、
  溢出菜单去掉「新建云端项目」、语言徽标胶囊、默认页签顺序。
- 我的：4 个导航目的地、合并后的教程页。

### 8.2 教程页改用 Pi A 的折叠搜索

`TutorialCenterPage` 的 AppBar 现在是首页那一套：

| 状态 | 顶栏 |
|---|---|
| 折叠（默认） | 标题「教程」靠左 + 右侧一个 `CollapsedSearchButton`（放大镜） |
| 展开 | 左侧返回箭头（`l10n.exitSearch`）+ `CollapsedSearchField` 占标题位，无其它动作 |

具体行为：

- 展开时 `toolbarHeight` 用 `collapsedSearchToolbarHeight(context)`，和首页同一个算法，大字体不会溢出。
- 折叠即清空搜索词（`_closeSearch` 把 `_filter.query` 清空），和首页一致；语言芯片不动。
- 筛选栏不再画自己的输入框（新增参数 `searchInToolbar`，合并页固定传 `true`），
  全页只有一个搜索框。旧页面 `LocalTutorialsTab` / `ExampleCodeTab` 不传，行为不变。
- 搜索词与语言选择仍由两段共用：切栏目后搜索词保留，示例段照样被过滤。
- 语言芯片栏仍是单行横向滚动，不受顶栏高度变化影响。

新增本地化键 `StudioLocalizations.searchContent`（三种语言）：`搜索标题、简介或知识点` /
`搜尋標題、簡介或知識點` / `Search titles, summaries or concepts`。
沿用 `clear`（按钮提示）和 `exitSearch`（返回按钮提示），不新增第二套文案。

### 8.3 保留的旧测试键

| 键 | 处理 |
|---|---|
| `content-query` | **保留**，现在挂在顶栏的 `CollapsedSearchField.fieldKey` 上（原来是筛选栏里 `TextField` 的键）。直接找这个键改文字的旧测试（`local_content_filters_test.dart`）一字未改、照样通过 |
| `content-language-row` / `content-language-*` / `content-level-*` / `content-reset` / `content-no-results` | 全部未动 |
| `home-project-search-field` | 未动（首页自己的） |

### 8.4 本轮调整的测试（新增 3 个、最小调整 2 个）

**新增（`test/tutorial_center_page_test.dart`）**

1. `the search collapses to an icon like Home`：折叠时只有 `CollapsedSearchButton`、没有任何 `TextField`；
   展开后 `CollapsedSearchField` 在 AppBar 矩形内、标题让位、语言栏还在；输入能过滤。
2. `collapsing the search clears the query`：输入 `java` 后按返回箭头，输入框消失、搜索词清空，
   语言芯片仍选中；再次展开时输入框是空的（与首页相同）。
3. `the search and the section switch share one query`：在教程段输入 `C++`，切到示例段后被同样过滤，
   输入框里的文字仍是 `C++`。

**调整（都是最小改动，没有放宽断言）**

4. **`qflistudio/test/studio_home_release_test.dart`「the networked main App Home keeps the cloud scope and its creation entry」**
   - 原因：A 的 `68ce22b` 把「新建云端项目」从溢出菜单移到了 FAB。旧断言找菜单文字，合并后必然失败。
   - 改法：先点「云端项目」页签，再点 `FloatingActionButton`，再断言 `l10n.newCloudProject` 出现。
     「云端页签存在」和「有创建入口」两条含义都保留；用的正是 A 自己在 `home_fab_scope_test.dart` 里定的路径。
5. **同文件「production Home opens bundled local tutorials and examples without publishing controls」**
   - 原因：教程页顶栏现在有折叠搜索动作，`header.actions` 不再是 `null`。
   - 改法：把 `expect(header.actions, isNull)` 换成更强的断言：动作区只有一个 `CollapsedSearchButton`，
     且整页没有 `FloatingActionButton`。「没有发布动作」的原意保留。

其余旧测试（内核 6 个文件 + 主程序 1 个文件）**本轮零改动**，因为 `content-query` 键保留。

### 8.5 本轮验证

```
内核 flutter analyze  → No issues found!
内核 flutter test     → +1416 ~9 -1（唯一失败仍是 interop_arkts_contract_test.dart 加载期缺件）
主程序 flutter analyze → No issues found!
主程序 flutter test    → +9 All tests passed!
```

## 9. 第二部分：netrix 第 3 批（ADV 组，19 个工具）

**状态：未开始 — 契约文件在 120 分钟内没有出现。**

已做的事：

1. 确认清单已按 Gate 1 裁定更新。`research/netrix-tools-inventory.md`（2026-11-17 01:22）
   第 7.3 节现在写的是**第 3 批 = `ADV` 组 19 个工具**：`url-parser`、`http-status`、`port-reference`、
   `headers-parser`、`curl-builder`、`reverse-dns`、`dns-name`、`query-parser`、`query-builder`、
   `http-content-type`、`http-cache-control`、`http-date`、`basic-auth`、`timestamp-converter`、
   `port-range`、`cookie-parser`、`url-join`、`http-method`、`dns-label`。与 Gate 1 派单一致。
2. 按派单轮询 `research/tools-port-contract.md`：从 `2026-11-17 01:43:58` 到 `03:40:59`，
   每 180 秒一次，共 **40 次**，**全部不存在**。轮询窗口已满 120 分钟，按规则结束本轮。
3. 因此没有可 `git merge` 的骨架提交基哈希，也没有可依的注册文件路径、类型名、错误键位置和
   可见性标记。**本部分一个工具都没移植。**

没有先自己定一套契约就开工的原因：`implement.md` 第 9 步把它定为硬前置，而契约决定的是
**三个 Pi 共用的**注册表结构、类型名和 i18n 位置。自行发明会导致：

- 第 1、2 批（Pi C / Pi D）的类型与我的不同，总注册表拼接时对不上。
- 三个 Pi 改同一个文件，违反「每批用自己的注册文件」。
- 已提交的错误键位置与契约不一致时，返工面覆盖 19 个工具。

契约到位后可直接接续的工作量（已勘察，不需要再确认）：

- ADV 的工具逻辑全在 `advanced_service.dart`，**纯本地字符串 / 表格处理，零网络、零平台能力**，
  比第 2 批简单：无 `http`、无 `dart:io`、无新增依赖。
- 两个疑似重复（`url-parser`、`timestamp-converter`）与 `research/tools-duplicates.md`：
  该文件本轮同样不存在。按派单的兜底规则（「否则合并进现有工具，只留一个，并写进报告」）执行；
  融合时保留现有 `TimestampToolPage` 的本地双向往返能力，补上 netrix 的 UTC 单向输出，
  并沿用未注册的 `UrlParserToolPage` 作为 `url-parser` 的实现页面，不再建第二个。
- 与第 2 批共用辅助函数：`lib/tools/netrix/batch2/` 下的地址与网络服务只覆盖 ADDR / NET，
  ADV 组用不到它们，因此不存在重复移植风险；`http-status` / `port-reference` 这类离线参考表需要在
  ADV 自己的服务文件里放，避免与第 2 批的端口校验函数重复。

**结论**：第 3 批**未完成**，阻塞原因是契约缺失，不是技术问题。请下一个派单附上
`research/tools-port-contract.md`（含骨架提交哈希），我从 `git merge` 一步开始。

## 10. 未完成项与风险

| 项 | 状态 | 说明 |
|---|---|---|
| `interop_arkts_contract_test.dart` 在 `ui-b` 与 `ui-int` 都失败 | 既存问题，未处理 | 兄弟目录 `qfli_java` 缺 ArkTS 源码。不是本次改动造成（基线同命令同样失败）。集成时要让大脑决定：补 `qfli_java` 检出，或让该测试在缺件时跳过 |
| 教程页改用 Pi A 的折叠搜索组件 | **已完成** | 见第 8.2 节，新增 3 个用例 |
| netrix 第 3 批（ADV 19 个） | **未开始** | 契约文件 120 分钟内未出现，见第 9 节 |
| 触摸/滚动手感未经真机验证 | 未做 | 只有组件测试（宽 360 / 1000 两种宽度 + `maxScrollExtent` 断言）。真机全流程在父任务阶段 3 由指定 Pi 截图确认 |
| 合并页两段同时加载 | 已评估 | 合并页只**创建**当前栏目的 `FutureBuilder`，另一段在第一次切过去时才请求。主 App 的 `StudioContentRepository` 内部用 `_catalogFuture` 复用同一份解析，`load()` 只跑一次。教程适配器为了给缺少输入夹具的课时配对，会额外调一次 `examples()`，这是 `local_content_adapter.dart` 里本来就有的行为，不是本次新增开销 |
| `research/pi-b-design` 的「Pi 补充」写在子任务 `design.md` | 已写 | 第 1–6 节：仓库/文件、两条栏的现状、共用栏策略、合并页结构与状态、每个入口的处理、受影响的旧测试 |
| 主程序 `pub get` 生成的原生注册文件被改动 | 未提交 | `linux/`、`macos/`、`windows/` 下 `generated_plugin_registrant.*` 因本地插件解析而变动，与本次无关，留在工作区未暂存 |
