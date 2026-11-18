# pi-B 第四轮

## 已完成

- 第一步：worktree 干净，`git merge --ff-only rework/integration` 成功（e43cfe2 → 318e443）。
- 新增 `lib/services/connection_probe.dart`：`ConnectionProbe`（`lookup` / `connect` / `handshake` 三步）加真机实现 `SocketConnectionProbe`。测试注入假实现，不碰真实网络。
- `lib/services/api_client.dart`：`_send`、`_aiChatDirect` 的异常处理不再只抛一句固定文案。
  - `details` 填 `phase`、`exception`、`osMessage`、`host`、`method`、`path`（不含查询串）、`elapsedMs`；HTTP 错误另填 `statusCode`、`serverError`（截 200 字符）、`requestId`（先取 `x-request-id` 头，再退回响应体的 `requestId`）。
  - `SocketException` 按文案区分 `dns` 与 `connect`；`TimeoutException` → `timeout`；`HandshakeException` → `tls`；`HttpException` → `http`；`FormatException` → `response`。
  - 友好文案带主机与步骤：「连不上服务器 qfli.suanxiwanjie.cn：TLS 握手失败」。
  - 「请检查设备时间」只在系统原文含 `expired` 或 `not yet valid` 时出现；其他握手失败写「握手被断开」。
  - 无服务端 `error` 文案的 HTTP 错误改为「服务器 <host> 返回 <code>，请稍后重试」，不再只写「服务暂时不可用」。
  - 新 `ApiClient.probeConnection()`：只连 API 服务器，逐步报解析、TCP、TLS，每步 6 秒超时，返回多行文本加结论；本方法不抛异常。
- `lib/services/api_client.dart` 在线终端流：三处 `HandshakeException` 之一（简报第 1000 行）同样填 `details`；终端原有文案保留，只把握手失败文案改成带主机。
- `lib/vibe_coding/vibe_agent_facade.dart`：
  - `lastErrorInfo` 填 `host`、`phase`、`statusCode`，`detail` 改为多行：请求、服务器、失败步骤、状态码、异常、系统信息、服务端信息、用时、设备时间（含 UTC）、请求 ID、建议。
  - `phase` 是 dns / connect / tls 时归到 `AgentErrorKind.offline`，`timeout` 归 `timeout`。
  - `VibeAgentRuntime.diagnoseConnection()` 接到 `ApiClient.probeConnection()`。
- 新增 `test/agent_connection_error_test.dart`（17 例）：dns 失败、连接被拒、握手被断开、证书过期提设备时间、超时、HTTP 502 带 `X-Request-Id`、直连上游主机与路径、令牌不出现在 `details`；诊断的 dns / connect / tls / 超时 / 全通五条结论，并断言只连 API 主机、端口 443；会话级 `AgentErrorInfo` 的多行 `detail`、502 状态码与请求 ID、令牌脱敏、运行时诊断转发。
- 提交：`3ddf2db`（AI 错误详情与诊断）、`6614251`（终端流同款 details）。

## 进行中

- 无。

## 请求

- pi-C：`AgentErrorInfo.detail` 现在是多行文本，`phase` 用于决定是否显示「诊断连接」。令牌、授权头、请求正文、查询串都不会进 `detail`。
- 大脑：`_send` 的网络失败文案改成带主机与步骤（例如「连不上服务器 <host>：域名解析失败…」），全应用共用这个客户端。若其他页面对旧文案有硬编码断言，需要一起改。

## 未验证

- 真机未跑第四轮：TLS 被断开这条路径只有假网络层覆盖，真机证据要等 pi-D。
- `probeConnection` 的真机实现（`SecureSocket.connect`）未在本机跑，6 秒超时只在假实现里验证。
- `interop_arkts_contract_test` 的 1 项失败未修：worktree 同级缺完整 `qfli_java`，跨范围。
- 全量测试：`flutter test --no-pub --concurrency=2` → `+1641 ~9 -4`，失败仅 `editor_run_target_test` 3 项与 `interop_arkts_contract_test` 1 项（均为允许口径）。`flutter analyze --no-pub`：No issues found。
