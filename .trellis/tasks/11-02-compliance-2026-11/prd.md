# 2026-11 合规整改（W1–W3 + 部署 + 发版 + 验收）

需求原文：docs/compliance/2026-11-整改任务书.md（§0 规则、§1 硬约束、§2 审核服务架构、§3 分解、§4 验收、§6 回报）。本文件不重复原文。
共享契约：contracts.md。通用规则：rules.md。

| 子任务 | worker | 仓库 |
|---|---|---|
| w1-moderation-core | w37:p6 codex | D:/MyNewProjects/azurekiln-moderation（新建） |
| w1-moderation-ext | w37:p7 codex | 同上（契约就绪后开工） |
| w2a-server-identity-logs | w37:p2 pi | qflistudio/azurekiln-qfli-server |
| w2b-server-moderation | w37:p3 pi | qflistudio/azurekiln-qfli-server |
| w3a-client-shell-login | w37:p5 pi | qfli_studio_core + qflistudio/ohos |
| w3b-client-settings-community-ai | w37:p4 pi | qfli_studio_core |

后续阶段（实现完成后由 root 派发）：部署（W1 审核服务 + W2 上线 qfli.suanxiwanjie.cn）、W3 发版（版本号 + 签名 release HAP）、逐条验收（§4，结果写入 docs/compliance/2026-11-验收记录.md）。W4 由网关工作区（会话 azurekiln-oauth2-c6）完成。

## 验收
任务书 §4 第 1–12 条。
