# Preserved terminal task evidence

本目录保存迁移审查选出的 104 个源代码和进度文件。

## 来源

- 原始目录：`.trellis/tasks/10-23-studio-release-ux-workspaces/.artifacts/`。
- 原始文件保持在本机私有 hold。
- 本目录不包含绝对 `backup_root`。
- `hash-manifest.json` 记录每个文件的原始哈希、发布哈希、字节数和变换。

## 字节规则

- 36 个 Dart 文件使用原始字节。
- 3 个 patch 文件使用原始字节。
- 1 个 YAML 文件使用原始字节。
- 这些 40 个文件没有宽正则替换，也没有修改源码字段。

## JSON 规则

原始目录实际包含 22 个 `process-handle-report.json`，不是 18 个。22 个文件全部生成最小进度摘要。摘要只保留状态、套件、结果码、完成时间和数量。摘要移除命令、工作目录、进程标识、标准输出、标准错误、会话和原始日志。

其余证据 JSON 只做结构化摘要或本机路径替换。报告不保存原始运行时转储。

## Markdown 规则

Markdown 只替换本机路径。其他内容保持原文。

## staging

staging 根目录的 5 个文件只写入元数据证据。staging 子目录、生成 bundle、日志和原始会话不复制。

## 恢复核验

恢复前，104 个原始文件全部通过原始 SHA-256 核验。请查看 `hash-manifest.json`。本目录不授权 Git 暂存、提交、合并、推送、构建或测试。
