# 每日累计任务、积分兑换与本机统计

## Goal

让本地创建、打开项目和修改文件逐次推进每日任务，达到档位后自动发放积分与累计经验，并让用户能查看统计、签到日历和积分兑换。

## Requirements

- 创建项目、打开项目、修改文件各有每日 1/5/10 次进阶档位，管理员可调整奖励、开关和目标次数。
- 客户端保存每次成功操作的本机计数和待同步事件；断网后重试，服务端用事件 ID 防止重复奖励。
- “我的”页进入每日任务、积分兑换和统计；点击连续签到数值进入独立签到日历。
- 任务、签到日历和积分兑换优先显示账号本地缓存，每天自动读取服务端一次，手动刷新强制重新读取。
- 积分兑换和获取/扣除流水由服务端持久化，兑换扣分、库存和订单保持事务一致。

## Acceptance Criteria

- [ ] 当日第 1、5、10 次创建或修改操作分别完成对应档位；重复上传同一个事件不增加进度或积分。
- [ ] 离线操作重启客户端后仍能同步，失败时页面可见待同步状态。
- [ ] “我的”页的入口和签到日历位置正确，统计页展示今日、近 7 天和累计本机操作数。
- [ ] 手动刷新之前优先使用本机缓存；兑换后余额和流水可更新。
- [ ] 服务端测试、客户端静态分析与相关 Flutter 测试通过。

## Notes

- Keep `prd.md` focused on requirements, constraints, and acceptance criteria.
- Lightweight tasks can remain PRD-only.
- For complex tasks, add `design.md` for technical design and `implement.md` for execution planning before `task.py start`.
