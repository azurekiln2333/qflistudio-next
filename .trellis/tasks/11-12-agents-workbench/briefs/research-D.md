# Brief D：跨仓库 CI/CD 与 APK release

先读同目录 `RULES.md`。

输出文件：`.trellis/tasks/11-12-agents-workbench/research/D-cicd.md`

## 调查内容

只运行只读命令。

1. 确认 studio 和 core 两个仓库的本地路径、`git remote -v`、托管平台、默认分支、未推送的提交数量。studio 可能没有配置 remote，请核实。
2. 确认 studio 依赖 core 的方式：path 依赖、git 依赖、submodule、构建产物。给出配置位置。
3. 列出两个仓库现有的 CI 文件。
4. 确认 Android 构建方式：Flutter 版本、构建命令、签名配置的位置、keystore 是否在仓库内、版本号来源。
5. 确认本机的托管平台 CLI 是否可用并已登录（例如 `gh auth status`）。
6. 比较至少三种跨仓库云构建方案：CI 中用令牌 checkout 两个仓库、git 依赖、submodule。推荐一种，并说明理由。
7. 列出用户必须提供的 secrets 和一次性手工操作。
8. 在输出文件中给出 workflow 草案：PR 检查（analyze + test），以及 tag 触发的构建、签名、发布 APK release。本阶段不创建 `.github` 下的文件。
9. 结论节必须回答：现在能否直接推送并发布 APK，缺什么。
