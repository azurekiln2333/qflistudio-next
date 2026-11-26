# 首页 Agents 标签：实施报告（Pi-C）

## 1. 结论

四个提交全部完成。父任务需求 9、10、11 各一个提交，接口另有一个前置提交。

- 接口提交 `76ab98b`：会话定位参数、设备信息类型、编辑器首帧行为。
- 需求 9 `03fd278`：hub 追加、索引模型、内置会话索引、快照、首页入口、点击跳转。
- 需求 10 `3fae3a8`：状态圆点的固定语义色与文字标签。
- 需求 11 `69ebd65`：会话详情页与文案。

静态检查结果：`dart format` 无改动，`flutter analyze --no-pub` 只剩两条基线已有的 info。
本机未跑测试，测试交给云端 CI。

## 2. 裁定落地对照

| 裁定 | 落地 |
| --- | --- |
| R1 会话参数 | `HarnessSessionTarget` 是唯一入口。`openEditorPage` 与 `EditorPage` 各加参数。目标主机是内置 Agent 时设置 `WorkbenchState.sessionId`，其它主机走 `hub.openSession`。 |
| R2 首页含内置会话 | `StudioSessionIndex` 只读 `agent_sessions/index.json` 的元数据，不读 `.jsonl`。状态统一 `idle`。 |
| R3 状态圆点 | `harnessStatusDotColor` 给五个固定色，未知返回 null 画空心圈。圆点带文字语义标签与长按提示。 |
| R4 设备信息 | 线上字段 `hostName`、`os`、`osVersion` 与 Dart 字段同名。类型由本任务定义。内置 Agent 主机实现 `HarnessDeviceHost`。远程主机的解析留给 `11-23-device-sync`。 |
| R10 文件归属 | 只改 `harness_host.dart`、编辑器两个文件的会话参数，未碰 `project.dart`、`project_store.dart`、`Info.plist`。 |
| R11 顺序 | 先接口，再需求 9、10、11。每个提交单独可回滚。 |

## 3. 需求 9：首页 Agents 标签

### 3.1 变更

1. `HarnessHub` 追加三个方法：
   - `listenAll()`：订阅全部主机，重复调用无副作用。
   - `watchSessions()`：全部会话的合并流，订阅时先发一帧。
   - `openSessionById()`：按主机 id 与会话 id 打开，超时抛 `HarnessHubException`。
2. 新增 `AgentsIndexRow` 与三个纯函数：`harnessStatusRank`、`agentsHostLabel`、`buildAgentsIndex`。
   另加 `sortAgentsRows` 与 `dedupeAgentsRows` 供首页合并使用。
3. 新增 `StudioSessionIndex`：读 `index.json`，映射成 `HarnessSessionInfo`。
   坏条目跳过，文件缺失或损坏返回空表，不写回文件。
4. 新增 `AgentsSnapshotStore` 与 `AgentsSnapshotWriter`：schema 1，最多 100 行，写失败不抛错，写入防抖 2 秒。
5. 新增 `HomeAgentsTab`：先读快照，再订阅 hub，最后读内置索引。
   列表按状态、更新时间、标题排序。下拉可刷新。
6. 首页项目条最左加 `home-agents-tab` 按钮，位置在 `TabBar` 外。
   项目主体用 `Offstage` 保活，切回时页签与滚动位置都在。
7. `openAgentSession`：用会话目录匹配本地项目，匹配不到时取最近的本地项目，一个都没有时弹说明。
   跳转时传 `harnessSession` 与首页那份 hub。

### 3.2 文件

- `lib/harness/hub/harness_hub.dart`
- `lib/harness/hub/agents_index.dart`（新增）
- `lib/harness/hub/studio_session_index.dart`（新增）
- `lib/harness/hub/agents_snapshot.dart`（新增）
- `lib/harness/ui/home_agents_tab.dart`（新增）
- `lib/harness/ui/agents_entry.dart`
- `lib/pages/home_page.dart`
- `lib/i18n/studio_localizations.dart`
- `test/harness/agents_index_test.dart`（新增）
- `test/harness/studio_session_index_test.dart`（新增）
- `test/harness/agents_snapshot_test.dart`（新增）
- `test/harness/home_agents_tab_test.dart`（新增）

### 3.3 提交

`03fd278 feat(home): list every agent session on the Home Agents tab`

## 4. 需求 10：状态圆点

### 4.1 变更

1. `harnessStatusDotColor`：待确认橙、运行中绿、空闲灰、已完成蓝、已结束红、未知 null。
2. `harnessStatusDotBorderColor`：实心状态与填充同色，未知用主题前景色画空心圈。
3. 首页列表的圆点改用这两个函数，并带 `Semantics` 标签与 tooltip。
4. 原有 `harnessStatusColor` 未改，Agents 面板的旧界面不受影响。

### 4.2 文件

- `lib/harness/ui/hub_status.dart`
- `lib/harness/ui/home_agents_tab.dart`
- `test/harness/hub_status_dots_test.dart`（新增）
- `test/harness/home_agents_tab_test.dart`

### 4.3 提交

`3fae3a8 feat(home): give agent status dots fixed semantic colours`

## 5. 需求 11：会话详情

### 5.1 变更

1. 新增 `AgentSessionDetailsPage`：五个字段，缺值显示「未知」，路径可选中复制。
2. 列表行尾加详情图标，键为 `agents-details-<rowKey>`。
3. 文案三语补齐：详情标题、未知、设备名、系统、系统版本、主机类型、会话路径。

### 5.2 文件

- `lib/harness/ui/agent_session_details_page.dart`（新增）
- `lib/harness/ui/home_agents_tab.dart`
- `lib/pages/home_page.dart`
- `lib/i18n/studio_localizations.dart`
- `test/harness/agent_session_details_test.dart`（新增）
- `test/harness/home_agents_tab_test.dart`

### 5.3 提交

`69ebd65 feat(home): add an agent session details view`

## 6. 接口提交（前置）

### 6.1 变更

1. `harness_host.dart` 追加 `HarnessDeviceOs`、`HarnessDeviceInfo`、`HarnessDeviceHost`、`harnessDeviceOf`。
2. 新增 `device_info.dart`：`harnessDeviceOsOf` 与 `currentDeviceInfo`。
3. 新增 `harness_session_target.dart`：`HarnessSessionTarget`。
4. `StudioAgentHost` 实现 `HarnessDeviceHost`，设备信息取当前设备。
5. `openEditorPage` 追加 `harnessSession` 与 `harnessHub`。
6. `EditorPage` 追加 `initialHarnessSession`、`harnessHub`、`ownsHarnessHub`，并在首帧后选中会话。
7. `RetainedEditorController` 的会话记录带上目标与外来 hub。

### 6.2 文件

- `lib/harness/harness_host.dart`
- `lib/harness/device_info.dart`（新增）
- `lib/harness/harness_session_target.dart`（新增）
- `lib/harness/studio/studio_agent_host.dart`
- `lib/editor/retained_editor_host.dart`
- `lib/editor/editor_page.dart`
- `test/harness/device_info_test.dart`（新增）
- `test/editor_harness_session_target_test.dart`（新增）

### 6.3 提交

`76ab98b feat(harness): open a named session on the editor first frame`

完整哈希写在 `contract-c.done`。

## 7. 静态检查结果

| 检查 | 范围 | 结果 |
| --- | --- | --- |
| `dart format` | 本任务改动的全部文件 | 无待格式化文件 |
| `flutter analyze --no-pub` | 全仓库 | 2 条 info，均为基线已有：`composer_card.dart` 的 `curly_braces_in_flow_control_structures`、`harness_host.dart` 的 `unnecessary_import` |
| `flutter pub get` | core 工作树 | 通过 |
| 现有测试 | 全仓库 | 未改动任何现有测试文件 |

`ste-lint-zh.py`：`design.md` 与 `implement.md` 硬违规 0 处，本报告同样通过。

## 8. 真机验证需求

需要真机：

1. 手机与电脑配对后，首页 Agents 能看到电脑上的会话，端标注是设备名。
2. 内置会话出现在首页索引里，状态显示「空闲」。
3. 六种状态圆点在深色与浅色主题下都能区分，长按能读到状态名。
4. 点会话后编辑器首帧停在 Agent 面板，选中的就是该会话。
5. 窄屏首帧落在 Agent 分段。
6. 内置会话跳转后落在内置 Agent 面板，不是 Hub 列表。
7. 详情页显示设备名、系统、版本与路径，小屏不截断。
8. 切回项目列表后页签与滚动位置未丢。

不需要真机：排序、快照、内置索引、文案、契约。

## 9. 已知限制与后续

1. 内置会话状态只有 `idle`。索引不读运行态，真状态要接运行时。
   后续任务接运行态时只改 `StudioSessionIndex` 的映射。
2. 设备名来自 `Platform.localHostname`，安卓上多是 `localhost`。
   平台通道版本留作后续：通道 `qflistudio/platform`，方法 `deviceInfo`，字段与本报告同名。
3. 首页 hub 只服务 Agents 标签。项目卡片入口仍由编辑器自建 hub。
   共用 hub 留作后续，避免一次改动同时碰两处入口。
4. 快照只保留 100 行。更大的列表要分页，本任务不做。
5. 内置会话索引的 provider 固定为 `studio`，与 `kStudioProviderId` 一致。
   若后续改标识，首页与编辑器要一起改。

## 10. 回滚

按提交反向 revert 即可。

- 回滚 `69ebd65`：首页列表回到没有详情入口的样子。
- 回滚 `3fae3a8`：圆点回到主题色。
- 回滚 `03fd278`：首页回到纯项目列表，hub 只留接口提交后的样子。
- 回滚 `76ab98b`：会话参数与设备信息类型一起消失，编辑器回到基线。

每个提交都只碰自己的文件，回滚不需要解决冲突。