# W1-core 审核服务核心与 API 契约
仓库：D:/MyNewProjects/azurekiln-moderation（新建，main 分支）。需求：任务书 §2、§3-W1。

## 第一步（最优先）
README.md 写定 API 契约并提交，然后在终端打印 `CONTRACT READY <短哈希>`。契约须覆盖：appId+密钥鉴权与按 app 隔离；/v1/text/check、/v1/image/check、/v1/ip/check；人工审核队列（按 app/scene 先审后发开关、待审列表、结果查询/回调）；举报中心；管理接口（词库、IP 规则、开关）；错误码；SDK packages/client 用法、超时、failClosed；部署方式与端口；目录归属（W1-ext 负责 src 下 image/review/reports 模块、packages/client、deploy/，其余归 W1-core）。

## 范围
多应用鉴权与隔离；文本审核（先规范化：全半角、大小写、繁简、去插入的空格/符号/零宽字符，再匹配）；分类：涉政、色情、赌博、毒品、枪支弹药、管制器具、诈骗、暴恐、违禁品、广告引流、自定义；词库管理接口增删改，热加载 ≤10 分钟生效；导入开源中文敏感词库（写明来源与许可证）；IP/CIDR 黑名单与可选地区限制；所有判定落审计，365 天留存清理；数据库迁移；测试。

## 验收
§4 第 4、6（IP 部分）、11、12 条。
