# pi-C 第四轮返工状态

分支 `rework/pi-c`，worktree `D:\MyNewProjects\_wt\pi-c\qfli_studio_core`。
提交：`1d942c3 feat(chat): explain failures and fit the tool row by real width`。

## 已完成

1. 第一步：在自己的 worktree 跑 `git merge --ff-only rework/integration`，快进成功（`7e9f618` → `318e443`），合并前 worktree 干净。
2. 错误卡片标题改用 `lastError` 的友好文案（现在带主机和步骤）；`host` 为空时沿用原分类文案，H2/H3/H4 旧断言不变。
3. 「详情」里的 `detail` 用等宽字体、可选中；状态码单独一行。
4. 详情加「复制」按钮：写 `detail` 加一行「复制于 <yyyy-MM-dd HH:mm:ss +08:00>」，按钮回执改「已复制」。
5. `phase` 是 dns/connect/tls/timeout 时显示「诊断连接」；http/response/other 不显示。只在点击时调 `runtime.diagnoseConnection()`，运行中转圈，结果追加在详情下面，可重复诊断。没有自动诊断。
6. 诊断抛异常时写一句本地提示，不冒泡到界面。
7. `WorkbenchAgentPane` 把 `widget.runtime.diagnoseConnection` 传给 `ChatTranscript.onDiagnose`；`ChatTranscript` 新参数有默认值，原有参数未改名。
8. `FakeAgentFacade` 加 `seedError(...)`（message、kind、statusCode、host、phase、detail，一次通知落到 failed）；`FakeAgentRuntime` 加 `diagnoseGate` 以便观察转圈。
9. 追加要求：`composer_card.dart` 工具行改按 `LayoutBuilder` 实测可用宽度判档，文字宽度用 `TextPainter`（含字体缩放），收缩顺序为推理强度、权限，模型名最后；剩余宽度全给模型按钮，模型与发送键之间不再留空档。
10. 修掉 8.4 px 溢出：`_fitFor` 把模型下界（84）算进判档，`modelWidth` 取剩余宽度，不再用 `math.max` 硬顶。
11. 测试：
    - `chat_transcript_test.dart`：多行详情含主机与步骤、无 host 回退、复制写剪贴板（`SystemChannels.platform` mock）、tls 有诊断而 http 没有、点一次调一次并显示结果、诊断失败不冒泡、390 宽 1.3 倍不溢出。
    - `workbench_agent_pane_test.dart`：H6 带主机文案加诊断走真实运行时入口。
    - `chat_composer_card_test.dart`：424 宽显示「每次询问」且末尾无空档、408 宽同样显示、360 宽不溢出、1.3 倍不溢出、放不下时收文字顺序正确。
12. 检查结果：
    - `flutter analyze --no-pub`：No issues found。
    - `flutter test --no-pub --concurrency=2`：1637 通过、9 跳过、4 失败，失败恰为允许项（`editor_run_target_test` 3 项、`interop_arkts_contract_test` 1 项）。
    - 提交后 `git status -s` 干净。

## 进行中

无。

## 请求

无。若大脑认为 424 宽应同时显示推理强度文字，需要调整 `_toolFitSlack` 或模型下界，属于跨 owner 的观感取舍，等大脑定。

## 未验证

1. 真机 424 逻辑宽截图复核（`_fitFor` 在真机字体下的取值）——当前只有 widget 测试，真机证据由 pi-D 采集。
2. 真机上「诊断连接」对着 `qfli.suanxiwanjie.cn` 的 TLS 握手断开的实际输出（依赖 pi-B 的 `diagnoseConnection` 落地）。
3. `interop_arkts_contract_test` 1 项（worktree 同级缺完整 `qfli_java`，环境问题，未处理）。