# 接收别的应用分享的文件

本文是 `11-23-mobile-files-agents` 的子任务 PRD，覆盖父任务需求 1 与需求 2。设计见 `design.md`，执行见 `implement.md`。

## 目标

用户从别的应用分享文件时，QFLI 出现在系统目标列表里。选中后用户选一个去向：放进项目，或附到 agent 会话。Android、iOS、鸿蒙三端行为一致。

## 背景

- 微信里的 PDF 与 md 现在只能「用其他应用打开」。QFLI 不在这个列表里。
- Android 清单只有 LAUNCHER 一个 intent-filter。没有 SEND，也没有 SEND_MULTIPLE。
- iOS 的 `Info.plist` 没有 `CFBundleDocumentTypes`。`LSSupportsOpeningDocumentsInPlace` 与 `UIFileSharingEnabled` 已经为真。
- 鸿蒙 `module.json5` 的 `EntryAbility` 只有 `action.system.home` 一条 skill。
- 编辑器已有 Agent 面板。附件走 `attachedPaths`，路径必须是项目内相对路径。
- 会话落在应用数据目录的 `agent_sessions/` 下，元数据带 `projectId`。
- 应用已有 `PickerService` 与 `ShareService`，都挂在 `qflistudio/platform` 通道。

## 需求

### 需求 1 三端注册为分享目标

| 编号 | 需求 |
|---|---|
| R1.1 | Android 注册 `ACTION_SEND`，单个文件可从微信「用其他应用打开」进入 QFLI |
| R1.2 | Android 注册 `ACTION_SEND_MULTIPLE`，一次多个文件进入同一批 |
| R1.3 | Android 注册 `ACTION_VIEW`，点开文件时 QFLI 出现在打开方式里 |
| R1.4 | iOS 注册文档类型，文件应用与微信的「用其他应用打开」列表出现 QFLI |
| R1.5 | iOS 处理外部打开 URL，冷启动与热启动都能拿到文件 |
| R1.6 | 鸿蒙 `module.json5` 增加 `sendData` 与 `viewData` 两条 skill |
| R1.7 | 鸿蒙 `EntryAbility` 在 `onCreate` 与 `onNewWant` 收下文件 |

### 需求 2 收到文件后让用户选去向

| 编号 | 需求 |
|---|---|
| R2.1 | 文件到达后弹出选择面板，给出「放进项目」「附到 Agent 会话」「取消」三个选项 |
| R2.2 | 放进项目时先选项目，再选子目录，默认 `inbox` |
| R2.3 | 放进项目时重名自动改名，不覆盖已有文件 |
| R2.4 | 附到会话时先选项目，再选会话或新建会话 |
| R2.5 | 附到会话后打开编辑器，首帧停在 Agent 面板并选中该会话 |
| R2.6 | 附件进入输入卡片，不自动发送 |
| R2.7 | 取消后本批文件留在收件箱，7 天内可再次处理 |
| R2.8 | 冷启动：进程未启动时分享，首屏就绪后弹面板 |
| R2.9 | 热启动：进程在前台或后台时分享，当前界面直接弹面板 |
| R2.10 | 多文件：整批进同一个面板，逐项显示文件名与大小 |
| R2.11 | 大文件：复制走流式，内存峰值不随文件大小增长 |
| R2.12 | 收件箱有上限，超期与超额批次自动清理 |

## 约束

- 中继不存文件。本次改动不引入服务端接口。
- 收件箱只写应用数据目录。不写共享存储，不申请新的存储权限。
- 单文件上限 2 GiB。单批上限 16 个文件。收件箱常驻上限 512 MiB。
- 收件箱保留 7 天。成功处理后立刻删除该批次。
- 三端共用 Dart 侧的收件箱、选择面板与落盘逻辑。
- 原有测试不改也要通过。
- 测试只在云端 CI 跑，本机不跑。
- 不加 iOS App Group。CI 出的 iOS 包不签名，用户自己重签。
- 不碰插件注册文件。

## 验收标准

### 三端目标列表

- [ ] A1 Android 微信「用其他应用打开」列表出现 QFLI，选中后进入 QFLI
- [ ] A2 Android 一次选三个文件，三个文件进同一批
- [ ] A3 Android 从文件管理器点开 .md，QFLI 出现在打开方式里
- [ ] A4 iOS 文件应用「用其他应用打开」列表出现 QFLI
- [ ] A5 iOS 微信分享 PDF 到 QFLI，文件进收件箱
- [ ] A6 鸿蒙系统分享面板出现 QFLI，`sendData` 生效
- [ ] A7 鸿蒙文件管理器点开文件，QFLI 出现在打开方式里

### 去处与生命周期

- [ ] A8 冷启动：QFLI 未运行时分享，首屏就绪后自动弹选择面板
- [ ] A9 热启动：QFLI 在前台时分享，当前界面直接弹面板
- [ ] A10 放进项目后文件出现在项目文件树，可打开编辑
- [ ] A11 同名文件放进项目后变成 `name (1).ext`，原文件不变
- [ ] A12 附到会话后编辑器首帧停在 Agent 面板，会话已选中
- [ ] A13 输入卡片带附件，正文为空，未自动发送
- [ ] A14 取消后 7 天内再分享一次，旧批次仍在收件箱
- [ ] A15 1 GiB 文件可复制进项目，进程内存峰值明显低于文件大小
- [ ] A16 启动时清掉超过 7 天的批次
- [ ] A17 收件箱总占用超过 512 MiB 时先删最旧的批次

### 回归

- [x] A18 `core-check` 在 `main` 全绿
- [x] A19 App installers 在 `main` 全绿
- [ ] A20 原有测试文件一处不改也通过

## 暂不做

- iOS Share Extension。
- iCloud 容器。
- 纯文本分享（`ACTION_SEND` 的 `text/plain` 正文）。
- 从分享面板直接新建项目。
- agent 替用户点别的应用界面。
