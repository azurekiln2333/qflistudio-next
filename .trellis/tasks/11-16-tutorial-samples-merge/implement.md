# 执行计划（Pi B）

工作目录：`D:\MyNewProjects\_wt\ui-b`。分支：`ui/pi-b`。

## 第一部分：合并

1. [ ] 读父任务的 `pi-rules.md`、`prd.md`、`design.md`。读本目录的 `prd.md`、`design.md`。
2. [ ] 读 `implement.jsonl` 列出的规范文件。
3. [ ] 两个 worktree 各运行 `flutter pub get`。
4. [ ] 定位两个页面和全部入口。填写 `design.md` 的「Pi 补充」。
5. [ ] 实现合并页。语言栏单行横向滚动。补测试。提交。
6. [ ] 处理原示例代码页的入口。补测试。提交。
7. [ ] 运行 `flutter analyze`、`flutter test`。修到全部通过。
8. [ ] 写 `research/pi-b-report.md` 的第一部分（位置在父任务目录）。

## 第二部分：第 3 批工具

9. [ ] 等 `research/netrix-tools-inventory.md` 和 `research/tools-port-contract.md` 出现。两者都出现后再开始。
10. [ ] `git merge` 契约里写的骨架提交。
11. [ ] 按清单移植第 3 批的每个工具。每个工具一个提交。
12. [ ] 运行 `flutter analyze`、`flutter test`。修到全部通过。
13. [ ] 自查：`git diff --stat <基线>..HEAD` 不含 `dirty-files.txt` 的路径。
14. [ ] 把第二部分补进报告。

基线：主程序 `d26cffc`，内核 `573d1b6`。

第一部分完成时两个文件还没出现：先结束本轮并在报告里写明。大脑会再次派发第二部分。
