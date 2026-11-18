# G：会话分支（agent isolation）设计调研

调研对象：`lib/services/git_service.dart`、`lib/pages/git_page.dart`、`lib/services/cloud_sync_service.dart`、
`lib/services/api_client.dart`、`lib/services/runner_service.dart`、`lib/services/code_analysis.dart`、
`lib/services/app_paths.dart`，以及服务端 `src/routes/cloud.js`。
只读调研，本文件不含代码改动。

## 结论

**能做，但要分两档，不能一套方案打到底。**

- 桌面（Windows / macOS / Linux，且装了 git）：**能做**，用 `git worktree`。证据：`GitService` 已经在跑本机 git CLI（`Process.run('git', ...)`），`GitService.isSupported` 只在桌面为真。缺的是 `worktree`、`branch`、`merge`、`diff` 四个子命令的封装，都是加方法，不改现有行为。
- 手机（Android / iOS / 鸿蒙）：**能做，但只能做写时复制叠加层**。证据：`GitService.isSupported` 在移动端为假，`run()` 直接返回 `当前平台不支持本地 git`。移动端没有 git 二进制，也没有可用的系统级 overlay 文件系统，所以叠加层必须由应用自己实现。
- 云端项目：**现在不能做**。证据：`CloudSyncService.git()` 打 `POST /api/cloud/projects/:id/git`，服务端 `src/routes/cloud.js` 里这个路由固定返回 `503 云端 Git 安全执行环境尚未配置，已禁止宿主机执行`。云端分支要等这个执行环境落地，本设计只留接口位。

风险最高的是叠加层的合并器（三方合并 + 冲突呈现），不是 worktree。建议先做桌面 worktree，验证交互和合并界面，再决定移动端叠加层是否值得做。

## 1. 现有 git 能力清单

`GitService`（`lib/services/git_service.dart`，70 行）：

| 能力 | 实现 | 备注 |
| --- | --- | --- |
| 平台判断 | `isSupported` = Windows / macOS / Linux | 移动端为假 |
| git 是否存在 | `where git` / `which git` | 每次调用都探测一次 |
| 执行 | `Process.run('git', args, workingDirectory: projectPath)` | Windows 走 `runInShell` |
| `init` | `git init` | |
| `status` | `git status --porcelain` | |
| `log` | `git log --oneline -20` | 固定 20 条 |
| `diff` | `git diff --stat HEAD` | 只有统计，没有逐行差异 |
| `push` | `git push -u origin HEAD` | |
| `pull` | `git pull --rebase` | |
| `setRemote` | `remote remove origin` + `remote add origin` | |
| `commit` | `git add -A` + `git commit -m` | 全量暂存 |

缺口（做会话分支必须补）：`worktree add/remove/list`、`branch`、`merge`、`diff` 逐行输出、`status` 的机器可读解析、`rev-parse`、`hash-object`。

`GitPage`（`lib/pages/git_page.dart`）：桌面走 `GitService`，云端走 `CloudSyncService.git()`。界面只有按钮和一段文本输出，没有差异视图，没有冲突处理。

`CloudSyncService.git()`：转发到 `POST /api/cloud/projects/:id/git`，参数 `{action, message?, url?}`。服务端该路由固定 503，所以云端 git 目前不可用。

## 2. 平台矩阵

| 平台 | 有 git | 可行方案 | 说明 |
| --- | --- | --- | --- |
| 桌面 + 有 git | 是 | `git worktree` | 首选。分支、合并、差异都由 git 提供 |
| 桌面 + 无 git | 否 | 写时复制叠加层 | 与移动端同一套实现。`GitService._exists()` 已经能探测到这种情况 |
| Android | 否 | 写时复制叠加层 | 项目根在应用沙箱内，路径可控 |
| iOS | 否 | 写时复制叠加层 | 同上。沙箱内不需要额外授权 |
| 鸿蒙 | 否 | 写时复制叠加层 | 同上。`path_provider_ohos` 已提供沙箱目录 |
| 云端项目 | 否（服务端 503） | 暂不做，留接口 | 等 `cloud.js` 的 git 执行环境落地 |

判定顺序：先看 `GitService.isSupported`，再看 `_exists()`，两者都真才走 worktree，否则走叠加层。

## 3. 方案 1：git worktree

### 命令序列

创建（进入项目后第一次需要分支时）：

```bash
git -C <项目根> rev-parse --is-inside-work-tree      # 不是仓库就先 init
git -C <项目根> rev-parse --verify HEAD              # 没有提交就先做一次基线提交
git -C <项目根> worktree add <分支目录> -b qfli/session-<会话ID>
```

合并（用户点「合并到项目」）：

```bash
git -C <分支目录> add -A
git -C <分支目录> commit -m "session: <会话标题>"
git -C <项目根> merge --no-ff qfli/session-<会话ID>
```

丢弃：

```bash
git -C <项目根> worktree remove --force <分支目录>
git -C <项目根> branch -D qfli/session-<会话ID>
```

### 目录位置

`<应用数据目录>/worktrees/<项目ID>/<会话ID>/`。不放项目内，避免被文件树、搜索、打包扫到。
`AppPaths.storageDirectory()` 已经给出可写目录，直接在其下建子目录。

### 忽略规则

- 分支目录不在项目根内，文件树天然看不到。
- 项目根的 `.gitignore` 追加 `worktrees/` 只在有人把目录放进项目时才需要，本方案不需要。
- 分支目录里的 `.git` 是文件（指向主仓库的 `worktrees/<名字>`），不是目录。备份与打包逻辑要跳过它。

### 异常处理

| 情况 | 处理 |
| --- | --- |
| 项目不是 git 仓库 | 提示「这个项目还不是 git 仓库」，给「初始化并创建分支」一个按钮 |
| 仓库没有任何提交 | 先做一次基线提交（`git add -A` + `commit`），再建 worktree |
| 分支名已存在 | 复用同名分支，不新建 |
| 目录已存在但没注册 | `worktree prune` 后重试一次 |
| 磁盘空间不足 | 建之前查可用空间，低于 200 MB 拒绝并说明 |
| 用户手动删了目录 | `worktree list` 对不上时 `prune`，再重建 |

## 4. 方案 2：写时复制叠加层

### 读取穿透

叠加层只存「被改过的文件」。读一个路径时按顺序找：

1. 叠加层目录 `<数据目录>/overlays/<项目ID>/<会话ID>/files/<相对路径>`
2. 主项目 `<项目根>/<相对路径>`

第 1 步命中就用它，否则读主项目。目录列表取两边的并集，叠加层里的删除标记（`.deleted` 清单）从并集里剔除。

### 第一次写才复制

写一个路径时：

1. 叠加层里没有这个文件 → 先把主项目里的原文件复制进叠加层（不存在就记为空文件），并记下基线哈希。
2. 再写叠加层里的副本。
3. 主项目一个字节都不动。

进入项目、打开会话、浏览文件都不复制任何东西。复制只发生在第一次写某个路径时。

### 记录基线哈希

每个被复制的文件在 `<叠加层>/baseline.json` 里记一条：

```json
{ "lib/main.dart": { "sha256": "…", "size": 1234, "copiedAt": "2026-11-14T04:00:00Z" } }
```

哈希用 `sha256`，与 `crypto` 包一致。合并时用它判断主项目这一侧有没有被别人改过。

### 三方合并

合并一个路径时比较三份内容：

| 名称 | 来源 |
| --- | --- |
| base | 复制时的基线（哈希对得上就用主项目当前内容，对不上说明主项目变了） |
| ours | 主项目当前内容 |
| theirs | 叠加层里的副本 |

判定：

- `theirs == base`：这一侧没改，跳过。
- `ours == base`：只有会话改过，直接覆盖主项目。
- `ours == theirs`：两边改成一样，跳过。
- 三者都不同：逐行三方合并。能自动合并就写回，冲突就进冲突列表。

逐行合并用「最长公共子序列」求差异块，再按块合并。不引入第三方 diff 包，`re_editor` 里已有行级 diff 的基础设施可复用。

### 运行或检查时才临时展开

运行、诊断、打包需要看到完整目录。做法：

1. 在 `<数据目录>/staging/<项目ID>/<会话ID>/` 建一个临时目录。
2. 用硬链接把主项目文件链进去（同盘，零拷贝）。
3. 把叠加层里的文件覆盖进去（真复制，数量少）。
4. 把 `.deleted` 清单里的路径删掉。
5. 运行或检查结束后删掉临时目录。

硬链接失败（跨盘、文件系统不支持）时退回复制，并提示「本次运行会慢一些」。

### 进入项目不复制任何东西

这条是硬约束。进入项目只做两件事：读 `baseline.json`（不存在就当空），读 `.deleted` 清单。两者都是小 JSON。

## 5. 合并前检查

| 检查 | 现有能力 | 用法 |
| --- | --- | --- |
| 编辑器诊断 | `CodeAnalyzer.analyze(CodeAnalysisRequest)` 返回 `CodeDiagnostic` 列表 | 对叠加层里改过的文件跑一遍，有 error 级诊断就拦下 |
| 运行一次 | `RunnerService.runProject(...)` 返回 `RunResult` | 可选。用户点「先跑一次」才跑，不自动跑 |
| agent 自检 | 会话里最后一条 assistant 消息 | 只做提示，不作为拦截条件 |
| 主项目是否被改 | `baseline.json` 的哈希对比 | 主项目这一侧变了就标「需要人工确认」 |

拦截规则：诊断有 error 就默认不允许合并，用户可以在确认框里选择「仍然合并」。

## 6. 合并界面

- 入口：Agent 面板顶部一个「合并到项目」按钮，只在会话有改动时出现。
- 差异视图：左侧文件列表（只列改过的路径，带 +N / -M 行数），右侧逐行差异。新增行绿底，删除行红底，与编辑器主题 token 一致。
- 冲突处理：冲突文件单独分组，每个冲突块给三个按钮「用项目版本」「用会话版本」「手动编辑」。手动编辑打开编辑器，保存后重新判定。
- 合并结果：底部一行汇总「合并 N 个文件，跳过 M 个，冲突 K 个」，加「完成」和「撤销本次合并」。
- 撤销：合并前把主项目被覆盖的文件备份到 `<数据目录>/merge-backup/<时间戳>/`，撤销时按备份还原。

## 7. 数据结构和存储位置

```dart
/// 一个会话的分支状态。存在 <数据目录>/sessions/<会话ID>/branch.json。
class AgentBranchState {
  String sessionId;
  String projectId;
  AgentBranchKind kind;        // worktree | overlay | none
  String? worktreePath;        // kind == worktree
  String? branchName;          // kind == worktree
  String? overlayPath;         // kind == overlay
  DateTime createdAt;
  int changedCount;            // 只做列表展示，真实数据以文件为准
}

enum AgentBranchKind { none, worktree, overlay }
```

| 数据 | 位置 |
| --- | --- |
| 分支状态 | `<数据目录>/sessions/<会话ID>/branch.json` |
| worktree 目录 | `<数据目录>/worktrees/<项目ID>/<会话ID>/` |
| 叠加层文件 | `<数据目录>/overlays/<项目ID>/<会话ID>/files/` |
| 基线哈希 | `<数据目录>/overlays/<项目ID>/<会话ID>/baseline.json` |
| 删除清单 | `<数据目录>/overlays/<项目ID>/<会话ID>/deleted.json` |
| 运行临时目录 | `<数据目录>/staging/<项目ID>/<会话ID>/` |
| 合并备份 | `<数据目录>/merge-backup/<时间戳>/` |

写入一律先写临时文件再改名，与会话存储的做法一致。

## 8. 与会话的关系

- 一个会话最多一个分支。`AgentBranchState` 挂在会话上，随会话删除一起清理。
- 创建会话时给一个选项：「在项目里直接改」（默认）或「在独立分支里改」。
- 默认策略（建议）：**第一个运行的会话直接在项目里工作。第二个并行会话启动时，提示是否创建独立分支。**
  理由：单会话时分支没有收益，只增加合并步骤；两个会话同时写同一批文件才会互相踩。
- 已有路径租约（design §11.4）负责同一时刻的写冲突。分支负责跨轮次的分歧。两者不重复：租约管「现在」，分支管「之后」。
- 会话列表每行加一个标记：有分支的显示分支图标，有未合并改动的显示数字角标。
- 删除会话时：有未合并改动先问一次「丢弃这些改动？」，确认后删分支目录。

## 9. 工作量估计与风险

| 模块 | 内容 | 估计 |
| --- | --- | --- |
| `GitService` 扩展 | worktree / branch / merge / diff 逐行 / rev-parse | 1 天 |
| 分支状态与存储 | `AgentBranchState`、读写、清理 | 0.5 天 |
| worktree 流程 | 创建、合并、丢弃、异常处理 | 1.5 天 |
| 叠加层读写 | 读穿透、写时复制、删除清单 | 2 天 |
| 三方合并器 | 行级 diff、自动合并、冲突块 | 3 天 |
| 运行临时展开 | 硬链接、回退复制、清理 | 1 天 |
| 合并界面 | 差异视图、冲突处理、撤销 | 2.5 天 |
| 合并前检查 | 诊断接入、拦截规则 | 0.5 天 |
| 测试 | 单元测试为主，界面用预览工具出图 | 2 天 |
| 合计 | | 约 14 天 |

风险：

1. **三方合并器是主要风险**。行级合并的边界情况多（换行符、编码、大文件）。缓解：先只支持 UTF-8 文本，二进制文件一律「整文件取会话版本」，并在界面写明。
2. **硬链接在移动端可能不可用**。缓解：失败就复制，并提示耗时。
3. **磁盘占用**。worktree 会复制一份工作区。缓解：建之前查空间，低于 200 MB 拒绝。
4. **云端项目不可用**。缓解：云端会话不显示分支选项，等 `cloud.js` 的 git 执行环境落地再接。
5. **用户不理解分支**。缓解：默认不开分支，只在第二个并行会话时提示一次，文案写清「改动先放在分支里，检查后再合并」。
