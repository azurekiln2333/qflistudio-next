# C：各平台系统权限与工具可用性

## 结论

**不阻塞 R7。** 现有 agent 的读写工具只能在项目根目录内活动。项目默认就落在应用私有目录。因此「读、写、搜索工作区文件」不需要任何存储权限，七个平台一致成立。

判断依据四条：

1. 工具面只有九个名字，其中碰文件的是 `list_files / read_file / write_file / edit_file`。
   路径校验在 `qfli_studio_core/lib/vibe_coding/vibe_tools.dart:111-130`：绝对路径、`.`、`..`、项目外路径、符号链接、元数据目录一律抛 `escape/protected`。
2. 项目根目录默认是 `<应用数据>/projects`，见 `qfli_studio_core/lib/services/app_paths.dart:65-95`。这是沙箱内路径，无需授权。
3. 唯一需要跨沙箱的场景是用户主动选一个外部目录。桌面走 `file_selector`，移动走 `qflistudio/platform` 通道。各平台都有官方授权机制（见 §4），但**这不是 R7 的前置条件**。
4. agent 从不下载也不执行代码。`run_command` 在移动端落到远程在线终端（`vibe_coding_controller.dart:996-1014`、`services/online_program.dart:36-88`），桌面端才走本地进程（`runner_service.dart:154-171`）。两端都不触碰商店对「执行下载代码」的红线。

真缺口两个，都不在 R7 上：

- **移动端口令通道没实现选择器。** `PickerService` 在非桌面平台调用 `qflistudio/platform` 的 `pickDocument/readUri/writeUri`（`picker_service.dart:27-90`），但 OHOS 侧只实现了 `openUrl/shareText/openAgreement/requestPrivacyWithdraw`（`qflistudio/ohos/entry/src/main/ets/entryability/EntryAbility.ets:191-245`），iOS 侧没有该通道的 Swift 处理器。所以手机上「选目录」会 `notImplemented`。默认沙箱路径不受影响。
- **macOS 少了用户选择文件的授权键。** `macos/Runner/Release.entitlements` 只有 `app-sandbox`、`network.client`、`network.server`，缺 `com.apple.security.files.user-selected.read-write`。后果是用户选了容器外目录后读写失败（代码推断，未在 macOS 实机验证）。

后台续跑不能当能力依赖。OHOS 短时任务配额每日 10 分钟、单次上限 3 分钟。连续任务的 `taskKeeping`（计算类）在 API 21 前只对 PC/2in1 开放。iOS/Android 同样不允许长时间后台计算。R7 只要求「同一套 agent 循环和工具」，不要求后台续跑，因此不阻塞。

## 1. 实际支持的平台

七个平台目录都在：`android/ ios/ macos/ windows/ linux/ web/ ohos/`。
插件注册按平台分化（`.flutter-plugins-dependencies`）：iOS/macOS 都是 `file_selector_* + path_provider_foundation`，Android 有 `qfli_studio_core` 原生插件，Windows/Linux 有 `file_selector_*`，OHOS 只有 `path_provider_ohos`（`ohos/entry/src/main/ets/plugins/GeneratedPluginRegistrant.ets`）。

交付口径以 prd R10 为准。CI 发布 **APK**。鸿蒙走 HAP（`ohos/entry/build/.../entry-default-signed.hap`，本机实测安装过）。仓库目前**没有任何 CI 工作流**（`.github/` 不存在），所以桌面三平台属于「可构建」而非「在发布链上」。web 目录存在，但依赖 `dart:io` 的路径探测（`app_paths.dart:32-62`）在 web 上会全部失败，视为不支持。

## 2. 工作区文件当前存放位置

- 配置/元数据根：`getApplicationSupportDirectory`，失败退到 Documents，再退到任意可写目录（`app_paths.dart:65-83`）。
- 项目根：`<根>/projects`（`app_paths.dart:85-95`），语言子目录由 `languageProjectsRoot` 拼（`app_paths.dart:97-110`）。
- 工作区元数据：`<根>/workspaces/*.json`（`workspace_store.dart:74-93`）。
- 用户可改位置：新建项目对话框里 `location` 是自由输入框，也可点按钮选目录（`widgets/project_dialogs.dart:184-194`）。**没有**把用户选择的目录登记到任何「授权清单」，下次靠路径字符串直接用。
- 结论：默认在应用沙箱内。外部目录完全依赖平台自身的授权模型。

## 3. 各平台已声明的权限

| 平台 | 文件 | 现有声明 |
|---|---|---|
| Android | `android/app/src/main/AndroidManifest.xml` | 仅 `INTERNET`。无 service，无存储权限 |
| OHOS | `ohos/entry/src/main/module.json5` | `INTERNET`、`GET_NETWORK_INFO`、`READ_PASTEBOARD`。`deviceTypes: phone/2in1/tablet` |
| iOS | `ios/Runner/Info.plist` | 无任何权限键，无文件访问说明 |
| macOS | `macos/Runner/{Debug,Release}.entitlements` | `app-sandbox`、`network.client`、`network.server`。Debug 多一个 `cs.allow-jit` |
| Windows | — | 无清单权限模型 |
| Linux | — | 无 |

## 4. 逐平台问答

**Android**
- 读写项目文件：可以完全读写，默认目录是 app 私有目录，不需要权限。
- 沙箱外：需要用户经 SAF 选目录（`ACTION_OPEN_DOCUMENT_TREE`，见 `QfliPickerPlugin.java` 的 `pickDocument` 分支）。授权可持久化：`takePersistableUriPermission` 已在 `onActivityResult` 里调用。官方说明「across device restarts … your app can 'take' the persistable URI permission grant」（https://developer.android.com/training/data-storage/shared/documents-files 的 *Persist permissions* 一节）。
- 执行进程：Java/Kotlin 层可以 `ProcessBuilder`。但 Flutter 侧没有本地 shell 路径，`run_command` 走在线终端。
- 后台续跑：Android 12+ 禁止从后台启动前台服务（`ForegroundServiceStartNotAllowedException`，https://developer.android.com/develop/background-work/services/fgs/restrictions-bg-start）。当前 app 不申请任何前台服务。切到后台后系统会挂起回合。
- 商店要求：Play「Device and Network Abuse」禁止下载可执行代码。同页又豁免「code that runs in a virtual machine or an interpreter」（https://support.google.com/googleplay/android-developer/answer/9888379）。另有「AI-Generated Content」政策，要求对 AI 内容做用户举报等治理（https://support.google.com/googleplay/android-developer/answer/13985936）。

**OHOS**
- 读写项目文件：可以，落在 `/data/app/el2/100/base/<bundle>/files` 下。旁证：本机 shell 能读写该目录（权限 `rwxrwxrwx`）。
- 沙箱外：用 FilePicker，接口本身不需要权限。拿到的 URI **只有临时读写权限**，应用退出或设备重启即失效。要长期访问必须 `ohos.permission.FILE_ACCESS_PERSIST` 加 `fileShare.persistPermission` 持久化。重启后还要「激活持久化授权」（https://gitee.com/openharmony/docs/raw/master/zh-cn/application-dev/file-management/file-persistPermission.md）。正文见同目录 `select-user-file.md`。
- 执行进程：应用能起子进程执行随包二进制。起系统 shell 并跑任意命令受限，且与 §7 一样受后台约束。
- 后台续跑：短时任务单日配额默认 10 分钟、单次最大 3 分钟、同时最多 3 个（https://gitee.com/openharmony/docs/raw/master/zh-cn/application-dev/task-management/transient-task.md）。长时任务需 `KEEP_BACKGROUND_RUNNING` 加 `backgroundModes`。业务类型还必须与实际一致。计算类 `taskKeeping` 到 API 21 才向非 2in1 开放（`continuous-task.md`）。本机实测与文档一致（`research/pi-C-20261109.md` §6、§10）。
- 商店要求：华为审核关注隐私与未成年人保护。对「执行下载代码」的具体条款**未取到官方原文，未验证**。

**iOS**
- 读写项目文件：可以，限容器内。
- 沙箱外：只能用 `UIDocumentPickerViewController`，配 security-scoped bookmark 持久化（https://developer.apple.com/documentation/uikit/uidocumentpickerviewcontroller 、https://developer.apple.com/documentation/foundation/nsurl/1417051-startaccessingsecurityscopedreso）。页面为 JS 渲染，正文未取到，**具体调用约定未验证**。当前 Info.plist 没有对应键，通道处理器也缺失。
- 执行进程：`Process` 在 iOS 上不可用（沙箱禁止 fork/exec 第三方二进制）。
- 后台续跑：受 `BGTaskScheduler` 调度，系统决定何时给时间，不能保证时长（https://developer.apple.com/documentation/backgroundtasks）。正文未取到，**具体时长未验证**。
- 商店要求：2.5.2 规定「Apps should be self-contained … may not read or write data outside the designated container area, nor may they download, install, or execute code which introduces or changes features」。同一节又留了教育类豁免（https://developer.apple.com/app-store/review/guidelines/ ，原文已抓到）。豁免条件是源码完全可见且可编辑，且代码不得用于其他用途。本项目满足源码可见可编辑。

**macOS**
- 读写项目文件：容器内可以。容器外需要 `com.apple.security.files.user-selected.read-write`（键名见 https://developer.apple.com/documentation/bundleresources/entitlements/com.apple.security.files.user-selected.read-write ，正文未取到）。**当前 entitlements 缺这一键**。
- 执行进程：可以，`Process.start` 已在用（`process_supervisor.dart:656`），子进程继承沙箱。
- 后台续跑：桌面无后台挂起概念，窗口在跑就能继续。
- 商店要求：Mac App Store 需沙箱。公证发布无额外条款。

**Windows / Linux**
- 读写、选目录、执行进程全部可以，无授权模型。只有文件系统 ACL（https://learn.microsoft.com/en-us/windows/win32/secauthz/access-control-lists）。
- 后台：无限制。
- 商店：Windows 若走 MSIX/Store 才引入额外约束，当前是裸 exe 构建。

## 5. 工具可用矩阵

`✅` 可用 · `⚠️` 可用但受限 · `❌` 不可用 · `n/a` 不适用

| 工具 | Android | OHOS | iOS | macOS | Windows | Linux |
|---|---|---|---|---|---|---|
| 读文件 | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| 写文件 | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| 编辑（替换） | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| 搜索（遍历项目） | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| 列目录 | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| 终端 `run_command` | ⚠️ 远程在线终端 | ⚠️ 远程 / 跨应用桥接 | ⚠️ 远程在线终端 | ✅ 本地进程 | ✅ 本地进程 | ✅ 本地进程 |
| 联网抓取 `web_fetch` | ✅ 服务端 | ✅ 服务端 | ✅ 服务端 | ✅ 服务端 | ✅ 服务端 | ✅ 服务端 |
| 选外部目录 | ❌ 通道未实现 | ❌ 通道未实现 | ❌ 通道未实现 | ⚠️ 缺授权键 | ✅ | ✅ |
| 后台续跑回合 | ❌ | ⚠️ ≤3 分钟/次，10 分钟/天 | ❌ | ✅ | ✅ | ✅ |

说明：`web_search` 已按整改下线（`vibe_coding_controller.dart:491-493`），不在矩阵内。`web_fetch` 由服务端抓取，与平台权限无关。

## 6. 不可用格子的降级方案

- **移动端选外部目录**：先用默认沙箱项目目录（当前默认行为）。需要外部目录时补通道实现。Android 已有 `QfliPickerPlugin` 可复用。OHOS 用 `file_picker` 或 `photoAccessHelper` 的 FilePicker，并登记 `FILE_ACCESS_PERSIST` 做持久化。iOS 用 `UIDocumentPickerViewController` 加 bookmark。补齐前，移动端 UI 隐藏「选择目录」按钮，只允许输入默认路径，避免 `notImplemented` 报错。
- **macOS 缺授权键**：给 `Release.entitlements` 与 `DebugProfile.entitlements` 加 `com.apple.security.files.user-selected.read-write`，并对选中目录存 security-scoped bookmark。在此之前，macOS 上「选目录」应关闭。
- **移动端终端**：已是降级形态（远程在线终端 + 跨应用桥接）。UI 上明确标注「在线镜像」与「本地不可用」，避免用户以为在跑本机命令。
- **移动端后台**：不做隐式续跑。系统切走回合时，把进度存进会话并标记「已中断」，回前台可续。不要申请长时任务冒充计算任务（OHOS 会管控或查杀）。
- **iOS 执行下载代码**：永久不做本地编译执行。若将来要做，只能以「教育类、源码完全可见可编辑」的形态申请，并逐版送审沟通。

## 7. 未验证项

- iOS 的 picker/bookmark 具体 API 调用约定（Apple 文档页是 JS 渲染壳，只确认了 URL 存在与标题）。
- iOS `BGTaskScheduler` 实际可获得的执行时长。
- 华为应用市场对「执行下载代码」的条款原文。
- macOS 缺授权键导致的运行时失败（纯代码推断，没有 macOS 实机）。
- Windows/Linux 未在本机执行过 agent 会话。
