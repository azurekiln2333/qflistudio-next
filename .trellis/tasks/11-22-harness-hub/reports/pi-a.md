# Pi-A 报告：本机 host（ProviderRegistry / StudioMux / 日志读取 / LocalHarnessHost）

分支 `harness/pi-a`，工作树 `D:/MyNewProjects/_wt/harness/pi-a/qfli_studio_core`。
App 工作树未改动：本阶段没有本机 host 之外的 UI 依赖。

## 1. 交付摘要

Core `lib/harness/local/` 新增 14 个文件，实现契约 `HarnessHost` 的本机一侧。

- **ProviderRegistry**：内置 claude、codex、pi、opencode、gemini、zcode、dsh、shell。
  解析顺序为配置绝对路径 → 配置探测路径 → PATH → 平台常见安装目录；
  Windows 按 PATHEXT 补全（`claude` → `claude.cmd`）。用户项来自
  `<appSupport>/qfli_harness_providers.json`，同 id 覆盖内置项（AC11）。
- **StudioMux**：持有 PTY 会话进程、状态、有界滚动缓冲、显式 `stop()`。
  关闭视图不结束进程；`stop()` 幂等并等待退出码；退出路径走
  `ProcessSupervisor`（Windows `taskkill /T /F`，POSIX TERM→KILL），符合
  process-lifecycle。
- **日志读取**：Claude Code（`~/.claude/projects`）、Codex（`~/.codex/sessions`）、
  Pi（`~/.pi/agent/sessions`），尾部窗口读取（默认 512 KiB，跳过半行与超长行），
  解析成 `TranscriptEvent`；Codex 的 `exec_approval_request` 等与 Pi 的
  `permission_request` 映射到 `requestId` 与候选选项。只读。
- **LiveLogFollower**：直播会话按“cwd 一致 + 修改时间不早于启动时刻”找到日志，
  每 2 秒增量推送事件，让 `open()` 的直播句柄同时具备终端与对话记录。
- **LocalHarnessHost**（id `local`，kind `local`）：合并 StudioMux 会话与近期
  日志会话；`providers()` 返回检测结果；`launch()` 在 StudioMux 里启动；
  `open()` 返回终端句柄（有日志时带 transcript）或只读日志句柄。
  桌面以外平台 state 为 `unsupported`，`watchSessions()` 只发一次空列表。

## 2. 提交

| 提交 | 说明 |
| --- | --- |
| `9c7f99f` | feat(harness): add the local harness host（14 个 lib 文件 + 9 个测试文件 + 4 个夹具） |
| `d5305dc` | fix(harness): keep live session capabilities truthful（直播会话不再声明 `approve`） |

基线 `f9b6485`（契约）。契约文件 `lib/harness/harness_host.dart` 未改动。

## 3. 文件

实现（`lib/harness/local/`）：

```
harness_provider.dart          提供方模型、内置表、配置解析
executable_locator.dart        可执行文件探测（PATH / PATHEXT / 安装目录 / ~）
provider_registry.dart         合并内置与用户项，暴露 HarnessProviderInfo
pty_process.dart               PTY 抽象与 script / pipe 后端
terminal_scrollback.dart       有界滚动缓冲
studio_mux.dart                会话进程、状态、事件流、显式结束
transcript_log_reader.dart     jsonl 尾部窗口、公共解析、id 规则
claude_code_log_reader.dart    Claude Code 解析
codex_log_reader.dart          Codex 解析（含审批 requestId）
pi_log_reader.dart             Pi 解析（含请求 requestId）
log_reader_factory.dart        格式 → 读取器
live_log_follower.dart         直播会话日志跟随
local_harness_host.dart        HarnessHost 实现与会话句柄
README.md                      使用方式、配置 schema、后端能力矩阵
```

测试（`test/harness/local/`，交给 CI 运行）：`terminal_scrollback_test.dart`、
`executable_locator_test.dart`（含配置解析）、`provider_registry_test.dart`、
`studio_mux_test.dart`、`claude_code_log_reader_test.dart`、
`codex_log_reader_test.dart`、`pi_log_reader_test.dart`、
`live_log_follower_test.dart`、`local_harness_host_test.dart`，
辅助 `support/fake_pty.dart`，夹具 `fixtures/home/{.claude,.codex,.pi}/…`。

## 4. 契约变更请求

无。契约文件未修改。

两点供 root 决定（不改也能工作）：

1. `harness_host.dart` 的 `import 'dart:typed_data'` 在 `flutter/foundation.dart`
   之后是冗余的，`dart analyze` 会报一条 `unnecessary_import` info。基线就有，
   不在我分支里修。
2. `HarnessCapability` 没有“可改尺寸”或“真实 TTY”的表达。本机后端当前不支持
   运行期改尺寸（见风险 1），界面若需要隐藏 resize 控件，可用
   `StudioMux.supportsResize` / `LocalHarnessHost.allocatesTerminal` 判断；
   若希望契约表达，可加一个 capability 值。

## 5. 新增依赖

无。仅复用 `services/process_supervisor.dart`、`services/app_paths.dart`、
`flutter/foundation.dart`、`package:path`。

## 6. 静态检查结果

在 `qfli_studio_core` 工作树内执行：

- `flutter pub get`：成功（依赖未变化）。
- `dart format lib/harness/local test/harness/local`：`Formatted 23 files (0 changed)`。
- `dart analyze lib/harness test/harness`：仅 1 条 info，位于基线契约文件
  `lib/harness/harness_host.dart:6`（`unnecessary_import`，未修改该文件）。
  我新增的 lib 与 test 文件零告警。

按规则未运行 `flutter test`、未构建、未启动任何模拟器、服务或真实 agent。

## 7. 假设与设计决定

1. **Core 里没有现成 PTY。** 现有终端是“每条命令一个进程 + 管道”
   （`terminal/shell/local_shell_io.dart`），没有 ConPTY/forkpty 绑定，也没有
   `script`/`winpty` 相关代码。因此 `StudioMux` 定义了 `PtyLauncher` 抽象，
   并提供两个实现：macOS/Linux 用系统 `script` 申请伪终端（真实 TTY，初始尺寸
   由 `stty` 设定）；Windows 退回进程管道（`.cmd`/`.bat` 经 `cmd.exe /c`）。
   会话、状态、滚动缓冲、结束路径与后端无关，补上原生实现即可升级。
2. **`resize()` 目前恒为 false。** `script` 持有 pty 主设备，无法在运行期改
   尺寸；接口保留 `bool resize(int, int)`，`MuxSession` 只在返回 true 时更新
   记录尺寸。
3. **日志格式按文档与兼容写法解析。** Claude/Codex 的字段名按公开格式；
   Pi 的日志形状按 `message.message`、`message.content`、`{role, content}`、
   裸 `{type, text}` 依次兼容。三者都用自写夹具验证，未对照真实会话日志
   （规则 5 禁止读取真实日志）。
4. **审批映射只在格式有的地方做。** Codex `exec_approval_request` /
   `apply_patch_approval_request` / `request_permissions` 与 Pi
   `permission_request` / `approval_request` / `question` 带 requestId；
   Claude Code 不把权限确认写进 jsonl，因此没有 requestId，界面不应显示
   审批按钮。
5. **直播会话的对话记录由 LiveLogFollower 提供**：按 cwd 与 mtime 匹配，
   2 秒轮询，按事件条数增量推送；尾部窗口滑走时重新对齐。直播句柄的能力集
   只声明 terminal、transcript、prompt、stop；不声明 `approve`。
6. **日志会话状态是推断值**：最后一条是待回复请求 → `blocked`；助手 → `done`；
   工具 → `idle`；用户 → `working`；空日志 → `unknown`。这是列表标签，不是
   harness 的真实进程状态。
7. **用户配置**：文件上限 64 KiB；顶层接受 `{"providers": [...]}` 或裸数组；
   非法项跳过并写入 `ProviderRegistry.warnings`；未知 `logFormat` 降级为无日志。
8. **shell 提供方**：Windows 解析 PowerShell；POSIX 先看 `$SHELL`，再
   `/bin/zsh`、`/bin/bash`、`/bin/sh`。
9. **平台判断**用 `defaultTargetPlatform`（配合 `kIsWeb`），因此 widget 测试
   可以覆盖平台；`LocalHarnessHost(supported: …)` 也允许显式注入。
10. **移动端行为**：`state = unsupported`、`watchSessions()` 发一次空列表、
    `launch()` 抛 `UnsupportedError`、`providers()` 返回空列表（注册表不加载）。

## 8. 未验证的验收项

| 项 | 状态 |
| --- | --- |
| AC1（三系统启动 shell/Claude/Codex/Pi） | **Windows 不满足**：只有管道后端，TUI 起不来。现在 `providers()` 在管道后端下把这类 harness 标成不可用（见 Fixes D0），界面不会给出必定失败的入口；macOS/Linux 仍未真机验证。 |
| AC11（配置添加未识别 harness） | 代码与单测覆盖解析/合并；真实配置文件未在设备上加载过。 |
| 日志读取正确性 | 只用自写夹具验证；未对照真实 Claude/Codex/Pi 日志。 |
| 运行期改尺寸 | **不支持**，`resize()` 返回 false。 |
| Windows ConPTY | **未实现**，当前为管道后端。 |
| 全部单元测试 | 已写入仓库，按规则未在本地运行，等 CI。 |

## 9. 风险

1. **Windows 没有真实终端**（最大风险）。已按 D0 做了界面侧兜底：管道后端下
   需要终端的 harness 标为不可用、`launch()` 明确报错，用户不会拿到假终端。
   真正的修复仍需原生 ConPTY；`PtyLauncher` 已留好接入点，替换后端不需要改
   `StudioMux`、`LocalHarnessHost` 或 Pi-C 的界面。建议在 P5 之前由 root 决定
   是否加依赖（例如 `flutter_pty`）或写 FFI 模块。
2. **Pi/Codex 日志字段的不确定性**。夹具按公开格式写；若真实文件字段不同,
   读取器会静默返回空列表（不抛异常）。建议追加以真实日志脱敏后的回归夹具。
3. **直播会话匹配靠 cwd + mtime**。同一目录并行开两个会话时可能跟错文件。
   缓解：只在启动后 5 秒窗口内挑选最近一个文件；风险仍存在。
4. **`script` 依赖 util-linux 语义**（Linux 用 `-q -e -f -c`）。BusyBox 的
   `script` 不认识 `-e`，Alpine 等环境下启动会失败；macOS 走 BSD 分支，不受
   影响。
5. **日志列表刷新间隔 20 秒**，界面需要即时更新时调用
   `LocalHarnessHost.refreshLogSessions()`。

## 10. 给 Pi-C 的接入说明

```dart
final local = LocalHarnessHost();               // 桌面默认可用
final providers = await local.providers();      // 新建会话菜单
final handle = await local.launch(
  HarnessLaunchRequest(providerId: 'claude', cwd: projectPath),
);
// 终端：handle.terminal（HarnessTerminalChannel）
// 对话：handle.transcript（有日志时非 null，直播会话为增量事件）
// 关闭视图：handle.detach()；结束会话：handle.stop()（先弹确认）
```

- 列表：`watchSessions()` 是广播流，但每个新订阅者会先收到一帧当前快照。
- 诊断：`local.ptyStrategy`（`script` / `pipe`）、`local.allocatesTerminal`、
  `local.warnings`、`local.logWarnings`。
- 历史会话只读：`sendPrompt` / `reply` / `stop` 会抛 `UnsupportedError`。

---

# Fixes（回应 check-d）

复核报告：`reports/check-d.md`。修复提交：`0917c93 fix(harness): address the
local host review findings`（基于 `d5305dc`）。契约 `lib/harness/harness_host.dart`
仍未改动（`git diff` 可证）；仍无新增依赖。

静态检查（仅这两项，未跑测试/构建）：`dart format --output=none lib/harness/local
test/harness/local` → `24 files (0 changed)`；`dart analyze lib/harness test/harness`
→ 仅基线契约里那条 `unnecessary_import` info。

| 编号 | 结论 | 处理 |
| --- | --- | --- |
| D0 | **部分修复**（验收侧已堵，根因待 root 决策） | 采纳建议 2：`HarnessProviderSpec` 新增 `requiresTerminal`（默认 `true`，可在配置里写 `false`）；`ProviderRegistry.infosFor(allocatesTerminal:)` 与 `LocalHarnessHost.providers()` 在管道后端下把 `claude`/`codex`/`pi`/`opencode` 等标成 `available: false`，`launch()` 另抛明确 `StateError`。shell 不受影响。原生 ConPTY 未做（需依赖或 FFI，属 root 决策）。报告 AC1 一行已改为“Windows 不满足”。 |
| D1 | **已修** | `MuxSession.sendLine` 改用 `utf8.encode(text)`，与 `\r` 拼接。新增用例：`sendLine('你好')` → `utf8.encode('你好') + [13]`，并断言中间不出现 `0x0D`。 |
| D2 | **已修** | `SupervisedPtyProcess` 同时订阅 `stderr`，两个管道都结束才关闭 `output`（避免 stderr 尾巴被截断）。为使这条可测，抽出 `PtyChildProcess` 最小接口（`ManagedPtyChild` 包 `ManagedProcess`）。新增 `pty_process_test.dart`：stdout+stderr 都转发、terminate 幂等、两个管道都结束才 done。 |
| D3 | **已修** | `detach()` 不再只停 follower 而是从 `_followers` 移除；`open()` 发现缺 follower 时按 `session.startedAt` 重建，并补齐已有事件。同时加了手柄缓存（`_liveHandles`/`_logHandles`）：同一个会话重复 `open()` 返回同一句柄，`stop()`/`detach()` 后重新创建。新增用例：`launch → detach → open` 后 transcript 是活流；`detach → stop` 仍会结束进程。 |
| D4 | **已修** | `watchSessions()` 改成 `Stream.multi`，每个订阅者先收 `_latest` 快照再跟广播流；`_beginWatching()` 对后续订阅者不再重扫日志目录，只重发快照。新增用例：连续两次 `watchSessions().first` 都拿到非空列表。 |
| D5 | **已修** | follower 不再用“事件条数”做游标，改用 `Set<String> _deliveredIds`（只看当前窗口内的 id）。窗口封顶后新事件仍会推送；窗口滑走不会重推。新增用例：`maxEvents: 3` + 追加一条，断言仍能收到新事件。 |
| D6 | **已修** | 事件 id 改用**文件内字节偏移**：新增 `JsonlLine`/`readJsonlTailLines`，`readJsonlTail` 变为薄封装；`logEventId(base, offset)`。窗口滑动不再改变同一条消息的 id。三个 reader 都改为按偏移生成；两条原本断言 `#0`/`#1` 的用例改为“两次读取 id 完全一致”。 |
| D7 | **已修** | `HarnessProviderConfig.parse` 保留 `enabled: false` 的项，`ProviderRegistry.load` 合并后跳过 → 同 id 即可禁用内置项。原“enabled 为 false 的项被丢弃”用例改写为“同 id 的 enabled:false 覆盖项会禁用内置项”，另加注册表级用例（`resolved` 从 8 变 7）。 |
| D8 | **已修** | `_resolveShell` 先看用户给 `shell` 配的 `executable`，解析不到再回落到平台默认（Windows `powershell.exe` / POSIX `$SHELL` → zsh/bash/sh）。新增用例。 |
| D9 | **已修** | `_beginWatching()` 在每个 `await` 之后复查 `_disposed`，再建 `Timer.periodic`。 |
| D10 | **已修** | `_start()` 在 `_registry.load()` 之后、`_state.value = online` 之前都复查 `_disposed`；`_muxEvents` 改为 `??=` 避免重复订阅。 |
| D11 | **部分修复** | `StudioMux` 新增 `maxExitedSessions`（默认 8），超限时从 `_sessions` 移除最旧的已退出会话并清空其滚动缓冲。**未** 调用 `MuxSession.dispose()`：界面可能还拿着该句柄，dispose 会让它的 `ValueNotifier` 抛“used after dispose”；去掉引用后由 GC 回收（定时器/订阅在退出时已释放）。新增用例。 |
| D12 | **已修** | `PtyLauncher` 新增 `Future<void> dispose()`；`ScriptPtyLauncher`/`PipePtyLauncher` 只释放自己创建的 `ProcessSupervisor`；`StudioMux` 在自建 launcher 时释放它，外部注入的不动；`LocalHarnessHost` 在自建 launcher 时调 `dispose()`。新增用例：外部注入的 launcher 不被 mux 释放。 |
| D13 | **已修** | 历史会话的 controller 加 `onCancel: () => controller.close()`，取消订阅即释放，二次订阅不会再抛“已经监听过”。 |
| D14 | **已修** | `refreshLogSessions()` 重建条目后，把新状态推给已打开的日志句柄（`updateStatus`）；条目消失时置 `exited`。 |
| D15 | **已修** | `logSessionId` 改为相对日志根目录的路径（`p.isWithin` 判定，分隔符归一为 `/`），跨项目同名文件不再互相覆盖。 |

补充：`README.md` 补了 `enabled: false` 与 `requiresTerminal` 的语义，以及
“管道后端下不提供 TUI harness”的说明。

## 明确拒绝 / 保留的项

- **D0 的原生 ConPTY**：未做。加依赖（`flutter_pty`）或写 FFI 不在本阶段授权范围，
  且会改动构建产物；已用“标不可用 + 明确报错”堵住用户可见的坏路径，根因留给 root。
- **D11 的 `MuxSession.dispose()`**：按上表理由改为“清空滚动缓冲 + 去掉引用”，
  不销毁句柄持有的 notifier。
- **D3 提出的“follower 自己缓存最近 N 条事件”**：未采纳。重建 follower 时会按
  `since` 重读整个尾部窗口，效果等价且不引入第二份事件缓存；重复推送由稳定 id
  （D6）保障可去重。

## 新增/调整的测试

| 文件 | 变更 |
| --- | --- |
| `pty_process_test.dart`（新） | stderr 转发、terminate 幂等、双管道结束才 close |
| `local_harness_host_test.dart` | `detach → open` transcript 仍活、`detach → stop` 仍结束、两次 `watchSessions` 都非空、管道后端隐藏 TUI、`open()` 返回同一句柄 |
| `studio_mux_test.dart` | `sendLine('你好')` UTF-8、退出会话超限回收、外部 launcher 不被释放 |
| `live_log_follower_test.dart` | 窗口封顶后仍推送新事件 |
| `provider_registry_test.dart` | `enabled:false` 禁用内置项、shell 覆盖优先、管道后端可用性过滤 |
| `executable_locator_test.dart` | `enabled:false` 保留、`requiresTerminal` 解析 |
| `claude_code_log_reader_test.dart` / `codex_log_reader_test.dart` | 事件 id 跨读取稳定 |

仍未运行任何测试（规则如此），以上均为静态推断；`dart analyze` 已覆盖全部
新老测试文件的类型检查。

## 仍未解决

1. Windows 真机 TUI（需 ConPTY，见 D0）。
2. 真实 Claude/Codex/Pi 日志的字段校验（夹具是自写的）。
3. `script` 在 BusyBox 下的兼容性。

一个过程提醒：`dart format lib/harness`（不带子目录）会重排契约里的
`HarnessReply` 构造函数。我每次格式化后都用 `git diff lib/harness/harness_host.dart`
核对并手工还原，最终提交无契约改动；后续只格式化 `lib/harness/local` 与
`test/harness/local`。
