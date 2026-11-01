# 官方服务地址与部署

## 客户端唯一配置

修改 `lib/config/api_config.dart` 的 `ApiConfig.baseUrl`，然后重新构建应用。当前值为：

```text
https://qfli.suanxiwanjie.cn
```

账号、注册、社区、签到、审计、云端项目、云端 Git 和在线终端都经过 `ApiClient` 的 `/api/...` 路径。应用设置和登录页没有更换软件服务器的入口，也不读取旧 `serverUrl` 作为请求目标。

用户自己的 AI 接口属于个人凭据配置；Git 仓库地址和本地 `127.0.0.1` HTML 预览同样有各自用途，不应被改成社区服务地址。个人 AI 仍使用用户显式配置的服务与密钥，客户端不会把它冒充为已上线的官方 AI 服务。官方 Vibe 编码走业务后端中继：服务器用 `QFLI_AI_BASE_URL`、`QFLI_AI_API_KEY`、`QFLI_AI_MODEL` 等 `QFLI_AI*` 环境变量调用模型，与个人 AI 配置相互独立，客户端不持有官方密钥。

旧版登录缓存若属于其他来源，会清除令牌并要求重新登录；同一 HTTPS 来源的登录缓存可迁移。修改域名后不能直接把旧站令牌发送给新站。

云项目记录也会校验来源。旧版未记录来源的云镜像会保留为本地项目，可从官方云端列表重新导入；新的镜像目录按服务来源隔离，避免不同服务器恰好使用同一项目 ID 时覆盖彼此的代码。

## 服务端需要完成

1. 将域名 A/AAAA 解析到实际服务入口。只有可用的 IPv6 服务才添加 AAAA。
2. 配置覆盖 `qfli.suanxiwanjie.cn` 的有效 HTTPS 证书和完整证书链，确认 SNI、443 端口和安全组。
3. 将 `/api/` 原样转发给后端，不能意外返回前端 HTML 或跳转到其他域名。参考 [Nginx 示例](deployment/nginx.conf.example)。
4. OAuth2 网关、华为回调、允许来源、上传及 WebSocket（如果后端使用）等服务端设置，也要核对公开地址。它们不在当前 Flutter 仓库中。
5. 验证 `/api/health` 返回 `200` 和 JSON `{"ok":true}`，再验证注册、登录、读帖子、上传、拉取与在线终端。

```powershell
curl.exe -i https://qfli.suanxiwanjie.cn/api/health
```

2026-09-15 从当前开发环境检查时，HTTPS 握手失败，HTTP 也返回空响应；因此本次没有完成线上接口可用性验收。客户端接口已通过模拟 HTTP 测试。请先确认上述 DNS、证书和反向代理配置，不要将客户端降级成 HTTP 或跳过证书验证。

## 云端终端与云项目

在线终端需要单独部署 [隔离执行服务](../azurekiln-qfli-terminal/README.md)。业务后端配置 `QFLI_TERMINAL_URL` 和独立 `QFLI_TERMINAL_SECRET`，只转发认证后的用户请求；App 不持有内部密钥。内部服务仅监听 `127.0.0.1:3101`，跨机器通过受来源限制的内部 HTTPS 接入，不公开该端口。业务账号不能拥有 Docker 权限。

执行宿主须为 Alibaba Cloud Linux 3 或 Ubuntu 24.04 x86_64，使用 systemd 239+、专用非 root 账号、rootless Docker、gVisor runsc、cgroup v2 和实际生效的账号资源限制。兼容方案让 gVisor 使用已受限的执行账号 cgroup，避开 systemd 239 不支持的独立 cgroup 创建接口。执行服务仍核对实际限额及沙箱进程归属，失败时保持不可用。CI 构建全部镜像并推送到 CNB，服务器只执行 `pull`，不在本机构建服务或工具链。当前运行验收进度见 [验收记录](../azurekiln-qfli-terminal/docs/runtime-validation.md)，不能仅凭静态检查认定两个系统均通过。

2 核 / 2 GiB 默认最多 1 个会话、1 个执行槽，FIFO 最多 8 条等待请求、20 秒等待，每用户最多一条执行或等待。执行账号整体最多 1 核 / 1 GiB，包含 Docker、gVisor、执行 Node 和唯一沙箱，swap 为 0；OS、业务、数据库和宝塔还需共用剩余内存。空闲会话 2 分钟回收且仍占容量，其他用户可能因会话满收到 429。镜像提供 Java、Lua、Node.js、Python、PHP、Go、Rust、Dart 及 C/C++；外网关闭，远程依赖不能在会话里下载。

`/api/terminal/exec/stream` 是 NDJSON 进度与输出接口；代理需关闭响应缓冲、缓存及压缩，并保持客户端取消向业务层传递。终端请求体上限 384 KiB，项目快照最多 64 文件、解码后 256 KiB。底部终端隐藏时执行保留，显式关闭或编辑器退出时取消并尝试释放沙箱。首次运行按需创建，打开 App 或查询 `/pwd` 不创建沙箱。

终端文件只在临时会话期间保留；重置、超时、断开、到期和服务重启会清除。云项目独立持久保存且不挂载进沙箱。旧云端 Git 的宿主执行已禁用，普通云文件同步保留。云存储应使用独立限容量卷，与数据库磁盘分开。

反向代理的终端请求超时建议至少 120 秒（含创建和回收时间），App 的终端请求超时为 110 秒，业务转发为 85 秒；用户命令实际执行期限为 60 秒。旧实例曾执行宿主命令，上线前需要检查残留进程和轮换旧业务凭据。详细部署、失败恢复和 Linux 验收要求见上述文档。

## 业务与终端镜像部署

业务后端与在线终端是两个独立容器。两者分别配置资源限额和更新范围。终端故障不触发业务容器重启。

镜像在 CNB 流水线构建，服务器只拉取。业务镜像为 `qfli-server:latest`，执行镜像为 `qfli-terminal:latest`，沙箱工具链镜像为 `qfli-terminal-sandbox:3`。三者都放在 `docker.cnb.cool/${CNB_REPO_SLUG_LOWERCASE}/` 命名空间。流水线在发布前先跑单元测试。预发布标签只推版本化标签，不移动 `latest` 或稳定沙箱标签。

业务容器不获取 Docker socket。执行器与更新容器使用专用 rootless socket。终端保持 rootless Docker、runsc、cgroup 校验与 fail-closed，不放宽隔离，也不把宿主 root Docker socket 交给用户代码。

终端健康检查 `/health` 返回 `ready` 与 `capacity`。`capacity` 含 `sessions`、`running`、`waiting`、`sessionsLimit`、`runningLimit`、`queueLimit`，不泄露用户、密钥或命令。业务后端据此判断节点可用性。

多执行节点时，业务后端用 `QFLI_TERMINAL_NODES` 配置 JSON 数组。每个节点独立设置 `id`、`url`、`secret`，可选 `draining`。节点升级前先置 `draining`，排空后单独升级该节点。业务与终端的生命周期不捆绑。

回滚按不可变镜像 ID 进行。安装脚本在 `pull` 之前记录旧执行容器与旧沙箱镜像的 ID，恢复时写回这些 ID。只备份可变标签不够，因为 `pull` 之后标签已指向新镜像。

业务当前为单进程状态。待完成的授权与 MFA 在内存，refresh token 轮换锁在进程内。因此多业务副本需要先共享这些状态。共享前只部署单副本。

## 运行与本地验证

```powershell
flutter pub get
flutter analyze --no-pub
flutter test --no-pub
```

使用 flutter_ohos 时，依赖解析还会检查鸿蒙 SDK。若报 `No Hmos SDK found`，核对 DevEco 的 SDK 路径、`flutter config --ohos-sdk` 保存的路径以及 `DEVECO_SDK_HOME` / `HOS_SDK_HOME`。环境变量不会覆盖 Flutter 已保存的 SDK 配置。

当前工程测试使用自带的 `vendor/re_editor` 补丁版，不能直接换回上游包，否则移动输入补丁与本次高亮任务调度改进都会丢失。
