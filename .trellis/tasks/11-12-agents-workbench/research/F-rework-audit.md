# 审计 F：验收反馈对应的根因

日期：2026-11-14。依据：用户验收反馈、代码、四个 Pi 的 status 文件。

## 结论

- 反馈的每一条都能在代码里找到原因。
- 三条是设计错误：导航三层、编辑器出现多处、模型选择被隐藏。
- 两条是实现缺陷：发送后无反馈、会话加载慢。
- 一条是流程缺失：没有做交叉检查，也没有做实机检查。

## 对照表

| # | 用户看到的 | 根因 | 证据 |
|---|---|---|---|
| 1 | 项目打开是列表，发送后跳第二页，还有第三层 | design.md §3 把导航定成三层。pi-A 把主页改成 `openProjectPage` | `lib/shell/project_entry.dart:20,139,150`。主页入口已还原 |
| 2 | 没有在原编辑器里改，另开了页面 | 工作台里嵌的是 `EditorPage` 的第二个实例。项目页的「编辑器」入口又走 `openEditorPage`，是第三处 | `workbench_shell.dart:297`、`project_entry.dart:128`、pi-A status「真正的三栏嵌入需要改 editor/」 |
| 3 | 发送后没有反馈，没有进度 | `_bootstrap` 串行等模型列表和技能列表，超时 90 秒，之后才打开会话并发送草稿。等待时界面写「还没有会话」 | `workbench_agent_pane.dart:95-114`、`api_client.dart:1228` |
| 4 | 底部没有模型选择 | 模型列表为空时，整个选择器被隐藏 | `composer_card.dart:367` |
| 5 | 会话加载很慢 | 启动解析全部会话文件。打开时整文件解析。每轮整文件重写 | `agent_session.dart:108-132,194-209,222-239` |
| 6 | 到底有没有检查 | 没有。`check/` 目录为空。三个 status 都写「真机、桌面观感未验证」。16 个测试失败没修 | `status/pi-A.md`、`pi-B.md`、`pi-C.md` |
| 7 | 后端要配 API 和 KEY | 转接模式下，服务端缺 `QFLI_AI_BASE_URL` 或 `QFLI_AI_API_KEY` 就返回 503「AI 服务未配置」 | `azurekiln-qfli-server/src/ai-client.js:44-49` |

## 过程缺陷

- 大脑把 R2 按字面实现成一个独立的项目页，没有回头问「用户要的是不是原编辑器页加 agent」。
- 阶段 2 集成没有完成，阶段 3 交叉检查没有开始，就向用户交付。
- 验收口径只有 `flutter analyze` 和 widget 测试。没有任何人在真机或桌面上看过界面。

## 已做的纠正

- 主页入口还原为 `openEditorPage`。`home_page.dart` 与 `HEAD` 一致。
- `retained_editor_test.dart` 里 pi-A 加的导航步骤已撤销。该文件与 `HEAD` 一致。
- 修改前的未提交文件已备份：`D:\MyNewProjects\_backups\workbench-rework-20261114-025148\`。
