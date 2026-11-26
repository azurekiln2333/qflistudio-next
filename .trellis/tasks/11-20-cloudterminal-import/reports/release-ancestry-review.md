# 发布基线与兼容审计

审计日期：2026-11-20。

本次只读检查了源码、Git 历史和既有日志。
本次没有运行测试或构建。
本次没有启动设备、模拟器或虚拟机。
本次只新增本报告。
原始 `D:/MyNewProjects/cloudterminal` 未修改。

## 结论

发布基线应使用远端 `main`。
旧集成分支已落后，不能作为发布起点。
thinking 历史跨端切换存在请求兼容缺口。
现有 5 项失败清单也需更新。
尚无最终合并树的云端验证证据。

## 1. 发布基线

2026-11-20 使用 `git ls-remote github refs/heads/main` 检查。

| 仓库 | 远端 main |
| --- | --- |
| qflistudio | `b7272bc3a81482a9f84be08b2273d0b603ec9870` |
| qfli_studio_core | `cbaa4a4166461baafff7c1a343bd3ca1865fcc4f` |
| azurekiln-qfli-server | `d919a91990615f17310391d0e84ba0cdb77c8ffa` |

两个 Flutter 仓库的远端 `main` 等于本地 `r5/integration`。
以下工作树干净，可供后续整合参考。

- App：`D:/MyNewProjects/_wt/round5/int/qflistudio`。
- Core：`D:/MyNewProjects/_wt/round5/int/qfli_studio_core`。

旧基线与当前远端存在这些差距。

| 本地基线 | 提交 | 落后远端 main |
| --- | --- | --- |
| App 根目录 main | `e018db9` | 42 个提交 |
| Core 根目录 main | `573d1b6` | 108 个提交 |
| Core rework/integration | `b7f3d40` | 51 个提交 |
| App ci/app-installers | `4f8d97d` | 30 个提交 |

App 根目录的忽略文件 `pubspec_overrides.yaml` 指向旧 Core。
该 Core 位于 `D:/MyNewProjects/_wt/integration/qfli_studio_core`。
该 Core 当前提交为 `b7f3d40`。
根目录能启动或构建，不代表它使用最新 Core。

## 2. 已进入 main 的工作

Core 当前基线已包含这些功能。

- 首页 FAB、项目标签顺序和折叠搜索。
- 合并后的教程与示例入口。
- Netrix 工具集合及 52 个工具。
- OHOS 平台枚举兼容层。
- QFLIStudioN 品牌名。
- Agent 文件备份、修改事件和文件卡片。
- 编辑器文件重载。
- 侧栏对齐和 Android 底部边距。
- 编辑器快捷栏及最终 25 dp 高度。

App 当前基线已包含这些工作。

- 多平台安装包 CI。
- 品牌名与应用标识更新。
- OHOS 后台互操作与快捷登录。
- 平台兼容保护。
- CNB 流水线。
- `5.0.4+5000004` 版本。

仓库已有 `v5.0.1` 至 `v5.0.4` 标签。
不要重复合并旧功能分支。

## 3. 建议整合顺序

1. 从 Core `cbaa4a4` 建立干净整合分支。
2. 合并 `thinking/contract`：`9a7cf78`。
3. 合并 `thinking/transport`：`05c7eb0`。
4. 合并 `thinking/loop`：`f38db12`。
5. 合并 `thinking/ui`：`bac2405`。
6. 合入审查后的 CloudTerminal Core 修改。
7. 从 App `b7272bc` 合入迁移修改。
8. 在构建中锁定最终 Core 提交。
9. 将 App 版本提升到 `5.0.4` 之后。
10. 同步 pubspec 与安装包工作流版本。

transport、loop、ui 都包含 contract。
三者在 contract 之外没有相互重叠的文件修改。

只读合并检查发现 3 处冲突块。
冲突都位于 `lib/chat/chat_transcript.dart`。

| 位置 | r5 参数 | thinking 参数 | 处理 |
| --- | --- | --- | --- |
| ChatMessageTile 调用 | onOpenFile、fileExists | liveText | 保留三者 |
| ChatMessageTile 构造 | onOpenFile、fileExists | liveText | 保留三者 |
| ChatMessageTile 字段 | 文件操作回调 | ValueListenable liveText | 保留三者 |

以下文件虽可自动合并，仍需检查数据流。

- `lib/vibe_coding/vibe_agent_facade.dart`。
- `lib/editor/ai_panel.dart`。
- `lib/shell/workbench_agent_pane.dart`。

CloudTerminal Core 修改基于 `b7f3d40`。
主要新增 `lib/remote_control/` 和 `vendor/xterm/`。
合并 pubspec 时保留最新依赖。
其中包括 `crypto: ^3.0.6`。
其中还包括 `web_socket_channel: ^3.0.3`。
保留 QFLIStudioN 描述。

CloudTerminal App 修改基于 `e018db9`。
主要新增 `lib/studio_tools_tab.dart` 和 `companion/`。
`lib/main.dart` 增加工具入口构造器。
合并时保留最新 OHOS 后台运行器。
App 必须保留 xterm 路径覆盖。
依赖包的 dependency_overrides 不会向上传递。
最新 ToolsGrid 已包装 ToolsBrowser。
新工具入口必须继续包含已迁入的 Netrix 工具。

## 4. thinking 中转历史兼容缺口

服务端 `thinking/server` 当前为 `81515f4`。
它比服务端 main 多 2 个提交。
`afbbf33` 提取 NDJSON 写入器。
`81515f4` 增加 AI 流式中转。
远端 main 仍为 `d919a91`。
没有证据证明生产环境已部署 thinking/server。

客户端会保留思考历史字段。
`vibe_coding_controller.dart:1867` 的 `_carryReasoning` 写入字段。
`vibe_coding_controller.dart:1905` 的 `_sanitizeHistory` 保留字段。
两个字段分别是 `reasoning_content` 和 `reasoning_blocks`。

`api_client.dart:1639` 的 `aiChat` 原样发送 messages。
`api_client.dart:1914` 的流式中转也原样发送 messages。
流式接口返回 404 或 405 时，客户端调用 `aiChat`。
该回退仍传入同一份历史。

服务端白名单与历史字段不一致。

| 接口版本 | reasoning_content | reasoning_blocks |
| --- | --- | --- |
| main 的旧中转 | 拒绝 | 拒绝 |
| thinking/server 的新中转 | 接受 assistant 字符串 | 拒绝 |

旧服务端的消息字段仅有以下四项。
`role`、`content`、`tool_calls`、`tool_call_id`。
新服务端只额外接受 `reasoning_content`。
`src/ai-client.js` 的 `onlyKeys` 会拒绝其他字段。

因此存在两种确定的失败路径。

1. 恢复带思考字段的历史后切到旧中转。
   流式接口回退后，旧接口返回 400。
2. 把带 `reasoning_blocks` 的历史发往新中转。
   新接口也返回 400。

全新的普通旧中转会话仍可工作。
旧中转本身不会产生这些思考字段。
不能据此声称全部历史都向后兼容。

### 最小修复建议

最小生产代码修改可集中在一个文件。
文件是 `lib/services/api_client.dart`。
新增私有的中转消息投影函数。
投影函数建立新 Map，保留原始历史。

| 请求路径 | 投影规则 |
| --- | --- |
| 新流式中转 | 保留四个旧字段及 reasoning_content |
| 404/405 后的旧接口回退 | 只保留四个旧字段 |
| 普通 aiChat 中转 | 默认使用旧接口字段集合 |
| direct 协议请求 | 继续使用现有协议适配器 |

所有中转请求都删除 `reasoning_blocks`。
旧接口回退同时删除 `reasoning_content`。
保持持久化历史和直连历史完整。
不要用任意 400 响应触发重复调用。

普通 `aiChat` 可先使用保守投影。
这会省略新中转的非流式思考重传。
若要保留该能力，需先明确服务端能力。
能力选择可控制是否发送 `reasoning_content`。

### 已有覆盖与缺口

`test/ai_chat_stream_relay_test.dart` 已覆盖以下行为。

- NDJSON 事件与最终结果。
- 流内错误与非 200 响应。
- 404、405 回退。
- 取消、空闲超时和提前断流。

其中 404/405 用例只发送普通用户消息。
Mock 返回思考响应，但不检查历史白名单。
因此该用例不能发现旧中转兼容缺口。

`test/ai_stream_protocol_test.dart` 覆盖直连协议。
它检查 Chat 的 reasoning_content 重传。
它检查 Messages 的思考块与签名重传。
它检查 Responses 不重传思考内容。
这些用例不证明中转兼容。

`test/vibe_thinking_stream_test.dart` 覆盖历史保留。
它检查思考字段写入和恢复清洗。
它也覆盖取消、重试和历史限额。
这些断言应继续保留。

修复后需补充以下云端测试。

- 严格旧接口接收 404/405 回退历史。
- 新流式中转删除 reasoning_blocks。
- 新流式中转保留 reasoning_content。
- 普通 aiChat 使用约定的消息投影。
- 发起请求后原始历史保持完整。
- 400 响应不会触发重复回合。

## 5. 最新 main 的测试范围

Core `cbaa4a4` 包含 180 个 `*_test.dart` 文件。
它比 `b7f3d40` 修改了 63 个测试或测试辅助文件。
测试范围包括聊天、编辑器、工具和互操作。
还包括备份、工作区、项目与平台保护。

新增功能已有对应测试。

| 功能 | 示例测试文件 |
| --- | --- |
| Agent 写入与备份 | agent_write_backup_test.dart |
| 编辑器同步与文件卡片 | editor_agent_file_sync_test.dart、agent_file_card_test.dart |
| Agent 导航与快捷栏 | editor_agent_navigation_test.dart、editor_agent_quick_bar_sync_test.dart |
| Android 底部边距 | editor_bottom_inset_test.dart |
| 快捷栏高度与交互 | editor_quick_bar_test.dart |
| Netrix 工具 | netrix_tools_contract_test.dart、ported_tools_test.dart |
| 首页与教程 | home_project_tabs_widget_test.dart、tutorial_center_page_test.dart |

现有测试日志必须按平台和提交解读。

| 证据 | 已记录结果 | 限制 |
| --- | --- | --- |
| round5/reports/integration.md | 0b2519c 全量：1987 通过、26 跳过、1 失败 | Windows 工作树，非最终 main |
| round5/reports/logs/int-full-suite-final.log | 1987 通过、26 跳过、1 失败 | 日志未自带精确提交 |
| round5/reports/pi3.md | cbaa4a4 静态分析无问题 | 报告记录，不是本次运行 |
| 同上 | 快捷栏 14、截图 10、编辑器 50、其他 81 通过 | 定向测试，非全量 |

最终全量日志产出于 2026-11-19 04:50:52。
唯一失败为 ArkTS 契约测试的加载错误。
后续 `cbaa4a4` 又修改了快捷栏及测试。
不能把旧全量结果称为最新 main 的云端全量结果。

Core main 当前没有 `.github` 工作流。
thinking/contract 新增 `core-check.yml`。
该工作流运行 analyze 和全量 Flutter 测试。
它使用 5 项已知失败清单放行历史失败。

App 的安装包流水线主要验证构建产物。
它不能替代 Core 全量测试。
App CNB 工作流包含 Flutter 检查任务。
该任务配置 `allowFailure: true`。
该任务克隆 Core 默认分支，未锁定提交。
该任务未准备 Java 并列仓库。
因此它当前不构成严格发布门禁。

thinking 分支已有历史云端成功记录。

| 分支 | 提交 | 运行号 |
| --- | --- | --- |
| thinking/server | 81515f4 | 44514768687 |
| thinking/transport | 05c7eb0 | 44544252714 |
| thinking/loop | f38db12 | 44549435514 |
| thinking/ui | bac2405 | 44523275868 |

服务端运行跳过了 image 任务。
这些成功记录也不能证明最终合并树通过。

## 6. 五个历史失败的现状

清单位于 thinking/contract 的 `.github/known-test-failures.txt`。
其基线是 `b7f3d40`。

| 旧失败 | 当前判断 | 证据 |
| --- | --- | --- |
| interop_arkts_contract_test 加载失败 | 仍存在环境前提 | round5 最终日志仍失败 |
| absolute attachment shows its tail | Linux 原因仍在 | 当前实现仍用宿主 p.isAbsolute |
| a missing sibling app keeps the original path | 旧用例已替换 | 3cbd918 重写测试 |
| an installed sibling app takes the run tap | 旧用例已替换 | 当前改为无 probe 直启 |
| an unknown probe keeps the original path | 旧行为已删除 | 当前不再先 probe |

### ArkTS 加载失败

`interop_arkts_contract_test.dart` 读取并列仓库源码。
它从 `Directory.current.parent` 拼接路径。
测试依赖 `qflistudio`、`qfli_studio_core` 和 `qfli_java`。
Core 单仓库 CI 缺少这些目录。
round5 的 App/Core 双仓库仍缺 Java。
补齐目录后还需验证契约内容。
目前不能认定契约断言全部通过。

### 附件路径失败

测试使用 Windows 路径 `D:/work/other/src/Util.java`。
当前 `composer_card.dart:311` 仍调用 `p.isAbsolute(path)`。
该调用使用宿主平台的路径规则。
Linux 不会把该盘符路径识别为绝对路径。
标签因此保留整段路径。

历史云端日志明确记录了这个失败。
日志为 `thinking/reports/ci-contract-full.log:1339`。
其期望标签为 `src/Util.java`。
实际没有找到该标签。
从基线到当前 main，标签函数没有修改。
`5843ad8` 只修复工具行宽度溢出。
它没有修复路径识别。

若产品支持跨平台恢复附件路径，应识别两类路径。
可显式使用 Windows 与 POSIX 路径规则。
相对路径仍显示原值。
补充盘符、UNC、POSIX 与相对路径用例。
如果只接受本机路径，则需明确该产品约束。
仅替换测试输入会掩盖跨平台恢复问题。

### 三个运行目标失败

`3cbd918` 改为直接启动目标应用。
当前测试覆盖以下行为。

- 已安装应用接收运行请求，且不先 probe。
- 应用缺失时回退，并记住缺失状态。
- 其他启动失败只显示错误，不重复运行。
- 无对应应用时使用本地运行路径。

旧的三个测试名已不存在。
应删除清单中的三个旧条目。
不应把用例消失称为旧用例已通过。
新用例仍需在最终合并树的 Linux CI 验证。

### 失败清单比较器的问题

`check_test_results.py` 计算 `known - failed`。
它将全部差集标成 `known failure now passes`。
该算法没有检查用例是否运行。
比较器也会将消失的用例标成通过。
它也不要求全量运行出现正常结束事件。

建议区分成功、失败、缺失和跳过。
CI 应检查测试进程退出码和结束事件。
旧失败清单不能替代完整运行证明。

## 7. 发布签名与根目录风险

当前 GitHub Android 安装包使用调试签名。
工作流也明确验证 Android Debug 证书。
该 APK 可以安装。
它不能覆盖由不同生产证书签名的应用。

OHOS HAP 和 iOS IPA 未签名。
它们需要签名后才能安装。
Windows 与 macOS 产物也未签名。

CNB release-apk 要求生产签名密钥。
该任务拒绝调试签名产物。
但 main 的 Android Gradle 仍指定 debug 签名。
因此当前配置无法满足该签名检查。
应明确实现签名配置后再验证发布任务。

根目录包含未提交修改。
不要把根目录差异整体纳入整合分支。
App 根目录还显示 77 项嵌套服务端文件删除。
这些删除不属于本次迁移交付。

以下根目录文件与已发布 r5 内容不同。

- `android/.gitignore`。
- `android/app/build.gradle.kts`。
- `lib/main.dart`。
- `ohos/build-profile.json5`。
- `pubspec.lock`。

OHOS 构建配置包含本地签名材料引用。
不要复制其密码、证书或 profile 值。
Android 根目录还存在未提交的签名逻辑。
该逻辑依赖忽略文件与环境变量。
应审查后单独实现所需行为。
Core 根目录脏修改大多重复历史工作。
本次整合应排除该脏工作树。

## 8. 后续验证范围

先修复中转消息投影和 CI 失败清单。
再为最终 App/Core 提交建立云端检查。
构建任务必须记录两个精确提交。
ArkTS 检查必须固定并列仓库版本。
最终验证包括全量测试、合并交互和发布签名。
本次没有运行这些验证。

## 证据路径

- `D:/MyNewProjects/_wt/round5/reports/integration.md`。
- `D:/MyNewProjects/_wt/round5/reports/pi1.md`。
- `D:/MyNewProjects/_wt/round5/reports/pi3.md`。
- `D:/MyNewProjects/_wt/round5/reports/logs/int-full-suite-final.log`。
- `D:/MyNewProjects/_wt/thinking/reports/ci-contract-full.log`。
- `D:/MyNewProjects/_wt/thinking/reports/ci-a.txt`。
- `D:/MyNewProjects/_wt/thinking/reports/ci-b.txt`。
- `D:/MyNewProjects/_wt/thinking/reports/ci-c.txt`。
- `D:/MyNewProjects/_wt/thinking/reports/ci-d.txt`。
- `D:/MyNewProjects/_wt/thinking/pi-b/qfli_studio_core/lib/services/api_client.dart`。
- `D:/MyNewProjects/_wt/thinking/pi-c/qfli_studio_core/lib/vibe_coding/vibe_coding_controller.dart`。
- `D:/MyNewProjects/_wt/thinking/server/azurekiln-qfli-server/src/ai-client.js`。
