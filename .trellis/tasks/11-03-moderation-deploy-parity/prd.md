# 审核服务部署对齐网关（Watchtower + GitHub Actions）
来源：用户经网关会话（azurekiln-oauth2-c6）提出，2026-11-03。仓库：D:/MyNewProjects/azurekiln-moderation。
参考（只读，不要修改）：D:/MyNewWebProjects/azurekiln-oauth2 的 docker-compose.yaml、.github/workflows/、.trellis/spec/backend/deployment.md；其做法源自 D:/My2KProjects/cnb2api-panel。

## 要求
1. 生产 compose：加固定版本 Watchtower `nickfedor/watchtower:1.23.2`，只按标签、项目 scope 和容器名更新审核服务容器，Watchtower 自身不被更新。另给一份本地构建用的 compose（build 方式），关闭自动更新。
2. GitHub Actions：push 与 PR 跑检查（测试、lint）；main 分支与 v* 标签构建并推送 GHCR 镜像。保留已有 CNB 流水线（.cnb.yml），两者并存，在 README 写明各自用途。
3. 端口只绑定 127.0.0.1，由宿主机 Nginx 反代。数据库：若支持 MySQL，提供容器外 MySQL（host 网络）与可选的容器内 MySQL；SQLite 模式写明持久化卷。Redis 同理（若用到）。
4. 同步更新审核服务 README 的部署章节，以及 qflistudio/docs/compliance/2026-11-上线手册.md 中审核服务的段落（只改审核服务相关部分）。
5. 本机能验证的都验证（compose 配置校验、workflow YAML 校验、测试）；不 push、不连生产、不写真实密钥。
6. Conventional Commits，不加任何署名。完成后在终端列出提交列表（短哈希+标题）。
