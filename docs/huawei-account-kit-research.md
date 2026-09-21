# Flutter 接入华为账号一键登录（Account Kit）调研

调研日期：2026-09-17
调研目标：在 QFLIStudio+ 鸿蒙端实现「华为账号一键登录」，并在登录页优先展示。

---

## 一、结论先行

1. **一键登录不能纯 Dart 实现。** 华为要求「华为账号一键登录」必须使用官方 ArkUI 组件 `LoginWithHuaweiIDButton`，并配套展示《华为账号用户认证协议》。这是合规硬要求，不是可选项。
2. **Flutter 接入它的唯一官方路径是 PlatformView。** ArkTS 侧实现 `PlatformView` + `PlatformViewFactory` + `FlutterPlugin`，Dart 侧用 `OhosView` 把这个原生组件嵌进 Flutter 布局。
3. **本项目环境已经具备条件**（已实测）：flutter_ohos 3.27.5-ohos-1.0.1 的引擎包里**已内置完整 PlatformView 实现**，Dart 侧 `OhosView` 组件也存在。不需要升级引擎、不需要换 Flutter 分支。
4. **华为官方提供了 Flutter 版示例工程**，可直接对照移植：`gitee.com/harmonyos_samples/accountkit-samplecode-clientdemo-flutter`。
5. **当前项目里的「华为账号登录」不是一键登录。** 它走的是 `AuthorizationWithHuaweiIDRequest`（授权码模式，只取 openid），拿不到手机号。一键登录需要**新增**一条 PlatformView 通道，而不是改造现有 MethodChannel。
6. **最大的前置门槛不在代码，在 AGC。** 必须先申请 `quickLoginMobilePhone`（华为账号一键登录）scope 权限并通过审核，否则代码写得再对也会返回 `1001502014 应用未申请 scopes 或 permissions 权限`。

---

## 二、概念区分：三种「华为登录」别搞混

| 名称 | 客户端实现 | 是否必须用官方按钮 | 能拿到手机号 | 需申请 scope |
|---|---|---|---|---|
| 华为账号登录 | `LoginWithHuaweiIDButton`（`LoginType.ID`）或 `authentication.createLoginWithHuaweiIDRequest()` | 用官方按钮时是 | 否 | **不需要** |
| **华为账号一键登录** | `LoginWithHuaweiIDButton`（`LoginType.QUICK_LOGIN`） | **是，强制** | **是**（授权码换完整手机号） | **需要 `quickLoginMobilePhone`** |
| 静默登录 | `authentication` 静默接口 | 否 | 否 | 视 scope 而定 |

一键登录的完整体验是：登录页先显示「138****8888 华为账号一键登录」的脱敏号码，用户勾选协议后点一下即完成登录，无需输入。

其中脱敏号码（匿名手机号）是**另一次独立请求**拿到的，走 `AuthorizationWithHuaweiIDRequest` + `scopes = ['quickLoginAnonymousPhone']`，属于普通 `authentication` 调用，**不需要** PlatformView。

所以完整的一键登录页面 = **脱敏号码（MethodChannel 就够）+ 官方按钮（必须 PlatformView）**。

---

## 三、本项目现状盘点

| 位置 | 现状 | 与一键登录的关系 |
|---|---|---|
| `ohos/entry/src/main/ets/entryability/EntryAbility.ets` | 已有 `qflistudio/huawei_account` MethodChannel，用 `authentication.HuaweiIDProvider` + `AuthorizationWithHuaweiIDRequest`，`scopes = ['openid']` | **这是授权码登录，非一键登录**。保留它作为降级通道即可 |
| `lib/pages/auth/login_page.dart` | `_huaweiLogin()` 调该通道拿 code，再调 `ApiClient.huaweiLogin(code)` | 需改造：一键登录按钮置顶，现有按钮降为兜底 |
| `lib/services/api_client.dart` | 已有 `POST /api/auth/huawei`（入参 code） | 服务端需扩展为可返回手机号 |
| `ohos/entry/src/main/module.json5` | 已有 `metadata.client_id = "REPLACE_WITH_AGC_CLIENT_ID"`（**占位符，未填**）；已有 `ohos.permission.INTERNET` | 需填真实 Client ID；需补 `GET_NETWORK_INFO` |
| `ohos/AppScope/app.json5` | `bundleName = com.azurekiln.qflistudio` | 必须与 AGC 应用包名一致 |
| `ohos/build-profile.json5` | 手动签名（`D:/Keystore/azurekiln.p12` + `qfli_profileDebug.p7b`），`compatibleSdkVersion 5.1.0(18)`，`targetSdkVersion 6.1.1(24)` | 一键登录**只支持手动签名**，本项目已满足；API 18 满足最低要求 |

---

## 四、环境可行性验证（已在本机实测）

以下结论不是推测，是从本机 SDK 里实际读出来的。

**Flutter 版本**
```
Flutter 3.27.5-ohos-1.0.1 · Dart 3.11.5
Engine hash 42d3d75a56efe1a2e9902f52dc8006099c45d937
SDK 路径 D:\ProgramFiles\flutter_ohos
```

**引擎包 `flutter.har` 内已包含 PlatformView 全套实现**
```
package/src/main/ets/plugin/platform/PlatformView.ets
package/src/main/ets/plugin/platform/PlatformViewFactory.ets
package/src/main/ets/plugin/platform/PlatformViewRegistry.ets
package/src/main/ets/plugin/platform/PlatformViewRegistryImpl.ets
package/src/main/ets/plugin/platform/PlatformViewWrapper.ets
package/src/main/ets/plugin/platform/PlatformViewsController.ets
package/src/main/ets/embedding/engine/systemchannels/PlatformViewsChannel.ets
```
且 `index.ets` 已对外导出 `PlatformView` / `PlatformViewFactory` / `PlatformViewRegistry`。

**Dart 侧 `OhosView` 已存在**（`packages/flutter/lib/src/widgets/platform_view.dart:203`），构造参数：
`viewType`（必填）、`onPlatformViewCreated`、`creationParams`、`creationParamsCodec`、`hitTestBehavior`、`gestureRecognizers`、`clipBehavior`。

**关键接口签名**（写代码时按这个来，网上老文章可能不一致）：

```typescript
// PlatformView.ets
export declare class Params {
  direction: Direction
  platformView: PlatformView
}
export default abstract class PlatformView {
  abstract getView(): WrappedBuilder<[Params]>;   // ← 注意是 WrappedBuilder<[Params]>
  abstract dispose(): void;
  onFlutterViewAttached(dvModel: DVModel): void {}
  onFlutterViewDetached(): void {}
}

// PlatformViewFactory.ets
public abstract create(context: common.Context, viewId: number, args: Any): PlatformView;

// FlutterPluginBinding
public getPlatformViewRegistry(): PlatformViewRegistry;
// PlatformViewRegistry
registerViewFactory(viewTypeId: string, factory: PlatformViewFactory): boolean;
```

**渲染方式**：`PlatformViewWrapper` 的实现是把原生视图投影到纹理层（`The view is ... projected onto a rendering target`），由 Flutter 统一合成，并保留了原生手势/键盘/无障碍链路。实际表现是原生按钮会以纹理形式嵌入 Flutter 布局，点击事件由原生侧处理，符合一键登录的交互要求。

**结论：技术上可行，无需更换 Flutter 分支或升级引擎。**

---

## 五、接入步骤

### 5.1 AGC 配置（先做，且可能卡审核）

1. 在 AppGallery Connect 创建/绑定应用，**包名必须是 `com.azurekiln.qflistudio`**。
2. 用 `D:/Keystore/qflistudio.cer` 生成并上传**签名证书指纹（SHA256）**。指纹不匹配会报 `1001502013`。
3. 记录应用的 **Client ID**。若 Client ID 与 App ID 不同，必须写入 `module.json5` 的 `client_id` metadata——项目里现在还是 `REPLACE_WITH_AGC_CLIENT_ID` 占位符，**这一项不填必定失败**。
4. **申请 `quickLoginMobilePhone`（华为账号一键登录）scope 权限**。这是人工审核项，也是整个方案的时间瓶颈，建议优先提交。

### 5.2 `ohos/entry/src/main/module.json5`

在 `requestPermissions` 补一条（跳转认证协议页前需要判断网络）：

```json5
{ "name": "ohos.permission.GET_NETWORK_INFO" }
```

### 5.3 ArkTS 侧：新增 PlatformView 插件

新建 `ohos/entry/src/main/ets/components/LoginView.ets`，结构与官方示例一致：

1. `@Component struct ButtonComponent` — 内部 `build()` 使用 `LoginWithHuaweiIDButton`，控制器用 `loginComponentManager.LoginWithHuaweiIDButtonController`，关键参数：
   - `loginType: loginComponentManager.LoginType.QUICK_LOGIN`（**一键登录靠这个，不是 ID**）
   - `style: loginComponentManager.Style.BUTTON_CUSTOM` 或 `BUTTON_RED`
   - `supportDarkMode: true`
   - `verifyPhoneNumber: true`（账号 90 天内未短信验证时拉起验证页）
   - 初始 `.setAgreementStatus(AgreementStatus.NOT_ACCEPTED)`
2. `@Builder function ButtonBuilder(params: Params)` — 包装组件
3. `class CustomView extends PlatformView implements MethodCallHandler` — 注册 MethodChannel，名字必须是 **`viewType + viewId`** 拼接
4. `class CustomFactory extends PlatformViewFactory` — `create()` 返回 `CustomView`
5. `class LoginPlugin implements FlutterPlugin` — 在 `onAttachedToEngine` 里 `binding.getPlatformViewRegistry()?.registerViewFactory('...', new CustomFactory(...))`

回调 `onClickLoginWithHuaweiIDButton` 里拿 `response.authorizationCode`，通过 MethodChannel 回传 Dart。

`EntryAbility.ets` 的 `configureFlutterEngine` 中追加：
```typescript
this.addPlugin(new LoginPlugin());
```

### 5.4 脱敏手机号（不需要 PlatformView）

在 ArkTS 侧加一个普通 MethodChannel 方法，或直接在现有 `qflistudio/huawei_account` 通道上加 `getAnonymousPhone`：

```typescript
const authRequest = new authentication.HuaweiIDProvider().createAuthorizationWithHuaweiIDRequest();
authRequest.scopes = ['quickLoginAnonymousPhone'];
authRequest.forceAuthorization = false;   // 一键登录场景必须 false
const phone = response?.data?.extraInfo?.quickLoginAnonymousPhone as string ?? '';
```

拿到后存 `AppStorage`，供 `ButtonComponent` 初始化时读取并显示。

### 5.5 Dart 侧

新建 `lib/pages/auth/huawei_login_view.dart`：

```dart
OhosView(
  viewType: 'com.azurekiln.qflistudio/loginView',   // 必须与 ArkTS registerViewFactory 完全一致
  onPlatformViewCreated: (int id) {
    _channel = MethodChannel('com.azurekiln.qflistudio/loginView$id');  // 注意 $id 后缀
    widget.onViewCreated(LoginViewController(_channel));
  },
  creationParams: const <String, dynamic>{},
  creationParamsCodec: const StandardMessageCodec(),
)
```

Controller 内部用 `setMethodCallHandler` 把原生消息转成 Stream，Dart 侧监听 `loginSuccess` / `quickLoginAnonymousPhone` / `openPrivacy` 等事件。

**登录页改造（`lib/pages/auth/login_page.dart`）**：把 `HuaweiLoginView` 放在表单**上方**，作为首选入口；把现有的「AZK 账号登录（OAuth2）」「华为账号登录」降级为「其他登录方式」；`MissingPluginException` 时说明当前平台不支持并回落到原按钮。

### 5.6 服务端

`POST /api/auth/huawei` 需要扩展：用 `authorizationCode` 调华为 token 接口换取 `access_token`，再取 **完整手机号 + UnionID + OpenID**，建立/匹配本地账号并签发本站 token。现有接口只处理 openid，需要确认服务端是否已具备手机号换取能力。

---

## 六、错误码与兜底策略

| 错误码 | 含义 | 建议处理 |
|---|---|---|
| `1001502014` | 应用未申请 scopes 或 permissions | AGC 权限未过审，**先查这个** |
| `1001502001` | 用户未登录华为账号 | 提示「请先登录华为账号」并回落其他方式；可订阅账号登录/登出事件提前识别 |
| `1001500003` | 不支持该 scopes/permissions | 账号为境外或儿童账号，回落其他登录方式 |
| `1005300001` | 用户未同意协议 | 拉起协议弹窗，`continueLogin()` 可一步完成同意并登录 |
| `1001502012` | 用户取消授权 | 静默处理，不报错 |
| `1001502005` | 网络异常 | 提示检查网络 |
| `1001502009` | 内部错误 | 提示稍后重试 / 换方式 |
| `12300001` | 系统服务异常 | 提示稍后重试 |
| `1001500002` | 重复请求 | 忽略 |
| `1001502013` | 证书指纹校验失败 | 核对 AGC 指纹与签名证书 |

**所有异常都必须有兜底**：一键登录失败时展示其他登录方式，不能出现死路。

---

## 七、约束、坑与风险

**平台约束（华为侧硬性限制）**
- 仅支持 **phone 设备、竖屏**；官方示例明确不支持横屏、大字体、隐私空间、深色模式（深色模式按钮本身支持 `supportDarkMode`，但整体页面适配需自行处理）。
- 仅支持**已绑定手机号的中国境内账号**（不含中国香港、中国澳门、中国台湾）。
- 必须**真机调试**，模拟器无效。
- 仅支持**手动签名**，不支持自动签名。本项目已是手动签名，符合。

**工程侧注意**
- `viewType` 字符串在 Dart 与 ArkTS 两侧必须**逐字符一致**；MethodChannel 名字必须是 `viewType + viewId`，漏掉 `$id` 是最常见的「通道收不到消息」原因。
- `getView()` 返回 `WrappedBuilder<[Params]>`，且组件需接收 `@Prop params: Params`。网上部分旧文章签名不同，以本机引擎为准。
- **开启代码混淆时必须加白名单**，否则脱敏号码字段被混淆后恒为空：
  ```
  -keep-property-name
  quickLoginAnonymousPhone
  ```
- 脱敏号码为空的三种原因：账号未绑手机号 / 权限未生效 / 混淆未加白名单。
- 用户在登录页切换到另一个华为账号时，需**重新获取脱敏号码并刷新页面**，否则展示的是旧号码。
- 用户点击时若系统已登出华为账号，直接报 `1001502001`，需自行处理。

**关于网上流传的第三方插件**
检索到有博客推荐 `flutter_huawei_login` 插件（声称在 atomgit / gitee 的 openharmony-sig 下）。我实际核对了 `atomgit.com/openharmony-sig/flutter_huawei_login` 与 `gitee.com/openharmony-sig/flutter_huawei_login`，**均为 404，无法确认存在**。建议**不要依赖该来源**，直接照华为官方 Flutter 示例自行实现，代码量约 200 行，可控性更好。

---

## 八、参考资料

1. 华为官方 Flutter 示例（**最值得对照**）
   `https://gitee.com/harmonyos_samples/accountkit-samplecode-clientdemo-flutter`
   关键文件：`ohos/.../components/LoginView.ets`、`ohos/.../entryability/EntryAbility.ets`、`lib/login_ohos_view.dart`、`ohos/.../common/Utils.ets`
2. 官方 Codelab：Account Kit（华为账号一键登录）
   `https://developer.huawei.com/consumer/cn/codelabsPortal/carddetails/tutorials_NEXT-AccountKit-QuickLogin`
3. 官方文档：Account Kit 一键登录概述
   `https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/account-quick-login`
4. 官方文档：账号权限申请（`quickLoginMobilePhone`）
   `https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/account-config-permissions`
5. 官方文档：错误码
   `https://developer.huawei.com/consumer/cn/doc/harmonyos-references/errorcode-account-kit`
6. 官方文档：华为账号用户认证协议（需在登录页提供入口）
   `https://privacy.consumer.huawei.com/legal/id/authentication-terms.htm?code=CN&language=zh-CN`

---

## 九、待确认事项

1. **AGC 上是否已创建 `com.azurekiln.qflistudio` 应用，Client ID 是多少？** 这是所有后续工作的前置。
2. **签名证书指纹是否已在 AGC 配置？** 若之前只做过 OAuth2 网页登录，指纹可能没配。
3. **`quickLoginMobilePhone` 权限是否已申请？** 未过审则无法真机验证。
4. **服务端 `/api/auth/huawei` 是否支持用 authCode 换手机号？** 现有实现只取 openid，可能需要服务端同步改造。
5. **产品决策**：一键登录失败时，是否自动回落到现有的「华为账号登录（openid）」或用户名密码？建议回落，避免登录死路。
