# 接口契约（2026-11 合规整改）

## A. W4 网关统一账号永久注销（azurekiln-oauth2-c6 于 2026-11-02 给出，W2a 调用）
POST {AZK_OAUTH2_BASE_URL}/oauth2/account/erase
- 鉴权：client credentials，Authorization: Basic base64(client_id:client_secret)，或 JSON body 带 client_id/client_secret。客户端须为 qflistudio 客户端（client_id 前缀 qfli），且有 scope `qfli_account_erase`（需网关管理员授予）。
- 请求体：{"user_id":"<网关用户ID=id_token 的 sub>","reason":"user_request"（可选，≤64）,"request_id":"<可选，≤64，幂等>"}
- 200：{"user_id","status":"deleted"|"already_deleted","deleted_at":"ISO8601","tokens_revoked":true}；幂等，500 可重试。
- 错误 {error,error_description}：400 invalid_request；401 invalid_client；403 access_denied / insufficient_scope；404 user_not_found；409 conflict；429 rate_limited；500 server_error。
- 效果：吊销该用户全部令牌、授权码、会话；删除外部身份绑定、TOTP、应用使用记录；用户行变墓碑并清空个人信息，之后无法登录；法定登录日志保留但用户名与用户ID不可逆去标识化。同一华为账号可重新注册，得到新用户ID。
- 网关确认（2026-11-02）：base URL 用现有 AZK_OAUTH2_BASE_URL（网关 issuer 根地址）；client_id/secret 用现有 qfli 客户端，client_id 必须以 qfli 开头（不区分大小写）。scope `qfli_account_erase` 须由用户本人在网关后台勾选，未授予前调用会得到 403 insufficient_scope：实现要把这种情况当作可重试的失败，记审计并提示，不得假装注销成功。

## B. W1 审核服务 API
唯一来源：D:/MyNewProjects/azurekiln-moderation/README.md（W1-core 先写）。W2b 与 W4 只通过 packages/client 接入。

## C. QFLI 服务端 ↔ 客户端（W2 ↔ W3，双方必须一致）
- 请求头：X-Client-Platform: harmonyos-app/<版本号>（其他平台 android-app/、ios-app/、windows-app/、macos-app/、linux-app/、web/）。服务端据此记录 platform。
- 错误体：{error, errorKey, message}。
  - 403 realname.required：无已验证手机号；客户端引导华为账号绑定手机号。
  - 403 huawei.phone_required：华为账号没有已验证手机号（服务端本地判断 phoneAvailable===false，或网关返回 huawei_verified_phone_required 时统一转换），message 为“请使用已绑定手机号的华为账号”；客户端在华为登录/绑定流程中显示该 message。
  - 403 account.banned / account.muted：被封停 / 被禁言。
  - 429 rate.limited：带 retryAfter（秒）。
  - 422 moderation.blocked：文本命中，带 categories（不回显命中词原文）。
  - 503 moderation.unavailable：message 为“审核服务暂不可用”（发布类 failClosed）。
- 帖子/评论 status："published" | "pending" | "rejected"；pending 仅作者与管理员可见，客户端显示“审核中”。
- AI 响应带 aiGenerated: true。
- POST /api/reports {targetType:"post"|"comment"|"user", targetId, reason} → 201 {id, status}。
- POST /api/users/me/deactivate {confirm:"DEACTIVATE"} → 200 {status:"deactivated"}；之后该账号所有会话失效。
