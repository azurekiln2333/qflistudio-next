# implement — w37:p2 验收条目 4、11

## 步骤

- [x] 1. 记录被测基线：三个仓库的当前分支与 `git rev-parse HEAD`。
- [x] 2. 读审核服务规范：`azurekiln-moderation/README.md`、`packages/client/README.md`、
      `.trellis/spec/backend/moderation-contract.md`。
- [x] 3. 写验收脚本 `scripts/compliance/acceptance-moderation.mjs`。
- [x] 4. 运行脚本，保存原始输出：22 个用例，21 判定全通过，退出码 0。
- [x] 5. 网关只读核对：`compliance/gateway-w4` 的 SDK 接入点与依赖。
- [x] 6. 静态核对业务代码：没有词库、正则或规范化实现。
- [x] 7. 写 `docs/compliance/acceptance/moderation.md`。
- [x] 8. 跑仓库现有测试与 ste-lint-zh。
- [x] 9. 提交并回写 Result。

## 校验命令

```sh
node scripts/compliance/acceptance-moderation.mjs --moderation-repo D:/MyNewProjects/azurekiln-moderation --json-out %TEMP%/acceptance-moderation.json
node --test scripts/compliance/
python scripts/ste-lint-zh.py docs/compliance/acceptance/moderation.md
git -C azurekiln-qfli-server diff --quiet   # 业务代码零改动
```

## 边界

只新增 `scripts/compliance/acceptance-moderation.mjs` 与
`docs/compliance/acceptance/moderation.md`，以及本任务目录下的规划文件。
不动 `azurekiln-qfli-server/src`、不碰网关工作区文件。

## Result

### 提交列表

- `(见下)` 共 1 个提交，提交后回填短哈希

### 测试命令与结果

| 命令 | 结果 |
| --- | --- |
| `node scripts/compliance/acceptance-moderation.mjs --moderation-repo D:/MyNewProjects/azurekiln-moderation --json-out %TEMP%/acceptance-moderation.json` | 退出码 0，22 个用例（21 判定全通过 + 1 顺序证据） |
| `node --test scripts/compliance/*.test.mjs` | `tests 16 / pass 16 / fail 0` |
| `npm test`（azurekiln-moderation） | `tests 45 / pass 45 / fail 0` |
| `node --test test/moderation.test.js test/moderation-sdk.test.js`（azurekiln-qfli-server） | `tests 25 / pass 25 / fail 0` |
| `node --test tests/moderation.test.js tests/moderation-sdk.test.js`（azurekiln-oauth2） | `tests 19 / pass 19 / fail 0` |
| `python scripts/ste-lint-zh.py docs/compliance/acceptance/moderation.md` | 硬违规 0 处 |

### 结论

- 条目 4：通过。变体（空格、符号、全角、零宽、繁体）全部命中；新词 22 毫秒生效；
  昵称与简介经 QFLI 与网关两侧都拦住，且 422 发生在写网关之前。
- 条目 11：通过。审核服务独立仓库与独立进程；QFLI 与网关都用同一个官方 SDK tarball
  （SHA-256 一致）；业务代码没有词库与判定算法；审核服务停机时 QFLI 发布返回 503 failClosed。

### 未完成项及原因

- 线上项（线上词库生效时间、线上昵称拦截、线上网关拦截、线上部署校验）：
  当前未部署，标“部署后复测”，已写出确切命令，不当作通过。

### 需要用户本人办的事

- 无。线上部署与 `MODERATION_APPS_JSON` 密钥由运维在部署时提供。
