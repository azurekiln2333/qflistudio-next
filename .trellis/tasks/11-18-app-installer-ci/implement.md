# Implement：产品安装包云构建工作流

由同工作区 herdr 的 Pi（w37 的 pC、pH、pG、pJ）运行本计划。不开 Claude 子代理。

## 0. 安全规则（每份 Pi 简报开头都要写）

- 禁止 `git reset`、`checkout --`、`restore`、`stash`、`clean`、切换分支、改写历史。
- 禁止改动主工作区 `D:/MyNewProjects/qflistudio` 与 `D:/MyNewProjects/qfli_studio_core`。两者都有大量未提交改动。
- 只在 `D:/MyNewProjects/_wt/app-installers/` 下工作。提交时只用显式路径。
- 提交信息不带任何 AI 署名行。
- 不 push。push 由主会话在用户批准后运行。

## 1. 准备 worktree（主会话运行）

```bash
git -C D:/MyNewProjects/qflistudio worktree add -b ci/app-installers \
  D:/MyNewProjects/_wt/app-installers/qflistudio HEAD
git clone https://github.com/azurekiln2333/qflistudio-core.git \
  D:/MyNewProjects/_wt/app-installers/qfli_studio_core
```

基线为 `HEAD`（`e018db9`），与 GitHub `main` 一致。不读取主工作区的未提交改动。

## 2. 官方最新版兼容性探测（GitHub 云端）

不在本机运行 Flutter 编译、分析或依赖解析。

1. `resolve-flutter` 在 `ubuntu-24.04` 解析官方 stable 版本与框架提交。
2. Windows、Linux、macOS、iOS、Android job 使用同一组版本输出。
3. 云端 job 负责依赖解析、编译、打包和产物架构检查。
4. 将首轮运行结果写入 `research/upstream-compat.md`。

出现兼容性错误时，记录完整日志并另开适配任务。不要在本地复现编译。

## 3. 编写工作流（Pi pH）

按 `design.md` 第 1 节新增文件，顺序：

1. `tool/ci/` 脚本：`resolve_flutter.sh`、`setup_flutter.sh`、`app_version.sh`、`run_logged.sh`、`stage_artifact.sh`、`package_linux.sh`、`thin_macos_app.sh`、`strip_ohos_signing.py`。
2. `.github/actions/setup-ohos/`：从 `D:/MyNewProjects/qfli_python/.github/actions/setup-ohos/` 复制，保留 LICENSE。
3. `.github/actions/app-setup/action.yml`。
4. `windows/installer/qflistudio.iss`。
5. `.github/workflows/app-installers.yml`。

每完成一项，在 worktree 分支上用显式路径提交一次。

## 4. 静态检查（Pi pG 交叉检查，pH 自检）

```bash
# 工作流语法
actionlint .github/workflows/app-installers.yml   # rhysd/actionlint 官方 release 二进制，放 _scratch
# 脚本语法
for f in tool/ci/*.sh .github/actions/setup-ohos/setup.sh; do bash -n "$f"; done
shellcheck tool/ci/*.sh                            # 若可用
python -m py_compile tool/ci/strip_ohos_signing.py
# action 白名单：每个 uses 都是 design.md 第 6 节的 SHA，或本仓库 ./ 路径
grep -rhoE 'uses:\s*\S+' .github | sort -u
# 只做脚本语法与工作流结构检查。不要在本机运行 Flutter。
# 云端 job 负责解析版本、依赖、编译、打包和架构验证。
```

pG 再对照 `prd.md` 的 AC1～AC7 与 `design.md` 逐条审查，问题写入 `research/cross-check.md`。

关卡：主会话审阅 diff 与 cross-check 结果。

## 5. 云端验证（需用户批准 push）

1. 主会话向用户请求批准：`git push github ci/app-installers`。
2. `push` 触发器包含 `ci/**`，push 后自动运行。
3. 用 GitHub REST API（公开仓库，免认证）读取：
   - 运行与各 job 结论。
   - 每个 check run 的 annotations，确认没有 "Node.js 20 is deprecated"。
   - artifact 列表，确认 11 个安装包所在的 artifact 齐全。
4. 失败时由 Pi 修复，重复第 4、5 步。日志下载需要认证。届时请用户 `gh auth login` 或提供只读 token。

## 6. 收尾

1. 云端全绿后，把新增文件合入 `main`。只提交新增路径，不带入主工作区的其他改动。提交前检查 `git diff --cached` 为空。
2. 更新 spec：在 `.trellis/spec/frontend/repository-layout.md` 增加 CI 安装包一节，写明工具链拆分、同级检出与 action 白名单。
3. 删除 worktree 与 `_scratch/flutter-upstream`。

## 回滚点

- 第 3 步之前：删除 worktree 即可。
- 合入 `main` 之后：删除 `design.md` 第 1 节列出的路径。

## Result

提交：

- `db40353`、`d459114`、`3a821fa`、`b70b140`、`5ea5470`：安装包脚本、OHOS setup、共享构建 action、Windows 安装器和完整工作流。
- `075fe05`：删除上游 Flutter 不支持的 `flutter config --no-enable-ohos`。
- `7e1eee6`：修正 Windows arm64 输出路径检查。

静态检查：

- `actionlint` 通过。
- `check_run_blocks.py` 解析 49 个 bash 块，跳过 1 个 cmd 块，失败 0 个。
- Git Bash `bash -n` 和 Python 语法检查通过。
- `ste-lint-zh.py` 检查通过。
- 未运行本地 Flutter 编译、分析或依赖解析。

未完成项：

- 尚未 push `ci/app-installers`，因此 GitHub 云端构建、11 个 artifact、架构校验和 Node 20 annotation 尚未验证。
- 尚未把 worktree 合入 `main`。这两步需要先获得 push 批准，再根据云端结果收尾。
- 远端分支 `ci/app-installers` 可随时删除。
