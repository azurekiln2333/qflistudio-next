
import {
  FlutterAbility,
  FlutterEngine,
  MethodChannel,
  MethodCall,
  MethodResult,
} from '@ohos/flutter_ohos';
import { authentication } from '@kit.AccountKit';
import { systemShare } from '@kit.ShareKit';
import { common, Want, ConfigurationConstant } from '@kit.AbilityKit';
import { window, display } from '@kit.ArkUI';
import { BusinessError } from '@kit.BasicServicesKit';
import { GeneratedPluginRegistrant } from '../plugins/GeneratedPluginRegistrant';
import { configureInteropChannels } from '../interop/StudioInterop';
import { AgreementPlatformBridge } from '../interop/AgreementBridge';

const CHANNEL_PLATFORM = 'qflistudio/platform';
const CHANNEL_HUAWEI = 'qflistudio/huawei_account';
const CHANNEL_SAFE_AREA = 'qflistudio/safe_area';

/**
 * Snapshot of the window avoid areas that page content must not cover.
 *
 * `topInVp` is the larger of the status bar height and the cutout bottom
 * edge, converted to vp so Flutter can apply it directly. `topPx` keeps the
 * raw value for ArkTS builders that avoid areas in px.
 */
export class WindowSafeArea {
  topInVp: number = 0;
  topPx: number = 0;

  toMap(): Map<string, Object> {
    const map: Map<string, Object> = new Map<string, Object>();
    map.set('top', this.topInVp);
    map.set('topPx', this.topPx);
    return map;
  }
}

/**
 * Screen density of the default display, in the same unit Flutter uses for
 * logical pixels. Missing or invalid values fall back to 1.
 */
export function screenDensity(): number {
  try {
    const density = display.getDefaultDisplaySync().densityPixels;
    if (density > 0) {
      return density;
    }
  } catch (e) {
    // Display information is unavailable; assume 1:1.
  }
  return 1;
}

/**
 * Reads the status bar and cutout avoid areas of `win` and returns the top
 * inset. Unreadable values become zero, so the caller never applies a larger
 * inset than the system asks for.
 */
export function readWindowSafeArea(win: window.Window): WindowSafeArea {
  const area = new WindowSafeArea();
  if (!win) {
    return area;
  }
  try {
    const density = screenDensity();
    const cutoutBottom = win.getWindowAvoidArea(
      window.AvoidAreaType.TYPE_CUTOUT,
    ).topRect.height;
    const statusBarBottom = win.getWindowAvoidArea(
      window.AvoidAreaType.TYPE_SYSTEM,
    ).topRect.height;
    const topPx = Math.max(cutoutBottom, statusBarBottom);
    area.topPx = topPx;
    area.topInVp = topPx / density;
  } catch (e) {
    // The avoid area APIs are missing on some devices; keep zero.
  }
  return area;
}

export default class EntryAbility extends FlutterAbility {
  private safeAreaWindow: window.Window | null = null;
  private safeArea: WindowSafeArea = new WindowSafeArea();
  private safeAreaChannel: MethodChannel | null = null;
  private avoidAreaListener: ((data: window.AvoidAreaOptions) => void) | null =
    null;

  onWindowStageCreate(windowStage: window.WindowStage): void {
    // 启动遮罩消失后、Flutter 首帧渲染前，引擎初始化期间窗口会露出
    // 默认白底。窗口底色与 Flutter 的 MD3 surface 保持一致。
    try {
      const isDark = this.context.config?.colorMode ===
        ConfigurationConstant.ColorMode.COLOR_MODE_DARK;
      windowStage.getMainWindowSync().setWindowBackgroundColor(
        isDark ? '#FF111418' : '#FFF8F9FF',
      );
    } catch (e) {
      // 设置失败不影响启动（仅深色模式可能出现短暂白闪）。
    }
    this.bindWindowAvoidArea(windowStage);
    super.onWindowStageCreate(windowStage);
  }

  onWindowStageDestroy(): void {
    const win = this.safeAreaWindow;
    const listener = this.avoidAreaListener;
    if (win && listener) {
      try {
        win.off('avoidAreaChange', listener);
      } catch (e) {
        // The window is already gone.
      }
    }
    this.avoidAreaListener = null;
    this.safeAreaWindow = null;
    super.onWindowStageDestroy();
  }

  /** Tracks the status bar and cutout insets, including fold and unfold. */
  private bindWindowAvoidArea(windowStage: window.WindowStage): void {
    try {
      const win = windowStage.getMainWindowSync();
      this.safeAreaWindow = win;
      this.safeArea = readWindowSafeArea(win);
      this.avoidAreaListener = (data: window.AvoidAreaOptions) => {
        const type = data ? data.type : undefined;
        if (type !== undefined && type !== window.AvoidAreaType.TYPE_CUTOUT &&
          type !== window.AvoidAreaType.TYPE_SYSTEM) {
          return;
        }
        this.safeArea = readWindowSafeArea(win);
        this.safeAreaChannel?.invokeMethod('update', this.safeArea.toMap());
      };
      win.on('avoidAreaChange', this.avoidAreaListener);
    } catch (e) {
      // Avoid area tracking is best effort.
    }
  }

  configureFlutterEngine(flutterEngine: FlutterEngine) {
    super.configureFlutterEngine(flutterEngine)
    GeneratedPluginRegistrant.registerWith(flutterEngine)

    // Cross-app compile and run: Dart asks a sibling app to build and execute a
    // project, and the sibling app streams events back to this engine.
    configureInteropChannels(flutterEngine, this.context as common.UIAbilityContext);

    const abilityContext = this.context as common.UIAbilityContext;

    // 状态栏与挖孔区避让：Flutter 读取原生避让区，取不到时用这里上报的值。
    const safeAreaChannel = new MethodChannel(
      flutterEngine.dartExecutor.getBinaryMessenger(),
      CHANNEL_SAFE_AREA,
    );
    this.safeAreaChannel = safeAreaChannel;
    safeAreaChannel.setMethodCallHandler({
      onMethodCall: (call: MethodCall, result: MethodResult): void => {
        if (call.method === 'getSafeArea') {
          const win = this.safeAreaWindow;
          if (win) {
            this.safeArea = readWindowSafeArea(win);
          }
          result.success(this.safeArea.toMap());
        } else {
          result.notImplemented();
        }
      },
    });

    // 通用平台能力：打开系统浏览器（HTML 预览用）。
    const platformChannel = new MethodChannel(
      flutterEngine.dartExecutor.getBinaryMessenger(),
      CHANNEL_PLATFORM,
    );
    platformChannel.setMethodCallHandler({
      onMethodCall(call: MethodCall, result: MethodResult): void {
        if (call.method === 'openUrl') {
          const url = call.argument('url') as string;
          const want: Want = {
            action: 'ohos.want.action.viewData',
            uri: url,
          };
          abilityContext.startAbility(want)
            .then(() => {
              result.success(null);
            })
            .catch((err: BusinessError) => {
              result.error(`${err.code}`, `${err.message}`, null);
            });
        } else if (call.method === 'shareText') {
          // 系统分享面板（Share Kit）：纯文本分享。
          const title = call.argument('title') as string;
          const text = call.argument('text') as string;
          const record: systemShare.SharedRecord = {
            utd: 'general.plain-text',
            content: text,
            title: title,
          };
          const data = new systemShare.SharedData(record);
          const controller = new systemShare.ShareController(data);
          const options: systemShare.ShareControllerOptions = {};
          controller.show(abilityContext, options)
            .then(() => {
              result.success(null);
            })
            .catch((err: BusinessError) => {
              result.error('SHARE_FAILED', `${err.code}: ${err.message}`, null);
            });
        } else if (call.method === 'openAgreement') {
          // 应用内协议阅读页（整改任务书 §3-W3）：只开 https 文档。
          const title = call.argument('title') as string;
          const url = call.argument('url') as string;
          AgreementPlatformBridge.openAgreement(abilityContext, title, url)
            .then((error: string | null) => {
              if (error === null) {
                result.success(true);
              } else {
                result.error('AGREEMENT_FAILED', error, null);
              }
            })
            .catch((err: BusinessError) => {
              result.error(
                'AGREEMENT_FAILED',
                `${err.code}: ${err.message}`,
                null,
              );
            });
        } else if (call.method === 'requestPrivacyWithdraw') {
          // 宿主不托管隐私声明：由系统设置里的华为隐私授权撤回。
          // Flutter 侧收到 false 就走本地退出 + 引导，不谎称已撤回。
          result.success(false);
        } else {
          result.notImplemented();
        }
      },
    });

    // 华为账号（Account Kit v4 / API 11）：
    // AuthorizationWithHuaweiIDRequest -> executeRequest -> authorizationCode，
    // authorizationCode 交给服务端换取 token / userinfo。
    const huaweiChannel = new MethodChannel(
      flutterEngine.dartExecutor.getBinaryMessenger(),
      CHANNEL_HUAWEI,
    );
    huaweiChannel.setMethodCallHandler({
      onMethodCall(call: MethodCall, result: MethodResult): void {
        if (call.method === 'login') {
          try {
            const provider = new authentication.HuaweiIDProvider();
            const request: authentication.AuthorizationWithHuaweiIDRequest =
              provider.createAuthorizationWithHuaweiIDRequest();
            request.scopes = ['openid'];
            request.permissions = [];

            const controller =
              new authentication.AuthenticationController(abilityContext);
            controller.executeRequest(request)
              .then((response: authentication.AuthenticationResponse) => {
                const authResponse =
                  response as authentication.AuthorizationWithHuaweiIDResponse;
                const code: string =
                  authResponse.data?.authorizationCode ?? '';
                if (code.length > 0) {
                  result.success(code);
                } else {
                  result.error('HUAWEI_LOGIN_EMPTY', '未获取到授权码', null);
                }
              })
              .catch((err: BusinessError) => {
                result.error('HUAWEI_LOGIN_FAILED', `${err.code}: ${err.message}`, null);
              });
          } catch (e) {
            const err = e as BusinessError;
            result.error('HUAWEI_LOGIN_ERROR', `${err.code}: ${err.message}`, null);
          }
        } else {
          result.notImplemented();
        }
      },
    });
  }
}
