# pi-D 第四轮：最终截图与真机全流程

## 已完成

任务 1：`check\screens\final\` 共 48 张。8 个场景 × 3 尺寸 × 2 主题，scale 2，`All tests passed!`。
场景：empty、running、failed-503、failed-offline、long、sessions、drawer、switch-session。

四项修复的图与位置：

1. 「每次询问」：`long-1280x800-light.png`，右栏（正好 400 宽）输入卡片工具行第二项，盾牌图标后。`long-1280x800-dark.png` 同位置。
2. 「搜索文本」：`long-1280x800-light.png`，右栏对话流第三个工具条目标题，副行「搜索 GridView、Warp 的用法」，右侧「完成」。`long-390x844-light.png`、`long-1280x800-dark.png` 同位置。
3. 「等待你确认写入」：`long-1280x800-light.png`，右栏分段控件下方的状态行，⚡ 图标后；同图下方是「需要确认写入」卡片。dark 与 390 同位置一致。
4. 切换会话：`switch-session-900x700-light.png`，底部输入卡片工具行显示「DeepSeek V4.1 Pro」和「high」。390x844 下模型名为「DeepSe…」、强度折叠成图标（窄宽折叠，非缺陷）。

任务 2：已装最终版 HAP，J1-J6 逐步截图（`check\screens\device\`）。

- J1 通过：`01-cold-start.png`（主页、项目列表）。
- J2 通过：`02-open-project.png` → `02b-open-project-editor.png`（编辑器页）→ 一次返回 `03b-back-home.png`（主页，含「返回编辑器」入口）。`02c` 是系统桌面，误触，非证据。
- J3 通过：`04c-drawer.png`（侧边栏「文件 | 会话」）。
- J4 通过：`06-agent-panel.png`（Agent 面板空态、输入卡片可用、无登录引导，即设备已登录）。
- J5 通过：`08-send-immediate.png`（同帧清空输入、用户气泡、发送键变停止键、顶部进度条、「思考中」）、`09-send-2s.png`（「已等待 4 秒」）、`10-send-later.png`（「网络不可用，检查网络后重试」+「重试」）。
- J6 通过：`06`、`08`、`10-send-later.png` 底部模型芯片常驻，列表为空时显示「默认模型」。

F6 耗时：本轮早先 `device_ui.sh log` 抓到 `sessions.load` 321 / 23 ms、`session.open` 36 / 30 ms、`send.feedback` 2 ms、`persist.append` 44 ms。缓冲区已轮转，未能复读。

## 进行中

- J7 收尾：缺「会话 2 运行中切回会话 1、原会话继续」的截图。
- 干净新会话的单点发送气泡计数，等解锁后补。

## 请求

- 设备 12:16 起回到锁屏，`launch` 报 `10106102`，J8-J11 无法继续。请解锁后派人续跑。
- 重复用户气泡（未定性）：`13d-retry-send.png` 单击一次发送只有 1 个气泡；`14b-list.png` 同一会话出现 2 个相同用户气泡，夹 1 张错误卡。代码路径 `workbench_agent_pane.dart:351` 的 `_send` 先插回声，失败时 `_rollback` 把文本写回草稿并撤回声；若失败后按钮被再点一次，会再发一次，形成 2 条。请复测时单点一次并 dump 布局数气泡。
- E2 疑点：`14b-list.png` 会话列表里「加一个求和函数」标「已完成」，实际当轮是网络失败；同列表「第二个会话，补一个素数判断」标「失败」。状态标记口径请 owner 复核。

## 未验证

- 任务 2 从 J8 起因锁屏阻塞。J8 未验证。
- J9 未验证（无冷启动后打开已有会话的专项记录，只有上面的 F6 数字）。
- J10 未验证（真机浅色 / 深色、横屏 / 竖屏都没过）。
- J11 未验证：未主动断网。网络错误文案与「重试」已在 `10-send-later.png`、`13c` 出现，属现象等价。
- 本轮未跑 `flutter analyze` 与全量测试；只跑了场景工具。按 CHECKLIST 口径，无证据项算不通过。
- 未在 studio 仓库提交任何东西，未改已有文件，未删 `pubspec_overrides.yaml`。
