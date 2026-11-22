# Pi-D 交叉检查：技能发现、Trellis 上下文、Studio 主机

检查对象：`harness/pi-d`
- core 工作树 `D:/MyNewProjects/_wt/harness/pi-d/qfli_studio_core`，`harness/base..HEAD` = `56da9af`、`db47ef6`、`ec110b2`，16 个文件 +2812/−36。
- app 工作树 `D:/MyNewProjects/_wt/harness/pi-d/qflistudio`，`release/studio-git-ui-20261120..HEAD` 为空：**没有任何 app 源码提交**，只有 `flutter pub get` 改写的平台注册文件（未提交）。

对照材料：`prd.md`（R13–R15、AC9/AC10/AC12）、`design.md:88-99`、契约 `lib/harness/harness_host.dart`、`reports/brief.md` 的 Pi-D 段、`reports/pi-d.md`，以及 `.trellis/spec/frontend/vibe-skills.md`、`process-lifecycle.md`。

方式：只读。逐文件读 diff 与新增文件，未改对方工作树、未跑任何 git 写命令、未执行测试或构建（避免在该工作树生成 `.dart_tool`）。`pi-d.md` 里的 `flutter analyze` 结论我未复跑；以下全部来自代码阅读。

## 结论摘要

整体是这一轮里质量偏高的分支：契约文件**逐字节未改**（`git hash-object lib/harness/harness_host.dart` 与 Pi-C 工作树同为 `0a26aab6`），`lib/remote_control/**`、`pubspec.yaml`、wire 协议零改动，没有新增依赖，没有凭据或真实会话日志读取。Trellis 读取全部走 `followLinks: false` 的普通文件判断，任务文件有 64 KiB 上限，坏文件只跳过不炸整体；`pi-d.md` 的风险自述基本诚实且准确。

没有发现阻断合入的缺陷。问题集中在一处**潜在的安全路径**（执行仓库自带的 `get_context.py`）、`StudioAgentHost` 的几处契约语义偏差，以及若干既有缺陷被“5 个用户技能目录”放大的地方。另需要提醒 root：Pi-D 的 `.trellis` 规则入口与 `_wt/studio-git-integration` 里**尚未提交的同一段改动**重复，且 `StudioAgentHost` 与 Pi-C 的“内置 Agent”面板会导致同一批会话被列两遍。

## 一、问题清单

| # | 严重度 | 位置 | 问题 |
| --- | --- | --- | --- |
| 1 | **中高（安全，当前不可达）** | `lib/trellis/trellis_context.dart:108-160` | `preferPython` 会执行仓库自带的 `get_context.py`，无任何用户确认；目前无人开这个开关，一旦按 `design.md:97` 接线即成为“打开仓库就执行代码” |
| 2 | **中** | `lib/harness/studio/studio_agent_host.dart:125-137` | `open()` 不校验会话是否属于本项目，可跨项目打开（cwd、标题、转录全部错配） |
| 3 | **中** | `lib/harness/studio/studio_agent_host.dart:275-279` | `sendPrompt` 继承门面的“忙时静默 return”，用户输入被丢弃而界面已清空输入框 |
| 4 | **中** | `lib/harness/studio/studio_agent_host.dart:310`、`186-195`、`373-381` | 句柄状态只在门面通知时刷新，不跟随 `runtime.liveChanges`；同一套状态映射写了两份 |
| 5 | 低-中 | `lib/harness/studio/studio_agent_host.dart:282-288` | `reply()` 忽略 `requestId`，且任何非白名单字符串都当“拒绝”，过期回复可误决另一次确认 |
| 6 | 低-中 | `lib/vibe_coding/vibe_skills.dart:408` | `Directory.list()` 未包在 try 里：任一技能目录不可读会中断整次技能加载（既有缺陷，被 5 个新根目录放大） |
| 7 | 低 | `lib/harness/studio/studio_agent_host.dart:116-122` | `providers()` 的 `available` 恒为 true，未登录时也一样 |
| 8 | 低 | `lib/harness/studio/studio_agent_host.dart:140-151` | `launch()` 先建会话记录再鉴权，登出时留下空会话；`request.cwd` 与 `args` 被静默忽略 |
| 9 | 低 | `lib/harness/studio/studio_agent_host.dart:308-315` | 每条消息变化都把整份转录重扫一遍并逐条构造事件 |
| 10 | 低 | `lib/harness/studio/studio_agent_host.dart`（无失败事件） | `AgentLiveStatus.failed` 与 `lastError` 不产生转录事件，Agents 对话页看不到失败原因 |
| 11 | 低 | `lib/trellis/trellis_panel.dart:53-80` | 子任务递归无环保护（手改坏的 `task.json` 可致栈溢出）；返回类型可空却永不返回 null；`isEmpty` 忽略 `specIndexes` |
| 12 | 低 | `lib/vibe_coding/vibe_coding_controller.dart:475` | 控制器侧仍全量读技能正文，`use_skill` 已改成按需读盘，这里没跟上 |
| 13 | 备注 | `lib/vibe_coding/vibe_rules.dart:86-105` | `hasTrellisWorkflow` 与 `TrellisProject.hasWorkflow` 是两份实现，读取上限还不一致 |
| 14 | 备注 | `lib/vibe_coding/vibe_skills.dart` 顶部注释、枚举 | 技能来源扩到 5 个用户目录 + `pi`/`codex` 两个枚举值，`vibe-skills.md` §2/§3 未同步 |
| 15 | 备注 | `lib/harness/studio/studio_agent_host.dart:303-305` | `stop()` 只取消本轮，契约写的是“结束会话”，界面文案必须区分 |
| 16 | 备注 | `test/vibe_agent_facade_test.dart:437` | 该测试现在会读开发机真实 `$HOME` 的技能目录（`pi-d.md` 只修了 `vibe_coding_skills_test.dart`） |
| 17 | 备注 | 测试目录 | 若干关键路径无测试（见第三节） |

## 二、详细说明

### 1（中高）Python 上下文脚本是一条“打开仓库即执行代码”的路径

`lib/trellis/trellis_context.dart:108-160`：

```dart
const TrellisContextLoader({this.preferPython = false, ...});

Future<String> load(String projectRoot) async {
  if (!TrellisProject.hasWorkflow(projectRoot)) return '';
  if (preferPython) {
    final text = await _runScript(projectRoot);   // python ./.trellis/scripts/get_context.py
    ...
```

`_runScript` 直接用 `ProcessSupervisor.start('python', [script.path], workingDirectory: projectRoot)` 跑**仓库里自带的**脚本，没有任何用户可见的提示、信任确认或设置开关。`trellis_project.dart` 的文件头还写着“不执行脚本”，两处表述互相矛盾。

现状是**不可达**：全仓库只有 `test/trellis_context_test.dart:113` 传 `preferPython: true`，而那条用例的项目里没有 `get_context.py`，实际走的是“脚本不存在 → 回退 Dart 解析”。`VibeProjectAgentContext` 用的是默认 `const TrellisContextLoader()`，即恒为 false。

但 `design.md:97` 明确写“桌面版可选调用 `python ./.trellis/scripts/get_context.py`”，brief 也这么要求；只要 root 或后续任务把 `preferPython` 在桌面端打开（很可能顺手加上 `AppPaths.isDesktop`），就变成：用户打开任意一个克隆来的 Trellis 项目并发出第一条消息，Studio 就静默执行该仓库里的 Python。这与“只读文件”的既有安全模型不是一个量级。

建议（三选一，推荐第 2 个）：
1. 删掉 `_runScript` 与 `preferPython`，只保留 Dart 解析——Dart 路径已经能给出任务、阶段、规范索引，脚本带来的增量很小；
2. 保留但加门：`AppPaths.isDesktop` **且** 用户在设置里显式开启“允许运行项目脚本”，开启时弹一次确认说明会执行谁；未开启时显示“已跳过项目脚本”；
3. 若必须默认可用，至少加 `--` 之后的独立参数、固定脚本相对路径、把脚本哈希纳入提示，并让用户在界面上看到“正在运行 `.trellis/scripts/get_context.py`”。

无论选哪个，都要补一条用临时目录写真脚本的测试（含超时与杀进程），否则这条路径永远处于“写了但没人验证”的状态。

### 2（中）`open()` 不校验会话归属，可跨项目打开

`lib/harness/studio/studio_agent_host.dart:125-137`：

```dart
Future<HarnessSessionHandle> open(String sessionId) async {
  if (_disposed) throw StateError('StudioAgentHost has been disposed');
  final facade = await _runtime.open(projectId, sessionId);
  ...
```

`_runtime.open(projectId, sessionId)` 一路走到 `lib/vibe_coding/vibe_agent_facade.dart:1375-1381`：

```dart
Future<AgentFacade> _openNew(String projectId, String sessionId) async {
  final meta = _sessions.metaOf(sessionId);
  if (meta == null) throw ArgumentError...
  final root = _projectRootOf(projectId);     // 用的是传入的 projectId，不是 meta.projectId
```

也就是说：传入一个**别的项目**的 `sessionId`，会话能打开，`cwd` 却是当前项目的根，`info.cwd`/`projectRoot` 也跟着错。而 `StudioAgentHost` 的 `info` 来自 `_infoFor(sessionId)`（`meta?.title`），于是会出现“标题是 A 项目的会话、工作目录是 B 项目”的组合；Agent 的读写边界随后按 `projectRoot` 走，等于把 A 项目的对话接到 B 项目的文件树上。

`HarnessHub.openSession()` 正常只喂自己列表里的 id，但 hub 会恢复持久化选择、`sourceRef` 也可能来自旧数据；一旦 id 过期或被移动到别的项目，这里就会静默错配而不是报错。

建议：`open()` 里先 `final meta = _sessions.metaOf(sessionId); if (meta == null || meta.projectId != projectId) throw ArgumentError.value(sessionId, 'sessionId', '会话不属于本项目');`。三行，且能顺带覆盖 `launch()` 之后的路径。补一条测试：造两个项目的会话，跨项目 `open` 必须抛错。

### 3（中）`sendPrompt` 会把用户输入静默丢掉

`lib/harness/studio/studio_agent_host.dart:275-279`：

```dart
Future<void> sendPrompt(String text) async {
  final prompt = text.trim();
  if (prompt.isEmpty) return;
  await _facade.send(prompt, permission: _facade.permission);
}
```

`VibeAgentFacade.send`（`lib/vibe_coding/vibe_agent_facade.dart:809-813`）在 `running`/`cancelling`/`awaitingApproval` 时**直接 return**，不抛错、不排队、不给任何回调。契约里 `sendPrompt` 返回 `Future<void>`，调用方无从判断“发出去了没有”。

对 Agents 面板的后果是：用户在上一条还在跑（或正等他确认写入）时输入并回车，输入框被清空，转录里什么也没出现，模型也没收到。Pi-C 的对话框在 `working` 时仍可输入，这条路径是可达的。

建议：句柄里先判断 `_facade.state`，忙时抛 `StateError('会话正在运行，请先停止或等待')`，或在转录里补一条 `TranscriptRole.system` 事件说明“这条没有发出”；更好的做法是让 hub 在这一刻禁用发送。任选其一，但不要保持“静默成功”。

### 4（中）句柄状态不跟随 `liveChanges`，映射逻辑写了两份

`lib/harness/studio/studio_agent_host.dart:310`：

```dart
void _onFacadeChanged() {
  if (_detached) return;
  _status.value = _mapStatus(_runtime.statusOf(_facade.sessionId));
```

句柄只在**门面**通知时刷新状态。而运行时的活动状态（`queued`、`finishedUnread`、`failed`）是在 `AgentRuntime._onFacadeChanged`（`vibe_agent_facade.dart:1432-1457`）里算出来后 `_liveTick.value++`，再叠加调度器排队状态（`statusOf` 里 `_scheduler.isWaiting`）。有两种情况下门面不会通知、`liveChanges` 会通知：排队名额的进出（`queued`），以及状态被标记为“完成未读/失败未读”。此时 `handle.status` 会停在旧值，直到下一条消息来到。

同时 `_statusOf`（宿主，`studio_agent_host.dart:186-195`）与 `_mapStatus`（句柄，`373-381`）是逐字相同的两份 switch。以后加一个状态（例如“已取消”）很容易只改一处，列表和标题栏就会显示不同结果。

建议：句柄也监听 `_runtime.liveChanges`（`detach()` 时移除），映射函数收敛成文件级一个 `HarnessSessionStatus _mapStatus(AgentLiveStatus)`，宿主与句柄共用。补一条测试：不触发门面通知，只 `runtime.notifyLive()`，`handle.status` 也要变。

### 5（低-中）`reply()` 不校验 `requestId`，未知选项一律当拒绝

`lib/harness/studio/studio_agent_host.dart:282-288`：

```dart
Future<void> reply(HarnessReply reply) async {
  if (_facade.pendingApproval == null) return;
  final choice = reply.choice.trim().toLowerCase();
  final allow = choice == 'allow' || choice == 'yes' || choice == 'approve';
  _facade.resolveApproval(allow);
  _approvalKey = null;
}
```

契约里 `HarnessReply.requestId` 就是用来标识“回的是哪一次请求”的（`harness_host.dart` 注释：`[requestId] is set when the entry asks the user for an approval`）。这里完全没看它：只要此刻有**任意**一次待确认，就按 `choice` 决定放行还是拒绝。用户点的是旧卡片（例如重连后重放的 `approval:...` 事件），就可能把刚弹出的新确认拒掉。

另外 `choice` 走白名单，其余全部落到 `false`——`options` 里写的是 `['allow','deny']`，与实现一致；但以后加 `'always'` 之类的选项时，会静默变成拒绝。

建议：`if (reply.requestId != _approvalKey) return;`（或抛 `StateError`），并对未知 `choice` 拒绝执行而不是默认拒绝写入。补一条测试：先用旧 key 回一次，待确认必须仍然存在。

### 6（低-中）技能目录列举失败会炸掉整次会话

`lib/vibe_coding/vibe_skills.dart:400-414`：

```dart
final type = FileSystemEntity.typeSync(dir, followLinks: false);
if (type != FileSystemEntityType.directory) return const [];
final skills = <VibeSkill>[];
final entries = await Directory(dir).list(followLinks: false).toList();   // 未包 try
```

`typeSync` 挡掉了“不是目录”和符号链接，但**没有**挡掉“是目录但列不出来”（Windows 上的权限、被占用的挂载点、路径过长）。这一行在 `harness/base` 里就是这样，属于既有缺陷；但 Pi-D 把扫描根从 1 个用户目录扩到 5 个（`~/.qfli`、`~/.claude`、`~/.agents`、`~/.pi`、`~/.codex`），暴露面变成 5 倍，且这些目录都是**别的工具**建的，不归本产品管。

后果不是“少几个技能”：`VibeCodingController._run` 第 475 行 `_skills = await _agent.skills();` 在 try 之外，异常会冒出去，`_activeRun` 变成未处理错误，`phase` 停在 `running`，界面卡在“正在运行”。

建议：把 `list()` 与 `typeSync` 一起包进 `try { ... } on FileSystemException { return const []; }`，并在 `_run` 里对 `skills()`/`rules()` 各自兜底（读不到就退化为空列表，不阻断会话）。

### 7（低）`providers()` 恒报可用

`studio_agent_host.dart:116-122` 里 `available: true` 是硬编码。未登录时 `open`/`launch` 会抛 `AgentLoginRequired`，但 hub 的新建会话菜单仍然会把“内置 Agent”列为可选。建议按 `runtime` 的能力给出 `available:false`（例如 `models()` 抛登录异常时），或在 `HarnessHostState` 上体现登录态。

### 8（低）`launch()` 先建记录再鉴权，且忽略 `cwd`/`args`

`studio_agent_host.dart:140-151`：`await _sessions.create(...)` 在 `open()` 之前，`open()` 里的 `_runtime.open` 才检查 token。登出状态下会留下一条空会话记录（`pi-d.md` 已自述）。另外契约的 `HarnessLaunchRequest.cwd`/`args` 被静默丢弃——内置 Agent 目前确实只有“本项目”一种工作目录，但 hub 若按通用逻辑传了子目录，行为会与用户预期不符。

建议：先 `final handle = await openExistingOrCreate()` 的成功路径再落库，或失败时 `_sessions.delete(meta.id)`；`launch` 时若 `request.cwd` 不是本项目根，明确抛 `UnsupportedError` 而不是忽略。

### 9（低）每个 token 全量重扫转录

`studio_agent_host.dart:308-315`：每次门面通知都遍历整份 `_facade.messages`，为**每条**消息构造 `TranscriptEvent` 再比较文本。流式输出时这是每条增量一次 O(n) 分配，长会话（几百条）会明显发热。

建议：只从 `_lastPublishedIndex` 之后扫描（门面消息是追加式的），只在“同一条消息被改写”时才回头处理末尾那一条。

### 10（低）失败没有转录事件

`AgentLiveStatus.failed` 只映射成 `HarnessSessionStatus.unknown`，`facade.lastError`/`lastErrorInfo` 没有变成 `TranscriptEvent`。Agents 面板是通用对话视图，用户只会看到状态变成“未知”，看不到“余额不足/网络错误”这类原因。

建议：状态切到 `failed` 且 `lastError` 非空时，发布一条 `TranscriptRole.system` 事件（带稳定 id，例如 `error:<lastError>`，同一错误只发一次）。

### 11（低）任务面板的递归与返回类型

`lib/trellis/trellis_panel.dart:53-80`：

```dart
void append(String name, int indent) {
  final task = byName[name];
  if (task == null) return;
  rows.add(TrellisPanelTask(task: task, indent: indent));
  for (final child in task.children) {
    append(child, indent + 1);
  }
}
```

没有 visited 集合。`task.json` 是仓库里的普通 JSON，手改或脚本写坏完全可能出现 `children` 互指，结果是 `StackOverflowError`——面板直接崩，而 `TrellisProject.load` 对坏文件是“跳过不炸”的，两处健壮性不一致。

同一函数声明 `TrellisTaskPanel?` 并在注释里写“不是 Trellis 项目时返回 null”，但实现永远返回非 null（调用方 `trellis_project_test.dart:140` 还得写 `!`）。`TrellisTaskPanel.isEmpty` 只看 `currentTask` 与 `activeTasks`，忽略了 `specIndexes`，于是“有规范索引、没有活跃任务”的项目会显示“当前项目没有 Trellis 任务”。

建议：`append` 加 `final seen = <String>{}`，进入时 `if (!seen.add(name)) return;`；返回类型改成非空并同步注释；`isEmpty` 补上 `&& specIndexes.isEmpty`。

### 12（低）控制器侧还在全量读技能正文

`vibe_coding_controller.dart:475` 的 `_skills = await _agent.skills()` 走 `VibeProjectAgentContext.skills()`，那里构造 `VibeSkillLibrary(projectRoot: ..., language: ...)` **没有** `lazyBodies: true`。Pi-D 已经让 `_useSkill` 调用 `await match.resolveBody()`（`:1330-1350`），也就是说按需读盘这条路已经打通，但控制器没切过去。

于是每次 send 都会把最多 40 个 `SKILL.md`（每个最多 12 KiB）完整读一遍，而现在有 5 个用户目录 + 5 个项目目录要扫。建议把 `VibeProjectAgentContext.skills()` 也改成 `lazyBodies: true`，让索引与正文彻底分开——这正是 `vibe-skills.md` §3「提示词只放名称与描述，正文按需」想要的状态。

### 13（备注）两份 `hasTrellisWorkflow`

`vibe_rules.dart:86-105` 与 `trellis_project.dart:196-215` 是同一段判断，只有读取上限不同（`kVibeMaxRuleFileChars * 2` = 8192 vs 4 KiB）。Pi-D 为了让 `loadVibeRules`（同步、无 `dart:io` 依赖问题）能用，复制了一份。建议合并：`vibe_rules.dart` 直接调用 `TrellisProject.hasWorkflow`，或把判断抽到一个不依赖 `TrellisProject` 的小工具里。两份实现以后很容易只改一处（例如“空文件算不算”）。

### 14（备注）文档漂移：技能来源

`lib/vibe_coding/vibe_skills.dart` 现在有：
- `enum VibeSkillSource { user, projectQfli, claude, agents, pi, codex, builtIn }`；
- 用户级目录五个（`defaultUserSkillsDirs()`），项目级目录五个（`projectSkillDirNames`）。

`.trellis/spec/frontend/vibe-skills.md` §2 仍写 `enum VibeSkillSource { user, projectQfli, claude, agents, builtIn }`，§3 仍写「User skills come from `~/.qfli/skills`」「Project discovery checks `.qfli/skills`, `.claude/skills`, then `.agents/skills`」。这与 `design.md:90`、`brief.md` 的 Pi-D 段一致地**把实现做对了、把文档留在旧版**。

`vibe-skills.md` 属于 `vibe-agent-skills` 任务、状态是 `Draft`，Pi-D 不宜擅自改。建议 root 在集成时同步一次（枚举值、五个目录、优先级顺序、16 KiB 元数据读取、`resolveBody`），否则下一个人照文档写测试会直接失败。

### 15（备注）`stop()` 的语义与契约措辞不一致

契约：`/// Ends the session. Callers must get explicit user confirmation first.`
实现：`Future<void> stop() async { await _facade.cancel(); }` ——只取消本轮，会话记录保留，状态回到 `idle`。

对内置换算合理（内置 Agent 的“会话”是持久对话，删掉历史是另一件事），但 hub 侧必须把按钮文案写成“停止本轮”/“取消运行”，不能写“结束会话”，否则用户以为历史没了。Pi-D 在 `pi-d.md` 风险里也说明了这一点，属于需要在集成时落到文案与确认对话框里的事项。

### 16（备注）一个既有测试现在依赖开发机 home

`test/vibe_agent_facade_test.dart:437` 的 `'skills lists project skills for the sidebar'` 用 `runtime(_FakeRelay()).skills('p1')` 断言 `contains('demo')`。Pi-D 只给 `vibe_coding_skills_test.dart` 的三条用例加了 `includeUserSkills: false`；这条没加，而 `VibeAgentRuntime.skills()` 没有提供关闭用户目录的开关，所以它会扫真实 `$HOME`。断言用 `contains` 不会失败，但测试结果与耗时开始依赖开发机（`~/.codex/skills` 里若有几千个技能就会拖慢 CI）。

建议：`VibeAgentRuntime` 增加可注入的 `VibeSkillLibrary` 工厂或 `includeUserSkills` 参数，测试里关掉；至少在这条用例的注释里写明它读 home。

### 17（备注）测试缺口

已写的 47 条新测试覆盖面不错（检测、任务读取、上下文文本与截断、规则入口预算、斜杠命令、技能目录与懒加载、主机的列表/状态/打开/确认/停止/detach/launch/dispose）。缺的部分：

- Python 脚本路径：`_runScript` 成功、非零退出、超时杀进程，全部没有；现有那条“preferPython”用例实际走的是回退。
- 控制器集成：`_routeSlashCommand` 是否真的把**当前这一条**用户消息换掉、`_loadTrellis` 只读一次、Trellis 文本落在 `projectContext` 段，都没有测试。
- `VibeAgentRuntime.skills()` 的“只返回元数据”没有测试（那 2 行改动目前无覆盖）。
- 主机：登出状态下的 `launch`（空记录问题）、多个 `watchSessions()` 订阅者同时收到推送、`dispose` 之后再 `watchSessions()`/`open()`、`transcript` 在 `detach` 后返回 null 的行为只测了一半。
- `TrellisTaskPanelView` 没有 widget 测试，也从未被渲染过（`pi-d.md` 已自述）。

## 三、没有发现问题的项（已核对）

- **契约**：`lib/harness/harness_host.dart` 与 Pi-C 工作树对象哈希相同（`0a26aab6`），`harness/base..HEAD` 对该文件零 diff。Pi-D 没有改共享契约。
- **凭据与隐私**：没有读 `auth.json`、`.env`、token、真实会话日志。`.trellis/.runtime/sessions/*.json` 只取 `current_task` 与 `last_seen_at` 两个键，其余字段既不解析也不输出；`.trellis/.developer` 只取 `name=`。`buildTrellisContext` 会带上开发者名与任务标题——这属于 Trellis 上下文的本意，不是凭据。
- **wire 协议**：`lib/remote_control/**`、`lib/interop/**`、协议常量、请求 ID、重连语义均无改动。
- **进程生命周期**：唯一的外部进程在 `TrellisContextLoader._runScript`，走 `ProcessSupervisor.start`（符合 `process-lifecycle.md` §2），stdout/stderr 都排空，`finally` 里 `supervisor.dispose()`，超时先 `process.cancel()` 再返回 null。
- **文件读取边界**：Trellis 与技能目录的每个入口都有 `typeSync(..., followLinks: false)`；符号链接目录整份跳过，符号链接 `SKILL.md` 跳过，规则文件符号链接跳过，任务 `task.json` 超过 64 KiB 跳过并只宽松解码。
- **规则预算**：`used` 按 `section.length + 2` 记账（含分隔符），`join('\n\n')` 的实际长度恒为 `used - 2`，不会越过 `kVibeMaxRulesChars`；Trellis 入口先占位，长 `AGENTS.md` 挤不掉它（有测试）。
- **斜杠命令改写历史**：`send()` 在 `:403` 先 `_history.add({'role': 'user', ...})`，`:407` 才 `_run(prompt)`，所以 `_routeSlashCommand` 倒序找到的那条确实是本轮输入，不会改写上一条用户消息。
- **生命周期**：`_notify()` 有 `_disposed` 守卫；`_invalidateContextUsage()` 只清缓存不通知；`_loadTrellis`/`_routeSlashCommand` 之后 `_run` 会复查 `_cancelRequested || _disposed`。
- **订阅回收**：`StudioAgentHost.dispose()` 移除两个 `addListener`、detach 所有句柄、关闭所有 watcher、dispose `_state`；`StudioSessionHandle.detach()` 移除门面监听并关闭全部转录流，且幂等。`transcript` 的 `Stream.multi` 回放与注册之间没有 `await`，不存在丢事件的窗口。
- **Trellis 规则入口文案**：与 `_wt/studio-git-integration/qfli_studio_core` 里的 `_trellisBootstrap` **逐字节相同**（我做了字符串比对），合并后不会出现两套提示词。
- **无新增依赖**，`pubspec.yaml` 未改；新增代码没有 `print`/`debugPrint`/`TODO`/`FIXME`。

## 四、给 root 的集成注意

1. **两处“内置 Agent”会重复列会话。** Pi-D 的 `StudioAgentHost` 用 `id = 'studio'`、`providerId = 'studio'`，接进 hub 后会成为主机列表里的一个主机；而 Pi-C 的 `HubAgentsSurface` 已经有一个“内置 Agent”段（直接渲染编辑器原有的会话面板，数据源同样是 `AgentSessionStore`）。两者同时在线时，同一批会话会出现两遍，且两边各自 `open` 会拿到同一个门面实例、各自挂监听（功能上不冲突，但列表重复、状态标签可能不一致）。建议二选一：要么 hub 只用 `StudioAgentHost`、Pi-C 的内置段退回成“宿主入口”，要么不注册 `StudioAgentHost`。这与 AC1“统一列表”直接相关，需要明确决定。

2. **`StudioAgentHost.dispose()` 是终态。** 置 `_disposed = true` 之后 `open`/`launch` 永远抛 `StateError`，没有复活路径；而 Pi-C 的 `HarnessHub.dispose()` 会 `await host.dispose()`。所以 root 不能用应用级单例注册它，必须像 Pi-C 的文档要求那样“每个 hub 新建一份”（或改成引用计数）。否则关掉一个编辑器页，其他页的 Agents 面板全废。

3. **Trellis 规则入口与 `_wt/studio-git-integration` 里未提交的改动重复。** 那个工作树的 `lib/vibe_coding/vibe_rules.dart` 有 +35 行未提交改动，内容与 Pi-D 的 `kVibeTrellisRuleEntry` 完全相同，只是符号名不同（那边是私有 `_trellisBootstrap` / `_hasTrellisWorkflow`，这边是公开 `kVibeTrellisRuleEntry` / `hasTrellisWorkflow`）。线性重建时只保留一份，并注意 Pi-D 在 `vibe_coding_controller.dart` 的 `export ... show hasTrellisWorkflow, kVibeTrellisRuleEntry`。另：那边把 `budget >= notice.length` 和这边 `budget >= notice.length + 1` 有 1 字符差异，取更保守的那份。

4. **`HarnessHosts.registerDefault` 仍未接线。** Pi-D 的 app 工作树零提交，`StudioAgentHost` 目前没有任何引用方（我 grep 过 `lib/`，只有它自己）。合并时要在装配点补：
   ```dart
   HarnessHosts.registerDefault((context) => [
     StudioAgentHost(runtime: studioAgentRuntime(...), projectId: ..., projectRoot: ...),
     ...
   ]);
   ```
   注意 `StudioAgentHost` 是**按项目**构造的（`projectId` / `projectRoot` 是构造参数），一个 hub 对应一个活跃项目，不能跨项目复用。

5. **app 工作树里那 7 个平台注册文件未提交**（`linux/`、`macos/`、`windows/`），是 `flutter pub get` 的产物。Pi-D 有意不提交，集成时别误带进去。

## 五、未验证项

- 没有跑 `flutter test`、`flutter analyze`、`flutter build`。Pi-D 声称 `flutter analyze --no-pub lib` 干净，我未复跑。
- `TrellisTaskPanelView` 从未被渲染，窄宽度下的布局（`ListView` 嵌进侧栏、长路径 `_PathLink` 的省略）未验证。
- AC9（面板显示当前任务与阶段）、AC10（模型真的能 `use_skill` 读到项目 `SKILL.md`）、AC12（自动检查）仍属未验证：只有单元测试代码，没有执行记录，也没有一次真实的模型回合。
- Python 路径在上述前提下无法验证（既无测试，也无运行环境）。
