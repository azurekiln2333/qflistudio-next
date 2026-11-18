# 返工阶段通用规则

覆盖 `RULES-impl.md` 中冲突的条款。

TASK = `D:\MyNewProjects\qflistudio\.trellis\tasks\11-12-agents-workbench`

## 用户的反馈（原话摘要）

- 项目打开后是一个列表。输入后发送，又跳到第二个页面。割裂。
- 应该是原来的编辑器页，加上 agent 的内容。不要重写多个套娃子页面。
- 发送后没有任何反馈，没有进度条，底部没有模型选择。
- 会话加载很慢。性能一定要好。
- 不能改变原来的逻辑。
- 一个会话绑定一个 agent。多个 agent 要能并行运行。

## 先读

1. `TASK\design.md` 第 11 节。
2. `TASK\briefs\CHECKLIST.md`。
3. 你的 brief。
4. 忽略此前会话里的旧设计。三层导航已作废。

## 你的位置

- 你在自己的 git worktree 里工作。路径在 brief 里。
- 你的分支是 `rework/pi-X`。基线是 `wip/baseline-20261114`。
- 不要写主目录 `D:\MyNewProjects\qfli_studio_core`。写了会触发告警。
- 文档例外。`status\`、`check\`、`research\` 写到 `TASK` 下。
- 在 worktree 里运行 `flutter` 命令。命令前先 `cd` 到 worktree。

## git

允许：`git status`、`git diff`、`git log`、`git add <明确路径>`、`git commit`。只在你自己的分支上。

禁止：

- `git add -A`、`git add .`
- `git reset`、`git checkout`、`git switch`、`git restore`
- `git stash`、`git clean`、`git rebase`、`git merge`
- `git branch -D`、`git worktree remove`、`git push`、`git tag`
- 改 remote。

提交信息：Conventional Commits，英文。没有 `Co-Authored-By`，没有 `Generated with`。

## 改文件

- 改既有文件前，先复制到 `D:\MyNewProjects\_scratch\pi-X\`。
- 用小块 Edit。不整文件重写。
- 不对既有文件运行 `dart format`。只格式化你新增的文件。
- 只改你的独占范围。别人的问题写进 status 的「请求」节。

## 测试

- 命令：`flutter analyze --no-pub`、`flutter test --no-pub`。
- 旧测试指基线里原有的测试文件。不得改它们的断言和步骤。旧测试失败，说明实现错了，改实现。
- 上一轮新增的测试属于各自的 owner，可以随实现演进，覆盖不得减少。它们是：`agent_session_test`、`ai_reasoning_effort_test`、`chat_*`、`composer_state_test`、`project_page_test`、`vibe_agent_facade_test`、`vibe_attachment_read_test`、`vibe_controller_agent_hooks_test`、`vibe_search_text_test`、`workbench_shell_test`、`support/fake_agent.dart`。
- 允许的既有失败：`test/editor_run_target_test.dart` 的 3 个。
- 新逻辑必须有测试。
- 没运行过的检查写「未验证」。不得写成通过。

## 其他

- 不开子代理。
- 密钥、令牌、密码不进任何文件和输出。
- 每完成一步，更新 `TASK\status\pi-X-rework.md`。四节：已完成、进行中、请求、未验证。不超过 60 行。
- 最后一条回复只写一行：`DONE <status 路径>` 或 `BLOCKED <原因>`。
