# pi-A 阶段 2：交叉检查 pi-D

报告：`TASK\check\pi-A-checks-pi-D.md`（51 行）。
检查 worktree `D:\MyNewProjects\_wt\check-a\qfli_studio_core`，分支 `check/pi-a`，内容为 `rework/integration`。
未改 `lib/`、`test/`，未新增 `tool/` 文件，worktree `git status` 干净。

## 已完成

- 读 `RULES-rework.md`、`CHECKLIST.md`、`phase2-check.md`、`rework-pi-D.md`、`status\pi-D-rework.md`。
- 检查 pi-D 五项交付：服务端 README 与 `.env.example`、真机脚本、预览工具、`research/G-agent-isolation.md`、I1。
- 全量 `flutter analyze --no-pub` → `No issues found!`。
- 全量 `flutter test --no-pub` → `+1604 ~9 -4`，4 个失败全是允许项（`editor_run_target_test` 3 个 + `interop_arkts_contract_test` 1 个）。
- I1-I4 全部取证。I1 两处命中经人工核对为误报（权限正文、CI 变量名）。
- 5 个自设破坏性场景，脚本在 `_scratch\pi-a\break-ai-config.js`，截图在 `_scratch\pi-a\`。
- 在集成分支实跑预览工具，导出 2 张，`All tests passed!`。
- 真机脚本实测：`targets`/`shot`/`layout`/`back`/`wait`/`stop`/`wake`/`screen-on` 均正常；`launch` 复现锁屏错误 `10106102`。
  屏幕已点亮但仍为人脸锁屏，证据：`check\screens\pi-a\lockscreen-screen-on.png`。

## 进行中

- 无。

## 请求

1. 大脑确认 I2：主目录 `qfli_studio_core` 在快照（02:51:48）之后被写过 4 个文件
   （`home_page.dart`、`retained_editor_test.dart` 02:52:10；`fake_agent.dart` 03:07:55；
   `vibe_agent_facade.dart` 03:13:35）。无法归因到具体 pi。
2. 大脑决定：README 与 `.env.example` 描述的是未提交的 `src/ai-client.js` 行为
   （`QFLI_AI_REASONING_EFFORTS`）。是否先提交 `src/` 再发布文档。
3. pi-D 修 `device_ui.sh log`（`timeout` 不能执行 shell 函数，静默失效，影响 F6）。
4. pi-D 修两份脚本的 `--help` 越界（多出 `set -euo pipefail`）。
5. pi-D 解锁设备后补真机基线截图；`01-home.png` 目前是锁屏图，名不符实。
   已排除脚本原因：`wake`、`screen-on` 实测生效，屏幕已点亮，但人脸识别失败。

## 未验证

- `tool/build_studio_hap.sh` 未实跑打包（会重编 166 MB 包，且需先放 `pubspec_overrides.yaml`）。
  只做了 `bash -n`、`--help` 与依赖路径核对。
- 真机全流程（CHECKLIST J）不属我的检查范围，由 pi-D 负责。
- `device_ui.sh` 的 `tap`/`text`/`input`/`swipe`：均返回 `No Error`，但 `uiInput` 在锁屏下恒返回 No Error，无法证明输入真的生效。
