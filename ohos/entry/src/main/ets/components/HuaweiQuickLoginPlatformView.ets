import {
  MethodCall,
  MethodChannel,
  MethodResult,
  StandardMessageCodec,
} from '@ohos/flutter_ohos';
import { BinaryMessenger } from '@ohos/flutter_ohos/src/main/ets/plugin/common/BinaryMessenger';
import PlatformView, { Params } from '@ohos/flutter_ohos/src/main/ets/plugin/platform/PlatformView';
import PlatformViewFactory from '@ohos/flutter_ohos/src/main/ets/plugin/platform/PlatformViewFactory';
import common from '@ohos.app.ability.common';
import { loginComponentManager, LoginWithHuaweiIDButton } from '@kit.AccountKit';

export const HUAWEI_QUICK_LOGIN_VIEW_TYPE = 'qflistudio/huawei_quick_login';

@Observed
class HuaweiButtonTheme {
  background: number = 0xFF0061A4;
  foreground: number = 0xFFFFFFFF;
  disabledBackground: number = 0xFFE0E2E7;
  disabledForeground: number = 0xFF74777C;

  update(colors: Map<string, number>): void {
    const background = colors.get('background');
    const foreground = colors.get('foreground');
    const disabledBackground = colors.get('disabledBackground');
    const disabledForeground = colors.get('disabledForeground');
    if (typeof background === 'number') this.background = background;
    if (typeof foreground === 'number') this.foreground = foreground;
    if (typeof disabledBackground === 'number') this.disabledBackground = disabledBackground;
    if (typeof disabledForeground === 'number') this.disabledForeground = disabledForeground;
  }
}

export class HuaweiQuickLoginViewFactory extends PlatformViewFactory {
  private messenger: BinaryMessenger;

  constructor(messenger: BinaryMessenger) {
    super(new StandardMessageCodec());
    this.messenger = messenger;
  }

  public create(context: common.Context, viewId: number, args: Object): PlatformView {
    const colors = args instanceof Map ? args as Map<string, number> : new Map<string, number>();
    return new HuaweiQuickLoginPlatformView(this.messenger, viewId, colors);
  }
}

export class HuaweiQuickLoginPlatformView extends PlatformView {
  private channel: MethodChannel;
  private controller: loginComponentManager.LoginWithHuaweiIDButtonController;
  private theme: HuaweiButtonTheme = new HuaweiButtonTheme();

  constructor(messenger: BinaryMessenger, viewId: number, colors: Map<string, number>) {
    super();
    this.theme.update(colors);
    this.channel = new MethodChannel(messenger, `${HUAWEI_QUICK_LOGIN_VIEW_TYPE}${viewId}`);
    this.controller = new loginComponentManager.LoginWithHuaweiIDButtonController();
    this.controller
      .setAgreementStatus(loginComponentManager.AgreementStatus.NOT_ACCEPTED)
      .setEnabled(false)
      .onClickLoginWithHuaweiIDButton((error, credential) => {
        if (error) {
          const code = `${error.code}`;
          if (code !== '1001502012') {
            this.channel.invokeMethod('loginError', `${code}: ${error.message}`);
          }
          return;
        }
        const authorizationCode = credential?.authorizationCode ?? '';
        if (authorizationCode.length === 0) {
          this.channel.invokeMethod('loginError', '华为账号未返回授权码');
          return;
        }
        this.channel.invokeMethod('loginSuccess', authorizationCode);
      });

    this.channel.setMethodCallHandler({
      onMethodCall: (call: MethodCall, result: MethodResult): void => {
        if (call.method === 'setAgreementAccepted') {
          const accepted = call.args as boolean;
          this.controller
            .setAgreementStatus(
              accepted
                ? loginComponentManager.AgreementStatus.ACCEPTED
                : loginComponentManager.AgreementStatus.NOT_ACCEPTED,
            )
            .setEnabled(accepted);
          result.success(null);
        } else if (call.method === 'setTheme') {
          this.theme.update(call.args as Map<string, number>);
          result.success(null);
        } else {
          result.notImplemented();
        }
      },
    });
  }

  getController(): loginComponentManager.LoginWithHuaweiIDButtonController {
    return this.controller;
  }

  getTheme(): HuaweiButtonTheme {
    return this.theme;
  }

  getView(): WrappedBuilder<[Params]> {
    return new WrappedBuilder(HuaweiQuickLoginBuilder);
  }

  dispose(): void {
    this.controller.setEnabled(false);
    this.channel.setMethodCallHandler(null);
  }
}

@Builder
function HuaweiQuickLoginBuilder(params: Params) {
  HuaweiQuickLoginButton({
    theme: (params.platformView as HuaweiQuickLoginPlatformView).getTheme(),
    controller: (params.platformView as HuaweiQuickLoginPlatformView).getController(),
  })
    .width('100%')
    .height('100%')
}

@Component
struct HuaweiQuickLoginButton {
  @ObjectLink theme: HuaweiButtonTheme;
  controller: loginComponentManager.LoginWithHuaweiIDButtonController =
    new loginComponentManager.LoginWithHuaweiIDButtonController();

  build() {
    LoginWithHuaweiIDButton({
      params: {
        loginType: loginComponentManager.LoginType.QUICK_LOGIN,
        style: loginComponentManager.Style.BUTTON_CUSTOM,
        // Flutter supplies both light and dark app theme colors.
        supportDarkMode: false,
        verifyPhoneNumber: true,
        extraStyle: {
          buttonStyle: new loginComponentManager.ButtonStyle()
            .backgroundColor(this.theme.background)
            .fontColor(this.theme.foreground),
          customButtonStateStyles: {
            disabled: new loginComponentManager.ButtonStyle()
              .backgroundColor(this.theme.disabledBackground)
              .fontColor(this.theme.disabledForeground),
          },
        },
      },
      controller: this.controller,
    })
      .width('100%')
      .height('100%')
  }
}
