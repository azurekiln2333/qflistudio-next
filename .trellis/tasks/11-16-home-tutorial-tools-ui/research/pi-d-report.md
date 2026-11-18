# Pi D 报告：netrix 工具清单与第 2 批

日期：2026-11-16
工作目录：`D:\MyNewProjects\_wt\ui-d`（`qflistudio` + `qfli_studio_core`，分支 `ui/pi-d`）
基线：主程序 `d26cffc`，内核 `573d1b6`

## 0. 一句话结论

清单已交付（52 个工具，三批划分完毕，每个工具恰好属于一批）。
第 2 批 27 个工具的逻辑层、默认值、结果行、错误键已 1:1 移植。
测试覆盖这 27 个工具。
**工具页接入未完成**（沿注册表挂上工具页、显示密度、只在主程序显示），
原因是 `research/tools-port-contract.md` 与 Pi C 的骨架提交在整个 20 分钟等待窗口内都没有出现
（见第 9 节）。这不是「已完成」，请大脑按第 10 节继续派发。

## 1. 提交列表

### 内核仓库 `qfli_studio_core`（分支 `ui/pi-d`）

| 哈希 | 标题 |
|---|---|
| `4b0a9a3` | `feat(tools): add netrix tool models and address helpers for the port` |
| `5bbce43` | `feat(tools): add the netrix network service and the websocket dependency` |
| `a253b2c` | `feat(tools): port the netrix address and subnet toolset` |
| `6c6628d` | `feat(tools): port the netrix network toolset` |
| `adde4be` | `test(tools): cover the ported netrix batch 2 toolbox` |
| `2a7b3f9` | `feat(tools): register the netrix batch 2 tool list` |
| `a92a812` | `feat(tools): render netrix batch 2 errors with the netrix sentences` |
| `26f674f` | `build(core): require web_socket_channel 3 so the web package is not downgraded` |

### 主程序仓库 `qflistudio`

无提交。第 2 批不需要改主程序文件（见清单第 9 节）。
工作区里只有 `flutter pub get` 生成的平台注册文件与 `pubspec.lock` 变化，未提交：

```
 M linux/flutter/generated_plugin_registrant.cc
 M linux/flutter/generated_plugin_registrant.h
 M linux/flutter/generated_plugins.cmake
 M macos/Flutter/GeneratedPluginRegistrant.swift
 M pubspec.lock
 M windows/flutter/generated_plugin_registrant.cc
 M windows/flutter/generated_plugin_registrant.h
 M windows/flutter/generated_plugins.cmake
```

`git status --short -- lib test pubspec.yaml` 为空：主程序源码和 `pubspec.yaml` 一个字没改。

## 2. 改动文件

内核 `lib/tools/netrix/batch2/`（新增，7 个文件）：

| 文件 | 行数 | netrix 对应源 |
|---|---|---|
| `batch2_models.dart` | 233 | `lib/core/models.dart`（198 行，只加 `Netrix` 前缀） |
| `batch2_address_service.dart` | 395 | `lib/core/services/address_service.dart`（209）+ `advanced_service.dart` 里的 IPv4 / 掩码 / 端口范围函数 |
| `batch2_network_service.dart` | 695 | `lib/core/services/network_service.dart`（612） |
| `batch2_address_tools.dart` | 375 | `registry.dart` 里 13 个地址工具的条目 + 运行函数 |
| `batch2_network_tools.dart` | 543 | `registry.dart` 里 14 个网络工具的条目 + 运行函数 |
| `netrix_batch2_tools.dart` | 49 | 新增：本批注册清单（契约缺位时的过渡方案） |
| `batch2_error_text.dart` | 115 | `lib/core/localization.dart` 的 `errorMessage`（658 行中本批用到的那部分） |

内核 `test/tools/netrix/`（新增，5 个文件）：`batch2_address_service_test.dart`（91）、
`batch2_network_service_test.dart`（84）、`batch2_tools_test.dart`（262）、
`batch2_registration_test.dart`（40）、`batch2_error_text_test.dart`（64）。

内核 `pubspec.yaml`：`dependencies` 末尾追加一行 `web_socket_channel: ^3.0.3`。
内核 `pubspec.lock`：随之变化（见第 7 节）。

黑板目录（不在 git 仓库内）：`research/netrix-tools-inventory.md`、
`research/pi-d-contract-questions.md`、`research/pi-d-report.md`，以及子任务 `design.md` 的「Pi 补充」。

## 3. `flutter analyze` 与 `flutter test` 输出

### 内核 `qfli_studio_core`

```
$ flutter analyze
Analyzing qfli_studio_core...
No issues found! (ran in 8.6s)
```

```
$ flutter test --concurrency=1
01:40 +498 ~5 -1: loading .../test/interop_arkts_contract_test.dart [E]
04:04 +1387 ~9 -1: Some tests failed.
```

唯一失败项是 `test/interop_arkts_contract_test.dart`，**基线就失败，与本批无关**：
它读取 `D:\MyNewProjects\_wt\ui-d\qfli_java\ohos\entry\src\main\ets\interop\InteropReceiver.ets`，
而 worktree 配对只有 `qflistudio` 和 `qfli_studio_core`，没有 `qfli_java`：

```
Failed to load ".../test/interop_arkts_contract_test.dart": Bad state: missing
D:\MyNewProjects\_wt\ui-d\qfli_java\ohos\entry\src\main\ets\interop\InteropReceiver.ets
  test\interop_arkts_contract_test.dart 21:7   main.read
```

1387 通过、9 跳过、1 个加载失败。

另有一次不加 `--concurrency=1` 的全量运行里，`workspace_dialog_layout_test.dart` 失败。
单独运行该文件 5/5 通过。与 `test/tools` 一起串行运行也通过。
这是并行调度下的既有抖动，不是本批引入。

本批自己的测试：

```
$ flutter test test/tools
00:01 +31: All tests passed!
```

### 主程序 `qflistudio`

```
$ flutter analyze
Analyzing qflistudio...
No issues found! (ran in 2.9s)

$ flutter test
00:03 +8: All tests passed!
```

## 4. 清单验收

| 验收标准 | 状态 | 证据 |
|---|---|---|
| `research/netrix-tools-inventory.md` 存在 | ✅ | 文件已写 |
| 工具总数与 netrix 注册条目数一致 | ✅ | 52 = 52 = 52（`ToolDefinition(` 计数、`id:` 计数、netrix 自带 `registry_test.dart` 的 `expect(kTools.length, 52)`） |
| 每个工具恰好属于一批 | ✅ | 清单第 8 节：25 + 27 + 0 = 52，无重复。代码侧 `batch2_registration_test.dart` 断言第 2 批 27 个 id，且与第 1 批 25 个 id 无交集（27 + 25 = 52） |
| 列出每个工具的 id、名称、分类、入口文件、依赖、平台能力、两种密度所需数据 | ✅ | 清单第 2、5 节 |
| 列出未注册但存在的工具页面 | ✅ | 清单第 3 节（本项目 9 个未注册页面）、第 4 节（netrix 侧为 0） |
| 列出本项目现有工具 | ✅ | 清单第 3 节 |
| 疑似重复对照表 | ✅ | 清单第 6 节，判定权留给 Pi C |

## 5. 第 2 批验收

| 验收标准 | 状态 | 证据 |
|---|---|---|
| 第 2 批每个工具已移植 | ✅ 逻辑层 | 27 个 `NetrixToolDefinition`，`batch2_tools_test.dart` 断言 27 个唯一 id |
| 第 2 批每个工具已注册 | ⚠️ 部分 | 已有本批注册清单 `netrixBatch2Tools`。**尚未接进工具页总注册表**（等契约） |
| 每个工具能打开 | ❌ 未完成 | 需要工具页外壳。契约与骨架缺位时，改 Pi C 的文件才能接线 |
| 每个工具至少一个测试 | ✅ | 5 个测试文件 31 个用例，逐工具覆盖默认值 / 结果行 / 错误键（见第 6 节） |
| 报告有逐工具对照表 | ✅ | 第 6 节 |
| 改动过的仓库 analyze 无问题 | ✅ | 第 3 节 |
| 改动过的仓库 test 全部通过 | ⚠️ | 本批测试全通过。内核全量有 1 个基线就失败的 `interop_arkts_contract_test.dart`（缺 `qfli_java`） |
| 没有改动 `dirty-files.txt` 的路径 | ✅ | 第 8 节 |
| 报告已写 | ✅ | 本文件 |

## 6. 逐工具对照表（第 2 批 27 个）

「差异」列只有两种取值：`无`，或写明原因。

| # | netrix 源（`registry.dart` 条目 + 运行函数） | 本项目目标 | 差异 |
|---|---|---|---|
| 7 | `subnet-calculator` / `_runSubnet` | `batch2_address_tools.dart` | 无 |
| 19 | `subnet-splitter` / `_runSubnetSplitter` | 同上 | 无 |
| 20 | `range-to-cidr` / `_runRangeToCidr` | 同上 | 无 |
| 21 | `cidr-aggregate` / `_runCidrAggregate` | 同上 | 无 |
| 22 | `ip-converter` / `_runIpConverter` | 同上 | 无 |
| 23 | `wildcard-mask` / `_runWildcardMask` | 同上 | 无 |
| 24 | `ip-inspector` / `_runIpInspector` | 同上 | 无 |
| 33 | `ip-membership` / `_runIpMembership` | 同上 | 无 |
| 34 | `ip-range` / `_runIpRange` | 同上 | 无 |
| 44 | `prefix-mask` / `_runPrefixMask` | 同上 | 无 |
| 45 | `mask-prefix` / `_runMaskPrefix` | 同上 | 无 |
| 47 | `ipv4-classifier` / `_runIpv4Classifier` | 同上 | 无 |
| 48 | `ipv4-scope` / `_runIpv4Scope` | 同上 | 无 |
| 1 | `reachability` / `_runReachability` | `batch2_network_tools.dart` | 无 |
| 2 | `port-check` / `_runPortCheck` | 同上 | 无 |
| 3 | `port-scan` / `_runPortScan` | 同上 | 无 |
| 4 | `host-scan` / `_runHostScan` | 同上 | 无 |
| 5 | `hostname-lookup` / `_runHostnameLookup` | 同上 | 无（`List<dynamic>` 原样保留，与 netrix 一致） |
| 6 | `dns-record` / `_runDnsRecord` | 同上 | 无 |
| 8 | `public-ip` / `_runPublicIp` | 同上 | 无 |
| 9 | `local-interfaces` / `_runLocalInterfaces` | 同上 | 无 |
| 10 | `http-request` / `_runHttpRequest` | 同上 | 无 |
| 11 | `websocket` / `_runWebSocket` | 同上 | 依赖版本按第 7 节由 `^2.4.5` 提到 `^3.0.3`。`WebSocketChannel.connect` / `ready` / `stream.first` / `sink.close` 的用法不变 |
| 25 | `mac-normalizer` / `_runMacNormalizer` | 同上 | 无 |
| 26 | `dns-propagation` / `_runDnsPropagation` | 同上 | 无 |
| 27 | `rdap` / `_runRdap` | 同上 | 无 |
| 28 | `tls-inspector` / `_runTlsInspector` | 同上 | 无 |

逐项检查的内容：id、`title`、`titleEn`、`description`、分类、图标、字段（id / label / hint /
defaultValue / required / type / keyboardType / obscureText / options 的顺序）、结果 `title`、
`summary`、`ok`、结果行（label、value、`mono`）、面板（title、text）、全部限额
（端口 256、主机 256 地址 × 16 端口、HTTP 请求体 1 MB、响应 256 KB、RDAP 512 KB、DNS 256 KB、
超时 5 / 8 / 12 / 15 秒、并发 12、子网段 256、CIDR 结果 256、端口范围 4096）、全部错误键。

## 7. 依赖变化与风险

- 新增内核直接依赖 `web_socket_channel`。netrix 钉 `^2.4.5`。该版本会把依赖图里的
  `web` 从 `1.1.1` **降级**到 `0.5.1`，可能影响其他包（`file_selector` 等）的 web 实现。
  我改用 `^3.0.3`：`web` 仍停在 `0.5.1`（`http 1.6.0` / `archive 4` 这一支本来就要求 0.5 系列），
  只新增 `web_socket 1.0.1`，不删除、不改写任何别人的行。
  如果契约要求与 netrix 完全同版本，改一行即可。
- `crypto 3.0.8` 作为传递依赖进入锁文件（来自 `web_socket_channel` 的依赖链），本批不直接使用。
- 同目录内核变化后，`flutter pub get` 更新了主程序 `pubspec.lock`。我没有提交它（第 1 节）。

## 8. `dirty-files.txt` 自查

`dirty-files.txt` 列出的内核路径：`lib/editor/*`、`lib/interop/*`、`lib/services/ai_service.dart`、
`lib/services/api_client.dart`、`lib/services/studio_profile.dart`、`lib/vibe_coding/*`、多个 `test/*`、
`tool/vibe_e2e_runner.dart`，以及 7 个未跟踪目录。

`git diff --stat 573d1b6..HEAD`（内核）只含：
`lib/tools/netrix/batch2/*`（7 个新文件）、`test/tools/netrix/*`（5 个新文件）、
`pubspec.yaml`（+1 行）、`pubspec.lock`（依赖解析）。
`git status --short` 在 `lib/`、`test/`、`pubspec.yaml` 上为空。列表里的路径一个都没动。
主程序仓库 `git diff --stat d26cffc..HEAD` 为空。

## 9. 等待契约的完整时间线

`11-16-tools-netrix-batch2/implement.md` 第 7 步要求：等 `research/tools-port-contract.md`
出现并含骨架提交哈希，然后 `git merge` 骨架，再按契约移植。

### 9.1 Gate 1 之前的等待（已结案）

- 时间：约 21:20–21:40。按原规则等待 20 分钟，4 次检查，契约未出现。
- 当时的状态：`research/tools-port-contract.md` 不存在。Pi C 的两个 worktree 都在基线，
  `ui-c\qfli_studio_core` 是 `573d1b6`，工作区干净。
- 结论：按兜底结束那一轮，需求写进 `research/pi-d-contract-questions.md`。

### 9.2 Gate 1 之后的等待（本轮，超时结案）

- 规则：大脑 Gate 1 要求每 3 分钟检查一次，最多等 120 分钟。
- 实际：从 **01:24** 开始，到 **05:01** 结束，共 **113 分钟**，**38 次**检查（每次 `Start-Sleep 180` 后看文件是否存在）。
- 每一次检查都是 `contract=False`。`research/` 目录始终只有下面 6 个文件：
  `dirty-files.txt`、`netrix-tools-inventory.md`、`pi-a-report.md`、`pi-b-report.md`、
  `pi-d-contract-questions.md`、`pi-d-report.md`。
- Pi C 在同一时间段的状态变化（用于定位卡在哪里）：
  - `ui-c\qfli_studio_core` 的 HEAD 始终是 `573d1b6`，**从未出现新提交**。
  - 工作区自 01:37 起一直是 11 项改动（5 改 + 6 新增）：
    `lib/pages/quick_tools_page.dart`、`lib/pages/tools_grid.dart`、`lib/widgets/tool_widgets.dart`、
    `pubspec.yaml`、`pubspec.lock`，以及 `lib/tools/ported/`、`lib/tools/ported_tool.dart`、
    `lib/tools/ported_tools.dart`、`lib/tools/tool_audience.dart`、
    `lib/tools/tool_state_store.dart`、`lib/widgets/tools_browser.dart`。
  - 这 11 项在 113 分钟里一个字没动，也未提交。也就是说 Pi C 的骨架写到了工作区，
    但没落地成提交，也没写契约。
- 结束时的结论：等待预算用完，契约与骨架提交都没拿到。本轮不执行第 10 节，
  按大脑的指示在报告里说明这一点。

### 9.3 为什么不在没有契约的情况下自己接进工具页

契约缺位时，下面这些事都属于 Pi C 的领域，`pi-rules.md` 与父任务 `design.md` 明确不许我改：
工具页外壳 `lib/pages/tools_grid.dart`、`lib/pages/quick_tools_page.dart`、
`lib/widgets/tool_widgets.dart`、总注册表、显示密度状态与持久化、可见范围判断、
`lib/i18n/studio_localizations.dart` 的插入位置约定。
Pi C 把这 11 个文件写在工作区但未提交，我若去改同一批文件，两边合并时必然冲突，
而且会覆盖别人未提交的成果。所以本轮不碰。

## 10. 下一轮要做的事（契约到位后）

1. `git merge <契约里的骨架哈希>`。骨架在内核就只合并内核，在主程序就两个仓库分别合并。
2. 按契约改路径与类型名。把 `NetrixToolDefinition` / `NetrixToolField` / `NetrixToolResult`
   映射到契约类型，或把契约类型换成我的（以契约为准）。
3. 把 `netrixBatch2Tools` 接进总注册表按批拼接的位置。
4. 沿契约接口标记 27 个工具「只在主程序显示」，并补「非主程序不显示」的测试。
5. 工具详情页接线：字段渲染、检查输入、运行按钮、结果行/面板、错误键翻译
   （`netrixBatch2ErrorText` 可直接用）、两种密度下的卡片与行。
6. 补 27 个工具的组件测试（打开、渲染字段、默认值、跑一个离线工具看到结果行）。

## 11. 与 PRD「大脑的解释」不一致的地方

1. **三批 vs 两批。** `design.md` 与父任务 `implement.md` 假定三批并行（40 % / 40 % / 20 %）。
   我实际给出的是 `25 / 27 / 0`：`prd.md` 要求「共用同一组辅助代码的工具放在同一批」，
   netrix 的工具正好按四份服务文件聚成四组，切成 52 / 26 两半会把 `text_service.dart`
   和 `advanced_service.dart` 的使用者拆开。两批都在 40 % ± 10 个百分点内
   （按工具条目 47.5 % / 52.5 %，按条目 + 服务文件 43.3 % / 56.7 %）。
   如果大脑坚持要第三批，建议把第 1 批的 `ADV` 分组整体挪给 Pi B，但那会落到 ~34 %，需大脑拍板。
   清单第 7 节已写明这一点。
2. **`url-parser` 的重复判定。** 本项目 `lib/pages/offline_text_tool_pages.dart` 里有
   `UrlParserToolPage`（title「URL 解析」），但全文没有任何引用，是死代码。
   `dirty-files.txt` 没有列出该文件。我按「疑似重复」放进第 1 批，判定留给 Pi C。
   若 Pi C 决定复用该页面，`url-parser` 就是「复活死代码 + 补齐字段」，不需要另建页面。
3. **「子项目也使用移植来的工具页 UI（A8）」与「移植工具只在主程序显示（R9）」的张力。**
   A8 说子项目也用两种显示密度的工具页 UI，R9 说移植来的工具只在主程序显示。
   我的理解：密度 UI 是框架（Pi C 做，全产品可见），27 个移植工具本身只在主程序可见
   （给 `tools-port-contract.md` 的问题 4）。
4. **依赖版本。** netrix 用 `web_socket_channel ^2.4.5`。我提到 `^3.0.3` 以避免降级 `web`。
   这与「1:1 照搬」在依赖层面有个小偏离，代码用法不变（第 7 节）。

## 12. 未完成项与风险（如实列出）

未完成：

- 工具页接入、显示密度、可见范围标记、密度持久化的对接（第 9 节）。
- 27 个工具的组件测试（需要工具页外壳）。
- 主程序仓库没有本批的任何提交（本批不涉及主程序代码）。
- 工具页真机/模拟器走查与截图：第 3 阶段属于交叉检查与全流程，且现在工具页还没接上。

风险：

- **Pi C 迟迟没有产出骨架**，是本次第 2 批无法交付「能打开」的直接原因。
  如果 Pi C 的方案（例如放在主程序而不是内核）与我的落位不同，我这 8 个提交需要搬家，
  但逻辑与测试可以整体复用，成本低。
- 网络工具的实跑（TCP / TLS / DNS-over-HTTPS / RDAP / WebSocket）在 CI 里不做，
  只测输入检查路径。真机走查时必须真的点一遍，尤其 OHOS 上的 `dart:io` Socket 与
  OHOS 沙箱是否放行 `SecureSocket`。
- `web_socket_channel ^3.0.3` 引入 `web_socket 1.0.1`。OHOS 上能否建连需要真机确认。
- 内核全量测试有 1 个基线失败项（`interop_arkts_contract_test.dart`，缺 `qfli_java`），
  大脑合并时请按同一标准看待，不要算到本任务头上。
