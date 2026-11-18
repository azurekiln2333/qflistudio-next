# pi-D 返工状态（第三轮：交叉检查修复）

## 已完成

**第一步：合并集成分支**
- `_wt\pi-d\qfli_studio_core`（分支 rework/pi-d）运行 `git merge --ff-only rework/integration`。快进 646a282 → a43b7df，37 个文件，合并后工作树干净。
- 合并后 `flutter analyze --no-pub`：No issues found。
- `git rev-list --left-right --count rework/integration...HEAD` = 0 / 0，与集成分支一致。

**D4-1：device_ui.sh log 静默失效**
- 病因：`timeout "$seconds" hdc_cmd ...`。`timeout` 是外部程序，调不到 shell 函数 `hdc_cmd`，stderr 被 /dev/null 吞掉，命令瞬间返回。
- 修：拼 `hdc_args=(-t "$HDC_TARGET")`（为空则空数组），直接 `timeout "$seconds" hdc "${hdc_args[@]}" shell hilog`。无 timeout 时退回 head。
- 实测：`log 3` 跑满 ~4.0s、退出 0；设 `HDC_TARGET` 后 `log 2` 跑满 ~2.3s、退出 0。`timeout 2 hdc shell hilog | grep --line-buffered HiLog` 输出真实 hilog 行。

**D4-2：--help 多出 `set -euo pipefail`**
- device_ui.sh：`sed -n '2,30p'` 改 `2,28p`（--help 与未知子命令两处）。
- build_studio_hap.sh：`sed -n '2,22p'` 改 `2,20p`。
- 实测：两份 `--help` 都不再有 `set -euo pipefail`；`bash -n` 均返回 0。

**提前验证 OHOS 构建**
- studio 主目录建未跟踪 `pubspec_overrides.yaml`：`qfli_studio_core` 与 `re_editor` 都指向 `_wt\integration\qfli_studio_core`。`git check-ignore -v` 命中 `.git/info/exclude:23`。保留未删。
- 发现并修 `build_studio_hap.sh` 真实 bug：`REPO_ROOT` 指到 `D:/qflistudio/ohos`，首跑报「找不到 …/ohos」；改为 `REPO_ROOT="$STUDIO_ROOT"`。
- `flutter pub get`：两份依赖都显示 `overridden`。pub get 会改写 `pubspec.lock`，已手工还原为 `../qfli_studio_core`。
- `tool/build_studio_hap.sh`：BUILD SUCCESSFUL（23s），日志含「内核覆盖: …integration…」，产物 166M。
- `tool/device_ui.sh install`：`install bundle successfully`。

**补截图（900 / 1280）**
- 根因：`_selectSession` 靠点侧边栏会话行；中屏/宽屏下会话行在抽屉里点不到。
- 修：从顶栏 `AgentEntryButton.host` 取宿主，`host.activate()` + `state.selectSession(id)` + `setAgentPaneCollapsed(false)` + `showMainPane(MainPane.agent)`，与宽度无关。
- 重出 4 场景 × 390x844 / 900x700 / 1280x800 × 两主题 = 24 张，落 `check\screens\integration\`，覆盖旧文件。抽查各场景文本正确。

**提交**
- `9a63d02` fix(tool): run the hilog capture through the real hdc binary（device_ui.sh）
- `2a93c0a` fix(tool): trim the help text and fix the hvigor project root（build_studio_hap.sh）
- round-2 的 `tool/agent_preview_test.dart` 已在 `646a282` 提交，随集成分支合并。

## 进行中

无。

## 请求

- 其余未跟踪文件按 rework-pi-D.md 第 15/73 行不提交：studio `pubspec_overrides.yaml`（保留不删）、check-d 截图工具、TASK 截图。
- 设备锁屏：本轮再次 `wake` + `shot` 确认仍在锁屏（07:30 界面）。`[agent-perf]` 日志行与真机启动截图待人工解锁，未反复尝试解锁。

## 未验证

- 真机启动 App 后的 `[agent-perf]` 日志（锁屏）。
- 真机运行截图（锁屏）。
- 安装后未启动 App，未做运行期冒烟。
