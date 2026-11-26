# Journal - lichengyu (Part 1)

> AI development session journal
> Started: 2026-09-21

---



## Session 1: Repair terminal bootstrap and publish v1.0.1
<!-- trellis-session: v=2 fp=ecc60c99dffc4982 -->

**Date**: 2026-11-15
**Task**: Repair terminal bootstrap and publish v1.0.1
**Branch**: `main`

### Summary

Four existing Herdr pi workers implemented bootstrap defaults, source staging, port configuration, cgroup delegation and optional updater behavior. Integrated regressions, pushed standalone repository and v1.0.1 to GitHub/CNB, verified release CI and CNB images.

### Git Commits

| Hash | Message |
|------|---------|
| `f883070` | fix(deploy): simplify bootstrap defaults and repair rootless setup |
| `8d78afe` | docs(deploy): clarify runtime limit verification |

### Testing

- [OK] 74 local tests: 69 pass, 5 Linux-only skipped; actual Compose and ShellCheck passed; GitHub release CI passed.

### Status

[OK] **Completed**

### Next Steps

- Live ECS bootstrap remains operator validation; no production host was modified.


## Session 2: Published Studio Git preview v5.0.5-git.2
<!-- trellis-session: v=2 fp=ab40123b0ea57fec -->

**Date**: 2026-11-21
**Task**: Published Studio Git preview v5.0.5-git.2
**Branch**: `release/studio-git-ui-20261120`

### Summary

Published the integrated Studio Git UI and native API 2 preview after all required cloud checks.

### Main Changes

- Pi A fixed file URLs in the mobile integration fixture. Root reviewed and pushed Plugin 53ad359, Core 79bfe01 and App 6473c16.

### Git Commits

| Hash | Message |
|------|---------|
| `6473c165b94367151655f7ebd5a9cf25ff219da5` | build: pin the corrected Git mobile fixture for preview |

### Testing

- [OK] GitHub tagged run 44820763009 passed all 18 required jobs. Core: 2394 visible passes and 26 existing skips. Production Flutter 3.50.0 iOS clone/conflict/merge/push flow passed.
- [OK] Verified 13 uploaded release assets and all 12 ZIP digests against SHA256SUMS. Downloaded and inspected the actual released Windows ZIP. Mobile native binaries and CA hashes matched.
- [OK] No local tests, builds or App launches. Original cloudterminal HEAD, index and file hashes remained unchanged.

### Status

[OK] **Completed**

### Next Steps

- User installs preview for physical-device acceptance. Older iOS SDK diagnostics and live-provider acceptance remain separate.


## Session 3: Git branch cards and mobile keyboard fixes
<!-- trellis-session: v=2 fp=a826ff97a1b00e71 -->

**Date**: 2026-11-21
**Task**: Git branch cards and mobile keyboard fixes
**Branch**: `release/studio-git-ui-20261120`

### Summary

Published v5.0.5-git.5 with branch cards, clone keyboard layout and a selection-preserving keyboard-dismiss action. All 18 cloud jobs and 24 new regressions passed. Release assets and Android provenance verified.

### Main Changes

# Git UI follow-up: completed

## Delivered behavior

- Project cards read the local repository HEAD asynchronously and show the current branch. Unborn branches, linked worktrees and detached HEAD are supported. Cards refresh on Home refresh, editor return, retained-editor minimize and App resume.
- Git dialogs apply the mobile keyboard inset once. The clone form remains scrollable and mobile opening does not autofocus the URL field.
- The editor symbols bar has a fixed keyboard-dismiss button at the far right. The action hides the input method while preserving editor focus, code and selection. Its rendered target is 44 by 44 points and stays fixed while symbols scroll.

## Source and immutable release

- App: 23b81a4abf33c9cec73490ba498bae5110acd587
- Core: 0f18c3692791e66aa8cb74e71f49ea52469b7295
- qfli_git: 53ad359159258706d4c242e70a2db0e1d075dabc
- Java receiver contract: 60d97c783f29da767fafe503980812101f6aa61f
- Branch: release/studio-git-ui-20261120
- Tag: v5.0.5-git.5
- Release: https://github.com/azurekiln2333/qflistudio-next/releases/tag/v5.0.5-git.5
- Release ID: 453270763
- Published: 2026-11-21 07:11:23 Asia/Shanghai

App and Core commits were pushed to GitHub. The App workflow pins the exact Core commit. The existing .3 and .4 tags were preserved. The .4 release gate rejected two real keyboard-action regressions and no .4 release was published. The corrective Core commit addresses those regressions without weakening the selection or geometry assertions. See keyboard-fix-review.md.

## Cloud verification

- Authoritative App run 44833095726: all 18 jobs succeeded, including both complete Flutter suites, Java/companion checks, Windows assistant, production-SDK Git iOS simulator integration, eleven installer targets and publication.
- Independent Core run 44833065983: 2418 visible tests passed, 26 existing skips, zero errors, 249097 ms.
- All 24 new regression cases passed: HEAD reader 9, project cards 9, clone-dialog layout 3, keyboard dismissal 3.
- Formatting, targeted static analysis, Chinese UI-copy lint and git diff --check passed. Full Core analysis retained one existing info message.
- Duplicate branch run 44833095727 was cancelled.

## Published package inspection

The release contains 13 assets: eleven installer ZIPs, one Windows assistant ZIP, and SHA256SUMS. All twelve GitHub ZIP digests match the published manifest. The tag, workflow, release body and source pins agree.

The Android arm64 ZIP was downloaded and inspected as an archive. Its SHA256 is 29fac8992370bf74c7545a39d8ee5d351ff3e738a6c30529e91d90f0adb900f2. Outer and inner checksums pass. BUILD_INFO records the exact App/Core/plugin/native source pins. The APK contains the expected AArch64 Git library and matching CA bundle. No installer was executed.

Evidence: app-monitor-git5-verification.json, app-monitor-git5-android-verification.json, core-monitor-git5-counts.json and their raw logs/artifacts.

## Boundaries and installation

No local tests, builds, App launches, services or emulators ran. The original cloudterminal checkout was not modified. Product changes were confined to the isolated integration worktrees. Existing unrelated edits and the empty index in the primary checkout were preserved.

Android uses a temporary debug signing key generated in the cloud job. A differently signed installed build cannot be overwritten directly; back up application data before replacing it. iOS and OHOS packages require signing before installation. Windows is unsigned. macOS is ad-hoc signed and not notarized. No physical-device validation is claimed.


### Git Commits

| Hash | Message |
|------|---------|
| `23b81a4abf33c9cec73490ba498bae5110acd587` | build: pin selection-preserving keyboard action for preview |

### Status

[OK] **Completed**


## Session 4: Release QFLIStudioN 5.0.6 to GitHub main
<!-- trellis-session: v=2 fp=1d12739580de9369 -->

**Date**: 2026-11-21
**Task**: Release QFLIStudioN 5.0.6 to GitHub main
**Branch**: `main`

### Summary

Four Herdr Pi workers completed release metadata, workflow, branch and provenance reviews. App, Core and Git plugin histories are now on GitHub main. Stable v5.0.6 is Latest with all cloud gates green.

### Main Changes

- Published App 5.0.6+5000006 at 1cea029, pinned to Core c619f9ff and plugin697291a/API3.
- Fast-forwarded all three GitHub main branches and removed four fully merged App remote branches with exact-SHA lease guards.
- Preserved the original CloudTerminal workspace and unrelated dirty checkouts.

### Git Commits

| Hash | Message |
|------|---------|
| `1cea02946e5191f2a76bd8915ff0a527547f0463` | chore(release): promote verified Git integration to 5.0.6 |

### Testing

- [OK] GitHub App tag run44872268037 passed all18 jobs and published13 assets; plugin and Core prerequisite runs also passed.
- [OK] Verified OHOS artifact BUILD_INFO, inner checksums and exact uploaded archive digest. Local checks used only static analysis, formatting and artifact inspection.

### Status

[OK] **Completed**


## Session 5: Mobile files and Agents home released in 5.0.11
<!-- trellis-session: v=2 fp=532bd261cb80a3f7 -->

**Date**: 2026-11-23
**Task**: Mobile files and Agents home released in 5.0.11
**Branch**: `mobile/integration`

### Summary

Integrated the four Pi workstreams. Core main, App main and release CI passed. Published v5.0.11 with verified asset hashes. Physical-device acceptance remains pending.

### Main Changes

# 集成接管记录

日期：2026-11-23。
任务：移动端文件互通与 Agents 首页。

## 工作树

- App：`D:/MyNewProjects/_wt/mobile/int/qflistudio`。
- Core：`D:/MyNewProjects/_wt/mobile/int/qfli_studio_core`。
- 两个工作树都使用 `mobile/integration`。
- 原工作区的业务文件未纳入本次提交。
- App 的七个插件注册文件保留原状。

## 分工

| Pi | Herdr 窗格 | 范围 |
| --- | --- | --- |
| A | `w37:pC` | 原生分享入口 |
| B | `w37:p14` | 外部文件夹 |
| C | `w37:pG` | 编辑器会话与测试隔离 |
| D | `w37:pJ` | 设备信息与同步哈希 |

Pi 只改动各自负责的文件。
Codex 复核后按文件提交。
测试套件只在云端 CI 运行。
Pi-D 曾误跑本机 Node 函数探针。
Pi-A 也曾用临时脚本运行本机探针。
父级发现后已制止。
本机探针不作为验收证据。

## 已确认的根因

旧 CI 运行号为 `45136693596`。
它验证 Core 提交 `606810bd`。
旧调度脚本多次复用了这次失败结果。
旧完成标记不能证明新版已通过。

| 失败 | 证据与修复 |
| --- | --- |
| 远程设备字段为空 | 构造函数漏读当前信息帧。已有 `758a704` 补上读取。 |
| 外部文件文本读取失败 | 测试字节编码错误。外部路径解析也有遗漏。已有 `a796ccb` 与 `9847ea7` 修正。 |
| 文件树找不到 `note.md` | 空注册表跳过书签恢复。直接添加外部项目没有登记路径归属。 |
| 内置会话残留定时器 | 完整日志指向输入框默认值存储。路径探测留下 2 秒超时。 |

内置会话失败不经过远程会话等待。
已有 `cf5927a` 修复另一条等待泄漏。
本轮向测试注入内存默认值存储。
原会话行为断言保留。

## 本轮新增提交

| 仓库 | 提交 | 结果 |
| --- | --- | --- |
| Core | `f45b661` | 补充文件与会话契约。 |
| Core | `d7be205` | 本地文件也使用流式哈希。 |
| Core | `8b0d1bf` | 登记外部根。读取失败时保留文件树。 |
| Core | `f434128` | 隔离会话测试的原生存储依赖。 |
| Core | `9f83a61` | 过滤空会话 ID，固定未知状态描边。 |
| Core | `af42cfd` | 按需创建收件目录，保留显示名。 |
| Core | `21e61e0` | 等待主机首份列表，修正状态语义。 |
| Core | `fe05572` | 修正同步测试的读写与结果框等待。 |
| Core | `0bf1ffa` | 记录快照与云端验证契约。 |
| Core | `45ff454` | 在真实异步环境等待同步结果。 |
| Core | `d3d8995` | 在用例结束前释放无障碍句柄。 |
| App | `6cd795c` | 补充分享与发布验证契约。 |
| App | `e5c6056` | 准备版本 `5.0.11`。 |
| App | `f4686fe` | 修复鸿蒙分享通道重绑与失败副本清理。 |
| App | `d95361d` | 固定 Core 为 `f434128`。 |
| App | `ef5e222` | 固定 Core 为 `0bf1ffa`。 |
| App | `055dd22` | 固定 Core 为 `d3d8995`。 |

版本变更覆盖四个位置。
发布标签条件与发布说明同步变更。

## 父级复核修正

- 文件树不经过 agent 的路径解析器。
- 字段声明位置不是设备信息缺失的根因。
- 目录读取失败不能伪装为空目录。
- 刷新前不能清空要保留的目录缓存。
- 回归测试使用同一文件树实例刷新。
- 恢复成功后才能重置错误提示状态。
- 已删除目录的缓存和展开状态一并删除。
- Android 对象哈希不能标识一次投递。
- 鸿蒙预算算式改写不能限制复制峰值。

上述无效改动已撤回或修正。

## 验证状态

本机静态分析通过。
本机未运行测试套件。
本机函数探针见 `takeover-ci-d1.md`。

| 工作流 | 提交 | 运行号 | 状态 |
| --- | --- | --- | --- |
| core-check | `f434128` | `45157266417` | 测试卡住，已取消取日志。 |
| App installers | `d95361d` | `45157553417` | 已发现失败。新提交替换了本次运行。 |
| App installers | `d644b8c` | `45158844625` | 非 Core 项均通过。新提交替换本轮。 |
| core-check | `0bf1ffa` | `45161876449` | 两项同步测试挂起，已取消取日志。 |
| App installers | `ef5e222` | `45161937167` | 旧 Core 失败，Git iOS 启动超时。 |
| core-check 定向诊断 | `8d51224` | `45164365603` | 34 项结束，仅无障碍句柄清理失败。 |
| core-check 定向复验 | `8a03c30` | `45164778222` | 34 项全通过。 |
| core-check 完整验证 | `d3d8995` | `45164721090` | 通过。 |
| core-check 主分支复验 | `d3d8995` | `45165704040` | 通过。 |
| App installers 最终验证 | `055dd22` | `45165599562` | 全部通过。 |
| App installers 主分支复验 | `055dd22` | `45167745111` | 全部通过。 |
| App installers 发布验证 | `055dd22` | `45167787307` | 全部通过，已发布 `v5.0.11`。 |

App 新增修复：

- `4d5d0cc` 修正 iOS 书签选项。
- `d644b8c` 修正 companion 两项返回契约。

第二轮 companion 检查已通过。
所有移动端与桌面安装包检查已通过。
Git iOS 云端集成检查已通过。
旧的十项 Core 失败在 App 日志中已通过。
后续用例出现十四项失败和两项未完成。
四个 Pi 已按 `takeover-core-failures-1.md` 继续修复。

本轮复核发现两处额外阻塞。
首页把已订阅误当成已收到列表。
此时会过早删除快照行。
修复将区分订阅状态和收到数据。
有效空列表仍应删除旧快照。

同步测试先等待结果，再关闭结果框。
但同步函数要等用户关闭结果框才返回。
测试须先关闭结果框，再等待函数返回。
真实磁盘读写由 `runAsync` 承载。
缓存驱逐夹具的预算也有错误。
两份各 100 字节的缓存需新增 100 字节。
预算 150 字节时必须删除两份缓存。
验证仅删最旧一份时，预算改为 250 字节。
生产驱逐策略保持原样。

`0bf1ffa` 日志记录 2489 项完成。
这些已完成项没有失败。
两项同步对话框用例挂起。
最后一条事件停在第 207 秒。
两项用例都在假异步环境等待 `pending`。
但 `pending` 由真实异步环境创建。
本机 Flutter 文档说明这可能导致挂起。
`45ff454` 将等待移回 `runAsync`。
四项同步界面用例各设 60 秒上限。
定向诊断只运行同步和首页四个测试文件。
诊断分支为 `ci/mobile-diag`。
诊断工作树位于 `_wt/mobile/diag/qfli_studio_core`。
诊断工作流变更不会合入主分支。

定向测试在 11.5 秒内正常结束。
所有同步用例均已通过。
首页仅剩无障碍句柄清理失败。
该用例的状态文字断言已通过。
`addTearDown` 晚于框架的用例结束检查。
`d3d8995` 用 `finally` 在返回前释放句柄。
新版完整测试与定向复验均已启动。

完整验证已通过。
日志包含 3447 条完成记录。
没有失败记录，也没有未结束记录。
完整测试耗时约 299 秒。
定向复验的 34 条记录也全部通过。

完整状态记录在同目录的 `takeover-ci-*.json`。
查询脚本按仓库、工作流、分支和完整 SHA 匹配。
Core 已正常快进到远端主分支。
Core 主分支提交为 `d3d8995`。
Core 主分支完整验证已通过。
App 最终验证已全部通过。
Git iOS 日志明确记录 `All tests passed!`。
App 已正常快进到远端主分支。
App 主分支提交为 `055dd22`。
发布标签 `v5.0.11` 指向同一提交。
主分支复验与发布验证均已通过。
发布流程保留全部检查门槛。
2026-11-23 20:03:43 已发布安装包。
该时间使用北京时间。
发布记录 ID 为 `455366662`。
共 11 个应用 ZIP 和 1 个 Windows 助手 ZIP。
另有一份 `SHA256SUMS`。
发布核验确认标签指向 App 提交 `055dd22`。
发布说明记录 Core 提交 `d3d8995`。
清单中的 12 个哈希均与 GitHub 资产摘要一致。
本机只下载哈希清单，没有重新下载全部 ZIP。
发布流程已检查包内来源信息与文件哈希。
证据见 `takeover-release-v5.0.11.json`。

旧 Git iOS 日志停在等待 VM Service 端口。
等待期间没有出现测试通过或断言失败。
该步骤达到 20 分钟上限后失败。
最终验证使用同一 Git 插件提交。
它连接成功，随后通过集成测试。
现有日志不能确定旧运行的底层错误。

Pi-B 随后取得旧运行的完整诊断附件。
系统日志在 11:25:28 UTC 记录 VM 服务已监听。
工具日志仍停在等待该服务端口。
因此不能再把此现象称为 VM 服务未启动。
证据指向工具发现或连接阶段停滞。
具体失效机制仍未确定。
新版分支、主分支与发布验证均未复现。

## 交付状态

四个 Pi 的实现与复核均已汇总。
代码已合入 App 和 Core 的远端主分支。
`v5.0.11` 已发布，产物检查通过。
父任务仅勾选主分支 CI 验收项。
真机验收仍保留待办。
步骤见 `device-acceptance.md`。
父任务和子任务暂不归档。

## 验证边界

真机分享与外部目录授权尚未验收。
iCloud 占位下载尚未做真机验收。
LCSign 重签后的覆盖安装尚未复现。
外部目录功能不能证明安装丢文件已解决。

鸿蒙在无法读取来源大小时仍整份复制。
这种情况可能短暂超过收件箱配额。
Android Activity 重建后的投递行为待真机确认。

华为登录与 iOS 存储诊断保留在：
`docs/login-ios-files-investigation-20261123.md`。
本次没有改动登录身份策略。


### Git Commits

| Hash | Message |
|------|---------|
| `055dd223e4641419cc8e603405a134508508094c` | ci(release): pin core after mobile widget verification |

### Status

[OK] **Completed**

### Next Steps

- Run the device acceptance checklist, including LCSign update behavior.
