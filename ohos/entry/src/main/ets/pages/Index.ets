
import common from '@ohos.app.ability.common';
import { window, display } from '@kit.ArkUI';
import { FlutterPage } from '@ohos/flutter_ohos'

let storage = LocalStorage.getShared()
const EVENT_BACK_PRESS = 'EVENT_BACK_PRESS'
const EVENT_STARTUP_PROGRESS = 'EVENT_STARTUP_PROGRESS'

/** Screen density of the default display; 1 when it cannot be read. */
function screenDensity(): number {
  try {
    const density = display.getDefaultDisplaySync().densityPixels;
    if (density > 0) {
      return density;
    }
  } catch (e) {
    // Assume 1:1 when display information is unavailable.
  }
  return 1;
}

/**
 * Top inset (vp) of the status bar and display cutout, so the splash content
 * is not drawn under the punch hole.
 */
function readTopAvoidVp(context: common.UIAbilityContext): Promise<number> {
  return window.getLastWindow(context)
    .then((win: window.Window) => {
      const density = screenDensity();
      const cutout = win.getWindowAvoidArea(
        window.AvoidAreaType.TYPE_CUTOUT,
      ).topRect.height;
      const status = win.getWindowAvoidArea(
        window.AvoidAreaType.TYPE_SYSTEM,
      ).topRect.height;
      return Math.max(cutout, status) / density;
    })
    .catch(() => 0);
}

@Component
struct StartupSplash {
  private context = getContext(this) as common.UIAbilityContext;
  @State progress: number = 0;
  @State topAvoidVp: number = 0;

  private onProgress = (progress: number): void => {
    this.progress = progress * 100;
  };

  aboutToAppear(): void {
    this.context.eventHub.on(EVENT_STARTUP_PROGRESS, this.onProgress);
    readTopAvoidVp(this.context).then((top: number) => {
      this.topAvoidVp = top;
    });
  }

  aboutToDisappear(): void {
    this.context.eventHub.off(EVENT_STARTUP_PROGRESS, this.onProgress);
  }

  build() {
    Stack({ alignContent: Alignment.Center }) {
      Image($r('app.media.icon'))
        .width(96)
        .height(96)
        .objectFit(ImageFit.Contain)

      Column() {
        Blank()
        Progress({ value: this.progress, total: 100, type: ProgressType.Linear })
          .width('100%')
          .constraintSize({ maxWidth: 420 })
          .style({ strokeWidth: 4, enableSmoothEffect: true, enableScanEffect: true })
      }
      .width('100%')
      .height('100%')
      .padding({ left: 32, right: 32, bottom: 48, top: this.topAvoidVp })
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.start_window_background'))
    .transition(TransitionEffect.asymmetric(
      TransitionEffect.IDENTITY,
      TransitionEffect.OPACITY.animation({ duration: 280, curve: Curve.EaseOut }),
    ))
  }
}

@Entry(storage)
@Component
struct Index {
  private context = getContext(this) as common.UIAbilityContext
  @LocalStorageLink('viewId') viewId: string = "";

  @Builder
  startupSplash() {
    StartupSplash()
  }

  build() {
    Column() {
      FlutterPage({ viewId: this.viewId, splashScreenView: this.startupSplash })
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.start_window_background'))
  }

  onBackPress(): boolean {
    this.context.eventHub.emit(EVENT_BACK_PRESS)
    return true
  }
}
