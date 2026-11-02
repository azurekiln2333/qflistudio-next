# 客户端与全仓检查验收记录

日期：2026-11-03。时区：UTC+08:00。
验收者：w37:p7，接手原 w37:p6 的分工。
本轮覆盖第 3 条客户端、第 8、9、10、12 条。
业务代码保持只读。
本轮没有操作锁屏设备。

## 结论

| 条目 | 结论 | 依据 |
|---|---|---|
| 3 客户端 | 通过，本地 widget 范围 | 鸿蒙登录入口受限，无手机号时不能跳过或绑定 |
| 8 | 失败，待协议地址 | 两个入口均为 3 次点击，用户协议正文尚不可读 |
| 9 | 失败 | 旧 AI 地址仍生效，部分文件没有标识 |
| 10 | 需真机，未验证 | Mate 60、Mate X5 折叠和展开均未实测 |
| 12 | 失败，另需部署后复测 | 预览测试失败，两处 analyze 失败，服务端缺少 lint |

第 9 条的 Bing 调用扫描通过。
第 12 条的提交信息检查通过。
两项通过均不能覆盖同条中的失败。

## 环境与证据

主检查时间为 04:16:30 至 04:17:53。
补充检查截至 04:48:36。

| 项目 | 主检查版本 | 补充检查版本 |
|---|---|---|
| qfli_studio_core | `6ac1442` | `6ac1442` |
| qflistudio | `20382e2` | `1a1d8df` |
| azurekiln-qfli-server | 父仓库 `20382e2` | 父仓库 `1a1d8df` |
| azurekiln-moderation | `6d6754c` | `6d6754c` |

服务端属于 qflistudio 的 Git 根目录。
它不是独立的 Git 仓库。
期间新增的父仓库提交只更新发版记录。
主检查覆盖的源码哈希没有变化。
原有脏文件保持原状。
本轮没有提交其他 worker 的文件。

工具版本如下。

```text
Node v24.15.0
Flutter 3.27.5-ohos-1.0.1
Flutter revision 12587c79e88aacf3172a84e536f226457d037594
Dart 3.11.5
```

下文用 E 表示原始证据目录。

```text
D:/AppData/Local/Temp/qfli-client-acceptance-20261103-p7-xvt69sg9
```

| 证据 | 内容 |
|---|---|
| `E/manifest.json` | 初始版本、脏文件、主检查源码哈希 |
| `E/summary.json` | 主检查命令、超时、退出码与源码变化 |
| `E/source-review.json` | 补充检查版本、扫描数量、提交数量 |
| `E/global-bing-scan.json` | 扫描范围、逐处命中与上下文 |
| `E/commit-audit.json` | 完整提交信息及逐条判定 |
| `E/*.log`、`E/*.json` | 各命令原始输出与计时 |

任务内的 evidence-summary.json 保留结果索引。
该索引也保存原始证据的 SHA-256。

复跑入口位于任务的 client 子目录。
各命令的外层超时由 Python 控制。
超时后只停止本轮命令的进程树。
Node 测试不继承生产密钥或生产数据库设置。
Flutter 检查使用已解析依赖，不更新锁文件。

```powershell
cd D:/MyNewProjects/qflistudio
python -X utf8 -u .trellis/tasks/11-02-acceptance/client/bounded_checks.py
# 用上一命令打印的新 evidenceRoot 替换 <E>。
python -X utf8 -u .trellis/tasks/11-02-acceptance/client/supplemental_checks.py --evidence <E>
```

脚本会保留失败输出并继续独立检查。
当前版本遇到检查失败时返回非零退出码。
AI 探针通过表示缺口复现，不表示合规通过。

## 第 3 条：客户端登录限制

**条目原文**

```text
没有手机号的华为账号无法跳过绑定直接建号；鸿蒙端看不到"其他方式登录"和注册入口。
```

**验证方法**

执行内核全量测试。
另跑登录、设置、文件标识测试以保留清晰摘录。
检查生产登录页与绑定页的条件分支。

```powershell
cd D:/MyNewProjects/qfli_studio_core
flutter test --no-pub test/auth_login_entry_test.dart test/settings_compliance_test.dart test/ai_file_header_test.dart --reporter expanded --timeout 1m
# 外层超时 120 秒。见 supplemental_checks.py。
```

**实际结果**

```text
HarmonyOS login page offers only Huawei one-tap login
Binding page without a phone number blocks skipping
Huawei rejections a missing phone number shows the server guidance
00:01 +33: All tests passed!
```

测试把平台设为 ohos。
登录页没有其他登录入口和注册文字。
无手机号的绑定页没有建号入口。
绑定按钮存在，但回调为空。
页面显示“请使用已绑定手机号的华为账号”。
有手机号的正向对照仍可绑定或建号。

**结论：通过，本地 widget 范围。**
真实华为授权仍需部署与真机证据。
服务端判定见 `server.md` 第 3 条。

**证据路径**

- `E/core-compliance-widgets.log`。
- `qfli_studio_core/test/auth_login_entry_test.dart`。
- `qfli_studio_core/lib/pages/auth/login_page.dart:194`。
- `qfli_studio_core/lib/pages/auth/account_login_page.dart:70`。

## 第 8 条：协议与撤回同意

**条目原文**

```text
设置里能找到用户协议、隐私政策（不超过 4 次点击）和撤回同意入口。
```

**验证方法**

任务独立 widget 测试挂载真实 HomePage。
它使用主应用的 qfliStudioProfile。
测试点击真实底栏和 ListTile。
它不直接调用页面导航函数。
两个视口分别为 360×800、600×1000。
滚动不计入点击次数。
协议阅读通道使用测试夹具。
夹具只记录调用，不证明原生阅读器可用。

```powershell
cd D:/MyNewProjects/qflistudio
flutter test --no-pub .trellis/tasks/11-02-acceptance/client/navigation_click_test.dart --reporter expanded --timeout 1m
# 外层超时 120 秒。
```

**实际结果**

```text
ACCEPTANCE path=Home>我的>设置>用户协议 taps=3 viewport=360.0x800.0 scrolls=allowed nativeReader=fixture userAgreementPublished=false
ACCEPTANCE path=Home>我的>设置>隐私政策 taps=3 viewport=360.0x800.0 scrolls=allowed nativeReader=fixture userAgreementPublished=false
ACCEPTANCE path=Home>我的>设置>用户协议 taps=3 viewport=600.0x1000.0 scrolls=allowed nativeReader=fixture userAgreementPublished=false
ACCEPTANCE path=Home>我的>设置>隐私政策 taps=3 viewport=600.0x1000.0 scrolls=allowed nativeReader=fixture userAgreementPublished=false
00:02 +4: All tests passed!
```

路径为主界面→我的→设置→协议入口。
每条路径均为 3 次点击。
小屏需滚动到设置和协议项。
测试在点击前检查目标可命中。

隐私政策调用携带以下托管地址。

```text
https://agreement-drcn.hispace.dbankcloud.cn/index.html?lang=zh&agreementId=2045441424513576896
```

用户协议地址为空。
点击后只显示“协议暂未发布”。
这符合任务书允许暂留空的实现约定。
它仍缺少可阅读正文，不能完成最终验收。

设置页同时提供撤回同意与注销入口。
未登录时禁用这两个操作。
已有 widget 测试验证撤回确认与退出登录。
它也验证注销必须输入确认词。

```text
account and privacy section withdrawing consent signs out and never claims a host call
account and privacy section erasure needs the typed confirmation word
```

当前原生 requestPrivacyWithdraw 返回 false。
Flutter 随后删除本地登录信息。
界面提示到系统设置撤回授权。
这条分支不调用远端 logout。
它只调用 AuthStore.clearLocalData。
该方法删除令牌和用户资料。
它没有删除头像、审计或统计缓存。
本轮未证明所有本机个人缓存均已删除。
注销成功后的缓存删除属于另一条代码路径。

**结论：失败，待用户协议地址。**
入口与点击预算通过。
撤回的本地退出分支通过。
原生阅读、真实授权撤回仍需真机。
全部个人缓存的撤回后删除仍未验证。

**证据路径**

- `E/navigation-widget-final.log`。
- `E/core-compliance-widgets.log`。
- `.trellis/tasks/11-02-acceptance/client/navigation_click_test.dart`。
- `qfli_studio_core/lib/pages/home_page.dart:172`。
- `qfli_studio_core/lib/pages/profile_page.dart:63`。
- `qfli_studio_core/lib/pages/settings_page.dart:75`。
- `qfli_studio_core/lib/config/agreement_config.dart`。
- `qfli_studio_core/lib/store/auth_store.dart:165`。
- `ohos/entry/src/main/ets/interop/AgreementBridge.ets:66`。

## 第 9 条：Bing、AI 标识与官方转发

**条目原文**

```text
客户端和服务端都没有 bing.com 的调用；AI 回复和 AI 生成的文件都有标识；鸿蒙版不能自定义 AI 接口。
```

**验证方法**

扫描客户端、原生适配与两项服务的源码。
检索 bing 与 web_search，忽略大小写。
逐处检查命中上下文与调用方。
测试文件和工具脚本也纳入扫描。
依赖目录与构建产物不纳入扫描。
本轮未向 Bing 提交请求。

| 范围 | 文件数 | 文本命中数 |
|---|---:|---:|
| 内核 lib、test、tool | 339 | 65 |
| 主应用与原生适配、scripts | 86 | 2 |
| QFLI 服务端 | 60 | 6 |
| 审核服务 | 33 | 0 |

**实际结果：Bing**

没有发现 Bing 地址的生产请求调用。
命中项包含下线注释、测试断言与旧工具名称。
英文 plumbing 等子串也会命中 bing。
这些文本没有构成 Bing 调用。
客户端联网工具只暴露 web_fetch。
中转失败后没有设备直连分支。
旧 ApiClient.aiWebSearch 方法仍然存在。
它请求 QFLI 的旧路径，不请求 Bing。
该服务端路径已下线，HTTP 验收返回 404。

```text
lib/vibe_coding/vibe_web_tools.dart:28
const Set<String> kVibeWebToolNames = {'web_fetch'};

lib/services/api_client.dart:1362
'/api/ai/web_search'
```

该部分结论为通过。
完整范围与全部命中保存在扫描 JSON。
服务端 HTTP 证据见 `server.md` 第 9 条。

**实际结果：回复与文件标识**

真实 AI 面板显示“内容由AI生成”。
下述 HTTP 探针也断言了该文字。
Vibe 回复依据 aiGenerated 显示徽标。
服务端响应标识与客户端映射均存在。

文件写入路径调用 addAiGeneratedHeader。
支持注释的格式会插入标识。
已有测试覆盖 Python、Dart、SQL、HTML 等格式。
测试也覆盖 shebang、编码声明、XML 和 CRLF。
但 JSON、CSV、TXT 与未知格式保持原文。
这些文件没有文件内标识。
界面会提示未插入的原因。

```text
languages without comment syntax JSON is written unchanged and says why
languages without comment syntax csv, txt and unknown extensions are also left alone
00:01 +33: All tests passed!
```

这不能证明“AI 生成的文件都有标识”。
该部分结论为失败。
需实现者补充不破坏格式的标识方案。

**实际结果：自定义 AI 地址**

主应用 allowCustomAiEndpoint 为 false。
设置页和编辑器都隐藏自定义入口。
但生产 AiPanel._send 仍读取旧设置。
它调用 AiService.chat，直接请求该地址。
EditorPage 的 AI 菜单仍可打开此面板。
该菜单只受 offlineOnly 限制。

独立探针使用真实生产面板。
平台为 ohos，产品档位为主应用档位。
探针把旧地址设为本轮回环 HTTP 服务。
测试没有注入生产发送函数。
回环服务实际收到以下请求。

```text
ACCEPTANCE DEFECT_REPRODUCED allowCustomAiEndpoint=false platform=ohos label=official-forwarding received=[{"method":"POST","path":"/v1/chat/completions","model":"acceptance-local-only"}] replyLabel=内容由AI生成
00:00 +1: All tests passed!
```

这条测试通过表示缺口复现。
面板虽显示官方转发，传输仍使用旧地址。
空设置时也不会自动改走官方转发。
Vibe 控制器的官方 API 路径不能覆盖此面板。
该部分结论为失败。

复现命令如下。

```powershell
cd D:/MyNewProjects/qflistudio
flutter test --no-pub .trellis/tasks/11-02-acceptance/client/ai_transport_probe_test.dart --reporter expanded --timeout 1m
# 外层超时 120 秒。只使用回环服务，不接触外部 AI。
```

**结论：失败。**
Bing 调用扫描与回复标识通过。
自定义地址和部分文件标识不满足要求。
本轮没有修业务代码。

**证据路径**

- `E/global-bing-scan.json`。
- `E/ai-transport-probe-complete.log`。
- `E/core-compliance-widgets.log`。
- `.trellis/tasks/11-02-acceptance/client/ai_transport_probe_test.dart`。
- `qfli_studio_core/lib/editor/ai_panel.dart:246`。
- `qfli_studio_core/lib/editor/editor_page.dart:3104`。
- `qfli_studio_core/lib/services/ai_service.dart:595`。
- `qfli_studio_core/lib/services/ai_file_header.dart`。
- `qfli_studio_core/test/ai_file_header_test.dart:97`。
- `qfli_studio_core/lib/vibe_coding/vibe_coding_controller.dart:298`。
- `qfli_studio_core/lib/vibe_coding/vibe_coding_widgets.dart:251`。

## 第 10 条：挖孔区与状态栏

**条目原文**

```text
Mate 60 和 Mate X5 上顶部不再与挖孔区、状态栏重叠。
```

**验证方法与实际结果**

本轮只检查代码与模拟 widget 结果。
原生层读取 TYPE_SYSTEM 和 TYPE_CUTOUT。
它取两项高度的最大值并换算逻辑像素。
窗口变化后会重读避让区。
Flutter 登录页合并宿主高度与 MediaQuery。
已有测试模拟顶部避让区。
这些证据不能替代三态真机验收。

```text
ohos/entry/src/main/ets/entryability/EntryAbility.ets:69
getWindowAvoidArea(TYPE_CUTOUT)
getWindowAvoidArea(TYPE_SYSTEM)

qfli_studio_core/lib/services/ohos_safe_area.dart:85
return math.max(padding, _topAvoid.value);
```

设备 192.168.68.207 处于锁屏状态。
用户明确禁止操作设备。
本轮没有连接、查询、安装、启动或截屏。

**结论：需真机，未验证。**

用户通知设备已解锁后，按以下步骤复测。
设备操作须由后续真机任务执行。

1. 记录设备型号、系统版本与屏幕密度。
2. 记录最终 HAP 的版本与 SHA-256。
3. 覆盖 Mate 60 竖屏状态。
4. 覆盖 Mate X5 折叠状态。
5. 覆盖 Mate X5 展开状态。
6. 在每态冷启动并打开华为登录页。
7. 在每态打开绑定页、设置页和编辑器。
8. 记录两类 avoidArea 矩形。
9. 记录 Flutter 顶部 inset 与控件边界。
10. 检查控件与两类避让区无交叠。
11. 保存带型号、状态、版本的截图。
12. 在页面停留时折叠再展开。
13. 检查布局更新，无需重启才避让。
14. 复测协议阅读和撤回授权提示。

重点复看原驳回坐标。
Mate 60 为 [208,53,942,129]。
Mate X5 为 [200,51,818,124]。
坐标只用于定位历史问题。
最终判定以当前设备矩形为准。

**证据路径**

- `ohos/entry/src/main/ets/entryability/EntryAbility.ets:69`。
- `ohos/entry/src/main/ets/components/HuaweiQuickLoginPlatformView.ets:75`。
- `ohos/entry/src/main/ets/pages/Index.ets:31`。
- `qfli_studio_core/lib/services/ohos_safe_area.dart`。
- `qfli_studio_core/test/auth_login_entry_test.dart`。
- `.trellis/tasks/11-02-w3-release/implement.md` 的 Device smoke。

## 第 12 条：全量检查、提交与部署

**条目原文**

```text
所有仓库测试通过；提交信息符合规范且没有署名；服务已部署到线上。
```

**验证方法**

四个项目均执行全量测试与 analyze 或 lint。
另查默认测试入口外的仓库脚本测试。
所有命令均有外层超时。
Node 单项测试另设 60000 毫秒超时。
Flutter 单项测试另设 1 或 2 分钟超时。
没有命令发生超时。

**实际结果：测试与静态检查**

| 项目与命令 | 外层超时 | 退出码 | 结果 |
|---|---:|---:|---|
| core：`flutter test --no-pub --reporter expanded --timeout 2m` | 600 秒 | 0 | 1363 过，9 跳过 |
| core：`flutter analyze --no-pub` | 240 秒 | 1 | 951 个问题 |
| 主应用：`flutter test --no-pub --reporter expanded --timeout 2m` | 300 秒 | 0 | 8 过 |
| 主应用：`flutter test --no-pub tool/preview_test.dart --reporter expanded --timeout 1m` | 120 秒 | 1 | 编译失败 |
| 主应用：`flutter analyze --no-pub` | 240 秒 | 1 | 2 error、2 info |
| 主应用：`node --test --test-timeout=60000 "scripts/*.test.mjs" "scripts/compliance/*.test.mjs"` | 120 秒 | 0 | 28 过 |
| 服务端：`node --test --test-timeout=60000 "test/*.test.js"` | 120 秒 | 0 | 153 过，1 跳过 |
| 服务端：`npm run lint` | 60 秒 | 1 | 缺少 lint 脚本 |
| 服务端：逐文件 `node --check` | 180 秒合计 | 0 | 60 个文件通过 |
| 审核服务：`npm test` | 120 秒 | 0 | 45 过，含 SDK |
| 审核服务：`node --test --test-timeout=60000 scripts/publish-ci.test.mjs` | 120 秒 | 0 | 7 过 |
| 审核服务：`npm run lint` | 120 秒 | 0 | 31 个 JS 文件通过 |

默认测试目录通过不等于全部测试通过。
主应用的预览测试仍失败。
原始摘录如下。

```text
tool/preview_test.dart:45:13: Error: The argument type 'int' can't be assigned to the parameter type 'String'.
        id: 1,
00:00 +0 -1: Some tests failed.

error - A value of type 'int' can't be assigned to a parameter of type 'String' in a const constructor - tool\preview_test.dart:45:9 - const_constructor_param_type_mismatch
error - The argument type 'int' can't be assigned to the parameter type 'String'. - tool\preview_test.dart:45:13 - argument_type_not_assignable
4 issues found.
```

内核全量 analyze 报 448 error。
另有 31 warning、472 info。
其中 build 检查点占 863 项。
vendor 占 77 项，tool 占 11 项。
本轮没有排除这些目录来改写结论。

```text
error - Target of URI doesn't exist: 'package:re_editor_exmaple/find.dart' - build\checkpoints\0667c4ec8462\vendor\re_editor\example\lib\editor_autocomplete.dart:6:8 - uri_does_not_exist
951 issues found. (ran in 16.9s)

npm error Missing script: "lint"

Syntax checked 31 JavaScript files
```

服务端语法检查不能替代缺失的 lint 门禁。
内核的 9 项跳过也未计入通过数。
其中包含真实 AI 与回环服务条件项。
另有两项 Windows 文件语义条件项。
还跳过了一项终端取消收尾用例。
该用例说明夹具死锁，仍未验证。
服务端跳过项需要独立 MySQL 测试库。

**实际结果：提交信息**

检查覆盖全部可达 refs。
起点为 2026-11-02 00:00:00 +08:00。
时间筛选采用提交者时间。
检查读取完整提交信息。
它检查 Conventional Commits 格式。
它也检查署名、协作署名与生成工具落款。
没有重写历史。

```powershell
git log --all --since=2026-11-02T00:00:00+08:00 --format="%H%x00%cI%x00%B%x00%x1e"
# 服务端从父仓库根目录追加路径过滤：
git log --all --since=2026-11-02T00:00:00+08:00 --format="%H%x00%cI%x00%B%x00%x1e" -- azurekiln-qfli-server
```

| 范围 | 提交数 | 格式不合规 | 署名命中 |
|---|---:|---:|---:|
| qfli_studio_core | 12 | 0 | 0 |
| qflistudio 全部历史 | 66 | 0 | 0 |
| 服务端路径历史 | 24 | 0 | 0 |
| azurekiln-moderation | 5 | 0 | 0 |

服务端的 24 条包含在父仓库的 66 条中。
上表截至补充检查版本，不含本报告提交。
本报告提交也遵守相同规则。

**实际结果：部署与发版**

server.md 与 moderation.md 均未确认生产部署。
部署准备任务也明确没有连接生产环境。
本轮没有生产访问或发布操作。
线上保留期、代理源端口与网关效果仍缺证据。
第 12 条不能判为部署通过。

发版者已提交最终签名 HAP 记录。
本轮独立计算文件哈希，与记录一致。
本轮也读取了已有签名检查成功日志。
这些证据只证明本地制品。
它们不证明 AGC 上架或真机通过。

```text
Version: 5.0.1 / 5000001
D:/MyNewProjects/qflistudio/ohos/entry/build/default/outputs/default/qflistudio-5.0.1-5000001-release-signed.hap
SHA256: 788fe80a0dcea38d089a4e94212aa94d0b36a912930b5cc809dc2232616c1511
final-verify.log: verify-app success
```

**结论：失败，另需部署后复测。**
提交信息检查通过。
主应用预览测试和静态检查仍失败。
生产部署与跳过分支保持未验证。

**证据路径**

- `E/core-test.log`、`E/core-analyze.log`。
- `E/studio-test.log`、`E/studio-preview-test.log`。
- `E/studio-analyze.log`、`E/studio-script-tests.log`。
- `E/server-test.log`、`E/server-lint-command.log`。
- `E/server-syntax.json`。
- `E/moderation-test.log`、`E/moderation-lint.log`。
- `E/moderation-ci-tests.log`。
- `E/commit-audit.json`、`E/source-review.json`。
- `D:/AppData/Local/Temp/qfli-w3-release/final-verify.log`。
- `.trellis/tasks/11-02-w3-release/implement.md`。
- `.trellis/tasks/11-02-deploy-prep/implement.md`。

## 遗留与分派依据

业务实现者需修复旧 AI 地址的传输分支。
还需补齐无注释格式的 AI 文件标识。
业务实现者需修复预览测试的 ID 类型。
仓库维护者需处置全量 analyze 问题。
服务端维护者需补齐可执行的 lint 门禁。
本轮保留了这些失败，没有改业务代码。

用户需发布用户协议并提供 HTTPS 地址。
用户需解锁设备后通知后续真机任务。
用户需确认隐私声明并完成 AGC 提交。
部署所需用户事项见汇总报告的清单。
