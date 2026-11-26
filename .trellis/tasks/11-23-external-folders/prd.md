# 打开外部文件夹

## 目标

iOS 与 Mac 把系统文件夹选作项目根。重启后仍能读写。写入不损坏文件。

## 背景

- iOS 端没有文件夹书签代码。
- Mac 版开了沙盒。它缺"用户选择的文件"权限。
- Android 已有目录授权。它用 `ACTION_OPEN_DOCUMENT_TREE` 与持久化授权。
- 用户常用 Obsidian 打开同一个库。两个应用同时写会写坏文件。
- iCloud 里的文件可能只有占位。占位没有正文字节。

## 需求

### R1 iOS 文件夹选择

用系统文件夹选择器选目录。QFLI 保存安全作用域书签。

### R2 书签续期

启动时解析书签。书签过期就续期。用户不重新选择。

### R3 Mac 沙盒权限

补 `com.apple.security.files.user-selected.read-write`。

补 `com.apple.security.files.bookmarks.app-scope`。

Mac 走与 iOS 相同的书签流程。

### R4 协调写入

写文件走 `NSFileCoordinator`。

QFLI 保存时不得写坏 Obsidian 同一时刻的写入。

### R5 占位下载

读文件前先触发 iCloud 下载。下载完成后再读正文。

### R6 项目根

外部文件夹可充当项目根。

文件树列出目录。编辑器打开、编辑、保存文件。agent 文件工具读写与列目录。

## 约束

- 只做 iOS 与 Mac。Android 的 SAF 目录当项目根不在本任务。
- 把 Android 的 Dart 接口形状当参照。通道名与返回结构沿用。
- 不复制外部文件夹到应用沙箱。
- 不删除用户文件。
- 原有测试不改也要通过。
- 测试只在云端 CI 跑。本机不跑测试。

## 验收标准

- [ ] iOS 选中"我的 iPhone/Obsidian"后，文件树能列出目录。
- [ ] 重启 QFLI 后，同一个文件夹仍能读写，用户不用重选。
- [ ] 书签过期时 QFLI 自动续期，不弹选择器。
- [ ] Mac 沙盒包选中外部文件夹，重启后仍能读写。
- [ ] Obsidian 同时打开同一文件时，QFLI 保存后文件内容完整。
- [ ] 打开 iCloud 未下载文件时先下载，再显示正文。
- [ ] 外部文件夹作为项目根时，编辑器的打开、编辑、保存都可用。
- [ ] agent 的 `read_file`、`write_file`、`list_dir` 在外部项目根内可用。
- [x] core-check 与 App installers 在 `main` 上全绿。
