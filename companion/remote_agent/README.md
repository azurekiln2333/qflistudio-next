# remote_agent — 电脑侧 agent

本目录是 Studio 远程电脑功能的电脑侧后台。它在一台电脑上启动真实终端，并通过中继把终端交给已配对的手机。它同时带一个进程内局域网中继，电脑不需要公网地址。

```
手机 (Studio 远程电脑入口) ──wss──▶ 中继 ──wss──▶ 本 agent
                                                    │
                                                    ├─ PTY：PowerShell / sh / CLI
                                                    ├─ Claude SDK：结构化会话
                                                    └─ Herdr / Codex：工作区与会话
```

agent 主动连出，所以不需要端口映射。中继只做认证与转发，不解析会话内容。

## 独立运行

安装一次依赖：

```powershell
cd companion/remote_agent
npm ci
```

然后启动：

```powershell
companion\remote_agent\start.cmd
```

Linux 与 macOS 用 `./start.sh`。两个启动脚本都以自身目录为工作目录，可以在任意路径下调用。依赖缺失时它们运行一次 `npm ci`，不静默安装其他东西。

也可以直接调用入口：

```powershell
node src/agent/main.ts --help
```

## 运行方式

| 命令 | 作用 |
| --- | --- |
| `node src/agent/main.ts` | 默认方式。进程内启动局域网中继，端口 8787 |
| `--relay wss://host/ws` | 连接公网中继 |
| `--relay-key <key>` | 公网中继要求注册密钥时使用 |
| `--local-relay` / `--no-local-relay` | 显式开启或关闭进程内中继 |
| `--port <n>` | 局域网中继端口 |
| `--root <dir>` | 手机可访问的目录，可重复 |
| `--cwd <dir>` | 手机会话的默认目录 |
| `--terminal` | 同时在本机接管一个共享终端 |
| `--setup` | 交互式填写连接与启动选项 |
| `--sidecar` | 供连接助手使用的本机 socket 模式，见下一节 |
| `--reset-pairing` | 生成新身份，已配对手机都要重新配对 |
| `--help` | 全部选项 |

运行时按回车会打印新的一次性配对码。

## sidecar 模式

`companion/windows_assistant` 不直接连中继。它用 `--sidecar` 启动本 agent，然后在本机回环 socket 上收发 JSON 行：

- agent 的第一行标准输出固定是 `{"type":"listening","port":N}`。
- socket 只绑定 `127.0.0.1`，不暴露到局域网。
- 客户端发 `pair_code`、`reset_pairing`、`tool_probe`、`tool_bind`、`tool_unbind`、`tool_input`、`tool_poll_interval`、`set_relay`、`tool_start_managed`。
- agent 发 `snapshot`、`pair_code`、`stream_event`、`managed_started`、`error`。

协议实现与不变量见 `src/agent/sidecar.ts` 与 `test/sidecar.test.ts`。Studio 手机端走的是同一套中继协议，没有另立一套。

## 身份与设置

默认身份文件是 `~/.cloudterminal/agent.json`。设置 `CLOUDTERMINAL_HOME` 可改用其他目录。

- 本迁移不读取、不复制、不覆盖已有的身份文件。迁移后的 agent 第一次运行时，如果该文件已存在，就继续使用它。
- 需要隔离时，给测试或预览设置临时的 `CLOUDTERMINAL_HOME`。
- 中继地址的来源优先级：命令行参数、环境变量、`agent.json`、`bootstrap.json`、无。
- `bootstrap.json` 只用于分发包，可放中继地址与注册密钥。设置 `CLOUDTERMINAL_BOOTSTRAP` 可指定文件。
- 注册密钥与配对凭据都以明文存放在用户私有目录。该目录不进入版本库，也不进入日志。请按本机账户权限保护它。

## 目录

| 路径 | 作用 |
| --- | --- |
| `src/agent/` | agent 主体：入口、核心、PTY、Herdr、Codex、Claude SDK、sidecar、设置向导 |
| `src/relay/relay.ts` | 进程内局域网中继 |
| `src/shared/` | 协议、配对、加密、日志、账号协议 |
| `scripts/` | 端到端脚本、演示 agent、Herdr 冒烟、中继同步、隧道启动 |
| `test/` | 协议、sidecar、配对、中继、终端与 Herdr 测试 |
| `relay-core.json` | 中继核心副本的来源与哈希 |
| `TUNNEL.md` | 把中继暴露给手机的三种方式 |

## 中继核心副本

`src/relay/relay.ts`、`src/shared/relay-protocol.ts`、`src/shared/protocol-account.ts`、`src/shared/crypto.ts`、`src/shared/log.ts` 是公网中继仓库的副本。`relay-core.json` 记录来源仓库与提交号。

- 公网中继独立部署在 `cloudterminal-relay-server` 仓库，本迁移不合并该服务。
- 不要原地修改这五个文件。先改中继仓库，再用 `npm run sync-relay -- <中继仓库路径>` 同步。
- `test/relay-core-sync.test.ts` 会比对副本与清单，副本漂移即失败。

## 来源与许可

本目录从 CloudTerminal 的 `server/` 迁移而来，源提交 `49b2aac781858929a19307faeb808b83f8154410`。

- 除注释与文档里的路径外，代码未改写。协议、中继、测试和锁文件保持原样。
- 源仓库顶层没有提供 LICENSE 文件。本次迁移不新增、也不臆造许可证声明。第三方依赖各自遵循其上游许可，版本见 `package-lock.json`。
- 公网中继核心的来源与提交号以 `relay-core.json` 为准。

## 测试

```powershell
cd companion/remote_agent
npm ci
npm test
```

`npm run check` 做 TypeScript 类型检查。测试使用临时 `CLOUDTERMINAL_HOME`，不接触真实身份，也不连公网中继。云端流水线见任务报告第 4 阶段。
