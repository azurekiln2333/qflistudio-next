# Authentication UI

## Password Verification

The account form remains native Flutter username/password inputs. Call QFLI `/api/auth/login/requirements` with those credentials first; the gateway validates them before exposing factor requirements. Present `SecondFactorDialog` before `CaptchaDialog`, then submit the final login with collected codes. Password/username edits reset all verification state. Invalid factor codes reopen factor collection; CAPTCHA failures preserve the factor code because the gateway checks CAPTCHA before consuming the factor.

The requirements probe is not a login and must never return a QFLI session. It depends on the gateway's `check_verification` support; deploy the gateway before switching clients. Do not replace this flow with an unauthenticated account-name lookup or skip gateway validation.

## Huawei Account Binding

The anonymous device phone displayed before Huawei login is masked and separate from the gateway's verified full phone. After Huawei authorization, a verified phone match signs in directly. A `bindingRequired` response opens the existing-account form with the server-issued `bindingId`; show whether a usable phone was available. The user can verify the existing account with its usual password, MFA and CAPTCHA, or choose Skip to create a new account. Do not persist the binding ID or call `signIn` before either decision completes. Expired pending requests require a new Huawei authorization code.

## In-App Agreements

`AgreementPage` validates configured HTTPS URLs and invokes `qflistudio/platform.openAgreement`. Every OHOS app shell must implement that method and register `pages/AgreementReader` in `main_pages.json`. Use an ordinary native ArkWeb page instead of a Flutter texture platform view for the full-page reader. It stays within the application and has back/reload/loading/error handling. Preserve each shell's existing picker/native runtime channels.

Empty app agreement URLs intentionally show an unpublished state. They are configured in `lib/config/agreement_config.dart`; do not invent documents or open an external browser.

## Diagnostics

Server errors include `requestId`, which the API client adds to the user-facing error message. Keep server-stage details in backend logs, and never put credentials or token values in diagnostic messages.
