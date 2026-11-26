# 交叉检查：首页 Agents 标签（Pi-D）

检查对象：`11-23-home-agents-tab`（父任务 `11-23-mobile-files-agents`），
含 `reports/wire-c.md` 的接线（W3 内置会话真状态）。

代码基线：`D:/MyNewProjects/_wt/mobile/int`，分支 `mobile/integration`。
检查前 core HEAD 为 `664d90e`，app HEAD 为 `5526d6a`。

结论：需求 9、10、11、12 主路径已落地，可修缺陷 6 处，全部已修并各自提交。
另有 3 处记录为残余风险，未改代码。

## 1. 检查范围

读了这些文件：

- 任务文档：`prd.md`、`design.md`、`implement.md`。
- 父任务：`prd.md`、`reports/plan-review.md`、`reports/impl-c.md`、`reports/wire-c.md`。
- 实现：`lib/harness/hub/agents_index.dart`、`agents_snapshot.dart`、
  `studio_session_index.dart`、`harness_hub.dart`、`harness_hosts.dart`、
  `default_harness_hosts.dart`、`lib/harness/ui/home_agents_tab.dart`、
  `hub_status.dart`、`agents_entry.dart`、`agent_session_details_page.dart`、
  `hub_agents_surface.dart`、`lib/pages/home_page.dart`、
  `lib/editor/editor_page.dart`、`lib/editor/retained_editor_host.dart`、
  `lib/harness/remote/remote_harness_host.dart`、
  `lib/remote_control/models/protocol.dart`、`lib/session/agent_session.dart`、
  `lib/sync/placeholder_project.dart`、`lib/store/project_store.dart`。
- 电脑端：`companion/remote_agent/src/agent/device-info.ts`、`core.ts`、
  `src/shared/protocol.ts`。
- 现有测试：`test/harness/agents_index_test.dart`、`home_agents_tab_test.dart`、
  `home_agents_tab_live_status_test.dart`、`support/fake_harness_host.dart`。

## 2. 缺陷

### D1 首页 hub 从不装已绑定电脑（严重）

`lib/pages/home_page.dart:838`、`lib/harness/ui/home_agents_tab.dart:130`

需求 9.3 要首页列出每台主机的会话。首页建的 hub 由
`HarnessHosts.build` 装配，该工厂只造内置 Agent、本机和 Herdr。
已绑定电脑要异步打开 `RemoteStore`，从不在这个工厂里。
因此手机上首页只会显示内置会话与本机会话，已绑定电脑一条都不出现。

同一处还有第二层：`openAgentsSurface` 在 App 里没有调用方，
首页是本任务新增的唯一入口。

修法：标签打开时与下拉刷新时调 `openRemoteHarnessHost()`，
拿到主机后交 `HarnessHub.addHost`。已有远程主机时不重复开，
一条 hub 一条连接。测试可注入 `remoteHostOpener`。
提交 `63a7be4`，另补一条注释提交 `34ece8f`。

### D2 快照与 hub 合并后旧行永不消失（严重）

`lib/harness/ui/home_agents_tab.dart:275` `_rebuild`

`_rebuild` 只把快照写进 `_rows`，之后每次重算都只合并 hub 与内置索引。
快照里的行因此一直留在列表上：电脑上已经结束的会话永远显示，
排序也跟着错。需求 12.2 要求快照之后换成新列表。

修法：新增 `_stale`。快照行只在主机还没报过列表时兜底。
`_hub.isListening(hostId)` 且没有读取错误的主机不再用快照补。
提交 `63a7be4`。

### D3 Herdr 与本机混成一栏（中）

`lib/harness/hub/agents_index.dart:88` `agentsHostLabel`

`HarnessHostKind.local` 一律返回「本机」，`HerdrHost.label` 是 `Herdr`。
需求 10.5 要求本机、Herdr、已绑定电脑分开标。
桌面端上本机终端与 Herdr 的会话混成一栏，读起来都像是本机终端。

修法：`local` 用主机自己的 `label`，空串时退回「本机」。
本机主机自己的 label 就是「本机」，行为不变。提交 `63a7be4`。

### D4 设备会话落到别的项目上（严重）

`lib/harness/ui/agents_entry.dart:137` `resolveSessionProject`

需求 9.7 只允许「本机会话没有对应项目时打开最近的项目」。
原实现把这条兜底用在所有主机上：内置会话与已绑定电脑的会话
找不到目录时，直接打开本机最近的项目。编辑器于是显示另一个项目的
目录、文件树与保存位置，用户以为在改电脑上的项目。

修法：非 `kStudioHostId` 且非 `remote` 的主机才走「最近的项目」。
其余主机一律建自己的占位项目。提交 `0e8bc01`。

### D5 首页点内置会话只弹一句错误（严重）

`lib/editor/editor_page.dart:626` `_openInitialHarnessSession`

首页那份 hub 传 `projectRoot: ''`、不传 `projectId`，
所以 `buildDefaultHarnessHosts` 不装内置主机。
点内置会话时 `hub.hostById('studio')` 为 null，只弹「主机不在线」，
需求 9.6 的「首帧选中」走不到。

修法：目标主机 id 等于 `kStudioHostId` 时不查 hub，直接调
`_agentHost.selectSession`。内置面板由编辑器自己画，本来不依赖 hub。
提交 `0e8bc01`。

### D6 打开与刷新可能开两条电脑连接（中）

`lib/harness/ui/home_agents_tab.dart:158` `_attachRemoteHost`

打开标签时补接与下拉刷新并发，两个 opener 都会往下走。
第二个主机在 `addHost` 里因 id 重复交给 `dispose`，但两条连接都已建过。
另外 opener 抛错会冒成未捕获错误。

修法：加 `_attachingRemote` 闸门。opener 抛错按「没有电脑」处理。
提交 `1676df6`。

## 3. 检查过的部分

- 状态权重与排序：六态权重 0 到 5。同态按更新时间倒序，无时间排后。
  再按标题升序、`rowKey` 收尾。与 R10.3、R10.4 一致。
- 圆点：六色互不相同。`unknown` 返回 null 由界面画空心圈。
  `Semantics` 与 `Tooltip` 都带文字说法，不只靠颜色（R3）。
- 内置索引：只读 `index.json`，不读 `.jsonl`。坏条目跳过。
  文件缺失或格式错返回空表，不写回（R2、`studio_session_index.dart`）。
- W3 接线：`currentStudioAgentRuntime()` 只取已装配的运行时，
  不建新运行时。活动状态变化只改状态字段。
  六个用例与实现逐条对上。
- 协议字段：电脑端 `collectDeviceInfo` 给 `hostName`、`os`、`osVersion`。
  手机端 `AgentInfo.fromJson` 同名读取，`RemoteHarnessHost` 按 R4 映射。
  缺值时 `HarnessDeviceInfo` 各字段保持未知，不猜。
- 详情页：五类字段齐全。缺值显示「未知」，路径可选中复制（R11）。
- 首页入口：`home-agents-tab` 在 `TabBar` 外，导航目的地仍为 4 个。
  项目主体 `Offstage` 保活，页签与滚动位置不丢。
- `agents_snapshot.dart` 读写都不抛。读失败按没有快照处理，写失败吞掉。
- 现有测试零改动。新增用例只加在自己的文件里。

## 4. 残余风险（未改代码）

1. 同一台电脑可能有两个 hub 各连一条。
   首页 hub 与编辑器 hub 各自 `addHost` 同一台电脑，
   等于两个 `RemoteController`、两条 WebSocket。
   修法要共享一份远程主机，牵到编辑器页的装配路径，
   超出本任务范围，记为后续。
2. 首页不显示项目名以外的会话路径。
   内置索引的 `cwd` 由 `projectId` 映射本地项目路径，
   项目已删时给空串，详情页显示「未知」。这是索引本身的限制。
3. 内置会话占位项目的 id 不含项目身份。
   `PlaceholderProjects` 按会话 id 建目录，同一项目的新会话会再建一份。
   与 `11-23-device-sync` 报告里的同一条残余风险。

## 5. 静态检查

| 检查 | 范围 | 结果 |
| --- | --- | --- |
| `dart format` | 改动的 7 个文件与 3 个测试文件 | 无改动 |
| `flutter analyze --no-pub` | `lib/harness`、`lib/pages/home_page.dart`、`lib/editor/editor_page.dart`、`test/harness` | 仅 1 条基线 info（`harness_host.dart:6` 的 `unnecessary_import`） |
| `flutter analyze --no-pub` | 新增测试 `agents_entry_project_test.dart`、改动的两个测试文件 | `No issues found!` |

没有跑 `flutter test`，测试交给云端 CI。电脑端未改，未跑 `tsc`。

## 6. 新增与改动的测试

- `test/harness/agents_index_test.dart`：端标注改为按主机名，
  新增 Herdr 与本机空名两例（替换原来「一律本机」那条断言）。
- `test/harness/home_agents_tab_test.dart`：新增三例。
  主机报过列表后不留快照旧行、打开时接上已绑定电脑、
  已有远程主机不再开第二条连接。
- `test/harness/agents_entry_project_test.dart`（新增，5 例）。
  本机会话命中项目、本机会话退回最近项目、没有任何项目时给 null、
  内置会话不占本机项目、同一会话复用占位项目。

## 7. 提交

| 提交 | 内容 |
| --- | --- |
| `63a7be4` | D1、D2、D3，含 3 个新用例与端标注断言改写 |
| `0e8bc01` | D4、D5，含新测试文件 |
| `34ece8f` | 首页 hub 注释说明电脑在哪里补接 |
| `1676df6` | D6 闸门与错误兜底 |

只提交上表自己的路径。同工作树里别人的改动与生成的插件注册文件未动。
