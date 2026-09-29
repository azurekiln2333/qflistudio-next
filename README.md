# QFLIStudio+

基于 Flutter / Material 3 的轻量级代码编辑器 + 开发者社区。

## 仓库结构

主应用、11 个语言 App 和共享内核是 13 个并列的 Git 仓库。开发时把它们检出到同一父目录，
各应用通过相对路径引用共享内核，并各自维护 `pubspec.lock`。

```
checkout-parent/
  qflistudio/                主应用与跨产品校验工具
  qfli_studio_core/          共享 IDE 内核，内含补丁版 vendor/re_editor
  qfli_c/                    C/C++ App，内含 packages/qfli_c_runtime
  qfli_dart/ ... qfli_web/   其余 10 个语言 App
```

主应用是全能版；各 `qfli_*` App 是独立仓库、独立构建的单语言产品。
所有应用仓库都要与 `qfli_studio_core` 并列检出；仅克隆一个 App 时，本地路径依赖无法解析。

每个仓库单独设置 GitHub 远端、提交并推送。例如先为共享包创建 GitHub 仓库，再执行：

```bash
git -C ../qfli_studio_core remote add origin <共享包仓库 URL>
git -C ../qfli_studio_core push -u origin main
git -C ../qfli_c remote add origin <C App 仓库 URL>
git -C ../qfli_c push -u origin main
```

其他 App 和主应用同理。当前本地迁移不自动创建 GitHub 仓库或设置远端。

每个语言 App 里只有三个文件与语言相关（`lib/main.dart` 档位、`lib/<id>_runner.dart`
运行后端、`test/<id>_app_test.dart` 接线测试），其余都是复制来的平台工程。

C、C++、Python、Java、Lua、Web 和 Dart 各版的可行性、运行方式与缺口，见
[docs/multi-language-apps.md](docs/multi-language-apps.md)。

## 主页

- 底部导航：主页（项目列表）/ 教程 / 讨论 / 我的
- 根工程是联网全能版，保留社区教程、讨论、云端项目和在线终端；语言 App 是本地版，底部导航为本地项目 / 本地 JSON 教程 / 示例代码。
- 新建项目：选择类型（空项目/Java/Python/C/C++/HTML/Dart），自动创建初始 demo 代码并直接打开
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
- 在线终端：命令发送到 azurekiln-qfli-server 执行（每用户隔离目录，15 秒超时）

## 云端项目与 Git

- **云端项目（私有云盘）**：「主页 → 更多 → 新建云端项目」（需登录），模板文件自动上传；
  编辑时停止输入 2.5 秒自动写盘并推送到服务器（实时同步），保存立即推送；
  状态栏显示同步状态（同步中 / 已同步 / 离线）；文件树删除文件同步删除云端副本；
  支持手动「从云端拉取」（服务器覆盖本地）
- **Git**：
  - 本地项目（桌面端）：本机 git CLI —— init / 状态 / 提交 / 历史 / 远程仓库 / 推送 / 拉取
  - 云端项目：服务器端 git（服务器需安装 git）——提交自动注入身份，无需部署机配置；
    远程仓库可指向 GitHub/Gitee（https 地址内嵌凭据）
  - 移动端本地项目没有 git 二进制，可用在线终端手动操作

## 社区（azurekiln-qfli-server）

- 教程 / 讨论双内容类型，专区（Java、Python、C/C++、前端、Flutter、鸿蒙等）+ #标签
- 标题内容搜索、分页加载、下拉刷新
- 详情页：点赞、分享（复制）、树形评论与回复、删除自己的内容
- 发布页：类型、专区、# 标签（最多 5 个）
- 登录注册：账号密码 + AZK OAuth2 网关（授权页换登录码）+ 华为账号 Account Kit（仅鸿蒙）
- 我的：MD3 资料卡、积分与签到统计、创作入口和偏好设置；浅色/深色外观全局生效

软件服务统一连接 `https://qfli.lqsxm666.top`。地址只在共享内核的 `lib/config/api_config.dart` 中维护，登录和设置不提供自定义软件服务器入口。个人 AI 接口、Git 远程仓库和本地网页预览保留各自用途。

后端不在当前仓库中，部署方式见 [官方服务配置](docs/deployment.md)。

## 运行

```bash
flutter pub get

# 全能版（根工程）
flutter run -d windows   # 或鸿蒙设备

# 单语言版（在主仓库的并列目录）
cd ../qfli_c && flutter pub get && flutter run -d windows

flutter analyze --no-pub
```

为尚不存在的语言生成独立 App 仓库（再补运行后端）：

```bash
dart run tool/new_language_app.dart go    # 已存在的目标会跳过；新目标生成在并列目录
```

生成器会一并装好新 App 的 `ohos/` 依赖（`npm install` + `ohpm install`）。
**这一步不能省**：本机上 flutter 工具不会替你做（`installHvigorPlugin` 排在
`updateLocalProperties` 后面，后者找不到 HarmonyOS SDK 就退出了），缺了它一在
DevEco 里 Sync 就报 `Cannot find module 'flutter-hvigor-plugin'`。
详见 [docs/multi-language-apps.md](docs/multi-language-apps.md)。

想在命令行里跑 hvigor（不走 DevEco 图形界面）：

```bash
tool/sync_ohos.sh qfli_c        # Sync：设 DEVECO_SDK_HOME、绕开 ohpm.bat 的递归
tool/build_hap.sh qfli_c        # 出 HAP（unsigned，签名见下）
```

两个脚本都会检查对应 App 的 `.flutter-plugins-dependencies`。缺少时先进入那个 App
目录运行 `flutter pub get`；每个仓库现在自行生成插件清单。

`build_hap.sh` 产出的是 **unsigned** HAP：仓库里的 `.p7b` 绑的是别的 bundleName，
要装真机得先在 DevEco 里配签名（File → Project Structure → Signing Configs →
勾 *Automatically generate signature*）。

各仓库分别运行测试：

```bash
(cd ../qfli_studio_core && flutter test)
(cd ../qfli_c/packages/qfli_c_runtime && flutter test)
(cd ../qfli_c && flutter test --no-pub)
(cd ../qfli_python && flutter test --no-pub)
(cd ../qfli_java && flutter test --no-pub)
(cd ../qfli_lua && flutter test --no-pub)
(cd ../qfli_web && flutter test --no-pub)
(cd ../qfli_dart && flutter test --no-pub)
```

> 语言 App 的测试建议加 `--no-pub`。它们带了 `ohos/` 平台目录，`flutter test` 不加这个
> 参数时会先做一遍全平台工具链校验，本机没有 HarmonyOS SDK 就报
> `No Hmos SDK found` 并**直接退出 1，一个用例都不跑**——看起来像测试挂了，
> 其实是环境检查没过。共享包没有 `ohos/`，不加也能跑。

> 本机如果挂了 HTTP 代理，跑 `flutter test` 前需要
> `export NO_PROXY="localhost,127.0.0.1,::1"`，否则测试用的本地 WebSocket 会被代理拦掉。

## 语言专属 App

一个语言一个 App，共享同一套 IDE 内核。现有 11 个语言 App，另有主联网全能版：

| App | 运行方式 | 状态 |
| --- | --- | --- |
| `../qfli_c` | C/C++ Forge | 独立仓库 |
| `../qfli_web` | WebForge | 独立仓库 |
| `../qfli_python` | PyFlow | 独立仓库 |
| `../qfli_java` | JVMX | 独立仓库 |
| `../qfli_lua` | Script | 独立仓库 |
| `../qfli_dart` | DartWing | 独立仓库 |
| `../qfli_rust` | RustCore | 独立仓库 |
| `../qfli_go` | GoShift | 独立仓库 |
| `../qfli_sql` | SQLab | 独立仓库 |
| `../qfli_json` | QFLIJson | 独立仓库 |
| `../qfli_note` | QFLINote | 独立仓库 |

C、C++、Python、Java、Lua、Web、Dart 的可行性、教程 JSON、离线页面和路线图，见
[多语言 App：各语言在鸿蒙上的可行性与现状](docs/multi-language-apps.md)。

语言 App 的第二页由 `TutorialService` 从共享仓库的 `assets/tutorials/<language>.json`
加载本地教程，第三页从同一份类型化数据展示可复制示例代码。后续把服务实现替换为 API
时不需要改页面模型；语言运行时仍按各 App 的实际状态展示，未实现的解释器不会伪造运行结果。

之所以是「解释」而不是「编译」（鸿蒙普通应用 exec 不了任何可执行文件），
以及 C 版是怎么落地的，见 [语言专属 App 与鸿蒙上的本地编译](docs/c-app-and-harmonyos.md)。

原生 picoc 后端（可选，需要 NDK）见 `../qfli_c/native/README.md`。

### 在 DevEco 里构建 C 版

用 DevEco Studio **Open `../qfli_c/ohos`**。等 Sync 跑完
（它会 `npm install` 装 `flutter-hvigor-plugin`、再 `ohpm install`），点 Run 即可。
Flutter 产物由 hvigor 插件自动 `flutter assemble` 并拷贝，不用手动跑 `flutter build hap`。

> **全新克隆要先补两个被 gitignore 的文件**：`ohos/local.properties`（写 `flutter.sdk`）
> 和 `ohos/package.json`（声明 `flutter-hvigor-plugin`）。它们本来由 flutter 工具生成，
> 但那条链路要先把 HarmonyOS SDK 找出来，本机找不到就直接退出了，所以得手工补。
> 具体内容见 [docs/c-app-and-harmonyos.md](docs/c-app-and-harmonyos.md#在-deveco-里构建)。

**构建前要配签名**：`ohos/build-profile.json5` 的 `signingConfigs` 是有意留空的。
`.p7b` 描述文件绑定 bundleName，`D:/Keystore` 下没有属于 `com.azurekiln.qflistudio.c`
的描述文件。最快的路是 File → Project Structure → Signing Configs →
勾 `Automatically generate signature`。细节见同一节。

## 上线规划与验证

- [会员方案](docs/membership-plan.md)：月/年会员、前 100 名及后续 200 名创始永久会员、功能分层和成本边界。
- [大陆社区上线清单](docs/community-launch.md)：企业/个体工商户的备案、实名、举报审核与安全评估准备。
- [启动与性能验证](docs/startup-and-performance.md)：已经修改的内容、自动测试和真机验收步骤。
- 个人页预览：[浅色](docs/previews/profile-light.png) / [深色](docs/previews/profile-dark.png)，[设置页](docs/previews/settings-light.png)。预览使用演示资料。
