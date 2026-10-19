import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mioamoreapp/providers/vip_status_provider.dart';
import 'package:mioamoreapp/views/app/rewards_page.dart';

/// Monta o conteúdo conforme o usuário seja VIP (estado vindo do servidor).
/// Telas antigas do template ainda usam este widget; não há compra no app.
class SubscriptionBuilder extends ConsumerWidget {
  final Widget Function(BuildContext context, bool isPremiumUser) builder;

  const SubscriptionBuilder({super.key, required this.builder});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isPremiumUserRef = ref.watch(isPremiumUserProvider);

    return isPremiumUserRef.when(
      data: (data) => builder(context, data),
      error: (_, __) => builder(context, false),
      loading: () => const SizedBox(),
    );
  }

  /// Antes abria a assinatura paga; agora leva ao VIP por anúncio premiado.
  static Future<void> showSubscriptionBottomSheet({
    required BuildContext context,
    String? message,
  }) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => RewardsPage(highlight: message, focusKind: "VIP"),
      ),
    );
  }
}
