# 执行计划（父任务，大脑执行）

## 阶段 0：准备（大脑）

- [x] 建父任务和四个子任务。
- [x] 建五对 worktree：`ui-a`、`ui-b`、`ui-c`、`ui-d`、`ui-int`。
- [x] 在 `ui-int` 验证基线：`flutter pub get`、`flutter analyze` 通过。
- [x] 写 `research/dirty-files.txt`。
- [ ] 写完全部计划文件。`task.py start` 四个子任务。
- [ ] 清空四个 Pi 的上下文（`/new`）。派发第一轮。

## 阶段 1：并行实现（Pi）

| Pi | 第一步 | 第二步 |
|---|---|---|
| A | 主页 R1、R2、R3、R4、R5、R11 | 写报告 |
| B | 教程合并 R6 | 移植第 3 批工具（等清单和契约） |
| C | 写移植契约，提交骨架 | 工具页框架、显示密度、可见范围、合并重复、第 1 批工具 |
| D | 写 netrix 工具清单 | 移植第 2 批工具（等契约） |

关卡 1（大脑，每个 Pi 完成时）：

- [ ] 报告存在，内容完整。
- [ ] `git log` 的提交信息合规，无署名。
- [ ] `git diff --stat <基线>..ui/pi-x` 没有 `dirty-files.txt` 的路径。
- [ ] 报告里的 analyze 和 test 输出是通过。
- [ ] 两个主工作树的 `git status` 没有因 Pi 而变化。

## 阶段 2：集成（大脑）

- [ ] 在 `ui-int` 两个仓库分别合并四个分支。顺序：c、d、b、a。
- [ ] 在 `ui-int` 运行 `flutter pub get`、`flutter analyze`、`flutter test`（两个仓库）。

## 阶段 3：交叉检查与真机全流程（Pi，在 `ui-int`，串行写入）

- [ ] Pi A 检查工具移植（对照 netrix 清单逐项核对，C、D、B 的三批）。
- [ ] Pi D 检查主页改动和教程合并。
- [ ] Pi B 让教程页改用 A 的折叠搜索组件。
- [ ] Pi C 在真机或模拟器走全流程。截图存 `screens/`。全流程清单：
  - 主页五个标签的默认顺序。
  - 长按拖动一个标签。重启应用后顺序保留。
  - 在「云端项目」标签点悬浮按钮，进入新建云端项目。
  - 在其他标签点悬浮按钮，行为与改动前一致。
  - 右上角菜单没有「新建云端项目」。
  - 主页搜索图标展开为搜索框，输入后过滤，收起后恢复。
  - 项目列表的语言标签是胶囊形，字体变小（R11）。
  - 教程页：标题、单行语言栏、教程与示例代码切换、搜索。
  - 工具页：紧密显示、宽松显示、切换后重启保留。
  - 逐个打开移植来的工具，至少每个工具一张截图。
  - 非主程序配置下工具页不显示移植来的工具（测试或截图证明）。

## 阶段 4：复核与发布（大脑）

- [ ] 复核截图（UI/UX）。问题派回 Pi 修复，然后重跑受影响的检查。
- [ ] 更新 `.trellis/spec/`（由 Pi 起草，大脑检查）。
- [ ] 两个仓库：`main` 快进到 `ui/integration`。遇到与未提交修改重叠时停下，单独处理。
- [ ] 提交任务文档（只加本任务的路径）。
- [ ] 推送两个仓库的 `main` 到各远端。
- [ ] 打 tag 并推送。tag 名在发布时按 `pubspec.yaml` 版本和 CI 配置决定。
- [ ] 归档子任务和父任务。

## 验证命令

```powershell
# 在某个 worktree 对里
cd D:\MyNewProjects\_wt\ui-int\qfli_studio_core; flutter pub get; flutter analyze; flutter test
cd D:\MyNewProjects\_wt\ui-int\qflistudio;       flutter pub get; flutter analyze; flutter test
```

## herdr 派发方式

```powershell
herdr agent prompt w37:pC "<ascii text pointing at the brief files>" --wait
```

- 提示词只用 ASCII。细节放在任务文件里。
- Pi 遇到网关 502 会变成空闲。大脑读它的输出后让它继续。
