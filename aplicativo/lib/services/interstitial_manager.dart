import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:mioamoreapp/config/config.dart';
import 'package:mioamoreapp/services/ads_service.dart';

/// Gerencia o anúncio intersticial (Google Ad Manager): pré-carrega e exibe
/// respeitando o intervalo mínimo configurado no painel (/config/ads).
class InterstitialManager {
  InterstitialManager._();

  static AdManagerInterstitialAd? _ad;

  /// Identidade da configuração que carregou o anúncio. A revisão impede
  /// reutilizar um cache anterior quando o formato/VIP foi desligado e depois
  /// religado com o mesmo bloco.
  static String? _adUnit;
  static int? _adRevision;
  static String? _loadingUnit;
  static int? _loadingRevision;
  static DateTime? _lastShown;

  static void _discardCached() {
    _ad?.dispose();
    _ad = null;
    _adUnit = null;
    _adRevision = null;
  }

  static void preload() {
    final revision = AdsService.revision.value;
    final unit = isAdmobAvailable && AdsService.shouldShowAds
        ? AdsService.interstitialUnitId
        : null;

    // Além de não carregar, invalida o cache e qualquer callback em voo.
    if (unit == null) {
      _discardCached();
      _loadingUnit = null;
      _loadingRevision = null;
      return;
    }
    if (_ad != null && (_adUnit != unit || _adRevision != revision)) {
      _discardCached();
    }
    if (_ad != null) return;
    if (_loadingUnit == unit && _loadingRevision == revision) return;

    _loadingUnit = unit;
    _loadingRevision = revision;
    AdManagerInterstitialAd.load(
      adUnitId: unit,
      request: const AdManagerAdRequest(),
      adLoadCallback: AdManagerInterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          final stillCurrent = _loadingUnit == unit &&
              _loadingRevision == revision &&
              isAdmobAvailable &&
              AdsService.shouldShowAds &&
              AdsService.interstitialUnitId == unit &&
              AdsService.revision.value == revision;
          if (!stillCurrent) {
            ad.dispose();
            return;
          }
          _ad = ad;
          _adUnit = unit;
          _adRevision = revision;
          _loadingUnit = null;
          _loadingRevision = null;
        },
        onAdFailedToLoad: (_) {
          // Uma carga antiga não pode apagar o estado da carga atual.
          if (_loadingUnit == unit && _loadingRevision == revision) {
            _loadingUnit = null;
            _loadingRevision = null;
          }
        },
      ),
    );
  }

  /// Mostra o intersticial se houver um carregado e o intervalo mínimo passou.
  /// Retorna true se exibiu.
  static bool maybeShow() {
    if (!isAdmobAvailable || !AdsService.shouldShowAds) {
      preload();
      return false;
    }
    final secs = AdsService.interstitialEverySecs;
    if (secs > 0 && _lastShown != null) {
      final since = DateTime.now().difference(_lastShown!).inSeconds;
      if (since < secs) {
        preload();
        return false;
      }
    }
    final ad = _ad;
    final unit = AdsService.interstitialUnitId;
    final revision = AdsService.revision.value;
    if (ad == null ||
        unit == null ||
        _adUnit != unit ||
        _adRevision != revision) {
      preload();
      return false;
    }
    ad.fullScreenContentCallback =
        FullScreenContentCallback<AdManagerInterstitialAd>(
      onAdDismissedFullScreenContent: (ad) {
        if (identical(_ad, ad)) {
          _discardCached();
        } else {
          ad.dispose();
        }
        preload();
      },
      onAdFailedToShowFullScreenContent: (ad, _) {
        if (identical(_ad, ad)) {
          _discardCached();
        } else {
          ad.dispose();
        }
        preload();
      },
    );
    ad.show();
    _lastShown = DateTime.now();
    return true;
  }
}
