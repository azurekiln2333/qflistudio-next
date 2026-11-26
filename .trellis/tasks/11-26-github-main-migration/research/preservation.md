# 迁移保全报告

## 结论

已从 private hold 核对并恢复 104 个 allowlist 文件。恢复前，104 个原始 SHA-256 全部匹配。原始本机文件保留在 hold。

最新观察 HEAD：`c5f4bc3afe9c81ba488fd3f544d43c3dac061512`。本次只读观察没有执行 Git 修改。

## 恢复结果

目标目录：`research/preserved-terminal-task/`。

| 类别 | 数量 | 处理 |
| --- | ---: | --- |
| Dart | 36 | 原始字节 |
| patch | 3 | 原始字节 |
| YAML | 1 | 原始字节 |
| Markdown | 34 | 只替换本机路径 |
| 其他 JSON | 8 | 结构化摘要或路径替换 |
| process JSON | 22 | 最小脱敏进度摘要 |

原始目录实际有 22 个 `process-handle-report.json`。此前记录的 18 个是计数错误。本次全部 22 个都生成最小摘要。

## 源码保护

36 个 Dart、3 个 patch 和 1 个 YAML 文件逐字节复制。脚本没有对这些文件执行正则替换。源码字段没有改动。

## 脱敏规则

- Markdown 只替换个人本机路径。
- 非源码证据 JSON 只替换本机路径，或输出不含运行时转储的结构化摘要。
- 22 个 process JSON 只保留状态、套件、结果码、完成时间和数量。
- 摘要移除命令、工作目录、进程标识、标准输出、标准错误、会话数据和原始日志。
- 不发布 raw transcript、日志、generated bundle 或 staging 子目录。
- 不发布 `backup_root`。

## staging 根目录

已审查 staging 根目录 5 个文件。报告只保存文件名、大小、哈希和风险分类。没有复制 staging 内容。

## 校验文件

- `preserved-terminal-task/README.md`：恢复规则。
- `preserved-terminal-task/hash-manifest.json`：104 个文件的原始与发布哈希。
- `preserved-terminal-task/staging-root-review.json`：staging 根目录 5 个文件的元数据。

原始文件仍保留在本机 private hold。未删除或覆盖原件。

## 操作边界

本次只编辑本报告、机器清单、README 和恢复证据。没有执行 Git 暂存、提交、合并或推送。没有运行构建、测试或安装。
