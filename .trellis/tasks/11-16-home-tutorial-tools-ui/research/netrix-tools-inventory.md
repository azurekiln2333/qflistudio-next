# netrix 工具清单与分批（Pi D 产出）

> 依据：`D:\MyOtherNewProj\netrix`（只读 Flutter 项目）。
> 目的：把 netrix 工具页的**全部**工具列清，分成三批，互不重叠、一个不漏。
> 读者：Pi C（第 1 批）、Pi D（第 2 批）、Pi B（第 3 批）、大脑。

## 1. 计数方法与检查结论

- netrix 工具页入口：`lib/main.dart` → `HomePage(tools: kTools, ...)`。
- 工具注册位置：`lib/core/registry.dart` 顶层的 `final List<ToolDefinition> kTools`。
  该列表从 `registry.dart:14` 开始，到 `registry.dart:827` 的 `];` 结束。
- 计数方法（三重检查，三者一致）：
  1. 在 `kTools` 列表体内匹配 `^  ToolDefinition\(`：**52** 处。
  2. 在同样的列表体内匹配行首 `    id: '...'`：**52** 个，全部唯一。
  3. netrix 自带测试 `test/registry_test.dart` 断言 `expect(kTools.length, 52)`，此时检查通过。
- **工具总数 = 52**。本文档第 2 节列 52 行，第 6 节分批合计也是 52。
- 源码目录另外检查过：`lib/ui/home_page.dart`（工具页外壳）、`lib/ui/tool_page.dart`（通用工具详情页）、
  `lib/widgets/common.dart`（结果视图）、`lib/core/services/*`（工具逻辑）、`lib/core/localization.dart`（文案）。
  这些文件里没有额外注册、也没有未注册的工具页面，见第 4 节。

## 2. 全部 52 个工具

列说明：

- **loc** = `registry.dart` 里该 `ToolDefinition(...)` 条目行数 + 该工具 `_run*` 运行函数行数（用 Python 从原文量出）。
- **字段** = 工具表单字段（紧密显示、宽松显示两种密度下都使用同一组字段，见第 5 节）。
- **依赖** = 该工具运行时依赖的第三方包。
- **平台能力** = 运行时需要的原生能力。

分类枚举来自 `lib/core/models.dart` 的 `ToolCategory`：
`diagnostics`（诊断）、`address`（地址与子网）、`dns`（DNS 与域名）、`web`（Web 与 API）、
`security`（安全与密码）、`text`（文本与编码）、`local`（本机网络）。

| # | id | 名称 | 英文名 | 分类 | 图标 | 字段 | 运行函数 | loc | 依赖 | 平台能力 | 批 |
|---|---|---|---|---|---|---|---|---|---|---|---|
| 1 | `reachability` | 主机连通性 | TCP Reachability | diagnostics | speed_outlined | host, port | `_runReachability` | 34 | 无（`dart:io` Socket） | 出站 TCP | 2 |
| 2 | `port-check` | TCP 端口检测 | TCP Port Check | diagnostics | power_outlined | host, port | `_runPortCheck` | 32 | 无（`dart:io` Socket） | 出站 TCP | 2 |
| 3 | `port-scan` | 端口批量探测 | Bounded Port Scan | diagnostics | radar_outlined | host, ports | `_runPortScan` | 44 | 无（`dart:io` Socket） | 出站 TCP，并发 12，上限 256 端口 | 2 |
| 4 | `host-scan` | 主机扫描 | Private Host Scanner | diagnostics | radar_outlined | cidr, ports | `_runHostScan` | 57 | 无（`dart:io` Socket） | 出站 TCP，仅私有 IPv4，上限 256 地址 × 16 端口 | 2 |
| 5 | `hostname-lookup` | 主机名解析 | Hostname Lookup | dns | travel_explore_outlined | host | `_runHostnameLookup` | 24 | 无（`dart:io`） | 系统 DNS 解析 | 2 |
| 6 | `dns-record` | DNS 记录查询 | DNS-over-HTTPS | dns | dns_outlined | name, type(select) | `_runDnsRecord` | 34 | `http` | 出站 HTTPS（cloudflare-dns.com） | 2 |
| 7 | `subnet-calculator` | IPv4 子网计算 | IPv4 CIDR Calculator | address | account_tree_outlined | cidr | `_runSubnet` | 28 | 无 | 无（纯计算） | 2 |
| 8 | `public-ip` | 公网 IP | Public IP | address | public_outlined | — | `_runPublicIp` | 16 | `http` | 出站 HTTPS（api.ipify.org） | 2 |
| 9 | `local-interfaces` | 本机网络接口 | Local Interfaces | local | router_outlined | — | `_runLocalInterfaces` | 21 | 无（`dart:io`） | 枚举网卡 | 2 |
| 10 | `http-request` | HTTP 请求测试 | HTTP Request | web | http_outlined | method(select), url, headers, body | `_runHttpRequest` | 60 | `http` | 出站 HTTP(S)，响应体截断 256 KB | 2 |
| 11 | `websocket` | WebSocket 测试 | WebSocket Probe | web | cable_outlined | url, message | `_runWebSocket` | 30 | `web_socket_channel` | 出站 WS/WSS | 2 |
| 12 | `url-parser` | URL 解析 | URL Parser | web | link_outlined | url | `_runUrlParser` | 33 | 无（`dart:core` Uri） | 无 | 3 ❗重复 |
| 13 | `json` | JSON 格式化 | JSON Formatter | text | data_object_outlined | input | `_runJson` | 22 | 无 | 无 | 1 ❗重复 |
| 14 | `base64` | Base64 编解码 | Base64 Codec | text | swap_horiz_outlined | mode(select), input | `_runBase64` | 30 | 无 | 无 | 1 ❗重复 |
| 15 | `url-codec` | URL 编解码 | URL Codec | text | link_off_outlined | mode(select), input | `_runUrlCodec` | 30 | 无 | 无 | 1 ❗重复 |
| 16 | `hex` | Hex 编解码 | Hex Codec | text | code_outlined | mode(select), input | `_runHex` | 30 | 无 | 无 | 1 |
| 17 | `digest` | 摘要哈希 | Digest Hash | security | fingerprint_outlined | algorithm(select), input | `_runDigest` | 25 | `crypto` | 无 | 1 ❗重复 |
| 18 | `jwt` | JWT 查看器 | JWT Viewer | security | key_outlined | token | `_runJwt` | 28 | 无 | 无 | 1 |
| 19 | `subnet-splitter` | 子网拆分规划 | Subnet Splitter | address | call_split_outlined | cidr, prefix | `_runSubnetSplitter` | 40 | 无 | 无 | 2 |
| 20 | `range-to-cidr` | IP 范围转 CIDR | Range to CIDR | address | swap_calls_outlined | start, end | `_runRangeToCidr` | 23 | 无 | 无 | 2 |
| 21 | `cidr-aggregate` | CIDR 聚合 | CIDR Aggregator | address | merge_type_outlined | cidrs | `_runCidrAggregate` | 25 | 无 | 无 | 2 |
| 22 | `ip-converter` | IPv4 进制转换 | IPv4 Converter | address | calculate_outlined | ip | `_runIpConverter` | 25 | 无 | 无 | 2 |
| 23 | `wildcard-mask` | 通配符掩码 | Wildcard Mask | address | filter_alt_outlined | prefix | `_runWildcardMask` | 28 | 无 | 无 | 2 |
| 24 | `ip-inspector` | IPv4 / IPv6 查看 | IP Inspector | address | account_tree_outlined | ip | `_runIpInspector` | 25 | 无（`dart:io` InternetAddress） | 无 | 2 |
| 25 | `mac-normalizer` | MAC 地址规范化 | MAC Normalizer | local | devices_other_outlined | mac | `_runMacNormalizer` | 26 | 无 | 无 | 2 |
| 26 | `dns-propagation` | DNS 多解析器对比 | DNS Propagation | dns | compare_arrows_outlined | name, type(select) | `_runDnsPropagation` | 39 | `http` | 出站 HTTPS（Cloudflare / Google / AdGuard） | 2 |
| 27 | `rdap` | RDAP 注册信息 | RDAP Lookup | diagnostics | badge_outlined | target | `_runRdap` | 30 | `http` | 出站 HTTPS（rdap.org） | 2 |
| 28 | `tls-inspector` | TLS 证书查看 | TLS Inspector | web | verified_user_outlined | host, port | `_runTlsInspector` | 36 | 无（`dart:io` SecureSocket） | 出站 TLS，接受无效证书 | 2 |
| 29 | `http-status` | HTTP 状态码参考 | HTTP Status Reference | web | rule_outlined | code | `_runHttpStatus` | 32 | 无 | 无（离线参考表） | 3 |
| 30 | `port-reference` | 常用端口参考 | Port Reference | diagnostics | list_alt_outlined | port | `_runPortReference` | 30 | 无 | 无（离线参考表） | 3 |
| 31 | `headers-parser` | HTTP 请求头分析 | Header Analyzer | web | subject_outlined | headers | `_runHeadersParser` | 28 | 无 | 无 | 3 |
| 32 | `curl-builder` | cURL 命令生成 | cURL Builder | web | terminal_outlined | method(select), url, headers, body | `_runCurlBuilder` | 50 | 无 | 无 | 3 |
| 33 | `ip-membership` | IPv4 网段归属 | IPv4 CIDR Membership | address | account_tree_outlined | ip, cidr | `_runIpMembership` | 30 | 无 | 无 | 2 |
| 34 | `ip-range` | IPv4 地址范围 | IPv4 Range | address | swap_calls_outlined | cidr | `_runIpRange` | 26 | 无 | 无 | 2 |
| 35 | `reverse-dns` | 反向 DNS 名称 | Reverse DNS Name | dns | dns_outlined | ip | `_runReverseDns` | 22 | 无 | 无 | 3 |
| 36 | `dns-name` | DNS 名称检查 | DNS Name Inspector | dns | travel_explore_outlined | name | `_runDnsName` | 25 | 无 | 无 | 3 |
| 37 | `query-parser` | 查询字符串解析 | Query String Parser | web | subject_outlined | query | `_runQueryParser` | 26 | 无 | 无 | 3 |
| 38 | `query-builder` | 查询字符串生成 | Query String Builder | web | link_outlined | parameters | `_runQueryBuilder` | 26 | 无 | 无 | 3 |
| 39 | `http-content-type` | Content-Type 分析 | Content-Type Inspector | web | http_outlined | contentType | `_runHttpContentType` | 37 | 无 | 无 | 3 |
| 40 | `http-cache-control` | Cache-Control 分析 | Cache-Control Inspector | web | rule_outlined | header | `_runHttpCacheControl` | 27 | 无 | 无 | 3 |
| 41 | `http-date` | HTTP 日期转换 | HTTP Date Parser | web | schedule_outlined | date | `_runHttpDate` | 26 | 无（`dart:io` HttpDate） | 无 | 3 |
| 42 | `basic-auth` | Basic 认证头 | Basic Auth Header | security | lock_outline | username, password(obscure) | `_runBasicAuth` | 30 | 无 | 无 | 3 |
| 43 | `timestamp-converter` | Unix 时间戳转换 | Unix Timestamp Converter | text | schedule_outlined | timestamp | `_runTimestamp` | 29 | 无 | 无 | 3 ❗重复 |
| 44 | `prefix-mask` | 前缀转子网掩码 | Prefix to Netmask | address | filter_alt_outlined | prefix | `_runPrefixMask` | 28 | 无 | 无 | 2 |
| 45 | `mask-prefix` | 子网掩码转前缀 | Netmask to Prefix | address | compare_arrows_outlined | mask | `_runMaskPrefix` | 24 | 无 | 无 | 2 |
| 46 | `port-range` | 端口范围分析 | Port Range Analyzer | diagnostics | list_alt_outlined | ports | `_runPortRange` | 24 | 无 | 无 | 3 |
| 47 | `ipv4-classifier` | IPv4 分类查看 | IPv4 Classifier | address | category_outlined | ip | `_runIpv4Classifier` | 24 | 无 | 无 | 2 |
| 48 | `ipv4-scope` | IPv4 地址范围 | IPv4 Scope | address | public_outlined | ip | `_runIpv4Scope` | 23 | 无 | 无 | 2 |
| 49 | `cookie-parser` | Cookie 请求头分析 | Cookie Header Parser | web | subject_outlined | cookie | `_runCookieParser` | 26 | 无 | 无 | 3 |
| 50 | `url-join` | URL 路径拼接 | URL Resolver | web | link_outlined | base, path | `_runUrlJoin` | 28 | 无 | 无 | 3 |
| 51 | `http-method` | HTTP 方法参考 | HTTP Method Reference | web | rule_outlined | method(select) | `_runHttpMethod` | 59 | 无 | 无 | 3 |
| 52 | `dns-label` | DNS 标签检查 | DNS Label Validator | dns | dns_outlined | label | `_runDnsLabel` | 26 | 无 | 无 | 3 |

### 2.1 工具之外、但工具页离不开的部分

工具条目本身只有一个 `ToolDefinition`，界面和状态来自下面的公共代码。
这三份代码不按工具分摊，按「框架」处理（Pi C 首批移植）：

| 部分 | 文件 | 行数 | 作用 |
|---|---|---|---|
| 工具页外壳 | `lib/ui/home_page.dart` | 1485 | 四个目的地（首页 / 全部 / 收藏 / 我的）、搜索、分类 chip、密度切换、卡片与行、设置页 |
| 通用工具详情页 | `lib/ui/tool_page.dart` | 200 | 表单、检查、运行按钮、收藏星标、英文名 |
| 结果视图 | `lib/widgets/common.dart` | 145 | 结果卡片、键值行、可复制文本面板 |
| 数据模型 | `lib/core/models.dart` | 198 | `ToolDefinition` / `ToolField` / `ToolResult` / `ToolCategory` 与输入检查函数 |
| 主题 | `lib/core/theme.dart` | 76 | Material 3 主题 |
| 文案 | `lib/core/localization.dart` | 658 | zh / zh-TW / en / ja / ko 五套文案 |
| 状态与持久化 | `lib/core/services/tool_state.dart` | 289 | 收藏、最近使用、主题、密度、本机网络展开。JSON 落盘 + OHOS 原生通道 |
| 应用入口 | `lib/main.dart` | 50 | 装配 |

框架合计 3101 行。

### 2.2 工具逻辑文件与使用它的工具

| 服务文件 | 行数 | 使用它的工具 |
|---|---|---|
| `lib/core/services/text_service.dart` | 102 | json, base64, url-codec, hex, digest, jwt |
| `lib/core/services/address_service.dart` | 209 | subnet-calculator, subnet-splitter, range-to-cidr, cidr-aggregate, ip-converter, wildcard-mask, ip-inspector, ip-membership, ip-range, prefix-mask, mask-prefix, ipv4-classifier, ipv4-scope（network_service 的 host-scan 也复用它） |
| `lib/core/services/network_service.dart` | 612 | reachability, port-check, port-scan, host-scan, hostname-lookup, dns-record, public-ip, local-interfaces, http-request, websocket, dns-propagation, rdap, tls-inspector |
| `lib/core/services/advanced_service.dart` | 412 | http-status, port-reference, headers-parser, curl-builder, reverse-dns, dns-name, query-parser, query-builder, http-content-type, http-cache-control, http-date, basic-auth, timestamp-converter, port-range, cookie-parser, url-join, http-method, dns-label, url-parser |

代码量口径：工具条目 + 运行函数 = 1581 行（第 2 节 loc 列求和）。四个服务文件 = 1335 行。
框架 = 3101 行。
分批比例只按「工具条目 + 运行函数」统计，见第 7 节。
早期草稿里写的 2916 行无法用上述口径复现，已改为实测值。

## 3. 本项目现有工具（移植时用于判重）

来源：`qfli_studio_core/lib/pages/tools_grid.dart` 的 `commonTools`（9 项，全部产品可见）。

| 现有工具 | 页面文件 | 作用 |
|---|---|---|
| 字符/Unicode | `lib/pages/offline_tool_pages.dart` `UnicodeToolPage` | 码点、转义、UTF-8/16 字节 |
| Base64 | 同上 `Base64ToolPage` | 标准 / URL-safe 两种字母表 |
| URL 编解码 | 同上 `UrlToolPage` | 表单风格百分号编解码 |
| 正则测试 | 同上 `RegexToolPage` | Dart RegExp 试跑 |
| JSON 格式化 | `lib/pages/content_tools_pages.dart` `JsonToolPage` | 格式化、检查、结构树 |
| 哈希摘要 | `offline_tool_pages.dart` `HashToolPage` | MD5 / SHA-1 / SHA-256 一次出三种 |
| 时间戳 | `offline_tool_pages.dart` `TimestampToolPage` | 秒/毫秒 ⇄ 本地日期时间 |
| UUID 生成 | `offline_tool_pages.dart` `UuidToolPage` | v4 / v3 / v5 |
| 颜色转换 | `offline_tool_pages.dart` `ColorToolPage` | #RGB / #RRGGBB / #AARRGGBB |

**已存在但没有注册的页面**（`lib/pages/offline_text_tool_pages.dart`，9 个类，全文无任何引用）：

| 页面类 | title | 对应 netrix 工具 |
|---|---|---|
| `NumberBaseToolPage` | 进制转换 | 无 |
| `PasswordToolPage` | 密码生成 | 无 |
| `TextStatsToolPage` | 文本统计 | 无 |
| `TextLinesToolPage` | 行排序去重 | 无 |
| `CaseToolPage` | 命名风格 | 无 |
| `HtmlEscapeToolPage` | HTML 转义 | 无 |
| `JsonCsvToolPage` | JSON ⇄ CSV | 无 |
| `UrlParserToolPage` | URL 解析 | 与 netrix `url-parser` 目标重叠（只能有一个） |
| `DiffToolPage` | 文本对比 | 无 |

netrix 侧若也存在未注册页面，第 4 节给出检查结论。

## 4. netrix 侧「没有注册但存在于代码里」的工具页面

检查方式：`lib/` 下全部 13 个 Dart 文件逐个看类与引用关系。

- `lib/ui/tool_page.dart` 的 `ToolPage` 是**通用详情页**，不是某个具体工具，由 `HomePage._openTool` 按 `ToolDefinition` 打开。
  它已注册为框架的一部分。
- `lib/ui/home_page.dart` 的 `_SettingsView` / `_SettingsPage` / `_MyView` / `_LocalNetworkCard`
  是外壳与设置页，不对应任何工具。
- 结论：**netrix 没有未注册的工具页面，注册条目数 = 工具数 = 52。**

## 5. 紧密显示与宽松显示用到的数据

netrix 的两种密度是 `ToolCardDensity { standard, compact }`（`lib/ui/home_page.dart:14`）：

- 宽松显示（`standard`，文案「标准」）用 `_ToolCard`：
  网格 `maxCrossAxisExtent: 360`。首页三段用 `mainAxisExtent: 136`（`_homeStandardSliver`），
  全部/收藏用 `mainAxisExtent: 176`（`_standardSliver`）。间距 12 / 14。
  卡片内容：图标、收藏按钮、打开按钮、`title`（titleMedium）、`description`（bodySmall，最多 2 行）。
- 紧密显示（`compact`，文案「紧凑」）用 `_ToolRow`：
  `SizedBox(height: 78)` 外包一层 `EdgeInsets.only(bottom: 10)` 的 Padding，
  内部 `_ToolRow` 自身 `SizedBox(height: 68)`。`Card` 无外边距，水平内边距 12。
  行内容：图标（宽 40）、`title`（titleSmall，1 行）、
  `'${tool.titleEn} · ${strings.category(tool.category.key)}'`（bodySmall，1 行）、收藏按钮、打开按钮。
- 切换控件：`SegmentedButton<ToolCardDensity>`，出现在「全部」页头部（`_AllToolsHeader`）和设置页（`_SettingsView`）。
  标签分别是 `strings.standard` / `strings.compact`（设置页用 `standardCard` / `compactRows`）。
- 持久化：`ToolStateStore.cardDensity`（`lib/core/services/tool_state.dart`），
  落盘键 `cardDensity`，合法值 `standard` / `compact`，默认 `standard`。
  `_decodeCardDensity` 遇到非法值回落到默认值。
- 生效范围：首页的「最近使用」「全部」「收藏」三段、全部工具页、收藏工具页都跟随密度。
  工具**详情页**本身不随密度变化（`ToolPage` 只有一套布局）。
- 每个工具需要提供的密度数据：`id`、`title`、`titleEn`、`description`、`icon`、`category`。
  宽松显示用前四项 + 图标，紧密显示用 `title` + `titleEn` + 分类文案。

## 6. 疑似重复对照表（判定权在 Pi C）

| netrix 工具 | 本项目现有工具 | 重复点 | 只有 netrix 有的能力 | 判定建议 |
|---|---|---|---|---|
| `base64` | Base64 | 都是文本 ⇄ Base64 编解码 | 有 `encode` / `decode` 下拉模式 | 合并保留一个 |
| `url-codec` | URL 编解码 | 都是百分号编解码 | netrix 用 `Uri.encodeComponent`，现有用表单风格（空格变 `+`） | 合并保留一个 |
| `json` | JSON 格式化 | 都是 JSON 检查 + 缩进 | 现有版还有结构树。netrix 输出是等宽文本面板 | 合并后保留双方：既有结构树又有缩进文本 |
| `digest` | 哈希摘要 | 都是 MD5 / SHA-1 / SHA-256 | netrix 多 SHA-512 与算法选择 | 合并保留现有版并补 SHA-512 |
| `timestamp-converter` | 时间戳 | 都是 Unix 时间戳转换 | netrix 只做 UTC 单向。现有版做本地双向往返 | 合并保留现有版 |
| `url-parser` | （未注册）`UrlParserToolPage` | 同一个作用 | — | `UrlParserToolPage` 未注册，可不计为重复。注册 `url-parser` 时若复用该页面就不要再建第二个 |
| `port-reference` / `port-range` | 无 | — | — | 不重复 |
| 其余 46 个 | 无 | — | — | 不重复 |

## 7. 分批

分配规则（来自父任务 `design.md`、Pi D 的 `prd.md`，以及大脑 Gate 1 的裁定）：

- 按代码量 40% / 40% / 20% 分给 Pi C / Pi D / Pi B，允许偏差 10 个百分点。
- 共用辅助代码的工具同批。
- 疑似重复的工具放第 1 批。
- Gate 1 裁定（2026-11-16）：`TEXT` 留第 1 批（Pi C），`ADV` 整组改为第 3 批（Pi B），第 2 批不变。

共用代码分组（三个 Pi 共用一套服务层，不重复移植）：

- `TEXT`：`text_service.dart`（json, base64, url-codec, hex, digest, jwt）
- `ADDR`：`address_service.dart`（13 个纯地址计算工具）
- `NET`：`network_service.dart`（13 个网络工具 + mac-normalizer 共用 host/port 检查）
- `ADV`：`advanced_service.dart`（18 个 HTTP / DNS 文本工具 + url-parser）

代码量（工具条目 + 运行函数，按第 2 节 loc 列求和）：

| 批次 | 分组 | 工具数 | 行数 | 占 1581 行 |
|---|---|---|---|---|
| 第 1 批（Pi C） | `TEXT` | 6 | 165 | 10.4% |
| 第 2 批（Pi D） | `ADDR` + `NET` | 27 | 832 | 52.6% |
| 第 3 批（Pi B） | `ADV` | 19 | 584 | 36.9% |
| 合计 | | **52** | **1581** | 100% |

比例说明（如实记录）：第 2 批与第 3 批超出 `design.md` 的 40% 目标，第 1 批低于 40%。
原因是 Gate 1 要求在保留第 2 批的前提下把 `ADV` 整组改给第 3 批，而 `TEXT` 只有 6 个工具。
清单照裁定结果落地。偏差数据记在 `research/pi-d-report.md`。

### 7.1 第 1 批（Pi C）：6 个

| # | 分组 | id | 名称 | 行数 |
|---|---|---|---|---|
| 13 | TEXT | `json` | JSON 格式化 ❗重复 | 22 |
| 14 | TEXT | `base64` | Base64 编解码 ❗重复 | 30 |
| 15 | TEXT | `url-codec` | URL 编解码 ❗重复 | 30 |
| 16 | TEXT | `hex` | Hex 编解码 | 30 |
| 17 | TEXT | `digest` | 摘要哈希 ❗重复 | 25 |
| 18 | TEXT | `jwt` | JWT 查看器 | 28 |

合计 6 个，165 行。依赖的服务文件：`text_service.dart`。
本组含 4 个疑似重复项（`json`、`base64`、`url-codec`、`digest`）。

### 7.2 第 2 批（Pi D）：27 个

与 Gate 1 之前相同，未作改动。

`reachability`、`port-check`、`port-scan`、`host-scan`、`hostname-lookup`、`dns-record`、
`subnet-calculator`、`public-ip`、`local-interfaces`、`http-request`、`websocket`、
`subnet-splitter`、`range-to-cidr`、`cidr-aggregate`、`ip-converter`、`wildcard-mask`、
`ip-inspector`、`mac-normalizer`、`dns-propagation`、`rdap`、`tls-inspector`、
`ip-membership`、`ip-range`、`prefix-mask`、`mask-prefix`、`ipv4-classifier`、`ipv4-scope`。

依赖的服务文件：`address_service.dart`、`network_service.dart`。

代码量口径：832 行 = 这 27 个工具的「条目 + 运行函数」行数之和。

### 7.3 第 3 批（Pi B）：19 个

原第 1 批的 `ADV` 组整组划入本批（Gate 1 裁定）。

| # | 分组 | id | 名称 | 行数 |
|---|---|---|---|---|
| 12 | ADV | `url-parser` | URL 解析 ❗重复候选 | 33 |
| 29 | ADV | `http-status` | HTTP 状态码参考 | 32 |
| 30 | ADV | `port-reference` | 常用端口参考 | 30 |
| 31 | ADV | `headers-parser` | HTTP 请求头分析 | 28 |
| 32 | ADV | `curl-builder` | cURL 命令生成 | 50 |
| 35 | ADV | `reverse-dns` | 反向 DNS 名称 | 22 |
| 36 | ADV | `dns-name` | DNS 名称检查 | 25 |
| 37 | ADV | `query-parser` | 查询字符串解析 | 26 |
| 38 | ADV | `query-builder` | 查询字符串生成 | 26 |
| 39 | ADV | `http-content-type` | Content-Type 分析 | 37 |
| 40 | ADV | `http-cache-control` | Cache-Control 分析 | 27 |
| 41 | ADV | `http-date` | HTTP 日期转换 | 26 |
| 42 | ADV | `basic-auth` | Basic 认证头 | 30 |
| 43 | ADV | `timestamp-converter` | Unix 时间戳转换 ❗重复 | 29 |
| 46 | ADV | `port-range` | 端口范围分析 | 24 |
| 49 | ADV | `cookie-parser` | Cookie 请求头分析 | 26 |
| 50 | ADV | `url-join` | URL 路径拼接 | 28 |
| 51 | ADV | `http-method` | HTTP 方法参考 | 59 |
| 52 | ADV | `dns-label` | DNS 标签检查 | 26 |

合计 19 个，584 行。依赖的服务文件：`advanced_service.dart`。
本组含 2 个疑似重复项（`url-parser`、`timestamp-converter`）。
Gate 1 裁定这两项进第 3 批，不放第 1 批。此处与「疑似重复放第 1 批」的规则不一致，故记在此处。

## 8. 批次汇总检查

| 批次 | 分组 | 工具数 | 行数 | id 集合检查 |
|---|---|---|---|---|
| 第 1 批 | `TEXT` | 6 | 165 | 与 7.1 列出的 6 个一致 |
| 第 2 批 | `ADDR` + `NET` | 27 | 832 | 与 7.2 列出的 27 个一致 |
| 第 3 批 | `ADV` | 19 | 584 | 与 7.3 列出的 19 个一致 |
| 合计 | | **52** | **1581** | 等于 `kTools.length`，无重复、无遗漏 |

三批的 id 集合互不相交，并集为 52。第 2 批的 27 个 id 另有代码侧断言：
`test/tools/netrix/batch2_registration_test.dart` 固定这 27 个 id。

## 9. 平台能力差异（移植时必须知道）

| 能力 | netrix 用法 | 本项目现状 | 处理 |
|---|---|---|---|
| 出站 TCP / TLS / DNS / 网卡 | `dart:io` | 内核已用 `dart:io`（`local_web_server.dart` 等） | 直接照搬 |
| HTTP 客户端 | `package:http` | 内核 `pubspec.yaml` 已有 `http: ^1.6.0` | 直接照搬 |
| WebSocket | `package:web_socket_channel` | 内核**没有**该依赖 | 第 2 批需要追加依赖，只加不改 |
| 摘要哈希 | `package:crypto` | 内核**没有**，只有自研 `OfflineDigest` | 用它的 `digest` 工具归第 1 批（Pi C）。`jwt` 只解码不检查，不依赖 `crypto` |
| HTTP 文本工具 | 无（纯本地表格与字符串处理） | 内核无需 | `ADV` 整组归第 3 批（Pi B），Gate 1 裁定 |
| OHOS 状态持久化 | `MethodChannel('netrix/state')` | 本项目用 JSON 文件落盘（`local_store_backend.dart`） | 按契约改成本项目已有的落盘方式 |
| 打开外链 | `url_launcher` + `MethodChannel('netrix/platform')` | 只在设置页用，不是工具能力 | 不需要 |
| 应用语言 | 五种（zh / zh-TW / en / ja / ko） | 三种（zh-CN / zh-TW / en） | 按契约接入 `StudioLocalizations`，ja / ko 不移植 |
