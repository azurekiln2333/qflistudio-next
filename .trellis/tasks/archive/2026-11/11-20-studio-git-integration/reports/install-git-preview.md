# Studio Git 预览安装

版本：`v5.0.5-git.2`。
发布结果：18 项云端任务全部通过。

发布页：
https://github.com/azurekiln2333/qflistudio-next/releases/tag/v5.0.5-git.2

## Windows x64

下载文件：`qflistudio-5.0.5-windows-x64.zip`。

1. 解压下载的 ZIP。
2. 运行 `QFLIStudioN-5.0.5-windows-x64-setup.exe`。
3. 打开一个本地项目。
4. 点击编辑器工具栏的 `Git`。

桌面 Git 使用已安装的 Git 命令行。
克隆入口位于主页更多菜单。
菜单名称为“克隆 Git 仓库”。

## Android ARM64

下载文件：`qflistudio-5.0.5-android-arm64-v8a.zip`。
解压后安装 APK。
云构建使用临时调试证书。
旧安装可能出现签名冲突。
先备份项目。
出现冲突后再卸载旧安装。

## 其他平台

发布页包含全部 11 个安装目标。
iOS 和 OHOS 包需要签名后安装。
Windows 伴侣位于独立 ZIP。
解压后运行 `Start-QFLI-Remote.cmd`。

## 已验证范围

Core 通过 2394 项测试。
26 项原有测试跳过。
iOS 模拟器已通过原生 Git 流程。
该流程覆盖克隆、分支和冲突合并。
该流程也覆盖合并提交和推送。
13 个发布附件已上传。
12 个 ZIP 的 SHA256 均与清单一致。
Windows 发布包的源码提交已核对。
移动包的原生库和 CA 已核对。
本机未运行测试或构建。
真机效果由用户安装后确认。
