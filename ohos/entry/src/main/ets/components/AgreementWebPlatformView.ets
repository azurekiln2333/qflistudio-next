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
import { webview } from '@kit.ArkWeb';

export const AGREEMENT_WEB_VIEW_TYPE = 'qflistudio/agreement_web';

export class AgreementWebViewFactory extends PlatformViewFactory {
  private messenger: BinaryMessenger;

  constructor(messenger: BinaryMessenger) {
    super(new StandardMessageCodec());
    this.messenger = messenger;
  }

  public create(context: common.Context, viewId: number, args: Object): PlatformView {
    const url = typeof args === 'string' && args.startsWith('https://')
      ? args : 'about:blank';
    return new AgreementWebPlatformView(this.messenger, viewId, url);
  }
}

export class AgreementWebPlatformView extends PlatformView {
  private channel: MethodChannel;
  private controller: webview.WebviewController = new webview.WebviewController();
  private url: string;
  private loading: boolean = true;
  private error: string = '';
  private disposed: boolean = false;

  constructor(messenger: BinaryMessenger, viewId: number, url: string) {
    super();
    this.url = url;
    this.channel = new MethodChannel(messenger, `${AGREEMENT_WEB_VIEW_TYPE}${viewId}`);
    this.channel.setMethodCallHandler({
      onMethodCall: (call: MethodCall, result: MethodResult): void => {
        if (call.method === 'getStatus') {
          const status = new Map<string, Object>();
          status.set('loading', this.loading);
          if (this.error.length > 0) status.set('error', this.error);
          result.success(status);
        } else if (call.method === 'reload') {
          try {
            this.onPageStarted();
            this.controller.loadUrl(this.url);
            result.success(null);
          } catch (e) {
            this.onLoadError('协议加载失败，请稍后重试');
            result.error('AGREEMENT_LOAD_FAILED', '协议加载失败，请稍后重试', null);
          }
        } else {
          result.notImplemented();
        }
      },
    });
  }

  getUrl(): string {
    return this.url;
  }

  getController(): webview.WebviewController {
    return this.controller;
  }

  onPageStarted(): void {
    if (this.disposed) return;
    this.loading = true;
    this.error = '';
    this.channel.invokeMethod('pageStarted', null);
  }

  onPageFinished(): void {
    if (this.disposed) return;
    this.loading = false;
    this.channel.invokeMethod('pageFinished', null);
  }

  onLoadError(message: string): void {
    if (this.disposed) return;
    this.loading = false;
    this.error = message;
    this.channel.invokeMethod('loadError', message);
  }

  getView(): WrappedBuilder<[Params]> {
    return new WrappedBuilder(AgreementWebBuilder);
  }

  dispose(): void {
    this.disposed = true;
    this.channel.setMethodCallHandler(null);
  }
}

@Builder
function AgreementWebBuilder(params: Params) {
  Web({
    src: (params.platformView as AgreementWebPlatformView).getUrl(),
    controller: (params.platformView as AgreementWebPlatformView).getController(),
    renderMode: RenderMode.SYNC_RENDER,
  })
    .width('100%')
    .height('100%')
    .javaScriptAccess(true)
    .domStorageAccess(true)
    .mixedMode(MixedMode.None)
    .onPageBegin(() => {
      (params.platformView as AgreementWebPlatformView).onPageStarted();
    })
    .onPageEnd(() => {
      (params.platformView as AgreementWebPlatformView).onPageFinished();
    })
    .onErrorReceive((event) => {
      if (event?.request.isMainFrame()) {
        (params.platformView as AgreementWebPlatformView).onLoadError(
          `协议加载失败：${event.error.getErrorInfo()}`,
        );
      }
    })
    .onHttpErrorReceive((event) => {
      if (event?.request.isMainFrame()) {
        (params.platformView as AgreementWebPlatformView).onLoadError(
          `协议加载失败（HTTP ${event.response.getResponseCode()}）`,
        );
      }
    })
    .onOverrideUrlLoading((request) => {
      const url = request.getRequestUrl();
      return !url.startsWith('https://') && !url.startsWith('http://');
    })
}
