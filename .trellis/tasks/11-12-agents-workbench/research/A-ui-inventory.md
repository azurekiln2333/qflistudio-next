# A：UI 现状盘点与并行拆分

## 结论

1. **能复用**：项目列表、项目新建（R1）、编辑器（R5 主体）、文件树。
   登录态与登录页（R8 的零件）、agent 循环与工具（R7 的零件）、技能发现也可复用。
2. **必须新建**：主页到项目的两级导航（R1/R2）、项目页的 agent 会话列表与输入卡片（R2/R3）。
   三栏宽屏布局（R6）、侧边栏会话/文件切换（R4）、agent 功能的登录门控（R8）也需新建。
3. **UI 不在 `qflistudio/lib`**：那里只有 `main.dart` 与 `content/`。全部界面在并列仓库 `../qfli_studio_core/lib`（186 个 dart 文件）。
   证据：`qflistudio/pubspec.yaml:15`（path 依赖）、`qflistudio/lib/main.dart:7`。
4. **现有导航是 5 个底部/侧栏 tab**（home/tools/tutorial/examples/profile），不是"主页→项目→会话"。
   证据：`lib/pages/home_page.dart:145-215`。
5. **没有命名路由**。`MaterialApp` 只有 `home:`，其余靠 `Navigator.push`。
   证据：`lib/app.dart:126-140`、`lib/editor/retained_editor_host.dart:21`。
6. **状态管理是 `ChangeNotifier` + 构造注入**，没有 Provider/Riverpod/Bloc。
   证据：`lib/store/project_store.dart:73`、`lib/store/auth_store.dart:17`、`lib/store/settings_store.dart`。
7. **重大发现：整条 vibe_coding agent 链路（R7）是死代码**。`VibeCodingController` 只有 `VibeCodingPanel` 一个引用方。
   而 `VibeCodingPanel` 在全仓库没有任何实例化点。
   证据：`lib/vibe_coding/vibe_coding_panel.dart:12`、`lib/vibe_coding/vibe_coding_controller.dart:84`。
   编辑器实际用的是更简单的 `AiPanel`（`lib/editor/editor_page.dart:3196`），它不走工具循环。
8. **R3 的三个选择器全部缺失**：`SettingsStore` 只有 `aiBaseUrl`/`aiApiKey`/`aiModel`/`aiProtocol`，没有权限模式、推理强度、附件。
   证据：`lib/store/settings_store.dart:115-123`。
9. **断点散落 6 处且不一致**：600、720、900、1200、520、128。
   证据：见第 2 节表格。
10. **R8 现状不满足**：`isLoggedIn` 仅覆盖个人页、社区与设置。agent 与 AI 功能没有门控。
    证据：`lib/pages/profile_page.dart:76`、`lib/pages/community/post_list_page.dart:171`。
11. **测试现状**：studio `flutter analyze` 无问题、8 个测试全过。core `flutter analyze` 无问题、1411 过 9 跳过 **3 失败**（`test/editor_run_target_test.dart`，`Expected: contains 'java' Actual: []`）。该文件未改动，`lib/editor/editor_page.dart` 有未提交改动，故判为**既有失败**，非本次调研引入。
12. **未验证**：CI 设置（`.cnb.yml`）与 R10 的实际状态，不在本 brief 范围。

## 1. 入口、路由、状态管理

| 部分 | 入口文件 | 路由方式 | 状态 |
|---|---|---|---|
| 启动 | `lib/main.dart:64` `main()` | `runApp(QfliApp)` | 构造注入 3 个 store |
| App 壳 | `lib/app.dart:19` `QfliApp` | `MaterialApp.home`（`app.dart:136`） | `ValueNotifier` + `ValueListenableBuilder` |
| 启动屏 | `lib/splash_screen.dart` | `app.dart:133` | `AppBootstrap.run` |
| 主页 | `lib/pages/home_page.dart:39` `HomePage` | 5 页 `PageView`（`home_page.dart:92`） | `_currentIndex` `ValueNotifier` |
| 项目列表 | `home_page.dart:288` `HomeTab` | 页内 `TabBar`（`home_page.dart:534`） | `TabController` + `ProjectStore` |
| 工作区 | `lib/workspace/saved_workspaces_tab.dart:19` | 作为项目页的一个 tab（`home_page.dart:571`） | `WorkspaceStore.instance`（`workspace_store.dart:44`） |
| 侧边栏 | 无独立实现。仅编辑器内有 `Drawer`（`editor_page.dart:3010-3022`） | — | `_explorerVisible` |
| 编辑器 | `lib/editor/editor_page.dart:141` `EditorPage` | `openEditorPage()` 全页 push（`retained_editor_host.dart:21`） | `EditorController` |
| 文件树 | `lib/editor/file_explorer.dart:34` | 编辑器内嵌/抽屉 | `FileExplorer` 自身 setState |
| AI 会话 | `lib/editor/ai_panel.dart:146` `AiPanel` | 编辑器底部面板（`editor_page.dart:3196`） | 局部 `setState`，消息不持久化 |
| agent 链路 | `lib/vibe_coding/vibe_coding_controller.dart:84` | **无 UI 入口** | `ChangeNotifier` |
| 登录 | `lib/pages/auth/login_page.dart:18` `LoginPage` | `Navigator.push`（`profile_page.dart:56`） | `AuthStore`（`auth_store.dart:17`） |

`ProjectStore`/`AuthStore`/`SettingsStore`/`WorkspaceStore` 都继承 `ChangeNotifier`，靠构造函数逐层传参，没有 InheritedWidget 或全局 provider。

## 2. 现有响应式处理

| 断点 | 位置 | 行为 |
|---|---|---|
| 900 | `pages/home_page.dart:145` | `wide`：左侧 `NavigationRail`，否则底部 `NavigationBar` |
| 1200 | `pages/home_page.dart:146` | `extendedRail`：侧栏展开带文字 |
| 720 | `editor/editor_page.dart:203` | `_wideBreakpoint`：侧栏常驻，否则改 `Drawer` |
| 720 | `pages/home_page.dart:877` | 项目网格列数 |
| 520 | `editor/editor_page.dart:4004`、`editor/symbols_bar.dart:285` | 工具栏/符号栏折叠 |
| 600 | `widgets/tool_widgets.dart:13` | 图标尺寸 16/24/32 |
| 900 | `editor/retained_editor_host.dart:551` | 是否预留底部导航高度 |
| 128 | `editor/editor_output_panel.dart:394` | 面板按钮是否显示 |

窄屏与宽屏各自 `if (wide)` 分支，**没有共享的布局描述层**。
因此 R6 要求“同一套状态跨断点不丢失”需要新增布局壳，而不是改现有分支。

## 3. 登录态来源与门控

- 来源：`AuthStore`（`lib/store/auth_store.dart:17`），持久化到 `auth.json`，字段 `token` + `user`，`isLoggedIn` 见 `auth_store.dart:24`。
- 装载：`AppBootstrap.run`（`lib/splash_screen.dart:100` 附近）在启动时 `load()`。
- 现有门控点（共 22 处 `isLoggedIn`）：
  - `pages/profile_page.dart:76-77`：点个人页操作时若无登录则 `_login()`。
  - `pages/community/post_list_page.dart:171,238,253`：社区发帖/点赞入口。
  - `pages/settings_page.dart:101,115`：撤回同意、注销账号。
  - `pages/community/post_detail_page.dart:447,469`。
- **缺口**：`editor/ai_panel.dart`、`editor/editor_page.dart`、`vibe_coding/*` 全都不检查登录。R8 需要新建统一门控（建议放在 agent 会话新建处，而不是每个按钮）。

## 4. 对照 R1–R6、R8、R9 归类

| 需求 | 判定 | 依据 |
|---|---|---|
| R1 主页新建项目→进入项目 | **需修改** | 新建与打开已存在（`home_page.dart:1084`、`project_store.dart:224`），但缺“新建后落在项目页”的落点 |
| R2 项目页显示 agent 会话列表 + 底部输入卡片 + 点进对话流 | **需新建** | 无项目级会话概念。`AiPanel` 消息只存内存（`ai_panel.dart:219`）。`_EditorSession` 是编辑器标签页（`retained_editor_host.dart:325`），`ProjectSession` 是文档历史（`editor/project_history.dart:81`） |
| R3 输入卡片（加号/权限模式/模型/推理强度/内部发送） | **需新建** | `settings_store.dart:115-123` 无权限模式与推理强度。`ai_panel.dart` 只有文本框 |
| R4 侧边栏会话/文件切换 | **需新建** | `pages/` 层无侧边栏。`file_explorer.dart:34` 只有文件树，无切换容器 |
| R5 窄屏主体区编辑器/对话流切换 | **需修改** | 编辑器已是全页（`retained_editor_host.dart:21`），但无对话流对手方 |
| R6 宽屏三栏 + 对话流可收起 | **需新建** | 现无三栏。`editor_page.dart:3112` 只有编辑器内两栏（侧栏+编辑器） |
| R7 跨平台 harness + skill | **可复用（零件）+ 需修改（接线）** | 工具 `list_files/read_file/write_file/edit_file/run_command/todo/use_skill`（`vibe_tools.dart`）、技能发现 `.qfli/skills`、`.claude/skills`、`.agents/skills`（`vibe_skills.dart:37-40`）、计划与循环守卫均在，但**没有任何 UI 实例化** |
| R8 agent 功能登录门控 | **需新建** | 见第 3 节缺口 |
| R9 其他逻辑保持一致 | **需修改** | 保留 5 tab 中的 tools/tutorial/examples/profile 入口即可 |

## 5. 体验割裂的具体点

| # | 割裂点 | 文件位置 |
|---|---|---|
| 1 | 同一份 agent 能力有两套实现：`VibeCodingPanel`（带工具循环，未接线）与 `AiPanel`（纯聊天，已接线） | `vibe_coding/vibe_coding_panel.dart:12` vs `editor/ai_panel.dart:146` |
| 2 | 打开编辑器有两种方式：`openEditorPage`（保留会话）与 `Navigator.push(MaterialPageRoute(EditorPage))` | `editor/retained_editor_host.dart:21`、`editor/editor_page.dart:3437`、`editor/retained_editor_host.dart:669` |
| 3 | 工作区有两个概念同名："保存的工作区"（项目页 tab）与"工作区文件"（R3 加号要引用） | `workspace/saved_workspaces_tab.dart:19`、`workspace/workspace_store.dart:41` |
| 4 | 导航在宽窄屏是两套 widget（`NavigationRail` / `NavigationBar`），选中态靠同一个 `_currentIndex` 才勉强一致 | `pages/home_page.dart:185` 与 `:212` |
| 5 | 断点不统一：主页 900/1200，编辑器 720，工具 600 | 见第 2 节 |
| 6 | 侧边栏只在编辑器里有，主页没有，用户在两处的心智模型不同 | `editor_page.dart:3010` vs `pages/home_page.dart`（无） |
| 7 | 编辑器内 AI 面板是底部抽屉，窄屏时与终端、问题、输出抢同一块空间 | `editor_page.dart:64`（`_BottomPanel` 8 个枚举值） |
| 8 | 登录入口只在个人页，agent 想用 AI 时无处引导 | `pages/profile_page.dart:56` |

## 6. 模块拆分建议（4 人并行不冲突）

按目录划所有权，**每人只改自己目录 + 自己新增文件**。

| 角色 | 独占范围 | 可读不可改 |
|---|---|---|
| 1 布局壳 | `lib/shell/`（新建）、`lib/pages/home_page.dart` | `store/*` |
| 2 项目页与会话列表 | `lib/pages/project/`（新建）、`lib/session/`（新建：会话模型与持久化） | `store/project_store.dart` |
| 3 输入卡片与对话流 | `lib/chat/`（新建：卡片、工具行、消息流、三个选择器） | `vibe_coding/*` |
| 4 侧边栏与响应式适配 | `lib/sidebar/`（新建）、`lib/layout/breakpoints.dart`（新建） | `editor/file_explorer.dart` |
| 保留 | `editor/`、`terminal/`、`services/`、`interop/`、`community/` 本次不动 | — |

**必须先落地的共享接口文件**（一次定死，之后只读）：

1. `lib/layout/breakpoints.dart` — 统一断点常量，替换第 2 节 6 处散落数值。
2. `lib/session/agent_session.dart` — 会话模型与 id，角色 2 定义、角色 3 消费。
3. `lib/session/agent_session_store.dart` — 持久化接口（`ChangeNotifier`，沿用现有风格）。
4. `lib/chat/composer_state.dart` — 输入卡片状态（附件、权限模式、模型、推理强度），角色 3 定义。
5. `lib/vibe_coding/vibe_agent_facade.dart` — 把已存在的 `VibeCodingController` 包一层薄门面，供角色 3 调用，避免直接改 `vibe_coding/*`。

冲突热点（需先约定）：`pages/home_page.dart` 只归角色 1。
`editor_page.dart` 本次不改，对话流用新的三栏壳承载，而不是塞进编辑器。

## 7. 测试与 lint 现状（已运行）

| 命令 | 目录 | 结果 |
|---|---|---|
| `flutter analyze --no-fatal-infos --no-fatal-warnings` | `qflistudio` | **No issues found**（8.3s） |
| `flutter test` | `qflistudio` | **8 passed** |
| `flutter analyze --no-fatal-infos --no-fatal-warnings` | `qfli_studio_core` | **No issues found**（8.2s） |
| `flutter test` | `qfli_studio_core` | 1411 passed、9 skipped、**3 failed** |
| `node scripts/check-root-ci.mjs` | `qflistudio` | 未运行（不在本 brief 范围） |

失败明细：`test/editor_run_target_test.dart` 三条（`an installed sibling app takes the run tap`、`a missing sibling app keeps the original path`、`an unknown probe keeps the original path`），报错 `Expected: contains 'java' / Actual: []`。
该测试文件工作树无改动。`lib/editor/editor_page.dart` 有用户未提交改动，判定为既有失败。
