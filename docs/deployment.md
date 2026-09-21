# 官方服务地址与部署

## 客户端唯一配置

修改 `lib/config/api_config.dart` 的 `ApiConfig.baseUrl`，然后重新构建应用。当前值为：

```text
https://qfli.lqsxm666.top
```

账号、注册、社区、签到、审计、云端项目、云端 Git 和在线终端都经过 `ApiClient` 的 `/api/...` 路径。应用设置和登录页没有更换软件服务器的入口，也不读取旧 `serverUrl` 作为请求目标。

用户自己的 AI 接口属于个人凭据配置；Git 仓库地址和本地 `127.0.0.1` HTML 预览同样有各自用途，不应被改成社区服务地址。个人 AI 仍使用用户显式配置的服务与密钥，客户端不会把它冒充为已上线的官方 AI 服务。

旧版登录缓存若属于其他来源，会清除令牌并要求重新登录；同一 HTTPS 来源的登录缓存可迁移。修改域名后不能直接把旧站令牌发送给新站。

云项目记录也会校验来源。旧版未记录来源的云镜像会保留为本地项目，可从官方云端列表重新导入；新的镜像目录按服务来源隔离，避免不同服务器恰好使用同一项目 ID 时覆盖彼此的代码。

## 服务端需要完成

1. 将域名 A/AAAA 解析到实际服务入口。只有可用的 IPv6 服务才添加 AAAA。
2. 配置覆盖 `qfli.lqsxm666.top` 的有效 HTTPS 证书和完整证书链，确认 SNI、443 端口和安全组。
3. 将 `/api/` 原样转发给后端，不能意外返回前端 HTML 或跳转到其他域名。参考 [Nginx 示例](deployment/nginx.conf.example)。
4. OAuth2 网关、华为回调、允许来源、上传及 WebSocket（如果后端使用）等服务端设置，也要核对公开地址。它们不在当前 Flutter 仓库中。
5. 验证 `/api/health` 返回 `200` 和 JSON `{"ok":true}`，再验证注册、登录、读帖子、上传、拉取与在线终端。

```powershell
curl.exe -i https://qfli.lqsxm666.top/api/health
```

2026-09-15 从当前开发环境检查时，HTTPS 握手失败，HTTP 也返回空响应；因此本次没有完成线上接口可用性验收。客户端接口已通过模拟 HTTP 测试。请先确认上述 DNS、证书和反向代理配置，不要将客户端降级成 HTTP 或跳过证书验证。

## 运行与本地验证

```powershell
flutter pub get
flutter analyze --no-pub
flutter test --no-pub
```

使用 flutter_ohos 时，依赖解析还会检查鸿蒙 SDK。若报 `No Hmos SDK found`，核对 DevEco 的 SDK 路径、`flutter config --ohos-sdk` 保存的路径以及 `DEVECO_SDK_HOME` / `HOS_SDK_HOME`。环境变量不会覆盖 Flutter 已保存的 SDK 配置。

当前工程测试使用自带的 `vendor/re_editor` 补丁版，不能直接换回上游包，否则移动输入补丁与本次高亮任务调度改进都会丢失。
