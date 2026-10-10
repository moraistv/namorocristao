import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:mioamoreapp/config/config.dart';
import 'package:mioamoreapp/services/app_api.dart';

/// IDs de TESTE oficiais do Google (Android) — usados como fallback.
class TestAdUnits {
  TestAdUnits._();
  static const banner = "ca-app-pub-3940256099942544/6300978111";
  static const interstitial = "ca-app-pub-3940256099942544/1033173712";
  static const rewardedInterstitial = "ca-app-pub-3940256099942544/5354046379";
  static const appOpen = "ca-app-pub-3940256099942544/9257395921";
  static const native = "ca-app-pub-3940256099942544/2247696110";
}

/// Bloco de demonstração do Google Ad Manager para anúncios premiados.
/// Usado quando o "Modo teste" do painel está ligado.
const adManagerDemoRewardedUnit = "/21775744923/example/rewarded";

/// Lê a configuração de anúncios do painel (/config/ads) e mantém em cache.
/// Banner e intersticial ainda caem no ID de TESTE do Google quando o painel
/// não envia ID. O premiado (Ad Manager) só usa o bloco de demonstração com o
/// "Modo teste" ligado.
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
  static bool _rewardedFormatEnabled = false;

  static bool _interstitialOnOpenChat = false;
  static int _interstitialEverySecs = 120;

  static bool _loaded = false;

  static String get bannerId => _bannerId ?? TestAdUnits.banner;
  static String get interstitialId =>
      _interstitialId ?? TestAdUnits.interstitial;
  static String get appOpenId => _appOpenId ?? TestAdUnits.appOpen;

  /// Bloco do anúncio premiado (Google Ad Manager), ou null se indisponível.
  /// Em modo teste usa sempre o bloco de demonstração do Google; fora dele só
  /// vale o ID configurado no painel (nunca cai em anúncio de teste).
  static String? get rewardedUnitId {
    if (!enabled || !_rewardedFormatEnabled) return null;
    if (testMode) return adManagerDemoRewardedUnit;
    final id = _rewardedId;
    return (id == null || id.isEmpty) ? null : id;
  }

  /// Anúncios ligados no painel, formato Premiado ativo e bloco disponível.
  /// Vale também para VIP: o anúncio premiado é opcional.
  static bool get rewardedAvailable => rewardedUnitId != null;
  static bool get interstitialOnOpenChat => _interstitialOnOpenChat;
  static int get interstitialEverySecs => _interstitialEverySecs;

  static List<String> _appliedTestDevices = const [];

  /// Registra os aparelhos de teste do painel: neles os blocos reais exibem
  /// anúncios de teste, evitando tráfego inválido ao testar com IDs de produção.
  static Future<void> _applyTestDevices(List<String> ids) async {
    if (!isAdmobAvailable || listEquals(ids, _appliedTestDevices)) return;
    try {
      await MobileAds.instance.updateRequestConfiguration(
        RequestConfiguration(testDeviceIds: ids),
      );
      _appliedTestDevices = ids;
    } catch (error) {
      debugPrint("Não foi possível aplicar os aparelhos de teste: $error");
    }
  }

  /// Carrega a config do servidor (1x; usa cache depois).
  static Future<void> load({bool force = false}) async {
    if (_loaded && !force) return;
    final firstLoad = !_loaded;
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
      final formats = cfg["formats"];
      _rewardedFormatEnabled = formats is Map
          ? formats["rewarded"] == true
          : (_rewardedId?.isNotEmpty ?? false);
      final banner = (cfg["banner"] as Map?) ?? {};
      bannerPosition = (banner["position"] as String?) ?? "bottom";
      final inter = (cfg["interstitial"] as Map?) ?? {};
      _interstitialOnOpenChat = inter["onOpenChat"] == true;
      _interstitialEverySecs = (inter["everySecs"] as num?)?.toInt() ?? 120;
      final testDevices = ((cfg["testDeviceIds"] as List?) ?? const [])
          .map((id) => id.toString().trim())
          .where((id) => id.isNotEmpty)
          .toList();
      unawaited(_applyTestDevices(testDevices));
      _loaded = true;
      // Primeira carga: avisa quem já foi desenhado antes da config chegar
      // (ícone de recompensas, faixa do perfil, banners).
      if (firstLoad) _bump();
    } catch (_) {
      // Sem servidor: mantém desativado (não mostra nada).
      enabled = false;
    }
  }
}
