# 通用规则（所有 worker 必须遵守）

1. 先读 docs/compliance/2026-11-整改任务书.md（§0、§1、§2、§3 你的部分、§4）、本目录 contracts.md、你的 prd.md。§1 是硬约束。遵守目标仓库 AGENTS.md 与 .trellis/spec。
2. 在你的任务目录先写简短 design.md、implement.md，再实现；完成后在 implement.md 末尾写 Result：提交列表（短哈希+标题）、测试命令与结果、未完成项及原因、需要用户本人处理的事。
3. 只改你边界内的文件。同一仓库有其他 worker 并行，不要改、不要提交、不要格式化别人的文件。
4. Git：禁止 git reset、checkout --、restore、stash、clean、rebase、amend、切分支、push、force push；禁止 git add -A 或 git add 点号。只用 git add 显式路径，或 git commit -F 消息文件 -- 路径；消息文件放 %TEMP%，不要留在仓库。
5. 提交信息：标准 Conventional Commits（type(scope): 祈使句摘要，正文写原因），沿用仓库现有格式；不得有任何署名：不写 Co-Authored-By，不写 Generated with 之类。
6. 改动要有测试，不得让现有功能回归；提交前跑相关测试。不提交密钥、签名材料、.env、构建产物、大于 5MB 的新增文件。不引入跳过 SSL 证书校验的代码。不新增任务书未披露的第三方服务。
7. 必须由用户本人办的事（AGC 后台、密钥、上架）记入 Result 继续做其余部分，不要停下等待。完成或真正卡住时，在终端用一段话汇报。
