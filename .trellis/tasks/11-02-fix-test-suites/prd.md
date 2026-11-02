# 测试全绿（验收第 12 条）
仓库：D:/MyNewProjects/qfli_studio_core、D:/MyNewProjects/qflistudio（Flutter 测试）。

## 背景
全量 flutter test 有既有失败（qfli_studio_core 约 7–10 个，qflistudio 约 5 个）。一部分来自 2026-11-01 08:18 工作区被 reset 后丢失的实现（如 reloadFromDisk、积分页/任务页的命名参数），一部分可能来自本轮 W3 改动或测试夹具。

## 要求
- 逐个失败定位原因并分类：本轮回归 / 丢失实现 / 夹具问题 / 测试过时。
- 本轮回归与夹具问题：修复。丢失实现：按测试描述的行为补全实现（测试即规格）。不得为了通过而删测试或放宽断言；确属过时的测试，删除前在 Result 写明理由。
- 两个仓库全量 flutter test 通过，flutter analyze 无 error。
- 不改服务端与跨应用联动代码（lib/interop、ets/interop）。

## 输出
implement.md 的 Result：每个失败的原因分类、修法、提交哈希；全量测试命令与结果。
