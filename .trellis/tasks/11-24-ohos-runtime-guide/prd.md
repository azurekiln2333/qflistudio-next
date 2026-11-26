# 鸿蒙运行工具安装指引

## 目标

鸿蒙本地终端提供安装指引入口。
指引使用用户提供的九款图标。
下载按钮打开对应应用市场页面。

## 需求

- 仅在鸿蒙本地终端显示入口。
- 页面展示全部九款应用。
- 当前项目的语言工具优先显示。
- 手机使用单列，大屏使用网格。
- 下载失败时允许重试或复制链接。
- 返回后保留终端会话和输入。
- 本次只做入口和指引界面。
- 用户后续补充运行调起逻辑。

## 授权

用户要求制定方案后派给四个 Pi。
用户要求完成检查、提交和推送。
用户已授权版本标签与 CI/CD。
不再次请求实施批准。

## 验收

- 九款图标、名称和链接正确匹配。
- 入口不影响其他平台与在线终端。
- 窄屏和大字体不出现溢出。
- 打开商店失败时显示可操作提示。
- 云端测试和平台构建通过。
- 真机商店跳转单独记录验收状态。

## 边界

不新增运行协议或接收端。
不探测安装状态，不自动下载。
仅允许本地格式检查和静态分析。
产品测试与构建只在云端运行。
方案和分工见 design.md 与 implement.md。


## Latest user override

All checks, including format/static analysis/lint, tests and builds, MUST run
in GitHub Actions. Local reads, edits and Git operations only. User authorizes
merging the verified feature branch into main, followed by a release tag and CI/CD.
This instruction overrides any earlier allowance for local static checks.
