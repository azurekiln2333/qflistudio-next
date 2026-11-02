# W3b 设计（客户端设置、协议、注销、社区举报、AI 标识、请求头）

仓库：`D:/MyNewProjects/qfli_studio_core`（共享内核）；必要时 `qflistudio/ohos`（ArkTS 宿主）。

## 边界

只改以下路径：

- `lib/config/agreement_config.dart`、`lib/config/client_platform.dart`（新增）
- `lib/services/api_client.dart`、`lib/services/account_erasure_service.dart`（新增）
- `lib/services/ai_service.dart`（仅加 AI 文件头常量与函数）
- `lib/store/auth_store.dart`（只加清空本地数据的方法）
- `lib/pages/settings_page.dart`、`lib/pages/auth/agreement_page.dart`
- `lib/pages/community/post_detail_page.dart`、`post_list_page.dart`、`publish_page.dart`
- `lib/community/community_widgets.dart`、`lib/community/moderation_feedback.dart`（新增）
- `lib/vibe_coding/vibe_web_tools.dart`、`vibe_coding_controller.dart`、`vibe_coding_panel.dart`、`vibe_models.dart`、`vibe_coding_widgets.dart`
- `lib/editor/ai_panel.dart`
- 对应 `test/` 新增或修改的测试文件
- `qflistudio/ohos/entry/src/main/ets/entryability/EntryAbility.ets`（只有 `openAgreement` 一项，且只增不改他人逻辑）

不碰：W3a 的 `login_page.dart`、`account_login_page.dart`、`ohos_safe_area.dart` 调用方；`lib/interop`、`editor_page.dart` 的运行逻辑、`ets/interop`。

## C 节契约落点

| 契约 | 实现位置 |
| --- | --- |
| `X-Client-Platform: <platform>-app/<版本>` | `ClientPlatform.header`；`ApiClient._headers` 与三条直连请求（AI 直连、流式终端）统一注入 |
| `403 realname.required` | `ModerationFeedback.describe(ApiException)` → 提示文案 + `requiresBinding` 引导 |
| `403 account.banned / account.muted` | 同上，给出“已被封停 / 已被禁言”文案 |
| `429 rate.limited` + `retryAfter` | 同上，带秒数 |
| `422 moderation.blocked` + `categories` | 同上，只列类别，不回显命中词 |
| `503 moderation.unavailable` | 同上，文案固定“审核服务暂不可用” |
| `POST /api/reports` | `ApiClient.report()`，`{targetType,targetId,reason}` → `{id,status}` |
| `POST /api/users/me/deactivate` | `ApiClient.deactivateAccount()`，`{confirm:"DEACTIVATE"}` → `{status:"deactivated"}` |
| `aiGenerated: true` | `AiChatResult.aiGenerated`；面板与 Vibe 会话据此显示“内容由AI生成” |
| `status: published/pending/rejected` | `Post.status`/`Comment.status`；`pending` 显示“审核中” |

## 关键取舍

1. **平台头取值**：`String.fromEnvironment('QFLI_CLIENT_PLATFORM')` 优先（各语言 App 可注入），否则按 `defaultTargetPlatform` 映射，版本号来自 `StudioProfile.clientVersion`（新增可选字段，默认 `1.0.0`）。头值只放 ASCII，避免非 latin-1 头导致 `http` 抛错。
2. **错误文案只在一处**：`ModerationFeedback` 是纯函数，界面只负责展示与跳转，不重复判断错误码。分类不回显命中词原文（服务端也不下发）。
3. **举报入口**：帖子详情页顶部菜单与每条评论的菜单；理由用固定选项 + 可补充，提交走 `POST /api/reports`，未登录先提示登录（不自动跳转，避免与 W3a 的登录页耦合）。
4. **注销**：设置页“账户与隐私”分组 → 二次确认（勾选 + 输入确认词）→ 调接口 → 成功清本地登录态与本地缓存目录 → 退出到设置页并提示。失败保留登录态并显示服务端文案。网络不可用时不允许“假注销”。
5. **撤回隐私同意**：鸿蒙优先调用 `qflistudio/platform.requestPrivacyWithdraw`（本轮只在 ArkTS 宿主侧留出可选实现，缺失插件时走本地分支：清本地数据 + 退出登录 + 提示到系统设置撤回）。Dart 侧两种分支都必须可用，且不依赖宿主是否存在。
6. **web_search 下线**：删除直连 Bing 回退与工具定义，`kVibeWebToolNames` 只剩 `web_fetch`，控制器不再暴露 `web_search`。**`web_fetch` 直连回退一并删除**：§1 要求“不得新增未披露的第三方”，设备直连任意网站等于把用户请求发给未披露的第三方，与服务端 SSRF 校验也不一致；保留中转路径。
7. **AI 文件头**：`AiService.aiGeneratedFileHeader(path)` 按扩展名给出注释前缀（`#`、`//`、`--`、`<!-- -->`、`/* */`、`;`、`%`），无注释语法的类型（`.json`、`.csv`、`.txt` 等）不加头并在保存提示里说明；shebang 之后插入，保证脚本仍可直接执行。
8. **自定义 AI 接口**：`StudioProfile.allowCustomAiEndpoint`（默认 false = 只走官方转发）。设置页与 `AiPanel` 的入口按该开关显示；鸿蒙正式版为 false。`ApiClient` 仍支持 direct 路由，供桌面调试与非鸿蒙产品，但正式版 UI 不暴露入口。
9. **协议页**：`AgreementPage` 在没有 `openAgreement` 宿主实现时不再只报错，改为应用内 ArkWeb 无法使用时给出可复制的地址与“暂未发布”状态，避免用户看到死路；鸿蒙宿主补上 `openAgreement` → `pages/AgreementReader`。

## 回滚

改动集中在单一仓库的独立文件，回滚只需 `git revert` 单个提交；无数据库、无迁移、无部署步骤。
