# B：agent harness 可行性调研

## 结论

能做，不需要新建 harness。core 已有一套可用的 agent 循环（工具、skill、计划、守卫、取消），
缺的是接线、权限模式、检索工具、会话持久化、模型与推理参数。

- **harness 放 core 层**。studio 是薄壳：`qflistudio/lib/main.dart:7` 只 import `app.dart`，自身 `lib/` 无 AI 代码。
- **已有循环**：`qfli_studio_core/lib/vibe_coding/vibe_coding_controller.dart:84`，工具 7 个
  （`vibe_tools.dart:569-689`），skill（`vibe_skills.dart:184`），计划与守卫、取消（`:587`）。
- **最大缺口**：这套 harness 没有 UI。`VibeCodingController` 只在测试里构造，`VibeCodingPanel`
  零引用；编辑器接的是 `lib/editor/ai_panel.dart:146`（单轮问答 + 流式文本，无工具）。
- **R7 是接线 + 补缺口，不是从零造**。

| R7 子项 | 现状 | 证据 |
| --- | --- | --- |
| 同一套循环与工具 | 有 | `vibe_coding_controller.dart:84`、`vibe_tools.dart:569` |
| skill | 有，仅项目级 + 内置 | `vibe_skills.dart:38-40,172-175` |
| 权限模式 | 没有 | 全仓无 permission mode 概念 |
| 读/写/编辑/列目录 | 有 | `vibe_tools.dart:569-637` |
| 会话持久化 | 没有 | 全仓无会话存储 |
| 模型列表 | 服务端有，客户端没接 | `server/src/routes/ai.js:15` vs `api_client.dart` 无调用 |
| 推理强度 | 没有 | 无 reasoning/effort 字段；服务端只放行 `messages/tools/model`（`ai-client.js:178`） |

## 1. core 的本地路径与 studio 的用法

- 路径依赖：`qflistudio/pubspec.yaml` → `qfli_studio_core: path: ../qfli_studio_core`。
- 真实路径：`D:\MyNewProjects\qfli_studio_core`（包名 `qfli_studio_core`）。
- studio 用法：`qflistudio/lib/main.dart:7` import `app.dart`，另引 `project_templates.dart:8`、
  `interop_runner.dart:9`、`studio_profile.dart:11`、`auth_store.dart:13`、`project_store.dart:14`、`settings_store.dart:15`。界面、编辑器、终端、AI 全在 core，R2-R6 改造面主要在 core。

## 2. 现有 AI 能力

| 项 | 有/没有 | 位置 |
| --- | --- | --- |
| 模型调用路径 | 两条：服务端转接 + 用户直连 | `api_client.dart:1227` `aiChat`；relay 走 `/api/ai/chat`（`:1244`），direct 走 `_aiChatDirect`（`:1259`） |
| 鉴权 | relay 用登录 bearer 令牌；direct 用用户自填 apiKey | `_send` 的 `token:` 参数；`ai_service.dart:102` `headers(protocol, apiKey:)` |
| 流式输出 | 仅普通问答有，agent 循环没有 | `ai_service.dart:577` `chat`（Chat 协议 SSE，`isEventStream` 判定 `:144`）；`relayChat` 非流式退化为分段；循环侧 `aiChat` 一次返回完整回复 |
| tool calling 循环 | 有 | `vibe_coding_controller.dart:298` 调 `aiChat`，`:347` 回写 `tool_calls`；`CONTRACT.md` 记 8 轮上限 |
| 会话持久化 | 没有 | 消息只在内存；无会话存储文件 |
| 模型列表 | 服务端有接口，客户端未接 | `server/src/routes/ai.js:15` `GET /api/ai/models`；`api_client.dart` 无对应方法 |
| 模型参数 / 推理强度 | 模型 relay 固定、direct 可填；推理强度两边都没有 | `CONTRACT.md`「客户端从不发模型」；direct 用 `settings_store.dart:117` `aiModel`；服务端 `ai-client.js:178` 只允许 `messages/tools/model` |
| 文件附件/引用 | 没有 | 无附件模型；`read_file` 由模型按路径取 |
| skill | 有 | `vibe_skills.dart:184` `load()`；源 `.qfli/skills`、`.claude/skills`、`.agents/skills`（`:38-40`）+ 内置 `assets/skills/*`（`:172-175`）；`use_skill` 工具 `vibe_tools.dart:684` |
| 联网工具 | 仅 `web_fetch` | `vibe_web_tools.dart:68`；`web_search` 已下线（`:257`） |
| 终端工具 | 有，云端隔离 | `run_command` → `api_client.dart:907` `terminalEvents`；不本机执行 |

## 3. R7 推荐架构

**harness 放 core**。理由：studio 无 AI 代码（`main.dart:7`）；R2-R6 的界面也在 core
（`editor_page.dart`、`pages/`）；跨平台一致性靠单一 Dart 实现即可。

- 层次：`core/lib/agent/`（新，从 `vibe_coding/` 迁并）← UI（core `pages/`）← studio 壳。
  服务端只做模型转接与联网代理，不放工具循环（工具要读写本地文件）。
- 工具集：现有 6 个 + 新增 `search_text`（grep 式，带路径/模式/上限）+ 保留 `web_fetch`。
  终端保持云端，作为移动端唯一可用执行方式（见第 6 节）。
- 权限模式：`readOnly` / `askEveryWrite` / `autoAcceptEdits` 三档，落在 `VibeProjectFiles` 的
  `shouldWrite` 钩子（`CONTRACT.md` 的 commit-point hook 已存在）；只读模式在写工具入口直接拒绝。
- skill：沿用 `SKILL.md` + YAML front-matter（`vibe_skills.dart:14`），新增用户级 `~/.qfli/skills`，
  优先级 用户级 < 项目级 < 内置；注入只放 name+description，正文由 `use_skill` 按需取（40 条 / 4 KiB）。
- 上下文管理：保留 8 轮预算；按 token 估算压缩——较早轮次换成「已读文件 + 工具结果摘要」，
  保留最后 N 轮原文；中断用 `cancel()`（`:587` 已补齐孤立 `tool_calls`）；重试只在无副作用时重放同轮。

## 4. 接口草案（Dart）

```dart
enum AgentPermissionMode { readOnly, askEveryWrite, autoAcceptEdits }

class AgentModelOption {
  const AgentModelOption({required this.id, required this.label, this.reasoningEfforts = const []});
  final String id, label;
  final List<String> reasoningEfforts;          // 空表示该模型不支持
}

abstract interface class AgentModelCatalog {
  Future<List<AgentModelOption>> models();      // 服务端 /api/ai/models 或本地配置
  Future<List<String>> reasoningEfforts(String modelId);
}

abstract interface class AgentTool {
  String get name;
  String get description;
  Map<String, Object?> get inputSchema;         // JSON Schema，直接给模型
  bool get mutatesWorkspace;                    // true 走权限模式判定
  Future<AgentToolResult> run(AgentToolRequest request);
}

class AgentToolRequest {
  const AgentToolRequest({required this.callId, required this.arguments, required this.permission});
  final String callId; final Map<String, Object?> arguments; final AgentPermissionMode permission;
}

class AgentToolResult {
  const AgentToolResult({required this.text, this.isError = false, this.changedPaths = const []});
  final String text; final bool isError; final List<String> changedPaths;
}

abstract interface class AgentSkillSource {
  Future<List<AgentSkillRef>> index();          // 只 name + description
  Future<String?> body(String name);            // 正文按需
}

abstract interface class AgentSessionStore {
  Future<List<AgentSessionMeta>> list(String projectId);
  Future<AgentTranscript> load(String sessionId);
  Future<void> save(AgentTranscript transcript);
  Future<void> delete(String sessionId);
}

abstract class AgentHarness {
  AgentHarness({required AgentModelCatalog catalog, required AgentSessionStore store,
      required List<AgentTool> tools, required List<AgentSkillSource> skills,
      AgentPermissionMode permission = AgentPermissionMode.askEveryWrite});
  List<AgentMessage> get messages;
  AgentRunState get state;                      // idle/running/cancelling/failed
  AgentPermissionMode get permission;
  set permission(AgentPermissionMode value);
  Future<void> send(String text, {List<String> attachedPaths = const []});
  Future<void> cancel();
  Future<void> retryLastRound();                // 仅无副作用时可用
  Future<void> compact({int keepRecentRounds = 3});
  void dispose();
}
```

`AgentHarness` 是 `VibeCodingController` 的接口化重构，`send/cancel/dispose` 语义与 `CONTRACT.md` 一致。

## 5. 最小可用范围与工作量

MVP（R7 验收必需）：

- 把 `VibeCodingController` 接到编辑器右侧/窄屏页签（小）——`VibeCodingPanel` 已就绪。
- 权限模式三档 + `shouldWrite` 接线（小）；`search_text` 工具（小）。
- 项目级 skill 与登录门控（`tokenProvider`）已可用，零改动（`CONTRACT.md` 已规定）。

后续项：会话持久化 + 会话列表（中，R2/R4 依赖）；模型列表与推理强度（中，需客户端接
`/api/ai/models`、服务端放行 `reasoning_effort`）；上下文压缩（中）；用户级 skill（小）；附件（中，R3 加号）。

## 6. 风险与未验证

- **未验证**：harness 未在任何平台接线过，`VibeCodingPanel` 零 UI 引用，真机体验无数据。
- **未验证**：`GET /api/ai/models` 未从客户端调用过，返回结构与权限未知；`reasoning_effort`
  服务端只允许 `messages/tools/model`（`ai-client.js:178`），加参数必须改服务端（测试覆盖未查）。
- 风险：`dart:io` 全平台可用，但移动端项目根在沙箱内（`vibe_tools.dart:8` 用 `dart:io`），
  用户经系统选择器引入的外部目录可能拿不到持续权限——未验证。
- 风险：本地终端在移动端不可用（`local_shell_io.dart:75` `localShellAvailable` 对
  ohos/android/ios 一律 false），`run_command` 只能走云端终端；离线时必须降级为明确错误。
- 风险：`web_fetch` 是唯一联网工具且为直连抓取，移动端网络权限差异未验证。
- 风险：现有 8 轮上限与 4 KiB 规则上限对长任务偏紧，压缩策略落地前可能频繁触顶。
