# 阶段 2：交叉检查

先读 `RULES-rework.md` 和 `CHECKLIST.md`。

## 你的位置

- 你检查别人的成果。你不改 `lib/`、`test/`。只写报告。
- `tool/` 下只允许新增未跟踪的临时文件，用来出截图。不要 `git add`，不要提交。
- 你在自己的检查 worktree 里工作：`D:\MyNewProjects\_wt\check-X\qfli_studio_core`。分支 `check/pi-X`，内容是集成分支 `rework/integration`。
- 报告写到 `TASK\check\pi-X-checks-pi-Y.md`。

## 分工

| 检查人 | 检查对象 | 重点项 |
|---|---|---|
| pi-B | pi-A | A1-A5、B1-B7、E2、E3、F5、G8、G9 |
| pi-C | pi-B | E1、E4-E7、F1-F4、H3 |
| pi-D | pi-C | C1-C6、D1-D6、G2-G7、H1-H5 |
| pi-A | pi-D | 服务端 README 与 `.env.example`、真机脚本、预览工具、`research/G-agent-isolation.md`、I1 |

所有人额外做：

1. 运行 `flutter analyze --no-pub` 和 `flutter test --no-pub`。记录汇总行。
2. 运行 CHECKLIST 的 I1-I4。
3. 试着弄坏它。每个检查人至少写出 3 个自己设计的破坏性场景，并给出结果。

## 方法

- 先读对象的 diff：`git diff wip/baseline-20261114..rework/integration -- <对象的范围>`。
- 每一项都要有证据。没有证据算不通过。
- 能用测试证明的，写一个临时测试放在 `_scratch\pi-X\`，运行，把输出贴进报告。不要把临时测试放进仓库。
- 不确定的项写「未验证」，写清原因。

## 报告格式（不超过 120 行）

```
# pi-X 检查 pi-Y

## 汇总
通过 N 项。不通过 M 项。未验证 K 项。

## 结果
| ID | 结果 | 证据 |
|---|---|---|

## 不通过项
- ID：现象。原因。负责人。建议改法。

## 我设计的破坏性场景
1. 场景。结果。

## 额外发现
```

## 完成

最后一条回复只写一行：`DONE <报告路径>` 或 `BLOCKED <原因>`。

## pi-D 的额外任务：集成后的编辑器截图

大脑要用这些截图做 UI/UX 检查。这是你的重点交付。

1. 在你的检查 worktree 的 `tool\` 下新增 `agent_editor_scenes_test.dart`（未跟踪，不提交）。用 `agent_preview_test.dart` 的导出能力。
2. 场景构造：`EditorPage(agentEnabled: true, agentRuntime: FakeAgentRuntime(...))`，用 `FakeAgentFacade` 造不同状态。参考 `test\editor_agent_embed_test.dart` 的写法。
3. 场景：
   - 空会话。
   - 运行中：用户消息加进度条加状态行。
   - 失败：503 未配置、网络不可用，各一张。
   - 长对话：含工具条目和写确认卡片。
   - 会话列表：含运行中、排队、待确认、失败、已完成未读五种状态。
   - 窄屏抽屉打开，显示「文件 | 会话」。
4. 尺寸：390×844、900×700、1280×800。主题：浅色和深色。
5. 输出到 `TASK\check\screens\integration\`。文件名写明场景、尺寸、主题。
6. 在报告里列出每张图看到了什么，和你认为不对的地方。
