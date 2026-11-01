/*
 * Receives response events from a sibling language app.
 *
 * A receiver cannot call back into a Flutter engine in another app, so every
 * event arrives as one `startAbility` on this exported ability. The ability
 * validates the caller bundle, matches the session Studio started, forwards
 * the event to Dart and finishes immediately.
 *
 * It deliberately does not create a Flutter engine: a second engine in the
 * same process would not share Dart's channel state with EntryAbility.
 */
import { UIAbility, Want } from '@kit.AbilityKit';
import { window } from '@kit.ArkUI';
import { FlutterEngine, FlutterManager } from '@ohos/flutter_ohos';
import { bridgeHostEngine, forwardBridgeEvent } from './InteropBridge';

export default class InteropBridgeAbility extends UIAbility {
  onCreate(want: Want): void {
    this.handle(want);
    this.finish();
  }

  onNewWant(want: Want): void {
    this.handle(want);
    this.finish();
  }

  onWindowStageCreate(windowStage: window.WindowStage): void {
    // No UI. The framework still creates a window stage, so it is finished at
    // once instead of loading a page that would show for a frame.
    this.finish();
  }

  private finish(): void {
    try {
      this.context.terminateSelf();
    } catch (error) {
      // Already finishing; nothing to do.
    }
  }

  private handle(want: Want): void {
    const source = want.parameters;
    if (source === undefined) {
      return;
    }
    const ability = FlutterManager.getInstance().getUIAbility(this.context);
    const engine: FlutterEngine | null = ability === undefined
      ? null
      : bridgeHostEngine(ability);
    // The caller bundle is the only identity the platform gives us here. The
    // parameter map is untrusted, so nothing from it decides authorisation.
    const caller = want.bundleName ?? '';
    forwardBridgeEvent(caller, source, engine, this.context);
  }
}
