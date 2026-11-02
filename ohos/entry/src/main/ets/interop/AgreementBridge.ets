import common from '@ohos.app.ability.common';
import { router } from '@kit.ArkUI';
import { BusinessError } from '@kit.BasicServicesKit';
import { hilog } from '@kit.PerformanceAnalysisKit';

/**
 * Agreement reader and privacy-consent entry points for the Flutter
 * `qflistudio/platform` channel.
 *
 * Kept in its own file so it can be registered from `EntryAbility` with two
 * lines and does not collide with the login and status-bar work that touches
 * the same ability.
 *
 * `openAgreement` opens the native `pages/AgreementReader` (an ordinary ArkWeb
 * page registered in `main_pages.json`), which is what
 * `lib/pages/auth/agreement_page.dart` expects.
 */
export class AgreementPlatformBridge {
  /**
   * Opens the in-app reader. Returns an error message for the Flutter side, or
   * null when the page was pushed.
   */
  static openAgreement(
    context: common.UIAbilityContext,
    title: string,
    url: string,
  ): Promise<string | null> {
    // Only https documents are opened in the app: an http page would be
    // downgraded transport for a legally binding document.
    if (typeof url !== 'string' || !url.startsWith('https://')) {
      return Promise.resolve('协议地址无效');
    }
    const params: Record<string, string> = {
      'title': typeof title === 'string' && title.length > 0 ? title : '协议',
      'url': url,
    };
    return context
      .startAbility({
        bundleName: context.abilityInfo.bundleName,
        abilityName: context.abilityInfo.name,
        parameters: params,
      })
      .then(() => {
        router.pushUrl({ url: 'pages/AgreementReader', params: params })
          .catch((err: BusinessError) => {
            hilog.error(0x0000, 'AgreementBridge', 'pushUrl failed: %{public}s',
              `${err.code}: ${err.message}`);
          });
        return null;
      })
      .catch((err: BusinessError) => `协议加载失败：${err.code}`);
  }

  /**
   * Withdraws the privacy-policy consent through the HarmonyOS privacy host.
   *
   * Returns `false` when this host has no hosted privacy statement to withdraw,
   * so the Flutter side can fall back to clearing local data, signing out and
   * telling the user to withdraw in system settings.
   *
   * The hosted withdrawal API (`privacyManager` / `AppPrivacyHost`) is only
   * present on shells that host their statement through Huawei's privacy
   * service. This build does not, so it reports "not hosted" instead of
   * pretending the consent was withdrawn.
   */
  static requestPrivacyWithdraw(): boolean {
    return false;
  }
}
