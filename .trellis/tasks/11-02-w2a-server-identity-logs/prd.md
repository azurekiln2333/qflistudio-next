# W2a 日志、可信代理、实名门槛、华为登录、注销、AI、联网搜索下线
仓库：qflistudio/azurekiln-qfli-server。需求：§3-W2 对应条目与 §1 口径。

## 范围
- 日志：audit.js RETENTION_DAYS=365；db.js 里 SQLite 与 MySQL 两处清理语句同改；审计表加 port、platform、login_type；登录、注册、登出都记录；平台取 X-Client-Platform。
- 可信代理：不再信任客户端 X-Forwarded-For；只信 X-Real-IP/X-Real-Port 或正确配置 trust proxy；nginx 加 `proxy_set_header X-Real-IP $remote_addr;` 与 `proxy_set_header X-Real-Port $remote_port;`（仓库里的 nginx 示例与部署配置同改）。
- 实名门槛中间件：无已验证手机号 → 403 realname.required；在挂载层统一套到社区浏览/发帖/评论/点赞/举报、云项目、在线终端、AI、SQL 沙箱；本地内置教程不受影响。
- 华为登录：/huawei/skip、/huawei/bind 在 phoneAvailable===false 时拒绝，提示“请使用已绑定手机号的华为账号”。
- 联网搜索下线：不再调用 www.bing.com，web_search 不再对外暴露；web_fetch 保留。
- AI：响应加 aiGenerated: true；核对并写明线上 QFLI_AI_BASE_URL 只转发到 DeepSeek 官方接口。
- 永久注销：POST /api/users/me/deactivate（contracts.md C 节）；删除本站数据（级联）与 data/cloud/u<id>、data/terminals/u<id>；调用网关 erase（contracts.md A 节）；吊销全部会话；审计保留 365 天但个人标识去标识化；即时完成。

## 边界
W2b 负责社区路由内部、admin 路由、举报、限流、封停、审核接入。你不改 src/routes 下社区与 admin 路由文件内部；实名中间件在挂载层加。db.js 只改审计/保留期/注销相关，写成独立函数，小步提交。先不要部署（root 另行指示）。

## 验收
§4 第 1、2、3（服务端）、7、9（服务端）条。
