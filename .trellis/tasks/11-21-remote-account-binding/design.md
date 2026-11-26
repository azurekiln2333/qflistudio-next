# 技术设计：桌面端与手机端远程互联

## 改动边界

- 预览版手机端已连接桌面 companion。
- Companion 已读取 Herdr、Claude 和 Codex 会话。
- Windows 助手显示二维码和一次性配对码。
- macOS、Linux 启动脚本显示一次性配对码。
- QFLI 后端缺少 relay 授权票据。
- Relay 账号接口存在令牌和撤销缺口。
- 本任务扩展现有登录、配对和会话链路。
- 本任务不改 CloudTerminal 原仓和已发布版本。

## 隔离工作树

从已验证的远程功能预览提交创建工作树。

| 仓库 | 基线 | 工作树 |
| --- | --- | --- |
| Studio | 6d1b96d | D:/MyNewProjects/_wt/remote-account-binding/studio |
| Core | 72c0b09 | D:/MyNewProjects/_wt/remote-account-binding/core |
| QFLI 服务 | d919a91 | D:/MyNewProjects/_wt/remote-account-binding/qfli-server |
| Relay 服务 | 841cc86 | D:/MyNewProjects/_wt/remote-account-binding/relay-server |

每个工作树使用新分支。不得修改主仓和已有迁入工作树。

## 产品流程

1. 桌面 companion 启动后连接 relay。
2. companion 申请并显示一次性配对码。
3. Windows 助手同时显示二维码和配对链接。
4. macOS、Linux CLI 同时显示配对链接。
5. 手机用户登录 QFLI 账号并查看电脑列表。
6. 手机把一次性配对码交给 relay 完成绑定。
7. 手机用 relay 令牌连接账号授权的电脑。
8. 撤销后 relay 回收令牌并断开手机连接。

桌面 companion 继续读取本机 Herdr、Claude 和 Codex 会话。
手机端保留终端、会话、问题和权限处理。
远程批准仍由用户显式操作。

## 身份和令牌

- QFLI 登录令牌只发送到 QFLI 服务。
- QFLI 服务从已验证会话读取网关 sub。
- 远程授权使用现有手机号实名门槛。
- QFLI 创建 60 秒单次票据并限制 audience 和 scope。
- QFLI 只存票据哈希，不记录票据明文。
- Relay 通过服务端认证调用 QFLI introspection。
- Relay 检查 issuer、sub、audience、scope 和有效期。
- Relay 只签发自己的 access 和 refresh 令牌。
- Relay access 有效期为 15 分钟。
- Relay refresh 有效期为 30 天，每次刷新都要新票据。
- Studio 为 relay 令牌新增独立安全存储。
- Relay 令牌不进入 auth.json 或配对配置文件。

## HTTP 契约

Studio 向 QFLI 请求短期 relay 票据。

POST /api/relay/grants
请求：audience=cloudterminal-relay，scope=relay.connect。
响应：grant、expires_at、audience。

Relay 用 Basic 认证查询 QFLI 票据。

POST /api/relay/introspect
请求：grant。
响应：active、iss、sub、aud、scope、exp、name。

Studio 用票据向 relay 换取 relay 令牌。

POST /api/v1/auth/exchange
请求：grant。
响应：account_id、access_token、refresh_token。
到期字段：access_expires_at、refresh_expires_at。
两个到期字段均使用 ISO 8601 字符串。

账号查询和绑定使用 relay access。

GET /api/v1/devices 返回当前账号的设备列表。
POST /api/v1/devices/bindings 请求 pair_code。
POST /api/v1/devices/:deviceId/bindings 请求 pair_code。
DELETE /api/v1/devices/:deviceId/bindings/:accountId 撤销绑定。

手机用短码直接调用首个绑定接口。
Relay 从配对码读取设备 ID。
绑定响应包含 device_id。
手机不得先消费旧配对码来查询设备 ID。

令牌刷新同时提交 relay refresh 和新的 grant。
Relay 要求 introspection 的 sub 与 refresh 所属账号一致。
客户端不得提交账号主键作为授权依据。

## 设备绑定

- Relay 数据库作为账号设备关系的唯一数据源。
- 手机用 relay access 查询账号设备列表。
- 绑定请求提交一次性配对码。
- 已知设备 ID 时可使用原绑定接口。
- Relay 先消费配对码，再创建设备和账号关系。
- 首个有效账号成为设备 owner。
- Relay 只接受 access 类型令牌访问设备接口和 WebSocket。
- 未绑定设备继续支持旧配对密钥流程。
- 绑定设备不得用旧客户端密钥绕过账号授权。
- 撤销时回收该设备令牌并断开对应连接。
- 重置设备时轮换设备 ID 和配对密钥。

## Relay 安全修复

- pair_code 绑定前确保 relay 设备记录存在。
- device/start 不接受匿名调用方覆盖 secret_hash。
- device/poll 检查 state 和设备授权状态。
- 首个绑定账号获得 owner 角色。
- Relay 按 token kind 检查 access 和 refresh。
- 撤销时立即禁用 access、refresh 和活跃连接。
- 已撤销设备不能用旧密钥重新连接。
- 账号隔离覆盖列表、绑定、会话和撤销接口。

## 桌面配对和会话

- Studio 桌面版增加本机配对和 Agent 会话页面。
- Studio 桌面页复用现有 sidecar 和配对协议。
- 三种桌面版显示状态、地址、短码、二维码和倒计时。
- 三种桌面版提供配对链接复制和刷新操作。
- 桌面页读取真实 Herdr、Claude 和 Codex 会话。
- macOS、Linux 保留 CLI 启动方式作为备用路径。
- 三种系统使用同一配对 URI 和配对码规则。
- 空状态和错误状态不得创建伪造会话。
- 日志不得包含配对密钥或账号令牌。
- Windows 助手继续作为独立兼容入口。
- macOS 保留 app sandbox，不增加全盘访问权限。
- macOS 子进程受限时，提供可用的外部 companion。
- 桌面页检查外部 companion 的随机附着凭据。
- 沙箱内桌面页必须能读取附着信息。
- macOS 用户通过文件选择器读取附着文件。
- Studio 只申请用户所选文件的只读权限。

## 手机账号界面

- Core 增加我的电脑列表和刷新入口。
- 列表显示电脑名称、平台、在线状态和最后在线时间。
- 用户可通过现有配对页添加电脑。
- 用户可撤销自己的绑定。
- owner 可撤销该设备的其他账号绑定。
- relay 撤销当前设备绑定后，手机立即断开会话。
- 登录失效、relay 不可用和空列表分别显示。
- 账号服务失败时，手动配对仍保持可用。

## 四个 Pi 的写入边界

Pi mobile 负责手机端账号设备管理。

- Core：新增 relay API、账号存储和设备列表页面。
- Core：新增账号 scope，并从现有 AuthStore 读取登录态。
- Core：在配对页和已连接页提供我的电脑入口。
- 不改桌面入口、companion 和服务端。

Pi desktop 负责 Studio 桌面端本机入口。

- Studio：修改 studio_tools_tab.dart 并区分桌面和手机入口。
- Core：新增桌面本机页和本机 sidecar 客户端。
- Studio：完善 companion 配对链接和 Agent 会话状态。
- 不改账号设备列表、QFLI grant 和 relay 授权。

Pi qfli 负责 QFLI relay grant。

- QFLI 服务：票据表、签发接口、introspection 和测试。
- 票据绑定已验证 session 和 gateway sub。
- 不改 Studio、Core、companion 和 relay 服务。

Pi relay 负责账号授权和撤销安全。

- Relay 服务：换票、绑定、刷新、撤销和连接踢除。
- 修复账号隔离、设备登记和 token kind 检查。
- 不改 Studio、Core、companion 和 QFLI 服务。

## 检查要求

- QFLI 检查未登录、未实名、过期和重复消费。
- Relay 检查 token 类型、设备隔离、绑定和撤销。
- Flutter 检查设备列表、登录失效和手动配对。
- Companion 检查链接、刷新、过期、离线和敏感字段。
- CI 覆盖 Windows、macOS 和 Linux 的 companion 路径。
- 真实手机配对仍需设备验收。

## 回退

回退账号客户端即可恢复手动配对流程。
服务端不得恢复已经撤销的设备令牌。
数据库迁移必须提供回滚步骤。
