# pi-A 检查 pi-D

检查对象：服务端 README 与 `.env.example`、真机脚本、预览工具、`research/G-agent-isolation.md`、I1。
检查 worktree：`D:\MyNewProjects\_wt\check-a\qfli_studio_core`（`check/pi-a`，内容为 `rework/integration`）。
临时脚本与截图在 `_scratch\pi-a\`，未入库。

## 汇总

通过 9 项。不通过 3 项。未验证 1 项。

## 结果

| ID | 结果 | 证据 |
|---|---|---|
| D1 服务端 README 配置步骤 | 通过 | `git diff README.md` → +91 行。变量表 8 行与 `src/ai-client.js:38-41` 的 `boundedInt` 默认值和区间逐项一致（60000/100-120000、20/1-600、2/1-8、16/1-64）。`cd /data/qfli/server` 与 README 既有第 460、475 行一致。`docker-compose.yaml` 服务名确为 `server`，`env_file: - .env`，故 `up -d --force-recreate server` 正确。200/401/403/502/503/504 文案与 `ai-client.js:48`、`:262`、`client-context.js:114` 对得上。429 退避「1/2/4 秒、最多 3 次」与 `lib/vibe_coding/agent_request_scheduler.dart:20-24` 一致。 |
| D2 `.env.example` | 通过 | `git diff .env.example` → +7 行，新增 `QFLI_AI_REASONING_EFFORTS=`，四个 AI 变量各一行中文注释。全部为空占位符，无真实值。 |
| D3 `tool/build_studio_hap.sh` | 未验证 | `bash -n` 退出 0；`--help` 正常；`source tool/lib/hvigor_env.sh` 存在且提供 `winpath`/`NODE`/`HVIGOR_JS`/`DEVECO_ROOT`/`OHOS_DIR`/`ensure_plugin_manifest`。未实跑打包（会重编 166 MB 包，且需先放 `pubspec_overrides.yaml`）。 |
| D4 `tool/device_ui.sh` | 不通过 | `bash -n` 退出 0。实测通过：`targets` → `192.168.68.207:46551`；`shot` 取回 73768 字节 PNG（落地自检生效）；`layout` 导出 78576 字节 JSON（含 `lock` 键，佐证锁屏）；`back` → `No Error`；`wait`、`stop` → `force stop process successfully.`；`wake` → `WakeupDevice is called`，实测屏幕从黑屏变亮（截图从 73768 字节变 3778956 字节）；`screen-on` → `Override screen off time to 600000`。失败项只有 `log`，见不通过项 1。`tap`、`text`、`input`、`swipe` 均返回 `No Error`，但 `uiInput` 在锁屏下恒返回 No Error，无法证明真的注入成功，记未验证。 |
| D5 真机基线截图 | 不通过 | `check/screens/pi-d/baseline/` 只有锁屏图。`01-home.png` 实际是锁屏（「未识别成功，双击屏幕重试」）。我用 `wake` + `screen-on` 把屏幕点亮后重拍：`check/screens/pi-a/lockscreen-screen-on.png`（3778956 字节）仍是锁屏，人脸识别失败；黑屏对照 `lockscreen-screen-off.png`（73768 字节）。`device_ui.sh launch` 复现同一阻塞：`Error Code:10106102 The device screen is locked during the application launch, unlock screen failed`。缺「打开项目」那张。 |
| D6 预览工具 | 通过 | 在集成分支实跑：`flutter test --no-pub tool/agent_preview_test.dart --dart-define=PREVIEW_SCENES=empty,failed --dart-define=PREVIEW_SIZES=390x844 --dart-define=PREVIEW_THEMES=light` → 导出 2 张，`All tests passed!`。基线 24 张齐全，尺寸实测 780x1688 / 1200x2000 / 1800x2000 / 2560x1800，与 2 倍率一致。中文字体与 MaterialIcons 已注册。 |
| D7 `research/G-agent-isolation.md` | 通过 | 结论先行。逐条核对：`git_service.dart` 确为 70 行；`isSupported` 仅 Windows/macOS/Linux（第 9-10 行）；`_exists()` 用 `where`/`which`（第 11-19 行）；`status --porcelain`、`log --oneline -20`、`diff --stat HEAD`、`push -u origin HEAD`、`pull --rebase`、`add -A`+`commit -m` 全部逐字命中（第 48-69 行）；`AppPaths.storageDirectory()`、`RunnerService.runProject`、`CodeAnalyzer.analyze` 均存在；`CloudSyncService.git()` → `cloudGit`，服务端 `src/routes/cloud.js:173-174` 固定 503，与文档一致。 |
| T1 `flutter analyze --no-pub` | 通过 | `No issues found! (ran in 9.1s)` |
| T2 `flutter test --no-pub` | 通过 | 汇总 `+1604 ~9 -4: Some tests failed.` 4 个失败全部是允许项：`editor_run_target_test` 3 个（`-1`/`-2`/`-3`）+ `interop_arkts_contract_test` 1 个（`-4`，worktree 环境已知失败）。无其他失败。 |
| I1 无密钥入库 | 通过 | 核心仓 `git grep -nE "sk-…|Bearer …|password *[:=] *['\"]…"` 无命中。TASK 目录 2 处命中经人工核对为误报：`research/C-platform-permissions.md:61` 是权限说明正文，`research/D-cicd.md:136` 是 CI 变量名 `$ANDROID_KEYSTORE_PASSWORD`（无值）。`tool/*.sh`、`tool/agent_workbench_device.md`、服务端 `README.md`、`.env.example` 均无命中。 |
| I2 主目录未被写 | 不通过 | 见不通过项 2。 |
| I3 无禁止的 git 操作 | 通过 | `git reflog show` 五个分支只有 `commit:`、`merge …`、`branch: Created from`。无 reset/checkout/stash/clean/rebase/merge 之外的破坏性操作。 |
| I4 提交信息无 AI 署名 | 通过 | `git log --format=%B wip/baseline-20261114..rework/integration` 扫 `Co-Authored-By|Generated with|Claude|ChatGPT|Codex|Signed-off-by` 无命中。27 条提交全为英文 Conventional Commits。 |

## 不通过项

- **D4-1：`device_ui.sh log` 静默失效。** 现象：`tool/device_ui.sh log 1` 只打印标题行，没有任何 hilog 输出。原因：`timeout "$seconds" hdc_cmd shell hilog` 里 `hdc_cmd` 是 shell 函数，`timeout` 只能执行外部程序，实测 `timeout: failed to run command 'hdc_cmd': No such file or directory`（退出码 127），而该行又带 `2>/dev/null`，错误被吞掉。影响：CHECKLIST F6 依赖的 `[agent-perf]` 行取不到。负责人：pi-D。建议改法：`timeout "$seconds" bash -c "$(declare -f hdc_cmd); hdc_cmd shell hilog"`，或先算出 `-t` 参数再直接调 `timeout … hdc …`，并去掉 `2>/dev/null`。
- **D4-2：`--help` 输出泄漏脚本正文。** 现象：`tool/device_ui.sh` 与 `tool/build_studio_hap.sh` 的 help 末尾都多出一行 `set -euo pipefail`。原因：`sed -n '2,30p'` 的范围越过了注释块（`device_ui.sh` 第 29 行是 `set -euo pipefail`）。负责人：pi-D。建议改法：把范围收到注释块最后一行，或改用 `sed -n '2,/^set -/p'` 再去掉末行。
- **D5：真机基线截图未交付。** 现象：`baseline/` 7 张全是锁屏或黑屏，`01-home.png` 名不符实。原因：设备停在人脸/PIN 锁屏，`aa start` 报 `10106102`，自动化无法解锁。我已确认不是脚本问题：`wake`、`screen-on` 都生效，屏幕已点亮（见 `check/screens/pi-a/lockscreen-screen-on.png`），但人脸识别失败，脚本没有 PIN 也不能替你录入。负责人：pi-D（需人工解锁一次）。建议改法：解锁后跑 `device_ui.sh launch` + `shot 01-home`，再 `tap` 进项目 `shot 02-editor`；未拿到前把 `01-home.png` 改名为 `00g-lockscreen-retry.png`，避免误导。
- **I2：主目录在快照之后被写过。** 现象：`D:\MyNewProjects\qfli_studio_core` 当前 `git diff` 与 `_backups\workbench-rework-20261114-025148\core-tracked.patch` 不一致（103521 vs 107039 字节，20 vs 22 个文件）。差异是 `lib/pages/home_page.dart` 与 `test/retained_editor_test.dart` 被还原成 HEAD 内容。按 mtime 扫描，快照（02:51:48）之后有 4 个文件被写：`test/retained_editor_test.dart`、`lib/pages/home_page.dart`（02:52:10）、`test/support/fake_agent.dart`（03:07:55）、`lib/vibe_coding/vibe_agent_facade.dart`（03:13:35）。后两个是返工新增文件。原因：无法归因到具体 pi（时间早于各分支首次提交）。负责人：大脑确认。建议改法：确认这 4 次写入是准备基线时的有意操作；若不是，按 `core-tracked.patch` 还原并追查。

## 我设计的破坏性场景

1. **往 `QFLI_AI_REASONING_EFFORTS` 灌垃圾**（`LOW , low ,, ,,, Bank; DROP TABLE, a-b_c, 中文, x`）。结果：`reasoningEfforts()` 返回 `["low","a-b_c","x"]`，去重、小写、非法项丢弃，无异常。再灌 16 项 → 截断为 8 项。通过。
2. **未公布的推理强度与多余字段**。`reasoning_effort=high`（只公布 low,medium）→ 400「推理强度参数不可用」；`reasoning_effort=low` → 通过；多传 `temperature` → 400。通过。
3. **畸形 `QFLI_AI_BASE_URL`**。`http://ai.example.com`、`https://user:pass@…`、`https://…/?q=1`、`https://…/#frag`、`not a url`、空值 → 全部 503；`http://127.0.0.1:8080` 放行；有 URL 无 KEY → 503「AI 服务未配置」。通过，但见额外发现 1。
4. **`device_ui.sh log` 在 Git Bash 下**。结果：静默无输出，退出码被 `|| true` 吞掉。不通过，已记为 D4-1。
5. **预览工具传错参数**。`PREVIEW_SCENES=nope` → `PREVIEW_SCENES 没有匹配到场景`；`PREVIEW_SIZES=abc` → `FormatException: 尺寸要写成 390x844：abc`。两者都明确失败，不静默出空图。通过。

## 额外发现

1. **README 与 `.env.example` 描述的是未提交的 `src/ai-client.js` 行为。** `QFLI_AI_REASONING_EFFORTS` 的读取、`reasoning_effort` 透传、`model.reasoning_efforts` 公布，全部只存在于服务端工作树的未提交改动（`src/ai-client.js` mtime 11/12 16:46，早于 pi-D 开工，pi-D 未动它）。若该改动被丢弃，文档会描述不存在的功能。负责人：大脑，决定是否先提交 `src/` 再发布文档。
2. **`configuration()` 的错误文案不精确。** 带凭据、带 query、带 hash 的 HTTPS 地址都返回「AI 服务地址需要 HTTPS」，实际问题是地址形态。README 已用「或地址不是 HTTPS、格式无效」覆盖，故不算文档错误。`src/` 不属 pi-D 范围，转大脑。
3. **`.env.example` 自相矛盾。** `QFLI_AI_MAX_INFLIGHT=16`，紧邻注释写「建议不超过 8」。默认值本身合法（1-64），但默认与建议冲突。负责人：pi-D，建议把默认改成 8 或把注释改成「小主机建议 8」。
4. **集成后 390 宽模型按钮仍截断。** 我在集成分支出的 `empty-390x844-light.png` 显示「DeepSe…」。pi-C 的 `ed0525b` 只做到「可读」，未做到完整。属 pi-C 范围，供大脑参考。
5. **预览工具默认输出路径写死。** `_defaultOutput` 是 `D:/MyNewProjects/qflistudio/.trellis/tasks/11-12-agents-workbench/check/screens/pi-d/preview-baseline` 绝对路径，换机器或换任务即失效。建议改成相对仓库根或强制传 `PREVIEW_OUT`。
6. **我的 worktree HEAD reflog 有一条 `reset: moving to HEAD`**（`check/pi-a`）。属环境准备，不是实现者操作，记录以免误判 I3。
