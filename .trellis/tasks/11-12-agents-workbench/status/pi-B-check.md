# pi-B 阶段 2 交叉检查状态：检查 pi-A

检查 worktree `D:\MyNewProjects\_wt\check-b\qfli_studio_core`，分支 `check/pi-b`，内容为 `rework/integration`。
报告：`TASK\check\pi-B-checks-pi-A.md`。

## 已完成
- 读完 `RULES-rework.md`、`CHECKLIST.md`、`phase2-check.md`、`design.md` §11、pi-A 两份 brief 与 status。
- `flutter analyze --no-pub`：`No issues found! (ran in 10.1s)`。
- `flutter test --no-pub`：`00:51 +1604 ~9 -4: Some tests failed.`。4 个失败 = `editor_run_target_test` 3 个（允许）+ `interop_arkts_contract_test` 1 个（已知环境失败，忽略）。
- 重点项 A1-A5、B1-B7、E2、E3、F5、G8、G9 全部通过，逐项附证据写进报告。
- G9 用位置断言验证（临时测试，`tool/`，未跟踪，已删）：agent 入口在 390/600/900/1280 均 48×48、`top=4`、右边缘距屏幕右边恒为 152px；侧边栏分段均 `left=20`。
- 额外项 I1-I4 全部通过：无真实密钥、主目录 HEAD 未变、pi-A 分支无禁止 git 操作、提交无 AI 署名。
- 自设计 5 个破坏性场景，全部通过：断点边界 719/720/1099/1100 展开、离线产品强制开启、连续展开收起加跨断点拉伸、发送后立刻拉伸、agent 开启加脏缓冲最小化恢复。
- 临时测试写在 `tool/`（未跟踪），跑完已删除；worktree 干净，未改 `lib/`、`test/`。

## 进行中
- 无。

## 请求
- B5 的 `onOpenAgent` 移除不在 B5 允许清单，但由 `rework-pi-A-round2.md` 第 5 步授权，请大脑确认口径一致。
- G9 已用位置断言通过；若大脑仍要截图，请 pi-D 真机补。

## 未验证
- 真机侧（G1 各宽度截图、G2 文字缩放、F6 实测耗时）属 pi-D，本轮未做。
