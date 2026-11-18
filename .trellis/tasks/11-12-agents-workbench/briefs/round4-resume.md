# 第四轮续跑指南（2026-11-14）

先读 `RULES-rework.md` 和你对应的轮次简报。

## 重要：防内存溢出约定

本机 12:20 因多路默认并发测试触发内存耗尽，孤立进程已由大脑清理。

1. 先运行 `flutter analyze --no-pub` 与你的新增专项测试。
2. 跑全量 `flutter test --no-pub` 时**必须限制并发**，二选一：`--concurrency=2` 或 `-j 1`。
3. 禁止使用无并发限制的默认 `flutter test --no-pub`。

## 允许的测试失败口径

worktree 全量测试目前固定存在以下 4 项已知外部失败，其余用例必须全通过：

1. `test/editor_run_target_test.dart`（3 项既有失败，RULES 允许）。
2. `test/interop_arkts_contract_test.dart`（1 项，因 worktree 同级缺完整 `qfli_java`，写入「未验证」即可）。

## git 与状态要求

- 本轮完成自测后，在自己分支 `rework/pi-X` 使用 `git add <明确路径>` 提交未提交代码。
- 遵守 Conventional Commits（英文），不带 AI 署名行。
- 写完状态文件（不超过 60 行），最后回复 `DONE <该路径>` 或 `BLOCKED <原因>`。

## 各 Pi 续跑检查单

### pi-A（`w37:pC`，`rework/pi-a`）

1. 检查现有未提交改动（`agent_dock.dart`、`agent_pane_switcher.dart`、`editor_page.dart`、`editor_top_bar_title_test.dart`）完整满足 `rework-round4.md` 顶栏与分段要求。
2. 运行 `flutter analyze --no-pub` 和 `flutter test --no-pub -j 1`（确认仅含上述 4 项已知外部失败）。
3. 按任务提交代码到 `rework/pi-a`，确认 `git status -s` 干净。
4. 写入 `TASK\status\pi-A-rework-4r.md`，回复 `DONE D:\MyNewProjects\qflistudio\.trellis\tasks\11-12-agents-workbench\status\pi-A-rework-4r.md`。

### pi-B（`w37:pH`，`rework/pi-b`）

1. 检查 `api_client.dart`、`connection_probe.dart`、`vibe_agent_facade.dart`、`agent_connection_error_test.dart` 满足 `rework-round4.md` 与 `diagnoseConnection` 全部要求（含脱敏与 6 秒超时）。
2. 运行 `flutter analyze --no-pub` 与 `flutter test --no-pub --concurrency=2`（确认仅含上述 4 项已知外部失败）。
3. 提交代码到 `rework/pi-b`，确认 `git status -s` 干净。
4. 写入 `TASK\status\pi-B-rework-4r.md`，回复 `DONE D:\MyNewProjects\qflistudio\.trellis\tasks\11-12-agents-workbench\status\pi-B-rework-4r.md`。

### pi-C（`w37:pG`，`rework/pi-c`）

1. 修复 `lib/chat/composer_card.dart` 与 `test/chat_composer_card_test.dart` 的两处失败。
   `_fitFor` 用 `_modelChipMinWidth`（106）做下界，窄宽剩余不足 106 时会溢出 8.4px。
   同时对齐 424 宽 gap 断言、可用宽度计算与折叠顺序。
2. 复跑 `chat_composer_card_test.dart`、`chat_transcript_test.dart`、`workbench_agent_pane_test.dart`。
3. 运行 `flutter analyze --no-pub` 与 `flutter test --no-pub --concurrency=2`（仅允许上述 4 项已知外部失败）。
4. 提交全部第四轮改动到 `rework/pi-c`，确认 `git status -s` 干净。
5. 写入 `TASK\status\pi-C-rework-4r.md`，回复 `DONE D:\MyNewProjects\qflistudio\.trellis\tasks\11-12-agents-workbench\status\pi-C-rework-4r.md`。

### pi-D（`w37:pJ`，`rework/pi-d`）

1. 不等待 30 分钟：在 `D:\MyNewProjects\qflistudio` 下单次探测 `tool/device_ui.sh wake` 与 `tool/device_ui.sh launch`。
2. 整理任务 1 产物：查看 `TASK\check\screens\final\`（48 张图），记录 `phase3-final.md` 四项修复的文件名与位置。
3. 分两种情况写 `TASK\status\pi-D-rework-4.md`（四节，不超过 60 行）：
   - **若设备已解锁**：复测干净新会话下的 J8（确认是否仍有重复用户气泡）。接着完成 J9 至 J11 与 `[agent-perf]` hilog 取证，汇总写进状态文件，回复 `DONE D:\MyNewProjects\qflistudio\.trellis\tasks\11-12-agents-workbench\status\pi-D-rework-4.md`。
   - **若仍报锁屏 `10106102`**：不要反复尝试解锁。把任务 1 证据与 `device/01` 至 `17` 已测结果（J1 至 J7、`[agent-perf]`、会话 2 重复气泡线索）写进状态文件。注明任务 2 从 J8 起因锁屏阻塞，最后回复：`BLOCKED 设备仍在锁屏（Task 1 与 J1-J7 证据已落盘 pi-D-rework-4.md）`。
