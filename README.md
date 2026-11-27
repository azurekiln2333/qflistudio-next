# QFLIStudioN

基于 Flutter / Material 3 的轻量级代码编辑器 + 开发者社区。

## GitHub 仓库与新电脑克隆

主应用和共享内核是两个独立的 GitHub 仓库。
新电脑先克隆这两个仓库。
应用通过 `../qflistudio-core` 引用共享内核。
内核的 Dart 包名仍为 `qfli_studio_core`。

| 用途 | GitHub 仓库 | 克隆目录 |
| --- | --- | --- |
| 主应用 | `azurekiln2333/qflistudio-next` | `qflistudio-next/` |
| 共享内核 | `azurekiln2333/qflistudio-core` | `qflistudio-core/` |

在任意空目录执行：

```bash
mkdir qflistudio-workspace
cd qflistudio-workspace
git clone --branch main --single-branch https://github.com/azurekiln2333/qflistudio-next.git qflistudio-next
git clone --branch main --single-branch https://github.com/azurekiln2333/qflistudio-core.git qflistudio-core
git -C qflistudio-core checkout --detach 1ae4674a4b153701b0c3b3ff04b1a1b77a318611
```

上例固定到本次核对的工作流 `CORE_REF`。
后续版本以目标应用提交的 `CORE_REF` 为准。
手动云端运行若覆盖此值，必须记录实际内核提交。
不要把内核 `main` 的最新提交当作兼容版本。

这些名称是克隆目标，不代表本机已有目录。
其他语言仓库按需克隆。
旧 `apps/`、`packages/` 路径仅作历史记录。

构建、测试、分析、代码生成和依赖安装均在 GitHub Actions 执行。
包名、版本和依赖解析也由云端核对。
本机不要运行 Flutter、Dart、npm、ohpm、hvigor、Gradle 或原生工具链。
不要下载或解压构建产物到工作区。

## 主页

- 底部导航：主页（项目列表）/ 教程 / 讨论 / 我的
- 根工程是联网全能版，保留社区教程、讨论、云端项目和在线终端；语言 App 是本地版，底部导航为本地项目 / 本地 JSON 教程 / 示例代码。
- 新建项目：按语言保存到 `projects/cProjects`、`projects/javaProjects` 等目录，自动创建模板代码并打开
- 项目允许重名：目录冲突时使用 `demo_<时间戳>`，显示名称从 `.qfli/project.json` 读取；新建、示例和归档导入使用同一规则
- 项目卡片显示名称与路径，支持打开、在资源管理器中显示、从列表移除；列表持久化
- 右上角搜索栏（按名称/路径实时过滤）、更多菜单（添加现有项目、移除失效项目）
- 启动：原生窗口与 Flutter 主题 surface 同色（亮 #F8F9FF / 暗 #111418），首帧后加载本地数据，去掉固定 900 毫秒等待，社区页面按需初始化
- 项目列表支持原生 Material 下拉刷新球；空列表、短列表、收藏、历史和云端列表均可刷新

## 编辑器（re_editor）

- 标准 Material TabBar 文件标签页，未保存圆点标记、关闭前确认
- 行号、代码折叠、re_highlight 语法高亮（支持 HTML 中的 CSS / JavaScript）
- 设置 → 代码高亮：TextMate / VS Code 配色导入、自定义代码颜色与基础 `.tmLanguage.json` 语法导入；[格式与兼容范围](docs/highlighting.md)
- 高亮输入合并、后台规则缓存、长行/大文件/超时回退，缩略图限制采样数量
- 查找替换（Ctrl+F，大小写/正则）、跳转到行（Ctrl+G）、格式化（Ctrl+I）
- 右侧代码鸟瞰条（minimap），点击/拖动跳行
- Ctrl+S / Meta+S 保存；文件树侧边栏为圆角卡片（无阴影细描边），宽屏可收起、窄屏为抽屉
- 运行按钮按语言分流（顺序即优先级）：
  - 语言专属 App 注入的运行时（如 C 版的应用内解释器）：直接接管
  - HTML：内置 HttpServer 在 127.0.0.1 起服务并拉起浏览器预览
  - Python / Dart：桌面端直接运行，输出进终端面板
  - Java / C / C++：桌面端编译+运行；移动端引导使用在线终端
- 本地终端：沙箱内命令响应式 shell（30 秒超时）
- 在线终端：业务 API 将已认证请求转交独立的 gVisor 沙箱执行服务。部署和限额见[云端终端与云项目](docs/deployment.md#云端终端与云项目)。

## 云端项目与 Git

- **云端项目（私有云盘）**：「主页 → 更多 → 新建云端项目」（需登录），模板文件自动上传；
  编辑时停止输入 2.5 秒自动写盘并推送到服务器（实时同步），保存立即推送；
  状态栏显示同步状态（同步中 / 已同步 / 离线）；文件树删除文件同步删除云端副本；
  支持手动「从云端拉取」（服务器覆盖本地）
- **Git**：
  - 本地项目（桌面端）：本机 git CLI —— init / 状态 / 提交 / 历史 / 远程仓库 / 推送 / 拉取
  - 云端项目：原宿主机 Git 接口已关闭；云端文件与同步继续可用
  - 移动端本地项目没有 git 二进制；在线终端为无网络的临时沙箱，不能直接连接 GitHub/Gitee

## 社区（azurekiln-qfli-server）

- 教程 / 讨论双内容类型，专区（Java、Python、C/C++、前端、Flutter、鸿蒙等）+ #标签
- 标题内容搜索、分页加载、下拉刷新
- 详情页：点赞、分享（复制）、树形评论与回复、删除自己的内容
- 发布页：类型、专区、# 标签（最多 5 个）
- 登录注册：账号密码 + AZK OAuth2 网关（授权页换登录码）+ 华为账号 Account Kit（仅鸿蒙）
- 我的：MD3 资料卡、积分与签到统计、创作入口和偏好设置；浅色/深色外观全局生效

软件服务统一连接 `https://qfli.suanxiwanjie.cn`。地址只在共享内核的 `lib/config/api_config.dart` 中维护，登录和设置不提供自定义软件服务器入口。个人 AI 接口、Git 远程仓库和本地网页预览保留各自用途。

后端不在当前仓库中，部署方式见 [官方服务配置](docs/deployment.md)。

## 云端构建与验证

本仓库不支持在新电脑上执行本地构建、测试、分析、代码生成或依赖解析。
打开工作区时，请关闭 IDE 自动构建、自动测试、自动依赖安装和项目 Sync。

通过 [App installers](.github/workflows/app-installers.yml) 查看云端任务。
检查结果时，核对以下证据：

- 应用的完整提交、包名和版本。
- 内核的完整提交、包名和版本。
- 工作流 `CORE_REF` 或手动覆盖值。
- 锁文件中的内核路径和版本。
- 解析后的包路径确实指向该内核检出。
- GitHub Actions 运行 ID、任务结果和产物来源。

路径依赖的锁文件不记录内核 Git 提交。
云端须另行记录内核检出的完整提交。
旧提交的绿灯不能证明新提交已验证。
云端构建通过也不代表真机验收完成。

旧版本地运行、HarmonyOS Sync、测试和分析记录保留在历史文档中。它们不适用于当前工作区。
仅使用 GitHub Actions 生成的获准产物。不要把本地产物或临时依赖目录放进克隆目录。

## 独立语言仓库

语言 App 是独立仓库。下表只列标准 GitHub 仓库和克隆目录。
克隆主应用不会自动创建这些目录。

| GitHub 仓库 | 标准克隆目录 | 产品 | 状态 |
| --- | --- | --- | --- |
| `azurekiln2333/qflistudio-cpp` | `qflistudio-cpp/` | C/C++ Forge | 独立仓库 |
| `azurekiln2333/qflistudio-web` | `qflistudio-web/` | WebForge | 独立仓库 |
| `azurekiln2333/qflistudio-python` | `qflistudio-python/` | PyFlow | 独立仓库 |
| `azurekiln2333/qflistudio-java` | `qflistudio-java/` | JVMX | 独立仓库 |
| `azurekiln2333/qflistudio-lua` | `qflistudio-lua/` | Script | 独立仓库 |
| `azurekiln2333/qflistudio-dart` | `qflistudio-dart/` | DartWing | 独立仓库 |
| `azurekiln2333/qflistudio-rust` | `qflistudio-rust/` | RustCore | 独立仓库 |
| `azurekiln2333/qflistudio-go` | `qflistudio-go/` | GoShift | 独立仓库 |
| `azurekiln2333/qflistudio-sql` | `qflistudio-sql/` | SQLab | 独立仓库 |
| `azurekiln2333/qflistudio-json` | `qflistudio-json/` | QFLIJson | 独立仓库 |
| `azurekiln2333/qflistudio-note` | `qflistudio-note/` | QFLINote | 独立仓库 |

需要了解早期各语言实现和路径时，见历史文档 [多语言 App：各语言在鸿蒙上的可行性与现状](docs/multi-language-apps.md)。
文中的旧 `apps/`、`packages/` 路径只作历史记录。

语言 App 的本地教程和示例读取共享内核的内容资源。当前跨产品生成流程需要对应语言仓库，
不得假定这些仓库已克隆。运行时状态以各 App 的云端版本为准。

鸿蒙运行时研究见历史文档 [语言专属 App 与鸿蒙上的本地编译](docs/c-app-and-harmonyos.md)。
C/C++ 独立仓库名称为 `qflistudio-cpp`；旧 `qfli_c` 只作为历史路径保留。

原生 picoc 后端属于 `qflistudio-cpp` 仓库。请先核对该仓库自己的 README 和云端版本。

### 历史记录：DevEco 与 C/C++ 设备构建

以下路径和操作来自旧目录布局，只供理解历史验证结果。当前工作区禁止本地依赖安装、DevEco Sync、构建、签名和设备验证。请勿执行本节命令。

旧记录曾从 `qfli_c/ohos` 打开 C App，并用 npm、ohpm 和 DevEco 生成 HAP。
旧源码位置已迁入独立 `qflistudio-cpp` 仓库。当前桌面版和鸿蒙安装包只能通过获准的 GitHub Actions 产物获取。
签名、产物校验和设备验收须遵循云端发布流程及独立授权。

## 上线规划与验证

- [会员方案](docs/membership-plan.md)：月/年会员、前 100 名及后续 200 名创始永久会员、功能分层和成本边界。
- [大陆社区上线清单](docs/community-launch.md)：企业/个体工商户的备案、实名、举报审核与安全评估准备。
- [启动与性能验证](docs/startup-and-performance.md)：已经修改的内容、自动测试和真机验收步骤。
- 个人页预览：[浅色](docs/previews/profile-light.png) / [深色](docs/previews/profile-dark.png)，[设置页](docs/previews/settings-light.png)。预览使用演示资料。

## 许可证

本仓库代码采用 GNU GPL v3.0 许可证。
单独声明许可证的内容沿用原许可证。
许可证全文见 [LICENSE](LICENSE)。
