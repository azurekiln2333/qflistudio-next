# Wire-C：内置会话显示真实状态（W3）

## 1 问题

首页 Agents 标签的内置会话状态恒为 `idle`。
`StudioSessionIndex.read` 把状态写死。
磁盘上的 `index.json` 没有运行中进程的信息，真状态要问运行时。

同时不能为了这个列表就启动运行时。
`studioAgentRuntime(...)` 会建运行时，不能直接调。

## 2 改动

### 2.1 只读运行时入口（`lib/shell/agent_runtime_factory.dart`）

新增 `AgentRuntime? currentStudioAgentRuntime()`，返回已装配的 `_cached`。
没跑过时返回 `null`，不建运行时。

### 2.2 索引接受状态回调（`lib/harness/hub/studio_session_index.dart`）

`read` 增加可选参数 `HarnessSessionStatus Function(String sessionId)? statusOf`。
有回调时用回调结果，没有时保持 `idle`。
本函数自己不建运行时。

新增顶层函数 `studioSessionWithStatus(session, status)`。
只换状态，其余字段原样搬过去。
运行时活动状态变化时用它就地改状态，不重读磁盘。

旧文档注释里「本任务不引入第二个运行时」「一律给 idle」两句已改为当前行为。

### 2.3 首页接运行时（`lib/harness/ui/home_agents_tab.dart`）

- 新增可选参数 `runtime`，测试注入假运行时用。
- 新读法 `_liveRuntime`：`widget.runtime ?? currentStudioAgentRuntime()`。
  不调 `studioAgentRuntime`。
- 新方法 `_statusOfStudioSession`。
  没有运行时给 `idle`。
  有运行时给 `mapStudioLiveStatus(runtime.statusOf(id))`。
- `_loadStudioSessions` 先 `_watchRuntime()`，再读索引并传 `statusOf`。
- `_watchRuntime` / `_unwatchRuntime` 挂、摘 `runtime.liveChanges` 监听。
- `_onRuntimeChanged` 只就地改 `_studioSessions` 的状态再 `_rebuild()`。
- `dispose` 先摘监听再释放写手。

状态映射复用 `mapStudioLiveStatus`，没有第二份映射表：

| `AgentLiveStatus` | `HarnessSessionStatus` |
| --- | --- |
| `running` / `queued` | `working` |
| `awaitingApproval` | `blocked` |
| `finishedUnread` | `done` |
| `failed` | `unknown` |
| `idle` | `idle` |

## 3 文件

| 文件 | 说明 |
| --- | --- |
| `lib/shell/agent_runtime_factory.dart` | 新增 `currentStudioAgentRuntime()` |
| `lib/harness/hub/studio_session_index.dart` | `read` 增加 `statusOf`。新增 `studioSessionWithStatus` |
| `lib/harness/ui/home_agents_tab.dart` | 运行时接入口、状态回调、活动状态监听 |
| `test/harness/studio_session_index_live_status_test.dart` | 新增，6 个用例 |
| `test/harness/home_agents_tab_live_status_test.dart` | 新增，6 个用例 |

已有测试一个都没改。

## 4 提交

`4d3ab46e74770e1a74c09128b7f5950b5295388a`
`feat(home): show live studio session status on the Agents tab`

只提交上表 5 个路径。
未提交同工作树里别人的改动：`lib/editor/editor_page.dart`、`lib/harness/ui/agents_entry.dart`、`lib/sync/` 下的新文件。
没有生成的文件被带入。

## 5 静态检查

| 检查 | 范围 | 结果 |
| --- | --- | --- |
| `dart format` | 5 个改动文件 | 3 个文件被格式化，无遗留 |
| `flutter analyze --no-pub` | 5 个改动文件 | `No issues found!` |
| `flutter analyze --no-pub` | `lib/harness` `lib/shell` `test/harness` | 仅 1 条既有 info `unnecessary_import`（`harness_host.dart:6`，改动前就在） |

没有跑 `flutter test`，测试留给云端 CI。

## 6 测试覆盖

`studio_session_index_live_status_test.dart`：

1. 不传 `statusOf` 时一律 `idle`。
2. 传了 `statusOf` 时用运行时给的状态。
3. `statusOf` 只影响状态，其余字段照旧。
4. `statusOf` 抛错不吞错。
5. `studioSessionWithStatus` 只换状态。
6. 原对象不变。

`home_agents_tab_live_status_test.dart`：

1. 没有运行时保持 `idle`。
2. 运行时在跑时 `working` / `blocked` / `done` / `idle` 四态分别对上。
3. 运行时状态变化后列表跟着变，且索引文件删掉后行仍在（证明没重读磁盘）。
4. `queued` 也算 `working`。
5. 运行时没见过的会话仍是 `idle`。
6. 内置会话行仍按状态排序（`blocked` < `idle` < `done`）。

## 7 未做与边界

- 应用侧（`qflistudio`）没有改动。
  `HomeAgentsTab` 的调用方不传 `runtime`，走 `currentStudioAgentRuntime()` 自动读取。
  逻辑全在 core，无需接线。
- 首页只看已装配的运行时。
  用户没进过 Agent 页面时运行时不存在，此时按需求保持 `idle`。
- 真机复核项：
  打开 Agent 页面跑起来后切回首页，圆形状态点应反映 `working`。
  等审批时应为 `blocked`。