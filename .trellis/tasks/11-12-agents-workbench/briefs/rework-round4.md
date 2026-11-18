# 第四轮：错误详情要说清哪里坏了

先读 `RULES-rework.md`。状态文件换成 `TASK\status\pi-X-rework-4r.md`（X 是你的字母）。最后一条回复：`DONE <该路径>` 或 `BLOCKED <原因>`。

## 第一步（所有人）

在你自己的实现 worktree 里运行 `git merge --ff-only rework/integration`。这是唯一允许的 merge。worktree 必须是干净的。

## 用户的原话

> 这个请求详情也不详细啊，就单一个「无法建立安全连接，请检查设备时间或稍后重试」，能看出哪里的问题？

## 真实情况

大脑查过：真机和电脑在同一个局域网。到 `qfli.suanxiwanjie.cn` 的 TLS 握手在握手这一步被断开。同一个 Cloudflare IP，换成域名 `newapi.azurekiln.cn`，握手 0.2 秒成功。说明问题出在这个域名，不在设备时间，也不在 AI 密钥。

现在的界面只显示一句固定的话。`AgentErrorInfo.detail` 只是 `api.message`。`ApiException.details` 没人用。

## 契约（已在集成分支里）

- `AgentErrorInfo` 新增 `host`（服务器主机名）和 `phase`（`AgentErrorPhase`：dns、connect、tls、timeout、http、response、other）。
- `AgentRuntime.diagnoseConnection()`：返回多行文本。基线是占位，返回空文本。

## pi-B

文件：`lib/services/api_client.dart` 的 AI 调用部分、`lib/vibe_coding/**`。

1. 在 AI 调用的异常处理里，不要只抛一句固定的话。给 `ApiException` 的 `details` 填结构化信息。涉及 `HandshakeException`（约第 291、1000、1388 行）、`SocketException`、`TimeoutException`、`HttpException`、`ClientException`。字段：
   - `phase`：dns、connect、tls、timeout、http、response。
   - `exception`：异常类型名，例如 `HandshakeException`。
   - `osMessage`：系统给出的原文。
   - `host`、`method`、`path`。path 不带查询串。
   - `elapsedMs`：从发起到失败的毫秒数。
   - `requestId`：服务器返回的 `X-Request-Id`，没有就省略。
   - HTTP 错误时：状态码、服务端的 `error` 文案或前 200 个字符。
2. 保留友好的 `message`，但要写明主机和步骤。例如「连不上服务器 qfli.suanxiwanjie.cn：TLS 握手失败」。
3. 「请检查设备时间」只在证书错误且含有「expired」或「not yet valid」时才出现。其他握手失败不要提设备时间。握手被断开时写「握手被断开，常见原因：当前网络拦截了这个域名，或服务器证书、代理配置有问题」。
4. `VibeAgentFacade.lastErrorInfo` 用这些字段填 `AgentErrorInfo`：`host`、`phase`、`statusCode`、`detail`。`detail` 是多行文本，例如：
   ```
   请求：POST /api/ai/chat
   服务器：qfli.suanxiwanjie.cn
   失败步骤：TLS 握手
   异常：HandshakeException
   系统信息：Connection terminated during handshake
   用时：8.2 秒
   设备时间：2026-11-14 12:03:11 +08:00（UTC 04:03:11）
   请求 ID：abc123
   ```
5. 禁止把这些放进 `detail`：Authorization 头、令牌、请求正文、查询串。
6. 实现 `ApiClient.probeConnection()` 和 `VibeAgentRuntime.diagnoseConnection()`。只连接 API 服务器，不连接任何其他主机。每一步超时 6 秒。返回文本例如：
   ```
   服务器：qfli.suanxiwanjie.cn
   ① 域名解析：成功，172.67.140.164、104.21.70.240（0.04 秒）
   ② TCP 连接 443：成功（0.12 秒）
   ③ TLS 握手：失败，HandshakeException（6.0 秒）
   结论：能连到服务器的 IP，但 TLS 握手被断开。试试换一个网络，比如手机流量。
   ```
   结论按失败的步骤写：域名解析失败写检查网络和 DNS；TCP 失败写服务器端口不通或被拦；TLS 失败如上；全部成功写连接正常，问题可能在服务端返回。
7. 测试，用注入的假网络层：dns 失败、连接被拒、TLS 失败、超时、HTTP 502 带请求 ID。断言 `phase`、`host`、`detail` 内容。再断言：把令牌设为一个假字符串，`detail` 里找不到它。

## pi-C

文件：`lib/chat/**`、`lib/shell/workbench_agent_pane.dart`。

1. 错误卡片的标题用 `lastError` 的友好文案，它现在会带主机和步骤。没有 `host` 时保持原样。
2. 「详情」展开后，用等宽字体显示 `detail`，可以选中文字。
3. 详情里加「复制」按钮。复制 `detail` 加一行「复制于 <设备时间>」。
4. 当 `phase` 是 dns、connect、tls、timeout 时，显示「诊断连接」按钮。点击后调 `runtime.diagnoseConnection()`，运行中显示转圈，完成后把结果追加到详情下面。再点可以重新诊断。
5. 不要自动诊断。只在用户点击时才发起。
6. 测试：
   - 详情显示多行 `detail`，含主机名和步骤。
   - 复制按钮把文本写进剪贴板（用 `SystemChannels.platform` 的 mock）。
   - `phase` 是 tls 时有「诊断连接」，是 http 时没有。
   - 点击后调用 `diagnoseConnection` 一次，结果出现在详情里。
   - 窄屏 390 宽无溢出，文字缩放 1.3 无溢出。
7. 在 `FakeAgentFacade` 里加字段来设置 `errorInfo` 的 `host`、`phase`、`detail`。

## 追加：真机截图发现的两个问题（大脑，第四轮）

证据：`TASK\check\screens\device\02-open-project.png`、`06-agent-panel.png`、`10-send-later.png`。手机逻辑宽约 424。

### pi-A：顶栏标题被挤成「Ba…」

1. 现象：项目名只显示「Ba…」，文件路径只显示「src/M…」。原因：顶栏多了一个机器人图标，标题只剩约 50 宽。
2. 窄屏和中屏已经有「编辑器 | Agent」分段，顶栏的机器人图标是重复的。改法：
   - 只在宽屏（有右栏）时，顶栏显示机器人图标。
   - 窄屏和中屏不显示它。
   - 后台会话待确认或失败的角标，改挂在分段条的「Agent」上。
3. 菜单里的「AI 助手」保留。
4. 测试：宽度 424，开关开启和关闭两种情况，标题文字的渲染宽度相同。宽屏的图标和角标测试保持通过。
5. 还要检查：「编辑器 | Agent」分段在 424 宽下不溢出，点击目标不小于 44×44。

### pi-C：权限按钮有空位也只显示图标

1. 现象：手机上输入卡片的权限按钮只有盾牌图标，没有「每次询问」。模型按钮和发送键之间有大片空白。
2. 原因：按屏幕宽度分档，不是按实际可用宽度。
3. 改法：工具行用 `LayoutBuilder` 的可用宽度来决定。先尝试全部带文字。放不下时，按这个顺序收起文字：推理强度，权限。模型名最后收。有空位就显示权限文字。
4. 测试：宽度 424、字体缩放 1.0，权限显示「每次询问」。宽度 360 或缩放 1.3 时不溢出。
