# pi-C 阶段 2 状态：交叉检查 pi-B

角色：检查人（阶段 2）。检查对象 pi-B（会话存储、并行运行时、调度、租约、性能）。
报告：`check/pi-C-checks-pi-B.md`。worktree `D:\MyNewProjects\_wt\check-c\qfli_studio_core`（`check/pi-c`，内容 `rework/integration` a43b7df）。

## 已完成

- 读完 `RULES-rework.md`、`CHECKLIST.md`、`briefs/phase2-check.md`。
- 重点项全部有证据：E1、E4、E5、E6、E7、F1、F2、F3、F4、H3（共 10 项）。
- 环境：`flutter analyze --no-pub` 无问题；全量 `flutter test --no-pub --concurrency=1`
  `+1604 ~9 -4`，失败仅 `editor_run_target_test` 3 例（允许）+ `interop_arkts_contract_test` 1 例（已知忽略）。
- I1-I4 全查：I1 无密钥（lib/test/tool 与 status/check 文档均无匹配）；I3 `rework/pi-b` reflog 只有 6 个 commit
  加一次 baseline 快进，无禁止操作；I4 提交信息无 AI 署名。I2 见「未验证」。
- 4 个自设破坏性场景（临时文件 `tool/pi_c_scenarios_test.dart`，跑完删除、未 git add）：
  S1 三方并发上限 2 → `[running, queued, running]`，通过。S2 持租约时 `cancelAll` 后另一会话能写，通过。
  S3 崩溃半行重开只丢最后一行，通过。S4 大小写变体 `a.txt`/`A.TXT` → 双双放行，失败（即 E4）。
  S5 用真实 runtime 端到端坐实 E4：甲持 `a.txt` 租约，乙写 `A.TXT` 返回「已创建 A.TXT」，
  `a.txt` 被覆盖为乙的正文，失败。
- 未改 `lib/`、`test/`；worktree 干净，无提交。

## 进行中

- 无。

## 请求

- pi-B：修 E4。`ProjectWriteLeases._keyOf`（`lib/vibe_coding/project_write_leases.dart:87-96`）
  只 `p.normalize` 和把 `\` 换成 `/`，不做大小写折叠。Windows / macOS 上 `a.txt` 与 `A.TXT` 是同一文件，
  却得到两个租约键，第二个会话直接放行，可覆盖先写的内容。建议按平台 `toLowerCase()`，并补一条大小写等价单测。
- 大脑：关卡 2 核 I2 归因。主目录 HEAD 与备份一致（`573d1b6`），但脏文件集合自备份后变了：
  我这边少了两项改动（`lib/pages/home_page.dart`、`test/retained_editor_test.dart`，是删改、不是新增）。
  pi-A 独立记录同一时段主目录被写过 4 个文件（含这两项），结论「无法归因到具体 pi」与我的判断一致。
  因此 I2 的事实成立（主目录被写），但无证据指向 pi-B。

## 未验证

- I2 已确认「主目录被写」这件事（我与 pi-A 两方独立取证一致），但无法归因到 pi-B；
  其中 `lib/pages/home_page.dart` 正是 B1 要守的文件，建议大脑在关卡 2 优先确认它的当前内容。
- F1 的「旧实现」是基准脚本内联重写的等价模拟，不是直接跑基线旧类；数字量级可信，严格说非同类对跑。
- 真机未验（并发、429、限流窗口、租约跨平台大小写与符号链接）。
