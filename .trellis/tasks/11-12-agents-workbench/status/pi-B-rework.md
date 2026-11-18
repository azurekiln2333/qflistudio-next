# pi-B 返工状态：会话存储、并行运行时、性能

分支 `rework/pi-b`，worktree `D:\MyNewProjects\_wt\pi-b\qfli_studio_core`。

## 已完成
- 存储 v2：`index.json` 加 `<id>.jsonl`。列表只读索引；打开只从尾部反向读 64 KB 块；写入追加一行，崩溃留下半行时先补换行。同 id 后写覆盖旧值。`AgentSessionStore` 原成员全保留，新增 `readTail/readBefore/readHistory/appendMessage/writeHistory/flush/compactIfNeeded`。
- 设计 10 条已全部落地：单条记录超 200 KB 走独立 isolate 解析；坏行过半时后台压缩重写；历史读取上限 200 条；工具输出落盘前截断到 8 KB（完整输出只在内存）；索引临时文件加改名、只在元数据变化时写。
- 顺带修一个真 bug：反向读在单行跨块时会丢整行（大历史快照读不出来），已修并有测试。
- 旧 `.json` 迁移：无索引时同步转换并建索引，有索引时后台补转，旧文件改名 `.json.bak`，结果写回索引。
- 打开路径：`runtime.open` 只读尾部一页（60 条），不解析全文、不碰网络；历史恢复推迟到第一次 `send`；`hasEarlier`/`loadEarlier()` 按 60 条分页。
- 发送反馈：`send` 同步段先放乐观用户消息并置 running，之后才读历史、写盘；标题更新不 await。
- `lastErrorInfo` 按状态码与 `details['code']` 分类，503 含「AI 服务未配置」→ `notConfigured`；`activity` 给出进行中工具文案。
- 模型列表：内存加 `models_cache.json`，10 分钟有效；`aiModels` 超时 90 s → 8 s；失败回退设置模型，不抛出。
- 打点 `[agent-perf] sessions.load|session.open|send.feedback|persist.append <ms>`，四个事件都已接上；`send.feedback` 本机实测 0 ms（预算 ≤100 ms）。
- 运行时：按 `sessionId` 复用实例，`liveChanges`、`statusOf` 六态、`markSeen`、`cancelAll`；空闲且已读超 8 个销毁最久未用（运行中永不销毁）；会话删除先 cancel 再销毁。
- 调度：`AgentRequestScheduler` 并发 2，超出排队（queued），429 按 1/2/4 秒退避最多 3 次，取消后不再重试。
- 租约：`ProjectWriteLeases` 冲突文案「文件正被会话「X」修改，稍后再试」，接既有 `shouldWrite`（`addWriteGuard`），本轮结束/取消/销毁释放。
- 顺带修一个真 bug：「已反馈、还没起来」的窗口点停止以前被忽略，现在不会启动本轮。
- 测试本范围 67 例全过：`agent_session_test` 18、`vibe_agent_facade_test` 20、`agent_hub_test` 10（E1/E4/E5/状态映射/复用/销毁上限/永不销毁运行中/cancelAll）、`agent_scheduler_test` 6（E6/E7）、`vibe_attachment_read_test` 13（改 1 处后缀 `.json`→`.jsonl`，断言不变）。
- 基准 `tool/agent_session_bench.dart`，200 会话、大会话 3000 条 25.4 MB：`sessions.load` 201→23 ms（≤50）、`session.open(3000)` 88→53 ms（≤150）、`persist.append` 89→0 ms（≤5），三项达标。
- `flutter analyze --no-pub` 无问题；全量 1557 通过、4 失败：`editor_run_target_test` 3（允许）、`interop_arkts_contract_test` 1（见「未验证」）。
- 检查项全部通过：E1、E4、E5（`agent_hub_test`）、E6、E7（`agent_scheduler_test`）、F1（基准三项达标）、F2（open 不触发网络，请求计数 0）、F3（追加不重写）、F4（迁移）、H3 单元侧（429 → `rateLimited` 加退避）；H3 的 widget 侧与最终文案属 pi-C。

## 进行中
- 无。

## 请求
- 契约新增（additive）：`AgentMessagePage`、store 的 6 个新方法、`AgentSessionMeta.messageCount/preview`、`VibeAgentRuntime(maxIdleFacades/pageSize/scheduler/cacheDir)`、`AgentRequestScheduler`、`ProjectWriteLeases`、`VibeProjectFiles.addWriteGuard`。
- `VibeAgentFacade` 构造参数 `restoredHistory` 删除，改为 `hasEarlier/scheduler/leases`，内容由注入的 store 读；请统一用 `runtime.open`，不要自己 new。
- 侧边栏要「排队中」实时刷新，监听 `runtime.liveChanges`（`statusOf` 会返回 queued）。
- 模型缓存写在 `agent_sessions/models_cache.json`，别清整目录。
- 会话文件后缀 `.json` → `.jsonl`，引用旧路径的代码或测试要改。

## 未验证
- 真机/桌面实测耗时（F6 的 hilog `[agent-perf]` 行）未做，只有本机 Windows 基准。
- `interop_arkts_contract_test` 在本 worktree 加载即失败：读工作区外 `_wt\pi-b\qflistudio\ohos\...\StudioInterop.ets`（不存在），只 import 未改动的 interop 代码，判断与本次改动无关，跨范围未修。
- 并行会话对真实服务端（并发上限、429、限流窗口）未验证。
- 租约只在 Windows 验过；跨平台大小写与符号链接归一未验。
- 压缩重写与 isolate 解析只在单元测试里验过（构造的坏行与 360 KB 历史快照），未在真机大文件上跑过。
