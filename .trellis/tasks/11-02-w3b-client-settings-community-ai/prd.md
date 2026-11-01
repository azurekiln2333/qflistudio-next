# W3b 设置页、协议、注销、社区举报与提示、AI 标识、请求头
仓库：D:/MyNewProjects/qfli_studio_core（需要时 qflistudio/ohos）。需求：§3-W3 对应条目。

## 范围
- 设置页（我的→设置，从主界面进入 ≤4 次点击）：用户协议、隐私政策入口；撤回隐私政策同意（优先调鸿蒙隐私托管撤回接口；没有则清本地数据、退出登录，并提示到系统设置撤回）；注销账号（二次确认后调 POST /api/users/me/deactivate，成功后清本地登录态）。
- lib/config/agreement_config.dart：隐私政策地址填任务书给定 URL；用户协议托管地址留空并写入遗留（待用户提供）。
- 社区：帖子与评论“举报”按钮（POST /api/reports）；pending 显示“审核中”；realname.required、rate.limited、moderation.blocked、moderation.unavailable、account.banned/muted 给出明确提示，未实名时引导华为账号绑定手机号。
- AI：回复下方显示“内容由AI生成”（依据 aiGenerated）；AI 写入的文件开头按对应语言注释语法加一行“本文件由 AI 生成”（处理 shebang、JSON 等无注释语法的情况并写明规则）；删除 lib/vibe_coding/vibe_web_tools.dart 中直连 Bing 的回退并下线 web_search 工具（web_fetch 与服务端一致保留，其直连回退是否保留按 §1 判断并写明理由）；鸿蒙正式版隐藏 lib/editor/ai_panel.dart 的自定义 AI 接口，只走官方转发。
- 请求头：所有请求带 X-Client-Platform: harmonyos-app/<版本号>（其他平台用 contracts.md 的前缀）；新增接口调用。接口与错误码严格按 contracts.md C 节。

## 边界
W3a 负责状态栏/挖孔区、login_page.dart、account_login_page.dart；这些不要动。跨应用联动代码（lib/interop、editor_page.dart 运行逻辑、ets/interop）本轮不改。

## 验收
§4 第 2（客户端）、7（客户端）、8、9（客户端）条。
