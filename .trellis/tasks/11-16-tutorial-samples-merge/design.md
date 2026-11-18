# 设计（Pi B）

## 大脑给定的边界

- 归属：教程页、示例代码页、它们的入口（导航项、菜单项、路由）。
- 页面结构（大脑的解释，见父任务 `prd.md` A4、A5）：
  - 顶栏：标题「教程」，搜索保持现状。
  - 第一行：语言栏。单行，横向滚动。教程和示例代码共用。
  - 第二行：教程与示例代码的切换。单行。
  - 内容区：当前语言下的教程列表，或者示例代码列表。
- 你读代码后认为另一种结构更符合用户原话时，可以采用。条件：每条栏都是单行，语言栏共用，标题是「教程」。把理由写进报告。
- 用户原话：「教程页和示例代码页合并 标签栏共用 并且横向单行放置 不要现在一个语言chip栏就给屏幕铺满了 就是示例代码和教程两页共用在一页 顶栏标题就教程就好」。
- 示例代码页的业务逻辑搬进合并页时复用原有组件。不重写业务逻辑。
- 第 3 批工具：按 Pi C 的契约做。先 `git merge` 契约里写的骨架提交。

## Pi 补充（改代码前填写）

### 1. 两个页面在哪个仓库、哪些文件

- 页面本体两个都在内核 `qfli_studio_core`：`lib/pages/local_content_pages.dart`。
  - `LocalTutorialsTab`（教程，离线/本地内容档位）；`ExampleCodeTab`（示例代码）。
  - 数据：`LocalContentAdapter` + `ContentRepository`（产品用 `contentRepositoryFactory` 注入；主 App 用 `qflistudio/lib/content/studio_content_repository.dart`）。
  - 详情页 `_LessonPage`、`ExampleDetailPage` 不合并，继续用。
- 外壳（底部导航、页面下标）也在内核：`lib/pages/home_page.dart` 的 `_HomePageState`。
  主 App `qflistudio/lib/main.dart` 只提供档位和内容仓库，没有页面代码。
- 因此合并只改内核；主程序仓库只改测试。

### 2. 两条语言栏现在各自怎么实现，语言集合是否相同

- 两条都是同一个私有组件 `_ContentFilterBar` 里的 `Wrap`：`ChoiceChip` + 键
  `content-language-all` / `content-language-<key>`；教程用 `lessonCount`，示例用
  `examplesCount`。`Wrap` 会换行，正是 R6 要修的「铺满屏幕」。
- 语言集合不同：教程的选项来自课时（`lesson.type` / `lesson.language`），示例的选项来自示例条目。
  同一语言两边通常都有，但两边各自去重，顺序也不同。
- 难度栏同理（`content-level-*`），教程按课时难度，示例按示例难度。

### 3. 语言集合不同时共用栏怎么处理

- 共用一份选择状态 `_ContentFilterSelection`（语言、难度、搜索词）。
  栏目切换时语言和搜索词保留；难度回到「全部」——难度选项按当前栏目计算，
  沿用上一栏目的难度可能把新栏目筛成空列表。R6 只要求语言保留。
- 芯片选项仍按当前栏目的数据计算（沿用现有逻辑），所以共用的是「选择」和「这一条栏」，
  不是两个集合的并集。

### 4. 合并页的结构和状态

新增 `TutorialCenterPage`（同一文件，私有组件可复用，不新增公开 API）：

- AppBar：标题「教程」（`titleLarge` + `colorScheme.primary`，与其它主页面栏一致），无动作按钮。
- 第二行：栏目标签栏 `TabBar(isScrollable: true)`，两项「教程」「示例代码」，恒为单行、可横向滚动。
  这一行不放进 FutureBuilder，加载中也能切换。
- 内容区（按当前栏目）：教程 → `_TutorialList`；示例代码 → `_ExampleCodeList`。
  两者继续把 `_ContentFilterBar` 作为列表第 0 项（保持现有滚动行为与旧测试的
  `estimatedChildCount`），只接受注入的共用选择状态。
- 每段各自加载：教程 `LocalContentAdapter.loadTutorial`，示例走提炼出的
  `_loadExampleCatalog`（含 `ExampleCodeStore.load`、产品过滤、主 App 全域特例）。
  一段加载慢不阻塞另一段。
- `_ContentFilterBar` 的语言栏和难度栏由 `Wrap` 改成新的 `_SingleLineChipRow`
  （横向 `SingleChildScrollView` + `Row`）；统计行改成 `Row`，重置按钮仍用
  `content-reset` 键。键名、筛选语义、结果文案全部不变，旧页面自动获得单行语言栏。
- 旧页面的 `LocalTutorialsTab` / `ExampleCodeTab` 公开 API、标题、行为保持不变
  （它们的页面级测试继续通过），只是内部改用了提炼后的加载函数和单行芯片栏。
  「示例代码」独立页在应用内不再可达，但组件本身不删——避免删除旧测试。

### 5. 每个原入口的处理

| 入口 | 处理 |
|---|---|
| 底部导航「示例代码」（下标 3，`Icons.code_outlined`） | 删除。导航变成 4 项：首页 / 工具 / 教程 / 我的 |
| 底部导航「教程」（下标 2） | 指向合并页；它是两段内容的唯一入口 |
| 无本地内容源的联网档位（`offlineOnly == false` 且无 `contentRepositoryFactory`） | 下标 2 仍是社区 `TutorialsTab`；示例代码入口随导航项一起删除（R6 允许删除） |
| 详情页（课时、示例） | 不变；仍从合并页内打开 |
| 其它 | 全仓库检索 `ExampleCodeTab`：只有测试引用，没有别的菜单、路由或深链 |

### 6. 受影响的旧测试（都要改，逐个在报告里说明）

页面级旧测试（挂 `LocalTutorialsTab` / `ExampleCodeTab`）不改，继续通过。
只有「走外壳、按导航下标/图标进示例代码」的测试必须改：

内核：`widget_test.dart`、`home_navigation_test.dart`、`home_content_repository_test.dart`、
`content_idle_frames_test.dart`、`content_code_import_test.dart`、`retained_editor_test.dart`。
主程序：`studio_home_release_test.dart`。

新增（不改旧断言）：内核 `test/tutorial_center_page_test.dart` 覆盖合并页验收，
主程序 `studio_home_release_test.dart` 增补「外壳没有独立示例代码入口」一项。
