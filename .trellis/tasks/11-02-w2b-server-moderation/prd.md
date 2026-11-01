# W2b 审核接入、限流、封停、管理员处置、举报
仓库：qflistudio/azurekiln-qfli-server。需求：§3-W2 对应条目。

## 范围
- 审核接入：发帖标题/正文/标签、评论、昵称、简介走文本审核；发布前查 IP 规则；先审后发开启时新内容 status=pending，仅作者与管理员可见。审核逻辑只能通过 W1 SDK 调用，src 里只留薄适配层。W1 契约在 D:/MyNewProjects/azurekiln-moderation/README.md；就绪前按 contracts.md 与任务书 §2 写适配层接口与测试替身，就绪后对齐。服务不可用时发布类请求 failClosed（503 moderation.unavailable）。
- 限流：发帖、评论按用户分别限制每分钟与每天上限，429 rate.limited（可复用 terminalRateLimited 思路）。
- 封停/禁言：管理员操作，被封停或禁言账号禁止发布，写审计。
- 管理员处置：DELETE /api/admin/posts/:id、/api/admin/comments/:id，必填原因，审计 admin.*；查看并处理举报；开关先审后发；词库与 IP 规则代理或跳转审核服务管理接口。
- 举报：POST /api/reports，转发审核服务举报中心，同时写本地审计。
- 错误码与字段严格按 contracts.md C 节。

## 边界
W2a 负责 audit.js 保留期与字段、可信代理、实名中间件、华为登录、web_search 下线、AI、注销；这些不要动。db.js 只增加你需要的表/列，写成独立迁移块，小步提交。

## 验收
§4 第 4（服务端接入）、5、6、11 条。
