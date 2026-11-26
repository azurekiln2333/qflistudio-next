# 实现计划：Agent 思考过程实时流式显示

## 0. 规则（派给 Pi 的第一份说明里原样写入）

- 禁止破坏性 git 操作：`reset`、`checkout --`、`restore`、`stash`、`clean`、切分支、改写历史、force push。
- 只用显式路径提交：`git add <路径>`。不用 `git add -A` 或 `git add .`。
- 提交信息只写 Conventional Commits 的标题和正文，不加 `Co-Authored-By` 或 Generated with 行。
- Pi 不推送、不打标签。推送由大脑的编排脚本做。
- Pi 不在本机跑测试套件（`flutter test`、`node --test`）。测试写好后交给云端 CI 跑。本机只允许 `dart format` 和对改动文件跑 `flutter analyze`。
- Pi 只在自己的 worktree 里改动，不碰主目录：`D:\MyNewProjects\qflistudio`、`D:\MyNewProjects\qfli_studio_core`、`D:\MyNewProjects\azurekiln-qfli-server`、`D:\MyNewProjects\_wt\integration`。
- 密钥只从进程环境读，不写进文件、测试样本、日志或提交。
- 中文注释和文档按受控中文写，提交前跑 `python D:/MyNewProjects/qflistudio/scripts/ste-lint-zh.py <文件>`。

## 1. 分工

Pi 在 herdr 工作区 w37。每个 Pi 发 `/new` 后，先发 `/model newapi/deepseek-v4.1-flash`，再发派工说明。

| Pi | 窗格 | 范围 | worktree | 分支 |
|---|---|---|---|---|
| A | w37:pC | 服务端：design §3 | `D:\MyNewProjects\_wt\thinking\server\azurekiln-qfli-server` | `thinking/server`，基于 `main` `d919a91` |
| B | w37:pH | 传输与三种协议适配、设置字段：design §2、§4 | `D:\MyNewProjects\_wt\thinking\pi-b\qfli_studio_core` | `thinking/transport`，基于契约提交 |
| C | w37:pG | Agent 循环、历史、消息模型、会话压缩：design §5 | `D:\MyNewProjects\_wt\thinking\pi-c\qfli_studio_core` | `thinking/loop`，基于契约提交 |
| D | w37:pJ | 思考气泡、设置页开关：design §6、§4.4 的界面部分 | `D:\MyNewProjects\_wt\thinking\pi-d\qfli_studio_core` | `thinking/ui`，基于契约提交 |

文件归属（避免冲突）：

- B：`lib/services/ai_service.dart`、`lib/services/api_client.dart` 的 AI 部分、`lib/store/settings_store.dart`。
- C：`lib/vibe_coding/vibe_coding_controller.dart`、`vibe_models.dart`、`vibe_agent_facade.dart`、`agent_request_scheduler.dart`、`lib/session/agent_session.dart`。
- D：`lib/chat/chat_transcript.dart`、新增 `lib/chat/thinking_bubble.dart`、`lib/pages/settings_page.dart` 的直连区域。
- 契约文件 `lib/services/ai_turn_event.dart` 由大脑在第 2 步写好。之后谁要改它，先告诉大脑。

## 2. 阶段

### 阶段 0：准备（大脑）

1. `python ./.trellis/scripts/task.py start .trellis/tasks/11-19-agent-thinking-stream`。
2. 内核契约提交：
   - 在 `rework/integration`（`b7f3d40`）上建分支 `thinking/contract`，用独立 worktree `_wt/thinking/contract/qfli_studio_core`。
   - 写入 `lib/services/ai_turn_event.dart`（design §2）。
   - 给 `AiChatResult` 加 `reasoning` 字段。
   - 给 `VibeMessage` 加 `kind`、`durationMs`。
   - 给 `AgentMessageView` 加 `durationMs`，`role` 文档加 `reasoning`。
   - 给 `ApiClient` 加 `aiChatStream`。先实现为回退版本：调用 `aiChat`，再发出单个 `AiTurnCompleted`。这样 C 和 D 不用等 B 也能开发和测试。
   - 新增 `.github/workflows/core-check.yml`：所有分支推送时运行 `flutter pub get`、`flutter analyze`、`flutter test`。Flutter 版本按 `pubspec.yaml` 的 SDK 约束选定并写死。
   - 推送 `thinking/contract` 到 github 远端，确认 CI 通过后再往下走。
3. 从契约提交建 B、C、D 的 worktree，从服务端 `main` 建 A 的 worktree。每个 worktree 先跑 `flutter pub get` 或 `npm ci`。
4. 真机构建用的 App 基线：按第 0 节规则，不碰主目录，把 `qflistudio` 当前工作区快照成本地分支 `wip/thinking-app-baseline`：
   - 用临时 `GIT_INDEX_FILE`，依次运行 `git read-tree HEAD`、`git add -A`、`git write-tree`、`git commit-tree`、`git branch`。
   - 这个分支只在本地，永不推送。它包含未提交的鸿蒙签名设置。

### 阶段 1：实现（A、B、C、D 并行）

每个 Pi 完成后，在 `D:\MyNewProjects\_wt\thinking\reports\pi-<x>.md` 写报告：改了什么、新增了哪些测试、未解决的问题。然后创建完成标记 `pi-<x>.done`。

编排脚本看到完成标记后，把该分支推送到 github 远端，等 GitHub Actions 结果，写入 `reports/ci-<x>.txt`。CI 失败时，脚本把失败日志的末尾发给该 Pi，让它修复后重新标记完成。

- **A**：
  - 新路由、SSE 组装、NDJSON 写入（复用终端的背压逻辑）、空闲和总时长超时、`reasoning_content` 的检查与转发、`/chat` 带回 `reasoning_content`、审计、README 变量表。
  - 测试用本地假上游。覆盖思考、正文和工具增量，`result` 结构，各项超限，空闲超时。
  - 还要覆盖：客户端断开时中断上游、keep-alive 注释行、旧 `/chat` 不变、非 assistant 角色带 `reasoning_content` 返回 400。
- **B**：
  - 中转 NDJSON 解析和 404/405 回退。
  - 直连三种协议的流式编码和 SSE 解析。
  - 上游返回 JSON 时整体解码。
  - Chat 回传 `reasoning_content`，Messages 回传 `reasoning_blocks`。
  - `aiThinking` 设置字段。
  - 首字节和空闲超时，中断。
  - 测试用录制的 SSE 样本，每种协议一组，放在 `test/fixtures/ai_stream/`。样本里不能有真实密钥或真实用户内容。
- **C**：
  - 控制器消费事件流。
  - 思考消息生命周期（design §5.1 的 5 步）和 50 毫秒合并刷新。
  - 调度器名额覆盖整个流。
  - 取消与失败时保留已显示内容。
  - 历史字段的清洗和 448 KiB 字节预算裁剪。
  - `AgentMessageView` 的 `reasoning` 往返。
  - 会话文件压缩（20 份快照或 8 MiB）。
  - 测试用假的 `aiChatStream`，覆盖以上每一项。
- **D**：
  - `ThinkingBubble`：自动展开和收起、用户覆盖、计时、恢复时收起、AI 标记、44×44 点击区域。
  - 设置页的「请求思考过程」开关，只在直连区域出现。
  - 测试用 widget test 覆盖以上每一项，文字缩放 1.3 下也要通过。

### 阶段 2：大脑审查（关卡 1）

- 逐个读四个 Pi 的 diff 和报告。对照 design 和 prd 的 AC。
- 不通过的打回原 Pi 返工，写明问题和期望。

### 阶段 3：集成

1. 在 `_wt/thinking/integration/qfli_studio_core` 建分支 `thinking/integration`，从契约提交依次合并 B、C、D。
2. 删掉契约里 `aiChatStream` 的回退实现，接上 B 的真实实现。
3. 跑内核全量检查（第 3 节）。

### 阶段 4：交叉检查

轮换：A 查 D，B 查 A，C 查 B，D 查 C。检查人只写报告 `reports/check-<x>-by-<y>.md`，不改代码。发现问题交回原 Pi 修。

### 阶段 5：真实接口验证

- 用户提供了网关 `https://newapi.azurekiln.cn` 和一个密钥。密钥只放进当次命令的环境变量，不写进文件、报告、派工说明或提交。
- 2026-11-19 探测时这个密钥返回 401「无效的令牌」。拿到可用的密钥前，这一步阻塞，其余阶段照常推进。
- 验证内容：
  - 中转：用 `QFLI_AI_BASE_URL` 指向网关，本地启动 A 的分支，跑一次三轮工具调用，验证 AC2。
  - 直连 Chat：直接请求网关，确认思考、正文和工具调用的流式格式。
  - 顺带核实 design §9 的前两项。
- 这是一次性探测脚本，不是测试套件，跑完即删。

### 阶段 6：服务端上线

- 服务端集成后 CI 通过，大脑直接把 `thinking/server` 合入 `main`，升 `package.json` 的补丁版本，推送到 github 和 cnb，打 `vX.Y.Z` tag，等 CI 通过。用户已授权，不再询问（prd D8）。
- 推送 `main` 即上线生产。上线后用 `curl -X POST https://qfli.suanxiwanjie.cn/api/ai/chat/stream` 确认返回 401，不是 404。

### 阶段 7：真机全流程检查

1. 建 App 构建对：`_wt/thinking/app/qflistudio`（基于 `wip/thinking-app-baseline`）和 `_wt/thinking/app/qfli_studio_core`（基于 `thinking/integration`）。两者并列，`../qfli_studio_core` 直接解析到集成内核，不需要 `pubspec_overrides.yaml`。
2. `tool/build_studio_hap.sh --debug`，`tool/device_ui.sh install`，设备地址从 `HDC_TARGET` 读。
3. 跑 AC1、AC3、AC6、AC7、AC8，每项截图存到 `.trellis/tasks/11-19-agent-thinking-stream/check/screens/device/`。
4. 跑 AC14：用假上游推 300 KB 思考内容，同时滚动对话列表，用 `tool/device_ui.sh` 读性能日志，记录帧耗时分布。
5. 设备锁屏导致启动失败时，暂停并通知用户解锁，不写「已验证」。

### 阶段 8：大脑终审（含 UI/UX）

- 看全部截图：气泡层级、配色是否弱化、收起后的高度、计时文案、深浅两种主题、窄屏 280 px。
- 不通过的回到阶段 1 的对应 Pi。

### 阶段 9：落地

- 把 `thinking/integration` 合入 `rework/integration`（`_wt/integration/qfli_studio_core`），用普通 merge，不用会覆盖已有改动的命令。
- 合并前检查 `11-15-agent-chat-usability` 有没有在 `rework/integration` 上新增提交。有冲突时在 `thinking/integration` 上先合 `rework/integration` 解决，再合回去。
- 更新规范（Trellis 3.3）：
  - `.trellis/spec/frontend/ai-protocols.md`：流式事件契约、三种协议的 SSE 映射、思考内容回传。
  - `.trellis/spec/backend/ai-terminal-pool.md`：`/chat/stream`、`reasoning_content` 白名单、空闲超时。
- 内核：CI 通过后把 `rework/integration` 推送到各远端，不再询问。
- App 发版 tag 不在本任务里自动打。原因：应用 CI 用内核 `main` 构建，发版要先把 `rework/integration` 合进内核 `main`，这会把其他进行中任务的改动一起发出去。用户说发版时再做。

## 3. 检查命令

全部在 GitHub Actions 上运行：

- 服务端：现有工作流 `.github/workflows/build-and-push.yml` 的 verify 任务（`node scripts/ci-common.mjs verify`，内含 lint 和 `node --test test/*.test.js`）。
- 内核：新增的 `.github/workflows/core-check.yml`（`flutter analyze`、`flutter test`）。

本机只做两件轻量检查：

```bash
git diff --check
python D:/MyNewProjects/qflistudio/scripts/ste-lint-zh.py <文件>
```

## 4. 编排

- 派工后不轮询。启动一个后台脚本，等四个 `.done` 标记都出现后退出。Pi 空闲超过 3 分钟且没有标记时，提醒一次让它继续。
- herdr 命令在 Git Bash 里加 `MSYS_NO_PATHCONV=1`。
- 用 Monitor 监视三个主目录的 `git status` 和文件内容哈希。主目录一旦出现非用户本人的改动，立即停下所有 Pi。

## 5. 回滚点

| 位置 | 回滚方式 |
|---|---|
| 契约提交 | 删 `thinking/*` 分支即可，`rework/integration` 没动 |
| 各 Pi 分支 | 打回返工，或丢弃该分支重派 |
| 服务端生产 | 按服务端 README 把 `QFLI_SERVER_IMAGE` 固定到上线前的 digest。新客户端自动回退到 `/chat` |
| `rework/integration` 合并 | `git revert -m 1 <合并提交>`，不改写历史 |

## 6. 风险

- `chat_transcript.dart` 也是 `11-15-agent-chat-usability` 的改动范围。阶段 9 处理合并冲突。
- DeepSeek 默认模型可能不思考，那样 AC1 要换成会思考的模型来验收。阶段 5 核实。
- 思考内容很长时，`SelectableText` 重排可能卡顿。D 要用 300 KB 的样本在真机上看滚动是否流畅。
