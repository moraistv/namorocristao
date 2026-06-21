import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:mioamoreapp/config/config.dart';
import 'package:mioamoreapp/services/ads_service.dart';

/// Gerencia o anúncio intersticial: pré-carrega e exibe respeitando o
/// intervalo mínimo configurado no painel (/config/ads).
class InterstitialManager {
  InterstitialManager._();

  static InterstitialAd? _ad;
  static bool _loading = false;
  static DateTime? _lastShown;

  static void preload() {
    if (!isAdmobAvailable || !AdsService.shouldShowAds) return;
    if (_ad != null || _loading) return;
    _loading = true;
    InterstitialAd.load(
      adUnitId: AdsService.interstitialId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          _ad = ad;
          _loading = false;
        },
        onAdFailedToLoad: (_) {
          _ad = null;
          _loading = false;
        },
      ),
    );
  }

  /// Mostra o intersticial se houver um carregado e o intervalo mínimo passou.
  /// Retorna true se exibiu.
  static bool maybeShow() {
    if (!isAdmobAvailable || !AdsService.shouldShowAds) return false;
    final secs = AdsService.interstitialEverySecs;
    if (secs > 0 && _lastShown != null) {
      final since = DateTime.now().difference(_lastShown!).inSeconds;
      if (since < secs) {
        preload();
        return false;
      }
    }
    final ad = _ad;
    if (ad == null) {
      preload();
      return false;
    }
    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        _ad = null;
        preload();
      },
      onAdFailedToShowFullScreenContent: (ad, _) {
        ad.dispose();
        _ad = null;
        preload();
      },
    );
    ad.show();
    _lastShown = DateTime.now();
    return true;
  }
}
