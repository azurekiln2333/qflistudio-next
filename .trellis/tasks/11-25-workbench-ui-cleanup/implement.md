# 执行计划

## 阶段

1. 实现：4 个 Pi 并行，各在自己的 worktree 与分支提交。
   - 第一阶段：design.md 第 4–7 节，简报 `brief-pi-<x>.md`，完成标记 `pi-<x>.done`。
   - 第二阶段：design.md 第 10 节 MD3 视觉整改，新会话执行，
     简报 `brief-pi-<x>-ui.md`，完成标记 `pi-<x>-ui.done`。
   - 编排脚本：`D:/MyNewProjects/_wt/wsui/scripts/wait-pis.sh`，日志 `reports/orchestrator.log`。
2. 门禁 1：大脑读各分支 diff，对照 design.md 第 3–7 节。
3. 集成：一个 Pi 在 `wsui/integration` 合并 4 条分支，按需求重建线性提交。
4. 交叉检查：每个 Pi 审另一个 Pi 的分支（A↔C，B↔D）。
5. 云端：大脑推 `wsui/integration` 到 GitHub，看 core-check 结果，失败回给对应 Pi。
6. 大脑终审与 UI/UX 检查，然后合入 main、推送、更新 App 的 CORE_REF、打 tag。

## 每个 Pi 的交付

- 在自己的分支提交，用显式路径 `git add <file>`。
- 提交信息不带署名行。
- 写报告：`D:/MyNewProjects/_wt/wsui/reports/pi-<x>.md`。
  内容：改动文件、对应需求编号、未解决问题、给集成方的合并提示。
- 完成后创建 `D:/MyNewProjects/_wt/wsui/reports/pi-<x>.done`。

## 禁止

- `git reset`、`git checkout --`、`git restore`、`git stash`、`git clean`、
  切换分支、改写历史、`git push`、打 tag。
- 改别的 Pi 独占的文件（见 design.md 第 3 节）。
- 本机跑 `flutter test`、构建、模拟器、虚拟机、WSL。
- 向用户提问。遇到不确定处，按 design.md 的原则自行决定，写进报告。

## 允许的本机检查

- `flutter pub get`
- `dart format <改动文件>`
- `flutter analyze <改动文件>`

## 会话轮数

Pi 用 gpt-6.1-sol，单会话上限 20 轮。
- 简报一次给全，Pi 不需要追问。
- 每完成一个小节，把进度追加到报告文件。
- 会话轮数用尽时，大脑 `/new` 后让 Pi 读报告继续。

## 回滚点

- 基线 `wsui/base`（`6e22b5b`）。
- 每条 Pi 分支可单独丢弃。
