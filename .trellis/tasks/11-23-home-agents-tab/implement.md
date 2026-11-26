# 首页 Agents 标签：实施清单

本版按 `../11-23-mobile-files-agents/reports/plan-review.md` 的裁定 R1、R2、R3、R4、R10、R11 改写。

## 0. 前置

- 分支：`mobile/pi-c`。基线：`main`。
- 仓库：只改 `qfli_studio_core`。
- 工作树：`D:/MyNewProjects/_wt/mobile/pi-c/qfli_studio_core`。
- 先读 `implement.jsonl` 列出的规范文件。
- 本机只跑静态检查。测试交给云端 CI。
- 提交按父任务需求号：先交接口，再按 9、10、11 各一个提交。

## 1. 接口提交（裁定 R1、R4）

不含界面。这是给 Pi-A、Pi-D 合入的接口。

- 仓库：core
- 文件：
  - `lib/harness/harness_host.dart`
  - `lib/harness/device_info.dart`（新增）
  - `lib/harness/studio/studio_agent_host.dart`
  - `lib/editor/retained_editor_host.dart`
  - `lib/editor/editor_page.dart`
  - `test/harness/device_info_test.dart`（新增）
  - `test/editor_harness_session_target_test.dart`（新增）
- 动作：
  1. 追加 `HarnessDeviceOs`、`HarnessDeviceInfo`、`HarnessDeviceHost`、`harnessDeviceOf`。
  2. 新增 `currentDeviceInfo` 与 `harnessDeviceOsOf`。
  3. `StudioAgentHost` 实现 `HarnessDeviceHost`。
  4. 追加 `HarnessSessionTarget`。
  5. `openEditorPage` 追加 `harnessSession` 与 `harnessHub`。
  6. `EditorPage` 追加 `initialHarnessSession`、`harnessHub`、`ownsHarnessHub`。
  7. 首帧按目标主机类型处理：studio 走 `selectSession`，其它走 `openSession`。
  8. 保留会话记录追加 target 与计数。
- 静态检查：

```bash
dart format lib/harness/harness_host.dart lib/harness/device_info.dart lib/harness/studio/studio_agent_host.dart lib/editor/retained_editor_host.dart lib/editor/editor_page.dart test/harness/device_info_test.dart test/editor_harness_session_target_test.dart
flutter analyze --no-pub lib/harness lib/editor test/harness/device_info_test.dart test/editor_harness_session_target_test.dart
```

- 评审门：新参数都有默认值。已有调用点不用改。studio 分支设置 `WorkbenchState.sessionId`。设备信息字段名为 `hostName`、`os`、`osVersion`。
- 回滚点：单独一个提交。整份 revert 即回到原状。
- 真机：不需要。

## 2. 需求 9：首页 Agents 标签

### 2.1 hub 追加

- 仓库：core
- 文件：`lib/harness/hub/harness_hub.dart`
- 动作：追加 `listenAll`、`watchSessions`、`openSessionById`。`dispose` 关闭新 controller。
- 静态检查：

```bash
dart format lib/harness/hub/harness_hub.dart
flutter analyze --no-pub lib/harness/hub/harness_hub.dart
```

- 评审门：订阅可取消。重复订阅无副作用。超时抛 `HarnessHubException`。
- 回滚点：本需求第一个提交。

### 2.2 索引模型

- 仓库：core
- 文件：`lib/harness/hub/agents_index.dart`（新增）
- 动作：定义 `AgentsIndexRow`、`harnessStatusRank`、`agentsHostLabel`、`buildAgentsIndex`。
- 静态检查：

```bash
dart format lib/harness/hub/agents_index.dart
flutter analyze --no-pub lib/harness/hub/agents_index.dart
```

- 评审门：排序是纯函数。主机缺失时丢行不抛错。

### 2.3 内置会话索引（裁定 R2）

- 仓库：core
- 文件：`lib/harness/hub/studio_session_index.dart`（新增）
- 动作：只读 `index.json`。映射为 `HarnessSessionInfo`。状态统一 `idle`。
- 静态检查：

```bash
dart format lib/harness/hub/studio_session_index.dart
flutter analyze --no-pub lib/harness/hub/studio_session_index.dart
```

- 评审门：不读 `.jsonl`。坏数据返回空表。不写索引文件。

### 2.4 快照

- 仓库：core
- 文件：`lib/harness/hub/agents_snapshot.dart`（新增）
- 动作：实现 `load` 与 `save`。坏数据整表丢弃。超过 100 行截断。
- 静态检查：

```bash
dart format lib/harness/hub/agents_snapshot.dart
flutter analyze --no-pub lib/harness/hub/agents_snapshot.dart
```

- 评审门：读写都不抛错。测试后端可用内存实现。

### 2.5 首页入口与索引页

- 仓库：core
- 文件：
  - `lib/harness/ui/home_agents_tab.dart`（新增）
  - `lib/pages/home_page.dart`
- 动作：
  1. 建 `HomeAgentsTab`。它持有 hub 与快照。
  2. 打开时先读快照再订阅。
  3. 列表按 `buildAgentsIndex` 排序。
  4. 首页项目条最左加 `home-agents-tab` 按钮。它不在 `TabBar` 内。
  5. 项目主体用 `Offstage` 保活。
- 静态检查：

```bash
dart format lib/harness/ui/home_agents_tab.dart lib/pages/home_page.dart
flutter analyze --no-pub lib/harness/ui/home_agents_tab.dart lib/pages/home_page.dart
```

- 评审门：导航目的地仍为 4 个。`ProjectScope` 未改。标签栏内无新增 `Text`。
- 回滚点：本需求第二个提交。
- 真机：需要看真机的窄屏布局与滚动手感。

### 2.6 点击跳转

- 仓库：core
- 文件：`lib/harness/ui/agents_entry.dart`
- 动作：
  1. 追加 `openAgentSession(...)`。
  2. 用 `session.cwd` 匹配本地项目。
  3. 匹配失败时取最近更新的本地项目。
  4. 一个都没有时弹说明。
  5. 跳转时传 `harnessSession` 与首页 hub。
- 静态检查：

```bash
dart format lib/harness/ui/agents_entry.dart
flutter analyze --no-pub lib/harness/ui/agents_entry.dart
```

- 评审门：`openAgentsSurface` 行为不变。云端项目不当工作目录。
- 回滚点：本需求第三个提交。

### 2.7 需求 9 的用例

- 仓库：core
- 文件：`test/harness/agents_index_test.dart`、`test/harness/studio_session_index_test.dart`、`test/harness/agents_snapshot_test.dart`、`test/harness/home_agents_tab_test.dart`（新增）
- 动作：覆盖排序、内置索引、快照、快照优先与刷新。
- 静态检查：

```bash
dart format test/harness
flutter analyze --no-pub test/harness
```

- 评审门：只用假主机与内存后端。

## 3. 需求 10：状态圆点与端标注

- 仓库：core
- 文件：`lib/harness/ui/hub_status.dart`、`lib/harness/ui/home_agents_tab.dart`
- 动作：
  1. 追加 `harnessStatusDotColor` 与 `harnessStatusDotBorderColor`。
  2. 固定语义色按裁定 R3。
  3. `unknown` 画空心圈。
  4. 圆点带 `Semantics` 标签与 tooltip。
  5. 行内显示端标注。
- 静态检查：

```bash
dart format lib/harness/ui/hub_status.dart lib/harness/ui/home_agents_tab.dart
flutter analyze --no-pub lib/harness/ui/hub_status.dart lib/harness/ui/home_agents_tab.dart
```

- 评审门：六色互不相同。深浅主题都能看清。旧函数未改。
- 回滚点：本需求一个提交。
- 真机：需要看深浅主题下的可辨识度。

## 4. 需求 11：会话详情

- 仓库：core
- 文件：
  - `lib/harness/ui/agent_session_details_page.dart`（新增）
  - `lib/harness/ui/home_agents_tab.dart`
  - `lib/i18n/studio_localizations.dart`
- 动作：
  1. 建详情页，五行字段。
  2. 行尾加详情图标，跳到详情页。
  3. 文案三语补齐。
- 静态检查：

```bash
dart format lib/harness/ui/agent_session_details_page.dart lib/harness/ui/home_agents_tab.dart lib/i18n/studio_localizations.dart
flutter analyze --no-pub lib/harness/ui/agent_session_details_page.dart lib/harness/ui/home_agents_tab.dart lib/i18n/studio_localizations.dart
```

- 评审门：缺值显示「未知」。三语键一致。
- 回滚点：本需求一个提交。
- 真机：需要确认详情页在小屏上不截断。

## 5. 现有测试回归

- 仓库：core
- 文件：不改任何现有测试。
- 动作：
  1. 逐条检查 `widget_test` 的四目的地断言。
  2. 逐条检查 `home_project_tabs_test` 的默认顺序。
  3. 逐条检查 `home_project_tabs_widget_test` 的标签读取方式。
- 静态检查：

```bash
flutter analyze --no-pub
```

- 评审门：现有测试文件零改动。`git diff --stat` 只含新文件与预期文件。
- 回滚点：无代码改动。

## 6. 云端验证

- 触发 `core-check`。
- 关注三点：
  1. `flutter analyze` 无告警。
  2. 全量测试通过，旧用例零改动。
  3. 新增用例在 Linux 下通过。
- 触发 `App installers`，确认 App 构建不受影响。
- 记录失败用例的完整异常与栈帧，再定位。

## 7. 真机验证

需要真机的项：

1. 手机与电脑配对后，首页能看到电脑会话。
2. 内置会话出现在首页索引里。
3. 六种状态圆点在深色与浅色主题下都能区分。
4. 点会话后首帧停在 Agent 面板，选中的就是该会话。
5. 窄屏首帧落在 Agent 分段。
6. 详情页显示设备名、系统、版本与路径。
7. 切回项目列表后滚动位置未丢。

不需要真机的项：排序、快照、内置索引、文案、契约。

## 8. 顺序与风险

1. 先合接口提交。Pi-A 与 Pi-D 依赖它。
2. 再合索引、内置索引与快照。它们纯 Dart。
3. 再合首页入口。此时功能可见。
4. 再合圆点与详情。
5. 每个需求号一个提交，每个提交都能单独回滚。

主要风险：内置会话只有 `idle` 一个状态。
缓解：详情页与列表照常显示。运行态留待后续任务。