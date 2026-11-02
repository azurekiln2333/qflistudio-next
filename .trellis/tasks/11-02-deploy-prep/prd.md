# 部署准备（审核服务 + QFLI 服务端 + nginx）
仓库：D:/MyNewProjects/azurekiln-moderation、qflistudio（azurekiln-qfli-server、docs）。需求：任务书 §3-W2“部署”、§2“独立部署”。

## 背景
本机没有 8.138.227.60 的 SSH 配置，也没有 Docker CLI。QFLI 业务镜像由 CNB 流水线在推送 main 后构建，服务器只拉取（见 docs/deployment.md）。审核服务是新仓库，还没有远程与流水线。上线顺序必须是先审核服务、后 QFLI 服务端，否则发布类请求会因 failClosed 全部 503。

## 要求
- 写可直接执行的上线手册 qflistudio/docs/compliance/2026-11-上线手册.md：上线顺序；服务器前置条件；审核服务 compose 与环境变量；为 qflistudio 与网关签发 appId/密钥的命令；QFLI 服务端新增环境变量清单；nginx 改动（X-Real-IP、X-Real-Port，审核服务只走内网或受限反代）；数据库迁移与回滚；冒烟测试命令。
- 为 azurekiln-moderation 增加 CNB 流水线配置（参照 qflistudio 根 .cnb.yml），用户创建 CNB 仓库后推送即可构建镜像。
- 写一个冒烟脚本（可对任意 base URL 运行，以只读或测试账号请求为主），覆盖健康检查、文本审核变体拦截、未实名 403、限流 429 等，供部署后和验收使用。
- 在本机用两个进程把审核服务与 QFLI 服务端连起来跑一遍端到端（QFLI 通过 vendored SDK 调用审核服务）。SDK 正由 w37:p3 放进 azurekiln-qfli-server/vendor，等它提交后再跑这一步，先做手册与流水线。
- 不得 push，不得连接生产服务器，不得写入任何真实密钥。

## 输出
Result：手册与脚本路径、本机端到端结果、需要用户提供的访问与密钥清单。
