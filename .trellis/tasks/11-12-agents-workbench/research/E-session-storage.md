# 调研 E：会话存储与加载性能

## 结论

- 主流 agent 用追加写的 JSONL 存会话。一个会话一个文件。
- 本机实测：Claude Code、Pi、Codex 都是 JSONL。没有一个把会话正文放进 SQLite。
- SQLite 只出现在两处：Codex 的日志、队列、记忆库，和 Antigravity 的每会话库。
- 我们现在的实现每轮重写整个文件，启动时解析全部文件。加载慢的主因在这里。
- 决定：JSONL 加一个小索引文件。不引入 SQLite。
- 重估条件：基准测试达不到 design.md §11.6 的预算时，再评估 SQLite。

## 本机实测

只数文件、看后缀、读文件头。没有读任何对话内容。

| 工具 | 位置 | 格式 | 规模 |
|---|---|---|---|
| Claude Code | `~/.claude/projects/<项目路径编码>/<会话id>.jsonl` | JSONL，追加写 | 144 个 jsonl，0 个 SQLite。本项目最大一个 10.2 MB |
| Pi | `~/.pi/agent/sessions/<项目路径编码>/<时间戳>_<id>.jsonl` | JSONL | 680 个 jsonl |
| Codex | `~/.codex/sessions/年/月/日/rollout-<时间>-<id>.jsonl` | JSONL，旧文件压成 zstd | 952 个 zst，71 个 jsonl |
| Codex 其他数据 | `~/.codex/logs_2.sqlite`、`queue_1.sqlite`、`memories_1.sqlite`、`goals_1.sqlite` | SQLite | 日志、队列、记忆、目标 |
| Antigravity | `~/.gemini/antigravity/conversations/<id>.db` | SQLite（文件头已核对） | 每个会话一个库 |
| Antigravity 列表 | `~/.gemini/antigravity/conversation_summaries.db` | SQLite | 只存摘要，用于列表 |

未核实：Cursor、Zed、OpenCode、Cline。本机没有安装。

## 共同点

- 正文是只追加的日志。写一条消息只写一行。
- 列表不靠解析正文。Claude Code 和 Pi 用文件名和修改时间。Antigravity 用独立的摘要库。
- 崩溃时最多丢最后一行。读取时跳过坏行即可。

## 我们现在的实现（代码证据）

| 问题 | 位置 |
|---|---|
| `load()` 对每个会话文件做完整 `jsonDecode`，只为取 5 个元数据字段 | `lib/session/agent_session.dart:108-132` |
| `read()` 整文件解析，在界面线程完成 | `agent_session.dart:194-209` |
| 每轮结束重写整个文件，含 `messages` 与 `history` 两份内容 | `agent_session.dart:222-239`、`vibe_agent_facade.dart:437-461` |
| 改标题要读全文再整文件重写 | `agent_session.dart:170-179` |
| 打开会话前先串行等待模型列表与技能列表，网络超时 90 秒 | `lib/shell/workbench_agent_pane.dart:95-114`、`lib/services/api_client.dart:1228` |
| 模型列表为空时，输入卡片隐藏模型选择 | `lib/chat/composer_card.dart:367` |

## 目标设计

文件布局（根目录 `agent_sessions/`）：

- `index.json`：所有会话的元数据数组。每项含 id、项目 id、标题、创建时间、更新时间、消息数、一行预览。
- `<会话id>.jsonl`：第 1 行是头（版本、id、项目 id、创建时间）。之后每行一条记录。

读写规则：

1. 列表只读 `index.json`。不碰任何 jsonl。
2. 打开会话只读文件尾部。从末尾反向读 64 KB 块，凑够最近 60 条消息。
3. 向上滚动再分页读更早的消息。
4. 模型历史在第一次发送时才读，且受长度预算限制。纯查看不需要它。
5. 写一条消息就追加一行。同 id 的新行覆盖旧行。流式阶段节流，每 500 ms 至多写一次。
6. 回合结束时才 `flush`。
7. 超过 200 KB 的 JSON 解析放到独立 isolate。
8. 垃圾行比例超过 50% 时，空闲时后台压缩重写。
9. 工具输出落盘前截断到 8 KB。完整输出不落盘。
10. 索引文件写入用「临时文件加改名」。只在元数据变化时写。

迁移：

- 旧格式是 `<id>.json`。首次 `load()` 发现没有索引时，在后台逐个转成 jsonl 并建索引。
- 旧文件改名为 `.json.bak`。本版本不删除。

## 为什么不用 SQLite

- 主流 agent 的会话正文都不放 SQLite。
- 追加写 O(1)。SQLite 单行插入也快，但我们没有跨会话查询的需求。
- 本项目要在 Android、iOS、Windows、macOS、Linux、鸿蒙上运行。`pubspec.yaml` 现在没有任何 SQLite 依赖。鸿蒙上的 SQLite 插件支持未核实。
- JSONL 是纯 Dart，没有原生依赖。
- 以后要做跨会话全文搜索，再加 SQLite 作为可重建的派生索引。

## 未验证

- 上述预算在鸿蒙平板上的实际数字。需要 pi-B 的基准测试和 pi-D 的真机测试给出。
