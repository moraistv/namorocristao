import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mioamoreapp/services/app_api.dart';

/// VIP do usuário, vindo do servidor: concedido no painel ou ganho por anúncio
/// premiado. Não existe compra dentro do app.
final isPremiumUserProvider = FutureProvider<bool>((ref) async {
  try {
    final stats = await AppApi.getStats();
    return stats["isPremium"] == true;
  } catch (_) {
    return false;
  }
});
