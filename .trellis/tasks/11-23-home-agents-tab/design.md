# 首页 Agents 标签：技术设计

本版按 `../11-23-mobile-files-agents/reports/plan-review.md` 的裁定改写。
裁定 R1、R2、R3、R4、R10、R11 覆盖前一版对应建议。

## 1. 边界

本任务只改 core 仓库 `qfli_studio_core`。
App 仓库 `qflistudio` 不改代码。
编辑器仍是 Agents 的家。首页只做索引。

### 落点

| 内容 | 仓库 | 文件 |
| --- | --- | --- |
| 设备信息契约 | core | `lib/harness/harness_host.dart` |
| 设备信息读取 | core | `lib/harness/device_info.dart`（新增） |
| 首帧选中契约 | core | `lib/editor/retained_editor_host.dart`、`lib/editor/editor_page.dart` |
| hub 订阅与按 id 打开 | core | `lib/harness/hub/harness_hub.dart` |
| 索引模型与排序 | core | `lib/harness/hub/agents_index.dart`（新增） |
| 内置会话索引 | core | `lib/harness/hub/studio_session_index.dart`（新增） |
| 快照存储 | core | `lib/harness/hub/agents_snapshot.dart`（新增） |
| 首页索引页 | core | `lib/harness/ui/home_agents_tab.dart`（新增） |
| 会话详情页 | core | `lib/harness/ui/agent_session_details_page.dart`（新增） |
| 点击跳转 | core | `lib/harness/ui/agents_entry.dart` |
| 状态圆点 | core | `lib/harness/ui/hub_status.dart` |
| 首页入口 | core | `lib/pages/home_page.dart` |
| 文案 | core | `lib/i18n/studio_localizations.dart` |

### 文件归属（裁定 R10）

- `lib/harness/harness_host.dart`：只有本任务改。
- `lib/editor/editor_page.dart`、`lib/editor/retained_editor_host.dart`：会话参数归本任务。
  编修者只追加 `composerPrefill`。
- 不碰 `lib/models/project.dart`、`lib/store/project_store.dart`、`ios/Runner/Info.plist`。

## 2. 契约

### 2.1 设备信息（裁定 R4）

Dart 类型归本任务。字段名与线上字段同名：`hostName`、`os`、`osVersion`。

```dart
/// 设备系统。识别不了时用 unknown。
enum HarnessDeviceOs { android, ios, ohos, macos, windows, linux, unknown }

/// 一台主机所在设备的信息。
///
/// 三个字段都可缺。缺的字段在详情页显示「未知」。
@immutable
class HarnessDeviceInfo {
  const HarnessDeviceInfo({
    this.hostName,
    this.os = HarnessDeviceOs.unknown,
    this.osVersion,
  });

  /// 显示用设备名。线上字段 `hostName`。
  final String? hostName;

  final HarnessDeviceOs os;

  /// 版本原文。不解析，不改写。
  final String? osVersion;

  bool get isEmpty =>
      (hostName?.trim().isEmpty ?? true) &&
      os == HarnessDeviceOs.unknown &&
      (osVersion?.trim().isEmpty ?? true);
}

/// 可选能力：主机能报设备信息时实现本接口。
///
/// 契约主体不新增必需成员，四家主机与测试假件都不用改。
abstract class HarnessDeviceHost {
  ValueListenable<HarnessDeviceInfo> get device;
}

/// 读取设备信息。主机没实现接口时返回 null。
HarnessDeviceInfo? harnessDeviceOf(HarnessHost host);
```

职责划分：

- 本任务实现手机本机那一台主机的设备信息。
- `RemoteHarnessHost` 的实现归 `11-23-device-sync`。
- 线上解析规则由 Pi-D 负责：`name` 取 `hostName`，缺了取 `host`。
  `os` 为 `other` 或缺失时按 `platform` 兜底。

### 2.2 设备信息读取

```dart
/// 当前设备的信息。只读平台常量，不碰网络。
HarnessDeviceInfo currentDeviceInfo();

/// 平台系统名到枚举。认不出返回 unknown。
HarnessDeviceOs harnessDeviceOsOf(String platformSystem);
```

`currentDeviceInfo()` 读 `Platform.localHostname`、`Platform.operatingSystem`、
`Platform.operatingSystemVersion`。
读取失败时返回空对象，不抛错。

平台通道版本留作后续：通道名 `qflistudio/platform`，方法 `deviceInfo`，
返回 `{"hostName": String, "os": String, "osVersion": String}`。
端口名与字段与线上一致。该项需要真机验证。

### 2.3 首帧选中会话（裁定 R1）

只有一个会话定位参数。名字沿用本任务的 `HarnessSessionTarget`。

```dart
/// 打开编辑器时要选中的会话。
@immutable
class HarnessSessionTarget {
  const HarnessSessionTarget({required this.hostId, required this.sessionId});
  final String hostId;
  final String sessionId;

  @override
  bool operator ==(Object other) =>
      other is HarnessSessionTarget &&
      other.hostId == hostId &&
      other.sessionId == sessionId;

  @override
  int get hashCode => Object.hash(hostId, sessionId);
}
```

`openEditorPage` 追加参数：

```dart
Future<void> openEditorPage(
  BuildContext context, {
  // 已有参数省略
  bool revealAgentPane = false,
  HarnessSessionTarget? harnessSession,
  HarnessHub? harnessHub,
});
```

`EditorPage` 追加参数：

```dart
  this.initialHarnessSession,
  this.harnessHub,
  this.ownsHarnessHub = true,
```

首帧行为：

1. `harnessHub` 非空时编辑器直接用这一份。否则按原逻辑建 hub。
2. `ownsHarnessHub` 为 false 时 `dispose()` 不释放 hub。
3. 首帧后调用一次 `_openInitialHarnessSession(target)`。
4. 目标主机类型是 `studio` 时走内置面板：
   `agentHost.activate()`、展开面板、`showMainPane(MainPane.agent)`、
   `selectSession(target.sessionId)`。
   这一步把 `WorkbenchState.sessionId` 设为该会话，内置面板因此打开它。
5. 其它主机类型先 `_revealAgentPane()`，再等会话出现在列表里，然后
   `hub.openSession(info, hostId: target.hostId)`。
6. 会话在 15 秒内没出现时提示「打不开这个会话：等待超时」。
7. 打开失败弹「打不开这个会话：$error」。
8. `didUpdateWidget` 发现 target 变了，按同一套流程再开一次。

等待会话用编辑器内的私有实现。它循环监听 hub 通知。
这样接口提交不依赖 hub 的新方法。

`_revealAgentPane()` 已存在。它内部调 `showMainPane(MainPane.agent)`。
窄屏的 Agent 分段由这一条覆盖。

`RetainedEditorController` 的会话记录追加两个字段：

```dart
  HarnessSessionTarget? harnessTarget;
  int harnessRequest = 0;
```

`open(..., harnessSession)` 非空时写入 target 并自增 `harnessRequest`。
`_SessionEditor` 把 target 与计数传给 `EditorPage`。

### 2.4 hub 追加 API

只追加方法。已有方法签名不变。

```dart
/// 订阅全部可见主机。重复调用无副作用。
void listenAll();

/// 全部会话的合并流。订阅时先发一帧，之后每次变化再发一帧。
Stream<List<HarnessSessionInfo>> watchSessions({bool listenAll = true});

/// 按主机 id 与会话 id 打开会话。超时抛 [HarnessHubException]。
Future<HarnessSessionHandle> openSessionById(
  String hostId,
  String sessionId, {
  Duration timeout = const Duration(seconds: 15),
});
```

### 2.5 索引模型

```dart
/// 首页列表的一行。
@immutable
class AgentsIndexRow {
  const AgentsIndexRow({
    required this.session,
    required this.hostLabel,
    required this.hostKind,
    this.device,
  });

  final HarnessSessionInfo session;
  final String hostLabel;
  final HarnessHostKind hostKind;
  final HarnessDeviceInfo? device;

  String get rowKey => '${session.hostId}:${session.id}';
}

/// 状态权重：blocked 0，working 1，idle 2，done 3，exited 4，unknown 5。
int harnessStatusRank(HarnessSessionStatus status);

/// 端标注：本机给「本机」，Herdr 给「Herdr」，已绑定电脑给设备名。
String agentsHostLabel({
  required HarnessHostKind kind,
  required String hostLabel,
  HarnessDeviceInfo? device,
});

/// 合并与排序。纯函数。
List<AgentsIndexRow> buildAgentsIndex({
  required Iterable<HarnessHost> hosts,
  required List<HarnessSessionInfo> sessions,
  required HarnessDeviceInfo? Function(HarnessHost host) deviceOf,
});
```

排序规则：

1. 按 `session.hostId` 找主机。找不到的行丢弃。
2. 按 `harnessStatusRank` 升序。
3. 权重相同时按 `updatedAt` 倒序。没有时间排后面。
4. 仍相同时按标题小写升序。

### 2.6 内置会话索引（裁定 R2）

首页索引必须包含 Studio 内置会话。
只读 `agent_sessions/index.json` 的元数据。不读 `.jsonl` 正文。

```dart
/// 读 `agent_sessions/index.json`，映射成主机会话。
///
/// 状态统一为 idle：磁盘上的会话没有正在运行的进程。
class StudioSessionIndex {
  StudioSessionIndex({required Directory root});

  /// 索引路径：`<root>/index.json`。
  File get indexFile;

  Future<List<HarnessSessionInfo>> read({
    required String hostId,
    required String Function(String projectId) cwdOf,
  });
}
```

索引格式（只读，不改写）：

```json
{
  "version": 2,
  "sessions": [
    {
      "id": "s-1",
      "projectId": "p-1",
      "title": "修复登录",
      "createdAt": "2026-11-23T09:00:00.000Z",
      "updatedAt": "2026-11-23T09:58:00.000Z",
      "messageCount": 12,
      "preview": "先看这个函数"
    }
  ]
}
```

映射规则：

1. `id` 用会话 id。
2. `providerId` 用 `studio`。
3. `cwd` 用 `cwdOf(projectId)`。项目已删时用空串。
4. `status` 用 `idle`。
5. `updatedAt` 缺失的条目丢弃。
6. 文件缺失或损坏时返回空表。

### 2.7 快照

```dart
/// 首页 Agents 列表的快照。
class AgentsSnapshotStore {
  AgentsSnapshotStore({LocalStoreBackend? backend});
  static const String fileName = 'home_agents_snapshot.json';
  static const int schemaVersion = 1;
  static const int maxRows = 100;

  Future<List<AgentsIndexRow>> load();
  Future<void> save(List<AgentsIndexRow> rows);
}
```

文件格式：

```json
{
  "version": 1,
  "savedAt": "2026-11-23T10:00:00.000Z",
  "rows": [
    {
      "hostId": "remote:abc",
      "hostLabel": "MacBook Pro",
      "hostKind": "remote",
      "sessionId": "session:17",
      "providerId": "claude",
      "title": "修复登录",
      "status": "blocked",
      "cwd": "/Users/me/work/app",
      "updatedAt": "2026-11-23T09:58:00.000Z",
      "device": {"hostName": "MacBook Pro", "os": "macos", "osVersion": "14.5"}
    }
  ]
}
```

枚举存 `name`。读回认不出的值退回默认值。

## 3. 数据流

```text
打开首页 Agents 标签
  -> 读快照（AgentsSnapshotStore.load）
  -> 先渲染快照行
  -> 建 hub（harnessHubFor）
  -> 有已绑定电脑时 addHost(openRemoteHarnessHost())
  -> 读内置会话索引（StudioSessionIndex.read）
  -> hub.listenAll() / watchSessions()
  -> 每帧合并排序（buildAgentsIndex）
  -> 渲染
  -> 防抖 2 秒写回快照
```

点一行：

```text
点行 -> openAgentSession(...)
  -> 用 session.cwd 匹配本地项目
  -> 匹配失败时取最近更新的本地项目
  -> 一个都没有时弹说明
  -> openEditorPage(revealAgentPane, harnessSession, harnessHub: 首页 hub)
  -> EditorPage 首帧后按目标主机类型处理
     -> studio：selectSession 并落到 Agent 分段
     -> 其它：openSession 后落到 Agent 面板
```

## 4. 界面

### 4.1 入口位置

首页项目条最左加一个标签样式的按钮。
键为 `ValueKey('home-agents-tab')`。文字为 `Agents`。
它不在 `TabBar` 里。

原因：现有测试按 `TabBar` 内的 `Text` 取标签列表。
现有测试还断言导航目的地为 4 个。
入口放 `TabBar` 外，两条断言都不受影响。

主体两个分支：

- `_agentsOpen == false`：现有 `TabBarView`。
- `_agentsOpen == true`：`HomeAgentsTab`。

项目主体用 `Offstage` 保活，不销毁。
这样切回项目列表时滚动位置与页签都还在。

### 4.2 列表行

一行由三块组成：

1. 左侧状态圆点。直径 10 dp。空心圈用 1.5 dp 描边。
2. 中间两行文字。第一行标题，第二行端标注加会话路径。
3. 右侧相对时间与详情图标。

详情图标：`Icons.info_outline`。tooltip 为「会话详情」。
行的键为 `ValueKey('agents-row-${row.rowKey}')`。
圆点的键为 `ValueKey('agents-status-${row.rowKey}')`。

圆点带文字语义标签。标签由 `harnessStatusLabel` 给出。
它是 `Semantics(label: ...)` 的值，也是 `Tooltip` 的文字。
读屏与长按都能读到状态名，不靠颜色区分。

### 4.3 状态圆点配色（裁定 R3）

颜色固定，不取主题色。

| 状态 | 颜色值 | 形状 |
| --- | --- | --- |
| `blocked` | `Color(0xFFF59E0B)` 橙 | 实心 |
| `working` | `Color(0xFF22C55E)` 绿 | 实心 |
| `idle` | `Color(0xFF9CA3AF)` 灰 | 实心 |
| `done` | `Color(0xFF3B82F6)` 蓝 | 实心 |
| `exited` | `Color(0xFFEF4444)` 红 | 实心 |
| `unknown` | 前景色描边 | 空心圈 |

```dart
/// 圆点颜色。unknown 返回 null，用描边画空心圈。
Color? harnessStatusDotColor(HarnessSessionStatus status);

/// 圆点描边色。unknown 用主题前景色。
Color harnessStatusDotBorderColor(
  ColorScheme scheme,
  HarnessSessionStatus status,
);
```

浅色与深色主题都直接可见。
原有 `harnessStatusColor` 不动。已有界面不受影响。

### 4.4 详情页

`AgentSessionDetailsPage` 接收 `AgentsIndexRow`。
内容为五行字段：设备名、系统、系统版本、主机类型、会话路径。
字段缺值时显示「未知」。
会话路径取 `session.cwd`。`cwd` 为空时也显示「未知」。

## 5. 兼容性

| 现有测试 | 影响 | 依据 |
| --- | --- | --- |
| `widget_test.dart` 的四目的地断言 | 不受影响 | 不改导航栏 |
| `home_project_tabs_test.dart` 的默认顺序与合并断言 | 不受影响 | `ProjectScope` 不动 |
| `home_project_tabs_widget_test.dart` 的 `_tabLabels` | 不受影响 | 入口在 `TabBar` 外 |
| `home_navigation_test.dart` 的页标题 | 不受影响 | 首页标题不变 |
| `retained_editor_test.dart` | 不受影响 | 新参数都有默认值 |
| `harness_hub_test.dart`、`hub_ui_test.dart` | 不受影响 | 只追加方法 |
| 四家主机与测试假件 | 不受影响 | 设备信息走可选接口 |
| `studio_agent_host_test.dart` | 不受影响 | 只追加 `device` 取值器 |

新增测试文件：

- `test/harness/device_info_test.dart`
- `test/editor_harness_session_target_test.dart`
- `test/harness/agents_index_test.dart`
- `test/harness/studio_session_index_test.dart`
- `test/harness/agents_snapshot_test.dart`
- `test/harness/home_agents_tab_test.dart`
- `test/harness/hub_status_dots_test.dart`
- `test/harness/agent_session_details_test.dart`

## 6. 权衡

- 首页 hub 与编辑器 hub 可能并存。已绑定电脑会多一条连接。
  取舍：Agents 入口共用首页 hub。项目卡片入口维持原样。
- 快照会过期。用户看到旧状态的时间等于一次刷新耗时。
  取舍：快照只用于首屏。刷新失败时保留快照并显示一行提示。
- 内置会话状态只能是 `idle`。索引不读运行态。
  取舍：真状态需要运行时。本任务不引入第二个运行时。
- 订阅只在标签打开时建立。
  取舍：首次打开有一帧空列表加加载态。快照能盖住常见情况。

## 7. 上线与回滚

上线顺序按裁定 R11：

1. 接口提交：会话参数、设备信息类型、首帧行为、用例。不含界面。
2. 索引与快照：纯 Dart，可单独合并。
3. 首页入口与列表页。
4. 详情页。
5. 文案。

每一步一个提交。每一步都能只回滚自己。
回滚方式：按提交顺序反向 revert。
回滚第 3 步后首页回到纯项目列表。已有功能不受影响。

## 8. 未决问题

1. Agents 标签能否拖动排序？
   推荐：不能。固定最左，避免与项目页签的顺序存储混在一起。
2. 内置会话进首页后，运行状态怎么来？
   裁定 R2 只读索引。推荐：本任务统一 `idle`，运行态留待后续接运行时。
3. 首页 hub 是否给项目卡片入口共用？
   推荐：本任务不共用。先保证 Agents 入口只有一个 hub。
4. 快照保留多少行？
   推荐：最多 100 行，按排序后的顺序截断。
5. 详情入口放在行尾图标，还是长按菜单？
   推荐：行尾图标。长按留给后续的多选。
6. 状态顺序是否统一 `remote_harness_host` 的现有排序？
   推荐：本任务只新增 `harnessStatusRank` 供首页使用。
   其余列表的排序留到后续任务统一。