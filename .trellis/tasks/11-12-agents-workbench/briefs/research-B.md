# Brief B：agent harness 可行性

先读同目录 `RULES.md`。

输出文件：`.trellis/tasks/11-12-agents-workbench/research/B-harness.md`

## 调查内容

1. 从 pubspec 或文档确认 core 仓库的本地路径，以及 studio 如何使用 core。
2. 找出 core 和 studio 中现有的 AI 能力，逐项回答有或没有，并给出位置：
   - 模型调用路径（后端代理或直连），鉴权方式
   - 流式输出
   - tool calling 循环
   - 会话持久化
   - 模型列表、推理强度参数
   - 权限模式
   - 文件附件或文件引用
   - skill 或类似机制
3. 评估 prd.md 的 R7，给出推荐架构：
   - harness 放在哪一层（Dart 客户端、core、后端），并说明理由
   - 工具集：读文件、写文件、编辑、搜索、列目录、可选终端
   - 权限模式：至少包含只读、每次询问、自动接受编辑
   - skill：`SKILL.md` 的发现、加载、注入方式，项目级目录和用户级目录
   - 上下文管理：长会话压缩、中断、重试
4. 给出接口草案，精确到 Dart 抽象类和方法签名。
5. 划分最小可用范围和后续项。标出每项的工作量（小、中、大）。
6. 列出风险和未验证的假设。
