# netrix 工具移植：框架与第 1 批（Pi C）

父任务：`.trellis/tasks/11-16-home-tutorial-tools-ui`。先读父任务的 `pi-rules.md`。

## 目标

把 `D:\MyOtherNewProj\netrix`（Flutter 项目，只读）的工具页和全部工具移植进来。你负责框架、契约、第 1 批工具。Pi D 负责清单和第 2 批。Pi B 负责第 3 批。

## 需求

### 契约与骨架（先做，别人在等）

- 写 `research/tools-port-contract.md`。必须包含父任务 `design.md` 3.2 列出的全部内容。
- 提交骨架：工具对外接口、总注册表、三批各自的空注册文件、可见范围判断、显示密度状态。
- 骨架必须能编译。`flutter analyze` 无问题。
- 把骨架提交的哈希（每个仓库一个）写进契约文件。
- 契约和骨架要尽快完成。先做它们，再做别的。

### 工具页框架

- R7 工具页支持紧密显示和宽松显示。两种显示的布局、间距、图标、文字与 netrix 一致。
- R7 切换显示密度的控件与 netrix 一致。应用保存用户的选择。重启后保留。
- R7 两种显示密度对工具页的全部工具生效，包括现有工具。
- R7 netrix 工具页的其他界面元素（分类、分组、搜索、收藏、排序等，以 netrix 实际有的为准）一并移植。
- R8 现有工具与 netrix 工具功能重复时，合并成一个。合并项保留双方功能的并集。
- R8 重复的判定和每一对的处理写进 `research/tools-duplicates.md`。
- R9 移植来的工具只在 qflistudio 主程序显示。子项目（基于 `qfli_studio_core` 的其他应用）不显示。
- R9 现有工具的可见范围不变。合并项沿用现有工具的可见范围。
- R9 子项目也使用新的工具页 UI（两种显示密度）。

### 第 1 批工具

- 移植 `research/netrix-tools-inventory.md` 里分给第 1 批的工具。
- 移植要求与 Pi D 的 `prd.md`「移植要求」一节相同。

## 约束

- 不改主页、教程页、示例代码页的文件。
- 不改 `lib/services/studio_profile.dart`（内核）和 `lib/main.dart`（主程序）。可见范围判断放在新文件里。行不通时停下并报告。
- 现有工具的功能和入口不变。
- 新依赖只在确实需要时添加。版本与 netrix 使用的版本兼容，并且与本项目的 Flutter（`D:\ProgramFiles\flutter_ohos`）兼容。
- 新增文字跟随现有多语言方式。

## 验收标准

- [ ] `research/tools-port-contract.md` 存在，含骨架提交哈希。
- [ ] 工具页有紧密显示和宽松显示。切换后重建页面，选择保留。有组件测试。
- [ ] 两种显示与 netrix 对照一致。报告列出对照过的属性（列数、间距、图标尺寸、字号）。
- [ ] 主程序配置下，清单里的每个工具都出现在工具页。有测试，测试读取注册表逐个断言。
- [ ] 非主程序配置下，移植来的工具一个都不出现，现有工具照常出现。有测试。
- [ ] `research/tools-duplicates.md` 列出每一对重复工具和处理结果。没有重复时写明「无」。
- [ ] 第 1 批的每个工具都能打开，逻辑与 netrix 一致。每个工具至少一个逻辑测试或组件测试。
- [ ] 现有工具的旧测试继续通过。
- [ ] 改动过的仓库 `flutter analyze` 无问题，`flutter test` 全部通过。
- [ ] 没有改动 `research/dirty-files.txt` 的路径。
- [ ] 报告 `research/pi-c-report.md` 已写。
