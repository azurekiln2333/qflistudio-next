# 最终复核：Harness Hub 集成

分支：core `harness/integration`，app `harness/integration`。
工作树：`D:/MyNewProjects/_wt/harness/integration/{qfli_studio_core,qflistudio}`。
基线：core `f9b6485`（含契约），app `d31ad29`。
用户主工作树未参与，未推送，未打标签。

## 1. 提交序列

### core（`f9b6485` 之后）

| 提交 | 标题 | 需求 |
| --- | --- | --- |
| `e183506` | feat(harness): add the local harness host | R4、R5、R8、R11、AC1、AC11 |
| `54ca0d2` | feat(harness): add the herdr host and the remote harness host | R2、R6、R7、R9、AC2、AC3、AC8 |
| `fb64bab` | feat(agent): discover project skills and inject Trellis context | R13、R14、R15、AC9、AC10 |
| `eb12ba2` | feat(harness): add the agents hub and the unified Agents surface | R1、R2、R3、R10、R11、R12、AC4、AC5、AC6、AC7 |
| `42cfe8d` | feat(harness): wire the four hosts into the hub | R1、R9、集成 |
| `92ab3cb` | fix(harness): open the Agents pane on the studio host | R1、AC4 |

### app（`d31ad29` 之后）

| 提交 | 标题 | 需求 |
| --- | --- | --- |
| `8eafd65` | feat(tools): route the Agents card to the editor Agents surface | R1、R10 |
| `4142a7d` | feat(harness): register the harness hosts at startup | R1、R9、集成 |

构建方式：四个 `harness/pi-*` 分支各用一次 `git merge --squash` 进入集成工作树，
再按组提交。没有合并提交，历史是一条直线。`implement.md` 要求「一个特性一个
提交」，这里按分支分组，共八条。四条分支改动的文件集合互不重叠，拆到特性级
只会得到编译不过的中间提交，所以没有继续拆。

契约文件 `lib/harness/harness_host.dart` 与基线逐字节一致（`git diff f9b6485`
对该文件为空）。

## 2. 冲突处理

文件级冲突为零：四个分支改的文件不相交。

语义冲突五处，都在这条集成分支上解决：

1. **主机上下文类型**。`HubHostContext` 原来把 `auth`、`projectStore`、
   `settings` 都声明成 `Object`，Pi-C 这样做是为了在别人的实现还没合入时也能
   编译。集成后补了 `runtime`、`projectId`、`signedIn`、`desktop` 四个字段，
   让内置 Agent 主机有运行时可用。
2. **PTY 接缝**。Pi-B 的 `HerdrHost` 只认 `HarnessPtyFactory`，Pi-A 的后端是
   `PtyLauncher`。新增 `lib/harness/local/studio_mux_pty.dart` 做适配，平台代码
   仍然只有一份。后端没有真实终端时适配器抛异常，Herdr 退回快照终端。
3. **远程主机是异步的**。`RemoteStore.open()` 是异步工厂，而 hub 的构造是同步
   的。给 hub 加了 `addHost()`，并新增 `OwnedRemoteHarnessHost` 持有
   `RemoteController` 与 `HerdrController`，在 `dispose()` 里一起释放。
   `RemoteHarnessHost` 本身只摘自己的监听，端口由调用方提供，直接放进去会
   泄漏一条 WebSocket。
4. **默认主机**。Pi-C 让桌面端默认停在本机。这样打开 Agents 面板看到的会是
   「本机没有会话」，内置 Agent 的对话被挡在后面，等于回退了编辑器原来的行为。
   改成优先选内置 Agent，没有内置 Agent 时才退到本机、再退到远程。
   `test/harness/harness_hub_test.dart` 的断言随之更新，另加了一条「没有内置
   Agent 时退回本机」的用例。
5. **装配入口**。Pi-C 留的 `HarnessHosts.registerDefault` 没人调。新增
   `lib/harness/hub/default_harness_hosts.dart` 作为唯一接线处，应用启动时调
   一次。编辑器页仍然只调 `harnessHubFor(...)`。

## 3. 验收项状态

| 项 | 状态 | 依据 |
| --- | --- | --- |
| AC1 三系统启动 shell、Claude、Codex、Pi | **需要真机**（Windows 不满足） | 代码路径齐全。Windows 只有管道后端，交互式 TUI 起不来。管道后端下需要终端的 provider 标成不可用，`launch()` 明确报错，界面不会给出必定失败的入口。macOS 与 Linux 用 `script` 后端，未启动过真实进程。 |
| AC2 Herdr 列表与 `herdr agent list` 一致 | **需要真机** | 解析器与状态映射有单测。零信任探测记录在 `pi-b.md` 第 11 节。未在真机比对。 |
| AC3 窗格实时刷新与输入 | **需要真机**（Windows 降级） | attach 走 PTY，集成分支已接上适配器。Windows 没有 ConPTY，只能走 1.5 s 级快照终端。 |
| AC4 关闭视图不结束会话 | **静态通过 + 需要 CI** | `detach()` 只释放视图。有面板关闭与 hub 释放的用例，未运行。 |
| AC5 结束会话需要确认 | **静态通过 + 需要 CI** | 标题栏与输入框两个入口都走同一个确认对话框。有取消不结束、确认调一次的用例，未运行。 |
| AC6 手机切换本机与已绑定电脑 | **需要真机** | 手机端按平台策略隐藏本机与 Herdr 主机，只留内置 Agent 与远程。远程主机在面板挂载后异步装配。未在设备上配对。 |
| AC7 手机按键栏 | **静态通过 + 需要真机** | Esc、Tab、Ctrl、Alt、方向键、粘贴六个键位有 widget 用例，未运行。真机键盘未试。 |
| AC8 旧远程协议兼容，手动配对可用 | **静态通过 + 需要真机** | `remote_control` 内部实现未删。`session_view.dart` 被 Pi-B 改过，只调整终端输出的分发位置，协议、请求 ID、重连与重放语义未动。未对真实 relay 配对。 |
| AC9 显示当前任务与阶段 | **静态通过 + 需要 CI** | 读取器、上下文文本、面板模型都有单测。面板视图从未渲染过。 |
| AC10 调用项目技能目录的 SKILL.md | **静态通过 + 需要 CI** | 五个目录的发现与按需加载有单测。未与真实模型往返。 |
| AC11 配置添加未识别的 harness | **静态通过 + 需要 CI** | 配置解析与合并有单测，同 id 覆盖、`enabled: false` 禁用内置项都覆盖。未在设备上加载真实配置文件。 |
| AC12 自动检查覆盖 | **需要 CI** | 单测写在仓库里，本地一条都没跑（简报要求）。 |

本地只跑了 `flutter pub get`、`flutter analyze`、`dart format`。测试、构建、
模拟器、虚拟机、服务一律未启动。

## 4. 静态检查结果

### core（`_wt/harness/integration/qfli_studio_core`）

```text
flutter pub get                          # 解析成功，无新增依赖
flutter analyze --no-pub lib             # 2 条 info，均在基线上已存在
flutter analyze --no-pub test            # No issues found
flutter analyze --no-pub lib/harness test/harness   # 只剩契约那条 info
dart format <本分支改动的 6 个文件>        # 已格式化
```

两条既存 info：`lib/chat/composer_card.dart:346` 的
`curly_braces_in_flow_control_structures`，`lib/harness/harness_host.dart:6` 的
`unnecessary_import`。两个文件都不在本分支的改动里。契约文件的这条按约定保留。

### app（`_wt/harness/integration/qflistudio`）

```text
flutter pub get                          # 解析成功
flutter analyze --no-pub lib             # 1 条 info，基线既存
dart format lib/main.dart                # 0 改变
```

既存 info：`lib/main.dart:3` 的 `unnecessary_import`。

`flutter pub get` 重新生成了七个平台插件注册文件，`git diff --numstat` 显示
零行变化（只有换行符状态），没有提交。

格式化的坑：`dart format lib/harness`（不带子目录）会重排契约里 `HarnessReply`
的构造函数。本分支每次格式化后都用 `git diff` 核对并手工还原，最终契约无改动。
`dart format lib test` 也会重排 `test/harness/hub_ui_test.dart` 等 Pi-C 的既有
文件，那些纯格式改动已经还原，没有混进提交。

## 5. 装配结果

应用启动时 `registerDefaultHarnessHosts()` 注册一次工厂。每个编辑器页建一个
hub，工厂按平台给新实例：

| 主机 | 平台 | 说明 |
| --- | --- | --- |
| 内置 Agent（`studio`） | 全部 | 需要 `AgentRuntime` 与项目 id；登录态由 `auth.isLoggedIn` 探针提供 |
| 本机（`local`） | 桌面 | 自带 provider 注册表、`PtyLauncher`、`StudioMux` |
| Herdr（`herdr`） | 桌面 | 已接 PTY 适配器；拿不到真实终端时退回快照 |
| 已绑定电脑（`remote:<id>`） | 全部 | 异步装配，自带控制器所有权 |

默认落在内置 Agent。手机端不装本机与 Herdr 主机，与 hub 的平台策略一致。

Trellis 上下文默认走 Dart 解析。`TrellisContextLoader(preferPython: true)` 只在
`allowProjectScript` 也打开时才执行项目脚本，集成后仍是关闭状态，等桌面端设置
项就位再开。

## 6. 剩余风险

1. **Windows 没有真实终端**。这是最大的一条。ConPTY 需要新依赖或 FFI 模块，
   不在本阶段授权内。当前用「标不可用 + 明确报错」堵住用户可见的坏路径。
   AC1 在 Windows 上不成立。
2. **远程主机一页一条连接**。每个编辑器页建一个 hub，每个 hub 一个
   `RemoteController`，页面销毁时释放。同时开多个项目页就有多条 WebSocket。
   如果确认不可接受，应改成应用级单例并给 hub 传 `ownsHosts: false`。
3. **内置 Agent 会话可能重复出现**。侧边栏的原生会话列表与 hub 的会话列表
   都来自同一个 `AgentSessionStore`。当前主机是内置 Agent 时，hub 的会话分区
   会隐藏自己，所以不会同时出现两份。切到本机等外部主机时，内置 Agent 的会话
   仍只在上半部分显示。这条依赖 Pi-C 的隐藏逻辑，未在真机核对过视觉结果。
4. **Herdr attach 依赖真实终端**。Windows 上只能看快照，刷新是 1.5 s 级。
5. **`script` 在 BusyBox 下的兼容性**。Linux 用 `-q -e -f -c`，Alpine 之类环境
   可能不认 `-e`。
6. **真实日志字段未校验**。Claude、Codex、Pi 的读取器只用自写夹具验证过。
   字段不符时读取器返回空列表，不抛异常，界面上表现为「没有历史会话」。
7. **单元测试一次都没跑**。全部结论是静态推演，等云端 CI。
8. **规范漂移未修**。`.trellis/spec/frontend/vibe-skills.md` 还是 Draft，没有
   写五个技能目录与两个新枚举值。Pi-D 按简报拒绝改它（该文件属于另一个任务，
   且只在主树里）。需要 root 在合并后同步。
9. **`flutter pub get` 的插件注册文件常驻脏状态**。只有换行符差异，不影响构建，
   但每次 `git status` 都会看到它们。

## 7. 下一步

1. 云端 CI 跑 core 与 app 的 `flutter test`。
2. 真机验收 AC1（macOS 与 Linux）、AC2、AC3、AC6、AC7、AC8。
3. 决定 Windows ConPTY 是否立项。
4. 由 root 决定远程主机的所有权模型：每页一个，还是应用级单例。
5. 同步 `vibe-skills.md` 与 Trellis 相关规范。
6. 全部通过后再推送、打标签。