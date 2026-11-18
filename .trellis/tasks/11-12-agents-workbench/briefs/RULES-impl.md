# 实现阶段通用规则

1. 先读任务目录下的 `prd.md`、`design.md`、`implement.md`。只做 `implement.md` 中分给你的工作流。
2. 只改 `implement.md` 中你的独占范围。别人范围内的问题写进你的 status 文件的「请求」节。
3. 两个仓库都有用户未提交的改动。基线清单在 `research/baseline-studio.txt` 和 `research/baseline-core.txt`。
4. 禁止执行：`git reset`、`git checkout --`、`git restore`、`git stash`、`git clean`、`git rebase`、`git push --force`、`git commit --amend`。
5. 只有 pi-D 可以执行 `git commit`、`git merge`、`git push`、`git tag`，并且只在 `implement.md` 写明的步骤中执行。
6. 不开子代理。
7. 密钥、令牌、密码不得写进任何受版本控制的文件、提交信息、status 文件、检查文件。
8. 提交信息用 Conventional Commits，英文，不带任何 AI 署名行（没有 Co-Authored-By，没有 Generated with）。
9. 动手前先读 `.trellis/spec/frontend/index.md` 中和你的范围对应的规范。
10. 4 个 Pi 同时改同一个工作目录。analyze 报出别人文件里的错误时，不要修，写进「请求」节。
11. 每完成 `implement.md` 中的一步，更新 `.trellis/tasks/11-12-agents-workbench/status/pi-X.md`。文件包含四节：已完成、进行中、请求、未验证。全文不超过 60 行。
12. 新增逻辑必须有测试。你范围内的 `flutter analyze` 和测试必须通过后才能报告完成。
13. 没有验证的内容写进「未验证」节。不得把没有运行过的检查报告为通过。
14. 完成后，最后一条回复只写一行：`DONE <你的 status 文件路径>`。受阻时只写一行：`BLOCKED <原因>`。
