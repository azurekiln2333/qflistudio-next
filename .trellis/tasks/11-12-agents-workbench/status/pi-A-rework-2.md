# pi-A 第二轮：开关、侧边栏分段、单一 AI 入口

worktree `D:\MyNewProjects\_wt\pi-a\qfli_studio_core`，分支 `rework/pi-a`，本轮 1 个提交。
`flutter analyze --no-pub`：无问题。

## 已完成

- `EditorPage` 新增 `agentEnabled`，默认 `false`。关闭时与基线一致：没有 agent 入口、
  没有分段、没有右栏，菜单「AI 助手」仍打开旧 `AiPanel`。
- 开启由宿主决定：`retained_editor_host.dart` 两处构造 `EditorPage` 都传
  `agentEnabled: StudioProfile.current?.offlineOnly != true`。`home_page.dart` 未动。
- 开启时菜单「AI 助手」直接开 Agent 面板，旧 `AiPanel` 不再显示；删掉单独的
  「Agent 面板」菜单项，应用内只剩一个 AI 入口。
- 「文件 | 会话」分段移到侧边栏顶部、文件树卡片之上；删掉顶栏的替代分段。
  顶栏保留 agent 图标按钮与角标。抽屉里的分段不变（同一个组件）。
- 未激活时也显示「会话」分段，点它才解析运行时（保持懒加载）。
- 页内切换项目的回退分支也传 `agentEnabled`。

### 验证

| 项 | 结果 | 证据 |
|---|---|---|
| 旧测试全跑 | 通过 | 1515 通过；仅 3 个 `editor_run_target`（允许）与 1 个 `interop_arkts_contract_test` 加载失败（见「请求」） |
| `editor_pad_layout_test` | 通过 | 未改一行；它直接构造 `EditorPage`，走关闭分支 |
| `main_editor_short_height_test` | 通过 | 未改一行；同上 |
| 开关关闭 | 通过 | 「关闭：无 agent 控件，「AI 助手」仍开旧面板」：四个 agent key 全无，菜单后 `AiPanel` 出现 |
| 开关开启 | 通过 | 「开启：分段在侧边栏顶部，「AI 助手」开 Agent 面板」：分段底边 ≤ 文件树顶边、左边 < 300，菜单后 `editor-agent-pane` 出现且 `AiPanel` 为 0 |
| 旧测试未改 | 通过 | `git diff wip/baseline-20261114 --name-status -- test` 只有新增本文件与 §11.3 授权的两个删除 |

## 进行中

- 无。
- 阶段 2 交叉检查（检查 pi-D）已完成：报告 `TASK\check\pi-A-checks-pi-D.md`，
  阶段 2 状态 `TASK\status\pi-A-check.md`。本轮实现未变。

## 请求

1. `interop_arkts_contract_test` 仍加载失败。`qflistudio` 链接已生效，但它还读
   `../qfli_java/ohos/entry/src/main/ets/interop/InteropReceiver.ets`，而
   `_wt/pi-a/qfli_java` 里只有 `.trellis`，没有该文件（主目录 `D:\MyNewProjects\qfli_java`
   里有）。请给 `qfli_java` 也加目录链接，或确认该测试在本轮可忽略。
2. 宽屏侧边栏默认收起（`_explorerVisible ?? false`，基线行为，未改）。因此分段在
   侧边栏展开后才可见；顶栏 agent 图标是默认可见的入口。若要求分段默认可见，
   需要改基线的侧边栏默认状态，请裁决。

## 未验证

- 真机（鸿蒙）：G1 各宽度截图、G2 文字缩放 1.3、F6 实测耗时，均未做。
- 与 pi-B 的并行会话注册表联调：本分支基线里 `statusOf`/`liveFacade` 仍是占位。
