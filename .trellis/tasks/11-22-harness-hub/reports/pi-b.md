# Pi-B 报告：Herdr host 与远程 host（HerdrHost / RemoteHarnessHost）

分支 `harness/pi-b`，工作树 `D:/MyNewProjects/_wt/harness/pi-b/qfli_studio_core`。
App 工作树 `D:/MyNewProjects/_wt/harness/pi-b/qflistudio` 未改动：本阶段只交付
core 的两个 host，界面由 Pi-C 接入。基线 `f9b6485`（契约），契约文件
`lib/harness/harness_host.dart` 未修改。

## 1. 交付摘要

Core 新增 17 个实现文件 + 6 个测试文件（共 23 个文件），实现契约
`HarnessHost` 的 Herdr 一侧与已绑定电脑一侧。

- **HerdrHost**（id `herdr`，kind `local`，label `Herdr`）：只通过公开的
  `herdr` 命令行与 Herdr 通信，不读 socket、配置或状态文件。可执行文件定位
  顺序为显式设置 → `QFLI_HERDR_PATH` → `PATH` → 平台常见安装目录（含 Windows
  `%ProgramFiles%\herdr-*`、`%LOCALAPPDATA%\Programs`、scoop shims、cargo
  bin；macOS `/opt/homebrew/bin` 等）。每次调用都是一个 argv 元素、
  `runInShell: false`，文本里的空格/引号/`;` 不会被当成 shell 语法。
- **状态映射**：`idle/working/blocked/done/unknown` 一一对应
  `HarnessSessionStatus`。`done` 与 `idle` 刻意不合并：`done` 表示上一轮结束、
  等人查看，列表可以给完成标记。标题取 `terminal_title_stripped` →
  `terminal_title` → `name` → `<agentKind> · <paneId>`；`cwd` 直接来自 CLI；
  `sourceRef` = `pane_id`；provider 用 Herdr 探测到的 agent 类型（无 agent 的
  面板为 `shell`）。
- **实时视图**：优先在 PTY 里跑 `herdr agent attach <target>`（默认不带
  `--takeover`，避免抢走用户自己的 Herdr 客户端）；PTY 不可用时回退到
  `pane read` 快照重放（1.5 s 一次），输入经 `pane send-text` / `pane send-keys`
  送达。两条路径共用同一个 `HarnessTerminalChannel`，界面无需分支。
- **状态刷新**：不是紧轮询。有 agent 处于 `working` 时，循环阻塞在
  `herdr agent wait <target> --until …`（预算 20 s，超时属正常）；全部空闲时
  只做 30 s 一次的安全刷新。用户操作后可 `refreshNow()` 立刻唤醒。
- **Herdr 缺失**：`state = unsupported` 并给出 `HerdrInstallHint`（标题、正文、
  https://herdr.dev、找到但跑不起来的路径），UI 不必自己拼文案。
- **RemoteHarnessHost**（kind `remote`）：包装既有 `remote_control` 模块，把
  三条来源合并成一份列表——Claude/终端会话（`RemoteController`）、桌面 Herdr
  面板（`HerdrController`）、Codex 会话（`CodexThreadView`）。所有动作都落到
  既有控制器上，没有新增请求、没有改 wire 协议、没有改 request id 或重连/重放
  语义。
- **句柄语义**：`detach()` 只释放视图与订阅，不发 `session_close`、不关面板；
  `stop()` 才结束（Herdr 为 `pane close`，远程会话为 `closeSession`），调用方
  必须先让用户确认。审批只有显式 `reply()` 一条路径，无法识别的 decision 一律
  按 `deny` 处理（失败关闭），绝不因为“打开看了一眼”就自动同意。

## 2. 提交

| 提交 | 说明 |
| --- | --- |
| `c1625ad` | feat(harness): add the herdr host and the remote harness host（17 个 lib 文件 + 6 个测试文件） |
| `09df701` | fix(harness): read remote herdr panes instead of a stale push cache（远程 Herdr 面板按需读取，而不是依赖推送缓存） |

## 3. 文件

实现（`lib/harness/`）：

```
pty/harness_pty.dart              PTY 注入缝：HarnessPty / HarnessPtyFactory / HarnessPtyException
herdr/herdr_models.dart           agent / workspace / server status 的 JSON 映射与能力集
herdr/herdr_cli.dart              唯一的 herdr 调用点：argv 组装、envelope 解析、错误码映射
herdr/herdr_platform.dart         条件导出（io / web stub）
herdr/herdr_platform_io.dart      可执行文件定位 + HerdrCliRunner（process_supervisor、2 MB 上限）
herdr/herdr_platform_stub.dart    web：报告“不可用”，不崩
herdr/herdr_input.dart            终端字节 → send-text / send-keys 的纯函数翻译
herdr/herdr_terminal.dart         PTY attach 终端与快照重放终端
herdr/herdr_session.dart          HerdrSessionHandle（会话句柄）
herdr/herdr_host.dart             HerdrHost（检测、刷新循环、open/launch、列表）
herdr/herdr.dart                  barrel
remote/remote_ports.dart          三个窄接口 + 到既有控制器的适配器
remote/remote_mapping.dart        状态/能力/id 前缀/transcript 的纯映射
remote/remote_terminal.dart       远程终端通道、对话流、状态通知器
remote/remote_session.dart        三类句柄：Claude/终端、Herdr 面板、Codex 线程
remote/remote_harness_host.dart   RemoteHarnessHost（合并列表、重连重读、open 路由）
remote/remote_harness.dart        barrel
```

测试（`test/`，交给 CI 运行，本地按规则未执行）：

| 文件 | 覆盖 |
| --- | --- |
| `harness_herdr_models_test.dart` | 真实 `agent list` 字段形状的解析、状态/标题/目标/能力映射 |
| `harness_herdr_cli_test.dart` | argv 精确断言、envelope 解析、错误码映射、非法输入拦截、`status`/`version` 文本解析 |
| `harness_herdr_platform_test.dart` | 显式路径 / 环境变量 / PATH / 引号条目 / `herdr-*` 目录 / POSIX 目录 / 缺失；agent 可执行文件（npm shim） |
| `harness_herdr_input_test.dart` | 文本合并、Enter/Tab/Backspace、Ctrl、方向键、SS3、孤立 ESC、未知 CSI 丢弃、中文 |
| `harness_herdr_host_test.dart` | 缺失→unsupported+hint、列表映射、`agent wait` 驱动刷新、provider 列表、PTY attach/detach、prompt/reply、stop 关面板、launch 建工作区并启动 agent、PTY 失败回退快照、坏可执行文件 |
| `harness_remote_host_test.dart` | 合并列表、状态/能力映射、Claude 对话与显式审批、未知 decision→deny、终端字节/输入/尺寸、stop 与 detach 的差别、远程 Herdr 快照与按键、Codex 对话与审批、launch、离线行为 |

## 4. 契约变更请求

无。`lib/harness/harness_host.dart` 未修改，`git status` 可证。

说明一处过程细节：`dart format lib/harness` 曾把契约里的一个构造函数折行，我在
提交前逐字还原，最终 diff 为空（格式化只影响我自己的文件）。

两点供 root 决定（不改也能工作）：

1. `harness_host.dart` 顶部 `import 'dart:typed_data'` 与 `flutter/foundation.dart`
   重复，`dart analyze` 报一条 `unnecessary_import` info。基线就有，不在我分支修。
2. `HarnessCapability` 没有“可接收粘贴（paste 语义）”的表达。远程 Herdr 的
   `herdrSendText(..., paste: true)` 与普通键入在桌面上是两条不同的路径；当前
   harness 只用普通键入（字节级发送），粘贴仍走同一路径。若界面想要桌面原生
   粘贴模式，建议在契约里加一个能力值，而不是让 UI 猜。

## 5. 新增依赖

无。复用 `flutter/foundation.dart`、`dart:io`（仅 io 平台文件）、
`services/process_supervisor.dart`、`remote_control`（`models/protocol.dart`、
`models/herdr.dart`、`state/remote_controller.dart`、`state/herdr_controller.dart`、
`state/session_view.dart`、`state/codex_thread_view.dart`），以及既有
`HerdrPaneSnapshot` 的重放数学（本地与远程两条路径共用，避免两套网格计算）。

## 6. 静态检查结果

在 `qfli_studio_core` 工作树内执行：

- `flutter pub get`：成功（依赖未变化）。
- `dart format lib/harness test/harness_herdr_*.dart test/harness_remote_host_test.dart`：
  `Formatted 23 files (0 changed)`（提交前状态）。
- `flutter analyze lib/harness/herdr lib/harness/pty lib/harness/remote` + 6 个测试文件：
  `No issues found!`。

按规则未运行 `flutter test`、未构建、未启动模拟器/WSL/服务，也未对真实 pane
执行 `attach` / `prompt` / `send-keys`。Herdr 侧只做了只读探测
（`--help`、`status`、`agent list`、`workspace list`、`pane list`、`api schema`），
用于确认字段形状与命令语义。

## 7. 假设与设计决定

1. **PTY 由外部注入。** Core 里没有 ConPTY/forkpty 实现（Pi-A 也确认了这一点：
   他的 `StudioMux` 用 `PtyLauncher` 抽象，Windows 退回管道）。因此
   `HerdrHost` 依赖 `HarnessPtyFactory` 注入，自己不做平台相关代码；测试用假
   factory。接缝协调见第 10 节。
2. **Herdr 的“新建会话”= 新工作区 + 在根面板启动 agent。** `agent start` 要求
   面板已处于交互式 shell 提示符，`workspace create` 返回的 `root_pane` 正好提供
   这个前提。默认 `--no-focus`，不打扰用户当前焦点。
3. **HerdrHost 不提供 shell 会话。** `herdr agent list` 只列有 agent 的面板，裸
   shell 面板不会出现在列表里；若允许新建 shell，会话会在下一次刷新时凭空消失。
   因此 `providers()` 只给 agent 类型，`launch(providerId: 'shell')` 显式报错，
   而不是返回一个会消失的会话。
4. **agent 名称做了清洗。** `agent start <NAME>` 的名字同时是后续
   `agent prompt` 的目标，Herdr 要求单行；因此去掉控制字符、合并连续 `-`、
   去首尾 `-`、截断 40 字符（保留中日韩字符）。
5. **Herdr 没有结构化审批。** 面板里的确认框只能用键盘回答，猜测“当前屏幕上是
   哪个对话框”极易点错，因此 `reply()` 直接抛 `UnsupportedError`，pane 处于
   `blocked` 时由用户在终端里回答。
6. **`detach()` 与 `stop()` 分离。** `detach()` 只关闭本地视图（PTY attach 客户端
   或快照轮询），Herdr 面板/远程会话继续跑；`stop()` 才结束，且契约要求调用方先
   确认（确认对话框属 Pi-C）。
7. **远程 `SessionStatus.error` 映射为 `unknown`。** 会话仍然存在、也还能再发
   提示词，标成 `exited` 是假话，标成 `idle` 会盖住用户该看的失败。
8. **远程 host 的 id 是 `remote:<配对 id>`。** 一台电脑一个 host，hub 会同时注册
   多个，常量 id 会在 map 里互相覆盖。配对 id 跨重连稳定。
9. **远程会话 id 带前缀**（`session:` / `herdr:` / `codex:`），这样三个来源里
   uuid 相同也不会撞，`open()` 只看前缀就能路由。
10. **Codex 的 `stop()` 是“打断当前回合”**，不是删线程：线程是对话，不是进程。
    没有活动回合时只做 detach。
11. **远程 Herdr 终端按需 `read`**，不依赖 `herdr_watch` 推送：harness host 不持有
    `HerdrPaneLease`，不应和 Remote Computer 页面争同一个订阅；推送到达时只是让
    下一次重绘更早发生。
12. **状态刷新的兜底节奏**：`idleRefresh` 默认 30 s、`waitBudget` 默认 20 s，都可
    在构造时注入（测试用小值）。
13. **Herdr 错误码不重试。** `agent_blocked` / `agent_not_ready` /
    `agent_prompt_stalled` / `pane_send_failed` / `connection_closed` 都映射成
    中文文案并原样带 `herdrCode`；`pane_send_failed` 与 `connection_closed` 明确
    写“不会自动重发”，因为无法确认输入是否已部分送达。
14. **不做版本猜测。** `herdr status` 是文本而非 JSON，按缩进分节解析；客户端
    protocol 只记录不校验，避免 Herdr 升级后 Studio 直接拒绝工作。

## 8. 未验证的验收项

| 项 | 状态 |
| --- | --- |
| AC2 桌面版列出本机 Herdr 全部 Agent，状态与 `agent list` 一致 | **代码完成、未验证**。解析用真实字段形状的自写夹具覆盖；未在运行中的 Herdr 上跑过（规则 4 禁止 attach/prompt，且不构建）。 |
| AC3 打开 Herdr 面板后输出实时刷新、输入立即送达 | **未验证，且当前有前提**。PTY attach 路径是“实时”的那条；Windows 上 Pi-A 目前只有管道后端，attach 很可能不可用，会回退到 1.5 s 快照（输入仍即时送达，输出是准实时）。见风险 1。 |
| AC4 关闭会话视图不会结束桌面会话 | 逻辑与单测覆盖（`detach()` 不发任何结束命令）；未在真实桌面验证。 |
| AC5 结束会话需要用户确认 | `stop()` 是唯一结束路径，契约与实现注释都写明“调用方先确认”；确认对话框属 Pi-C，未联调。 |
| AC6 手机端切换本机与已绑定电脑 | 远程 host 提供数据源（多 host id、合并列表、`providers()`）；切换界面属 Pi-C。 |
| AC8 旧远程协议保持兼容 | 未改协议/请求 id/重连语义，适配器只转发既有方法；未做真机配对联调。 |
| AC12 自动检查覆盖 Herdr 解析 | 已写 6 个测试文件（含真实字段夹具）；按规则未本地运行，等 CI。 |
| `herdr agent attach` 在 PTY 中的实际渲染 | **未验证**。未 attach 过真实 pane；`TERM`/尺寸/全屏刷新行为需要一次真机验证。 |
| `agent wait` 的边界语义 | 文档写明“不跟踪回合：若 agent 已在工作，当前回合结束也可能命中”。对本实现无害（只是提前刷新一次），但未实测。 |

## 9. 风险

1. **Windows 没有真实 PTY（最大风险，跨 Pi）。** Pi-A 的 `StudioMux` 在 Windows
   用管道后端，`allocatesTerminal == false`。`herdr agent attach` 需要 TTY，管道
   下大概率失败或输出异常。失败会回退到快照终端（可用，但不是“实时”）。建议在
   集成前由 root 决定引入原生 ConPTY（或 `flutter_pty` 之类），并让适配器在
   `allocatesTerminal == false` 时直接抛 `HarnessPtyException`，走快照分支而不是
   卡在一个坏掉的 attach 上。
2. **`TERM` 未显式设置。** `agent attach` 继承 Studio 的环境；若 `TERM` 缺失，
   全屏 TUI 可能降级渲染。可在适配器里补 `TERM=xterm-256color`（我保留
   `environment` 参数就是为了这个）。
3. **Herdr JSON 字段漂移。** 解析对缺字段容忍（给空串/null），但 `result.agents`
   必须是数组，否则列表为空而不报错。建议后续加一条“真实 Herdr 版本”回归夹具。
4. **快照终端的读取成本**：每个打开的面板每 1.5 s 一次 `pane read`（本地）或一次
   远程读。面板多时是线性成本；已用“一次只有一个读在飞”的闸门避免堆积。
5. **远程 Herdr 面板依赖桌面端 `herdr_read` 可用**（`canControl`）。不可控时列表
   仍显示，但打开会报错——这是有意的降级，不做只读假象。
6. **`agent start` 的 320 s 超时**：冷启动一个需要登录的 agent 可能更久；超时后
   工作区与面板已经建好，但列表里还没有 agent，用户会看到一个空工作区。属可接受
   的残留（不自动清理，避免误删用户面板）。
7. **`_agentNameFor` 截断可能撞名**：两个同名前缀的长标题会得到同一个 agent 名。
   Herdr 侧若拒绝重名会返回错误，UI 会看到中文提示；未做自动加后缀（避免用户
   看不懂名字）。

## 10. 集成说明

### 10.1 给 Pi-C（hub / Agents UI）

```dart
final herdr = HerdrHost(ptyFactory: studioMuxPtyFactory);   // 可注入，见 10.2
final remote = RemoteHarnessHost(
  remote: RemoteControllerSessionAdapter(remoteController),
  herdr: HerdrControllerAdapter(controller: herdrController, remote: remoteController),
  codex: RemoteControllerCodexAdapter(remoteController),
);

herdr.state;                    // ValueListenable<HarnessHostState>
herdr.installHint;              // 未安装时的 {title, message, url, resolvedPath}
herdr.currentSessions;          // 首帧前的快照，便于页面后挂载
herdr.lastError;                // 已中文化
await herdr.providers();        // 新建会话菜单（只有 agent 类型）
final handle = await herdr.open('w37:p14');
handle.terminal;                // HarnessTerminalChannel（PTY 或快照，调用方无感）
handle.sendPrompt('...');       // → herdr agent prompt
await handle.detach();          // 关闭视图，不结束会话
await handle.stop();            // 结束会话，先弹确认
```

- `watchSessions()` 是广播流，首帧立即给出当前快照（可能为空），随后每次刷新推送。
- 远程 host 的 `open()` 用 id 前缀路由；`session:` / `herdr:` / `codex:`。
- 远程 host 的 `providers()` 只有 `claude` 与 `shell`：wire 协议里没有“在桌面新建
  Herdr 面板”的动词，列出来会点了就报错。
- Herdr 面板没有 `transcript`，`reply()` 会抛 `UnsupportedError`；UI 应隐藏
  审批按钮，只留终端。
- `stop()` 不弹确认（契约如此），确认由 UI 负责。

### 10.2 与 Pi-A 的 PTY 接缝（需要一次协调）

我新增的是 `lib/harness/pty/harness_pty.dart`：

```dart
abstract interface class HarnessPtyFactory {
  Future<HarnessPty> start({
    required List<String> argv,
    String? workingDirectory,
    Map<String, String>? environment,
    int columns, int rows,
  });
}
```

Pi-A 的 `PtyLauncher.spawn({required String executable, required List<String> arguments, …})`
返回 `PtyProcess`（`pid` 非空、`write(List<int>)`、`resize` 返回 bool、`terminate()`）。
两边形状几乎一一对应，集成时写一个 ~30 行的适配器即可：

```dart
class StudioMuxPtyFactory implements HarnessPtyFactory {
  StudioMuxPtyFactory(this.launcher);
  final PtyLauncher launcher;

  @override
  Future<HarnessPty> start({required List<String> argv, String? workingDirectory,
      Map<String, String>? environment, int columns = 80, int rows = 24}) async {
    if (!launcher.allocatesTerminal) {
      throw const HarnessPtyException('当前后端没有真实终端');
    }
    final p = await launcher.spawn(
      executable: argv.first,
      arguments: argv.sublist(1),
      workingDirectory: workingDirectory,
      environment: environment,
      columns: columns,
      rows: rows,
    );
    return _PtyAdapter(p);
  }
}
```

建议 Pi-A（或 root 在集成时）把这个适配器放进 `lib/harness/local/`，这样
`LocalHarnessHost`、`HerdrHost` 共用同一个 PTY 后端；两边都不需要改自己的
逻辑。若最终不合并，`HerdrHost` 在拿不到 factory 时会一直用快照终端，功能完整
但刷新是 1.5 s 级。

## 11. 只读探测记录（供复核）

以下均为只读命令的结果，未对任何 pane 执行 attach / prompt / send-keys：

- `herdr status`：version 0.9.3、channel stable、protocol 22。
- `herdr agent list`：`{"result":{"type":"agent_list","agents":[{agent, agent_status,
  completion_seq, cwd, focused, name?, pane_id, revision, state_change_seq, tab_id,
  terminal_id, terminal_title, terminal_title_stripped, workspace_id}]}}`。
- `herdr workspace list`：`{workspace_id, label, number, focused, agent_status,
  pane_count, tab_count, active_tab_id}`。
- `herdr pane list --workspace …`：额外的 `scroll{max_offset_from_bottom,
  offset_from_bottom, viewport_rows}`。
- `herdr agent wait` 支持 `--until`（可重复）与 `--timeout`；不传 `--until` 时匹配
  idle/done/blocked。
- `herdr agent start` 的 kind 列表与 `HerdrCli.agentKinds` 一致；`--pane` 要求
  “已在交互式 shell 提示符”。
- `herdr pane read` 的 `--source` 取值：`visible`、`recent`、`recent-unwrapped`、
  `detection`；`--format text|ansi`。
- `herdr pane send-keys` 的规范转义键名是 `esc`（`escape` 也接受）。
- `herdr agent attach` 只有 `--takeover` 一个选项。
- `herdr workspace create` 支持 `--cwd`、`--label`、`--env`、`--focus|--no-focus`。

---

# 修复阶段（对应 check-a.md）

评审报告：`reports/check-a.md`。修复提交：`2115282`（`harness/pi-b`，14 个文件，+719/−87）。
静态检查：`dart format` 22 个文件 0 变化；`flutter analyze lib/harness lib/remote_control/state/session_view.dart` + 7 个测试文件 = 仅剩基线契约文件那条既存 info（`harness_host.dart:6 unnecessary_import`，未改契约）。
按 brief 未运行 `flutter test`，测试结论均为静态推演。

## 结论一览

| 编号 | 结论 | 位置 |
| --- | --- | --- |
| H1 远程终端永远空屏 | **已修** | `session_view.dart` + `remote_terminal.dart` |
| M1 没有默认可用的 PTY | **驳回（跨分支依赖）** | `herdr_host.dart:505` |
| M2 stop 后 open 返回死句柄 | **已修** | `herdr_session.dart`、`remote_session.dart`、两个 host |
| M3 快照终端输入乱序/一次按键一个进程 | **已修** | `herdr_terminal.dart` |
| M4 远程宿主 id 漂移 | **已修** | `remote_harness_host.dart` |
| M5 `agent wait` 输家进程堆积 | **已修** | `herdr_host.dart` |
| M6 Codex 状态停在打开那一刻 | **已修** | `remote_session.dart` |
| L1 dispose 与在途刷新竞态 | **已修** | `herdr_host.dart` |
| L2 closePane 绕过 HerdrActions | **已修** | `remote_ports.dart` |
| L3 provider 可用性靠猜 | **部分修复**（Herdr 侧修，远程侧驳回） | `herdr_cli.dart`、`herdr_host.dart` |
| L4 launch 丢参数 / 文本首字符 `-` | **部分修复**（参数已处理，`-` 经探测为非问题） | `remote_harness_host.dart` |
| L5 Alt 键被丢弃 | **已修** | `herdr_input.dart` |
| L6 显式路径无效报“未安装” | **已修** | `herdr_host.dart` |
| L7 每个事件复制整份事件表 | **部分修复** | `session_view.dart`、`remote_terminal.dart` |
| L8 其他小项（4 条） | **全部已修** | 见下 |
| 测试缺口 | **已补 9 条用例** | 4 个测试文件 |

## 逐条说明

### H1 远程终端永远空屏 —— 已修

`SessionView._add` 对 `TerminalOutputEvent` 是 `terminal.write(e.data); return true;`，事件从不进 `_events`，所以按 `events` 扫描的 `RemoteTerminalChannel` 一个字节也看不到。评审的判断正确，而且原测试 `harness_remote_host_test.dart` 的“a terminal session streams bytes…”按原实现必然失败。

修法采用评审建议 1（原始输出旁路），并补了回放能力：

- `lib/remote_control/state/session_view.dart`：新增 `addTerminalOutputListener(onData, {onReset})` /
  `removeTerminalOutputListener`、有上限的 `terminalLog`（32 KiB，逐块从头部裁剪）与
  `eventRevision`。`_add` 在 `terminal.write` 旁同时记录并回调；`applyBacklog(reset: true)`
  清空日志并先通知 `onReset`，避免重连后把新屏幕叠在旧屏幕上。
  这是**对共享模块的附加式改动**：既有调用方（`RemoteTerminalPane`）行为不变，只是多了一次
  记账和一次回调；不改 wire、不改 request id、不改重连/重放语义。
- `lib/harness/remote/remote_terminal.dart`：`RemoteTerminalChannel` 改为在**首次订阅**时
  回放 `terminalLog` 并挂监听（broadcast 控制器在没人订阅时发出的字节会被丢弃，构造函数里
  回放等于没回放）；`onReset` 时先发 `ESC[2J ESC[H`。

新增用例：`test/harness_remote_host_test.dart`
“a terminal replays the screen it missed and clears on reset” 覆盖首开、重开回放、reset 清屏。

### M1 没有默认可用的 PTY —— 驳回（跨分支依赖）

事实成立：`HerdrHost._createTerminal` 只有拿到注入的 `HarnessPtyFactory` 才走 `agent attach`，
否则退到 1.5 s 快照；本分支没有默认 factory，仓库里也没有 `HarnessPty` 的实现。

但评审建议的修法（把 `StudioMuxPtyFactory` 放进 `lib/harness/local/`）在本分支**无法编译**：
`lib/harness/local/` 只存在于 `harness/pi-a`，本分支没有该目录（`git status` 与目录检查均已确认），
import 会直接失败；而把一个依赖 Pi-A 内部类型的文件放进我的分支，会让任何先合我、后合 Pi-A
的顺序都编不过。brief 也把 “reuse the same PTY layer” 定为需要协调的事项，`pi-b.md` §10.2 已给出
适配器全文。

因此保留现状并把它作为**合并期动作**：集成提交时把 §10.2 的 `StudioMuxPtyFactory` 落到
`lib/harness/local/`，在 `HerdrHost` 的装配处传 `ptyFactory: StudioMuxPtyFactory(...)`（一行），
并让 `allocatesTerminal == false` 直接抛 `HarnessPtyException` 走快照。在此之前 AC3 的
“实时刷新”只在快照级别成立，这一点 `pi-b.md` §6 原本就标为未验证，不再升级为已完成。

### M2 stop 后 open 返回死句柄 —— 已修

- `HerdrSessionHandle` / `RemoteSessionHandle` / `RemoteHerdrHandle` /
  `RemoteCodexThreadHandle` 增加 `bool get isEnded => _stopped || _detached;`
  （不扩契约，只在实现类上暴露）。
- `HerdrHost.open`：命中缓存但 `isEnded` 时先从 `_handles` 摘掉，再走正常建链；
  `RemoteHarnessHost.open` 用 `_isEnded(handle)` 的 switch 做同样处理，并清三张表。
- 同时把三个远程 `onDetached` 的删除改成 `identical(...)` 条件删除：旧句柄晚到的 detach
  不会误删同名的新句柄（否则新句柄失去缓存、下次 open 再建一个）。
- `terminal` 取值改为 `(_stopped || _detached) ? null : _terminal`，与 `HerdrSessionHandle`
  的既有语义一致。

用例：远程 “a stopped session does not hand out a dead handle”、“a stopped Herdr pane reopens
with a live handle”；Herdr “a stopped pane reopens with a live terminal”。

### M3 快照终端输入乱序 —— 已修

`HerdrSnapshotTerminal.write` 以前每次 `unawaited(_dispatch(...))`，两次 write 各起一条 CLI 链，
`send-keys enter` 可能先于 `send-text hello` 到达。现在：

- 单一 `_pending` 队列 + 单飞 `_draining`，顺序严格；
- 约 12 ms 合批窗口，把一次输入的多个字符合成一次 `pane send-text`（Windows 上原来一次按键
  一个进程，50–200 ms，打字明显卡顿）；
- `_coalesce` 只合并相邻文本，按键作为边界，位置不变；
- `close()` 清空队列，之后 `write` 直接丢弃。

新增 `test/harness_herdr_terminal_test.dart`：慢调用下按键必须等文本完成、突发多块合并成一次
`send-text` + 一次 `send-keys`、失败被 `onError` 上报且不阻塞后续、close 后写入丢弃。

### M4 远程宿主 id 漂移 —— 已修

`id` 原来每次读取都从 `_remote.hostId` 现算，配对后从 `remote` 变成 `remote:<agentId>`，
而 hub 用它做 map key、`HarnessSessionInfo.hostId` 也用它盖章。现在在构造函数里解析一次并缓存
（`_id = _resolveHostId(hostId ?? remote.hostId)`），并新增可选命名参数 `hostId`，供“配对信息
晚到”的装配方传入稳定 id；已带 `remote:` 前缀的值不会二次加前缀。

用例：“the host id is resolved once and namespaced once”（配对后到、显式传入、已带前缀三种）。

### M5 `agent wait` 输家进程堆积 —— 已修

`Future.any` 只取第一个完成，其余 `agent wait` 会各自跑到 budget（20 s）才退出，而每一轮
循环又会为所有 working 面板再起一批。改为**同一时刻只等一个**（`busy.first`），
staleness 上界由 `waitBudget` 决定；注释写明了为什么不用 `Future.any`。

### M6 Codex 句柄状态不更新 —— 已修

`RemoteCodexThreadHandle` 现在在构造时 `_view.changes.addListener(_syncStatus)`，把
`remoteCodexStatus(_view.thread.status)` 写回 `_status`（值不变则不通知），并在 `detach()` /
`dispose()` 中移除监听；配合 `_statusDisposed` 守卫，避免 dispose 后写已释放的 notifier。

用例：“a Codex row follows the thread status”（active → blocked → done）。

### L1 dispose 与在途刷新的竞态 —— 已修

- `dispose()` 里 `_wake?.complete()` 改为先判 `!wake.isCompleted`（`refreshNow()` 已这样判，
  `dispose()` 漏了，重复 complete 会抛 `StateError` 让 dispose 失败）。
- `_refreshOnce`：`await` 之后、写 `_agents` 之前补 `_disposed` 检查；`_emit()` 开头也加
  `if (_disposed) return;`，避免往已释放的 `_state`/`_sessions` 写。
- `_refreshOnce` 增加 catch-all，`_runLoop` 整体 try/catch：非 `HerdrException`（解析类型意外等）
  只记 `_lastError`，刷新循环不再永久停摆。
- `HerdrSessionHandle` / `RemoteHerdrHandle` / `RemoteCodexThreadHandle` 加 `_statusDisposed`
  守卫，`update` / `markExited` / `stop` 不会写已释放的 `ValueNotifier`。

用例：Herdr “an unexpected refresh error does not stop the loop”（第一次 `agent list` 抛
`StateError`，列表仍然到达）。

### L2 closePane 绕过 HerdrActions —— 已修

`remote_ports.dart` 手拼的 `{'kind': 'pane_close', 'paneId': ...}` 换成
`remote.herdrAct(HerdrActions.paneClose(paneId))`，wire 形状回到唯一 owner。
没有改用 `HerdrController.run`：`run` 对同一个 key 的重入会**静默丢弃**，而结束会话不能被
静默丢弃；去重与错误动词化在 `stop()` 这一层本来就只有一次调用。

### L3 provider 可用性 —— 部分修复

- Herdr 侧（已修）：`HerdrProviderSpec` 增加 `verified`；表外的 kind（`agy` / `maki` / `muse` /
  `hermes` / `kilo` / `qodercli` / `letta` / `mastracode` / `kiro`）`verified: false`，
  `providers()` 对它们不再做 PATH 探测（可执行名只是猜测，`agent start --kind` 由 Herdr 自己解析），
  条目不再被隐藏。
- 远程侧（驳回）：`AgentInfo` 里没有任何“是否装了 claude”的字段，wire 也没有探测动词。把
  `available` 当“本宿主支持这种会话”而不是“桌面上确实装了”是当前唯一诚实的解释，已保留并在
  `providers()` 注释里写明；真正的可用性只能在 `launch()` 失败后回写，属 Pi-C/root 的界面语义。

用例：Herdr “a kind herdr knows but we do not is not hidden”。

### L4 launch 丢参数 / 文本首字符 `-` —— 部分修复

- `args`（已修）：`HarnessLaunchRequest.args` 非空时 `RemoteHarnessHost.launch` 直接抛
  `UnsupportedError`。wire 的三个动词都没有“额外参数”，静默丢弃会让“带参数新建”看起来成功
  却跑成别的样子。
- 首字符 `-`（驳回，已用只读探测证伪）：`herdr agent prompt zzz --help` 与
  `herdr pane send-text zzz --help` 都返回 `agent_not_found` / `pane_not_found`，说明 `--help`
  被当作 `<TEXT>` 接受而不是被解析成选项——Herdr 对 TEXT 位置本来就接受连字符开头的值。
  加 `--` 反而会在 `agent prompt` 上报 `unknown option: --help`（同一次探测结果），是有害的。

### L5 Alt 键被丢弃 —— 已修

`ESC` + 可打印字符原来是“识别但丢弃”。Herdr 没有 alt 动词（`pane send-keys --help` 只承诺
`esc`，schema 里也没有 alt 键名），但 `pane send-text --help` 明确是 “Send literal text to a
pane”，所以改成发 `ESC + char` 的字面文本：目标应用收到的字节与真实终端里 Alt+字母一致。
未知 CSI（`ESC[15~` 等）仍然丢弃——把它们当字面文本打进 shell 才是真的乱码，这一点保留原判。

用例：`harness_herdr_input_test.dart` 新增 “Alt+letter keeps the ESC prefix as literal text”
与 “Alt between typed text keeps its place”。

### L6 显式路径无效报“未安装” —— 已修

`_initialize` 在 locator 返回 null 且 `_executablePath` 非空时，报
`HerdrInstallHint(title: 'Herdr 路径无效', message: '设置里指定的路径不能执行：<path>…',
resolvedPath: <path>)`，与“没配置且找不到”区分开。

用例：Herdr “an explicit path that cannot run is not called 'not installed'”。

### L7 每个事件复制整份事件表 —— 部分修复

- 已修的部分：`SessionView` 增加 `eventRevision`，`RemoteTranscriptFeed._pump` 先比 revision，
  不再在**每个流式 token** 的通知上复制并扫描整份事件表（长会话里这是主要开销）。
- 未做的部分：`_pump` 在有新事件时仍然 `List.unmodifiable(_events)` 复制一次。真正消除需要
  `SessionView` 暴露 `eventsSince(seq)` 之类的增量 API，属于共享模块的接口设计，留给 root 决定；
  当前每次“新消息”一次复制，不是每次“token”一次。

同时顺手修了重连的一个隐患：`applyBacklog(reset: true)` 会把 view 的 seq 归零，而 feed 自己
的 `_lastSeq` 仍停在旧值，导致重连后所有条目都被当成重复丢弃——现在检测到 `view.lastSeq`
回退就把游标归零。

### L8 其他小项 —— 全部已修

- `HerdrHost.refreshProviders()`：清掉 `_providers` 缓存，运行中新装 harness 不必重启。
- `RemoteHarnessHost.watchSessions()`：Codex 目录轮询改成“第一个监听者启动、最后一个取消时停表”
  （`_watchCount` + `onCancel`），没人看列表时不再每 20 s 拉一次。
- `RemoteSessionHandle.terminal` 在 stop/detach 后返回 null（见 M2），与 Herdr 侧语义对齐。
- `herdr_platform_stub.dart` 的 Web 场景：`_initialize` 用 `kIsWeb` 区分文案
  （“此平台不支持 Herdr / 请用桌面版客户端”），不再对 Web 用户说“未安装”。

### 测试缺口 —— 已补

| 缺口 | 新增用例 |
| --- | --- |
| 远程终端字节（H1） | `harness_remote_host_test.dart`：streams bytes（原用例现在真的会通过）+ 重开回放 + reset 清屏 |
| stop → open 同一会话（M2） | 远程 2 条、Herdr 1 条 |
| `RemoteHarnessHost.id` 稳定性（M4） | 1 条（三种情形） |
| 刷新循环健壮性（L1） | Herdr “an unexpected refresh error does not stop the loop” |
| 快照终端输入顺序（M3） | 新文件 `harness_herdr_terminal_test.dart` 4 条 |
| Codex 状态刷新（M6） | 1 条（active→blocked→done） |
| Alt 组合（L5） | `harness_herdr_input_test.dart` 2 条 |
| 表外 kind 不被隐藏（L3） | Herdr 1 条 |
| 显式路径无效（L6） | Herdr 1 条 |

新增测试文件 1 个（`test/harness_herdr_terminal_test.dart`），其余为在原文件追加，共 9 条新用例。

## 需要 root 知道的两件事

1. **`lib/remote_control/state/session_view.dart` 被我改了**（+68 行，纯附加：一个监听注册对、
   一个有界日志、一个 revision 计数）。这是修 H1 的最小代价方案——不改它就只能去反解 xterm
   缓冲区。若 root 认为该文件不允许任何人碰，替代方案是我在 `harness/remote/` 里维护一份旁路
   缓冲，但那样 `SessionView` 之外的任何输入源（重连重放）都覆盖不到，H1 只能修一半。
2. **M1 仍是合并期动作**：AC3 的“实时刷新”只有在集成时接上 Pi-A 的 `PtyLauncher` 才成立，
   在那之前是 1.5 s 快照。这一点请在合并清单里保留，不要因为其它项修完就认为 AC3 已达成。
