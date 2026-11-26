# 实施契约

## 已确认事实

- 预览版已有手机端远程电脑页面和会话协议。
- 桌面工具入口仍打开手机侧配对页面。
- Windows companion 有图形配对页。
- macOS、Linux companion 只有命令行配对页。
- 手机端未实现 QFLI 账号设备列表和撤销。
- QFLI JWT 不能直接交给 relay。
- Relay 账号模块已有雏形，但当前 token 检查和撤销不完整。

## 固定决策

- PC Studio 是远程主机界面。
- 手机 Studio 是远程客户端和账号管理界面。
- QFLI 登录是唯一用户身份。
- Relay 的 account_id 来自 QFLI 已验证的 gateway sub。
- QFLI 签发 60 秒单次 relay grant。
- Relay introspection 后签发自己的 access 和 refresh。
- Relay 数据库是设备关系的唯一数据源。
- 首个设备账号获得 owner 角色。
- 被撤销设备不能用旧 access、refresh 或配对密钥重连。
- 未绑定账号的设备保留旧手动配对流程。

## 角色报告

- 桌面：research/pi-desktop.md、research/pi-platform.md。
- 手机：research/pi-mobile.md。
- 服务：research/pi-account.md。
- PI 按 implement.md 的目录边界写入。

## 不能改变

- 不把 QFLI JWT 发送给 relay。
- 不把 relay token 写入 auth.json 或设备配对文件。
- 不记录 grant、token、secret 或用户代码。
- 不允许 refresh token 通过 WebSocket access 校验。
- 不恢复撤销设备的旧凭据权限。
- 不修改 CloudTerminal 原仓、主仓或现有迁入工作树。
