# 华为登录与 iOS 文件排查

检查日期：2026-11-23。

本文保留首次排查时的发布状态。
后续实现与发布进度见[集成接管记录](../.trellis/tasks/11-23-mobile-files-agents/reports/takeover-integration.md)。
真机步骤见[验收记录](../.trellis/tasks/11-23-mobile-files-agents/reports/device-acceptance.md)。

本次检查 Herdr、发布包、发布代码与官方文档。
本次未复现 iPhone 安装过程。
本次未修改应用代码。

## 用户提供的现象

- 用户通过 LCSign 重签后安装。
- 用户确认 Files 中的实际文件消失。
- 用户怀疑版本号变化才触发问题。
- 用户说明两次使用同一张证书。
- 用户描述的版本为 5.0.5 到 5.1.0。
- 本次查到的最新发布为 5.0.10。
- 发布列表中未找到 5.1.0。
- 华为账号注册地暂不清楚。

## iOS 结论与边界

正常更新应保留持久数据。
版本号变化不是删除 Documents 的规则。[A1][A2]

Files 中的应用目录仍属于应用数据容器。
文件共享开关只控制访问入口。[A1][A2]
删除应用会同时删除它的共享文件。[A4]
把文件改放 Application Support 不能避免这个问题。
该目录也属于应用数据容器。[A1]

当前证据不足以认定 LCSign 删除了数据。
同一张证书也不能证明安装过程保留了旧容器。
仍需检查重签后的应用标识和安装日志。

### 发布包检查

本次直接下载发布 ZIP。
本次读取 ZIP 内 IPA 的 Info.plist 与 BUILD_INFO.txt。
下表只代表官方未签名包。
LCSign 重签后的内容尚未取得。

所有下列包的标识均为 `com.azurekiln.qflistudio`。

| 发布标签 | 包内版本 | 构建号 | Files 两个开关 |
| --- | --- | --- | --- |
| v5.0.5-remote.2 | 5.0.5 | 5000005 | 未声明 |
| v5.0.5-git.2 | 5.0.5 | 5000005 | 未声明 |
| v5.0.5-git.5 | 5.0.5 | 5000005 | 未声明 |
| v5.0.5-git.6 | 5.0.5 | 5000005 | 均为 true |
| v5.0.6 | 5.0.6 | 5000006 | 均为 true |
| v5.0.10 | 5.0.10 | 5000010 | 均为 true |

两个开关是 `UIFileSharingEnabled` 与 `LSSupportsOpeningDocumentsInPlace`。
因此只看界面上的 5.0.5，无法识别具体发布包。
这些包不能证明用户安装包的签名身份相同。[G1]

历史提交 `8a0827b` 曾修改包名。
提交日期为 2026-11-18。
旧值为 `com.azurekiln.qfli.qflistudio`。
新值为 `com.azurekiln.qflistudio`。
本次下载的上述发布包已经使用新值。
这条历史不能解释这些发布包之间反复丢文件。

### 发布代码检查

5.0.10 的 App 提交：
`898af24c01b2e62532b919084409423dafb7a1ad`。

5.0.10 的 Core 提交：
`8440dcc9183e64bcae449730dec62778bcaade3d`。

对应代码位于 `D:/MyNewProjects/_wt/harness/integration/`。
根工作区的本地依赖指向旧集成目录。
该依赖不能代表 5.0.10 发布代码。

- `lib/services/app_paths.dart:120` 使用 Documents/projects。
- `lib/services/ios_sandbox_paths.dart` 解析当前容器路径。
- `lib/store/project_store.dart` 在读取注册表时修正旧路径。
- `lib/splash_screen.dart:56` 负责启动加载。
- `lib/services/app_backup_service.dart:602` 检查待恢复标记。

以上文件均指 Core 仓库。

检查范围内未发现按应用版本删除项目的逻辑。
注册表刷新只重载列表，不删除本地目录。
容器 UUID 修复从 5.0.5-git.6 开始存在。
5.0.6 到 5.0.10 未修改该路径修复逻辑。
该修复不能找回安装阶段已经删除的文件。

启动时可能应用用户此前暂存的完整备份。
该流程要求存在 pending 标记或恢复事务记录。
没有这两类记录时，流程立即返回。
它不以应用版本号为触发条件。
若文件只在首次启动后消失，应继续检查这个分支。

### 能区分责任的复现步骤

1. 先把项目复制到电脑或 iCloud Drive。
2. 在应用目录创建测试文本 A。
3. 在应用目录外创建测试文本 B。
4. 记录两个文件的完整位置。
5. 记录安装前的登录态与偏好配置。
6. 用原证书签名新版本。
7. 检查重签后的应用标识。
8. 安装后先不要启动应用。
9. 在 Files 中检查 A 和 B。
10. 启动应用后再次检查。

| 结果 | 下一步 |
| --- | --- |
| 安装后 A 消失，B 保留 | 检查安装日志、应用标识与容器复用 |
| A 在首次启动后消失 | 检查启动日志、恢复标记与文件删除调用 |
| A 始终存在，项目列表为空 | 检查注册表、路径解析与文件可见性 |

应用未启动时，Files 的索引可能尚未刷新。
因此单次目录列表不能证明物理文件已经删除。
应结合安装日志或文件共享工具继续确认。

重签包需比较 `CFBundleIdentifier`、`application-identifier`。
同时比较 `com.apple.developer.team-identifier` 与 App ID Prefix。
Apple 说明，不匹配的应用标识可能导致更新遭拒。[A3]
更新遭拒不等于系统自动删除旧数据。
LCSign 是否在此后重装，仍需安装日志证明。

### 避免再次丢失

当前可把备份导出到应用目录外。
可选择电脑或 iCloud Drive 中的独立目录。
只保存在 QFLIStudioN 内的备份也会随容器丢失。

长期方案是让用户选择外部项目目录。
应用通过系统目录选择器取得访问授权。
书签保存授权位置，文件协调器管理读写。[A5]
重新安装后可能需要重新选择目录。
外部目录中的文件不依赖 QFLI 数据容器。
如果选择其他应用的私有目录，仍依赖那个应用。

## 华为一键登录

本次从华为官方文档接口取得正文。
错误码文档版本为 V41。
一键登录指南版本为 V256。

官方把一键登录的 `1001500003` 与账号注册地联系起来。
账号注册地为境外或港澳台时，可能触发此错误。
官方要求应用提供其他登录方式。[H1][H2]

`1001502014` 才是应用未获所需权限的错误码。[H1]
因此不能把本次错误直接归为 AGC 权限未审批。
设备在海外不等于账号注册地在海外。
当前优先检查账号注册地和账号服务站点。
若确认使用大陆注册账号，需记录系统版本与完整 SDK 日志。
随后检查网络条件，并向华为确认站点判定。
不能承诺切换网络就能解除限制。

项目存在两条请求：

- `EntryAbility.ets:312` 请求 `quickLoginAnonymousPhone`。
- `HuaweiQuickLoginPlatformView.ets:136` 使用 `QUICK_LOGIN`。

以上文件位于发布 App 的 `ohos/entry/src/main/ets/`。
SDK 错误经 `loginError` 原样传到 Flutter。
Core 的 `login_page.dart:198` 使用 `showPasswordLogin = !isOhos`。
因此鸿蒙端没有可用的备用登录入口。
这个缺口会把平台限制变成无法继续登录的问题。

隐藏入口来自已有产品要求。
本次没有擅自开放入口或绕过手机号要求。
普通账号登录只取得身份标识，不能替代手机号验证。
后续修复应明确备用身份验证流程。
同时应把 SDK 原始错误转成用户可理解的提示。[H2][H3]

另有独立配置待检查。
仓库 `module.json5` 中仍有 Client ID 占位值。
本次未读取线上 AGC 或用户安装 HAP 的配置。
因此不能据此认定本次错误来自这个占位值。

## Claude 与项目进度

Herdr 工作区为 `w37`。
Claude 位于 `w37:p1C`，检查时状态为 idle。
终端最后显示模型服务的 Cloudflare 522 错误。
它不是应用的业务服务器日志。

Claude 会话为 `271875aa-913d-40ef-90e5-d68fcd101c4c`。
当前任务为 `11-23-mobile-files-agents`。
四部分代码已进入 `mobile/integration`。
它们包括文件分享、外部目录、首页 Agents 与设备同步。

GitHub 确认 v5.0.10 已在 2026-11-23 发布。[G1]
新功能分支的 core-check 运行 `45136693596` 已失败。[G2]
该次运行检查 Core 提交 `606810bd`。
失败报告列出编辑器计时器与外部目录菜单问题。
本地已有后续修改，不能用旧 CI 结论替代新提交验证。
本次未查到新功能分支的 App 安装包运行。
因此不能把这一轮外部目录支持当成已发布能力。

## 官方来源与复查入口

以下地址均在本次排查中读取。
华为页面是动态页面，本次通过其公开文档接口读取正文。

- A1：Apple File System Programming Guide。
  `https://developer.apple.com/library/archive/documentation/FileManagement/Conceptual/FileSystemProgrammingGuide/FileSystemOverview/FileSystemOverview.html`
- A2：Apple QA1699，文件共享与私有数据目录。
  `https://developer.apple.com/library/archive/qa/qa1699/_index.html`
- A3：Apple TN2319，更新时应用标识不匹配。
  `https://developer.apple.com/library/archive/technotes/tn2319/_index.html`
- A4：Apple 文件共享文档，删除应用的影响。
  `https://support.apple.com/en-us/120403`
- A5：Apple 外部目录访问文档。
  `https://developer.apple.com/documentation/uikit/providing-access-to-directories`
- H1：华为 Account Kit 错误码。
  `https://developer.huawei.com/consumer/cn/doc/harmonyos-references/errorcode-account-kit`
- H2：华为账号一键登录指南。
  `https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/account-phone-unionid-login`
- H3：华为账号登录指南。
  `https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/account-unionid-login-button`
- G1：项目发布记录。
  `https://api.github.com/repos/azurekiln2333/qflistudio-next/releases?per_page=30`
- G2：新功能分支的 Core CI。
  `https://api.github.com/repos/azurekiln2333/qflistudio-core/actions/runs?branch=ci/mobile-files&per_page=3`

华为正文读取方式：

```text
POST https://svc-drcn.developer.huawei.com/community/servlet/consumer/cn/documentPortal/getDocumentById
{"objectId":"errorcode-account-kit","language":"cn"}
{"objectId":"account-phone-unionid-login","language":"cn"}
```
