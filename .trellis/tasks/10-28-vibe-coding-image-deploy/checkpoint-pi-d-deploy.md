# Pi D 证据记录 — 独立镜像部署、共享引擎锁、镜像 ID 回滚

最后更新：2026-10-28。本文件是 Pi D 范围的唯一权威记录。
运行态观察见 `research/pi-d-runtime-checkpoint.md`。

范围限制：不改 root 拥有的源码。
不动的文件有根 `.cnb.yml`、`scripts/check-root-ci*` 与 `docs/deployment/scaling.md`。

## 1. 代码改动

### 1.1 共享引擎单实例围栏（内核 flock，fd 常驻）

`azurekiln-qfli-terminal/src/lock.js` 的要点如下。

- 打开锁文件用 `O_RDWR|O_CREAT|O_NOFOLLOW`，权限 0600。
- `fstat` 拒绝非普通文件。
- `ELOOP`、`EISDIR`、`ENOTDIR` 映射为 `executor_lock_invalid`。
- 其他打开失败映射为 `executor_lock_unavailable`。
- 该 fd 以 `stdio[3]` 传给短命 `/usr/bin/flock -n 3`。
- 辅助进程只加锁，加锁后立即退出。
- 锁属于本进程持有的 open file description。
- 进程退出或终止时，内核释放该锁。
- 没有辅助进程生命周期缺口，也没有重开路径的 TOCTOU。
- 同进程二次获取由模块标志拒绝。
- 锁内 `{pid,startTicks,bootId}` 仅作诊断。
- 任何代码都不 unlink `executor.lock`。
- 删路径会让第二个持有者绕过活锁，因此禁止。

`sessions.js` 在 `startEngine()` 之前取锁。
写法为 `await acquireInstanceLock(runtimeDir)`。
失败路径与 `shutdown()` 都 `await release()`。

`deployment/verify-runtime.mjs` 已删掉 `127.0.0.1:3101` 端口围栏。

`src/config.js` 的容器模式新增 `assertHostPidNamespace()`。
该函数要求 `pid: host` 与 `cgroup: host`。
判断依据是 `/proc/self/cgroup` 与 `/host/cgroup<path>/cgroup.procs`。
不满足时抛 `executor_requires_host_pid_namespace`。
该函数服务沙箱宿主 PID 检查，不是锁的前提。

### 1.2 镜像 ID 回滚

`deployment/bootstrap.sh` 在 `docker pull` 之前记录两项旧状态。

- `previous_executor_id` 取 `compose ps -q executor` 容器的 `.Image`。
- `previous_sandbox_id` 取旧 `.env` 或旧 `runner.env` 中镜像的 `.Id`。
- 两项写入 `backup_dir/images.previous.json`，权限 0600。

`restore_previous()` 合成 `.env` 时剔除原镜像键。
随后改写为固定 ID，再跑 `up -d`。

旧宿主单元回滚路径改写 `runner.env` 的 `QFLI_TERMINAL_IMAGE`。
改写值为旧 ID，改写前先备份 `runner.env.previous`。

### 1.3 重启后资源限制持久化

根因是 `systemctl set-property` 只写 `/run/systemd/transient`。
该配置在重启后失效。
重启后 `cpu.max` 变成 `max 100000`，没有 CPU 上限。

修复分三步。

1. bootstrap 先写持久 drop-in，路径为 `/etc/systemd/system/user-<uid>.slice.d/50-qfli-limits.conf`。
2. 跑 `daemon-reload`。
3. 再跑 `set-property`，让配置立即生效。

drop-in 含四项限额。

- CPU 配额为 `CPUQuota=100%`。
- 内存高水位为 `MemoryHigh=768M`，上限为 `MemoryMax=1G`。
- 交换上限为 `MemorySwapMax=0`。
- 任务上限为 `TasksMax=1024`。

bootstrap 还会断言该文件已写入。

证据范围要分清。
回归测试只断言 drop-in 的内容与写入顺序，不重启主机。
当前观测到的是生效的 cgroup 数值与该文件存在。
写入修复后没有再做一次真实重启验证。

### 1.4 限额读取 fail-closed

`src/docker.js` 新增 `readAccountLimits(base)`。
读取失败统一映射为 `sandbox_resource_controls_missing`。
修复前重启竞态会逸出裸 `ENOENT`。
日志只显示 `initialization_failed ENOENT`，难以定位。

### 1.5 子流水线修正

`azurekiln-qfli-server/.cnb.yml` 的三个任务都先跑 `npm ci`。
三个任务分别是 verify（main push）、PR 与 publish。

tag 发布用 `case "$VERSION" in *-*)` 判定预发布。
预发布只推版本化 tag，不移动 `:latest`。
终端预发布推 `qfli-terminal-sandbox:$TAG-sandbox`，不推稳定 `:3`。

Compose 拒绝 `start-period` 这个键。
两个 compose 文件都改成 `start_period`。

### 1.6 其他部署修复

旧宿主服务回滚的 `sh -c` 脚本引用 `$1`。
原调用缺 argv0 占位，`set -u` 下必然失败。
现在调用补上 `sh`，并加了静态回归测试。

`release_entries` 补入 `deployment/check-health.mjs` 与 `deployment/verify-runtime.mjs`。
缺这两项时，不带 `--source-dir` 的重跑会在预检阶段失败。
已加测试断言。

`.env.example` 的沙箱镜像补上 `:3`。
没有 tag 的引用会解析到 `latest`，因此要显式写 tag。

## 2. 测试

### 2.1 当前测试集

`azurekiln-qfli-terminal` 当前共 27 项。

| 环境 | 结果 |
| --- | --- |
| Linux 容器，node v24.15.0 | 27 tests、27 pass、0 fail、0 skipped，exit 0 |
| Windows 本地，无 flock | 22 pass、5 skip |

Linux 为 27 pass、0 skip。
Windows 跳过 5 项，因为 flock 只在 Linux 生效。
原始日志见 `research/linux-tests-20261028.log`，共 2422 字节。
日志含逐条用例与退出码。

Linux 下已实证的围栏用例有四项。

- 并行启动 8 个竞争者，只放行 1 个。
- 持有者收到 SIGKILL 后，新实例可以立即重取。
- 符号链接与非普通文件 fail-closed。
- 辅助进程退出后，围栏仍由持有者维持。

`azurekiln-qfli-server` 的结果如下。

- `node --test test/*.test.js` 为 68 tests、67 pass、1 skip、0 fail。
- `scripts/check-deployment.mjs` 通过。
- `bash -n deployment/bootstrap.sh` 通过。
- 五个 YAML 都能解析，含根 `.cnb.yml`。

### 2.2 历史测试（不再适用）

早期协议把端口围栏、PID 记录与 O_EXCL 创建混用。
跨 PID 命名空间时，第二个容器仍能取到锁，实测为 `SECOND_ACQUIRED`。
该协议已废弃，现在用内核 flock。

早期 Linux 全量测试为 23/23。
该数字属于 flock 改造前的口径，不代表当前用例数。

早期结论称锁依赖宿主 PID 命名空间，且代码未拒绝缺该前提的容器。
`assertHostPidNamespace()` 取代了该结论。

## 3. 实机验收（al3-clean）

环境为 Docker 26.1.3、Compose v2.27.0、systemd 239 与 cgroup v2。
rootless 账号为 `qfli-runner`，uid 3000，runsc 已注册。

| 项 | 结果 |
| --- | --- |
| 非 rootless 引擎跑容器模式 | `executor_requires_rootless_userns`，fail-closed |
| 缺宿主 PID 命名空间 | `executor_requires_host_pid_namespace` |
| rootless 加 `--pid=host --cgroupns=host` | 通过 uid_map、专用 socket、主机 cgroup 与账号预算检查 |
| `flock` 在镜像内 | `/usr/bin/flock`，util-linux 2.38.1 |
| 跨容器互斥，两者均 `--pid=host` | 第二个得到 `executor_already_running` |
| 持有者 `kill -9` 后重取 | 成功，无残留 |
| `docker compose config`，合成 `.env` | 通过。Compose v2.27 接受 `cgroup: host`。 |
| sandbox:3 构建并装入 rootless 引擎 | `sha256:1d73c439…`，label `toolchains=3` |
| 真实 gVisor 沙箱 | `runtime=runsc`、`user=65533:65533`、`cgroupns=private` |
| 沙箱内结果 | `python3` 输出 42，`docker` 不存在 |
| 跑完后容量 | `sessions:1`，`DELETE /v1/session` 后归零，无残留沙箱容器 |
| 容器状态 | `running/healthy`，`RestartCount=0`，capacity 全 0 |
| 运行时限额 | `cpu.max=100000 100000`、`memory.max=1073741824` |
| 其余限额 | `memory.swap.max=0`、`pids.max=1024` |

旧 TEST 服务已备份并停用，备份在 `~/.config/qfli-terminal/backup-20261028-055522/`。
未改生产。

## 4. CI 现状

根 `.cnb.yml` 由 Pi B 提供。
该文件已存在，YAML 解析通过，`scripts/check-root-ci.mjs` 通过。

根流水线从显式嵌套上下文构建三个镜像。
命名空间取根仓库 slug，即 `docker.cnb.cool/azurekiln/qflistudio-next/`。
三个镜像名分别为 `qfli-server`、`qfli-terminal` 与 `qfli-terminal-sandbox`。

本项目默认值与该命名空间一致。
涉及 `bootstrap.sh`、两个 `.env.example` 与两个 compose 文件。

尚未 push，尚未发布，也没有真实跑过 CI。
因此不能声称镜像已上线。

已知前置条件有两点。
一是 `azurekiln-qfli-server` 在父仓库中未跟踪。
二是 `azurekiln-qfli-terminal` 是嵌套 git 根，且没有 remote。
源码缺失时，根流水线会按设计报 `missing service source`。

## 5. 文档

`docs/deployment.md` 新增「业务与终端镜像部署」，位于 47 至 62 行。
同一文件还区分了个人 AI 与官方 Vibe 中继（`QFLI_AI*`）。
新章节 lint 违规 0 条。
全文仍有 24 条历史违规，未批量改写。

`azurekiln-qfli-terminal/README.md` 删掉了过期的 `--base-image` 与 `--debian-mirror` 生产说明。
该文件仍有历史违规，未批量改写。

`docs/deployment/scaling.md` 属 root，未修改。

## 6. 待办

1. 推送根流水线并跑首次真实构建（Pi B 与 root 负责）。
2. 清理中文文档的历史违规（非阻塞）。
3. 按需清理 `azurekiln-qfli-terminal/README.md` 的历史违规。

## 7. 复跑命令

```powershell
cd D:/MyNewProjects/qflistudio/azurekiln-qfli-terminal; npm test
cd ../azurekiln-qfli-server; node scripts/check-deployment.mjs; node --test test/*.test.js
cd ..; & 'D:\ProgramFiles\Git\bin\bash.exe' -n azurekiln-qfli-terminal/deployment/bootstrap.sh
python ./scripts/ste-lint-zh.py docs/deployment.md
```
