# Implement：Harness Hub

## 分工

| Pi | 窗格 | 分支 | 交付 |
|---|---|---|---|
| A | w37:pC | harness/pi-a | provider 注册表、StudioMux、LocalHarnessHost、日志读取 |
| B | w37:p14 | harness/pi-b | HerdrHost、RemoteHarnessHost |
| C | w37:pG | harness/pi-c | HarnessHub、Agents 界面、手机按键栏、设置页迁移 |
| D | w37:pJ | harness/pi-d | 技能发现、Trellis 上下文、任务面板、StudioAgentHost |

工作树：`D:/MyNewProjects/_wt/harness/pi-<x>/{qflistudio,qfli_studio_core}`。
基线：core `harness/base`（f9b6485，含契约），app `release/studio-git-ui-20261120`（d31ad29）。
简报：`reports/brief.md`。

## 阶段

- [x] P1 实现：四个 Pi 并行实现，各自提交，写 `reports/pi-<x>.md` 和 `pi-<x>.done`。
- [x] P2 互查：A 查 B，B 查 C，C 查 D，D 查 A。只写 `reports/check-<x>.md`。
- [x] P3 修复：各 Pi 处理指向自己的检查结论，写 `pi-<x>.fixed`。
- [x] P4 集成：Pi-A 在 `_wt/harness/integration` 合并四个分支，写 `reports/final-review.md`。Pi-B 只读复查，写 `reports/integration-check.md`。
- [ ] P5 brain 复核：检查集成 diff、界面截图和未验证项，再决定推送和 CI。

## 检查

- [ ] 本地只运行 `flutter pub get`、`dart format`、`flutter analyze`、`node --check`。
- [ ] 单元测试写入仓库，交给云端 CI 运行。
- [ ] 不在本地运行测试、构建、模拟器、虚拟机、WSL 或服务。
- [ ] 不对真实 Herdr 窗格执行 prompt、send-keys、start 或 attach。
- [ ] 报告列出未验证的验收项。

## 回滚点

- 每个 Pi 分支独立。丢弃分支即可回滚。
- 用户主工作树不参与本任务，集成通过后由 brain 处理。
