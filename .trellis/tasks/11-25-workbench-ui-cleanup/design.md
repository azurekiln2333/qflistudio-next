# 设计：大屏工作台界面整改

## 1. 原则

- 一个动作只有一个可见入口。快捷键与菜单项不算重复入口。
- 外壳（图标栏、侧栏、中央区）归 `LargeScreenWorkbench` 所有。
- 编辑器在大屏里只画编辑相关内容，不再画自己的导航。
- 判断大屏模式只用一个条件：`LargeScreenScope.maybeOf(context) != null`。
  编辑器里即 `_largeScreen != null`。不按窗口宽度判断。
- 手机分支一行不改。手机测试断言不改。

## 2. 基线与分支

- Core 基线：`wsui/base`，基于 GitHub main `ee83f1c`。
- 基线已含契约提交：
  - `3fe4a96` `SettingsStore.largeScreenSymbolBar`、`setLargeScreenSymbolBar`、
    `uiScale`、`setUiScale`、`minUiScale`、`maxUiScale`。
  - `6e22b5b` `LargeScreenController.centerOverlay`、`showCenterOverlay`、
    `closeCenterOverlay`，以及 `lib/shell/shortcut_label.dart` 的 `shortcutLabel`。
- 每个 Pi 一个 worktree：`D:/MyNewProjects/_wt/wsui/pi-{a,b,c,d}/qfli_studio_core`，
  分支 `wsui/pi-{a,b,c,d}`。
- 只改 Core。App 仓库不动。

## 3. 文件归属

同一文件只归一个 Pi。确需改别人的文件时，写进交付报告，由集成方合并。

| Pi | 范围 | 独占文件 |
| --- | --- | --- |
| A | 外壳、资源管理器、工作台快捷键、中央浮层渲染 | `lib/shell/large_screen_workbench.dart`、`lib/shell/large_screen_controller.dart`、`lib/shell/workbench_chrome.dart`、新建 `lib/shell/workbench_explorer.dart`、`lib/pages/home_page.dart`（只限大屏嵌入的项目点击） |
| B | 编辑器大屏模式、编辑器快捷键 | `lib/editor/editor_page.dart`、`lib/editor/editor_quick_bar.dart`、`lib/editor/symbols_bar.dart`、`lib/editor/agent/*.dart` |
| C | Agents 会话直开 | `lib/harness/ui/agents_entry.dart`、`lib/harness/ui/home_agents_tab.dart`、新建 `lib/shell/workbench_session_view.dart`、`lib/store/project_store.dart`（只在缺少目录登记入口时） |
| D | 界面缩放、全局快捷键、设置页 | 新建 `lib/shell/ui_zoom.dart`、`lib/app.dart`、`lib/pages/settings_page.dart` |

测试文件按同样范围新建，文件名以所测模块命名。

## 4. Pi A：外壳与资源管理器

### 4.1 图标栏

`WorkbenchActivity` 改为：`explorer, agents, tools, tutorial, settings, profile`。
删除 `projects` 与 `files`。顶部主入口为 `explorer`、`agents`。
重复点击当前入口时显示或收起侧栏（沿用现有 toggle 语义）。

### 4.2 资源管理器

侧栏里一个横向两页的容器：第 0 页项目列表，第 1 页文件树。
- 切页用 200ms 横向滑动动画。两页都保留状态（Offstage 规则沿用 `_retain`）。
- 控制器新增 `ExplorerPage { projects, files }`、`explorerPage`、
  `showProjects()`、`showFiles()`。
- 文件树页顶部一行：返回按钮（`←`，提示"项目列表"）+ 当前项目名。
  返回只切页，不关编辑器。
- 没有打开的项目时，第 1 页不可达；返回按钮之外不再显示"先打开一个项目"。
- 项目列表里标出已打开的项目和当前项目。

### 4.3 项目点击

- 点项目：`editors.open(...)`，然后 `showFiles()`，并清掉中央浮层。
- 点已打开的项目：切到该会话键，然后 `showFiles()`。
- 先查清"打开项目后点项目列表没反应"的原因，写进报告。
  修复必须覆盖：编辑器已可见时点同一个项目、点另一个项目。

### 4.4 中央浮层

`_center()` 在 `centerOverlay != null` 时显示浮层，编辑器宿主用 `_retain` 藏到后台。
打开项目、`editors` 变为可见时调用 `closeCenterOverlay()`。

### 4.5 工作台快捷键

在工作台根部用 `Shortcuts` + `Actions` 接下表。macOS 用 meta 代替 control。

| 键 | 动作 |
| --- | --- |
| Ctrl+B | 显示或收起侧栏 |
| Ctrl+Shift+E | 选 `explorer` |
| Ctrl+Shift+A | 选 `agents` |
| Ctrl+, | 选 `settings` |

图标栏 tooltip 用 `shortcutLabel` 带上快捷键。

## 5. Pi B：编辑器大屏模式

以下改动只在 `_largeScreen != null` 时生效。

- 不画快捷栏 `EditorQuickBar`。`_quickBarFallbackActions` 不再往"更多"菜单塞动作。
- 快捷栏动作的去处：
  - 撤销、保存、查找、跳行、格式化：顶栏"更多"菜单 + 已有快捷键。
  - 终端、输出、问题、调试、端口：状态栏右侧的面板按钮。
  - Git、云端拉取、在线终端：顶栏"更多"菜单。
  - 设置：删除。图标栏已有设置。
  - AI：删除。顶栏 `AgentEntryButton` 是唯一入口。
  - 关闭编辑器：顶栏"更多"菜单。
- 符号栏只在 `settings.largeScreenSymbolBar == true` 时显示。监听 settings 变化。
- 顶栏不画"打开文件树"按钮、"暂时收起编辑器"按钮。
- `_workbenchFiles` 只给文件树，不画"文件 | 会话"切换。会话列表在图标栏 Agents。
- 宽屏 Agent 栏收起时宽度为 0，不画 `AgentDockRail`。
- 中宽（720–1100）仍用 `AgentPaneSwitcher` 在编辑器与 Agent 之间切换。

### 5.1 编辑器快捷键

加入 `build` 里已有的 `Shortcuts` 映射。macOS 同时接 meta。

| 键 | 动作 |
| --- | --- |
| Ctrl+` | 显示或收起终端 |
| Ctrl+J | 显示或收起底部面板（回到上次的面板，默认终端） |
| Ctrl+L | 显示或收起 Agent 栏 |
| Ctrl+W | 关闭当前文件标签 |
| Ctrl+Tab / Ctrl+Shift+Tab | 下一个 / 上一个文件标签 |
| Ctrl+N | 新建文件 |
| F5 | 运行 |

- 焦点在终端输入里时，Ctrl+W、Ctrl+J、Ctrl+L 不拦截。
- 这些快捷键在手机上同样注册。手机界面不画新按钮。
- 相关按钮的 tooltip 用 `shortcutLabel` 带上快捷键。

## 6. Pi C：Agents 会话直开

`resolveSessionProject` 与 `openAgentSession` 的新流程：

1. 会话目录对应已登记的本地项目：打开该项目，右侧显示会话（不变）。
2. 桌面本机会话，目录存在但未登记：用现有"添加已有目录"的登记入口登记，
   再按第 1 步打开。不复制、不移动目录。
3. 远程或内置会话：沿用占位项目流程（不变）。
4. 以上都拿不到项目时：
   - 大屏：`LargeScreenScope.maybeOf(context)?.showCenterOverlay(...)`，
     内容为 `WorkbenchSessionView`。
   - 手机：保持现有行为。
5. 删除"先打开一个项目 / Agents 面板在编辑器里"弹窗（大屏不可达）。
6. 删除"本机会话目录对不上时随便挑一个本地项目"的分支 `_pickLocalProject`。
   会话不得落到别的项目目录。

`WorkbenchSessionView`（`lib/shell/workbench_session_view.dart`）：

```dart
class WorkbenchSessionView extends StatefulWidget {
  const WorkbenchSessionView({
    super.key,
    required this.row,
    required this.hub,
    required this.onClose,
  });
  final AgentsIndexRow row;
  final HarnessHub hub;
  final VoidCallback onClose;
}
```

- 顶部一行：会话标题、宿主名、关闭按钮。
- 主体：`HubChatView`，句柄从 `hub` 取。取不到时显示原因和重试按钮。

## 7. Pi D：界面缩放与设置页

### 7.1 `UiZoom`

`lib/shell/ui_zoom.dart`，包在 `MaterialApp.builder` 的最外层，覆盖所有路由和对话框。

- 读 `settings.uiScale`，监听变化。
- 整体缩放，不是只放大文字：
  `MediaQuery.size`、`padding`、`viewPadding`、`viewInsets` 除以倍数，
  子树在缩小后的尺寸里布局，再用 `Transform.scale`（左上角对齐）放大。
- 倍数为 1.0 时不插入 Transform，避免多余合成层。
- 点击、拖动、文本选择在缩放后位置正确。

### 7.2 全局快捷键

挂在 `UiZoom` 上：

| 键 | 动作 |
| --- | --- |
| Ctrl+= / Ctrl++ / Ctrl+NumpadAdd | `setUiScale(uiScale + 0.1)` |
| Ctrl+- / Ctrl+NumpadSubtract | `setUiScale(uiScale - 0.1)` |
| Ctrl+0 / Ctrl+Numpad0 | `setUiScale(1.0)` |
| Ctrl+鼠标滚轮（仅桌面） | 每格 ±0.1 |

- 缩放后用 SnackBar 或轻提示显示当前百分比 1 秒。
- 焦点在编辑器里时，这些键也要生效。编辑器不得吞掉它们。

### 7.3 设置页

- "界面缩放"：显示百分比，带 `-` `+` 和"复原"按钮。
- "大屏显示符号栏"：开关，读写 `largeScreenSymbolBar`。仅大屏显示此项。
- "快捷键"：只读列表，列出 PRD 快捷键表。

## 8. 兼容与回滚

- 设置文件新增两个键。旧版本读到会忽略。
- 每个 Pi 分支可单独回退。基线契约提交不影响旧界面。

## 9. 测试要求

- 新测试与改动同分支提交。现有测试不改断言。
- 测试由云端 CI 执行。本机不跑测试、不构建、不开模拟器。
- 本机允许：`flutter pub get`、`dart format`、`flutter analyze <改动文件>`。

## 10. 第二阶段：MD3 视觉整改

### 10.1 审查结论（照搬手机的地方）

| # | 现状 | 证据 | 问题 |
| --- | --- | --- | --- |
| V1 | 大屏主题固定 `VisualDensity.standard` 与 `MaterialTapTargetSize.padded` | `lib/shell/workbench_theme.dart:7` | PC 上每行、每个按钮都按手指尺寸放大 |
| V2 | 图标栏 52dp、20dp 图标、2px 竖线选中标记 | `lib/shell/workbench_chrome.dart` `_RailButton` | 不是 MD3 导航栏，也无文字标签 |
| V3 | 项目侧栏直接嵌手机首页：大号主色标题、折叠搜索、分类标签页 | `lib/pages/home_page.dart:654` | 手机页面塞进 300dp 侧栏 |
| V4 | 文件树外包 12dp 外边距、12dp 圆角描边卡片 | `lib/editor/file_explorer.dart:1408`、`editor_page.dart:297` | 侧栏像手机卡片，不像 PC 面板 |
| V5 | 编辑器顶栏 56dp 双行标题，下方再叠 44dp 标签栏 | `editor_page.dart:3438`、`:4720` | 垂直空间浪费约 60dp |
| V6 | "更多"菜单项高 44dp，不显示快捷键 | `PopupMenuButton` 多处 | 手机菜单；PC 菜单应紧凑并显示快捷键 |
| V7 | 侧栏 300dp、Agent 栏 400dp 固定宽度 | `lib/layout/breakpoints.dart` | PC 用户无法拖动调整宽度 |
| V8 | 附件选择、分享接收用底部弹层 | `lib/chat/attachment_picker.dart:156`、`lib/share/share_intake_sheet.dart:40` | 大屏上底部弹层是手机交互 |
| V9 | 编辑器空状态是 64dp 灰图标加一句话 | `editor_page.dart` `_buildEditorArea` | PC 空状态应给出入口与快捷键 |
| V10 | 设置、个人、工具、教程整页放在中央，内容按手机单列拉宽 | `lib/pages/settings_page.dart:269` 等 | 未用 MD3 大屏规范布局 |
| V11 | SnackBar 未针对大屏配置 | 无 `snackBarTheme` | 横跨整个窗口底部 |

### 10.2 统一规则

- 依据 MD3。桌面在 MD3 之上按 IDE 习惯压缩密度。
- 桌面（`AppFormFactor.desktop`）：`VisualDensity.compact`、`MaterialTapTargetSize.shrinkWrap`。
- 平板（`AppFormFactor.tablet`）：保持 `standard` 与 `padded`，触控优先。
- 颜色只用 `ColorScheme` 角色，不写死色值。浅色与深色都要正确。
- 悬停、按下、聚焦用 MD3 状态层（hover 8%、pressed 10%、focus 10% + 焦点环）。
- 可点击的自绘控件设 `SystemMouseCursors.click`。拖动分隔条设 `resizeColumn`。
- 菜单项、按钮提示文字带快捷键（`shortcutLabel`）。

### 10.3 分工（文件归属同第 3 节，新增项写在括号里）

**Pi A：外壳**
- V1：`WorkbenchTheme.from(base, formFactor)` 按 10.2 区分桌面与平板。
  同时配置 `menuTheme`、`tooltipTheme`（等待 500ms）、
  `snackBarTheme`（floating，宽 ≤ 480dp）。
- V2：改用 MD3 `NavigationRail`。宽 80dp，24dp 图标，
  胶囊选中指示器（`secondaryContainer`），图标下方显示 `labelMedium` 文字。
  设置与头像留在底部。
- V3：资源管理器项目页重做成 PC 面板：
  40dp 标题行（`titleSmall`"项目"+ 图标按钮：新建、打开文件夹、克隆、更多），
  常驻搜索框（36dp，`surfaceContainerHigh` 底色），
  紧凑列表行（桌面 32dp，平板 48dp），当前项目用 `secondaryContainer` 底色。
  不再嵌入手机首页的 AppBar 与分类标签页；分类改为搜索框旁的筛选菜单。
- V7：侧栏右缘加可拖动分隔条。范围 220–480dp，双击复原 300dp。宽度存在控制器里。
- V9 外壳部分：没有打开项目时的欢迎页，按 MD3 改成两栏：
  左栏"开始"（新建项目、打开文件夹、克隆仓库，各带快捷键），右栏"最近项目"列表。
- V11：SnackBar 落在中央区域底部居中。

**Pi B：编辑器**
- V5：大屏编辑器去掉 56dp AppBar。改成一行 40dp 编辑器标题栏：
  左侧文件标签，右侧运行、Agent 开关、"更多"。项目名只在资源管理器显示。
  标签 36dp：当前标签 `surface` 底色 + 2dp `primary` 下划线，其余 `surfaceContainer`。
  关闭按钮在悬停或当前标签上显示。未保存显示圆点，悬停时圆点变成关闭按钮。
  选区工具栏（`SelectionToolbarScope`）在大屏改为浮在选区附近，或并入右键菜单。
  手机保持原 AppBar。
- V4：大屏文件树去掉卡片外边距、圆角和描边，平铺在 `surfaceContainerLow` 面板上。
  桌面行高 28dp，平板 40dp。当前文件用 `secondaryContainer` 底色。
  （新增归属：`lib/editor/file_explorer.dart`）
- V6：大屏"更多"菜单与标签右键菜单改用 `MenuAnchor` + `MenuItemButton`，
  用 `shortcut:` 显示快捷键。分组之间用分隔线。
- V7：Agent 栏左缘加可拖动分隔条。范围 320–720dp，双击复原 400dp。
- V9：编辑器空状态改为快捷键提示列表（新建文件、打开资源管理器、Agent、终端）。
- 状态栏桌面 24dp。左侧：分支、问题数；右侧：面板按钮、光标位置、编码、语言。

**Pi C：Agents**
- Agents 侧栏列表按 Pi A 的 V3 规则：40dp 标题行、常驻搜索框、紧凑行、宿主分组标题用 `labelMedium`。
- `WorkbenchSessionView` 标题栏 40dp，与编辑器标题栏同高同色。
- V8：大屏上附件选择改为 `MenuAnchor` 菜单，分享接收改为居中对话框（宽 ≤ 560dp）。
  手机保持底部弹层。（新增归属：`lib/chat/attachment_picker.dart`、`lib/share/share_intake_sheet.dart`）

**Pi D：工具页面**
- V10 设置：大屏用 MD3 列表-详情布局。左栏分类列表（240dp），右栏该分类的设置项，内容宽 ≤ 720dp。
- V10 个人：内容列宽 ≤ 720dp，居中。
- V10 工具、教程：卡片网格，卡片最小宽 280dp，按宽度自动分列，间距 16dp。
- 大屏页面标题区统一：`headlineSmall` 标题，24dp 内边距，不用 AppBar 的返回箭头。
  （新增归属：`lib/pages/profile_page.dart`、`lib/pages/quick_tools_page.dart`、
  `lib/pages/local_content_pages.dart`、教程页所在文件）
- 手机保持原布局。

### 10.4 验收

- 桌面 1440×900 与 1024×768、浅色与深色，逐项对照 10.1 的 V1–V11 消除。
- 平板 1180×820 触控尺寸不小于 48dp。
- 手机界面像素不变。
- 现有测试断言不改。新增 widget 测试覆盖：桌面密度、导航栏选中、分隔条拖动范围、菜单快捷键文字。

## 11. 收尾（2026-11-25 电脑重启后）

### 11.1 现状

| Pi | 第一阶段 | 第二阶段 |
| --- | --- | --- |
| A | `b24fdbe` | 改动未提交，无报告 |
| B | `cf026d8` | 改动未提交，无报告 |
| C | `d1c58da` | `36436d8` |
| D | `7bf2f0c` | `b7745fd` |

重启后 Pi 窗格为 `w5H:p3 / p4 / p5 / p6`，会话全新。

### 11.2 旧测试的处理

- 旧大屏测试断言了本任务要删除的界面（"项目""文件"两个独立图标、旧 AppBar 按钮等）。
  这类断言按新设计迁移。迁移时在测试里注明对应的需求编号。
- 手机测试一律不改断言。需要时注入 `AppFormFactor.phone`。
- 不得为了旧测试恢复重复入口，也不得加只在测试里生效的分支。

### 11.3 截图测试

- 新分支 `wsui/shots`，基于 `wsui/base`。
- `test/screenshots/workbench_screenshots_test.dart`：环境变量 `QFLI_SCREENSHOTS=1` 时运行，否则跳过。
- 加载真实字体：RobotoMono（仓库自带）、MaterialIcons（Flutter SDK 自带）、
  Noto Sans CJK（CI 用 apt 安装 `fonts-noto-cjk`）。
- 场景：桌面 1440×900、桌面 1024×768、平板 1180×820，各出浅色与深色。
  每组截：欢迎页、资源管理器项目页、资源管理器文件树 + 编辑器、编辑器 + Agent 栏、设置页、"更多"菜单展开。
- 输出到 `build/screenshots/*.png`。
- `core-check.yml` 新增独立 job `screenshots`：装字体、运行该测试、用 upload-artifact 上传。
  Action 按 SHA 固定，SHA 取自 App 仓库已用的版本。

### 11.4 收尾任务

| 序 | 窗格 | 任务 | 前置 |
| --- | --- | --- | --- |
| 1 | p3 | Pi A 完成第二阶段并提交 | 无 |
| 2 | p4 | Pi B 完成第二阶段并提交 | 无 |
| 3 | p5 | 审查并修正 `wsui/pi-d` | 无 |
| 4 | p6 | 截图测试与 CI job | 无 |
| 5 | p3 | 审查并修正 `wsui/pi-c` | 1 |
| 6 | p5 | 审查并修正 `wsui/pi-a` | 1、3 |
| 7 | p6 | 审查并修正 `wsui/pi-b` | 2、4 |
| 8 | p4 | 集成到 `wsui/integration` | 2、4、5、6、7 |

- 审查者在被审分支的 worktree 里提交修正，提交信息前缀 `fix(review):`。
- 集成者从 `wsui/base` 新建 `wsui/integration`，按顺序 cherry-pick，
  把审查修正并入对应的需求提交，得到每个需求一个提交的线性历史，不留合并提交。
- 集成者负责跨分支衔接：Pi C 的中央浮层接到 Pi A 的渲染，Pi B 的 `_toggleExplorer` 改用 `showFiles()`，
  旧大屏测试按 11.2 迁移，全量 `flutter analyze` 无错误。
- 集成者把各报告的 spec 交接汇总到 `reports/spec-handoff.md`，由大脑写入 `.trellis/spec`。
- 大脑推送 `wsui/integration`，看 core-check 与截图，失败项回派。
