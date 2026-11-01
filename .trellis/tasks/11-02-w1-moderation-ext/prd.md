# W1-ext 图片审核、人工审核队列、举报中心、SDK、部署
仓库同 W1-core。开工前读 README 契约与目录归属，只改归你的模块；共享入口（应用入口、路由注册、迁移目录）以追加为主。需求：§2。

## 范围
图片审核 provider 可插拔，未配置时进入人工审核队列；人工审核队列（先审后发开关、待审列表、结果查询/回调）；举报中心（提交 targetType/targetId/reporterId/reason，管理员受理处理并记录结果，365 天留存）；Node SDK packages/client（超时、failClosed：发布类场景服务不可用时拒绝并返回“审核服务暂不可用”，有测试）；SDK 分发方式要让 qfli-server 与网关的 Docker 构建自包含（vendored 产物或已有私有源，写进 README）；Dockerfile、compose、健康检查、部署文档。

## 验收
§4 第 5（举报）、6（先审后发）、11、12 条。
