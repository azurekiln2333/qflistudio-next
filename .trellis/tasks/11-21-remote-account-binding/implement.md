# 实施计划：桌面端与手机端远程互联

## 派工

四个 Pi 在同一个 Herdr qflistudio 工作区并行工作。
每个 Pi 只写自己负责的仓库和报告文件。
所有 Pi 不得提交、推送或合并。

| Pi | 工作树 | 负责范围 | 报告 |
| --- | --- | --- | --- |
| mobile | core | 账号 scope、手机设备列表、绑定和撤销 | reports/pi-mobile.md |
| desktop | studio、core | 桌面入口、配对界面和 Agent 会话 | reports/pi-desktop.md |
| qfli | qfli-server | relay grant、introspection 和迁移 | reports/pi-qfli-server.md |
| relay | relay-server | 换票、设备授权、撤销和安全测试 | reports/pi-relay-server.md |

studio 工作树的写入边界：

- mobile 只写 Core 账号 scope、账号目录和手机页面。
- desktop 只写 Studio 工具入口、Core 本机页面和 companion 目录。
- 两个 Pi 不重叠编辑文件。

## 阶段一：冻结接口

- [ ] 所有 Pi 阅读 PRD、设计和四份调研报告。
- [ ] QFLI 与 relay 使用 design.md 的 HTTP 契约。
- [ ] mobile 只在契约稳定后接入客户端。
- [ ] 不修改五个 relay-core 同步文件。
- [ ] 不读取或复制设备密钥、环境变量值和数据库凭据。

## 阶段二：并行实现

- [ ] mobile 实现安全令牌存储和 relay API 客户端。
- [ ] mobile 实现电脑列表、绑定、撤销和错误状态。
- [ ] desktop 在三种系统显示同一配对码和链接格式。
- [ ] desktop 补充真实在线状态和配对状态。
- [ ] qfli 实现 grant 签发、单次消费和 introspection。
- [ ] qfli 绑定实名门槛、登录 session 和 gateway sub。
- [ ] relay 实现 grant 换票和带 grant 的 refresh。
- [ ] relay 修复 token kind、设备登记和 owner 初始化。
- [ ] relay 撤销设备 access、refresh 令牌并立即关闭 WebSocket。
- [ ] 每个 Pi 增加可在云端运行的回归测试。

## 阶段三：互审和联调

- [ ] root 检查四份报告和四个工作树的实际 diff。
- [ ] root 对照契约检查错误码、字段名和令牌寿命。
- [ ] root 检查账号隔离和设备撤销的数据流。
- [ ] root 检查手动配对和四种会话的兼容性。
- [ ] root 修复跨仓冲突并更新契约。

## 阶段四：验证

- [ ] 本地只运行格式化、静态分析和文档检查。
- [ ] 单元测试、集成测试和构建交给云端 CI。
- [ ] 不在本地启动服务、模拟器或设备工具。
- [ ] 检查 Windows companion 配对链接和会话流程。
- [ ] CI 覆盖 Windows、macOS 和 Linux companion 路径。
- [ ] 运行 git diff --check。
- [ ] 运行 ste-lint-zh.py 检查本任务中文文档。
- [ ] 记录尚未运行的云端、桌面和手机验收项。
- [ ] 未验证的验收项保持未完成状态。

## 阶段五：交付

- [ ] 将每项验收标准关联到测试、代码或人工步骤。
- [ ] 不部署 QFLI 服务或 relay 服务。
- [ ] 不发布预览版或正式版。
- [ ] 保留原 CloudTerminal 工作区和 Git 元数据。
- [ ] 不提交其他工作树中的用户改动。
