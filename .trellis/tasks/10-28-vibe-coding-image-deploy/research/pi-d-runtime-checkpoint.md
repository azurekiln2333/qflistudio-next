# Pi D 运行态快照（research）

最后更新：2026-10-28。这是一份带日期的观察记录。
权威记录见 `../checkpoint-pi-d-deploy.md`。
该文件覆盖设计、代码改动、测试与实机验收。
本文件只保留当前运行态与即时待办。

## 当前运行态（al3-clean）

root 的 live 验收已通过，耗时 51 秒。
引擎冻结已释放。
容器按 root 要求保留，未重启，未删除。

| 项 | 值 |
| --- | --- |
| 容器 | `qfli-terminal-live`，`running/healthy`，`RestartCount=0` |
| 运行镜像 | `qfli-terminal-executor:local`，由当前源码构建 |
| 沙箱镜像 | `qfli-terminal-sandbox:3` |
| 端口映射 | `3101/tcp -> 127.0.0.1:3101` |
| 监听进程 | `rootlesskit pid=79` |
| 健康接口 | `ready:true`，capacity 全 0 |
| 密钥文件 | `/home/qfli-runner/.config/qfli-terminal/live.env` |
| 密钥权限 | qfli-runner 所有，0600，64 hex |
| 旧 TEST 服务 | 已 `stop`，已 `disable` |
| 旧服务备份 | `~/.config/qfli-terminal/backup-20261028-055522/` |
| 持久限额文件 | `/etc/systemd/system/user-3000.slice.d/50-qfli-limits.conf` |

运行时限额的只读检查结果如下。

| 文件 | 值 |
| --- | --- |
| `cpu.max` | `100000 100000` |
| `memory.max` | `1073741824` |
| `memory.swap.max` | `0` |
| `pids.max` | `1024` |

## 冻结约定

root live 测试期间不运行 initialize、verify-runtime、restart 或引擎变更。
健康检查只读，可以运行。
不得与 root 的 live 并发 initialize。

## 测试结果

Linux 容器内已跑完当前测试集。
镜像为 `node:24.15.0-bookworm-slim`，node 版本 v24.15.0。
命令为 `node --test test/*.test.js`。
结果为 27 tests、27 pass、0 fail、0 skipped，exit 0。
原始日志见 `linux-tests-20261028.log`，共 2422 字节。
