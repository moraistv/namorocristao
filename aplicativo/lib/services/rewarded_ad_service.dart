import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:mioamoreapp/config/config.dart';
import 'package:mioamoreapp/services/ads_service.dart';

/// Resultado de exibir um anúncio premiado.
enum RewardedAdOutcome {
  /// O usuário assistiu até o fim e ganhou a recompensa (falta confirmar no servidor).
  earned,

  /// O usuário fechou o anúncio antes de ganhar a recompensa.
  dismissed,

  /// Não havia anúncio disponível (sem preenchimento, sem rede ou formato desligado).
  unavailable,

  /// O anúncio carregou, mas não foi possível exibi-lo.
  failed,
}

/// Anúncio premiado do Google Ad Manager com pré-carregamento.
///
/// O bloco vem do painel (`AdsService.rewardedUnitId`). Antes de exibir, o
/// resgate é reservado no servidor e seu id segue como `customData` para o
/// callback SSV do Google.
class RewardedAdService {
  RewardedAdService._();

  static RewardedAd? _ad;
  static String? _adUnit;
  static Completer<void>? _loading;
  static bool _showing = false;

  /// Há um anúncio carregado do bloco atual, pronto para exibir?
  static bool get isReady =>
      _ad != null && _adUnit != null && _adUnit == AdsService.rewardedUnitId;

  static void _discardIfStale(String? unit) {
    if (_ad != null && _adUnit != unit) {
      _ad?.dispose();
      _ad = null;
      _adUnit = null;
    }
  }

  static void _finishLoading(Completer<void> completer) {
    if (identical(_loading, completer)) _loading = null;
    if (!completer.isCompleted) completer.complete();
  }

  /// Começa a carregar um anúncio, se preciso. Seguro de chamar várias vezes.
  static Future<void> preload() {
    final unit = AdsService.rewardedUnitId;
    if (!isAdmobAvailable || _showing) return Future<void>.value();
    _discardIfStale(unit);
    if (unit == null || _ad != null) return Future<void>.value();

    final running = _loading;
    if (running != null) return running.future;

    final completer = Completer<void>();
    _loading = completer;
    RewardedAd.loadWithAdManagerAdRequest(
      adUnitId: unit,
      adManagerRequest: const AdManagerAdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          if (AdsService.rewardedUnitId == unit) {
            _ad?.dispose();
            _ad = ad;
            _adUnit = unit;
          } else {
            ad.dispose();
          }
          _finishLoading(completer);
        },
        onAdFailedToLoad: (error) {
          debugPrint("Anúncio premiado indisponível: $error");
          _finishLoading(completer);
        },
      ),
    ).catchError((Object error) {
      debugPrint("Falha ao pedir o anúncio premiado: $error");
      _finishLoading(completer);
    });
    return completer.future;
  }

  /// Garante um anúncio pronto, esperando o carregamento por até [timeout].
  static Future<bool> ensureReady({
    Duration timeout = const Duration(seconds: 12),
  }) async {
    if (isReady) return true;
    await preload().timeout(timeout, onTimeout: () {});
    return isReady;
  }

  /// Exibe o anúncio carregado. [userId] e [claimId] voltam no callback SSV.
  static Future<RewardedAdOutcome> show({
    required String userId,
    required String claimId,
  }) async {
    final ad = _ad;
    if (ad == null || _showing || !isReady) {
      return RewardedAdOutcome.unavailable;
    }
    _ad = null;
    _adUnit = null;
    _showing = true;

    final result = Completer<RewardedAdOutcome>();
    var earned = false;

    void finish(RewardedAdOutcome outcome) {
      if (!result.isCompleted) result.complete(outcome);
    }

    ad.fullScreenContentCallback = FullScreenContentCallback<RewardedAd>(
      onAdDismissedFullScreenContent: (ad) async {
        ad.dispose();
        // A recompensa costuma chegar antes do fechamento; a folga cobre a corrida.
        if (!earned) {
          await Future<void>.delayed(const Duration(milliseconds: 400));
        }
        finish(earned ? RewardedAdOutcome.earned : RewardedAdOutcome.dismissed);
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        debugPrint("Falha ao exibir o anúncio premiado: $error");
        ad.dispose();
        finish(RewardedAdOutcome.failed);
      },
    );

    try {
      await ad.setServerSideOptions(
        ServerSideVerificationOptions(userId: userId, customData: claimId),
      );
      await ad.show(onUserEarnedReward: (_, __) => earned = true);
    } catch (error) {
      debugPrint("Erro ao exibir o anúncio premiado: $error");
      ad.dispose();
      finish(RewardedAdOutcome.failed);
    }

    final outcome = await result.future;
    _showing = false;
    unawaited(preload());
    return outcome;
  }
}
