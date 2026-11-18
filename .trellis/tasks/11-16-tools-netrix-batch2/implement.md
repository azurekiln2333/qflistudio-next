# 执行计划（Pi D）

工作目录：`D:\MyNewProjects\_wt\ui-d`。分支：`ui/pi-d`。netrix：`D:\MyOtherNewProj\netrix`（只读）。

1. [ ] 读父任务的 `pi-rules.md`、`prd.md`、`design.md`。读本目录的 `prd.md`、`design.md`。
2. [ ] 读 `implement.jsonl` 列出的规范文件。
3. [ ] 通读 netrix 的工具页和工具注册位置。同时列出本项目现有工具。
4. [ ] 写 `research/netrix-tools-inventory.md`（位置在父任务目录）。核对总数。**这一步完成后 C 和 B 才能开始移植。**
5. [ ] 两个 worktree 各运行 `flutter pub get`。
6. [ ] 通读第 2 批工具的 netrix 源码。填写 `design.md` 的「Pi 补充」。
7. [ ] 等 `research/tools-port-contract.md` 出现并且含骨架提交哈希。
8. [ ] `git merge` 骨架提交。
9. [ ] 按契约移植第 2 批的每个工具。每个工具一个提交。
10. [ ] 运行 `flutter analyze`、`flutter test`。修到全部通过。
11. [ ] 自查：`git diff --stat <基线>..HEAD` 不含 `dirty-files.txt` 的路径。
12. [ ] 写 `research/pi-d-report.md`。

基线：主程序 `d26cffc`，内核 `573d1b6`。

第 7 步时契约还没出现：每隔几分钟检查一次，最多等 20 分钟。仍未出现时结束本轮并在报告里写明。大脑会再次派发。
