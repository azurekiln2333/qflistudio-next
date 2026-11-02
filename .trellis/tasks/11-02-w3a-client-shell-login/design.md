# Design — W3a 状态栏与挖孔区避让、登录入口

## 边界（文件级）

| 仓库 | 我的文件 | 不改 |
| --- | --- | --- |
| qfli_studio_core | `lib/pages/auth/login_page.dart`、`lib/pages/auth/account_login_page.dart`、`lib/pages/auth/huawei_quick_login_view.dart`、`lib/services/ohos_safe_area.dart`（新增）、`lib/splash_screen.dart`、`test/auth_login_entry_test.dart`（新增） | `lib/config/agreement_config.dart`、`lib/services/api_client.dart`、社区、AI 面板（W3b） |
| qflistudio | `ohos/entry/src/main/ets/entryability/EntryAbility.ets`、`ohos/entry/src/main/ets/components/HuaweiQuickLoginPlatformView.ets`、`ohos/entry/src/main/ets/pages/Index.ets` | 其余 |

## 挖孔区重叠

观测：鸿蒙驳回的坐标区间纵坐标约 51–129，正好跨状态栏与挖孔区。
Flutter 侧所有页面都用 `Scaffold` + `SafeArea` 或 `AppBar`，布局本身已避让。
最可能的泄漏点是平台组件：华为一键登录按钮由 ArkTS 平台视图渲染，
其 `HuaweiQuickLoginBuilder` 只有 `width('100%').height('100%')`，自身不避让。

做法（两道保险，都不引入新依赖）：

1. ArkTS 侧：读取 `windowStage.getMainWindowSync().getWindowAvoidArea(TYPE_SYSTEM)` 与
   `getWindowAvoidArea(TYPE_CUTOUT)`，把上边界像素与状态栏高度、顶部避让高度
   （px，按 `window.getWindowProperties().density` 反算）通过 `qflistudio/safe_area`
   通道传给 Flutter；并订阅 `avoidAreaChange` 事件（折叠屏展开/折叠会改变避让区）。
   取不到值时返回空 = 不额外加内边距。
2. Dart 侧：`OhosSafeArea` 只能缓存原生上报的数值。`LoginPage` 与
   `AccountLoginPage` 的滚动区用 `max(视口 padding.top, 原生顶部避让)`。

`Index.ets` 的 `FlutterPage` 保持 `width/height('100%')`：Flutter 需要铺满整窗才能
真实拿到 `MediaQuery.padding`。若要收窄视口，只改 `StartupSplash` 的顶部内边距。

## 登录入口

- `login_page.dart` 在 `TargetPlatform.ohos` 时不渲染"其他方式登录"分隔条与按钮。
- `account_login_page.dart`：绑定页（`bindingId != null`）且 `phoneAvailable == false` 时，
  不显示"跳过，创建新账号"，也不允许提交绑定；显示"请使用已绑定手机号的华为账号"。
  同时把默认的 `phoneAvailable = true` 改为按使用方传值，避免非鸿蒙调用方误开跳过。

## 测试

- 新增 `test/auth_login_entry_test.dart`：用 widget test 断言鸿蒙平台 `LoginPage` 没有
  "其他方式登录"，绑定页 `phoneAvailable == false` 时没有跳过按钮且有提示。
- 平台通道用 `TestDefaultBinaryMessengerBinding` 打桩，避免依赖真机。
- ArkTS 侧用 `hvigorw` 编译（若本机工具链可用）与 `hdc` 文字取证（hilog/uitest dumpLayout）。
