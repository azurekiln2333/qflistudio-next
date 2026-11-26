# 会员计划与 Token 档位

## Goal

设计并实现会员订阅和 AI Token 档位，保证 AI 与云端算力的成本至少回本。

## 用户原话（2026-11-19）

- 「顺带给我做个会员计划来？？？还有 tokenplan？？几个档位这样？」
- 「给我想几个盈利模式。。保证最起码回本的方案」
- 「这独立制定任务 trellis 规划好」
- 用户还问过「后端有没有管理面板的」。

## 现状（证据）

- 项目里没有任何支付代码。鸿蒙工程、主应用、内核和服务端都没有搜到 IAP 或支付相关实现。
- 服务端有积分系统（`.trellis/spec/backend/points-tasks.md`）：签到、每日任务、积分流水 `point_ledger`、奖励兑换 `reward_items` / `redemptions`。管理接口在 `/api/users/admin/`。
- 服务端没有网页管理面板。只有管理接口：内容审核（`src/routes/moderation-admin.js`）和积分任务/奖励。
- AI 全部经服务端中转到 DeepSeek（`azurekiln-qfli-server/src/ai-client.js`），上游返回 `usage`（prompt / completion / total tokens），中转已把它返回给客户端。
- 中转现在只有每用户限流（默认每分钟 20 次）和并发（默认 2），没有额度或记账。
- 在线终端经 gVisor 沙箱执行，按用户限额（`.trellis/spec/backend/ai-terminal-pool.md`、`terminal-isolation.md`）。
- 已有实名门槛（服务端 README「实名门槛」）。
- 11 个单语言 App 是离线版，没有服务器成本。

## 盈利方案草案（2026-11-19 已向用户提出）

1. 会员订阅（月付 / 年付）：覆盖固定成本。
2. Token 加油包：预付费点数，按上游成本的 2–3 倍定价，保证每次 AI 调用自负盈亏。
3. 免费档用签到积分和激励视频换额度。
4. 离线语言 App 买断。
5. 教育 / 团队版，按席位年付。

回本公式：付费用户数 × (客单价 × (1 − 渠道抽成) − 每个付费用户的可变成本) ≥ 每月固定成本 + 免费档预算。

## 用户决定

- D1（2026-11-19）：首期包含会员订阅（月付/年付）、Token 加油包、积分和激励视频换额度。离线 App 买断和教育/团队版不在首期。

## Requirements

- 待需求探索后填写。

## Acceptance Criteria

- [ ] 待需求探索后填写。

## Open Questions

- 各档位的价格、额度和权益。
- 支付渠道与合规要求（华为应用内支付、生成式 AI 服务收费、自动续费规则）。
- 需不需要网页管理面板。
- 真实的每月固定成本和单次 AI 调用成本。
