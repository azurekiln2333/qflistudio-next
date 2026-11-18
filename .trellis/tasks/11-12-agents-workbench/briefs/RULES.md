# 通用规则（每个 brief 都适用）

1. 忽略此前会话中的旧任务。只做本次 brief 的事。
2. 先读 `.trellis/tasks/11-12-agents-workbench/prd.md`。
3. 工作区有用户未提交的改动。禁止执行：`git reset`、`git checkout --`、`git restore`、`git stash`、`git clean`、`git rebase`、`git commit`、`git push`、改 remote。
4. 调研阶段只允许写 brief 指定的输出文件。不改其他任何文件。
5. 不开子代理。
6. 输出文件开头写「结论」节，不超过 30 行。先写能或不能，再写证据（`路径:行号` 或 URL）。全文不超过 150 行。
7. 没有验证的内容标注「未验证」。不猜。
8. 不输出任何密钥、令牌、密码的内容。只报告它们的位置。
9. 完成后，最后一条回复只写一行：`DONE <输出文件路径>`。
