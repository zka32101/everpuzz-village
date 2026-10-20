import 'dart:async';

import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:puzzle_core/foundation.dart';

/// AdMob のリワード広告(ライフ回復など、見ると報酬のものだけ)。
/// 広告ユニットIDはビルド時に渡す(`--dart-define=ADMOB_REWARDED_ID=...`)。
/// IDが無いときはアプリ側でこの窓口を作らない(広告ボタンは出ない)。
class AdMobGate implements AdGate {
  AdMobGate._(this._unitId, this._adsRemoved);

  final String _unitId;

  /// 広告削除済みなら出さない。
  final bool Function() _adsRemoved;

  /// 同意(UMP)を確認し、広告を出せる状態なら窓口を返す。出せないなら null。
  static Future<AdMobGate?> configure({
    required String unitId,
    required bool Function() adsRemoved,
  }) async {
    final consent = Completer<void>();
    ConsentInformation.instance.requestConsentInfoUpdate(
      ConsentRequestParameters(),
      () => ConsentForm.loadAndShowConsentFormIfRequired((_) {
        if (!consent.isCompleted) consent.complete();
      }),
      (_) {
        if (!consent.isCompleted) consent.complete();
      },
    );
    await consent.future;
    if (!await ConsentInformation.instance.canRequestAds()) return null;
    await MobileAds.instance.initialize();
    return AdMobGate._(unitId, adsRemoved);
  }

  @override
  Future<bool> showRewarded(RewardedPlacement placement) async {
    if (_adsRemoved()) return false;
    final loaded = Completer<RewardedAd?>();
    RewardedAd.load(
      adUnitId: _unitId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: loaded.complete,
        onAdFailedToLoad: (_) => loaded.complete(null),
      ),
    );
    final ad = await loaded.future;
    if (ad == null) return false;

    var earned = false;
    final done = Completer<void>();
    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        if (!done.isCompleted) done.complete();
      },
      onAdFailedToShowFullScreenContent: (ad, _) {
        ad.dispose();
        if (!done.isCompleted) done.complete();
      },
    );
    await ad.show(onUserEarnedReward: (_, __) => earned = true);
    await done.future;
    return earned;
  }
}
