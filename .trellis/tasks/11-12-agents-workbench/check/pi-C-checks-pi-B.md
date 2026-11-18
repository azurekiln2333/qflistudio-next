# pi-C 检查 pi-B

检查 worktree：`D:\MyNewProjects\_wt\check-c\qfli_studio_core`（分支 `check/pi-c`，内容 `rework/integration` a43b7df）。
对象：pi-B 的会话存储、并行运行时、调度、租约、性能（`wip/baseline-20261114..rework/integration` 中 pi-B 六个提交）。
重点项：E1、E4-E7、F1-F4、H3，外加 analyze、全量测试、I1-I4、自设破坏性场景。

## 汇总
通过 12 项。不通过 1 项。未验证 1 项。（14 个清单项）
环境两项：`flutter analyze` 通过；全量 `flutter test` 通过（只剩允许的失败）。

## 结果
| ID | 结果 | 证据 |
|---|---|---|
| analyze | 通过 | `Analyzing qfli_studio_core... No issues found! (ran in 28.8s)` |
| 全量测试 | 通过 | `--concurrency=1` 串行：`+1604 ~9 -4: Some tests failed.` 失败仅 `editor_run_target_test` 3 例（允许）+ `interop_arkts_contract_test` 1 例（已知忽略）。`app_restore_gate_test` 的加载失败是并行跑时的线程耗尽抖动，单独跑 `+4: All tests passed!` |
| E1 | 通过 | `agent_hub_test.dart`「E1 two sessions run at the same time」：两个会话同帧 `running`，`liveFacade` 切换后原会话仍 running；我另跑 S1 三方并发也确认 |
| E4 | 不通过 | 正常路径过（`agent_hub_test`「E4 …」：乙拿到「文件正被会话…稍后再试」，`a.txt` 不存在，甲写成功）。但大小写变体绕过租约：真实 runtime 下端到端复现 —— 甲持 `a.txt` 租约卡在待确认，乙写 `A.TXT`（autoAcceptEdits）返回 `isError=false 「已创建 A.TXT」`，文件内容变成乙的正文。见「不通过项」与 S4 |
| E5 | 通过 | `agent_hub_test`「E5 deleting a running session stops it before destroying it」；实现 `_onSessionsChanged` 先 `facade.cancel().whenComplete` 再 `_destroy`（vibe_agent_facade.dart:1128 起） |
| E6 | 通过 | `agent_scheduler_test`「E6 caps concurrency and queues the rest」：`started==['a','b']`、`isWaiting('c')` 真、放行后接上；我的 S1 走真实 runtime 也复现 `[running, queued, running]` |
| E7 | 通过 | `agent_scheduler_test`：`attempts==4`、`delays==[1s,2s,4s]`；重试成功返回、非 429 不重试、取消后不重试 |
| F1 | 通过 | 我实跑 `flutter test tool/agent_session_bench.dart`：`sessions.load 旧201 新23 ms 预算50 通过`、`session.open(3000) 旧84 新57 预算150 通过`、`persist.append 旧84 新1 预算5 通过`；大会话 25409429 字节 |
| F2 | 通过 | `vibe_agent_facade_test`「opening a session never touches the network」：`relay.requestCount == 0`，消息照常显示 |
| F3 | 通过 | `agent_session_test`「appends one line per message instead of rewriting the file」：`after.startsWith(before)`、长度增、`"hdr"` 只 1 行 |
| F4 | 通过 | `agent_session_test`「migrates a legacy json file」：生成 `.jsonl`、`.json` 改名 `.json.bak`、再启动不重复转换 |
| H3 | 通过 | 单元：`vibe_agent_facade_test`「classifies API failures」`429 → rateLimited`；widget：`workbench_agent_pane_test`「H3 429 的文案正确」断言 `请求太频繁，已自动重试仍失败，请稍后再试`，文案源 `chat_transcript.dart:339` |
| I1 | 通过 | `git grep -nE "sk-[A-Za-z0-9]{10,}|Bearer …|password *[:=]" -- lib test tool` 无匹配；`status/`、`check/` 下的 md 同样无匹配 |
| I2 | 未验证 | 主目录 HEAD 与备份一致（`573d1b6`），但脏文件集合自备份后变了：少了 `lib/pages/home_page.dart`、`test/retained_editor_test.dart` 两个改动。是删改，不是新增，方向与「agent 写入主目录」不符，判断非 pi-B 所为。pi-A 独立记录同一时段主目录被写过 4 个文件（含这两项），两方取证一致：主目录确实被写过，但无法归因 |
| I3 | 通过 | `git reflog show rework/pi-b` 只有 6 个 commit + 一次 baseline 快进合并，无 reset/checkout/stash/rebase/clean。仓库别处有 `reset: moving to HEAD`，在其他 worktree 的 HEAD 上，不在 pi-B 分支 |
| I4 | 通过 | `git log --format=%B wip/baseline-20261114..rework/integration` 无 `Co-Authored-By`/`Generated with`/`Claude`/`GPT`/`Copilot` |

## 不通过项
- **E4**：`ProjectWriteLeases._keyOf`（`lib/vibe_coding/project_write_leases.dart:87-96`）只 `p.normalize` 并把 `\` 换成 `/`，**不做大小写折叠**。Windows 上 `a.txt` 与 `A.TXT` 是同一个物理文件，却映射成两个租约键，第二个会话直接放行。后果：两个会话可同时写同一文件，后写覆盖先写 —— 这正是 E4 要防的事。
  端到端证据（真实 `VibeAgentRuntime`）：甲持 `a.txt` 租约卡在待确认，乙写 `A.TXT` 返回 `isError=false`、文案「已创建 A.TXT · 13 B」，`a.txt` 内容变为「乙的正文」。负责人：pi-B。建议：`_keyOf` 末尾按平台折叠大小写（`Platform.isWindows/isMacOS` 时 `toLowerCase()`），并补一条大小写等价的单测。

## 我设计的破坏性场景
1. **S1 三方并发、上限 2**（真实 `VibeAgentRuntime` + `AgentRequestScheduler(maxConcurrent: 2)`）。结果：`[AgentLiveStatus.running, queued, running]`，`active=2 waiting=1`，放行后发满 3 个请求。通过，与 E1/E6 一致。
2. **S2 持租约时 `cancelAll()`，另一会话再写同文件**。甲的租约来自 `cancel()` 里的 `_releaseLeases()`。结果：取消后乙写入成功，`a.txt` 内容为「乙的正文」，没有冲突。通过。
3. **S3 半行崩溃**。写 5 条后追加无换行的半行 `{"t":"m","v":{"id":"m5","role":"u`，重开 store：条数仍 5、最后「第 4 条」、不抛；再追加一条后条数 6、最后「崩溃后追加」。通过，符合「崩溃后只丢最后一行」。
4. **S4 大小写变体**。`acquire('a.txt')` 后 `acquire('A.TXT')`。结果：`第一=true 第二=true 冲突=null`。**失败**，即上面的 E4。
5. **S5 E4 端到端**（真实 `VibeAgentRuntime`）。甲持 `a.txt` 租约卡在待确认，乙 `autoAcceptEdits` 写 `A.TXT`。结果：乙 `isError=false`、「已创建 A.TXT · 13 B」，`a.txt` 内容变为「乙的正文」。**失败**，坐实 E4 有真实用户影响。

（S1-S4 为临时文件 `tool/pi_c_scenarios_test.dart`，跑完已删除，未 `git add`。）

## 额外发现
- F1 的「旧实现」是基准脚本里内联重写的等价模拟（`tool/agent_session_bench.dart` 的 old 段），不是直接跑基线那个 `FileAgentSessionStore` 旧类。数字量级可信，但严格说不是同一个类对跑，报告里宜标注。
- `tool/agent_session_bench.dart` 跑时会刷出上千行 `[agent-perf]`；因为建数据时每次 `appendMessage` 都打点。不影响结果，读起来很吵，可只在正式测三段计时时才打点。
- E5 的测试断言的是「实例被销毁且不再 running」，用 `dispose → controller.dispose` 也能满足；「先 cancel 再 destroy」的顺序是靠读 `_onSessionsChanged` 代码确认的，不是断言出来的。建议补一条「删除时确实调用了 cancel」的断言。
- `AgentSessionStore`（基类）的 `appendMessage` 仍是读全文再 `write` 全量重写；正确性没问题，但若有人直接拿基类型用会退回慢路径。`FileAgentSessionStore` 已覆盖，仅提醒契约。
- I2 主目录脏集合变化（两个文件被还原）建议大脑在关卡 2 核一下是不是自己做的，避免误判为 agent 越界。pi-A 同时段独立取证一致；其中 `lib/pages/home_page.dart` 正是 B1 要守的文件，优先确认它当前内容。
