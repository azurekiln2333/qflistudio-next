# 阶段 3：最终版本的截图和真机全流程

先读 `RULES-rework.md`、`CHECKLIST.md`。

- 状态文件：`TASK\status\pi-D-rework-4.md`。四节，不超过 60 行。
- 最后一条回复：`DONE <该路径>` 或 `BLOCKED <原因>`。

## 背景

集成分支 `rework/integration` 已含第三轮全部修复。它的最新提交就是最终版本。

上一批截图是修复合并之前导出的，已过期。

## 任务 1：重出最终截图

1. 在 `D:\MyNewProjects\_wt\check-d\qfli_studio_core` 运行 `git merge --ff-only rework/integration`。
2. 用 `tool\agent_editor_scenes_test.dart` 重出全部场景。输出到 `TASK\check\screens\final\`。
   - 场景、尺寸、主题与上一批相同。
3. 这批图必须能看出这些修复：
   - 右栏 400 宽，输入卡片的权限显示文字「每次询问」。
   - `search_text` 显示为「搜索文本」。
   - 等待确认写入时，状态行写「等待你确认写入」。
4. 新增一个场景「切换会话」：会话 A 选了某个模型和推理强度，切到会话 B 后，模型名和推理强度仍然显示。
5. 在状态文件里，对每个修复写一句：在哪张图的什么位置看到的。

## 任务 2：真机全流程

设备在 `HDC_TARGET` 指定的地址。上次它停在锁屏。

1. 先等设备解锁。每 60 秒试一次 `launch`，最多试 30 分钟。`aa start` 报 `10106102` 就是还在锁屏。不要尝试自动解锁。
2. 解锁后，用最终版本重新构建并安装：
   - `pubspec_overrides.yaml` 已指向集成 worktree。先在集成 worktree 里确认 `git log -1` 是最新提交。
   - 运行 `tool/build_studio_hap.sh`，再 `tool/device_ui.sh install`。
3. 按 CHECKLIST 的 J 节，11 步逐步执行。每一步截图，放到 `TASK\check\screens\device\`。文件名以步骤号开头。
   - 第 4、5 步需要登录态。设备上已有登录就继续。没有登录，写进「未验证」，不要用任何账号密码。
   - AI 服务可能没配置或不可达。发送后出现错误文案也算通过，截图记录文案。
4. 用 `device_ui.sh log` 读 hilog 里的 `[agent-perf]` 行。记录 `session.open`、`send.feedback`、`sessions.load` 的毫秒数。
5. 完成后不要删除 `pubspec_overrides.yaml`，也不要改 studio 的任何已有文件。不要在 studio 仓库提交任何东西。大脑会恢复现场。
6. 30 分钟后设备还锁着：任务 1 照常完成并写进 status。任务 2 写 `BLOCKED 设备仍在锁屏`。

## 报告

在 status 的「已完成」里，对 J 节每一步写：通过、不通过或未验证，加截图文件名。
