# design — w37:p2 验收条目 4、11

## 范围

验收 §4 的第 4 条和第 11 条，输出 `docs/compliance/acceptance/moderation.md`。
不修业务代码。发现缺陷写复现步骤并在终端汇报。

## 验收对象

| 条目 | 被测仓库 | 边界 |
| --- | --- | --- |
| 4 敏感词拦截与 10 分钟生效 | azurekiln-moderation、azurekiln-qfli-server | 只读核对 + 本机真实 HTTP |
| 11 审核独立部署、两方经 SDK 接入 | azurekiln-moderation、azurekiln-qfli-server、azurekiln-oauth2（compliance/gateway-w4） | 网关只读 |

## 方法

1. 真实栈：本机起审核服务（独立进程、独立 SQLite）+ QFLI 服务端（SQLite）+ 本地网关桩，用真实 HTTP 请求。
   复用 `scripts/compliance/local-e2e.mjs` 的启动骨架（`local-qfli.cjs` 夹具），但验收脚本独立写，
   每条断言保留原始响应摘录。
2. 条目 4 的四类变体：插入空格、全角、繁体、零宽字符。分别直连审核服务与经 QFLI 发帖两条路径验证。
3. 条目 4 的“10 分钟生效”：经管理接口新增词，记录时间戳，再发同一文本的帖子，比对首条拦截响应时间差。
   同时记录 SDK 缓存窗口（`KEYWORD_CACHE_MS`）与进程内热加载路径，判断是否满足 10 分钟承诺。
4. 条目 4 的昵称/简介：走 `PATCH /api/users/me` 与网关 `PUT /api/profile` 两个入口。
5. 条目 11 的静态核对：`grep` 业务代码里的词库、正则、规范化实现，确认判定全部落在审核服务内。
6. 条目 11 的运行时核对：业务进程环境里只有 base URL、appId、key，不含词库；
   关停审核服务后 QFLI 发布返回 503 `moderation.unavailable`。
7. 网关侧只读：分支 `compliance/gateway-w4` 的 `services/moderation.js`、`vendor/`、`package.json`、
   `.trellis/spec/backend/moderation.md`，不改文件、不切分支。

## 证据与结论口径

- 每条给出：条目原文、命令、原始输出摘录（脱敏）、结论、证据路径。
- 结论只用：通过、失败、部署后复测、未验证。
- 线上专属项（生产 hostname、线上配置、线上部署）一律“部署后复测”，并写出确切命令。

## 风险

- 审核服务与 QFLI 都可能被其他 worker 同时改动：验收脚本只读仓库，不改源码；
  运行前记录 `git rev-parse HEAD` 作为被测基线。
- 词库种子含涉政词：验收只用自定义词与赌博类词，不回显命中的涉政词原文。
- 时间成本：10 分钟生效无法等满，用“改动 → 立即重查”证明热加载，再说明缓存上限。
