import 'package:flutter/material.dart';
import 'package:mioamoreapp/services/ads_service.dart';
import 'package:mioamoreapp/services/app_api.dart';
import 'package:mioamoreapp/views/app/app_theme.dart';
import 'package:mioamoreapp/views/app/rewards_page.dart';

/// Quem não é VIP tocou num recurso VIP: oferece VIP por anúncio premiado.
/// `reason` é a primeira frase do aviso (ex.: "O modo incógnito é um recurso VIP.").
/// Devolve true se, ao voltar das recompensas, o usuário já está VIP.
Future<bool> offerVipByAd(BuildContext context,
    {required String reason}) async {
  final canWatch = AdsService.rewardedAvailable;
  final watch = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      title: Row(children: [
        Icon(Icons.workspace_premium, color: AppTheme.gold),
        const SizedBox(width: 8),
        const Text("Recurso VIP"),
      ]),
      content: Text(
        canWatch
            ? "$reason Assista a um anúncio e fique VIP por um tempo."
            : "$reason Os anúncios premiados estão indisponíveis agora. Tente mais tarde.",
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, false),
          child: Text(canWatch ? "Agora não" : "Entendi"),
        ),
        if (canWatch)
          ElevatedButton.icon(
            style: AppTheme.primaryButton,
            onPressed: () => Navigator.pop(dialogContext, true),
            icon: const Icon(Icons.play_circle_fill_rounded, size: 18),
            label: const Text("Assistir anúncio"),
          ),
      ],
    ),
  );
  if (watch != true || !context.mounted) return false;

  await Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => const RewardsPage(
        highlight: "Assista a um anúncio e fique VIP por um tempo.",
        focusKind: "VIP",
      ),
    ),
  );
  try {
    final stats = await AppApi.getStats();
    return stats["isPremium"] == true;
  } catch (_) {
    return false;
  }
}
