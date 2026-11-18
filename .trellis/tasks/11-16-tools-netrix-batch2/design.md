# 设计（Pi D）

## 大脑给定的边界

- 归属：netrix 工具清单、第 2 批工具、第 2 批的注册文件。
- 清单是 C、D、B 三个 Pi 的共同依据。清单漏掉的工具不会有人移植。
- 契约由 Pi C 写在 `research/tools-port-contract.md`。你按契约放文件、注册、标记可见范围。
- 契约出现之前，你做清单，并通读第 2 批工具的 netrix 源码。
- 用户原话（原文照录，不加工）见父任务 `prd.md` 第 1 节。要点：netrix 的全部工具都要合并，逻辑、紧密显示和宽松显示 1:1 照搬，重复的合并保留。

## Pi 补充（改代码前填写）

### 检查结果

- netrix 工具注册位置：`lib/core/registry.dart` 的 `final List<ToolDefinition> kTools`（第 14 行到第 827 行）。
  52 个条目，52 个唯一 id。检查方法写在 `research/netrix-tools-inventory.md` 第 1 节。
- 工具页外壳：`lib/ui/home_page.dart`（密度、搜索、收藏、最近使用）。通用详情页：`lib/ui/tool_page.dart`。
  结果视图：`lib/widgets/common.dart`。这三份属于 Pi C 的框架，不由我移植。
- netrix 没有未注册的工具页面。

### 第 2 批工具列表（27 个，与清单第 7.2 节一致）

地址与子网（13，共用 `address_service.dart`）：
`subnet-calculator`、`subnet-splitter`、`range-to-cidr`、`cidr-aggregate`、`ip-converter`、
`wildcard-mask`、`ip-inspector`、`ip-membership`、`ip-range`、`prefix-mask`、`mask-prefix`、
`ipv4-classifier`、`ipv4-scope`。

网络（14，共用 `network_service.dart`）：
`reachability`、`port-check`、`port-scan`、`host-scan`、`hostname-lookup`、`dns-record`、
`public-ip`、`local-interfaces`、`http-request`、`websocket`、`dns-propagation`、`rdap`、
`tls-inspector`、`mac-normalizer`。

### 需要一并移植的辅助代码

- `lib/core/services/address_service.dart`（209 行）+ 其中 `IPv4Address` / `CidrBlock` 等模型。
- `lib/core/services/network_service.dart`（612 行）。后者内部复用 `address_service.dart` 的 `parseCidr`。
- 输入检查函数（`hostFromInput` / `requirePort` / `parsePortList` / `parseHeaders` / `formatDuration` /
  `formatBytes` / `requireValue` / `requireHost`，在 `models.dart`）：`network_service.dart` 要用，
  所以随本批的 `netrix` 服务一起落位，不能等 Pi C。
- OHOS 原生状态通道不移植：本项目用 `LocalStoreBackend` 系列落盘。

### 新依赖

- `web_socket_channel`（`websocket` 工具）。netrix 用 `^2.4.5`，我改用 `^3.0.3`，理由见报告第 7 节。内核按契约追加，只加不改。
- `http` 内核已有（`^1.6.0`），不需要新增。
- `crypto` 只服务第 1 批的 `digest`，本批不需要。

### 无法 1:1 的地方和原因

- 多语言：netrix 五套（zh / zh-TW / en / ja / ko），本项目三套（zh-CN / zh-TW / en）。
  ja / ko 不移植。中文文案沿用 netrix 原文，英文文案沿用 netrix 英文表。
- 文案接入：netrix 用 `NetrixLocalizations._text(key)` 目录查表。本项目按契约接入
  `StudioLocalizations`（只追加键，不改别人的行）。工具内部的中文字面量（如结果行标签）
  netrix 本身也写死在 `registry.dart`，因此保持写死，不强行抽多语言。
- 状态持久化：netrix `ToolStateStore` 会走 `MethodChannel('netrix/state')`。本项目用 JSON 文件。
  本批工具本身只依赖「收藏 / 最近使用 / 显示密度」三种状态，由契约规定的接口提供。
- 主题：netrix 用自带 Material 3 主题。本项目用 `Theme.of(context)`。颜色由宿主主题决定，不算功能差异。

### 依赖契约/骨架的部分（等 `research/tools-port-contract.md`）

- 「移植工具的目录和文件命名」。
- 「工具对外的数据结构（标识、名称、图标、分类、入口页面、两种密度所需数据）」。
- 「注册方式：每批一个注册文件，总注册表按批拼接」。
- 「可见范围判断的接口」与「只在主程序显示」的标记。
- 「显示密度的状态和持久化位置」。
- 契约未出现时先做不冲突的部分：本批的服务层 + 工具定义 + 测试落在自己的文件里，
  不碰工具页框架与别的批的注册文件。契约到达后补一次适配提交。
