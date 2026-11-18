# 执行计划

core 仓库路径：`D:\MyNewProjects\qfli_studio_core`。下文 `lib/`、`test/` 指 core。

## 分工

| Pi | 工作流 | 独占范围 |
|---|---|---|
| pi-A | W-A 布局壳、导航、侧边栏、登录引导、最终集成 | `lib/layout/`、`lib/shell/`、`lib/sidebar/`、`lib/pages/home_page.dart`、对应测试 |
| pi-B | W-B harness、会话存储 | `lib/vibe_coding/`、`lib/session/`、`lib/services/` 中的 AI 调用、服务端 AI 路由、对应测试 |
| pi-C | W-C 输入卡片、对话流、项目页 | `lib/chat/`、`lib/pages/project/`、对应测试 |
| pi-D | W-D core 历史同步、CI/CD、签名、提交、发布 | 两个仓库的 CI 文件、`android/` 构建配置、git 操作 |

每个 Pi 只改自己的独占范围。需要别人改文件时，写进自己的 `status/pi-X.md` 的「请求」节。

## 阶段 1：实现（4 路并行）

### W-A（pi-A）

1. 落地契约：`breakpoints.dart`、`workbench_state.dart`、`login_gate.dart`（design.md §5）。
2. 实现工作台壳：三种宽度的布局（design.md §3）。中栏嵌入现有编辑器宿主。右栏和 Agent 分段先放占位组件。
3. 实现侧边栏：「会话 / 文件」分段。文件列表复用 `editor/file_explorer.dart`。会话列表读 `AgentSessionStore`。
4. 改 `home_page.dart`：点击项目进入项目页。保留其他入口。
5. 实现登录引导卡片和 `ensureLoggedIn`。
6. 写 widget 测试：跨断点拉伸后状态不丢失；未登录时显示登录引导。

### W-B（pi-B）

1. 落地契约：`agent_session.dart`、`vibe_agent_facade.dart`（design.md §5）。先给出能编译的签名。
2. 实现 `AgentSessionStore` 的文件持久化。
3. 实现 `AgentFacade` 和 `AgentRuntime`，包住现有的 `VibeCodingController`。
4. 接入三档权限模式和写确认。
5. 新增 `search_text` 工具。
6. 接入模型列表和推理强度。
7. 新增用户级 skill 目录。
8. 写单元测试：权限三档、会话存取、未登录抛 `AgentLoginRequired`、`search_text`、skill 优先级。

### W-C（pi-C）

1. 落地契约：`composer_state.dart`（design.md §5）。
2. 实现输入卡片：输入区、工具行（加号、权限模式、模型、推理强度）、卡片内的发送和停止按钮。
3. 实现加号的文件选择：「项目文件」和「工作区文件」两个来源。已选文件显示为可删除的标签。
4. 实现对话流：用户消息、助手消息、工具调用条目、写确认卡片、失败和重试、空状态。
5. 实现项目页：会话列表（新建、重命名、删除）加底部输入卡片。
6. 输入 `/` 时列出 skill。
7. 写 widget 测试：工具行元素齐全；运行中显示停止按钮；写确认卡片的允许和拒绝。

在 pi-B 的实现完成之前，pi-C 用假的 `AgentFacade` 开发和测试。

### W-D（pi-D）

1. core 历史同步（design.md §7 最后一条）。结果树不一致时停下并报告。
2. 推送两个仓库现有的本地提交到各 remote。推送前把 `git log --oneline -5` 和目标 remote 列表写进 status 文件。只推已提交的历史。
3. 改签名配置。在本机生成 `android/key.properties`。先用 `git check-ignore` 确认它被忽略。
4. 解决 gradle wrapper 缺失。
5. 在临时目录并列建两个干净 worktree，模拟 CI 检出，构建已签名的 release APK。用 `apksigner verify --print-certs` 确认证书不是 debug。
6. 写 CI 配置：PR 检查，以及 tag 触发的构建和发布。
7. 把用户必须做的一次性操作写成清单：`status/pi-D.md` 的「用户操作」节。

## 阶段 2：集成（pi-A 主导）

1. pi-A 把对话流、输入卡片、项目页接进工作台壳，替换占位组件。
2. pi-A 把旧的 `AiPanel` 入口改为打开新的对话流（design.md §4 第 12 条）。
3. pi-B 和 pi-C 修复集成中发现的本范围问题。
4. 全量运行：`flutter analyze`、`flutter test`（core 和 studio）。

## 阶段 3：交叉检查

| 检查人 | 检查对象 |
|---|---|
| pi-A | W-C |
| pi-C | W-A |
| pi-B | W-D（重点：没有密钥进入受版本控制的文件） |
| pi-D | W-B |

检查人对照 prd.md 的验收标准和 design.md §4 的 12 条规则。检查人把结果写到 `check/<工作流>.md`。小问题由检查人直接修。大问题退回所有者。

## 阶段 4：提交、推送、发布（pi-D）

1. 按工作流分别提交。遵守 design.md §8。
2. 大脑粗查 `git log` 和 `git show --stat`。
3. 推送。打 tag。CI 发布 APK。CI 密钥未配置时，改为上传本机构建的已签名 APK。

## 验证命令

```
cd D:\MyNewProjects\qfli_studio_core ; flutter analyze ; flutter test
cd D:\MyNewProjects\qflistudio ; flutter analyze ; flutter test
```

基线：core 有 3 个既有失败（`test/editor_run_target_test.dart`）。验收口径是没有新增失败。

## 回滚点

- 阶段 1 结束：每个工作流的改动互相独立，可以单独丢弃。
- 阶段 4 的每个提交对应一个工作流，可以单独 revert。

## 返工执行计划（2026-11-14）

上文「阶段 2、3、4」作废。以 design.md §11.9 的流程为准。

| Pi | worktree | 工作 |
|---|---|---|
| pi-A | `_wt\pi-a\qfli_studio_core` | 嵌入编辑器页、侧边栏分段、会话列表、删除套娃页面 |
| pi-B | `_wt\pi-b\qfli_studio_core` | 会话存储 v2、并行运行时、调度、路径租约、性能 |
| pi-C | `_wt\pi-c\qfli_studio_core` | Agent 面板反馈、错误、输入卡片、模型选择 |
| pi-D | `_wt\pi-d\qfli_studio_core` + 主目录文档 | 后端配置文档、真机工具、预览工具、隔离方案调研 |

简报在 `briefs/`：`RULES-rework.md`、`CHECKLIST.md`、`rework-pi-A.md` 至 `rework-pi-D.md`。

基线分支 `wip/baseline-20261114`（core 仓库）。基线已含接口契约：`AgentLiveStatus` 与 `AgentRuntime` 的 5 个新成员。

主目录的备份：`D:\MyNewProjects\_backups\workbench-rework-20261114-025148\`。

合并顺序：B、C、A、D。合并到 `rework/integration`，通过关卡 2 后才应用到主目录。

## 第四轮返工与续跑计划（2026-11-14）

### 恢复现场背景

12:20 多路并发全量测试触发内存耗尽，12:40 服务重启使四路 Pi 回到空闲。

内存残留 31 个孤立 `flutter_tester.exe`（约 2.1 GB），以及锁屏导致的真机阻塞。

派发前先终止孤立测试进程。各工作区全量测试一律限制 `--concurrency=2` 或 `-j 1`。

### 各路续跑交付

| Pi | worktree 与分支 | 续跑任务 | 状态文件与要求 |
|---|---|---|---|
| `pi-A` | `_wt\pi-a\qfli_studio_core` (`rework/pi-a`) | 窄屏顶栏去图标与角标迁移 | 跑通 analyze 与限并发全量测试，提交后写 `status\pi-A-rework-4r.md` |
| `pi-B` | `_wt\pi-b\qfli_studio_core` (`rework/pi-b`) | 结构化错误详情、脱敏与连接探测 | 跑通 analyze 与限并发全量测试，提交后写 `status\pi-B-rework-4r.md` |
| `pi-C` | `_wt\pi-c\qfli_studio_core` (`rework/pi-c`) | 修 `composer_card` 溢出及失败用例、接详情诊断卡 | 全量限并发通过后提交，写 `status\pi-C-rework-4r.md` |
| `pi-D` | `_wt\pi-d\qfli_studio_core` (`rework/pi-d`) | 整理 `final` 48 图证据。检查设备解锁后跑 J8 至 J11 | 若仍锁屏则立即汇报已有证据与阻塞，写 `status\pi-D-rework-4.md` |

续跑统一简报见 `briefs\round4-resume.md`，与 `briefs\RULES-rework.md`、`briefs\rework-round4.md` 同效。

### 集成与真机验证步骤

1. 收齐四路 `DONE`（或 `pi-D` 锁屏 `BLOCKED`）报告后，大脑运行关卡 1。
2. 大脑按 B、C、A 顺序合入 `rework/integration`，确认集成分支分析与全量测试通过。
3. 安排交叉验证第四轮改动，由 `check-d` 导出含第四轮界面的截图。
4. 真机解锁后，用新版集成代码重新编译安装 HAP，跑通 CHECKLIST J1 至 J11 及连接诊断验证。
5. 通过关卡 2 后把集成分支相对基线的差异合入主仓库，并检查 `studio` 工作区洁净度。
