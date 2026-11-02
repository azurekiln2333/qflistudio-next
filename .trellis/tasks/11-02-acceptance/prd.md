# 逐条验收（任务书 §4）
需求：docs/compliance/2026-11-整改任务书.md §4 与“补充规则”。验收者不验收自己实现的部分。

## 分工
| 验收者 | 条目 | 输出文件（qflistudio 仓库） |
|---|---|---|
| w37:p7 | 1、2、3（服务端）、5、6、7（服务端）、9（服务端） | docs/compliance/acceptance/server.md |
| w37:p2 | 4、11（含：QFLI 与网关都通过 SDK 接入，业务代码里没有审核逻辑） | docs/compliance/acceptance/moderation.md |
| w37:p6（客户端完成后 root 派发） | 3（客户端）、8、9（客户端）、10、12，并汇总 | docs/compliance/acceptance/client.md，汇总到 docs/compliance/2026-11-验收记录.md |

## 方法
- 在本机起真实环境：审核服务 + QFLI 服务端（SQLite），用真实 HTTP 请求逐条验证。可以复用 scripts/compliance/local-e2e.mjs 与 smoke.mjs，但每条都要有自己的请求和原始响应摘录。单元测试通过不等于验收通过。
- 需要线上环境的部分（线上配置的保留期、nginx 源端口、线上部署）标“部署后复测”，并写出部署后要执行的确切命令，不得写“通过”。
- 网关侧（W4）只做接口层核对，不改网关仓库。
- 每条格式：条目原文 / 验证方法（命令或请求）/ 实际结果（原始输出摘录，脱敏）/ 结论（通过、失败、部署后复测、未验证）/ 证据路径。
- 发现失败：写下复现步骤并在终端汇报，不要自己修业务代码，由 root 另派修复。
- 只写自己的输出文件；提交规则见父任务 rules.md（不署名、不 push、显式路径）。
