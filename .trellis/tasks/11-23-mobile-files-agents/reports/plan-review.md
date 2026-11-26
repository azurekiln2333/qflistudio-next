# 计划审查裁定（2026-11-23）

四份计划整体可行。下面的裁定覆盖各子任务 `design.md` 里的对应建议。实现前，各 Pi 先把裁定写回自己的 `design.md` 与 `implement.md`。

## R1 编辑器只留一个会话定位参数（A、C）

- 采用 Pi-C 的 `HarnessSessionTarget`：`openEditorPage` 的 `harnessSession`，`EditorPage` 的 `initialHarnessSession`。
- Pi-A 删除 `initialAgentSessionId`，只加 `composerPrefill`。附到会话时传 `harnessSession`。
- 目标主机是 Studio 主机时，Pi-C 的实现要让内置 Agent 面板打开这个会话（设置 `WorkbenchState.sessionId`）。
- Pi-C 先单独提交接口：`HarnessSessionTarget`、编辑器两个参数、`HarnessDeviceInfo`、`HarnessDeviceHost`。提交里不放界面。

## R2 首页列出 Studio 内置会话（C）

覆盖 Pi-C 的未决问题 2。首页索引要包含内置会话。只读 `agent_sessions/index.json` 的元数据，不读 `.jsonl` 正文。

## R3 状态圆点用固定语义色（C）

覆盖 Pi-C 的 4.3 节。颜色不取主题色：

| 状态 | 颜色 |
|---|---|
| `blocked` | 橙色 |
| `working` | 绿色 |
| `idle` | 灰色 |
| `done` | 蓝色 |
| `exited` | 红色 |
| `unknown` | 空心圈 |

浅色与深色主题都要看得清。每个圆点带文字语义标签，不只靠颜色区分。

## R4 设备信息的字段与转换（C、D）

- 线上字段以 Pi-D 设计第 12.1 节为准：`hostName`、`os`、`osVersion`。
- Pi-C 拥有 Dart 类型 `HarnessDeviceInfo` 与 `HarnessDeviceHost`。Pi-C 给手机本机的主机实现设备信息。
- Pi-D 负责 `RemoteHarnessHost` 实现 `HarnessDeviceHost`，在合入 Pi-C 的接口后做：
  - `name` 取 `hostName`，缺了取 `host`。
  - `os` 取 `windows`、`macos`、`linux` 映射到枚举。值为 `other` 或缺失时，用 `platform` 兜底：`win32` → `windows`，`darwin` → `macos`，`linux` → `linux`。都不匹配时为 `unknown`。
  - `osVersion` 原样传。

## R5 不往外部文件夹写 `.qfli/`（B）

覆盖 Pi-B 的 Q4。外部文件夹的项目元数据存应用数据目录，按文件夹 id 关联。外部文件夹里已有 `.qfli/project.json` 时可以读，但不新建。理由：用户要求不往文件夹里写无用文件。

## R6 接受 Pi-B 的 Q1 与 Q3（B）

- Android SAF 目录当项目根另开任务。父任务记为后续事项。
- 第一版不删外部文件。agent 在外部根上删除文件时，返回明确的错误。

## R7 局域网直连必须认证（D）

覆盖 Pi-D 的 Q6。直连沿用配对凭据，加密强度不低于中继路径。不新开未认证的监听端口。电脑端内置的局域网中继已有认证时，复用它。做不到时，第一版只走中继。

## R8 git 先完整克隆，克隆前提示大小（D）

接受 14.4 节。`project_git_info` 报告 `.git` 大小。超过 200 MB 时，克隆前要用户确认。浅克隆记为 qfli_git 的后续需求。本任务不改 qfli_git 仓库。

## R9 接受 Pi-D 的 Q2 到 Q5 与 Q7（D）

同步入口放在编辑器 Agent 面板。会话流缓存上限为 2 MiB 或 400 条。

## R10 重叠文件的规则

| 文件 | 涉及 | 规则 |
|---|---|---|
| `lib/editor/editor_page.dart`、`lib/editor/retained_editor_host.dart` | A、C | 按 R1，Pi-C 拥有会话参数。Pi-A 只加 `composerPrefill` |
| `lib/harness/harness_host.dart` | C | 只有 Pi-C 改 |
| `lib/models/project.dart`、`lib/store/project_store.dart` | B、D | 新字段各自成块追加。不重排、不重新格式化已有代码 |
| `ios/Runner/Info.plist` | A、B | 只追加键 |

## R11 顺序

1. Pi-C 先提交接口（R1）。同时 Pi-A、Pi-B、Pi-D 按裁定改文档。
2. 大脑把 Pi-C 的接口提交合进 `mobile/pi-a` 与 `mobile/pi-d`。
3. 四人并行实现。
4. 集成顺序：C → B → A → D。
