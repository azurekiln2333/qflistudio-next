# 执行计划（Pi C）

工作目录：`D:\MyNewProjects\_wt\ui-c`。分支：`ui/pi-c`。netrix：`D:\MyOtherNewProj\netrix`（只读）。

1. [ ] 读父任务的 `pi-rules.md`、`prd.md`、`design.md`。读本目录的 `prd.md`、`design.md`。
2. [ ] 读 `implement.jsonl` 列出的规范文件。
3. [ ] 两个 worktree 各运行 `flutter pub get`。
4. [ ] 读本项目的现有工具页。读 netrix 的工具页框架。填写 `design.md` 的「Pi 补充」。
5. [ ] 写 `research/tools-port-contract.md`（位置在父任务目录）。
6. [ ] 实现骨架并提交。`flutter analyze` 通过。把提交哈希写进契约。**这一步完成后 D 和 B 才能开始移植。**
7. [ ] 实现工具页框架：紧密显示、宽松显示、切换、持久化、netrix 工具页的其他界面元素。补测试。提交。
8. [ ] 实现可见范围过滤。补两个测试（主程序、非主程序）。提交。
9. [ ] 等 `research/netrix-tools-inventory.md` 出现。写 `research/tools-duplicates.md`。合并重复工具。提交。
10. [ ] 移植第 1 批的每个工具。每个工具一个提交。
11. [ ] 运行 `flutter analyze`、`flutter test`。修到全部通过。
12. [ ] 自查：`git diff --stat <基线>..HEAD` 不含 `dirty-files.txt` 的路径。
13. [ ] 写 `research/pi-c-report.md`。

基线：主程序 `d26cffc`，内核 `573d1b6`。

第 9 步时清单还没出现：先完成第 7、8 步的报告并结束本轮。大脑会再次派发。
