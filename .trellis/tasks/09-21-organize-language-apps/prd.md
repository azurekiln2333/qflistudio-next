# QFLIStudio+ language apps, content, project IO, and terminal UX

## Goal

把联网主程序与所有语言子 App 收敛到同一套可维护的 Flutter 内核：教程、功能、示例代码都是明确的独立页面；项目和代码内容使用可版本化的 JSON 数据；项目导入导出、资源导入和终端操作在桌面与 HarmonyOS 上都有清晰且可验证的路径。

## Background and confirmed facts

- 根工程是联网全能版，共享内核位于 `packages/qfli_studio_core`。
- `apps/` 已有 C、C++、Python、Java、Lua、Web、Dart 子 App；C 与 C++ 当前是两个独立 App，但 C++ 模板和 C 模板已经存在于共享模板枚举中。
- 教程 JSON 已有 C、C++、Python、Java、Lua、Dart、Web 资产，当前 `TutorialService` 解析课时并由页面临时投影示例代码。
- 当前主页面把第二个底部页面命名为“快捷功能”，该页同时放终端和教程入口；教程没有作为主导航独立页面。
- 子 App profile 当前通过 `showEditorTabs: false` 隐藏编辑器文件标签，这是错误的边界：用户要隐藏的是主页内部筛选/项目标签，编辑器文件标签应恢复显示并可在设置中控制。
- 现有项目导入主要依赖 `file_selector` 的桌面目录路径；各 HarmonyOS App 的 `EntryAbility.ets` 已有 `qflistudio/platform` MethodChannel，可扩展 Picker 方法。
- 本地设置已持久化为 `settings.json`，项目登记与项目内 `.qfli/project.json` 也已使用 JSON。
- 共享编辑器已有编辑、保存、恢复历史版本、格式化、C 运行时接入和终端输出接入；需要在这些边界上补齐示例代码临时编辑、恢复默认、项目 IO 和多终端状态。

## Requirements

### Navigation and layout

1. 主程序与全部子 App 都有独立的“功能”页和独立的“教程”页，不显示“快捷功能”这个页面名称；教程不能藏在功能页卡片中。
2. 离线子 App 继续提供独立的“示例代码”页；根联网版保留讨论页，不通过社区 API 替代本地语言教程。
3. 子 App 隐藏主页内部的项目筛选/项目范围标签栏和无意义的语言筛选行；底部页面导航仍可切换主页、功能、教程、示例代码等页面，不能因为隐藏内容标签而失去入口。
4. 所有页面的 Tab/Navigation 文本与图标垂直居中；主页项目列表标签栏继续作为对齐基准；符号栏按钮之间保留稳定间距，不出现相邻按钮粘连或布局越界。
5. 编辑器顶部文件标签恢复显示，新增设置项允许用户持久化隐藏/显示文件标签；此开关与子 App 主页标签隐藏相互独立。
6. 终端面板去掉“工作目录”说明式启动文案和多余注释样式，命令提示按常规 shell 形式显示，例如 Windows 的 `C:\Users\lichengyu>`，命令与输出分行显示。
7. 格式化命令直接执行并更新编辑器内容，不弹出格式化确认/结果提示；只有真实错误才显示错误状态。
8. 修正现有页面的约束、文本溢出和动态高度问题，消除可修复的 overflow/越界警告；必要时使用省略、滚动或稳定尺寸，不通过全局屏蔽 Flutter 错误。

### Language/type data

9. 新建项目对话框在主程序中明确显示 C 与 C++ 两个项目类型；C/C++ 子 App 只显示其允许的模板，且项目写入语言 `type`/language 元数据。
10. 教程顶层、每个教程条目和每个示例代码条目都带稳定的语言 `type`，至少覆盖 `c`、`cpp`、`python`、`java`、`lua`、`web`、`dart`。服务层不得依赖页面猜测语言。
11. 教程和示例代码使用类型化模型与服务读取。示例代码有独立的列表数据结构，并保留从旧课时 JSON 兼容生成的回退路径，已有资产升级后不丢内容。

### Code examples and projects

12. 示例代码列表项可点击进入独立详情页，详情页显示说明、代码、输出和语言 type，并提供复制、导入到新建项目、打开临时编辑器、恢复默认等操作。
13. 临时编辑器支持正常编辑、保存、修改和运行；导入到新建项目后代码进入真实项目并在项目列表中可见。运行能力必须如实使用已有 RunnerService/profile，尚未实现解释器的语言显示未就绪，不伪造成功输出。
14. 示例代码可添加和修改，默认内容可恢复；自定义内容和示例列表使用 JSON 持久化，重启后仍存在。
15. 设置页提供项目/示例数据的 JSON 导入与导出入口。导入导出至少覆盖项目元数据、源码、`.qfli/project.json` 和二进制资源；二进制资源以 Base64 或等价 JSON 字段保存，导入后恢复目录结构。
16. 项目内文件树支持长按目录导入资源；用户可调用系统相册选择图片，也可调用系统文件管理选择任意文件，将其复制到当前目录并刷新树。冲突文件必须有明确处理策略，不静默覆盖未确认的用户文件。

### HarmonyOS picker and terminal

17. HarmonyOS 使用原生 `DocumentViewPicker` 选择文件/目录与保存导出文件，使用 `PhotoViewPicker` 选择相册资源，通过现有 `qflistudio/platform` MethodChannel 暴露给 Dart。桌面端继续使用 `file_selector`，其他平台使用可用实现或明确回退。
18. 目录 Picker 能力受设备和系统 API 限制时，提供文件级 JSON 导入导出回退，并向用户展示可执行的结果；不能把 URI 当成本地路径直接使用，原生层负责读取/写入 URI 内容。
19. 终端支持新建多个终端、在终端之间切换、独立的工作目录与历史/输出，并支持拖拽调整弹窗/面板高度。关闭终端只终止对应进程，不影响其它终端。

### Localization

20. 新增和修改的可见文案进入共享本地化层，至少提供简体中文、繁体中文和英文；页面不再通过大段硬编码 `Text` 承载产品文案。代码、路径、type、命令和用户数据保留原文。

## Acceptance criteria

- 主程序和每个子 App 都能从主导航直接进入功能页和教程页；界面中不再出现“快捷功能”作为页面名称。
- 子 App 的主页内部项目/语言标签隐藏，底部页面导航可用；编辑器文件标签默认可见，并能在设置中关闭后持久化。
- 主程序新建项目类型中同时出现 C 与 C++；项目 JSON、教程 JSON、示例 JSON 均有稳定语言 type，服务测试覆盖所有已登记语言。
- 示例列表条目可进入详情；详情可复制、导入真实项目、打开临时编辑器、保存修改和恢复默认，且运行结果遵循真实 runner 能力。
- 设置可导入/导出 JSON；项目源码、配置和图片等资源可恢复到正确目录；目录/文件/相册入口在 HarmonyOS 上走原生 Picker 通道，桌面仍可工作。
- 文件树目录长按可导入资源，冲突不会静默覆盖；导入后文件树和编辑器状态正确刷新。
- 终端可新建并切换多个实例，提示符为常规路径格式，面板高度可拖拽调整；格式化直接执行无成功提示。
- 关键页面在窄屏、长标题、多文件、长路径和空数据状态下通过 `flutter test`/人工截图验证，无新增 overflow 断言或布局警告。
- `dart format`、`flutter analyze --no-pub`、共享内核测试、全部子 App 测试和 `git diff --check` 通过。

## Out of scope and deferred risk

- 不在本任务内实现所有语言的完整编译器/解释器；未实现的 runner 必须保持未就绪状态。
- 不重写联网社区、登录、云端同步和在线终端协议；根工程原有联网入口继续保留。
- HarmonyOS 手机端是否支持目录选择取决于设备系统能力。实现 Picker 目录模式和文件级 JSON 回退；不承诺在系统本身禁用目录选择的设备上伪造目录授权。
- 不用全局 `ErrorWidget.builder`、`FlutterError.onError` 或静默 `overflow` 方式掩盖真实错误；只修复组件约束和内容裁剪。
- 导出 JSON 可能因二进制 Base64 变大；本任务优先保证可移植性和单文件恢复，超大项目的压缩格式留作后续优化。

## Planning status

- Blocking product questions: none; the user approved twelve products with `QFLIScript` as the single scripting suite, including Lua and additional script formats.
- Technical research: local HarmonyOS SDK declarations confirm `DocumentViewPicker.select/save`, folder `DocumentSelectMode.FOLDER`, and `PhotoViewPicker.select`; the folder mode is capability-limited and requires a fallback.

## Latest product-line expansion

The product catalog is now fixed to twelve products:

| Product | Scope | Proposed app/package key |
| --- | --- | --- |
| `QFLIStudio+ 多语言编辑器（暂定）` | root full online editor | `qflistudio` |
| `QFLIScript` | scripting suite; Lua plus additional script formats | `script` |
| `QFLIRustCore` | Rust | `rustcore` |
| `QFLIGoShift` | Go | `goshift` |
| `QFLIJVMX` | Java | `jvmx` |
| `QFLIWebForge` | Web | `webforge` |
| `QFLIPyFlow` | Python | `pyflow` |
| `QFLIForge` | C and C++ in one App | `forge` |
| `QFLIDartWing` | Dart | `dartwing` |
| `QFLISQLab` | database/SQL | `sqlab` |
| `QFLIJson` | JSON | `json` |
| `QFLINote` | Markdown | `note` |

All platform identifiers must converge on `com.azurekiln.qfli.<key>` (or the root key for the main product), with Android namespace/applicationId, HarmonyOS bundleName, iOS/macOS identifiers, display labels, and signing profiles checked as one migration. Existing user-edited signatures and labels are input to this migration and must not be overwritten without matching bundle evidence.

The C and C++ source trees are to be merged into the single `qfli_forge` App. The merged App exposes both C and C++ project templates and routes each source type to a real runtime/toolchain. It must not keep two installable products with the same product identity.

Every listed language must have a truthful usable path: a bundled compiler/interpreter/runtime where the platform permits it, a desktop toolchain path where appropriate, and a visible unsupported explanation only for a capability that the target platform genuinely cannot provide. Markdown is intentionally editor + preview rather than a program runtime. JSON is editor + validation/formatting/preview. Database is editor + local SQLite/query workflow. `QFLIScript` is the single scripting App and includes Lua plus JavaScript, TypeScript, and shell-style script workflows.
