# Pi 通用规则（四个 Pi 都必须遵守）

任务目录（黑板）：`D:\MyNewProjects\qflistudio\.trellis\tasks\11-16-home-tutorial-tools-ui\`

## 1. 工作位置

| Pi | herdr pane | 工作目录 | 分支（两个仓库同名） | 子任务 |
|---|---|---|---|---|
| A | w37:pC | `D:\MyNewProjects\_wt\ui-a` | `ui/pi-a` | 11-16-home-fab-tabs-search |
| B | w37:pH | `D:\MyNewProjects\_wt\ui-b` | `ui/pi-b` | 11-16-tutorial-samples-merge |
| C | w37:pG | `D:\MyNewProjects\_wt\ui-c` | `ui/pi-c` | 11-16-tools-netrix-framework |
| D | w37:pJ | `D:\MyNewProjects\_wt\ui-d` | `ui/pi-d` | 11-16-tools-netrix-batch2 |

- 每个工作目录下有两个 git worktree：`qflistudio`（主程序）和 `qfli_studio_core`（内核）。
- 主程序通过 `../qfli_studio_core` 依赖内核。两个 worktree 已经配对。
- 基线：主程序 `d26cffc`，内核 `573d1b6`。
- 你只在自己的工作目录里改代码。先自己定位代码在哪个仓库。

## 2. 禁止事项

- 禁止修改主工作树 `D:\MyNewProjects\qflistudio` 和 `D:\MyNewProjects\qfli_studio_core` 里的代码。那里有用户未提交的工作。
- 禁止修改别的 Pi 的工作目录。禁止修改 `D:\MyNewProjects\_wt\` 下名字不以 `ui-` 开头的目录。
- 禁止修改 `D:\MyOtherNewProj\netrix`。它只读。
- 禁止运行 `git reset`、`git checkout --`、`git restore`、`git stash`、`git clean`、`git rebase`、`git push`、`git tag`。
- 禁止切换分支。禁止改写历史。禁止 `git commit --amend` 已经报告过的提交。
- 禁止修改或新建 `research/dirty-files.txt` 列出的路径。必须修改时，先停下，把原因写进报告。
- 禁止删除旧测试。禁止放宽旧测试的断言。
- 禁止启动子 agent 去改代码以外的仓库。

## 3. 允许事项

- 允许在自己的 worktree 里 `git add <明确路径>`、`git commit`、`git merge <别的 ui/ 分支或提交>`。
- 允许在黑板目录的 `research/` 和 `screens/` 下写文件。
- 允许读任何目录。

## 4. 提交

- 使用 Conventional Commits。例：`feat(home): create cloud projects from the FAB`。
- 提交信息用英文。
- 提交信息不得包含 `Co-Authored-By`、`Generated with` 或任何 AI 署名。
- 用明确路径 `git add`。不用 `git add -A` 和 `git add .`。
- 每个逻辑改动一个提交。两个仓库分别提交。

## 5. 流程

1. 读黑板的 `prd.md`、`design.md`、`implement.md`、本文件。
2. 读自己子任务目录的 `prd.md`、`design.md`、`implement.md`。
3. 读子任务 `implement.jsonl` 列出的规范文件。
4. 在自己的两个 worktree 里各运行一次 `flutter pub get`。
5. 改代码之前，把代码级设计补进子任务的 `design.md`（「Pi 补充」一节）。
6. 实现。补测试。
7. 在改动过的仓库里运行 `flutter analyze` 和 `flutter test`。两者都必须通过。
8. 提交。
9. 写报告 `research/pi-<a|b|c|d>-report.md`。

## 6. 报告内容

- 每个仓库的提交列表（哈希和标题）。
- 改动文件列表。
- `flutter analyze` 和 `flutter test` 的最后几行输出。
- 每条验收标准的状态和证据。
- 你对需求的解释与 `prd.md` 的「大脑的解释」不一致的地方。
- 未完成项和风险。不得把未完成写成完成。

## 7. 卡住时

- 需求不清或与代码冲突：选最接近用户原话的做法，继续做，把决定写进报告。
- 需要修改禁止路径、需要删除旧测试、基线无法编译：停下，写 `research/pi-<x>-blocked.md`，然后结束本轮。
