import 'package:flutter/foundation.dart';
import 'package:mioamoreapp/services/app_api.dart';

/// IDs de TESTE oficiais do Google (Android) — usados como fallback.
class TestAdUnits {
  TestAdUnits._();
  static const banner = "ca-app-pub-3940256099942544/6300978111";
  static const interstitial = "ca-app-pub-3940256099942544/1033173712";
  static const rewarded = "ca-app-pub-3940256099942544/5224354917";
  static const rewardedInterstitial = "ca-app-pub-3940256099942544/5354046379";
  static const appOpen = "ca-app-pub-3940256099942544/9257395921";
  static const native = "ca-app-pub-3940256099942544/2247696110";
}

/// Lê a configuração de anúncios do painel (/config/ads) e mantém em cache.
/// Quando um ID não vem do servidor, usa o ID de TESTE do Google.
class AdsService {
  AdsService._();

  static bool enabled = false;
  static bool testMode = true;
  static String bannerPosition = "bottom";

  /// Assinantes VIP não veem anúncios.
  static bool isPremiumUser = false;

  /// Só exibe anúncios se estiverem ligados E o usuário não for VIP.
  static bool get shouldShowAds => enabled && !isPremiumUser;

  /// Notifica os widgets de anúncio para reavaliarem (config remota mudou,
  /// usuário virou VIP, etc.) — reflete na hora, sem reabrir o app.
  static final ValueNotifier<int> revision = ValueNotifier<int>(0);
  static void _bump() => revision.value++;

  /// Marca/desmarca VIP e reflete imediatamente (esconde/mostra anúncios).
  static void setPremium(bool value) {
    if (isPremiumUser == value) return;
    isPremiumUser = value;
    _bump();
  }

  /// Recarrega a config do servidor (force) e notifica os widgets.
  static Future<void> reload() async {
    await load(force: true);
    _bump();
  }

  static String? _bannerId;
  static String? _interstitialId;
  static String? _rewardedId;
  static String? _appOpenId;

  static bool _interstitialOnOpenChat = false;
  static int _interstitialEverySecs = 120;

  static bool _loaded = false;

  static String get bannerId => _bannerId ?? TestAdUnits.banner;
  static String get interstitialId => _interstitialId ?? TestAdUnits.interstitial;
  static String get rewardedId => _rewardedId ?? TestAdUnits.rewarded;
  static String get appOpenId => _appOpenId ?? TestAdUnits.appOpen;
  static bool get interstitialOnOpenChat => _interstitialOnOpenChat;
  static int get interstitialEverySecs => _interstitialEverySecs;

  /// Carrega a config do servidor (1x; usa cache depois).
  static Future<void> load({bool force = false}) async {
    if (_loaded && !force) return;
    try {
      // Status VIP: assinantes não veem anúncios.
      try {
        final stats = await AppApi.getStats();
        isPremiumUser = stats["isPremium"] == true;
      } catch (_) {}
      final cfg = await AppApi.getAdsConfig();
      enabled = cfg["enabled"] == true;
      testMode = cfg["testMode"] != false;
      final units = (cfg["units"] as Map?) ?? {};
      _bannerId = (units["banner"] as String?)?.trim();
      _interstitialId = (units["interstitial"] as String?)?.trim();
      _rewardedId = (units["rewarded"] as String?)?.trim();
      _appOpenId = (units["appOpen"] as String?)?.trim();
      final banner = (cfg["banner"] as Map?) ?? {};
      bannerPosition = (banner["position"] as String?) ?? "bottom";
      final inter = (cfg["interstitial"] as Map?) ?? {};
      _interstitialOnOpenChat = inter["onOpenChat"] == true;
      _interstitialEverySecs = (inter["everySecs"] as num?)?.toInt() ?? 120;
      _loaded = true;
    } catch (_) {
      // Sem servidor: mantém desativado (não mostra nada).
      enabled = false;
    }
  }
}
