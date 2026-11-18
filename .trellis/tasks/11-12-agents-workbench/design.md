# 技术设计：Agents 工作台

调研依据：`research/A-ui-inventory.md`、`research/B-harness.md`、`research/C-platform-permissions.md`、`research/D-cicd.md`。

## 1. 边界

- 界面和 harness 的代码全部在 core 仓库：`D:\MyNewProjects\qfli_studio_core`。下文 `lib/` 指 core 的 `lib/`。
- studio 仓库只改 CI、Android 签名配置、本任务目录。
- harness 不新造。`lib/vibe_coding/` 已有 agent 循环、工具、skill、取消。本次接线并补缺口。
- 移动端权限不阻塞。工具只在项目根目录内活动。项目根默认在应用沙箱内。
- 本次不做：手机上选择沙箱外目录、macOS 文件授权键、后台续跑、上下文压缩、鸿蒙 HAP 和桌面端发布。

## 2. 术语（界面文案全篇统一）

| 词 | 含义 |
|---|---|
| 项目 | 主页上创建的一个代码目录 |
| 会话 | 项目内的一次 agent 对话 |
| 项目文件 | 当前项目内的文件 |
| 工作区文件 | 同一个已保存工作区内其他项目的文件 |
| 对话流 | 一个会话的消息列表 |
| 输入卡片 | 底部的输入组件 |

## 3. 布局

断点只定义在 `lib/layout/breakpoints.dart`。新代码不得写其他断点数值。

| 宽度 | 侧边栏 | 主体 |
|---|---|---|
| < 720 | 抽屉 | 单区。顶部分段切换「编辑器 / Agent」 |
| 720 – 1100 | 常驻 | 单区。顶部分段切换「编辑器 / Agent」 |
| ≥ 1100 | 常驻 | 中间编辑器，右侧对话流。对话流可收起和展开 |

- 三种宽度使用同一个 `WorkbenchState`。布局只读状态，不持有状态。
- 用户拉伸窗口跨越断点时，编辑器和对话流的 widget 不重建（用 `GlobalKey` 或保留宿主）。
- 侧边栏顶部有分段切换：「会话 / 文件」。文件列表复用 `editor/file_explorer.dart`。
- 导航：主页 → 编辑器页（原有）。agent 嵌入编辑器页。已替换三层导航，见 §11.1。
- 项目页和独立工作台页已作废。
- 主页现有的 tools、tutorial、examples、profile 入口保留（R9）。

## 4. 人性化规则（验收时逐条检查）

1. 输入卡片只有一个实现。项目页和工作台使用同一个组件。
2. 运行中，发送按钮变成停止按钮。位置不变。
3. 桌面端：Enter 发送，Shift+Enter 换行。移动端：回车换行，点按钮发送。
4. 移动端输入卡片跟随软键盘上移，并避开安全区。
5. 未登录时，agent 入口显示登录引导卡片和「登录」按钮。不弹错误。登录成功后回到原位置。
6. 「每次询问」模式下，写文件的确认卡片出现在对话流内。卡片显示路径和改动摘要。
7. 失败消息带「重试」按钮。错误文案说明原因和下一步。
8. 空状态有引导：没有项目、没有会话、没有文件各有一句说明和一个主操作。
9. 应用记住每个项目的：上次打开的会话、侧边栏分段、对话流收起状态、模型、推理强度、权限模式。
10. 所有可点击目标不小于 44×44。颜色只用现有主题 token。深色和浅色都检查。
11. 模型不支持推理强度时，推理强度选择器隐藏，不置灰。
12. 旧的 `AiPanel` 入口改为打开新的对话流。应用内只有一个 AI 入口。

## 5. 共享契约

所有者先落地签名。其他人只读。改签名必须先在 `status/` 里说明。

```dart
// lib/layout/breakpoints.dart —— pi-A
abstract final class Breakpoints {
  static const double sidebarPersistent = 720;
  static const double threePane = 1100;
}
enum WorkbenchLayout { narrow, medium, wide }
WorkbenchLayout layoutOf(double width);

// lib/shell/workbench_state.dart —— pi-A
enum SidebarSection { sessions, files }
enum MainPane { editor, agent }
class WorkbenchState extends ChangeNotifier {
  String projectId;
  String? sessionId;
  SidebarSection sidebarSection;
  MainPane mainPane;          // narrow、medium 使用
  bool agentPaneCollapsed;    // wide 使用
}

// lib/shell/login_gate.dart —— pi-A
/// 已登录返回 true。未登录时打开登录页，登录成功后返回 true。
Future<bool> ensureLoggedIn(BuildContext context);

// lib/session/agent_session.dart —— pi-B
class AgentSessionMeta { String id, projectId, title; DateTime createdAt, updatedAt; }
abstract class AgentSessionStore extends ChangeNotifier {
  Future<void> load();
  List<AgentSessionMeta> sessionsOf(String projectId);   // updatedAt 倒序
  Future<AgentSessionMeta> create(String projectId, {String? title});
  Future<void> rename(String sessionId, String title);
  Future<void> delete(String sessionId);
}

// lib/vibe_coding/vibe_agent_facade.dart —— pi-B
enum AgentPermissionMode { readOnly, askEveryWrite, autoAcceptEdits }
enum AgentRunState { idle, running, awaitingApproval, cancelling, failed }
class AgentModelOption { String id, label; List<String> reasoningEfforts; }
class AgentSkillRef { String name, description; }
class AgentMessageView {
  String id; String role;            // user | assistant | tool
  String text; String? toolName; bool isError; List<String> changedPaths;
}
class AgentWriteApproval { String path, summary; }
class AgentLoginRequired implements Exception {}

/// 一个实例对应一个会话。消息自动持久化。
abstract class AgentFacade extends ChangeNotifier {
  String get sessionId;
  List<AgentMessageView> get messages;
  AgentRunState get state;
  String? get lastError;
  AgentWriteApproval? get pendingApproval;
  void resolveApproval(bool allow);
  Future<void> send(String text, {
    List<String> attachedPaths = const [],
    required AgentPermissionMode permission,
    String? modelId, String? reasoningEffort});
  Future<void> cancel();
  Future<void> retryLast();
}

/// 应用级单例。构造注入，沿用现有 store 的风格。
abstract class AgentRuntime {
  AgentSessionStore get sessions;
  Future<List<AgentModelOption>> models();
  Future<List<AgentSkillRef>> skills(String projectId);
  /// 未登录时抛 AgentLoginRequired。
  Future<AgentFacade> open(String projectId, String sessionId);
}

// lib/chat/composer_state.dart —— pi-C
class ComposerState extends ChangeNotifier {
  String text;
  List<String> attachments;          // 相对项目根或工作区根的路径
  AgentPermissionMode permission;    // 默认 askEveryWrite
  String? modelId;
  String? reasoningEffort;
}
```

## 6. Harness 补缺口（pi-B）

- 权限模式接到现有的 `shouldWrite` 钩子。`readOnly` 在写工具入口拒绝。`askEveryWrite` 进入 `awaitingApproval`。
- 新增 `search_text` 工具。参数：模式、路径、结果上限。
- 模型列表接 `/api/ai/models`。接口失败时退回设置里的单个模型。
- 推理强度：客户端传 `reasoning_effort`。直连模式直接发。转接模式需要服务端放行该字段。服务端代码的改动要标明「需部署」。
- skill：保留项目级和内置。新增用户级目录。优先级：内置 < 用户级 < 项目级（项目里的同名技能覆盖内置）。输入 `/` 时列出 skill。
- 会话持久化：每个会话一个 JSON 文件，存在应用数据目录下。写入采用先写临时文件再改名。
- 登录门控有两层：界面层 `ensureLoggedIn`，harness 层 `AgentRuntime.open`。直连模式同样要求登录（R8）。
- 附件：发送时把附件路径列表写进用户消息。agent 用 `read_file` 读取。不把文件正文塞进消息。

## 7. CI/CD（pi-D）

- 平台：CNB。沿用 studio 现有的 `.cnb.yml`。并列检出 studio 和 core，`pubspec.yaml` 不改。
- 触发：PR 和 push 跑 analyze + test。`tag_push`（`v*`）跑构建、签名、发布 APK。
- 签名：`android/app/build.gradle.kts` 读 `android/key.properties`。文件不存在时读环境变量。两者都没有时 release 构建失败，不回退 debug 证书。
- 密钥只存在两处：本机 `D:\Keystore`、CNB 的密钥配置。密钥和密码不进任何受版本控制的文件、提交信息、调研文档。
- gradle wrapper：CI 中生成，或把 wrapper 入库。由 pi-D 选一种并说明理由。
- core 历史同步：本地包含远端全部 49 个提交的等价补丁，另多 57 个提交。在独立 worktree 合并 `github/main`，结果树必须和本地 `main` 一致，然后 `main` 快进，再推送。不 force push。

## 8. 提交规则

- 基线：`research/baseline-studio.txt` 和 `research/baseline-core.txt` 记录了开工前的未提交改动。这些改动属于用户。
- 尽量不改基线里的文件。必须改时，改动保持最小，并在 `status/` 里登记文件名。
- 提交只暂存本任务的改动。基线文件里的用户改动不得进入提交。
- 提交信息用 Conventional Commits，英文，不带任何 AI 署名行。
- 实现阶段不提交。检查通过后由 pi-D 统一提交。大脑确认后才推送。

## 9. 回滚

- 新界面全部是新增文件，加上 `home_page.dart` 的导航改动。回滚时 revert 对应提交即可。
- core 历史同步在独立 worktree 完成。结果树不一致时放弃该 worktree，`main` 不受影响。

## 11. 返工设计（2026-11-14，覆盖 §3 导航与 §4 相关条款）

### 11.1 形态

- 入口不变：主页的项目或工作区 → `openEditorPage` → `EditorPage`。`home_page.dart` 不改。
- 没有项目页，没有会话入口页，没有独立工作台页。路由栈只有两层：主页、编辑器页。
- agent 嵌入 `EditorPage`。
- 离线产品（`StudioProfile.current?.offlineOnly == true`）不显示任何 agent 控件。门控条件与旧的 AI 菜单项相同。
- 术语：「Agent 面板」指编辑器页内的对话流加输入卡片。「编辑器列」指标签栏、代码区和底部面板。

宽屏（≥ 1100）：

```
┌──────────────┬───────────────────────────────┬────────────────────┐
│ [文件|会话]   │ 标签栏                         │ 会话标题  ＋  ⏵收起 │
│              │ 代码区                         │ ────────────────── │
│ 文件树 或     │                               │ 对话流              │
│ 会话列表      │ ───────────────────────────── │ ▍思考中… ━━━━━━    │
│              │ 终端/输出/问题（原有）           │ ┌ 输入卡片 ───────┐ │
│              │                               │ │ ＋ 权限 模型 强度 ↑│ │
└──────────────┴───────────────────────────────┴────────────────────┘
```

中屏（720–1099）：侧边栏常驻。主体用分段「编辑器 | Agent」二选一。

窄屏（< 720）：侧边栏是抽屉，抽屉里也有「文件 | 会话」。主体用分段「编辑器 | Agent」二选一。

### 11.2 嵌入点（editor_page.dart，只加不改）

1. 侧边栏：`_buildExplorerCard` 的两处调用（常驻槽和抽屉）外包一层分段容器。「文件」分段显示原文件树。
2. 右侧：`editor-body-wide` 的 `Row` 末尾加 Agent 面板（宽屏）。
3. 中屏和窄屏：body 顶部加分段条。下面用 `Offstage` 保活两块：原右列和 Agent 面板。
4. 入口：AppBar 加一个 agent 图标按钮。菜单里原有的 `ai` 项改为同一动作。
5. agent 启用时，不再显示旧的 `AiPanel` 底部面板。`_BottomPanel.ai` 的其他逻辑不动。
6. 状态：`_EditorPageState` 持有一个 `WorkbenchState`。首帧不创建 runtime 和 facade。第一次展开 Agent 面板时才创建。
7. 保活：编辑器列与 Agent 面板各用 `GlobalKey`。跨断点不重建。最小化再恢复时 Agent 面板状态保留。

### 11.3 删除与保留

删除，由 pi-A 执行：`lib/shell/project_entry.dart`、`lib/shell/workbench_shell.dart`、`lib/pages/project/`、`lib/sidebar/workbench_sidebar.dart`、`test/workbench_shell_test.dart`、`test/project_page_test.dart`。

删除前，把会话列表、分段和保活逻辑搬到 `lib/editor/agent/`。

保留并复用：`lib/chat/`、`lib/session/`、`lib/vibe_coding/vibe_agent_facade.dart`、`lib/layout/breakpoints.dart`、`lib/shell/workbench_state.dart`、`lib/shell/login_gate.dart`、`lib/shell/agent_runtime_factory.dart`、`lib/shell/workbench_agent_pane.dart`。

验收：`grep -rn "ProjectPage\|ProjectEntryPage\|openProjectPage\|WorkbenchShell" lib test` 没有结果。

契约：`WorkbenchAgentPane` 现有构造参数不删不改名。新增参数必须有默认值。

### 11.4 并行会话

接口已写进基线：`AgentLiveStatus` 与 `AgentRuntime` 的 5 个新成员（`vibe_agent_facade.dart`）。pi-B 实现，pi-A 和 pi-C 使用。

- 一个会话对应一个 `AgentFacade` 实例。运行时持有，按 `sessionId` 复用。
- 界面不得 dispose facade。切换会话只是换一个实例显示。
- 空闲且已读的实例超过 8 个时，销毁最久未用的。运行中的实例永不销毁。
- 并发上限默认 2，与服务端 `QFLI_AI_CONCURRENCY` 默认值一致。超出的请求排队，状态 `queued`。
- 服务端返回 429 时，按 1 秒、2 秒、4 秒退避，最多 3 次。仍失败则本轮失败。
- 路径租约：写某个路径前向运行时申请。被另一个运行中的会话占用时，返回冲突，文案「文件正被会话「X」修改，稍后再试」。租约在占用会话的本轮结束时释放。

### 11.5 会话列表（侧边栏「会话」分段）

- 顶部：「新会话」按钮。菜单里有「全部停止」。
- 每行：标题、相对时间、状态标记。运行中转圈，排队显示时钟，待确认显示橙点和「待确认」，失败显示红点，已完成未读显示蓝点。
- 行菜单：重命名、删除（二次确认）。删除运行中的会话时先停止它。
- 空状态：「还没有会话」加主操作「新会话」。
- 后台会话待确认或失败时，AppBar 的 agent 图标显示计数角标。
- 点选会话：Agent 面板显示它。窄屏同时切到 Agent 分段并关抽屉。调用 `markSeen`。

### 11.6 反馈、错误和输入卡片

发送：

1. 同一帧内：清空输入框，追加用户消息，发送键变停止键。
2. 对话流顶部显示不确定进度条。状态行写「思考中…」「正在读取 <路径>」或「排队中」。
3. 超过 3 秒，状态行追加「已等待 N 秒」。
4. 工具条目运行中显示转圈。完成后显示对勾或叉。

错误。文案写明原因和下一步，带「重试」，附折叠的「详情」显示状态码：

| 情况 | 文案 |
|---|---|
| 401 | 登录已过期，请重新登录 |
| 429 | 请求太频繁，已自动重试仍失败，请稍后再试 |
| 503 AI 服务未配置 | AI 服务暂未开通（服务端未配置），请联系管理员 |
| 网络不可用 | 网络不可用，检查网络后重试 |
| 超时 | 上游响应超时，重试一次 |

模型选择：

- 始终显示。加载中显示「模型…」和小转圈。
- 列表为空或失败：显示「默认模型」。点开说明原因并提供「重试」。
- 推理强度不被当前模型支持时隐藏。
- 选择按项目记住。

输入卡片：每个会话一个 `ComposerState`。切换会话时保留各自的草稿和附件。

### 11.7 会话存储与性能预算

设计见 `research/E-session-storage.md`。预算按桌面实测。鸿蒙平板由 pi-D 真机测。

| 项 | 预算 |
|---|---|
| 打开项目到编辑器页首帧 | 比改动前慢不超过 50 ms。agent 部分懒创建 |
| 会话列表加载（200 个会话） | ≤ 50 ms，只读索引 |
| 打开含 3000 条消息、20 MB 的会话，首屏数据 | ≤ 150 ms |
| 界面线程单次阻塞 | ≤ 16 ms。大于 200 KB 的 JSON 解析放独立 isolate |
| 发送到出现用户消息 | ≤ 100 ms，不含网络 |
| 追加一条消息落盘 | ≤ 5 ms，不重写整个文件 |
| 断网时打开已有会话 | ≤ 300 ms 显示历史 |
| 模型列表 | 有缓存时 0 ms。超时 8 秒。失败不阻塞任何流程 |

基准测试放 `tool/agent_session_bench.dart`。结果写进 status。

### 11.8 后端配置

转接模式需要服务端环境变量：

- `QFLI_AI_BASE_URL`：OpenAI 兼容根地址，必须 HTTPS。合规要求指向 DeepSeek 官方接口。
- `QFLI_AI_API_KEY`：上游密钥。
- `QFLI_AI_MODEL`：可选。默认 `deepseek-v4.1-flash`。
- `QFLI_AI_CONCURRENCY`：每用户并发，默认 2，上限 8。并行会话需要调大。
- `QFLI_AI_RATE_LIMIT`：每用户每分钟次数，默认 20，上限 600。并行会话需要调大。
- `QFLI_AI_REASONING_EFFORTS`：可选，逗号分隔，例如 `low,medium,high`。不配置则不显示推理强度。

写进服务端 `.env`。用 `docker compose up -d --force-recreate` 生效。缺 BASE_URL 或 KEY 时，`/api/ai/*` 返回 503「AI 服务未配置」。

### 11.9 流程（按顺序，缺一不可）

1. 阶段 1 实现：4 个 pi 各在独立 worktree 的分支上工作。分支 `rework/pi-a` 至 `rework/pi-d`，基线 `wip/baseline-20261114`。
2. 关卡 1（大脑）：检查范围、禁区、`flutter analyze`、测试。
3. 集成：大脑按 B、C、A、D 顺序合并到 `rework/integration`。
4. 阶段 2 交叉检查：pi-B 查 pi-A，pi-C 查 pi-B，pi-D 查 pi-C，pi-A 查 pi-D。依据 `briefs/CHECKLIST.md`。报告写到 `check/`。
5. 阶段 3 真机全流程：pi-D 在鸿蒙真机上跑完整流程并截图。
6. 关卡 2（大脑）：复查 diff，重跑测试，看截图，做 UI/UX 检查。
7. 合并到主仓库：大脑把集成分支相对基线的差异应用到主目录。不使用会覆盖用户改动的命令。

### 11.10 延后项：会话分支

每个会话一个分支，检查通过后合并。桌面用 git worktree。手机没有 git，用写时复制的叠加层：读取穿透到主项目，第一次写某个文件时才复制它，合并时只回写被改的文件。进入项目不复制任何东西。

设计由 pi-D 在 `research/G-agent-isolation.md` 给出，评审后再实现。

## 12. 第四轮设计补充：错误详情与真机排版（2026-11-14）

### 12.1 共享契约扩展

契约已合入集成分支 `318e443`。所有实现分支基于该提交开发：

```dart
enum AgentErrorPhase { dns, connect, tls, timeout, http, response, other }
class AgentErrorInfo {
  final AgentErrorKind kind;
  final int? statusCode;
  final String detail;
  final String host;
  final AgentErrorPhase phase;
}
abstract class AgentRuntime {
  Future<String> diagnoseConnection();
}
```

### 12.2 结构化错误处理与脱敏（pi-B）

- `ApiClient` AI 路径捕获握手、连接、超时和 HTTP 错误，填充 `ApiException.details`。
- `details` 记录步骤 `phase`、类型名、`osMessage`、主机、方法、纯路径、耗时与 `requestId`。
- 证书仅在命中过期或未生效时提示检查设备时间。握手断开时提示检查网络或服务器证书。
- `VibeAgentFacade.lastErrorInfo` 组装 `host`、`phase`、`statusCode` 与多行 `detail`。
- `detail` 严禁写入 `Authorization` 头、用户令牌、请求正文和 URL 查询串。

### 12.3 按需连接诊断与错误卡片（pi-B 与 pi-C）

- `ApiClient.probeConnection()` 与 `VibeAgentRuntime.diagnoseConnection()` 分三步探测 API 服务器。
- 探测步骤为域名解析、TCP 443 连接与 TLS 握手，每步超时 6 秒，最后输出排查结论。
- 探测只访问当前配置的 API 主机，不得探测第三方地址。
- 错误卡片标题使用带主机和步骤的友好文案。「详情」展开后用等宽字体显示并支持选中复制。
- 复制内容在 `detail` 末尾追加「复制于 <设备时间>」。
- 仅 `phase` 为 `dns`、`connect`、`tls` 或 `timeout` 时，卡片显示「诊断连接」按钮。
- 用户点击后界面转圈并运行诊断，把结果追加到详情下方。禁止自动发起诊断。

### 12.4 顶栏与工具行真机自适应（pi-A 与 pi-C）

- `EditorPage` 仅在宽屏（宽度 ≥ `Breakpoints.threePane`）在顶栏显示机器人图标和角标。
- 窄屏与中屏隐藏顶栏机器人图标，释放标题与文件路径宽度。菜单内保留「AI 助手」。
- 窄屏与中屏把待确认或失败数量角标挂到 `AgentPaneSwitcher` 的「Agent」分段按钮上。
- 424 逻辑宽下「编辑器 | Agent」分段不得溢出，可点击目标不小于 44×44。
- `ComposerCard` 工具行使用 `LayoutBuilder` 测量可用宽度，先显示全部分段文字。
- 可用宽度不足时依次收起推理强度文字和权限文字，模型名保留到最后。
- 小卡片或大字体下确保模型按钮受剩余宽度约束，不得撑破工具行。

### 12.5 续跑合入与验证顺序

1. 大脑清理残留测试进程，向四路 Pi 下发续跑指令并强制限制测试并发参数。
2. `pi-B`、`pi-C`、`pi-A` 完成各自工作区单元测试与提交，`pi-D` 汇报静态截图与真机状态。
3. 大脑检查范围与全量测试（关卡 1），按 B、C、A 顺序合并进 `rework/integration`。
4. 集成树由 `studio` 通过 `pubspec_overrides.yaml` 构建新版 HAP，并在真机复测 J1 至 J11。
5. 全部验收项与关卡 2 通过后，大脑将集成差异应用回主目录并收尾归档。
