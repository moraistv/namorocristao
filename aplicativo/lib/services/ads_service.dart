import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:mioamoreapp/config/config.dart';
import 'package:mioamoreapp/services/app_api.dart';
import 'package:mioamoreapp/services/realtime_bus.dart';
import 'package:mioamoreapp/services/token_storage.dart';

/// Blocos de demonstração do Google Ad Manager (Android), usados com o
/// "Modo teste" do painel ligado. Não pertencem a nenhuma conta, então testar
/// com eles não gera tráfego inválido.
class AdManagerDemoUnits {
  AdManagerDemoUnits._();
  static const banner = "/21775744923/example/fixed-size-banner";
  static const interstitial = "/21775744923/example/interstitial";
  static const rewarded = "/21775744923/example/rewarded";
  static const rewardedInterstitial =
      "/21775744923/example/rewarded-interstitial";
  static const appOpen = "/21775744923/example/app-open";
  static const native = "/21775744923/example/native";
}

/// Lê a configuração de anúncios do painel (/config/ads) e mantém em cache.
/// Todos os blocos são do Google Ad Manager (caminho /REDE/bloco). Com o
/// "Modo teste" ligado o app usa os blocos de demonstração; desligado, só os
/// do painel. Formato desligado ou sem bloco não mostra nada.
class AdsService {
  AdsService._();

  static bool enabled = false;
  static bool testMode = true;
  static String bannerPosition = "bottom";

  /// Usuário sem banner e intersticial: VIP dado pela equipe, ou VIP por
  /// anúncio quando o painel liga essa opção (o servidor decide: `adFree`).
  static bool isPremiumUser = false;

  /// `adFree` do servidor; respostas antigas só têm `isPremium`.
  static bool adFreeFrom(Map<String, dynamic> data) =>
      data.containsKey("adFree")
          ? data["adFree"] == true
          : data["isPremium"] == true;

  /// Só exibe anúncios se estiverem ligados E o usuário não for VIP.
  static bool get shouldShowAds => enabled && !isPremiumUser;

  /// Notifica os widgets de anúncio para reavaliarem (config remota mudou,
  /// usuário virou VIP, etc.) — reflete na hora, sem reabrir o app.
  static final ValueNotifier<int> revision = ValueNotifier<int>(0);
  static void _bump() => revision.value++;

  static Timer? _premiumCheck;

  /// Marca/desmarca VIP e reflete imediatamente (esconde/mostra anúncios).
  /// Com validade, confere de novo no servidor quando ela vencer: o VIP por
  /// anúncio dura poucas horas e os anúncios precisam voltar sozinhos.
  static void setPremium(bool value, {DateTime? until}) {
    _schedulePremiumCheck(value ? until : null);
    if (isPremiumUser == value) return;
    isPremiumUser = value;
    _bump();
  }

  static void _schedulePremiumCheck(DateTime? until) {
    _premiumCheck?.cancel();
    _premiumCheck = null;
    if (until == null) return;
    final left = until.difference(DateTime.now());
    // Folga de 2s para o servidor já considerar o VIP vencido. Se o relógio do
    // aparelho já passou do fim mas o servidor ainda diz VIP (relógio
    // adiantado), espera 30s entre as conferências em vez de repetir na hora.
    _premiumCheck = Timer(
      left > Duration.zero
          ? left + const Duration(seconds: 2)
          : const Duration(seconds: 30),
      () => unawaited(refreshPremium()),
    );
  }

  /// Confere no servidor se o usuário está sem anúncios (fim do VIP, volta do
  /// app para a frente, evento perdido) e reagenda a próxima conferência.
  static Future<void> refreshPremium() async {
    if (!TokenStorage.isLoggedIn) {
      setPremium(false);
      return;
    }
    try {
      final stats = await AppApi.getStats();
      final adFree = adFreeFrom(stats);
      final changed = adFree != isPremiumUser;
      setPremium(
        adFree,
        until: DateTime.tryParse(stats["premiumUntil"]?.toString() ?? ""),
      );
      // Curtidas, perfil e descoberta recarregam com o VIP atual.
      if (changed) RealtimeBus.accountChanged();
    } catch (_) {
      // Sem rede agora: tenta de novo em 1 minuto.
      _premiumCheck?.cancel();
      _premiumCheck = Timer(
        const Duration(minutes: 1),
        () => unawaited(refreshPremium()),
      );
    }
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
  static bool _bannerFormatEnabled = false;
  static bool _interstitialFormatEnabled = false;
  static bool _rewardedFormatEnabled = false;
  static bool _appOpenFormatEnabled = false;

  static bool _interstitialOnOpenChat = false;
  static int _interstitialEverySecs = 120;

  static bool _loaded = false;

  /// Bloco a usar para um formato, ou null se ele não deve aparecer. Em modo
  /// teste usa sempre o bloco de demonstração do Ad Manager; fora dele só vale
  /// o bloco do painel (nunca cai em anúncio de teste em produção).
  static String? _unitFor(bool formatEnabled, String? configured, String demo) {
    if (!enabled || !formatEnabled) return null;
    if (testMode) return demo;
    return (configured == null || configured.isEmpty) ? null : configured;
  }

  static String? get bannerUnitId =>
      _unitFor(_bannerFormatEnabled, _bannerId, AdManagerDemoUnits.banner);
  static String? get interstitialUnitId => _unitFor(_interstitialFormatEnabled,
      _interstitialId, AdManagerDemoUnits.interstitial);

  /// Ainda não exibido pelo app; fica pronto para quando o App Open entrar.
  static String? get appOpenUnitId =>
      _unitFor(_appOpenFormatEnabled, _appOpenId, AdManagerDemoUnits.appOpen);

  /// Bloco do anúncio premiado (Google Ad Manager), ou null se indisponível.
  static String? get rewardedUnitId => _unitFor(
      _rewardedFormatEnabled, _rewardedId, AdManagerDemoUnits.rewarded);

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
      // Sem anúncios para o VIP da equipe (e, se o painel quiser, o por anúncio).
      try {
        final stats = await AppApi.getStats();
        setPremium(
          adFreeFrom(stats),
          until: DateTime.tryParse(stats["premiumUntil"]?.toString() ?? ""),
        );
      } catch (_) {}
      final cfg = await AppApi.getAdsConfig();
      enabled = cfg["enabled"] == true;
      testMode = cfg["testMode"] != false;
      final units = (cfg["units"] as Map?) ?? {};
      _bannerId = (units["banner"] as String?)?.trim();
      _interstitialId = (units["interstitial"] as String?)?.trim();
      _rewardedId = (units["rewarded"] as String?)?.trim();
      _appOpenId = (units["appOpen"] as String?)?.trim();
      // Formatos ligados no painel. Servidores antigos não mandam `formats`:
      // aí vale ter bloco preenchido.
      final formats = cfg["formats"];
      bool formatOn(String key, String? unit) =>
          formats is Map ? formats[key] == true : (unit?.isNotEmpty ?? false);
      _bannerFormatEnabled = formatOn("banner", _bannerId);
      _interstitialFormatEnabled = formatOn("interstitial", _interstitialId);
      _rewardedFormatEnabled = formatOn("rewarded", _rewardedId);
      _appOpenFormatEnabled = formatOn("appOpen", _appOpenId);
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
