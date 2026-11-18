# pi-B：会话存储、并行运行时、性能

先读 `RULES-rework.md`。

- worktree：`D:\MyNewProjects\_wt\pi-b\qfli_studio_core`
- 分支：`rework/pi-b`
- status：`TASK\status\pi-B-rework.md`

## 目标

会话列表和会话打开都快，且不等网络。多个会话可以同时运行。

## 独占范围

- `lib/session/**`
- `lib/vibe_coding/**`（含 `vibe_agent_facade.dart`）
- `lib/shell/agent_runtime_factory.dart`
- `lib/services/api_client.dart` 里的 AI 调用部分（`aiModels`、`aiChat`）
- `tool/agent_session_bench.dart`（新）
- 测试：`agent_session_*`、`vibe_*`、`agent_hub_test.dart`（新）、`agent_scheduler_test.dart`（新）

## 不得改

- `lib/chat/**`、`lib/editor/**`、`lib/pages/**`、`lib/shell/workbench_*`。
- 基线里原有的测试文件。

## 契约（已在基线里，只能加，不能删或改名）

- `AgentLiveStatus`、`AgentRuntime.liveChanges/statusOf/liveFacade/markSeen/cancelAll`：基线是占位，你来实现。
- `AgentFacade.lastErrorInfo/activity/hasEarlier/loadEarlier()`：基线是默认值，你在 `VibeAgentFacade` 里重写。
- `AgentRuntime.open` 的新语义写在它的文档注释里：同一 id 返回同一实例，调用方不得 dispose。

## 任务，按优先级

### P0 会话存储 v2 与打开路径

1. 读 `research/E-session-storage.md`。严格按「目标设计」10 条做。
2. 重写 `FileAgentSessionStore`：`index.json` 加 `<id>.jsonl`。`AgentSessionStore` 现有成员保留。新增分页读取，例如 `readTail`、`readBefore`。
3. 旧 `<id>.json` 迁移：后台转成 jsonl，旧文件改名 `.json.bak`。
4. `VibeAgentFacade.send`：先通知用户消息和 running 状态，再做任何磁盘 I/O。标题更新放到发送之后，不 await。
5. 历史恢复推迟到第一次发送。打开会话只读尾部的消息视图。实现 `hasEarlier`、`loadEarlier()`。
6. 实现 `lastErrorInfo`：把 `ApiException` 的状态码和 `details['code']` 映射到 `AgentErrorKind`。503 且文案含「AI 服务未配置」映射为 `notConfigured`。
7. 实现 `activity`：控制器正在运行的工具名和路径，例如「正在读取 lib/main.dart」。
8. `models()`：内存缓存加 `models_cache.json`，有效期 10 分钟。超时 8 秒。失败走回退，不抛出。`ApiClient.aiModels` 不再用 90 秒。
9. 打点：`[agent-perf] <事件> <毫秒>`，用 `debugPrint`。事件：`sessions.load`、`session.open`、`send.feedback`、`persist.append`。
10. 基准 `tool/agent_session_bench.dart`：200 个会话、其中 1 个 3000 条消息 20 MB。对比旧实现和新实现。数字写进 status。达不到 design.md §11.7 的预算，写原因和下一步。

### P1 并行运行时

11. `VibeAgentRuntime` 实现注册表：`open` 按 `sessionId` 复用实例。
12. `liveChanges`：任一实例状态变化时通知。
13. `statusOf` 映射：运行中为 running，排队为 queued，等确认为 awaitingApproval，失败且未看为 failed，完成且未看为 finishedUnread，其他为 idle。
14. `markSeen`、`cancelAll`。
15. 空闲且已读的实例超过 8 个，销毁最久未用的。运行中的永不销毁。
16. 会话被 `sessions.delete` 时，先 cancel 再销毁实例。

### P2 调度

17. 新文件 `lib/vibe_coding/agent_request_scheduler.dart`。每次模型请求前取名额，结束后归还。
18. 并发上限默认 2。超出的会话状态为 queued。
19. 429 按 1 秒、2 秒、4 秒退避，最多 3 次。

### P3 路径租约

20. 新文件 `lib/vibe_coding/project_write_leases.dart`。写某路径前申请租约。
21. 被另一个运行中的会话占用时，返回冲突结果，文案「文件正被会话「X」修改，稍后再试」。
22. 租约在占用会话的本轮结束、取消或销毁时释放。
23. 接到现有的 `shouldWrite` 钩子。

## 测试

- `agent_hub_test.dart`：E1、E5、状态映射、实例复用、销毁上限。
- `agent_scheduler_test.dart`：E6、E7。
- 存储：F2、F3、F4、坏行跳过、崩溃后只丢最后一行。
- 租约：E4。
- 发送反馈：C1 的数据侧（发送后同步段内 `messages` 含用户消息、`state` 为 running）。

## 提交

分多次提交到你的分支。例：`feat(session): store sessions as append-only jsonl with an index`。

## 完成标准

- CHECKLIST 的 E1、E4-E7、F1-F4、H3 通过。结果写进 status。
- P0 必须完成。P1、P2、P3 做不完的，在 status 的「未完成」里写清楚，不要假装完成。
- `flutter analyze --no-pub` 无问题。你的范围内测试全过。
