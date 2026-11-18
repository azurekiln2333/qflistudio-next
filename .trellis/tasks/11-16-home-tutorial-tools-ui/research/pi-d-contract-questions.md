# Pi D 对 `tools-port-contract.md` 的问题与需求

写入时间：2026-11-16 ~21:40。当时 `research/tools-port-contract.md` 不存在
（`research/` 下只有 `dirty-files.txt` 和 `netrix-tools-inventory.md`），
`ui-c` 分支还停在基线 `573d1b6`，因此按 `11-16-tools-netrix-batch2/implement.md`
第 7 步的兜底：等满 20 分钟后结束本轮，并把需求写在这里。

## 1. 我需要契约回答的问题

1. 移植工具放在内核还是主程序？目录和文件命名是什么？
   我现在落位在内核：`lib/tools/netrix/batch2/`（`batch2_models.dart`、
   `batch2_address_service.dart`、`batch2_network_service.dart`、
   `batch2_address_tools.dart`、`batch2_network_tools.dart`、`netrix_batch2_tools.dart`）。
   如果契约要求别的路径，请给出目标路径，我一次性搬过去。
2. 工具对外结构体的名字和字段是什么？我现在用 `NetrixToolDefinition`
   （`id` / `title` / `titleEn` / `description` / `category` / `icon` / `fields` / `run`），
   字段用 `NetrixToolField`（`id` / `label` / `hint` / `initialValue` / `required` /
   `type` / `keyboardType` / `obscureText` / `options`），结果为 `NetrixToolResult`
   （`title` / `summary` / `rows` / `panels` / `ok` / `elapsed` / `error`）。
   如果契约定义了 `NetrixTool` 这样的类型，请说明是「迁移到契约类型」还是「契约接受我的类型」。
3. 每批注册文件的名字和导出名？我现在导出 `netrixBatch2Tools`
   （`List<NetrixToolDefinition>`）和 `netrixBatch2ToolIds`（27 个 id）。
   总注册表按批拼接时用哪个？
4. 可见范围判断接口：第 2 批的 27 个工具全部是「只在主程序显示」。
   我需要一个函数/标记来声明这一点（例如 `netrixToolVisibleInCurrentProfile`）。
   契约里如果已有 `visibility` 字段，我按它改。
5. 显示密度的状态和持久化位置：第 2 批工具本身只提供 `id` / `title` / `titleEn` /
   `description` / `icon` / `category`，两种密度所需的显示数据都在这里。
   密度选择由框架持有即可。我需要确认契约里密度的值名称（netrix 是
   `standard` / `compact`）和落盘位置。
6. 多语言文字的写法：netrix 的错误是错误键（例如 `error_cidr_format`），
   由详情页把键翻成人话。第 2 批会抛出这些键。契约要求：
   - 键放在哪里（我现在不动 `studio_localizations.dart`，等契约指定位置再追加）。
   - 第 2 批涉及的新键清单见下面第 3 节。
7. 新依赖的加法：第 2 批需要 `web_socket_channel`（我已加在内核 `pubspec.yaml` 的
   `dependencies` 末尾）。netrix 用 `^2.4.5`，但该版本会把整包依赖里的 `web`
   从 `1.1.1` 降到 `0.5.1`。我改用 `^3.0.3`，只多引入 `web_socket 1.0.1`。
   如果契约必须与 netrix 版本一致，请说明，我改回 `^2.4.5`。
8. 骨架提交哈希：契约发布后请写入 `git merge <哈希>` 用的那个哈希。

## 2. 我已经完成、不依赖契约的部分

- `research/netrix-tools-inventory.md`（52 个工具、分批、现有工具判重表、能力差异表）。
- 第 2 批 27 个工具的 1:1 逻辑层：地址/子网 13 个 + 网络 14 个。
- 26 个测试，覆盖默认值、结果行、错误键、限额边界。全部离线，不访问网络。
- 提交 6 个（`ui/pi-d`，内核仓库），`flutter analyze` 与 `flutter test test/tools` 通过。

## 3. 第 2 批用到的错误键（详情页需要能翻译）

`error_required`、`error_whitespace`、`error_invalid_url`、`error_port_range`、
`error_port_segment`、`error_port_segment_range`、`error_port_limit`、
`error_port_invalid`、`error_no_ports`、`error_ipv4_segments`、`error_invalid_ipv4`、
`error_ipv4_octet`、`error_ipv4_prefix`、`error_cidr_format`、`error_invalid_ip`、
`error_mac_format`、`error_subnet_prefix_range`、`error_subnet_limit`、
`error_range_order`、`error_cidr_result_limit`、`error_no_cidr`、`error_cidr_limit`、
`error_non_contiguous_mask`、`error_port_range_format`、`error_port_range_order`、
`error_port_range_limit`、`error_prefix_integer`、`error_host_unresolved`、
`error_connection_timeout`、`error_connection_failed`、`error_port_scan_limit`、
`error_host_port_limit`、`error_host_limit`、`error_private_network_only`、
`error_dns_record_type`、`error_dns_http`、`error_dns_response_large`、
`error_dns_response_format`、`error_dns_timeout`、`error_dns_json`、
`error_dns_failed`、`error_public_ip_http`、`error_public_ip_format`、
`error_public_ip_timeout`、`error_public_ip_json`、`error_public_ip_failed`、
`error_rdap_http`、`error_rdap_response_large`、`error_rdap_response_format`、
`error_rdap_timeout`、`error_rdap_json`、`error_rdap_failed`、`error_tls_certificate`、
`error_tls_timeout`、`error_tls_failed`、`error_local_interfaces`、`error_http_url`、
`error_http_method`、`error_http_body`、`error_http_timeout`、`error_http_failed`、
`error_websocket_url`、`error_websocket_timeout`、`error_websocket_failed`、
`error_header_format`、`error_header_required`。

netrix 的中文文案在 `D:\MyOtherNewProj\netrix\lib\core\localization.dart`
（`_catalog['zh']`）以及 `NetrixLocalizations.errorMessage` 的映射里，可直接照抄。
中文之外的分类文案、结果行标签在 netrix 里本来就是中文硬编码，我保持原样。
