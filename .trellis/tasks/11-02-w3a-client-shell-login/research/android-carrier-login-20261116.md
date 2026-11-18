# Android carrier login options

## Request and local verification

The user requested that Huawei OHOS hide the alternate login entry, and asked
for Android carrier one-tap login options before implementation.

The active core resolves to `D:/MyNewProjects/_wt/integration/qfli_studio_core`.
Its `LoginPage` already sets `showPasswordLogin = !isOhos` and gates both the
divider and alternate-login button. The OHOS Flutter SDK maps the native
`ohos` operating system to `TargetPlatform.ohos`. The native
`HuaweiQuickLoginPlatformView` renders only the Huawei login button.
The existing `auth_login_entry_test.dart` suite passes all eight cases.
No authentication implementation changes were required for this verification.

## Proposed Android implementation

Use an Android-only carrier authentication SDK. Obtain the login token after
user authorization. Send that token to the application's backend. Have the
backend verify it with the provider and obtain the verified phone number.
Connect that identity to the existing identity gateway and account/session
flow. Do not authenticate a client-supplied phone number without verification.

The current backend's Huawei flow delegates authentication to the identity
gateway and issues local sessions through `identity.createSession`. An Android
provider requires a corresponding gateway authentication path. Merely adding
the SDK button to the Flutter page is insufficient.

Keep Android account login available when carrier authentication is unavailable.
SMS login is an additional fallback option if its backend is implemented.
Keep Huawei OHOS using its existing Huawei account flow.

## Provider comparison

### Aurora / JVerification: preferred Flutter candidate

- Official Flutter plugin and Android integration documentation exist.
- Public Android documentation lists China Mobile, China Unicom and China
  Telecom. It does not establish China Broadnet support.
- The official product page advertises a limited-time 50% discount: up to
  10,000 authentications at CNY 0.0295 each. The displayed quotation must be
  confirmed before purchase; it is not a permanent price guarantee.

Sources:

- https://docs.jiguang.cn/jverification/client/Flutter/jverification_flutter
- https://docs.jiguang.cn/jverification/client/Android/android_guide
- https://docs.jiguang.cn/jverification/server/rest_api/loginTokenVerify
- https://www.jiguang.cn/identify

### Alibaba Cloud PNVS: native integration alternative

- Integrate the official Android SDK through a Flutter platform channel.
- The official FAQ explicitly excludes China Broadnet, including 192 numbers.
- Standalone one-tap login costs CNY 0.050 per successful number retrieval for
  monthly usage up to 100,000. A 10,000-use pack costs CNY 440, and a 50,000-use
  pack costs CNY 2,000. Packs are valid for 12 months.
- Do not substitute fusion-authentication pricing for standalone one-tap login.

Sources:

- https://help.aliyun.com/zh/pnvs/product-overview/billing-overview/
- https://help.aliyun.com/zh/pnvs/support/common-problems-of-number-authentication

### Tencent Cloud: unsuitable for a new integration

The quickstart currently restricts new purchases to existing allowlisted users
and does not accept new integrations.

Source:

- https://cloud.tencent.com/document/product/1415/56198

## China Broadnet decision

Do not promise four-carrier coverage based on a generic carrier logo or
authentication-service footer. The reviewed public documentation does not
establish a suitable four-carrier integration for this application. If Broadnet
is required, obtain explicit provider confirmation and validate with a Broadnet
SIM, including successful server-side token exchange, before committing to it.

## Scope

Research only for Android. No provider account, purchase, SDK dependency,
gateway endpoint or Android login behavior was changed.
