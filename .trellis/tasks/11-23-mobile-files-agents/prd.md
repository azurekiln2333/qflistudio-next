# 移动端文件互通与 Agents 首页

## 目标

手机上的文件要能一步交给 agent。agent 要能像在电脑上一样读写本机文件。电脑上 harness 的改动要能回到手机。首页要能一眼看到所有端的会话。

## 背景

- 微信里的 PDF、md 只能"用其他应用打开"。QFLI 现在不在这个列表里：Android 清单没有 `ACTION_SEND`，iOS 没有 Share Extension，鸿蒙 `module.json5` 只有 home 和 interop 两个 action。
- iOS 端没有文件夹书签代码。Android 端已有目录授权（`QfliPickerPlugin.java` 的 `ACTION_OPEN_DOCUMENT_TREE` 与 `takePersistableUriPermission`）。
- Mac 版开了沙盒，但没有"用户选择的文件"权限。
- CI 出的 iOS 包不签名，用户自己重签。自建 iCloud 容器走不通。
- 已绑定电脑的通道（`lib/harness/remote/`）只传会话和终端，不传文件。
- Studio 会话落盘在应用数据目录 `agent_sessions/`。Herdr 与已绑定电脑的会话不落盘。
- 会话状态有 6 种：`working`、`idle`、`done`、`blocked`、`exited`、`unknown`。会话模型有工作目录，没有设备名和系统信息。

## 需求清单与子任务

| 编号 | 需求 | 子任务 |
|---|---|---|
| 1 | Android、iOS、鸿蒙注册为分享目标 | `11-23-share-target` |
| 2 | 收到文件后让用户选：放进项目，或附到 agent 会话 | `11-23-share-target` |
| 3 | iOS 文件夹授权与书签 | `11-23-external-folders` |
| 4 | Mac 沙盒补"用户选择的文件"权限与书签 | `11-23-external-folders` |
| 5 | 写入前走系统文件协调 | `11-23-external-folders` |
| 6 | iCloud 未下载的占位文件，读之前先触发下载 | `11-23-external-folders` |
| 7 | git 项目用 qfli_git 拉取，核实浅克隆支持 | `11-23-device-sync` |
| 8 | 非 git 项目走已绑定电脑通道按需同步 | `11-23-device-sync` |
| 9 | 首页 Agents 标签：列出所有端的会话，点一下直达编辑器 Agent 面板 | `11-23-home-agents-tab` |
| 10 | 状态圆点，等待处理的排最前，标注是哪一端 | `11-23-home-agents-tab` |
| 11 | 详情页：设备名、系统、会话路径 | `11-23-home-agents-tab`（电脑端上报部分可放进 `11-23-device-sync`） |
| 12 | 会话无本地项目时建占位项目，拉会话流，项目文件由用户决定是否拉取 | `11-23-device-sync`（依赖第 8 项） |

## 约束

- Agents 功能留在原 `EditorPage`。首页 → 项目 → 编辑器的原路径不变。Agents 标签只是索引，不放输入框和对话视图。
- 同步少占服务器。中继只转发，不存文件。
- 手机不能无限写入：只在用户触发时拉取，只传变化的文件，删除也同步，不留旧版本，缓存有上限。
- 原有测试不改也要通过。
- 测试只在云端 CI 跑，不在本机跑。

## 暂不做

- QFLI 自建 iCloud 容器。
- agent 替用户点别的应用界面。

## 跨子任务验收标准

- [ ] 在微信里点"用其他应用打开"，Android、iOS、鸿蒙的列表里都出现 QFLI。选中后文件能放进项目，或附到会话。
- [ ] iOS 上能选中"我的 iPhone/Obsidian"文件夹。重启 QFLI 后仍能读写，不用重新选。
- [ ] 首页有 Agents 标签。点会话后，首帧就停在编辑器的 Agent 面板，并选中这个会话。
- [ ] 电脑上改了非 git 项目，手机点"同步"后只拉变化的文件。电脑上删掉的文件，手机上也删掉。
- [ ] 会话在本机没有对应项目时，能看到会话流。项目文件要用户确认后才下载。
- [x] core-check 与 App installers 在 `main` 上全绿。
