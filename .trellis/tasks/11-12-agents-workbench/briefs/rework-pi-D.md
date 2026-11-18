# pi-D：后端配置、真机工具、预览工具、隔离方案调研

先读 `RULES-rework.md`。

- core worktree：`D:\MyNewProjects\_wt\pi-d\qfli_studio_core`，分支 `rework/pi-d`
- status：`TASK\status\pi-D-rework.md`

## 目标

用户知道后端怎么配。每一步都能在真机上验证。会话分支有可评审的设计。

## 独占范围

- 服务端仓库 `D:\MyNewProjects\azurekiln-qfli-server`（用主目录，不用 worktree）：只改 `README.md`、`.env.example`、`docs\`。不改 `src\`、`test\`。
- studio 仓库 `D:\MyNewProjects\qflistudio\tool\`：只新增文件。不改已有文件。
- core worktree：`tool/agent_preview_test.dart`（新）。
- 文档：`TASK\research\G-agent-isolation.md`、`TASK\status\pi-D-rework.md`。

## 不得改

- core 的 `lib/**` 和 `test/**`。
- 服务端的 `src/**`、`test/**`。有必要改时，写进 status 的「请求」，等大脑决定。

## 任务 1：后端 API 与 KEY 配置

1. 读 `src/ai-client.js`、`src/routes/ai.js`、`docker-compose.yaml`、`.env.example`、`README.md`。
2. 在 README 的「AI 与联网工具」一节写完整配置步骤：
   - 变量表，参照 design.md §11.8。
   - `.env` 示例，值用占位符。
   - 重启命令：`docker compose up -d --force-recreate`。先检查 `docker-compose.yaml` 的 `env_file` 写法，确认命令正确。
   - 验证命令：`curl` 带登录令牌请求 `/api/ai/models`，说明 200、401、503 各代表什么。
   - 说明并行会话为什么要调大 `QFLI_AI_CONCURRENCY` 和 `QFLI_AI_RATE_LIMIT`。
3. `.env.example` 补 `QFLI_AI_REASONING_EFFORTS`，并发和限流变量加中文注释。
4. 用本地 mock 上游验证三种状态：未配置返回 503，已配置时 `/api/ai/models` 返回列表，`/api/ai/chat` 正常。mock 放 `_scratch\pi-d\`，不入库。不使用任何真实密钥。
5. 不读、不输出 `.env` 里的值。只报告变量是否存在。

## 任务 2：真机工具

设备已连接：`hdc list targets`。上一轮你构建并安装过 HAP，脚本在 `%TEMP%\buildhap2.bat`。

1. 把它固化成 `qflistudio/tool/build_studio_hap.sh`。不带 `--parallel`，自动使用 DevEco 自带 JBR。（你上轮问过要不要固化：要。）
2. 写 `qflistudio/tool/device_ui.sh`，封装 hdc：安装、启动、截图（`uitest screenCap`）、点击（`uitest uiInput click`）、输入文字、返回键、读 hilog 过滤 `[agent-perf]`。
3. 设备地址读环境变量 `HDC_TARGET`，不写死。
4. 在当前已装的版本上验证：启动，主页截图，点开一个项目，再截图。截图放 `TASK\check\screens\pi-d\baseline\`。
5. 构建 HAP 时，studio 通过相对路径依赖 core。集成后要构建的是集成分支。做法：在 studio 主目录放一个未跟踪的 `pubspec_overrides.yaml`，把 `qfli_studio_core` 指向集成 worktree。先用 `git check-ignore` 或写进 `.git/info/exclude` 确保它不会被提交。本阶段只写好脚本和说明，不要创建这个文件。

## 任务 3：预览工具

在 core worktree 写 `tool/agent_preview_test.dart`：

- 输入：场景名到 widget 的映射、尺寸列表、主题列表。
- 输出：PNG 到指定目录。
- 加载 MaterialIcons 与中文字体。参考 `qflistudio/tool/preview_test.dart`。
- 先用基线里的 `WorkbenchAgentPane` 和 `FakeAgentRuntime` 出 3 个场景，证明可用。输出到 `TASK\check\screens\pi-d\preview-baseline\`。
- 集成后，阶段 2 会用它出编辑器页的完整截图。

## 任务 4：会话分支的设计调研（只读，不写代码）

写 `TASK\research\G-agent-isolation.md`。开头写「结论」：能不能做，先写能或不能，再写证据。内容：

1. 现有 git 能力清单。读 `lib/services/git_service.dart`、`lib/pages/git_page.dart`、`lib/services/cloud_sync_service.dart` 里的 git 部分。
2. 平台矩阵：桌面（有 git）、桌面（无 git）、Android、iOS、鸿蒙、云端项目。每格写可行方案。
3. 方案 1：git worktree。命令序列、目录位置、忽略规则、异常处理。
4. 方案 2：写时复制叠加层。读取穿透到主项目。第一次写才复制。记录基线哈希。三方合并。运行或检查时才临时展开。进入项目不复制任何东西。
5. 合并前检查：有哪些检查可用（编辑器诊断、运行一次、agent 自检）。
6. 合并界面：差异视图、冲突处理。
7. 数据结构和存储位置。
8. 与会话的关系：创建会话时的选项，默认策略。建议：第一个运行的会话直接在项目里工作。第二个并行会话启动时，提示是否创建独立分支。
9. 工作量估计，按模块。风险。

## 提交

core worktree 里的新文件提交到你的分支。例：`feat(tool): add a preview exporter for agent scenes`。

studio 和服务端主目录的改动不提交，留给大脑。

## 完成标准

- 任务 1 到 4 全部有产出。每项在 status 里写证据。
- 没有任何密钥进入文件或输出。
