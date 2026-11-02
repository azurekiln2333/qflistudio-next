# QFLI 服务端验收记录（2026-11-02）

最新本地复测：86 项断言全部通过。
原先 5 项失败均已通过复测。
线上配置和真实网关效果仍需补证。
最终结果见文末的第二次修复复测。

本报告负责 PRD 分工表的 w37:p7。
验收范围为第 1、2、3、5、6、7、9 项。
第 3、7、9 项仅含服务端部分。
验收者未实现 QFLI 服务端。
业务文件始终只读。

## 初验结论

初验完成 84 项断言。
79 项通过，5 项失败。
5 项失败对应 4 类缺口。
服务端尚未通过完整验收。

| 条目 | 本地结论 | 主要证据 |
|---|---|---|
| 1 | 失败 | 注册审计的用户 ID 为空 |
| 2 | 通过 | 无手机号与明确未验证手机号均返回 403 |
| 3 服务端 | 通过 | 本地拒绝与网关错误映射均返回 403 |
| 5 | 通过 | 管理员删除留痕，举报可提交、处理和查询 |
| 6 | 失败 | 限流和不公开通过，管理员看不到待审帖子 |
| 7 服务端 | 失败 | 注销审计残留原 ID，失败注销未写审计 |
| 9 服务端 | 通过 | 搜索接口返回 404，AI 响应带标识 |

线上配置、nginx 源端口与部署均为**部署后复测**。
真实网关的永久注销效果为**未验证**。
真实华为账号流程为**未验证**。
长期注册信息留存为**未验证**。
以上结论不含客户端验收。

## 环境与证据

初验时间为 2026-11-02 17:19:23 至 17:19:25。
时区为 UTC+08:00。
QFLI 与审核服务均启动真实 Node 进程。
两项服务分别使用临时 SQLite。
网关与 AI 使用本地 HTTP 夹具。
账号、手机号与 IP 均为测试数据。
证据已删除令牌、密码与凭据。



~~~json
{
  "qfliRevision": "af5829dd1b78eac67b920218c373b1d75f1e7a71",
  "moderationRevision": "6d6754c907b1e3b6caf162a55a2292edc6469022",
  "node": "v24.15.0",
  "sdkSha256": "e63df6cf97b73fb67dcf33d41b0a5b1c42ea20f1c1908374ef3a337c9fcaaab5",
  "sourceChangesDuringRun": [],
  "checks": 84,
  "passed": 79,
  "failed": [
    "1.fields.auth.register",
    "6.pending-admin-visible",
    "6.pending-list-admin",
    "7.audit-all-identifiers-removed",
    "7.failed-erase-audited"
  ]
}
~~~

证据根目录记为 E：


~~~text
D:/AppData/Local/Temp/qfli-server-acceptance-20261102-p7-099baf6f149948bd8f53bc88445de02a/run-1793611163252
~~~

| 文件 | 内容 |
|---|---|
| E/http-and-db.json | 每次请求、原始响应及数据库摘录 |
| E/checks.json | 84 项断言及判定 |
| E/gateway.json | 网关请求形状与夹具响应 |
| E/processes.json | 子进程输出与退出结果 |
| E/manifest.json | 版本、工作树状态与源码哈希 |
| E/summary.json | 本轮汇总 |

复现脚本保留在临时目录。
每次启动均另建数据目录。
脚本结束时关闭自己的服务进程。


~~~powershell
node "D:/AppData/Local/Temp/qfli-server-acceptance-20261102-p7-099baf6f149948bd8f53bc88445de02a/server-acceptance-initial.mjs"
~~~

脚本 SHA-256：


~~~text
1dd0ff762e3a4c56e3c19b22d607941c126212bd35a50d6c7b24768a1e4c1816
~~~

初验保留独立的响应摘录。
后续复测将在本文末尾追加。

## 1. 日志字段与保留期

**条目原文**

~~~text
登录、注册日志包含用户ID、平台、登录类型、IP、端口、时间；代码和线上配置中的保留期都是 365 天。
~~~

**验证方法**

提交密码登录、华为登录、注册和登出请求。
请求头使用测试平台及代理字段。
管理员随后查询审计接口。


~~~text
X-Client-Platform: harmonyos-app/acceptance
X-Real-IP: 198.51.100.17
X-Real-Port: 45678

POST /api/auth/login
{"username":"accept_login","password":"[REDACTED]"}
POST /api/auth/huawei
{"authorizationCode":"verified"}
POST /api/auth/register
{"username":"acceptance_new","email":"acceptance@example.invalid","password":"[REDACTED]","emailCode":"[REDACTED]"}
POST /api/auth/logout
{}
GET /api/audit?action=auth.register
~~~

将两条审计时间改成 366 天前。
保留另一条 364 天前的审计。
停止服务后调用真实数据库启动逻辑。
只在本轮临时 SQLite 中改时间。

**实际结果**

登录与登出响应均为 HTTP 200。
密码登录审计包含全部要求字段。


~~~json
{
  "user_id": "user_1cae6a09655a9386db445f4c55f4c6f6",
  "platform": "harmonyos-app",
  "login_type": "password",
  "ip": "198.51.100.17",
  "port": 45678,
  "created_at": "2026-11-02 09:19:24"
}
~~~

注册响应为 HTTP 200。
注册审计的用户 ID 为空。


~~~json
{
  "id": "audit_9d23068ed8f736ccfde04e848eb689aa",
  "user_id": null,
  "username": "acceptance_new",
  "action": "auth.register",
  "target": null,
  "detail": null,
  "ip": "198.51.100.17",
  "user_agent": "node",
  "created_at": "2026-11-02 09:19:24",
  "port": 45678,
  "platform": "harmonyos-app",
  "login_type": "register"
}
~~~

366 天前的登录与注册审计均删除。
364 天前的登录审计仍存在。


~~~json
[
  {
    "id": "audit_b7cfb151700701fa521427bf3cbe922c",
    "action": "auth.password_login",
    "created_at": "2025-11-03 09:19:25"
  }
]
~~~

伪造的 X-Forwarded-For 未进入审计。
非法代理字段回退到本机 socket。


~~~json
{
  "ip": "127.0.0.1",
  "port": 63706,
  "platform": "harmonyos-app",
  "login_type": "password"
}
~~~

**结论：失败。**
注册日志缺少用户 ID。
本地 SQLite 的 365 天清理通过。
MySQL 清理语句的静态口径为 365 天。
本机没有验证真实 MySQL 清理。
注册信息与注册审计采用不同口径。
长期注册信息需真实网关证据。
线上保留期及代理源端口为部署后复测。

**证据路径**：E/http-and-db.json，记录键为 1.*。
代码位置为 src/routes/auth.js 的注册审计调用。
清理位置为 src/db.js 与 src/audit-retention.js。
代码路径均相对 azurekiln-qfli-server/。

## 2. 手机号门槛

**条目原文**

~~~text
没有手机号的账号，使用社区、云项目、终端、AI、SQL 都被拒绝，并有绑定引导。
~~~

**验证方法**

以无手机号账号发出 19 次真实请求。
另测手机号明确未验证的账号。
已验证账号作为对照组。
请求涵盖以下接口。


~~~text
GET /api/zones
GET /api/tags
GET /api/posts
GET /api/posts/:id
POST /api/posts
POST /api/posts/:id/comments
GET /api/posts/:id/comments
POST /api/posts/:id/like
POST /api/reports
GET /api/cloud/projects
GET /api/terminal/pwd
GET /api/sql/databases
POST /api/ai/chat
GET /API/POSTS?acceptance=1
GET /api/posts/
GET /API/CLOUD/projects?x=1
GET /API/TERMINAL/pwd
GET /API/SQL/databases
POST /API/AI/chat
~~~

**实际结果**

19 次请求均返回 HTTP 403。
响应均包含绑定手机号引导。


~~~json
{
  "error": "请先绑定手机号",
  "errorKey": "realname.required",
  "message": "请使用已绑定手机号的华为账号登录"
}
~~~

明确未验证的手机号同样返回 403。
已验证账号查询专区返回 200。
兼容场景另有以下结果。


~~~json
{
  "explicitUnverified": {
    "status": 403,
    "contentType": "application/json; charset=utf-8",
    "body": {
      "error": "请先绑定手机号",
      "errorKey": "realname.required",
      "message": "请使用已绑定手机号的华为账号登录"
    }
  },
  "legacyPhoneWithoutFlag": {
    "status": 200,
    "meaning": "phone_number present, phone_number_verified omitted"
  },
  "anonymous": {
    "status": 200,
    "total": 1
  }
}
~~~

**结论：通过。**
本地账号门槛及路径变体通过。
旧网关仅提供手机号时仍可访问。
匿名浏览仍返回 200。
真实网关的验证字段可信度尚未验证。

**证据路径**：E/http-and-db.json 的 2.*。
代码位置为 src/client-context.js。

## 3. 华为跳过与绑定拒绝

**条目原文**

~~~text
没有手机号的华为账号无法跳过绑定直接建号；鸿蒙端看不到“其他方式登录”和注册入口。
~~~

**验证方法**

夹具返回 phone_available:false。
分别取得跳过与绑定所需的挑战。
向 QFLI 提交跳过和绑定请求。
再测网关的三种拒绝响应。


~~~text
POST /api/auth/huawei
{"authorizationCode":"no-phone-binding"}
POST /api/auth/huawei/skip
{"bindingId":"[REDACTED]"}
POST /api/auth/huawei/bind
{"bindingId":"[REDACTED]","username":"accept_login","password":"[REDACTED]"}

Upstream 403:
{"error":"huawei_verified_phone_required","error_description":"Verified phone required"}
~~~

**实际结果**

本地跳过与绑定均返回 HTTP 403。
两次拒绝均未调用上游跳过或绑定接口。


~~~json
{
  "error": "请使用已绑定手机号的华为账号",
  "errorKey": "huawei.phone_required",
  "message": "请使用已绑定手机号的华为账号",
  "requestId": "9b2e411f-7167-474c-ace1-71189f06338d"
}
~~~

网关 quick-login、skip、bind 的拒绝均完成映射。
统一错误键为 huawei.phone_required。


~~~json
{
  "error": "请使用已绑定手机号的华为账号",
  "errorKey": "huawei.phone_required",
  "message": "请使用已绑定手机号的华为账号",
  "requestId": "754fd13b-c081-48bd-afb9-28c957fef5db"
}
~~~

**结论：通过。**
本地拒绝和接口错误映射均通过。
真实华为账号及真实网关行为未验证。
鸿蒙入口属于客户端验收范围。

**证据路径**：E/http-and-db.json 的 3.*。
上游调用证据为 E/gateway.json。
代码位置为 src/routes/auth.js 与 src/gateway.js。

## 5. 管理员删除与举报

**条目原文**

~~~text
管理员能删除他人的帖子和评论，并有处置记录；举报可以提交、处理和查询。
~~~

**验证方法**

普通账号先创建帖子和评论。
另一普通账号尝试管理员删除。
管理员先提交无原因删除。
管理员随后带原因删除他人内容。
再提交、处理并查询举报。


~~~text
DELETE /api/admin/comments/:id
{"reason":"Acceptance comment removal reason"}
DELETE /api/admin/posts/:id
{"reason":"Acceptance post removal reason"}
POST /api/reports
{"targetType":"post","targetId":":postId","reason":"Acceptance report reason"}
GET /api/admin/reports?status=open
PATCH /api/admin/reports/:id
{"status":"handled","resolution":"Acceptance administrator handled"}
GET /api/admin/reports?status=handled
GET /api/audit?action=admin.post_delete
~~~

**实际结果**

普通账号的管理员删除返回 403。
无原因删除返回 400。
带原因删除均返回 200 {"ok":true}。
SQLite 中对应内容均不存在。
删除审计包含管理员、目标与原因。


~~~json
{
  "user_id": "user_56ef6a258024f9e24baa9b4381fa743b",
  "action": "admin.post_delete",
  "target": "post:post_f2c514464e391ae4d2ee8ad612a11367",
  "detail": "author=user_b0532261046cdf413acb8dacf3e133d5 reason=Acceptance post removal reason",
  "created_at": "2026-11-02 09:19:24"
}
~~~

举报提交返回 HTTP 201。


~~~json
{
  "id": "report_900bc25a84f26eb5d86f06f066d94102",
  "status": "open",
  "moderationReportId": "cbeb35fb-a255-4b48-ad02-22ded45a6d39"
}
~~~

处理请求返回 200 {"ok":true,"status":"handled"}。
查询结果包含处理人及处理时间。


~~~json
{
  "id": "report_900bc25a84f26eb5d86f06f066d94102",
  "status": "handled",
  "resolution": "Acceptance administrator handled",
  "handler_id": "user_56ef6a258024f9e24baa9b4381fa743b",
  "handled_at": "2026-11-02 09:19:24",
  "forwarded": 1
}
~~~

审核中心收到转发的举报。
本地处理后，中心状态仍为 open。


~~~json
{
  "id": "cbeb35fb-a255-4b48-ad02-22ded45a6d39",
  "status": "open",
  "history": []
}
~~~

**结论：通过。**
本地删除、留痕与举报处理均通过。
本地处理不会自动同步中心处理状态。
本项不据此宣称两处状态一致。

**证据路径**：E/http-and-db.json 的 5.*。
代码位置为 src/routes/moderation-admin.js。
举报代码位置为 src/routes/reports.js。

## 6. 限流、IP 与先审后发

**条目原文**

~~~text
连续快速发帖会被限流；IP 黑名单命中后禁止发布；先审后发打开后，新内容不公开。
~~~

**验证方法**

同一账号连续发帖 4 次。
另一账号连续评论 11 次。
每日限流用临时计数夹具补足 20 次。
再次发帖以验证每日上限。
通过管理员代理新增 IP 黑名单。
再以命中 IP 发帖。
打开本地先审后发开关。
分别查询作者、读者、匿名及管理员视角。
另测审核服务的场景开关。
最后停止审核服务以验证拒绝发布。


~~~text
POST /api/posts
{"type":"discussion","zoneId":":zoneId","title":"Acceptance rate post 4","content":"Acceptance local fixture body","tags":[]}
POST /api/admin/moderation/ip-rules
{"type":"ip","value":"203.0.113.23","reason":"Acceptance blocked address"}
PATCH /api/admin/settings/pre-publish
{"enabled":true}
GET /api/posts/:pendingId
GET /api/posts
PUT /api/admin/moderation/scenes/community.post.title
{"preReview":true}
~~~

**实际结果**

发帖状态依次为 200、200、200、429。
评论前 10 次返回 200，第 11 次返回 429。
第 4 次发帖的响应如下。


~~~json
{
  "error": "发布过于频繁，请稍后再试",
  "errorKey": "rate.limited",
  "retryAfter": 35,
  "scope": "minute",
  "requestId": "af351fe3-5e52-4b33-941d-bc91f5144ac2"
}
~~~

每日限流返回 429，scope 为 day。
IP 黑名单命中返回 403。


~~~json
{
  "error": "当前网络不允许发布内容",
  "errorKey": "moderation.ip_blocked",
  "requestId": "565d1e4c-8fde-4aa4-a293-880a804445f9"
}
~~~

仅伪造 X-Forwarded-For 仍可发帖。
先审后发产生 pending 帖子。


~~~json
{
  "id": "post_faf12961950c5def06fda441e816033e",
  "status": "pending"
}
~~~

作者详情返回 200。
读者与匿名详情均返回 404。
管理员详情也返回 404。


~~~json
{
  "status": 404,
  "contentType": "application/json; charset=utf-8",
  "body": {
    "error": "内容不存在"
  }
}
~~~

管理员列表返回 200，但不含该待审帖子。
待审评论的作者与管理员可见性通过。
读者看不到待审评论。
审核中心场景开关同样产生待审帖子。
封停与禁言均拒绝发帖和评论。
审核服务停止后，发帖返回 503。


~~~json
{
  "error": "审核服务暂不可用",
  "errorKey": "moderation.unavailable",
  "cause": "审核服务暂不可用",
  "requestId": "6294e56d-7551-48ee-bbee-bc279de4707b"
}
~~~

**结论：失败。**
限流、IP 拦截及不公开均通过。
管理员待审帖子可见性违反接口契约 C。
管理员详情和列表分别产生一项失败断言。

**证据路径**：E/http-and-db.json 的 6.*。
失败断言为 6.pending-admin-visible。
另一失败断言为 6.pending-list-admin。
代码位置为 src/routes/posts.js 的列表和详情过滤。

## 7. 永久注销与审计去标识化

**条目原文**

~~~text
App 内可以永久注销账号；注销后无法再登录，个人数据被删除，日志已去标识化。
~~~

**验证方法**

测试账号先创建两条真实会话。
通过 HTTP 创建帖子、评论、点赞及举报。
通过 HTTP 完成签到。
夹具另建云项目行和用户目录。
管理员先禁言该账号，再解除禁言。
随后调用永久注销接口。
直接查询 SQLite 与文件目录。
另以缺少授权范围的账号触发失败。


~~~text
POST /api/users/me/deactivate
{"confirm":"NO"}
POST /api/users/me/deactivate
{"confirm":"DEACTIVATE"}
GET /api/users/me
Authorization: Bearer [OLD_SESSION]

SELECT user_id,username,action,target,detail
FROM audit_logs
WHERE user_id=:erasedId
   OR username=:erasedUsername
   OR target LIKE :containsErasedId
   OR detail LIKE :containsErasedId;
~~~

**实际结果**

错误确认返回 HTTP 400。
正确确认返回 HTTP 200。


~~~json
{
  "status": "deactivated",
  "deactivated": true,
  "retentionDays": 365
}
~~~

注销前的数据计数如下。


~~~json
{
  "users": 1,
  "auth_sessions": 2,
  "posts": 1,
  "comments": 1,
  "likes": 1,
  "cloud_projects": 1,
  "checkins": 1,
  "user_state": 1,
  "publish_rate": 2,
  "user_moderation": 1,
  "reports": 1
}
~~~

注销后的上述计数全部为 0。


~~~json
{
  "users": 0,
  "auth_sessions": 0,
  "posts": 0,
  "comments": 0,
  "likes": 0,
  "cloud_projects": 0,
  "checkins": 0,
  "user_state": 0,
  "publish_rate": 0,
  "user_moderation": 0,
  "reports": 0
}
~~~

用户的云项目与终端目录均已删除。
相邻测试账号的目录仍存在。
两条旧会话均返回 401。
夹具拒绝该统一账号再次登录。
真实网关令牌吊销不能由夹具证明。

账号自己的审计已替换用户 ID。
账号自己的审计用户名为空。


~~~json
[
  {
    "user_id": "deleted_8b03e6df6218ab93e7f9d0db7d54f438",
    "username": null,
    "action": "post.create",
    "target": "post:post_0a0ad5b4fb7d73ffa891b4ada6765d44",
    "detail": "discussion Acceptance account erase post status=published",
    "ip": "198.51.100.17",
    "port": 45678,
    "platform": "harmonyos-app"
  }
]
~~~

管理员审计仍含注销账号的原 ID。


~~~json
[
  {
    "user_id": "user_56ef6a258024f9e24baa9b4381fa743b",
    "username": "accept_admin",
    "action": "admin.account_mute",
    "target": "user:user_a4d3823f51dd09010fecb15c7fb16eff",
    "detail": "reason=Acceptance target identity audit",
    "ip": "198.51.100.17",
    "port": 45678,
    "platform": "harmonyos-app"
  },
  {
    "user_id": "user_56ef6a258024f9e24baa9b4381fa743b",
    "username": "accept_admin",
    "action": "admin.account_unmute",
    "target": "user:user_a4d3823f51dd09010fecb15c7fb16eff",
    "detail": "reason=Acceptance unmute before erase",
    "ip": "198.51.100.17",
    "port": 45678,
    "platform": "harmonyos-app"
  }
]
~~~

网关缺少授权范围时，QFLI 返回 403。
本地账号及会话均保留。
审计总数仍为 44，未新增审计。


~~~json
{
  "before": 44,
  "after": 44,
  "rows": []
}
~~~

网关注销请求符合接口形状。
Basic 凭据匹配，用户 ID 使用网关 sub。


~~~json
{
  "method": "POST",
  "path": "/oauth2/account/erase",
  "basicValid": true,
  "body": {
    "user_id": "acceptance-erase",
    "reason": "user_request",
    "request_id": "a7b3d363-86ec-4cec-8be6-df066e6f6a7b"
  },
  "status": 200,
  "response": {
    "user_id": "acceptance-erase",
    "status": "deleted",
    "deleted_at": "2026-11-02T09:19:25.518Z",
    "tokens_revoked": true
  }
}
~~~

注销会删除本地举报行。
审核中心的举报仍存在。
中心的 reporterId 仍为原用户 ID。
该结果交给审核服务验收者评估。

**结论：失败。**
本地数据删除与会话失效通过。
跨操作者审计未完全去标识化。
缺少授权范围的失败未写审计。
该失败违反注销契约 A。
真实网关吊销和再次登录为未验证。
App 入口属于客户端验收范围。

**证据路径**：E/http-and-db.json 的 7.*。
网关请求形状位于 E/gateway.json。
代码位置为 src/deactivate.js。
失败路径还涉及 src/routes/users.js。

## 9. 搜索下线与 AI 标识

**条目原文**

~~~text
客户端和服务端都没有 bing.com 的调用；AI 回复和 AI 生成的文件都有标识；鸿蒙版不能自定义 AI 接口。
~~~

**验证方法**

使用已验证账号调用原搜索接口。
再向 AI 转发接口提交消息。
AI 上游使用本地 HTTP 夹具。
另测客户端覆盖上游地址的请求。
扫描服务端源文件中的搜索调用与 TLS 绕过。


~~~text
POST /api/ai/web_search
{"query":"acceptance"}
POST /api/ai/chat
{"messages":[{"role":"user","content":"Acceptance fixture only"}]}
POST /api/ai/chat
{"messages":[{"role":"user","content":"Acceptance"}],"baseUrl":"https://example.invalid","apiKey":"dummy"}
rg -n -i "bing\.com|web_search|rejectUnauthorized\s*:\s*false|NODE_TLS_REJECT_UNAUTHORIZED" src
~~~

**实际结果**

原搜索接口返回 HTTP 404。


~~~text
Cannot POST /api/ai/web_search
~~~

AI 回复返回 HTTP 200，并包含标识。


~~~json
{
  "aiGenerated": true,
  "model": "deepseek-v4.1-flash",
  "message": {
    "role": "assistant",
    "content": "Acceptance fixture AI reply"
  },
  "usage": {
    "prompt_tokens": 5,
    "completion_tokens": 5,
    "total_tokens": 10
  }
}
~~~

客户端覆盖上游地址的请求返回 400。
源文件扫描只命中下线说明注释。


~~~json
{
  "exitCode": 0,
  "output": "src\\routes\\ai.js:4:// web_search 已于 2026-11 合规整改下线：搜索走 Bing，会引入未披露的第三方。\n",
  "stderr": ""
}
~~~

**结论：通过。**
服务端搜索下线和响应标识通过。
线上 AI 上游是否仅为 DeepSeek，需部署后复测。
AI 文件标识和鸿蒙配置入口由客户端验收。

**证据路径**：E/http-and-db.json 的 9.*。
AI 夹具响应位于 E/gateway.json。
代码位置为 src/routes/ai.js 与 src/ai-client.js。

## 部署后复测命令

以下命令尚未用于生产环境。
部署者须保存脱敏输出作为追加证据。
所有令牌只用专门的验收账号。
注销只用可永久删除的验收账号。

先在部署主机的仓库根目录检查版本。
准备已验证、未验证、管理员和限流账号。
从部署环境提供下列变量。


~~~text
MODERATION_BASE_URL MODERATION_APP_ID MODERATION_API_KEY
SMOKE_UNVERIFIED_TOKEN SMOKE_RATE_TOKEN SMOKE_ZONE_ID
ADMIN_TOKEN AUDIT_USERNAME LOGIN_BODY_FILE
ERASE_TEST_TOKEN ERASE_TEST_SECOND_TOKEN
QFLI_PID PROBE_PUBLIC_IP
~~~



~~~bash
git rev-parse HEAD
node --version
node scripts/compliance/smoke.mjs \
  --qfli https://qfli.suanxiwanjie.cn \
  --moderation "$MODERATION_BASE_URL" \
  --strict --allow-rate --max-rate-requests 7
~~~

该命令不能替代本文各项的原始响应。
线上各项仍须保存对应 HTTP 摘录。

检查 nginx 生效配置及代码保留期。


~~~bash
sudo nginx -t
sudo nginx -T 2>&1 | rg -n 'X-Real-IP|X-Real-Port|proxy_pass'
node -p "require('./azurekiln-qfli-server/src/audit-retention').RETENTION_DAYS"
rg -n 'RETENTION_DAYS|DELETE FROM audit_logs' \
  azurekiln-qfli-server/src/audit-retention.js \
  azurekiln-qfli-server/src/db.js
~~~

必须确认两条代理头覆盖实际源 IP 和源端口。
还须检查运行进程使用的部署版本。
代码值不能证明运行进程的版本。

在服务主机捕获专用探测连接。
同时在探测机提交一次真实登录。


~~~bash
sudo timeout 20 tcpdump -nn -i any -c 1 \
  "tcp dst port 443 and src host $PROBE_PUBLIC_IP"
~~~



~~~bash
curl -sS -D /tmp/qfli-acceptance-login.headers \
  https://qfli.suanxiwanjie.cn/api/auth/login \
  -H "Content-Type: application/json" \
  -H "X-Client-Platform: harmonyos-app/acceptance" \
  -H "X-Real-IP: 203.0.113.99" \
  -H "X-Real-Port: 1" \
  -H "X-Forwarded-For: 203.0.113.99" \
  --data-binary @"$LOGIN_BODY_FILE" | jq 'del(.token)'
curl -sS \
  "https://qfli.suanxiwanjie.cn/api/audit?action=auth.password_login&user=$AUDIT_USERNAME" \
  -H "Authorization: Bearer $ADMIN_TOKEN" | \
  jq '.items | sort_by(.created_at) | last | {ip,port,platform,login_type,created_at}'
~~~

审计端口须等于抓包中的连接源端口。
经过 NAT 时采用服务主机观察到的端口。
不得采用伪造头中的 IP 或端口。

只输出运行进程的 AI 与 TLS 开关。


~~~bash
sudo python3 - "$QFLI_PID" <<'PY'
import pathlib, sys, urllib.parse
entries = pathlib.Path('/proc', sys.argv[1], 'environ').read_bytes().split(b'\0')
env = dict(item.decode().split('=', 1) for item in entries if b'=' in item)
base = env.get('QFLI_AI_BASE_URL', '')
print('QFLI_AI_BASE_URL=' + base)
print('NODE_TLS_REJECT_UNAUTHORIZED=' + env.get('NODE_TLS_REJECT_UNAUTHORIZED', '<unset>'))
assert urllib.parse.urlparse(base).scheme == 'https'
assert urllib.parse.urlparse(base).hostname == 'api.deepseek.com'
assert env.get('NODE_TLS_REJECT_UNAUTHORIZED') != '0'
PY
~~~

再保存真实 AI 回复及其 aiGenerated 字段。


~~~bash
curl -sS -i https://qfli.suanxiwanjie.cn/api/ai/chat \
  -H "Authorization: Bearer $ERASE_TEST_TOKEN" \
  -H "X-Client-Platform: harmonyos-app/acceptance" \
  -H "Content-Type: application/json" \
  --data '{"messages":[{"role":"user","content":"Reply with OK"}]}'
~~~

用户本人须先授予 qfli_account_erase。
随后对专用账号提交永久注销。


~~~bash
curl -sS -i https://qfli.suanxiwanjie.cn/api/users/me/deactivate \
  -H "Authorization: Bearer $ERASE_TEST_TOKEN" \
  -H "Content-Type: application/json" \
  --data '{"confirm":"DEACTIVATE"}'
for token in "$ERASE_TEST_TOKEN" "$ERASE_TEST_SECOND_TOKEN"; do
  curl -sS -i https://qfli.suanxiwanjie.cn/api/users/me \
    -H "Authorization: Bearer $token"
done
~~~

预期注销响应为 200，两条旧会话均为 401。
真实网关还须提交令牌吊销证据。
同一华为身份重新注册应取得新用户 ID。
这些结果须由真实网关接口补证。

## 初验交付与遗留项

协调者已将 5 项失败交给 w37:p3。
本报告等待修复提交后追加复测。
验收者不修改业务代码。

辅助单元测试为 83 项通过，0 项失败。
这些测试不能覆盖上述真实 HTTP 失败。


~~~bash
cd azurekiln-qfli-server
node --test test/audit-log.test.js test/client-context.test.js \
  test/deactivate.test.js test/huawei-binding.test.js \
  test/moderation.test.js test/moderation-sdk.test.js test/ai-relay.test.js
~~~

用户本人须在网关后台授予注销范围。
部署者须补充线上复测及实际网关证据。
本报告未确认生产部署完成。
本报告未验收审核服务自身的实现。


## 第一次修复复测（2026-11-02 17:50）

本节追加复测结果。
前文保留初验结论。
本次启动全新 QFLI 与审核服务进程。
本次另建 SQLite 和测试账号。
网关与 AI 仍为本地接口夹具。



~~~json
{
  "revision": "ac4d0b85cb6f37d10df6dedbfb5b9b6d5446d1b0",
  "fixCommits": [
    "10dee9b",
    "741e33f",
    "68a992e"
  ],
  "testCommit": "50aebcc",
  "taskRecordCommit": "ac4d0b8",
  "checks": 84,
  "passed": 81,
  "failed": [
    "1.fields.auth.register",
    "6.pending-admin-visible",
    "6.pending-list-admin"
  ],
  "sourceChangesDuringRun": []
}
~~~

**结论：失败。**
本轮 84 项断言中，81 项通过，3 项失败。
原有 5 项失败中，2 项通过，3 项仍失败。
线上及真实网关结论仍需补证。

| 原失败断言 | 本次结论 | 实际结果 |
|---|---|---|
| 注册审计用户 ID | 失败 | 首次注册仍为 null |
| 管理员待审详情 | 失败 | HTTP 404 |
| 管理员待审列表 | 失败 | HTTP 200，但不含待审帖子 |
| 跨操作者审计 ID | 通过 | 已测试的禁言、解除禁言记录不含原 ID |
| 失败注销审计 | 通过 | 审计计数由 44 增至 45 |

**验证方法**

沿用初验 HTTP 流程。
新增网关按用户名查询的夹具响应。
该响应返回新注册账号的真实测试 sub。
首次注册前不预插该账号的本地用户行。
另加强账号 ID 一致性检查。
注销复测还检查原审计行和时间均保留。



~~~powershell
node "D:/AppData/Local/Temp/qfli-server-acceptance-20261102-p7-099baf6f149948bd8f53bc88445de02a/server-acceptance-retest-one.mjs"
~~~

本次脚本 SHA-256：


~~~text
6812b099057d37aa5b468530b3c245f3806de8f25e99ea92df535db6bf925744
~~~

**注册审计实际结果**

注册响应仍为 HTTP 200。
网关公开资料查询也返回 200。
本地用户映射为空，审计用户 ID 仍为空。


~~~json
[
  {
    "method": "GET",
    "path": "/oauth2/public-profile/acceptance_new",
    "status": 200
  }
]
~~~



~~~json
{
  "gatewaySubject": "acceptance-new-user",
  "localUser": null
}
~~~



~~~json
{
  "id": "audit_591a2c078ab0fda71e6707c71d6f229e",
  "user_id": null,
  "username": "acceptance_new",
  "action": "auth.register",
  "target": null,
  "detail": null,
  "ip": "198.51.100.17",
  "user_agent": "node",
  "created_at": "2026-11-02 09:50:16",
  "port": 45678,
  "platform": "harmonyos-app",
  "login_type": "register"
}
~~~

修复代码只查询本地用户映射。
首次注册不会已有该映射。
新增回归测试预插了该用户行。
该测试无法证明首次注册场景通过。

**管理员待审可见性实际结果**



~~~json
{
  "status": 200,
  "contentType": "application/json; charset=utf-8",
  "body": {
    "id": "post_acaac41cfaab1c8a7266e10255ecd92d",
    "status": "pending"
  }
}
~~~



~~~json
{
  "status": 404,
  "contentType": "application/json; charset=utf-8",
  "body": {
    "error": "内容不存在"
  }
}
~~~

管理员列表仍不含该帖子。
作者与管理员使用相同的真实认证链。
真实 authOptional 只写入 req.userId。
修复代码却读取 req.user.is_admin。
测试替身额外写入了 req.user。
该差异使修复未覆盖真实认证链。

**注销两项实际结果**



~~~json
[
  {
    "id": "7.audit-all-identifiers-removed",
    "result": "pass",
    "actual": {
      "remaining": [],
      "allOriginalAuditRowsPreserved": true
    }
  },
  {
    "id": "7.failed-erase-audited",
    "result": "pass",
    "actual": {
      "before": 44,
      "after": 45,
      "rows": [
        {
          "id": "audit_888635762aa36a56e158c4f91167e145",
          "user_id": "user_5770a38f1e5e9d4a601d74d730b37c18",
          "username": "accept_denied",
          "action": "user.deactivate_failed",
          "target": "user:user_5770a38f1e5e9d4a601d74d730b37c18",
          "detail": "status=403 errorKey=gateway.insufficient_scope",
          "ip": "198.51.100.17",
          "user_agent": "node",
          "created_at": "2026-11-02 09:50:17",
          "port": 45678,
          "platform": "harmonyos-app",
          "login_type": null
        }
      ]
    }
  }
]
~~~

禁言与解除禁言审计已替换目标 ID。
管理员自身的用户 ID 保留。
原审计行的 ID、动作与时间均保留。


~~~json
[
  {
    "id": "audit_0061367e7426801804d89b309fca3e6e",
    "user_id": "user_a003670975346e2bb59820b116169232",
    "username": "accept_admin",
    "action": "admin.account_mute",
    "target": "user:deleted_1f590c0c5fe12aa24a89e272ef285ea9",
    "detail": "reason=Acceptance target identity audit",
    "created_at": "2026-11-02 09:50:17"
  },
  {
    "id": "audit_31c4eeb22b0ff3420c5e08fe95cf387a",
    "user_id": "user_a003670975346e2bb59820b116169232",
    "username": "accept_admin",
    "action": "admin.account_unmute",
    "target": "user:deleted_1f590c0c5fe12aa24a89e272ef285ea9",
    "detail": "reason=Acceptance unmute before erase",
    "created_at": "2026-11-02 09:50:17"
  }
]
~~~

缺少授权范围时新增失败审计。
审计记录 HTTP 403 与网关错误键。
本地数据和会话保留的检查仍通过。


~~~json
{
  "before": 44,
  "after": 45,
  "rows": [
    {
      "id": "audit_888635762aa36a56e158c4f91167e145",
      "user_id": "user_5770a38f1e5e9d4a601d74d730b37c18",
      "username": "accept_denied",
      "action": "user.deactivate_failed",
      "target": "user:user_5770a38f1e5e9d4a601d74d730b37c18",
      "detail": "status=403 errorKey=gateway.insufficient_scope",
      "ip": "198.51.100.17",
      "user_agent": "node",
      "created_at": "2026-11-02 09:50:17",
      "port": 45678,
      "platform": "harmonyos-app",
      "login_type": null
    }
  ]
}
~~~

**证据路径**



~~~text
D:/AppData/Local/Temp/qfli-server-acceptance-20261102-p7-099baf6f149948bd8f53bc88445de02a/run-1793613015772
~~~

原始请求和响应位于 http-and-db.json。
五项断言位于 checks.json。
网关接口轨迹位于 gateway.json。
完整版本及源码哈希位于 manifest.json。

复现代码位置如下。

- 注册映射：src/routes/auth.js 的 registeredGatewayUser 调用。
- 管理员身份：src/util.js 的 authOptional。
- 可见性判断：src/routes/posts.js。
- 替身差异：test/acceptance-fixes.test.js。

已向协调者和 w37:p3 回报剩余 3 项失败。
报告仍未宣称完整验收通过。

另有仅在管理员审计 detail 引用原 ID 的场景。
当前筛选条件没有匹配 detail。
该边界尚未验证，已交给修复者检查。
本节去标识化通过仅适用于本轮禁言样本。


## 第二次修复复测（2026-11-02 18:11）

本次启动全新 QFLI 与审核服务进程。
本次另建 SQLite 和测试账号。
真实认证、会话和实名中间件均参与请求。
网关与 AI 仍使用本地 HTTP 夹具。



~~~json
{
  "revision": "390fad5a500d8f52247a63a5a12042d4f69e9436",
  "fixCommits": [
    "60732a9",
    "936f9d6",
    "7285f82"
  ],
  "regressionTestCommit": "b6a25d7",
  "checks": 86,
  "passed": 86,
  "failed": [],
  "sourceChangesDuringRun": []
}
~~~

**本地结论：通过。**
本轮 86 项断言全部通过。
原先 5 项失败断言全部通过。
新增 2 项管理员删除审计断言也通过。
前文保留初验及第一次复测的失败证据。
本结论不替代生产部署或真实网关验收。

| 条目 | 最新本地结论 | 原缺口或补测结果 |
|---|---|---|
| 1 | 通过 | 首次注册审计绑定正确的本地用户 ID |
| 2 | 通过 | 无手机号及明确未验证手机号均受限 |
| 3 服务端 | 通过 | 华为跳过、绑定及上游拒绝映射通过 |
| 5 | 通过 | 删除、审计与举报处理通过 |
| 6 | 通过 | 管理员待审详情和列表均可见 |
| 7 服务端 | 通过 | 已测数据删除、会话失效及审计去标识化通过 |
| 9 服务端 | 通过 | 搜索下线及 AI 响应标识通过 |

**验证方法**

完整重跑前述 HTTP 验收流程。
继续验证首次注册且没有本地映射的账号。
继续检查网关 sub 与本地 ID 的对应关系。
在注销前另建一条帖子和一条评论。
管理员带原因删除这两条内容。
随后注销作者并查询审计的 detail 字段。
该样本覆盖仅在 detail 引用原 ID 的边界。



~~~powershell
node "D:/AppData/Local/Temp/qfli-server-acceptance-20261102-p7-099baf6f149948bd8f53bc88445de02a/server-acceptance-retest-two.mjs"
~~~

复测脚本 SHA-256：


~~~text
42aa73bb3eddea3b7aea229cfa0cd1b1eb3df7e72b761ca201fff3c7685e861a
~~~

**第 1 项原始结果摘录**

首次注册返回 HTTP 200。
本地映射的网关 ID 为 acceptance-new-user。
审计用户 ID 与该映射的本地 ID 相同。


~~~json
{
  "gatewaySubject": "acceptance-new-user",
  "localUser": {
    "id": "user_99996cd0fd2558e4045a1829d460744d",
    "gateway_user_id": "acceptance-new-user"
  }
}
~~~



~~~json
{
  "id": "audit_dbf2e003871dde01c8bc646a2ec16cc6",
  "user_id": "user_99996cd0fd2558e4045a1829d460744d",
  "username": "acceptance_new",
  "action": "auth.register",
  "target": null,
  "detail": null,
  "ip": "198.51.100.17",
  "user_agent": "node",
  "created_at": "2026-11-02 10:11:46",
  "port": 45678,
  "platform": "harmonyos-app",
  "login_type": "register"
}
~~~

真实网关的按用户名公开资料查询尚未验证。
此处通过仅说明 QFLI 对该接口夹具的处理。

**第 6 项原始结果摘录**

同一待审帖子对管理员的详情返回 200。


~~~json
{
  "status": 200,
  "post": {
    "id": "post_d2a1da4c7110f3ca70990e13d1f4eecb",
    "status": "pending",
    "title": "Acceptance pending post"
  }
}
~~~

管理员列表也包含该帖子。
作者可见性仍通过。
读者与匿名视角仍返回 404。


~~~json
[
  {
    "id": "6.pending-author-visible",
    "result": "pass",
    "actual": 200
  },
  {
    "id": "6.pending-public-hidden",
    "result": "pass",
    "actual": {
      "reader": 404,
      "anonymous": 404
    }
  },
  {
    "id": "6.pending-admin-visible",
    "result": "pass",
    "actual": {
      "status": 200,
      "body": {
        "post": {
          "id": "post_d2a1da4c7110f3ca70990e13d1f4eecb",
          "type": "discussion",
          "title": "Acceptance pending post",
          "status": "pending",
          "excerpt": "Acceptance local fixture body",
          "tags": [],
          "zoneId": "zone_8014f4f0150476dcdab923b6301144a7",
          "zoneName": "Java",
          "author": {
            "id": "user_c25361a2ad2437a463a922056d89ee82",
            "username": "accept_pending",
            "nickname": "Acceptance pending",
            "avatarColor": "#2196F3",
            "bio": "",
            "avatarUrl": "",
            "provider": "azk"
          },
          "likeCount": 0,
          "commentCount": 0,
          "liked": false,
          "createdAt": "2026-11-02 10:11:46",
          "updatedAt": "2026-11-02 10:11:46",
          "content": "Acceptance local fixture body"
        }
      }
    }
  },
  {
    "id": "6.pending-list-admin",
    "result": "pass",
    "actual": {
      "found": true,
      "status": 200
    }
  }
]
~~~

真实认证链的管理员判定现已通过。
测试没有向请求对象额外注入 req.user。

**第 7 项原始结果摘录**

管理员删除审计中的作者 ID 已替换。
管理员自身的身份仍保留。


~~~json
[
  {
    "id": "audit_572d87a675b04cafaf7fd66e67d4eae6",
    "user_id": "user_a130b035f9dd99d4084b4d8b9c6cf862",
    "username": "accept_admin",
    "action": "admin.post_delete",
    "target": "post:post_824074e3cc29098f830db59b3e0c6827",
    "detail": "author=deleted_5ab3ffa6925d3e6ed0dc9e0c4df968e8 reason=Acceptance deletion audit retention",
    "created_at": "2026-11-02 10:11:47"
  },
  {
    "id": "audit_d00e057fcc286390e0e588b45b318135",
    "user_id": "user_a130b035f9dd99d4084b4d8b9c6cf862",
    "username": "accept_admin",
    "action": "admin.comment_delete",
    "target": "comment:comment_10452036c2230ed9b2b8d51407787708",
    "detail": "author=deleted_5ab3ffa6925d3e6ed0dc9e0c4df968e8 post=post_d3cbf942a8241b9c368bc1320473f2e0 reason=Acceptance deletion audit retention",
    "created_at": "2026-11-02 10:11:47"
  }
]
~~~

禁言与解除禁言的目标 ID 同样已替换。
本轮 12 条原审计行和原时间均保留。
查询原用户 ID 的结果为空。


~~~json
{
  "id": "7.audit-all-identifiers-removed",
  "result": "pass",
  "actual": {
    "remaining": [],
    "allOriginalAuditRowsPreserved": true
  }
}
~~~

注销失败审计正常增加一条。
本地数据与旧会话仍保留以便重试。


~~~json
{
  "before": 48,
  "after": 49,
  "rows": [
    {
      "id": "audit_8ef0525f44da0928b7a2019796606b73",
      "user_id": "user_6cb9f367bbb57efd53e5560cec634996",
      "username": "accept_denied",
      "action": "user.deactivate_failed",
      "target": "user:user_6cb9f367bbb57efd53e5560cec634996",
      "detail": "status=403 errorKey=gateway.insufficient_scope",
      "ip": "198.51.100.17",
      "user_agent": "node",
      "created_at": "2026-11-02 10:11:47",
      "port": 45678,
      "platform": "harmonyos-app",
      "login_type": null
    }
  ]
}
~~~

本地举报行现在保留。
本地举报人的 ID 已去标识化。


~~~json
{
  "id": "report_b7310cf44a37fe07ec57a8053dc47c16",
  "reporter_id": "deleted_5ab3ffa6925d3e6ed0dc9e0c4df968e8",
  "status": "open",
  "reason": "Acceptance reporter erasure retention",
  "created_at": "2026-11-02 10:11:46"
}
~~~

该行证明本次注销没有删除这条举报。
本次未验证它在真实环境中的长期清理。
审核中心仍保存原 reporterId。
中心侧的去标识化交给审核服务验收。

**完整服务端测试**

145 项测试中，144 项通过，1 项跳过。
失败数为 0。
跳过项为需独立 MySQL 测试库的终端池用例。
单元测试仅作补充证据。
本地验收结论仍依据本轮真实 HTTP 结果。


~~~text
✔ assertPublicHost rejects localhost names without any lookup (0.8013ms)
✔ assertPublicHost rejects a hostname resolving to a private address (0.1918ms)
✔ assertPublicHost accepts a hostname with only public records (0.6641ms)
✔ fetchPage rejects non-http schemes and embedded credentials (0.4837ms)
✔ fetchPage blocks the request before connecting to a private host (0.2175ms)
✔ extractText strips scripts, styles and tags (0.6409ms)
✔ normalizeText collapses blank lines and padding (0.1965ms)
ℹ tests 145
ℹ suites 0
ℹ pass 144
ℹ fail 0
ℹ cancelled 0
ℹ skipped 1
ℹ todo 0
ℹ duration_ms 1923.3782
~~~



~~~powershell
cd D:/MyNewProjects/qflistudio/azurekiln-qfli-server
node --test --test-timeout=60000 "test/*.test.js"
~~~

本次实际启动测试时使用隔离的环境变量。
未继承生产数据库和应用密钥。

**证据路径**



~~~text
D:/AppData/Local/Temp/qfli-server-acceptance-20261102-p7-099baf6f149948bd8f53bc88445de02a/run-1793614305018
~~~

原始 HTTP 与数据库摘录位于 http-and-db.json。
全部断言位于 checks.json。
本地举报行查询位于 sqlite-final.json。
版本和源码哈希位于 manifest.json。
单元测试证据如下。


~~~text
D:/AppData/Local/Temp/qfli-server-acceptance-20261102-p7-099baf6f149948bd8f53bc88445de02a/server-unit-final.log
D:/AppData/Local/Temp/qfli-server-acceptance-20261102-p7-099baf6f149948bd8f53bc88445de02a/server-unit-final-summary.json
~~~

**最终遗留项**

线上配置、nginx 源端口与生产部署须部署后复测。
真实 MySQL 分支仍未验证。
真实网关的华为登录和永久注销仍未验证。
真实网关的首次注册资料查询仍未验证。
长期注册信息留存仍需真实网关证据。
审核中心的处理同步与去标识化不在本报告结论内。
用户本人仍须授予 qfli_account_erase。
前文已列出部署后复测命令。

## 第 7 条补充复测：审核身份假名（2026-11-03）

**条目原文**

~~~text
App 内可以永久注销账号；注销后无法再登录，个人数据被删除，日志已去标识化。
~~~

**本地结论：通过。**
本轮新增 69 项断言全部通过。
原先 86 项脚本也全部通过。
前文保留 2026-11-02 的历史结果。
本节更新审核侧新写入身份字段的结论。
本轮未修改业务代码。

**版本与环境**

复测时间为 2026-11-03 03:42:31 至 03:42:34。
时区为 UTC+08:00。
QFLI 与审核服务分别启动全新进程。
两项服务均使用全新的临时 SQLite。
QFLI 直接启动 src/server.js。
审核服务也直接启动 src/server.js。
两项服务均采用 NODE_ENV=production。
网关登录、资料和注销接口使用本地 HTTP 夹具。
认证和审核传输未注入替身。
测试账号均通过真实 QFLI 登录接口建号。
本轮没有读取项目 .env。

~~~json
{
  "qfliRevision": "cad26560e991ccc25e29d8aa942ef7ef9084c893",
  "moderationRevision": "6d6754c907b1e3b6caf162a55a2292edc6469022",
  "fixCommits": ["3463632", "715ed33", "59ab6af"],
  "node": "v24.15.0",
  "checks": 69,
  "passed": 69,
  "failed": [],
  "sourceChanges": {"qfli": [], "moderation": []}
}
~~~

**验证方法**

脚本在内存中创建本轮随机密钥。
脚本独立计算 HMAC-SHA256 预期值。
脚本没有调用业务的假名函数。
密钥和令牌未写入报告或证据 JSON。
完整脚本位于验收任务的 server 子目录。

~~~powershell
cd D:/MyNewProjects/qflistudio
node .trellis/tasks/11-02-acceptance/server/moderation-pseudonym-retest.mjs
~~~

脚本 SHA-256：

~~~text
ab8f13a2cea2c14424683d14534c8813d70f669b17a4f5a612555235b3c0eca4
~~~

脚本先检查数据库中的全部 4 个本地用户 ID。
扫描范围也包含这 4 个账号的网关 sub。
脚本提交以下请求。
路径中的变量来自本轮 HTTP 响应。

~~~text
POST /api/auth/login
{"username":"accept_p7_erase","password":"[REDACTED]"}
POST /api/posts
{"type":"discussion","zoneId":"<zoneId>","title":"Acceptance author discussion","content":"Acceptance ordinary technical discussion body","tags":["acceptance"]}
POST /api/posts/<postId>/comments
{"content":"Acceptance ordinary author comment"}
PATCH /api/users/me
{"nickname":"Acceptance profile","bio":"Acceptance ordinary profile text"}
POST /api/reports
{"targetType":"post","targetId":"<postId>","reason":"Acceptance report identity retention"}
POST /api/reports
{"targetType":"comment","targetId":"<commentId>","reason":"Acceptance report identity retention"}
POST /api/reports
{"targetType":"user","targetId":"<localUserId>","reason":"Acceptance report identity retention"}
POST /v1/admin/keywords
{"word":"acceptancebadwordpseven","category":"custom"}
POST /api/posts
{"type":"discussion","zoneId":"<zoneId>","title":"acceptancebadwordpseven","content":"Acceptance ordinary technical discussion body","tags":["acceptance"]}
POST /api/posts/<postId>/comments
{"content":"acceptancebadwordpseven"}
PATCH /api/users/me
{"nickname":"acceptancebadwordpseven"}
POST /v1/admin/ip-rules
{"type":"ip","value":"203.0.113.37","reason":"Acceptance blocked source"}
POST /api/posts
X-Real-IP: 203.0.113.37
PUT /v1/admin/scenes/community.post.title
{"preReview":true}
PUT /v1/admin/scenes/community.comment
{"preReview":true}
GET /v1/admin/audit?limit=100&offset=0
POST /api/users/me/deactivate
{"confirm":"DEACTIVATE"}
~~~

本轮还提交正常帖子和评论以触发人工审核队列。
作者举报帖子、评论和另一用户。
另一举报人举报作者本人。
脚本随后分别注销作者和该举报人。
每次注销后均检查旧会话。

**实际结果：身份字段**

正常帖子、评论和资料修改均返回 200。
4 条举报均返回 201 并转发成功。
帖子和评论命中词库后均返回 422。
昵称命中词库后也返回 422。
IP 黑名单命中后返回 403。
先审后发的帖子与评论均返回 pending。

审核库中的文本与 IP 审计只保存预期假名。
标题、正文、标签、评论、昵称和简介均已覆盖。
同一用户在这些场景中使用相同假名。
下列摘录保留原始字段和值。

~~~json
{
  "action": "text.check",
  "actor_id": "psn_c54a245ba7f522a2315048601d4a4f8bafb5583a641449ba464e4877b325d90d",
  "decision": "block",
  "data": "{\"scene\":\"community.post.title\",\"categories\":[\"custom\"],\"hits\":[{\"keywordId\":\"18f3a70e-3a78-44aa-a643-58676ea018e9\",\"category\":\"custom\"}]}"
}
~~~

user 类举报的目标 ID 也等于预期假名。
该条举报由另一个测试账号提交。

~~~json
{
  "target_type": "user",
  "target_id": "psn_c54a245ba7f522a2315048601d4a4f8bafb5583a641449ba464e4877b325d90d",
  "reporter_id": "psn_5301bd8ea39525995dc30b1b7f150ea9a2392f3438e9850509a335c4d1d5d2c6",
  "reason": "Acceptance report identity retention",
  "status": "open"
}
~~~

post 和 comment 类目标仍使用对应内容 ID。
这两类举报的 reporter_id 同样使用预期假名。
人工审核队列的 user_id 也使用预期假名。

~~~json
{
  "scene": "community.comment",
  "status": "pending",
  "user_id": "psn_c54a245ba7f522a2315048601d4a4f8bafb5583a641449ba464e4877b325d90d",
  "payload_json": "{\"text\":\"Acceptance queued comment\",\"metadata\":{}}"
}
~~~

**实际结果：数据库与注销后扫描**

脚本扫描审核库的全部 11 张表。
扫描覆盖每一行的每一列。
脚本另查管理员审计接口的全部分页。
文件扫描覆盖数据库、WAL 和 SHM。
文件扫描同时匹配 UTF-8 与 UTF-16LE。
下表中的命中数合并本地 ID 与网关 sub。

| 阶段 | 审计行 | 举报行 | 队列行 | 原始 ID 命中数 |
|---|---:|---:|---:|---:|
| 注销前 | 32 | 4 | 2 | 0 |
| 作者注销后 | 32 | 4 | 2 | 0 |
| 举报人注销后 | 32 | 4 | 2 | 0 |
| 恢复密钥并再次发帖后 | 36 | 4 | 3 | 0 |

两次注销均返回 200 deactivated。
两个旧会话均返回 401。
QFLI 的两条用户映射均已删除。
两次注销前后的审核库快照完全相同。
原 32 条审计、4 条举报和 2 条队列记录均保留。
4 次举报详情查询均未检出原始 ID。
保留记录中的假名与注销前相同。

**实际结果：缺少密钥时 failClosed**

脚本关闭已配置密钥的 QFLI 进程。
脚本随后启动缺少密钥的新生产模式进程。
另一轮新进程只配置 5 字符密钥。
审核服务在这两轮中持续正常运行。
其他配置和测试数据库保持一致。

| 请求 | 缺少密钥 | 5 字符密钥 |
|---|---:|---:|
| POST /api/posts | 503 | 503 |
| POST /api/posts/:id/comments | 503 | 503 |
| PATCH /api/users/me：昵称 | 503 | 503 |
| PATCH /api/users/me：简介 | 503 | 503 |

缺少密钥时的原始发帖响应如下。

~~~json
{
  "status": 503,
  "body": {
    "error": "审核服务暂不可用",
    "errorKey": "moderation.unavailable",
    "requestId": "6e0dc49c-f151-4f4b-9186-b3029f3ded54"
  }
}
~~~

两轮均未增加帖子或评论。
两轮均未调用网关资料修改接口。
审核库也没有新增或修改任何记录。
进程日志均记录 moderation.subject_salt_missing。
举报仍按既有契约在本地受理。
其响应为 201 queued，forwarded 为 0。
其 moderationReportId 为 null。
这两条举报没有转发到审核服务。

恢复有效密钥后，另一全新进程发帖返回 200。
该帖子因先审后发开关而处于 pending。
审核库新增记录仍只使用预期假名。
本轮启动的 5 个服务子进程均已关闭。

**原 86 项回归与完整服务端测试**

原 86 项脚本未作改动。
本次回归时间为 2026-11-03 03:34:08 至 03:34:10。
脚本重新启动两项真实服务。
脚本另建临时 SQLite。
该旧脚本仍采用 NODE_ENV=test。
新增脚本独立验证上述生产模式行为。

~~~json
{
  "checks": 86,
  "passed": 86,
  "failed": [],
  "sourceChanges": []
}
~~~

旧脚本 SHA-256 保持不变。

~~~text
42aa73bb3eddea3b7aea229cfa0cd1b1eb3df7e72b761ca201fff3c7685e861a
~~~

完整服务端测试共有 154 项。
其中 153 项通过，0 项失败，1 项跳过。
跳过项仍须独立 MySQL 测试库。
这些单元测试仅作为补充证据。

~~~powershell
cd D:/MyNewProjects/qflistudio/azurekiln-qfli-server
node --test --test-timeout=60000 "test/*.test.js"
~~~

**证据路径**

新增复测根目录记为 P。

~~~text
D:/AppData/Local/Temp/qfli-server-pseudonym-20261103-p7-nffJeH
~~~

| 文件 | 内容 |
|---|---|
| P/manifest.json | 版本、源码哈希与脚本哈希 |
| P/http-and-db.json | 原始请求、响应及测试身份清单 |
| P/checks.json | 全部 69 项断言 |
| P/moderation-before-erase.json | 注销前的全表快照与文件扫描 |
| P/moderation-after-erase.json | 作者注销后的相同检查 |
| P/moderation-after-reporter.json | 举报人注销后的相同检查 |
| P/moderation-final.json | 恢复密钥后的相同检查 |
| P/qfli-final.json | QFLI 用户、举报与审计摘录 |
| P/gateway.json | 本地网关资料和注销请求轨迹 |
| P/processes.json | 子进程 PID、日志与退出记录 |
| P/summary.json | 本轮汇总 |

原 86 项回归证据目录如下。

~~~text
D:/AppData/Local/Temp/qfli-server-acceptance-20261102-p7-099baf6f149948bd8f53bc88445de02a/run-1793648048450
~~~

完整测试证据目录如下。
原始日志为 server-unit.log。
汇总文件为 summary.json。

~~~text
D:/AppData/Local/Temp/qfli-p7-unit-20261103-3atjey9n
~~~

**范围与遗留项**

本节只验证 QFLI 自动填入的身份字段。
测试正文与举报理由均未主动包含原始 ID。
本节证明新写入记录的原始身份字段已替换。
本节未验证或清理既有生产记录。
前文的旧 reporterId 观察仍属于历史证据。
真实网关注销、线上部署和 MySQL 仍待补证。
生产环境须配置 QFLI_MODERATION_SUBJECT_SALT。
用户本人须注入至少 16 字符的独立随机密钥。
用户本人仍须授予 qfli_account_erase。
