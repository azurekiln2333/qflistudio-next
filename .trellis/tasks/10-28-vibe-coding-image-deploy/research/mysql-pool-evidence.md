# MySQL 终端池实跑证据

## 结论

终端池在真实 MySQL 上通过集成测试。2 个用例全部通过，退出码 0。

## 环境

- 发行版：Ubuntu 24.04.4 LTS（`qfli-terminal-test`）。
- 引擎：ROOT docker 29.8.1。与终端运行时的 rootless 引擎分开。
- 镜像：`mirror.gcr.io/library/mysql:8.4`（本地缓存，未拉取）。
- 运行时：`qfli-node` v24.21.0。
- 端口：`127.0.0.1:13379`。
- 数据库：`qfli_pool_test`（一次性，含 `test`）。
- 时间：2026-10-27T21:54:21Z 至 21:54:36Z。

## 命令

```bash
QFLI_TEST_MYSQL=1 \
DB_DRIVER=mysql \
MYSQL_HOST=127.0.0.1 \
MYSQL_PORT=13379 \
MYSQL_USER=root \
MYSQL_DATABASE=qfli_pool_test \
node --test test/terminal-pool.mysql.test.js
```

## 观测输出

完整输出见 `research/mysql-pool-run.log`。关键行如下。

```
✔ MySQL schema, shared placement and cross-replica concurrency hold (1485.682026ms)
✔ MySQL dispatch path uses the shared reservation and confirms reset (43.027541ms)
ℹ tests 2
ℹ pass 2
ℹ fail 0
ℹ cancelled 0
ℹ skipped 0
ℹ duration_ms 2354.137299
TEST_EXIT=0
```

## 覆盖范围

- MySQL 新库 DDL：`terminal_slots`、`terminal_coord`、`reclaim_user_id`。
- `terminal_coord` 单行版本锁串行化放置。
- 两个模块实例模拟两个业务副本，共享同一 MySQL。
- 两用户并发放置到不同节点。
- 同用户并发放置只成功一次。
- 令牌围栏拒绝迟到提交。
- 派单与确认回收的真实 HTTP 往返。
- 进程正常退出（`db.close` 调用 `pool.end()`）。

## 未覆盖

- 旧 MySQL 库的 `ALTER TABLE` 迁移。SQLite 路径已用旧库副本验证。
- InnoDB 锁等待超时与死锁回滚。
- 生产规模并发与长时压测。

以上三项不影响本功能验收。生产验证不得据此声称完成。

## 清理

容器 `qfli-pool-mysql-root` 与卷 `qfli-pool-mysql-root-data` 在 `trap` 中删除。
rootless 引擎与 `qfli-sqlbox` 未改动。

## 文件清单

- 测试：`azurekiln-qfli-server/test/terminal-pool.mysql.test.js`
- 说明：`azurekiln-qfli-server/test/terminal-pool.mysql.README.md`
- 原始日志：`research/mysql-pool-run.log`