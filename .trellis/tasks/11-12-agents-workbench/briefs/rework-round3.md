# 第三轮：修复交叉检查发现的问题

先读 `RULES-rework.md`。状态文件换成 `TASK\status\pi-X-rework-3.md`（X 是你的字母）。四节，不超过 60 行。最后一条回复：`DONE <该路径>` 或 `BLOCKED <原因>`。

## 第一步（所有人）

在你自己的实现 worktree 里（不是检查 worktree）运行：

```
git merge --ff-only rework/integration
```

这是唯一允许的 merge。它把别人的改动带进你的分支。worktree 必须是干净的。失败就停下，写进 status。

之后在这个基础上修复，分多次提交。

## pi-A

1. 宽屏右栏加宽。`Breakpoints.agentPaneWidth` 从 360 改为 400。原因：360 宽时输入卡片的权限和推理强度只剩图标。
2. 检查 1100 宽时编辑器列仍可用，没有溢出。侧边栏展开时也检查。
3. 更新受影响的测试和常量引用。旧测试不改。
4. 补一个测试：1100 宽、侧边栏展开，无溢出。

## pi-B

1. E4：租约的路径键必须在大小写不敏感的平台上折叠大小写。Windows、macOS、iOS 折叠。`a.txt` 与 `A.TXT` 是同一个租约。同时统一 `\` 与 `/`，去掉 `./`。位置：`lib/vibe_coding/project_write_leases.dart` 的 `_keyOf`。
2. 加测试：`a.txt` 对 `A.TXT`，`sub\a.txt` 对 `sub/a.txt`。大小写折叠用可注入的开关，让 Linux 上也能测。
3. G5：`vibeToolLabel`（`lib/vibe_coding/vibe_coding_widgets.dart`）没有 `search_text` 的映射，对话流把工具名原样显示。加 `'search_text' => '搜索文本'`。
4. 加测试：`vibe_tools.dart` 里注册的每个工具名，都有中文标签，不等于工具名本身。

## pi-C

1. D1、D2（最重要）：切换会话后，模型名和推理强度丢失。原因：每个会话新建 `ComposerState`，`modelId` 为空。`ComposerCard.didUpdateWidget` 只在 `models` 变化时同步默认选择，`state` 变化时不同步。
   - 修：新建 `ComposerState` 时，从项目的记忆值或模型列表第一项初始化 `modelId` 和 `reasoningEffort`。`state` 对象变化时也同步。
   - 加测试：在会话 A 选好模型和推理强度，切到会话 B，模型名和推理强度仍显示。
2. G4：`lib/chat/attachment_picker.dart:233` 的 `agent` 改为 `Agent`。全仓用户可见文案再 `grep` 一遍小写 `agent`。
3. G7：文件选择器的空状态加一个主操作按钮「关闭」。
4. C3：`awaitingApproval` 时状态行写「等待你确认写入」，不要写「思考中…」。加测试。

## pi-D

1. D4-1：`tool/device_ui.sh log` 静默失效。原因是 `timeout` 调用了 shell 函数。改成能工作的写法，并实测输出 hilog。
2. D4-2：`--help` 输出多了一行脚本内容 `set -euo pipefail`。修 `sed` 范围。`build_studio_hap.sh` 同样检查。
3. 提前验证 OHOS 构建：
   - 在 studio 主目录建未跟踪的 `pubspec_overrides.yaml`，把 `qfli_studio_core` 指向集成 worktree `D:\MyNewProjects\_wt\integration\qfli_studio_core`。`re_editor` 的 path 依赖也要覆盖。它已在 `.git/info/exclude`，用 `git check-ignore -v` 确认。
   - 用 `tool/build_studio_hap.sh` 构建并装机。目的是尽早发现编译错误。这一步不用等其他人的修复。
   - 构建完成后，保留 override 文件，不要删。写进 status。
   - 不要改 studio 已有的任何文件。
4. 补截图：900 宽和 1280 宽的 `running`、`long`、`failed-503`、`failed-offline` 场景，现在是点不到会话行。改成直接给 `WorkbenchState` 初始会话 id，或者其他不依赖点击的办法。输出到 `check\screens\integration\`，覆盖旧文件。
5. 设备在锁屏。你不能解锁它，大脑会通知用户。不要反复尝试自动解锁。
