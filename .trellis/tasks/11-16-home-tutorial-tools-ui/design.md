# 设计：边界、契约、集成

大脑没有读项目代码。本文件只规定仓库边界、Pi 之间的契约、集成方式。代码级设计由各 Pi 写进子任务的 `design.md`。

## 1. 仓库与基线

| 仓库 | 主工作树 | 基线提交 | 说明 |
|---|---|---|---|
| 主程序 | `D:\MyNewProjects\qflistudio` | `d26cffc` | 有未提交工作 |
| 内核 | `D:\MyNewProjects\qfli_studio_core` | `573d1b6` | 有大量未提交工作 |
| netrix | `D:\MyOtherNewProj\netrix` | 当前内容 | 只读。Flutter 项目 |

- 基线在 `D:\MyNewProjects\_wt\ui-int` 验证通过：两个仓库 `flutter pub get` 成功，`flutter analyze` 为 `No issues found!`（2026-11-16）。
- 每个 Pi 有一对 worktree。位置见 `pi-rules.md`。
- 集成 worktree：`D:\MyNewProjects\_wt\ui-int`，分支 `ui/integration`。只有大脑合并到这里。
- 基线选择 `HEAD` 而不是用户的未提交工作。原因：本次成果要提交并推送，历史必须干净。
- 主程序主工作树的 `pubspec_overrides.yaml` 把内核指向 `D:\MyNewProjects\_wt\integration\qfli_studio_core`（分支 `rework/integration`）。Pi 的 worktree 没有这个文件，所以使用同目录的内核 worktree。Pi 不得创建这个文件。

## 2. 文件归属

| 区域 | 归属 | 别人能否修改 |
|---|---|---|
| 主页（悬浮按钮、右上角菜单、标签栏、搜索） | Pi A | 不能 |
| 教程页、示例代码页、它们的入口 | Pi B | 不能 |
| 工具页框架、工具注册表、可见范围判断、显示密度 | Pi C | 不能 |
| netrix 第 1 批工具 | Pi C | 不能 |
| netrix 第 2 批工具 | Pi D | 不能 |
| netrix 第 3 批工具 | Pi B（教程合并提交之后） | 不能 |
| 多语言资源文件、`pubspec.yaml` | 共享 | 能。只追加，不重排，不改别人的行 |

共享文件只追加。这样合并冲突只出现在文件末尾，容易解决。

## 3. 契约

### 3.1 搜索框（A 与 B）

- Pi A 新建一个可复用的折叠搜索组件。外观与教程页现有搜索框一致。
- Pi A 不修改教程页文件。Pi B 不修改主页文件。
- Pi A 在报告里写明组件路径和用法。
- 集成阶段由大脑指定一个 Pi 让教程页改用同一个组件。

### 3.2 工具移植（C、D、B）

- Pi D 先产出 `research/netrix-tools-inventory.md`。内容见 D 的 `prd.md`。清单把工具分成三批。
- Pi C 同时产出 `research/tools-port-contract.md`，并提交骨架。契约必须规定：
  - 移植工具的目录和文件命名。
  - 一个工具对外提供什么（标识、名称、图标、分类、入口页面、紧密显示和宽松显示所需的数据）。
  - 注册方式。每一批用自己的注册文件。总注册表按批拼接。这样三个 Pi 不改同一个文件。
  - 可见范围判断的接口。
  - 显示密度的状态和持久化位置。
  - 多语言文字的写法。
  - 新依赖的加法。
- Pi C 把骨架提交的哈希写进契约文件。Pi D 和 Pi B 在自己的内核或主程序 worktree 里 `git merge <哈希>`，然后按契约移植。
- 契约发布后需要修改时，Pi C 在契约文件末尾追加「变更记录」。Pi C 不得悄悄改接口。

### 3.3 可见范围（R9）

- 目标：移植来的工具只在 qflistudio 主程序显示。子项目不显示。
- 推荐方案：在新文件里提供「当前应用是否为主程序」的判断。判断依据使用现有的应用配置信息。
- 不得修改 `lib/services/studio_profile.dart`（内核）和 `lib/main.dart`（主程序）。两个文件都有用户未提交的修改。
- 现有方案确实行不通时，Pi C 停下并报告。大脑决定怎么处理。
- 必须有两个测试：主程序配置下显示，非主程序配置下不显示。

### 3.4 主页标签顺序（R3、R4）

- 顺序用稳定的标签标识保存，不用下标保存。
- 读到未知标识时忽略它。缺少的标签按默认顺序补在后面。
- 拖动排序不得改变标签内容和现有的标签切换行为。

## 4. 集成流程

1. 每个 Pi 完成后写报告。大脑读报告和 `git log`、`git diff --stat`（关卡 1）。
2. 大脑在 `ui-int` 依次合并 `ui/pi-c`、`ui/pi-d`、`ui/pi-b`、`ui/pi-a`。两个仓库分别合并。
3. 大脑派 Pi 交叉检查：每个 Pi 检查另一个 Pi 的改动。检查在 `ui-int` 上进行。修复提交在 `ui/integration`。同一时刻只有一个 Pi 在 `ui-int` 写入。
4. 一个 Pi 在真机或模拟器上走全流程并截图。
5. 大脑复核截图（UI/UX）和测试输出。
6. 大脑把 `ui/integration` 快进合并到两个仓库的 `main`，推送，打 tag。

## 5. 风险

| 风险 | 处理 |
|---|---|
| 用户主工作树有未提交修改，与本次改动重叠 | Pi 不碰 `dirty-files.txt` 的路径。快进合并遇到重叠时 git 会拒绝，不会覆盖。大脑届时单独处理 |
| 新依赖改变 `pubspec.lock`（主程序的锁文件有未提交修改） | Pi 只在 worktree 里提交 `pubspec.yaml` 和锁文件。大脑在最后一步处理主工作树 |
| 用户日常构建指向 `rework/integration` 的内核 | 本次内核提交进入 `main`。大脑在交付说明里告诉用户 |
| netrix 工具依赖本项目没有的平台能力 | Pi 在清单里标出。能力缺失时工具仍要移植 UI 和逻辑，并在报告里写明差异 |
| netrix 工具数量很大 | 分三批并行 |

## 6. 回滚

- 每个 Pi 的工作都在自己的分支上。丢弃一个分支不影响别人。
- 推送之前，`main` 不动。推送之后的回滚用 `git revert`。
