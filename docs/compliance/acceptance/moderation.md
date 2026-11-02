# 验收记录：§4 第 4 条与第 11 条（内容审核）

- 验收者：w37:p2（pi）
- 验收日期：2026-11-02
- 任务目录：`.trellis/tasks/11-02-acceptance/`
- 本次核对的代码版本
  - qflistudio：`main` @ `af5829d`（验收期间 QFLI 服务端源码零改动）
  - azurekiln-moderation：`main` @ `6d6754c`
  - azurekiln-oauth2：`compliance/gateway-w4` @ `1c1efbc`（只读核对，未修改）
- 结论汇总：第 4 条 **通过**（6 项子验证全过），第 11 条 **通过**（5 项全过）。
  线上部署与线上配置两处标“部署后复测”。

## 验收环境

本机真实进程，三段式部署，用真实 HTTP 请求取证。

| 进程 | 来源 | 端口 | 数据库 |
| --- | --- | --- | --- |
| 审核服务 | `azurekiln-moderation/src/server.js` | 临时端口 | 临时目录 `moderation.sqlite` |
| QFLI 服务端 | `azurekiln-qfli-server`（经 `scripts/compliance/local-qfli.cjs` 夹具） | 临时端口 | 临时目录 `qfli/`（SQLite） |
| 网关桩 | 验收脚本内置 | 临时端口 | 内存 |

验收脚本：`scripts/compliance/acceptance-moderation.mjs`（本任务新增，只读取三个仓库，不改文件）。

```sh
node scripts/compliance/acceptance-moderation.mjs \
  --moderation-repo D:/MyNewProjects/azurekiln-moderation \
  --json-out %TEMP%/acceptance-moderation.json
```

结果：22 个用例全部通过（21 判定 + 1 记录），脚本退出码 0。
原始 JSON 输出含全部请求与响应，可按需重跑复现。

---

## 条目 4

敏感词包含插入空格、全角、繁体等变体。词库新增后要在 10 分钟内生效。
昵称与简介同样要拦住。

结论：**通过**。

### 4.1 变体拦截（直连审核服务）

验证方法：`POST /v1/text/check {scene:"acceptance.text", text:<变体>}`，请求头 `X-App-Id: qflistudio` 与 Bearer API key。
用种子词库的赌博类词做样本，避免涉政词回显。

| 变体 | 请求文本 | 响应摘录 | 结论 |
| --- | --- | --- | --- |
| 原文 | `网络赌场` | `{"decision":"block","categories":["advertising","gambling"],"hits":2}` | 通过 |
| 插入空格 | `网 络 赌 场` | `{"decision":"block","categories":["advertising","gambling"],"hits":2}` | 通过 |
| 全角 | `ＮｅｔＷｏｒｋ 网络赌场` | `{"decision":"block","categories":["advertising","gambling"],"hits":2}` | 通过 |
| 插入符号 | `网-络-赌-场` | `{"decision":"block","categories":["advertising","gambling"],"hits":2}` | 通过 |
| 零宽字符 | `网\u200b络\u200b赌\u200b场` | `{"decision":"block","categories":["advertising","gambling"],"hits":2}` | 通过 |
| 繁体 | `網絡賭場` | `{"decision":"block","categories":["advertising","gambling"],"hits":2}` | 通过 |
| 混合（英文+空格） | `XuJi 网 络 赌 场 下注` | `{"decision":"block","categories":["advertising","gambling"],"hits":2}` | 通过 |

判定全部来自审核服务的规范化：NFKC、繁转简、小写、去除空格/标点/符号/零宽字符
（`azurekiln-moderation/src/text/normalize.js`）。

### 4.2 变体拦截（经 QFLI 发帖，真实业务路径）

验证方法：`POST /api/posts`，带 `X-Client-Platform: harmonyos-app/1.0.0`，正文含变体。

原始响应摘录：

```json
{"error":"内容未通过审核","errorKey":"moderation.blocked","categories":["advertising","gambling"]}
```

| 变体 | HTTP | 响应摘录 | 结论 |
| --- | --- | --- | --- |
| `网 络 赌 场` | 422 | `errorKey: moderation.blocked`, `categories: [advertising, gambling]` | 通过 |
| `网-络-赌-场` | 422 | 同上 | 通过 |
| `網絡賭場` | 422 | 同上 | 通过 |

对照组：干净内容同路径发布返回 `200 {"id":"post_…","status":"published"}`，说明拦截不是全量拒绝。

### 4.3 词库新增后 10 分钟内生效

验证方法：

1. `POST /v1/admin/keywords {"word":"验收词f01ad5","category":"custom"}`（admin key）
2. 立即 `POST /api/posts`，正文含该词
3. 记录两次调用的时间差

原始响应摘录：

```json
{"createStatus":201,
 "createBody":{"id":"0171b035-…","word":"验收词f01ad5","category":"custom","enabled":true,"createdAt":"2026-11-02T09:07:17.281Z"},
 "blockStatus":422,
 "blockBody":{"error":"内容未通过审核","errorKey":"moderation.blocked","categories":["custom"],"requestId":"24205d73-…"},
 "effectMs":22}
```

结论：**通过**，实测生效延迟 22 毫秒，远低于承诺的 10 分钟。

补充证据：

- `GET /v1/admin/keywords?category=custom` 立刻可见新词（`{"total":2,"found":true}`）。
- 新词的插入空格变体同样命中：`{"errorKey":"moderation.blocked","categories":["custom"]}`。
- 实现依据：`azurekiln-moderation/src/text/keywords.js` 的 `KEYWORD_CACHE_MS = 60_000`，
  写操作调用 `matcher.invalidate(appId)`，本进程缓存立即失效。多进程共享数据库时按 60 秒刷新。
  两种情况都小于 10 分钟。

### 4.4 昵称、简介拦截

验证方法：`PATCH /api/users/me`。

| 用例 | 请求 | HTTP | 响应摘录 | 结论 |
| --- | --- | --- | --- | --- |
| 昵称命中词库 | `{"nickname":"正常昵称网络赌场"}` | 422 | `{"errorKey":"moderation.blocked","categories":["advertising","gambling"]}` | 通过 |
| 简介命中变体 | `{"bio":"简介里写 网 络 赌 场 变体"}` | 422 | `{"errorKey":"moderation.blocked","categories":["advertising","gambling"]}` | 通过 |
| 干净昵称 | `{"nickname":"验收正常昵称"}` | 200 | `{"user":{…,"nickname":"验收正常昵称"…}}` | 通过 |

补充证据（顺序正确性）：本地网关桩记录的请求序列为

```json
["GET /oauth2/userinfo", …, "PUT /oauth2/profile", "GET /oauth2/userinfo"]
```

只有一次 `PUT /oauth2/profile`，对应那次干净的昵称修改。
两次命中的请求没有产生 `PUT /oauth2/profile`，说明 422 发生在写入网关之前。
业务侧改动文本先审后写，符合任务书要求。

### 4.5 网关侧昵称、简介（只读核对）

网关分支 `compliance/gateway-w4` 已接入同一份审核判定，验收未修改网关文件。

| 核对点 | 位置 | 结果 |
| --- | --- | --- |
| 资料写入前审核 | `server.js:4381`、`services/qfli-integration.js:101` 调用 `moderation.assertProfileUpdates` | 存在 |
| 判定来源是 SDK | `services/moderation.js` 用 `new ModerationClient(...).checkText` | 存在 |
| 只有 pass 才放行 | `services/moderation.js`：`block` 与 `review` 都抛 `content_rejected` | 存在 |
| 不可用即失败 | 未配置或 SDK 失败抛 `moderation_unavailable`（503） | 存在 |
| 网关自身测试 | `node --test tests/moderation.test.js tests/moderation-sdk.test.js` | 19/19 通过 |

结论：网关侧“昵称、简介也会拦住”**通过**（代码与测试两层核对）。
线上网关的实测归入 W4 的线上部署，见 4.6。

### 4.6 部署后复测

| 事项 | 现状 | 部署后要执行的命令 |
| --- | --- | --- |
| 线上审核服务词库生效时间 | 未验证（本地 6 项已通过） | `time curl -sS -X POST "$MODERATION_BASE_URL/v1/admin/keywords" -H "X-App-Id: qflistudio" -H "Authorization: Bearer $MODERATION_ADMIN_KEY" -H 'content-type: application/json' -d '{"word":"验收词YYYYMMDD","category":"custom"}'`，随即用同词发帖，确认 422 且耗时小于 600 秒 |
| 线上昵称拦截 | 未验证 | 用已验证手机号的测试账号 `PATCH https://qfli.suanxiwanjie.cn/api/users/me` 提交含词昵称，确认 422 `moderation.blocked` |
| 线上网关昵称拦截 | 未验证 | `PUT https://<网关域名>/oauth2/profile` 提交含词昵称，确认 400 `content_rejected` |

---

## 条目 11

公共审核服务独立部署。QFLI 和网关都通过 SDK 接入。审核逻辑没有写在业务代码里。

结论：**通过**。

### 11.1 独立部署

验证方法：审核服务在独立仓库 `D:/MyNewProjects/azurekiln-moderation`，
用独立进程 `node src/server.js`、独立 SQLite 数据库启动，与 QFLI 服务端无共享进程或内存。

```text
GET <moderation>/healthz → 200 {"status":"ok"}
```

| 核对点 | 证据 | 结论 |
| --- | --- | --- |
| 独立仓库 | `azurekiln-moderation` 自成 Git 仓库（`git rev-parse --show-toplevel` 指向本仓库） | 通过 |
| 独立进程 | 验收里两个进程分别由 `spawn(process.execPath, ['src/server.js'])` 和 QFLI 夹具启动 | 通过 |
| 独立数据库 | 审核服务用 `MODERATION_DB_PATH` 指向自己的 `moderation.sqlite`，QFLI 用 `QFLI_DATA_DIR` | 通过 |
| 容器化部署材料 | `Dockerfile`、`compose.yaml`、`deploy/README.md`、`deploy/nginx.conf.example` | 通过 |
| 线上部署 | 生产 hostname、TLS 证书、`MODERATION_APPS_JSON` 需运维提供 | 部署后复测 |

部署后复测命令：

```sh
curl -sS "$MODERATION_BASE_URL/healthz"
node D:/MyNewProjects/azurekiln-moderation/deploy/smoke.mjs   # 需先导出 MODERATION_BASE_URL / MODERATION_APP_ID / MODERATION_API_KEY
```

### 11.2 QFLI 通过 SDK 接入

| 核对点 | 证据 | 结论 |
| --- | --- | --- |
| 依赖是官方 SDK tarball | `azurekiln-qfli-server/package.json`：`"@azurekiln/moderation-client": "file:vendor/azurekiln-moderation-client-0.1.0.tgz"` | 通过 |
| 与审核服务同源 | 两侧 tgz 的 SHA-256 都是 `e63df6cf97b73fb67dcf33d41b0a5b1c42ea20f1c1908374ef3a337c9fcaaab5` | 通过 |
| SDK 版本与能力 | `0.1.0`，方法 `checkText, checkImage, checkIp, submitReport, getReview` | 通过 |
| 全仓只有一处加载 SDK | `src/moderation-client.js` 的 `require('@azurekiln/moderation-client')`，其余模块只调 `moderation-service` | 通过 |
| 业务进程只有端点与凭据 | QFLI 子进程的 `MODERATION_*` 环境变量仅 `MODERATION_ADMIN_KEY, MODERATION_API_KEY, MODERATION_APP_ID, MODERATION_BASE_URL` | 通过 |
| 判定与审计落在审核服务 | `GET /v1/admin/audit?action=text.check` → `{"total":22,"appIds":["qflistudio"],"actions":["text.check"]}` | 通过 |
| 代码里没有词库与规范化 | 源码里没有敏感词表、`opencc` 依赖、正则黑名单。`web-fetch.js` 的 `normalizeText` 只做网页换行整理，与审核无关 | 通过 |
| 本地不存判定数据 | `src/moderation-migration.js` 只建 `moderation_settings`、`user_moderation`、`publish_rate`、`reports` 四张表，没有 keywords 与 ip_rules 表 | 通过 |
| failClosed | 停止审核服务进程后 `POST /api/posts` → `503 {"error":"审核服务暂不可用","errorKey":"moderation.unavailable"}` | 通过 |

调用链：`routes/{posts,comments,users,reports,moderation-admin}.js`
→ `src/moderation-service.js`（只决定“哪些内容要审、什么时候拒绝发布”）
→ `src/moderation-client.js`（传输层，SDK 实例）
→ 审核服务。

### 11.3 网关通过 SDK 接入（只读核对）

| 核对点 | 证据 | 结论 |
| --- | --- | --- |
| 依赖是官方 SDK tarball | `package.json`：`"@azurekiln/moderation-client": "file:vendor/azurekiln-moderation-client-0.1.0.tgz"` | 通过 |
| 与审核服务同源 | `vendor/azurekiln-moderation-client-0.1.0.tgz` SHA-256 同为 `e63df6cf…caaab5` | 通过 |
| SDK 已安装 | `node_modules/@azurekiln/moderation-client` 存在 | 通过 |
| 判定只经 SDK | `services/moderation.js` 全仓唯一 SDK 加载点，`checkText` 发往 `POST /v1/text/check` | 通过 |
| 代码里没有审核算法 | `server.js` 与 `services/*.js` 无敏感词表、`opencc`、正则黑名单。`services/moderation.js` 第 1 行注释即声明“关键词匹配与上游 HTTP 协议属于 SDK 与服务” | 通过 |
| 测试 | `node --test tests/moderation.test.js tests/moderation-sdk.test.js` → `pass 19 / fail 0` | 通过 |
| 线上网关 | 未部署 | 部署后复测 |

部署后复测命令：

```sh
npm --prefix D:/MyNewWebProjects/azurekiln-oauth2 run check:config   # 打印 moderationConfigured 与 moderationSdkAvailable
curl -sS -o /dev/null -w '%{http_code}\n' -X PUT https://<网关域名>/oauth2/profile \
  -H "Authorization: Bearer $GATEWAY_TOKEN" -H 'content-type: application/json' \
  -d '{"name":"含敏感词昵称"}'   # 期望 400 content_rejected
```

### 11.4 门禁与回归

| 核对项 | 命令 | 结果 |
| --- | --- | --- |
| 审核服务全量测试 | `npm test`（azurekiln-moderation） | `tests 45 / pass 45 / fail 0` |
| QFLI 审核测试 | `node --test test/moderation.test.js test/moderation-sdk.test.js` | `tests 25 / pass 25 / fail 0` |
| 网关审核测试 | `node --test tests/moderation.test.js tests/moderation-sdk.test.js` | `tests 19 / pass 19 / fail 0` |
| QFLI 业务代码零改动 | `git -C qflistudio status --short` 中没有 `azurekiln-qfli-server/src` 下的文件 | 通过 |

---

## 遗留与提示

1. **SDK 未覆盖管理接口（非本条目缺陷）**：`@azurekiln/moderation-client@0.1.0` 只有
   `checkText`、`checkImage`、`checkIp`、`submitReport`、`getReview` 五个方法。QFLI 的词库与 IP 规则管理
   走 `src/moderation-client.js` 的 `adminCall`，复用同一套 `X-App-Id` 与 Bearer 凭据直接调
   `POST/PATCH/DELETE /v1/admin/*`。判定路径全部在 SDK 内，管理路径是契约内的 HTTP 调用。
   第 11 条的“审核逻辑没有写在业务代码里”仍然成立。`adminCall` 只做 URL 拼接与响应核对，
   没有词库、正则或判定算法。建议 W1 后续把管理接口补进 SDK，即可删掉这一层。
2. **线上项**：4.6 与 11.1、11.3 的线上复测要等部署完成，按上面列出的命令执行。
   当前结论是“未验证”，不得当作通过。
3. **需要用户本人办的事**：无。线上部署与 `MODERATION_APPS_JSON` 密钥由运维在部署时提供。

## 证据路径

- 验收脚本：`scripts/compliance/acceptance-moderation.mjs`
- 原始 JSON：重跑脚本加 `--json-out <路径>` 生成，包含全部请求与原始响应摘录
- 审核服务契约：`D:/MyNewProjects/azurekiln-moderation/README.md`
- 网关审核规范：`D:/MyNewWebProjects/azurekiln-oauth2/.trellis/spec/backend/moderation.md`
